import XCTest
import UIKit
import CryptoKit
@testable import WhoWouldWin

/// These are deliberately synthetic diagnostic shapes, not generated user art.
/// No test in this suite calls an image service or changes a real account.
@MainActor
final class CustomFighterLibraryTests: XCTestCase {
    private let owner = "diagnostic-owner-A"

    func testSyntheticServerNormalizedPackPassesTheRealNativeInstallerContract() throws {
        let bundle = Bundle(for: Self.self)
        // Opaque resource extension prevents Xcode PNG optimization from changing
        // the server bytes whose SHA-256 the production installer must verify.
        let pngURL = try XCTUnwrap(bundle.url(forResource: "custom_fighter_interop", withExtension: "spritepack"))
        let manifestURL = try XCTUnwrap(bundle.url(forResource: "custom_fighter_interop", withExtension: "json"))
        let manifest = try JSONDecoder().decode(CustomFighterPackManifest.self, from: Data(contentsOf: manifestURL))
        let png = try Data(contentsOf: pngURL)
        let result = try CustomFighterLibraryStore.validate(manifest: manifest, pngData: png)
        XCTAssertEqual(result.bounds.count, 4)
        XCTAssertGreaterThan(result.extent, 100)
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let store = CustomFighterLibraryStore(rootURL: root); try store.setOwner(ownerID: owner)
        let fighter = CustomFighter(id: manifest.assetID, name: "Interop Mock", createdAt: Date(timeIntervalSince1970: 1_700_000_000), appearance: manifest.appearance)
        try store.install(manifest: manifest, pngData: png, fighter: fighter, forOwner: owner)
        XCTAssertNotNil(store.pack(for: manifest.appearance))
    }

    func testMalformedOptionalArtworkCannotDiscardSavedTournamentOrWagerState() throws {
        let legacy = Animal(id: "custom_legacy_saved", name: "Mossback", emoji: "🐉", category: .fantasy,
                            pixelColor: "#4E7E45", size: 5, isCustom: true)
        let matchup = Matchup(id: UUID(), fighter1: legacy, fighter2: Animals.all[0], environment: .grassland,
                              wager: MatchupWager(pickedFighterId: legacy.id, amount: 100), result: nil)
        let original = Tournament(id: UUID(), createdAt: Date(timeIntervalSince1970: 1_700_000_000), size: .four,
            selectionMode: .manual, phase: .roundResults(roundIndex: 0), bracket: Bracket(rounds: [[matchup], []]),
            grandChampion: nil, rerollUsed: false, ledger: [], schemaVersion: Tournament.currentSchemaVersion,
            resolvedRounds: [0], grandChampionResolved: false)
        let encoded = try JSONEncoder().encode(original)
        XCTAssertNil(try JSONDecoder().decode(Tournament.self, from: encoded).bracket.rounds[0][0].fighter1.appearanceRef)
        let badValues: [Any] = ["broken", ["schemaVersion": "wrong"],
            ["schemaVersion": 99, "assetID": UUID().uuidString.lowercased(), "version": 1, "sha256": String(repeating: "a", count: 64)],
            ["schemaVersion": 1, "assetID": "../../outside", "version": 1, "sha256": String(repeating: "a", count: 64)]]
        for bad in badValues {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            var bracket = try XCTUnwrap(json["bracket"] as? [String: Any])
            var rounds = try XCTUnwrap(bracket["rounds"] as? [[[String: Any]]])
            var animal = try XCTUnwrap(rounds[0][0]["fighter1"] as? [String: Any])
            animal["appearanceRef"] = bad
            rounds[0][0]["fighter1"] = animal; bracket["rounds"] = rounds; json["bracket"] = bracket
            let restored = try JSONDecoder().decode(Tournament.self, from: JSONSerialization.data(withJSONObject: json))
            XCTAssertEqual(restored.id, original.id)
            XCTAssertEqual(restored.bracket.rounds[0][0].fighter1, legacy)
            XCTAssertEqual(restored.bracket.rounds[0][0].wager?.amount, 100)
            XCTAssertTrue(restored.isRoundResolved(0), "Cosmetic decode failure must not reset a settlement guard.")
        }
    }

    func testInstalledFourPosePackSurvivesColdLoadAndRendersOfflineOnOneBaseline() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try mockPack()
        let store = CustomFighterLibraryStore(rootURL: root)
        try store.setOwner(ownerID: owner)
        try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner)
        let cold = CustomFighterLibraryStore(rootURL: root)
        try cold.setOwner(ownerID: owner)
        XCTAssertEqual(cold.fighters, [fixture.fighter])
        let restored = try XCTUnwrap(cold.pack(for: fixture.fighter.appearance))
        XCTAssertEqual(try Data(contentsOf: restored.atlasURL), fixture.png)
        let art = RetroAssetStore(manifest: nil, library: cold)
        let descriptor = art.artworkDescriptor(for: fixture.fighter.animal)
        XCTAssertTrue(RetroMotionProfile.resolve(artwork: descriptor).authoredPoses)
        XCTAssertEqual(RetroMotionProfile.resolve(artwork: descriptor).anatomy, .biped)
        let frames = try RetroPose.allCases.map { try XCTUnwrap(art.image(for: fixture.fighter.animal, pose: $0)) }
        XCTAssertEqual(Set(try frames.map { try XCTUnwrap($0.pngData()) }).count, 4)
        XCTAssertTrue(frames.allSatisfy { $0.size == CGSize(width: 128, height: 128) })
        let bottoms = try frames.map { try alphaBottom($0) }
        XCTAssertEqual(Set(bottoms).count, 1, "Attack extension must not resize or shift the foot baseline.")
        XCTAssertLessThanOrEqual(art.cachedAtlasCost, 32 * 1024 * 1024)
        art.clearMemoryCache()
        XCTAssertEqual(try XCTUnwrap(art.image(for: fixture.fighter.animal)?.pngData()), frames[0].pngData())
        let attachment = XCTAttachment(image: frames[2]); attachment.name = "mock_stored_pack_attack_not_generated_art"
        attachment.lifetime = .keepAlways; add(attachment)
    }

    func testOwnersCannotSeeOrInstallIntoEachOthersLibrariesAndLogoutHidesArtwork() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try mockPack(), store = CustomFighterLibraryStore(rootURL: root)
        try store.setOwner(ownerID: owner)
        try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner)
        let art = RetroAssetStore(manifest: nil, library: store)
        XCTAssertNotNil(art.artworkDescriptor(for: fixture.fighter.animal).generatedPack)
        try store.setOwner(ownerID: "diagnostic-owner-B")
        XCTAssertTrue(store.fighters.isEmpty)
        XCTAssertNil(store.pack(for: fixture.fighter.appearance))
        XCTAssertNil(art.artworkDescriptor(for: fixture.fighter.animal).generatedPack)
        XCTAssertThrowsError(try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner))
        try store.setOwner(ownerID: owner)
        XCTAssertEqual(store.fighters, [fixture.fighter])
        XCTAssertNotNil(store.pack(for: fixture.fighter.appearance))
        try store.setOwner(ownerID: nil)
        XCTAssertTrue(store.fighters.isEmpty)
        XCTAssertNil(store.pack(for: fixture.fighter.appearance))
    }

    func testImmutableVersionsAndSameNamedFightersHaveSeparateCaches() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let first = try mockPack()
        let second = try mockPack(assetID: first.manifest.assetID, version: 2, fighterID: first.fighter.id, orange: true)
        let conflicting = try mockPack(assetID: first.manifest.assetID, fighterID: first.fighter.id, orange: true)
        let store = CustomFighterLibraryStore(rootURL: root); try store.setOwner(ownerID: owner)
        let art = RetroAssetStore(manifest: nil, library: store)
        try store.install(manifest: first.manifest, pngData: first.png, fighter: first.fighter, forOwner: owner)
        let pinned = art.artworkDescriptor(for: first.fighter.animal)
        let before = try XCTUnwrap(art.image(for: first.fighter.animal, pose: .attack, artwork: pinned)?.pngData())
        XCTAssertThrowsError(try store.install(manifest: conflicting.manifest, pngData: conflicting.png, fighter: conflicting.fighter, forOwner: owner))
        XCTAssertEqual(store.fighters, [first.fighter])
        try store.install(manifest: second.manifest, pngData: second.png, fighter: second.fighter, forOwner: owner)
        XCTAssertEqual(first.fighter.animal.id, second.fighter.animal.id)
        XCTAssertEqual(first.fighter.name, second.fighter.name)
        XCTAssertNotEqual(pinned.cacheKey, art.artworkDescriptor(for: second.fighter.animal).cacheKey)
        XCTAssertEqual(before, try XCTUnwrap(art.image(for: first.fighter.animal, pose: .attack, artwork: pinned)?.pngData()))
        XCTAssertNotEqual(before, try XCTUnwrap(art.image(for: second.fighter.animal, pose: .attack)?.pngData()))
        XCTAssertNotNil(store.pack(for: first.fighter.appearance), "An immutable version pinned by an older tournament still works.")
    }

    func testHashFailureOrFailedRosterCommitNeverPublishesPartialFighter() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try mockPack(), store = CustomFighterLibraryStore(rootURL: root)
        try store.setOwner(ownerID: owner)
        var damaged = fixture.png; damaged[damaged.count / 2] ^= 1
        XCTAssertThrowsError(try store.install(manifest: fixture.manifest, pngData: damaged, fighter: fixture.fighter, forOwner: owner))
        XCTAssertTrue(store.fighters.isEmpty)
        XCTAssertNil(store.pack(for: fixture.fighter.appearance))
        let ownerRoot = root.appendingPathComponent(digest(Data(owner.utf8)))
        let blockedRoster = ownerRoot.appendingPathComponent("roster.json", isDirectory: true)
        try FileManager.default.createDirectory(at: blockedRoster, withIntermediateDirectories: true)
        XCTAssertThrowsError(try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner))
        XCTAssertTrue(store.fighters.isEmpty)
        XCTAssertNil(store.pack(for: fixture.fighter.appearance))
        try FileManager.default.removeItem(at: blockedRoster)
        try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner)
        XCTAssertEqual(store.fighters.count, 1, "A failed commit must leave a retry usable.")
    }

    func testDuplicateShiftedPosesClippingOpaqueBackgroundAndUnsafeManifestAreRejected() throws {
        for mode in [MockMode.duplicates, .opaque, .clipped] {
            let fixture = try mockPack(mode: mode)
            XCTAssertThrowsError(try CustomFighterLibraryStore.validate(manifest: fixture.manifest, pngData: fixture.png), "\(mode)")
        }
        let fixture = try mockPack()
        let invalid = CustomFighterPackManifest(schemaVersion: 1, assetID: fixture.manifest.assetID, version: 1,
            sha256: fixture.manifest.sha256, styleVersion: "retro-v1", width: Int.max, height: 128,
            archetype: "biped", frames: fixture.manifest.frames)
        XCTAssertThrowsError(try CustomFighterLibraryStore.validate(manifest: invalid, pngData: fixture.png))
        var frames = fixture.manifest.frames; frames["attack"] = frames["idle"]
        let duplicateRect = CustomFighterPackManifest(schemaVersion: 1, assetID: fixture.manifest.assetID, version: 1,
            sha256: fixture.manifest.sha256, styleVersion: "retro-v1", width: 128, height: 128,
            archetype: "biped", frames: frames)
        XCTAssertThrowsError(try CustomFighterLibraryStore.validate(manifest: duplicateRect, pngData: fixture.png))
    }

    func testCorruptOrSymlinkedDiskArtFallsBackWithoutChangingFighterIdentity() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try mockPack(), store = CustomFighterLibraryStore(rootURL: root)
        try store.setOwner(ownerID: owner)
        try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner)
        let pack = try XCTUnwrap(store.pack(for: fixture.fighter.appearance))
        try Data("not a PNG".utf8).write(to: pack.atlasURL)
        let cold = CustomFighterLibraryStore(rootURL: root); try cold.setOwner(ownerID: owner)
        let art = RetroAssetStore(manifest: nil, library: cold)
        XCTAssertNil(cold.pack(for: fixture.fighter.appearance))
        XCTAssertNil(art.artworkDescriptor(for: fixture.fighter.animal).generatedPack)
        XCTAssertNotNil(art.image(for: fixture.fighter.animal), "Bundled fallback survives missing downloaded artwork.")
        XCTAssertEqual(cold.fighters.first?.animal.id, fixture.fighter.animal.id)
        let outside = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: outside) }
        try fixture.png.write(to: outside)
        try FileManager.default.removeItem(at: pack.atlasURL)
        try FileManager.default.createSymbolicLink(at: pack.atlasURL, withDestinationURL: outside)
        XCTAssertNil(cold.pack(for: fixture.fighter.appearance), "A valid image outside the library is still not an installed pack.")
    }

    func testDeletionAndEraseInvalidateRenderedCachesAndRemainDeletedAfterColdLoad() throws {
        let root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try mockPack(), store = CustomFighterLibraryStore(rootURL: root)
        try store.setOwner(ownerID: owner)
        try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner)
        let art = RetroAssetStore(manifest: nil, library: store)
        let generated = try XCTUnwrap(art.image(for: fixture.fighter.animal)?.pngData())
        try store.remove(fighterID: fixture.fighter.id)
        XCTAssertTrue(store.fighters.isEmpty)
        XCTAssertNil(store.pack(for: fixture.fighter.appearance))
        XCTAssertNotEqual(generated, art.image(for: fixture.fighter.animal)?.pngData())
        let cold = CustomFighterLibraryStore(rootURL: root); try cold.setOwner(ownerID: owner)
        XCTAssertTrue(cold.fighters.isEmpty)
        try store.install(manifest: fixture.manifest, pngData: fixture.png, fighter: fixture.fighter, forOwner: owner)
        try store.eraseAllLocalData()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        XCTAssertTrue(store.fighters.isEmpty)
        XCTAssertNil(store.pack(for: fixture.fighter.appearance))
    }

    private enum MockMode { case normal, duplicates, opaque, clipped }
    private struct MockPack { let manifest: CustomFighterPackManifest; let png: Data; let fighter: CustomFighter }

    private func mockPack(assetID: String = UUID().uuidString.lowercased(), version: Int = 1,
                          fighterID: String = UUID().uuidString.lowercased(), orange: Bool = false,
                          mode: MockMode = .normal) throws -> MockPack {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { renderer in
            let c = renderer.cgContext; c.setAllowsAntialiasing(false)
            if mode == .opaque { UIColor.white.setFill(); c.fill(CGRect(x: 0, y: 0, width: 128, height: 128)) }
            for index in 0..<4 {
                c.saveGState()
                c.translateBy(x: CGFloat(index % 2) * 64, y: CGFloat(index / 2) * 64)
                if mode == .duplicates { c.translateBy(x: CGFloat(index), y: CGFloat(index)) }
                (orange ? UIColor.orange : UIColor.systemTeal).setFill()
                c.fill(CGRect(x: 20, y: 22, width: 24, height: 30))
                c.fill(CGRect(x: 25, y: 12, width: 18, height: 18))
                let pose = mode == .duplicates ? 0 : index
                switch pose {
                case 0: c.fill(CGRect(x: 16, y: 28, width: 8, height: 10))
                case 1: c.fill(CGRect(x: 12, y: 34, width: 12, height: 8))
                case 2: c.fill(CGRect(x: 40, y: 23, width: 18, height: 8))
                default: c.fill(CGRect(x: 12, y: 16, width: 12, height: 8))
                }
                if mode == .clipped { c.fill(CGRect(x: 0, y: 28, width: 22, height: 4)) }
                UIColor.black.setFill(); c.fill(CGRect(x: 36, y: 18, width: 3, height: 3))
                c.restoreGState()
            }
        }
        let png = try XCTUnwrap(image.pngData())
        let frames = ["idle": [0, 0, 64, 64], "anticipation": [64, 0, 64, 64],
                      "attack": [0, 64, 64, 64], "reaction": [64, 64, 64, 64]]
        let manifest = CustomFighterPackManifest(schemaVersion: 1, assetID: assetID, version: version,
            sha256: digest(png), styleVersion: "retro-v1", width: 128, height: 128, archetype: "biped", frames: frames)
        return MockPack(manifest: manifest, png: png, fighter: CustomFighter(id: fighterID, name: "Mock Fighter",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000), appearance: manifest.appearance))
    }

    private func alphaBottom(_ image: UIImage) throws -> Int {
        let rgba = try XCTUnwrap(RetroAtlasCache.detachedCopy(of: XCTUnwrap(image.cgImage)))
        let data = try XCTUnwrap(rgba.dataProvider?.data), bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        return (0..<rgba.height).filter { y in (0..<rgba.width).contains { bytes[y * rgba.bytesPerRow + $0 * 4 + 3] > 8 } }.max() ?? -1
    }

    private func temporaryRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("MockCustomFighters-" + UUID().uuidString) }
    private func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
