import Foundation

/// Immutable artwork identity. This never replaces the fighter's gameplay ID.
struct CustomFighterAppearanceRef: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let assetID: String
    let version: Int
    let sha256: String

    init(schemaVersion: Int = 1, assetID: String, version: Int, sha256: String) {
        self.schemaVersion = schemaVersion
        self.assetID = assetID
        self.version = version
        self.sha256 = sha256
    }

    var isValid: Bool {
        schemaVersion == 1 && UUID(uuidString: assetID)?.uuidString.lowercased() == assetID
            && (1...10_000).contains(version)
            && sha256.count == 64 && sha256.allSatisfy { "0123456789abcdef".contains($0) }
    }

    var cacheKey: String { "\(assetID).\(version).\(sha256)" }
}

/// The network supplies metadata and PNG separately. The local installer checks
/// both before making either available to the roster or renderer.
struct CustomFighterPackManifest: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let assetID: String
    let version: Int
    let sha256: String
    let styleVersion: String
    let width: Int
    let height: Int
    let archetype: String
    let frames: [String: [Int]]

    var appearance: CustomFighterAppearanceRef {
        CustomFighterAppearanceRef(schemaVersion: schemaVersion, assetID: assetID, version: version, sha256: sha256)
    }
}

/// A saved library entry. A player's installed fighters remain available without
/// a current creation entitlement; ownership is selected by the account service.
struct CustomFighter: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let createdAt: Date
    let appearance: CustomFighterAppearanceRef

    var animal: Animal {
        let stableID = UUID(uuidString: id).map { "custom_" + $0.uuidString.lowercased().replacingOccurrences(of: "-", with: "_") } ?? id
        return Animal(id: stableID, name: name, emoji: "✨", category: .land,
                      pixelColor: "#888888", size: 3, isCustom: true, appearanceRef: appearance)
    }

    var isValid: Bool {
        let uuidPart = id.hasPrefix("custom_") ? String(id.dropFirst(7)).replacingOccurrences(of: "_", with: "-") : id
        return UUID(uuidString: uuidPart)?.uuidString.lowercased() == uuidPart
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name.unicodeScalars.count <= 24 && name.utf8.count <= 200
            && name.rangeOfCharacter(from: .controlCharacters) == nil
            && appearance.isValid && createdAt.timeIntervalSince1970.isFinite
    }
}
