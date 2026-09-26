import XCTest
import UIKit
@testable import WhoWouldWin

final class RetroAssetTests: XCTestCase {
    @MainActor
    func testEntireCatalogHasFourDifferentAuthoredBundledPoses() throws {
        let store = RetroAssetStore.shared
        XCTAssertEqual(Animals.all.count, 143)
        for animal in Animals.all {
            try autoreleasepool {
                let sprite = try XCTUnwrap(store.manifest?.sprites[animal.id])
                XCTAssertEqual(Set(sprite.frames.keys), Set(RetroPose.allCases.map(\.rawValue)), animal.id)
                XCTAssertTrue(RetroMotionProfile.hasCompleteAuthoredPoses(sprite), "Missing or aliased authored frames: \(animal.id)")
                let frames = try RetroPose.allCases.map { try XCTUnwrap(store.image(for: animal, pose: $0)?.pngData()) }
                XCTAssertEqual(Set(frames).count, 4, "\(animal.id) must have four different rendered images, not duplicated art or idle aliases.")
                XCTAssertTrue(RetroMotionProfile.resolve(for: animal, manifest: store.manifest).authoredPoses,
                              "Shipped creatures must play their authored family without procedural deformation.")
            }
        }
    }

    @MainActor
    func testEveryRegisteredSpriteHasValidRenderableFrames() throws {
        let store = RetroAssetStore.shared
        let manifest = try XCTUnwrap(store.manifest, "Manifest must be packaged in the native app")
        XCTAssertEqual(manifest.styleVersion, RetroAssetStore.styleVersion)
        XCTAssertEqual(Set(manifest.sprites.keys), Set(Animals.all.map(\.id)),
                       "Every shipped catalog creature needs approved bundled sprite art")
        for (animalID, sprite) in manifest.sprites {
            let animal = try XCTUnwrap(Animals.all.first { $0.id == animalID }, "Unknown stable ID: \(animalID)")
            let sheet = try XCTUnwrap(store.atlasImage(named: sprite.asset), "Missing sheet: \(sprite.asset)")
            for pose in RetroPose.allCases {
                let frame = try XCTUnwrap(sprite.frames[pose.rawValue],
                                         "\(animalID) is missing mandatory authored pose \(pose.rawValue)")
                XCTAssertEqual(frame.count, 4)
                guard frame.count == 4 else { continue }
                XCTAssertGreaterThan(frame[2], 0)
                XCTAssertGreaterThan(frame[3], 0)
                XCTAssertGreaterThanOrEqual(frame[0], 0)
                XCTAssertGreaterThanOrEqual(frame[1], 0)
                XCTAssertLessThanOrEqual(frame[0] + frame[2], sheet.width, "Crop extends beyond sheet")
                XCTAssertLessThanOrEqual(frame[1] + frame[3], sheet.height, "Crop extends beyond sheet")
                let cropped = try XCTUnwrap(store.image(for: animal, pose: pose))
                XCTAssertEqual(cropped.cgImage?.width, frame[2])
                XCTAssertEqual(cropped.cgImage?.height, frame[3])
            }
        }
    }

    @MainActor
    func testAtlasLRUEvictsTheLeastRecentlyUsedDecodedSheetWithinItsBudget() throws {
        let sheet = try XCTUnwrap(diagnosticAtlas().cgImage)
        let cost = sheet.bytesPerRow * sheet.height
        var loads: [String: Int] = [:]
        let cache = RetroAtlasCache(costLimit: cost * 2) { name in
            loads[name, default: 0] += 1
            return sheet
        }
        _ = cache.image(named: "A"); _ = cache.image(named: "B")
        _ = cache.image(named: "A") // A is now newest, not the eviction candidate.
        _ = cache.image(named: "C")
        XCTAssertEqual(cache.cachedNames, Set(["A", "C"]))
        XCTAssertEqual(cache.residentCost, cost * 2)
        XCTAssertEqual(loads["A"], 1)
        _ = cache.image(named: "B")
        XCTAssertEqual(loads["B"], 2)
        XCTAssertEqual(cache.cachedNames, Set(["B", "C"]))
        cache.removeAll()
        XCTAssertEqual(cache.residentCost, 0); XCTAssertTrue(cache.cachedNames.isEmpty)

        var oversizedLoads = 0
        let tooSmall = RetroAtlasCache(costLimit: cost - 1) { _ in oversizedLoads += 1; return sheet }
        XCTAssertNotNil(tooSmall.image(named: "oversized"))
        XCTAssertNotNil(tooSmall.image(named: "oversized"))
        XCTAssertEqual(oversizedLoads, 2)
        XCTAssertEqual(tooSmall.residentCost, 0, "A usable oversized sheet must not silently break the retained-byte budget.")
    }

    @MainActor
    func testRawAtlasPrecedesLegacyCatalogAndCorruptionIsNotHidden() throws {
        let original = diagnosticAtlas()
        let source = try XCTUnwrap(original.cgImage)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("diagnostic.png")
        try XCTUnwrap(original.pngData()).write(to: url)
        var legacyLoads = 0
        let decoded = try XCTUnwrap(RetroAtlasCache.load(named: "diagnostic", rawURL: { _ in url }, legacy: { _ in legacyLoads += 1; return source }))
        XCTAssertEqual(canonicalPixels(decoded), canonicalPixels(source), "Uncached ImageIO decoding must preserve pixel orientation, colors and alpha.")
        XCTAssertEqual(legacyLoads, 0)
        try Data("invalid PNG".utf8).write(to: url)
        XCTAssertNil(RetroAtlasCache.load(named: "diagnostic", rawURL: { _ in url }, legacy: { _ in legacyLoads += 1; return source }))
        XCTAssertEqual(legacyLoads, 0, "A corrupt packaged raw sheet must fail validation rather than hide behind stale art.")
        XCTAssertNotNil(RetroAtlasCache.load(named: "legacy", rawURL: { _ in nil }, legacy: { _ in legacyLoads += 1; return source }))
        XCTAssertEqual(legacyLoads, 1)
    }

    @MainActor
    func testDetachedCropsKeepExactPixelsAndOwnOnlyTheirSmallBuffer() throws {
        let atlas = try XCTUnwrap(diagnosticAtlas().cgImage)
        let rect = CGRect(x: 3, y: 1, width: 9, height: 6)
        let expected = try XCTUnwrap(atlas.cropping(to: rect))
        let detached = try XCTUnwrap(RetroAtlasCache.detachedCopy(of: atlas, crop: rect))
        XCTAssertEqual(detached.width, 9); XCTAssertEqual(detached.height, 6)
        XCTAssertEqual(detached.bytesPerRow, detached.width * 4)
        let data = try XCTUnwrap(detached.dataProvider?.data)
        XCTAssertEqual(CFDataGetLength(data), detached.width * detached.height * 4,
                       "A displayed crop must not retain its parent atlas pixel buffer.")
        XCTAssertEqual(canonicalPixels(detached), canonicalPixels(expected), "Asymmetric colors and transparent pixels catch flipped, rescaled or damaged crops.")
    }

    @MainActor
    func testClearingBothCachesReloadsPosesWithoutChangingRetainedImages() throws {
        let source = try XCTUnwrap(diagnosticAtlas().cgImage)
        let frames = Dictionary(uniqueKeysWithValues: RetroPose.allCases.enumerated().map { index, pose in
            (pose.rawValue, [index * 4, 0, 4, 8])
        })
        let sprite = RetroSpriteManifest.Sprite(asset: "injected", archetype: "biped", frames: frames)
        let manifest = RetroSpriteManifest(version: 1, styleVersion: RetroAssetStore.styleVersion, sprites: ["diagnostic": sprite], customBases: nil)
        var loads = 0
        let store = RetroAssetStore(manifest: manifest, atlasLoader: { _ in loads += 1; return source })
        let animal = Animal(id: "diagnostic", name: "Diagnostic", emoji: "", category: .land, pixelColor: "#769BBA", size: 3)
        let images = try RetroPose.allCases.map { try XCTUnwrap(store.image(for: animal, pose: $0)) }
        let pixels = try images.map { canonicalPixels(try XCTUnwrap($0.cgImage)) }
        XCTAssertEqual(loads, 1, "Four crops from one atlas should decode that atlas once.")
        XCTAssertGreaterThan(store.cachedAtlasCost, 0)
        let revision = store.revision
        store.clearMemoryCache()
        XCTAssertEqual(store.cachedAtlasCost, 0)
        XCTAssertEqual(store.revision, revision + 1)
        for (index, pose) in RetroPose.allCases.enumerated() {
            let reloaded = try XCTUnwrap(store.image(for: animal, pose: pose)?.cgImage)
            XCTAssertEqual(pixels[index], canonicalPixels(reloaded))
            XCTAssertEqual(pixels[index], canonicalPixels(try XCTUnwrap(images[index].cgImage)),
                           "Already displayed images must survive both cache eviction and parent erase.")
        }
        XCTAssertEqual(loads, 2)
    }

    @MainActor
    func testMemoryWarningDropsCacheOwnershipWithoutTriggeringArtworkReload() async throws {
        let source = try XCTUnwrap(diagnosticAtlas().cgImage)
        let sprite = RetroSpriteManifest.Sprite(asset: "injected", archetype: "biped", frames: ["idle": [0, 0, 4, 8]])
        let manifest = RetroSpriteManifest(version: 1, styleVersion: RetroAssetStore.styleVersion, sprites: ["diagnostic": sprite], customBases: nil)
        var loads = 0
        let store = RetroAssetStore(manifest: manifest, atlasLoader: { _ in loads += 1; return source })
        let animal = Animal(id: "diagnostic", name: "Diagnostic", emoji: "", category: .land, pixelColor: "#769BBA", size: 3)
        let retained = try XCTUnwrap(store.image(for: animal))
        let pixels = try XCTUnwrap(retained.pngData())
        let revision = store.revision
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        // The notification's main-actor purge is asynchronous; allow that one
        // queued turn to run without driving the scene or requesting new images.
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(store.cachedAtlasCost, 0)
        XCTAssertEqual(store.revision, revision, "Memory pressure must not request scene texture regeneration.")
        XCTAssertEqual(loads, 1)
        XCTAssertEqual(retained.pngData(), pixels)
        XCTAssertEqual(store.image(for: animal)?.pngData(), pixels)
        XCTAssertEqual(loads, 2, "The next explicit request reloads the local sheet.")
    }

    @MainActor
    private func diagnosticAtlas() -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 16, height: 8), format: format).image { renderer in
            renderer.cgContext.setAllowsAntialiasing(false)
            for (index, color) in [UIColor.red, .green, .blue, .yellow].enumerated() {
                color.setFill(); renderer.fill(CGRect(x: index * 4, y: 0, width: 4, height: 8))
            }
            renderer.cgContext.clear(CGRect(x: 4, y: 2, width: 3, height: 3))
            UIColor.magenta.withAlphaComponent(0.5).setFill()
            renderer.fill(CGRect(x: 11, y: 1, width: 2, height: 2))
        }
    }

    private func canonicalPixels(_ image: CGImage) -> Data? {
        guard let context = CGContext(data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let bytes = context.data else { return nil }
        return Data(bytes: bytes, count: image.width * image.height * 4)
    }

    func testCustomArtCacheNormalizesIdentityWithoutCombiningDifferentCreatures() {
        XCTAssertEqual(RetroAssetStore.customCacheKey(for: "  MOSSBACK\n  Dragon  "),
                       RetroAssetStore.customCacheKey(for: "mossback dragon"))
        XCTAssertEqual(RetroAssetStore.customCacheKey(for: "Café dragon"),
                       RetroAssetStore.customCacheKey(for: "Cafe\u{301} dragon"))
        XCTAssertNotEqual(RetroAssetStore.customCacheKey(for: "mossback dragon"),
                          RetroAssetStore.customCacheKey(for: "ice dragon"))
        XCTAssertEqual(RetroAssetStore.customCacheKey(for: "lion").count, 64)
    }

    @MainActor
    func testAllTwelveLocalBasesHaveCompleteAuthoredFramesInBounds() throws {
        let store = RetroAssetStore.shared
        let bases = try XCTUnwrap(store.manifest?.customBases)
        XCTAssertEqual(Set(bases.keys), Set(RetroCustomRecipe.baseIDs))
        for (id, sprite) in bases {
            XCTAssertEqual(Set(sprite.frames.keys), Set(RetroPose.allCases.map(\.rawValue)), id)
            XCTAssertTrue(RetroMotionProfile.hasCompleteAuthoredPoses(sprite), id)
            let sheet = try XCTUnwrap(store.atlasImage(named: sprite.asset), id)
            for pose in RetroPose.allCases {
                let frame = try XCTUnwrap(sprite.frames[pose.rawValue], "\(id): \(pose.rawValue)")
                XCTAssertEqual(frame.count, 4)
                guard frame.count == 4 else { continue }
                XCTAssertGreaterThan(frame[2], 0); XCTAssertGreaterThan(frame[3], 0)
                XCTAssertGreaterThanOrEqual(frame[0], 0); XCTAssertGreaterThanOrEqual(frame[1], 0)
                XCTAssertLessThanOrEqual(frame[0] + frame[2], sheet.width)
                XCTAssertLessThanOrEqual(frame[1] + frame[3], sheet.height)
            }
        }
    }

    func testSpecificAnimalWordsKeepRecognizableAnatomy() {
        XCTAssertEqual(RetroCustomRecipe.make(name: "Blue Great White Shark").source, .catalog("great_white_shark"))
        XCTAssertEqual(RetroCustomRecipe.make(name: "Blue Great White Shark").tint, .blue)
        XCTAssertNil(RetroCustomRecipe.make(name: "Great White Shark").tint,
                     "A natural species name is not a recoloring instruction.")
        XCTAssertEqual(RetroCustomRecipe.make(name: "Komodo Dragon").source, .catalog("komodo_dragon"))
        XCTAssertEqual(RetroCustomRecipe.make(name: "Electric Wolf").source, .catalog("wolf"))
        XCTAssertEqual(RetroCustomRecipe.make(name: "Electric Wolf").ornament, .bolt)
        XCTAssertEqual(RetroCustomRecipe.make(name: "Ice snake").source, .catalog("cobra"))
        XCTAssertTrue(RetroCustomRecipe.make(name: "Caterpillar Supreme").isFantasyAvatar,
                      "cat must be a whole word, not an accidental substring match.")
    }

    func testEveryExplicitFantasyTypeAndCompositeResolvesToItsOwnBase() {
        for id in RetroCustomRecipe.baseIDs {
            XCTAssertEqual(RetroCustomRecipe.make(name: id).source, .base(id), id)
        }
        XCTAssertEqual(RetroCustomRecipe.make(name: "Blue winged cat").source, .base("wingedcat"))
        XCTAssertEqual(RetroCustomRecipe.make(name: "Sea serpent").source, .base("seaserpent"))
        XCTAssertEqual(RetroCustomRecipe.make(name: "Rock golem").source, .base("rockgolem"))
        XCTAssertEqual(RetroCustomRecipe.make(name: "Robot lion").source, .catalog("lion"),
                      "A modifier must not replace a recognizable animal with unrelated anatomy.")
    }

    func testUnknownAvatarRecipeIsStableAcrossUnicodeAndCatalogOrdering() {
        let first = RetroCustomRecipe.make(name: "  CAFÉ\nGlimmerflux  ")
        let second = RetroCustomRecipe.make(name: "Cafe\u{301} Glimmerflux", catalog: Array(Animals.all.reversed()))
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.isFantasyAvatar)
        if case .base(let id) = first.source { XCTAssertTrue(RetroCustomRecipe.baseIDs.contains(id)) }
        else { XCTFail("Unknown descriptions must be presented as fantasy avatars.") }
    }

    @MainActor
    func testCustomArtIsImmediateOfflineAndReproducibleAfterCacheClear() throws {
        let store = RetroAssetStore.shared
        let animal = custom("Glimmerflux", id: "custom_first")
        let first = try XCTUnwrap(store.image(for: animal))
        XCTAssertTrue(first === store.image(for: animal), "Repeated views reuse the bounded memory cache.")
        let pixels = try XCTUnwrap(first.pngData())
        store.clearMemoryCache()
        let rebuilt = try XCTUnwrap(store.image(for: animal))
        XCTAssertEqual(pixels, rebuilt.pngData(), "Local art must survive an offline cache eviction exactly.")
        XCTAssertEqual(rebuilt.size, CGSize(width: 128, height: 128))
        XCTAssertTrue(store.artworkDescription(for: animal).contains("Fantasy avatar"))
    }

    @MainActor
    func testSameNameSharesArtworkWithoutChangingCustomIdentityOrBattleFields() throws {
        let store = RetroAssetStore.shared
        let first = custom("Blue Lion", id: "custom_uuid_a")
        let second = custom(" blue LION ", id: "custom_uuid_b")
        let firstImage = try XCTUnwrap(store.image(for: first))
        XCTAssertTrue(firstImage === store.image(for: second))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.id, "custom_uuid_a")
        XCTAssertEqual(first.name, "Blue Lion")
        XCTAssertEqual(first.category, .fantasy)
        XCTAssertEqual(first.size, 3)
        for pose in RetroPose.allCases {
            XCTAssertTrue(store.image(for: first, pose: pose) === store.image(for: second, pose: pose),
                          "Equivalent names share each pose without merging gameplay identities.")
        }
    }

    @MainActor
    func testCustomCatalogAvatarsRetainAuthoredActionPosesAfterCacheRebuild() throws {
        let store = RetroAssetStore.shared
        let animal = custom("Blue Lion")
        let images = try RetroPose.allCases.map { try XCTUnwrap(store.image(for: animal, pose: $0)) }
        let pixels = try images.map { try XCTUnwrap($0.pngData()) }
        XCTAssertEqual(Set(pixels).count, RetroPose.allCases.count,
                       "Custom artwork must not collapse the lion's four action poses into one idle image.")
        XCTAssertTrue(images.allSatisfy { $0.size == CGSize(width: 128, height: 128) })
        store.clearMemoryCache()
        for (index, pose) in RetroPose.allCases.enumerated() {
            XCTAssertEqual(pixels[index], store.image(for: animal, pose: pose)?.pngData())
        }
        XCTAssertEqual(animal.id, "custom_preview")
    }

    @MainActor
    func testAllLocalCustomBasesKeepFourAuthoredPosesAfterRecolorAndCacheClear() throws {
        let store = RetroAssetStore.shared
        for id in RetroCustomRecipe.baseIDs {
            try autoreleasepool {
                let animal = custom("Blue " + id, id: "custom_authored_" + id)
                XCTAssertEqual(RetroCustomRecipe.make(name: animal.name).source, .base(id))
                let images = try RetroPose.allCases.map { try XCTUnwrap(store.image(for: animal, pose: $0)) }
                let pixels = try images.map { try XCTUnwrap($0.pngData()) }
                XCTAssertEqual(Set(pixels).count, 4, "Custom base \(id) must retain four different authored poses after recoloring.")
                XCTAssertTrue(images.allSatisfy { $0.size == CGSize(width: 128, height: 128) })
                XCTAssertTrue(RetroMotionProfile.resolve(for: animal, manifest: store.manifest).authoredPoses)
                store.clearMemoryCache()
                for (index, pose) in RetroPose.allCases.enumerated() {
                    XCTAssertEqual(pixels[index], store.image(for: animal, pose: pose)?.pngData(), id)
                }
                XCTAssertEqual(animal.id, "custom_authored_" + id)
            }
        }
    }

    @MainActor
    func testLongNamesStillHaveBoundedRenderableLocalArt() throws {
        let name = String(repeating: "extraordinarily ", count: 800) + "Purple Dragon"
        let recipe = RetroCustomRecipe.make(name: name)
        XCTAssertEqual(recipe.source, .catalog("dragon"))
        XCTAssertEqual(recipe.tint, .purple)
        XCTAssertEqual(RetroAssetStore.customCacheKey(for: name).count, 64)
        let image = try XCTUnwrap(RetroAssetStore.shared.image(for: custom(name)))
        XCTAssertEqual(image.cgImage?.width, 128)
        XCTAssertEqual(image.cgImage?.height, 128)
    }

    @MainActor
    func testRepresentativeLocalCustomsProduceReviewableNativeArtwork() throws {
        let names = ["Blue Lion", "Ice Dragon", "Mossback Dragon", "Winged Cat", "Robot", "Wizard", "Glimmerflux", "Purple Sea Serpent"]
        let portraits = try names.map { try XCTUnwrap(RetroAssetStore.shared.image(for: custom($0))) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1024, height: 560), format: format).image { renderer in
            UIColor(red: 0.96, green: 0.93, blue: 0.85, alpha: 1).setFill()
            renderer.fill(CGRect(x: 0, y: 0, width: 1024, height: 560))
            renderer.cgContext.interpolationQuality = .none
            for (index, portrait) in portraits.enumerated() {
                let x = CGFloat(index % 4) * 256, y = CGFloat(index / 4) * 280
                portrait.draw(in: CGRect(x: x + 32, y: y + 16, width: 192, height: 192))
                let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 15, weight: .bold), .foregroundColor: UIColor.darkGray]
                (names[index] as NSString).draw(in: CGRect(x: x + 12, y: y + 220, width: 236, height: 42), withAttributes: attributes)
                if RetroCustomRecipe.make(name: names[index]).isFantasyAvatar {
                    ("FANTASY AVATAR" as NSString).draw(at: CGPoint(x: x + 12, y: y + 246), withAttributes: attributes)
                }
            }
        }
        let attachment = XCTAttachment(image: sheet)
        attachment.name = "retro_local_custom_contact_sheet"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(portraits.allSatisfy { $0.cgImage != nil })
    }

    private func custom(_ name: String, id: String = "custom_preview") -> Animal {
        Animal(id: id, name: name, emoji: "", category: .fantasy, pixelColor: "#7A9F70", size: 3, isCustom: true)
    }
}


/// Payloads below were encoded by the untouched 1.1.7 model source, not by the
/// current decoder. They protect custom entrants and exactly-once settlement.
final class Upgrade117FixtureTests: XCTestCase {
    func testSettledTournamentPreservesCustomEntrantAndPayoutGuard() throws {
        let saved = try JSONDecoder().decode(Tournament.self, from: Legacy117Fixture.settled)
        XCTAssertEqual(saved.schemaVersion, Tournament.currentSchemaVersion)
        XCTAssertEqual(saved.phase, .roundResults(roundIndex: 0))
        XCTAssertTrue(saved.isRoundResolved(0), "Replaying a restored result must not pay the wager twice")
        XCTAssertEqual(saved.bracket.allFighters.count, 4)
        let custom = saved.bracket.rounds[0][0].fighter1
        XCTAssertEqual(custom.id, "custom_legacy_mossback")
        XCTAssertTrue(custom.isCustom)
        XCTAssertEqual(saved.bracket.rounds[0][0].winningFighter?.id, custom.id)
        XCTAssertEqual(saved.bracket.rounds[0][0].wager?.amount, 100)
        XCTAssertEqual(saved.grandChampion?.pickedFighterId, custom.id)
        XCTAssertFalse(saved.grandChampionResolved ?? true)
    }

    func testPendingTournamentResumesWithoutInventingResultsOrSettlement() throws {
        let saved = try JSONDecoder().decode(Tournament.self, from: Legacy117Fixture.pending)
        XCTAssertEqual(saved.phase, .roundBattles(roundIndex: 0, matchupIndex: 0))
        XCTAssertFalse(saved.isRoundResolved(0))
        XCTAssertTrue(saved.bracket.rounds[0].allSatisfy { !$0.isResolved })
        XCTAssertEqual(saved.bracket.rounds[0][0].fighter1.id, "custom_legacy_mossback")
        XCTAssertEqual(saved.bracket.rounds[0][0].wager?.amount, 100)
    }
}

private enum Legacy117Fixture {
    static let settled = Data(base64Encoded: "ewogICJicmFja2V0IiA6IHsKICAgICJyb3VuZHMiIDogWwogICAgICBbCiAgICAgICAgewogICAgICAgICAgImVudmlyb25tZW50IiA6ICJncmFzc2xhbmQiLAogICAgICAgICAgImZpZ2h0ZXIxIiA6IHsKICAgICAgICAgICAgImNhdGVnb3J5IiA6ICJGQU5UQVNZIiwKICAgICAgICAgICAgImVtb2ppIiA6ICLwn5CJIiwKICAgICAgICAgICAgImlkIiA6ICJjdXN0b21fbGVnYWN5X21vc3NiYWNrIiwKICAgICAgICAgICAgImlzQ3VzdG9tIiA6IHRydWUsCiAgICAgICAgICAgICJuYW1lIiA6ICJNb3NzYmFjayBEcmFnb24iLAogICAgICAgICAgICAicGl4ZWxDb2xvciIgOiAiIzRFN0U0NSIsCiAgICAgICAgICAgICJzaXplIiA6IDUKICAgICAgICAgIH0sCiAgICAgICAgICAiZmlnaHRlcjIiIDogewogICAgICAgICAgICAiY2F0ZWdvcnkiIDogIkxBTkQiLAogICAgICAgICAgICAiZW1vamkiIDogIvCfpoEiLAogICAgICAgICAgICAiaWQiIDogImxpb24iLAogICAgICAgICAgICAiaXNDdXN0b20iIDogZmFsc2UsCiAgICAgICAgICAgICJuYW1lIiA6ICJMaW9uIiwKICAgICAgICAgICAgInBpeGVsQ29sb3IiIDogIiNENEEwMTciLAogICAgICAgICAgICAic2l6ZSIgOiA0CiAgICAgICAgICB9LAogICAgICAgICAgImlkIiA6ICIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDEiLAogICAgICAgICAgInJlc3VsdCIgOiB7CiAgICAgICAgICAgICJmdW5GYWN0IiA6ICJEcmFnb25zIGFyZSBpbWFnaW5hcnkuIiwKICAgICAgICAgICAgImxvc2VySGVhbHRoUGVyY2VudCIgOiAxNCwKICAgICAgICAgICAgIm5hcnJhdGlvbiIgOiAiQSBzYXZlZCAxLjEuNyBzdG9yeS4iLAogICAgICAgICAgICAid2lubmVyIiA6ICJjdXN0b21fbGVnYWN5X21vc3NiYWNrIiwKICAgICAgICAgICAgIndpbm5lckhlYWx0aFBlcmNlbnQiIDogNzIKICAgICAgICAgIH0sCiAgICAgICAgICAid2FnZXIiIDogewogICAgICAgICAgICAiYW1vdW50IiA6IDEwMCwKICAgICAgICAgICAgInBpY2tlZEZpZ2h0ZXJJZCIgOiAiY3VzdG9tX2xlZ2FjeV9tb3NzYmFjayIKICAgICAgICAgIH0KICAgICAgICB9LAogICAgICAgIHsKICAgICAgICAgICJlbnZpcm9ubWVudCIgOiAiZ3Jhc3NsYW5kIiwKICAgICAgICAgICJmaWdodGVyMSIgOiB7CiAgICAgICAgICAgICJjYXRlZ29yeSIgOiAiTEFORCIsCiAgICAgICAgICAgICJlbW9qaSIgOiAi8J+mjSIsCiAgICAgICAgICAgICJpZCIgOiAiZ29yaWxsYSIsCiAgICAgICAgICAgICJpc0N1c3RvbSIgOiBmYWxzZSwKICAgICAgICAgICAgIm5hbWUiIDogIkdvcmlsbGEiLAogICAgICAgICAgICAicGl4ZWxDb2xvciIgOiAiIzJGMkYyRiIsCiAgICAgICAgICAgICJzaXplIiA6IDQKICAgICAgICAgIH0sCiAgICAgICAgICAiZmlnaHRlcjIiIDogewogICAgICAgICAgICAiY2F0ZWdvcnkiIDogIkxBTkQiLAogICAgICAgICAgICAiZW1vamkiIDogIvCfkK8iLAogICAgICAgICAgICAiaWQiIDogInRpZ2VyIiwKICAgICAgICAgICAgImlzQ3VzdG9tIiA6IGZhbHNlLAogICAgICAgICAgICAibmFtZSIgOiAiVGlnZXIiLAogICAgICAgICAgICAicGl4ZWxDb2xvciIgOiAiI0ZGNkIwMCIsCiAgICAgICAgICAgICJzaXplIiA6IDQKICAgICAgICAgIH0sCiAgICAgICAgICAiaWQiIDogIjAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMyIsCiAgICAgICAgICAicmVzdWx0IiA6IHsKICAgICAgICAgICAgImZ1bkZhY3QiIDogIlRpZ2VycyBhcmUgY2F0cy4iLAogICAgICAgICAgICAibG9zZXJIZWFsdGhQZXJjZW50IiA6IDE1LAogICAgICAgICAgICAibmFycmF0aW9uIiA6ICJBbm90aGVyIHNhdmVkIHN0b3J5LiIsCiAgICAgICAgICAgICJ3aW5uZXIiIDogInRpZ2VyIiwKICAgICAgICAgICAgIndpbm5lckhlYWx0aFBlcmNlbnQiIDogNjgKICAgICAgICAgIH0KICAgICAgICB9CiAgICAgIF0sCiAgICAgIFsKCiAgICAgIF0KICAgIF0KICB9LAogICJjcmVhdGVkQXQiIDogODExNjkyODAwLAogICJncmFuZENoYW1waW9uIiA6IHsKICAgICJhbW91bnQiIDogMTAwLAogICAgImxvY2tlZEF0Um91bmRJbmRleCIgOiAwLAogICAgIm11bHRpcGxpZXIiIDogNSwKICAgICJwaWNrZWRGaWdodGVySWQiIDogImN1c3RvbV9sZWdhY3lfbW9zc2JhY2siCiAgfSwKICAiZ3JhbmRDaGFtcGlvblJlc29sdmVkIiA6IGZhbHNlLAogICJpZCIgOiAiMDAwMDAwMDAtMDAwMC0wMDAwLTAwMDAtMDAwMDAwMDAwMDAyIiwKICAibGVkZ2VyIiA6IFsKCiAgXSwKICAicGhhc2UiIDogewogICAgInJvdW5kUmVzdWx0cyIgOiB7CiAgICAgICJyb3VuZEluZGV4IiA6IDAKICAgIH0KICB9LAogICJyZXJvbGxVc2VkIiA6IGZhbHNlLAogICJyZXNvbHZlZFJvdW5kcyIgOiBbCiAgICAwCiAgXSwKICAic2NoZW1hVmVyc2lvbiIgOiAxLAogICJzZWxlY3Rpb25Nb2RlIiA6ICJtYW51YWwiLAogICJzaXplIiA6IDQKfQ==")!
    static let pending = Data(base64Encoded: "ewogICJicmFja2V0IiA6IHsKICAgICJyb3VuZHMiIDogWwogICAgICBbCiAgICAgICAgewogICAgICAgICAgImVudmlyb25tZW50IiA6ICJncmFzc2xhbmQiLAogICAgICAgICAgImZpZ2h0ZXIxIiA6IHsKICAgICAgICAgICAgImNhdGVnb3J5IiA6ICJGQU5UQVNZIiwKICAgICAgICAgICAgImVtb2ppIiA6ICLwn5CJIiwKICAgICAgICAgICAgImlkIiA6ICJjdXN0b21fbGVnYWN5X21vc3NiYWNrIiwKICAgICAgICAgICAgImlzQ3VzdG9tIiA6IHRydWUsCiAgICAgICAgICAgICJuYW1lIiA6ICJNb3NzYmFjayBEcmFnb24iLAogICAgICAgICAgICAicGl4ZWxDb2xvciIgOiAiIzRFN0U0NSIsCiAgICAgICAgICAgICJzaXplIiA6IDUKICAgICAgICAgIH0sCiAgICAgICAgICAiZmlnaHRlcjIiIDogewogICAgICAgICAgICAiY2F0ZWdvcnkiIDogIkxBTkQiLAogICAgICAgICAgICAiZW1vamkiIDogIvCfpoEiLAogICAgICAgICAgICAiaWQiIDogImxpb24iLAogICAgICAgICAgICAiaXNDdXN0b20iIDogZmFsc2UsCiAgICAgICAgICAgICJuYW1lIiA6ICJMaW9uIiwKICAgICAgICAgICAgInBpeGVsQ29sb3IiIDogIiNENEEwMTciLAogICAgICAgICAgICAic2l6ZSIgOiA0CiAgICAgICAgICB9LAogICAgICAgICAgImlkIiA6ICIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDEiLAogICAgICAgICAgIndhZ2VyIiA6IHsKICAgICAgICAgICAgImFtb3VudCIgOiAxMDAsCiAgICAgICAgICAgICJwaWNrZWRGaWdodGVySWQiIDogImN1c3RvbV9sZWdhY3lfbW9zc2JhY2siCiAgICAgICAgICB9CiAgICAgICAgfSwKICAgICAgICB7CiAgICAgICAgICAiZW52aXJvbm1lbnQiIDogImdyYXNzbGFuZCIsCiAgICAgICAgICAiZmlnaHRlcjEiIDogewogICAgICAgICAgICAiY2F0ZWdvcnkiIDogIkxBTkQiLAogICAgICAgICAgICAiZW1vamkiIDogIvCfpo0iLAogICAgICAgICAgICAiaWQiIDogImdvcmlsbGEiLAogICAgICAgICAgICAiaXNDdXN0b20iIDogZmFsc2UsCiAgICAgICAgICAgICJuYW1lIiA6ICJHb3JpbGxhIiwKICAgICAgICAgICAgInBpeGVsQ29sb3IiIDogIiMyRjJGMkYiLAogICAgICAgICAgICAic2l6ZSIgOiA0CiAgICAgICAgICB9LAogICAgICAgICAgImZpZ2h0ZXIyIiA6IHsKICAgICAgICAgICAgImNhdGVnb3J5IiA6ICJMQU5EIiwKICAgICAgICAgICAgImVtb2ppIiA6ICLwn5CvIiwKICAgICAgICAgICAgImlkIiA6ICJ0aWdlciIsCiAgICAgICAgICAgICJpc0N1c3RvbSIgOiBmYWxzZSwKICAgICAgICAgICAgIm5hbWUiIDogIlRpZ2VyIiwKICAgICAgICAgICAgInBpeGVsQ29sb3IiIDogIiNGRjZCMDAiLAogICAgICAgICAgICAic2l6ZSIgOiA0CiAgICAgICAgICB9LAogICAgICAgICAgImlkIiA6ICIwMDAwMDAwMC0wMDAwLTAwMDAtMDAwMC0wMDAwMDAwMDAwMDMiCiAgICAgICAgfQogICAgICBdLAogICAgICBbCgogICAgICBdCiAgICBdCiAgfSwKICAiY3JlYXRlZEF0IiA6IDgxMTY5MjgwMCwKICAiZ3JhbmRDaGFtcGlvbiIgOiB7CiAgICAiYW1vdW50IiA6IDEwMCwKICAgICJsb2NrZWRBdFJvdW5kSW5kZXgiIDogMCwKICAgICJtdWx0aXBsaWVyIiA6IDUsCiAgICAicGlja2VkRmlnaHRlcklkIiA6ICJjdXN0b21fbGVnYWN5X21vc3NiYWNrIgogIH0sCiAgImdyYW5kQ2hhbXBpb25SZXNvbHZlZCIgOiBmYWxzZSwKICAiaWQiIDogIjAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMiIsCiAgImxlZGdlciIgOiBbCgogIF0sCiAgInBoYXNlIiA6IHsKICAgICJyb3VuZEJhdHRsZXMiIDogewogICAgICAibWF0Y2h1cEluZGV4IiA6IDAsCiAgICAgICJyb3VuZEluZGV4IiA6IDAKICAgIH0KICB9LAogICJyZXJvbGxVc2VkIiA6IGZhbHNlLAogICJyZXNvbHZlZFJvdW5kcyIgOiBbCgogIF0sCiAgInNjaGVtYVZlcnNpb24iIDogMSwKICAic2VsZWN0aW9uTW9kZSIgOiAibWFudWFsIiwKICAic2l6ZSIgOiA0Cn0=")!
}
