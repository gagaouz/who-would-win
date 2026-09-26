import Foundation
import Combine
import CryptoKit
import ImageIO
import CoreGraphics

struct InstalledCustomFighterPack {
    let manifest: CustomFighterPackManifest
    let atlasURL: URL
    let cacheKey: String
    /// Tight content bounds in atlas coordinates, measured from decoded alpha.
    let contentBounds: [String: [Int]]
    let familyExtent: Int
}

/// Durable private artwork, separate from temporary decoded-image caches. The
/// account service selects an owner; this store never checks creation entitlement
/// and never performs a network request. All writes stay inside that owner's root.
@MainActor
final class CustomFighterLibraryStore: ObservableObject {
    static let shared = CustomFighterLibraryStore()
    static let maximumPNGBytes = 8 * 1024 * 1024
    static let maximumManifestBytes = 16 * 1024
    static let maximumRosterBytes = 2 * 1024 * 1024

    enum StorageError: Error, LocalizedError {
        case invalidOwner, ownerChanged, invalidFighter, invalidManifest, invalidImage, hashMismatch, immutableVersion, unsafeFile
        var errorDescription: String? {
            switch self {
            case .invalidOwner, .ownerChanged: return "Sign in again to save this fighter."
            case .invalidFighter, .invalidManifest, .invalidImage, .hashMismatch: return "This fighter's artwork could not be verified. Please download it again."
            case .immutableVersion: return "This artwork version does not match the saved fighter."
            case .unsafeFile: return "The saved artwork could not be read safely."
            }
        }
    }

    @Published private(set) var ownerID: String?
    @Published private(set) var fighters: [CustomFighter] = []
    @Published private(set) var revision = 0
    private let rootURL: URL
    private let files: FileManager
    private var installed: [String: InstalledCustomFighterPack] = [:]

    init(rootURL: URL? = nil, fileManager: FileManager = .default) {
        files = fileManager
        self.rootURL = rootURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomFighters/v1", isDirectory: true)
    }

    func setOwner(ownerID: String?) throws {
        guard ownerID == nil || Self.validOwner(ownerID!) else { throw StorageError.invalidOwner }
        guard ownerID != self.ownerID else { return }
        // Clear the previous account before attempting a read. A damaged new
        // roster must never leave somebody else's fighters visible.
        self.ownerID = ownerID
        fighters = []
        installed.removeAll()
        revision &+= 1
        guard let ownerID else { return }
        let rosterURL = ownerDirectory(ownerID).appendingPathComponent("roster.json")
        guard files.fileExists(atPath: rosterURL.path) else { return }
        let data = try readBounded(rosterURL, maximum: Self.maximumRosterBytes)
        let decoded = try JSONDecoder().decode([CustomFighter].self, from: data)
        guard decoded.count <= 500, decoded.allSatisfy(\.isValid), Set(decoded.map(\.id)).count == decoded.count else {
            throw StorageError.invalidFighter
        }
        fighters = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    /// Installs a verified immutable PNG + manifest directory before publishing
    /// an atomically written roster. A failed or interrupted write cannot expose
    /// a half-downloaded fighter. An orphan pack is harmless and never a roster.
    func install(manifest: CustomFighterPackManifest, pngData: Data,
                 fighter: CustomFighter, forOwner: String) throws {
        guard ownerID == forOwner, Self.validOwner(forOwner) else { throw StorageError.ownerChanged }
        guard fighter.isValid, fighter.appearance == manifest.appearance else { throw StorageError.invalidFighter }
        let measurements = try Self.validate(manifest: manifest, pngData: pngData)
        let encodedManifest = try JSONEncoder().encode(manifest)
        guard encodedManifest.count <= Self.maximumManifestBytes else { throw StorageError.invalidManifest }
        let ownerRoot = ownerDirectory(forOwner)
        let destination = packDirectory(manifest.appearance, owner: forOwner)
        try ensureDirectory(destination.deletingLastPathComponent())
        var createdPack = false
        if files.fileExists(atPath: destination.path) {
            let existing = try JSONDecoder().decode(CustomFighterPackManifest.self,
                from: readBounded(destination.appendingPathComponent("manifest.json"), maximum: Self.maximumManifestBytes))
            guard existing == manifest else { throw StorageError.immutableVersion }
            let previousPNG = try readBounded(destination.appendingPathComponent("atlas.png"), maximum: Self.maximumPNGBytes)
            guard Self.digest(previousPNG) == manifest.sha256 else { throw StorageError.immutableVersion }
        } else {
            let staging = destination.deletingLastPathComponent().appendingPathComponent(".install-" + UUID().uuidString, isDirectory: true)
            try ensureDirectory(staging)
            defer { try? files.removeItem(at: staging) }
            try pngData.write(to: staging.appendingPathComponent("atlas.png"), options: .atomic)
            try encodedManifest.write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
            try files.moveItem(at: staging, to: destination)
            createdPack = true
        }
        var next = fighters.filter { $0.id != fighter.id }
        next.append(fighter)
        next.sort { $0.createdAt > $1.createdAt }
        guard next.count <= 500 else {
            if createdPack { try? files.removeItem(at: destination) }
            throw StorageError.invalidFighter
        }
        do {
            try saveRoster(next, ownerRoot: ownerRoot)
        } catch {
            if createdPack { try? files.removeItem(at: destination) }
            throw error
        }
        fighters = next
        installed[manifest.appearance.cacheKey] = InstalledCustomFighterPack(
            manifest: manifest, atlasURL: destination.appendingPathComponent("atlas.png"),
            cacheKey: ownerKey(forOwner) + "." + manifest.appearance.cacheKey,
            contentBounds: measurements.bounds, familyExtent: measurements.extent)
        revision &+= 1
    }

    /// Returns only a fully validated installed pack for the current account.
    /// Missing, corrupted, deleted and unsupported art cleanly falls back to the
    /// bundled recipe without modifying the Animal or its gameplay identity.
    func pack(for appearance: CustomFighterAppearanceRef) -> InstalledCustomFighterPack? {
        guard appearance.isValid, let ownerID,
              fighters.contains(where: { $0.appearance.assetID == appearance.assetID }) else { return nil }
        if let cached = installed[appearance.cacheKey] {
            guard files.fileExists(atPath: cached.atlasURL.path) else {
                installed.removeValue(forKey: appearance.cacheKey)
                return nil
            }
            return cached
        }
        let directory = packDirectory(appearance, owner: ownerID)
        do {
            let manifest = try JSONDecoder().decode(CustomFighterPackManifest.self,
                from: readBounded(directory.appendingPathComponent("manifest.json"), maximum: Self.maximumManifestBytes))
            guard manifest.appearance == appearance else { return nil }
            let atlasURL = directory.appendingPathComponent("atlas.png")
            let bytes = try readBounded(atlasURL, maximum: Self.maximumPNGBytes)
            let measurements = try Self.validate(manifest: manifest, pngData: bytes)
            let result = InstalledCustomFighterPack(manifest: manifest, atlasURL: atlasURL,
                cacheKey: ownerKey(ownerID) + "." + appearance.cacheKey,
                contentBounds: measurements.bounds, familyExtent: measurements.extent)
            installed[appearance.cacheKey] = result
            return result
        } catch { return nil }
    }

    /// Called on an atlas-cache miss. Recheck bounded files and pixels before
    /// decoding into the shared budget; metadata caching cannot bypass validation
    /// if a disk file has changed since it was installed.
    func atlasImage(for pack: InstalledCustomFighterPack) -> CGImage? {
        guard let ownerID,
              pack.cacheKey == ownerKey(ownerID) + "." + pack.manifest.appearance.cacheKey,
              pack.atlasURL == packDirectory(pack.manifest.appearance, owner: ownerID).appendingPathComponent("atlas.png") else { return nil }
        do {
            let bytes = try readBounded(pack.atlasURL, maximum: Self.maximumPNGBytes)
            return try Self.validate(manifest: pack.manifest, pngData: bytes).image
        } catch { return nil }
    }

    func remove(fighterID: String) throws {
        guard let ownerID else { throw StorageError.invalidOwner }
        guard let removed = fighters.first(where: { $0.id == fighterID }) else { return }
        let next = fighters.filter { $0.id != fighterID }
        try saveRoster(next, ownerRoot: ownerDirectory(ownerID))
        fighters = next
        installed.removeValue(forKey: removed.appearance.cacheKey)
        revision &+= 1
        if !next.contains(where: { $0.appearance == removed.appearance }) {
            let currentVersion = packDirectory(removed.appearance, owner: ownerID)
            let directory = next.contains(where: { $0.appearance.assetID == removed.appearance.assetID })
                ? currentVersion : currentVersion.deletingLastPathComponent()
            if files.fileExists(atPath: directory.path) { try files.removeItem(at: directory) }
        }
    }

    func eraseAllLocalData() throws {
        installed.removeAll()
        fighters = []
        revision &+= 1
        if files.fileExists(atPath: rootURL.path) { try files.removeItem(at: rootURL) }
    }

    private static func validOwner(_ owner: String) -> Bool {
        !owner.isEmpty && owner.utf8.count <= 512 && !owner.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    private func ownerKey(_ owner: String) -> String { Self.digest(Data(owner.utf8)) }
    private func ownerDirectory(_ owner: String) -> URL { rootURL.appendingPathComponent(ownerKey(owner), isDirectory: true) }
    private func packDirectory(_ appearance: CustomFighterAppearanceRef, owner: String) -> URL {
        ownerDirectory(owner).appendingPathComponent("packs", isDirectory: true)
            .appendingPathComponent(appearance.assetID, isDirectory: true)
            .appendingPathComponent(String(appearance.version), isDirectory: true)
    }

    private func saveRoster(_ roster: [CustomFighter], ownerRoot: URL) throws {
        let data = try JSONEncoder().encode(roster)
        guard data.count <= Self.maximumRosterBytes else { throw StorageError.invalidFighter }
        try ensureDirectory(ownerRoot)
        let target = ownerRoot.appendingPathComponent("roster.json")
        try rejectSymlinks(target)
        try data.write(to: target, options: .atomic)
    }

    private func ensureDirectory(_ directory: URL) throws {
        try rejectSymlinks(directory)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func rejectSymlinks(_ url: URL) throws {
        let rootPath = rootURL.standardizedFileURL.path
        guard url.standardizedFileURL.path == rootPath || url.standardizedFileURL.path.hasPrefix(rootPath + "/") else {
            throw StorageError.unsafeFile
        }
        var component = url
        while component.standardizedFileURL.path.hasPrefix(rootPath) {
            let values = try? component.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values?.isSymbolicLink == true { throw StorageError.unsafeFile }
            if component.standardizedFileURL.path == rootPath { break }
            component.deleteLastPathComponent()
        }
    }

    private func readBounded(_ url: URL, maximum: Int) throws -> Data {
        try rejectSymlinks(url)
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let count = values.fileSize, count > 0, count <= maximum else {
            throw StorageError.unsafeFile
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard !data.isEmpty, data.count <= maximum else { throw StorageError.unsafeFile }
        return data
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Decode only after checking PNG headers and dimensions. This is a local
    /// technical gate, not a claim that image content has been moderated; server
    /// moderation and semantic pose/identity review precede delivery.
    static func validate(manifest: CustomFighterPackManifest, pngData: Data) throws -> (bounds: [String: [Int]], extent: Int, image: CGImage) {
        let poses = ["idle", "anticipation", "attack", "reaction"]
        guard manifest.appearance.isValid, manifest.styleVersion == "retro-v1",
              ["quadruped", "primate", "flyer", "swimmer", "serpentine", "arthropod", "biped", "amorphous", "tentacle"].contains(manifest.archetype),
              (32...2048).contains(manifest.width), (32...2048).contains(manifest.height),
              manifest.width.isMultiple(of: 2), manifest.height.isMultiple(of: 2),
              manifest.width * manifest.height <= 4_194_304,
              Set(manifest.frames.keys) == Set(poses) else { throw StorageError.invalidManifest }
        let cellWidth = manifest.width / 2, cellHeight = manifest.height / 2
        for (index, pose) in poses.enumerated() {
            guard manifest.frames[pose] == [(index % 2) * cellWidth, (index / 2) * cellHeight, cellWidth, cellHeight] else {
                throw StorageError.invalidManifest
            }
        }
        guard pngData.count <= maximumPNGBytes, pngData.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]) else {
            throw StorageError.invalidImage
        }
        guard digest(pngData) == manifest.sha256 else { throw StorageError.hashMismatch }
        let options = [kCGImageSourceShouldCache: false, kCGImageSourceShouldAllowFloat: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(pngData as CFData, options),
              CGImageSourceGetType(source) as String? == "public.png", CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              properties[kCGImagePropertyPixelWidth] as? Int == manifest.width,
              properties[kCGImagePropertyPixelHeight] as? Int == manifest.height,
              (properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1,
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, options),
              let rgba = RetroAtlasCache.detachedCopy(of: decoded),
              let data = rgba.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { throw StorageError.invalidImage }
        var bounds: [String: [Int]] = [:]
        var distinct: Set<String> = []
        var extent = 0
        for pose in poses {
            let frame = manifest.frames[pose]!
            var left = cellWidth, top = cellHeight, right = -1, bottom = -1, opaque = 0, transparent = 0
            for y in 0..<cellHeight {
                for x in 0..<cellWidth {
                    let alpha = bytes[(frame[1] + y) * rgba.bytesPerRow + (frame[0] + x) * 4 + 3]
                    if alpha > 8 {
                        left = min(left, x); right = max(right, x); top = min(top, y); bottom = max(bottom, y)
                    }
                    if alpha > 127 { opaque += 1 }
                    if alpha < 8 { transparent += 1 }
                }
            }
            guard opaque > cellWidth * cellHeight / 33, transparent > cellWidth * cellHeight / 50,
                  left >= 2, top >= 2, right < cellWidth - 2, bottom < cellHeight - 2,
                  right >= left, bottom >= top else { throw StorageError.invalidImage }
            let width = right - left + 1, height = bottom - top + 1
            var poseBytes = Data("\(width)x\(height):".utf8)
            for y in top...bottom {
                let offset = (frame[1] + y) * rgba.bytesPerRow + (frame[0] + left) * 4
                poseBytes.append(bytes.advanced(by: offset), count: width * 4)
            }
            distinct.insert(digest(poseBytes))
            bounds[pose] = [frame[0] + left, frame[1] + top, width, height]
            extent = max(extent, max(width, height))
        }
        guard distinct.count == 4 else { throw StorageError.invalidImage }
        return (bounds, extent, rgba)
    }
}
