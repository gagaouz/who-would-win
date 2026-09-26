import XCTest
import SpriteKit
import simd
@testable import WhoWouldWin

final class RetroMotionRigTests: XCTestCase {
    private let examples: [(String, String, RetroMotionAnatomy)] = [
        ("cheetah", "quadruped", .quadruped), ("robot", "biped", .biped),
        ("barn_owl", "flyer", .bird), ("barracuda", "swimmer", .swimmer),
        ("electric_eel", "serpentine", .serpent), ("scorpion", "arthropod", .arthropod),
        ("octopus", "swimmer", .tentacle), ("slime", "biped", .amorphous)
    ]

    func testDistinctAnatomiesHaveReadableAnticipationStrikeAndRecoil() {
        var silhouettes = Set<String>()
        for (id, archetype, expected) in examples {
            let profile = RetroMotionProfile(sourceID: id, archetype: archetype)
            XCTAssertEqual(profile.anatomy, expected)
            let windup = RetroMotionRig.frame(profile: profile, moment: .action(0.24))
            let attack = RetroMotionRig.frame(profile: profile, moment: .action(0.50))
            let recoil = RetroMotionRig.frame(profile: profile, moment: .reaction(0.50))
            func difference(_ first: [SIMD2<Float>], _ second: [SIMD2<Float>]) -> Float {
                zip(first, second).map { simd_length($0 - $1) }.max() ?? 0
            }
            XCTAssertGreaterThan(difference(windup.vertices, attack.vertices), 0.045, "\(id) needs an internal silhouette change, not only translation.")
            XCTAssertGreaterThan(difference(recoil.vertices, RetroMotionRig.identity), 0.035, "\(id) needs a visible internal recoil.")
            let settled = RetroMotionRig.frame(profile: profile, moment: .action(1))
            XCTAssertEqual(settled.vertices, RetroMotionRig.identity, "Recovery must return to the original anatomy.")
            silhouettes.insert(attack.vertices.map { "\($0.x),\($0.y)" }.joined(separator: ";"))
        }
        XCTAssertEqual(silhouettes.count, RetroMotionAnatomy.allCases.count)
    }

    func testEveryGridStaysFiniteBoundedAndNeverFoldsAcrossCompleteCycles() {
        for (id, archetype, _) in examples {
            let profile = RetroMotionProfile(sourceID: id, archetype: archetype)
            for step in 0...120 {
                let p = Float(step) / 120
                for moment in [RetroMotionRig.Moment.action(p), .reaction(p), .idle(p * 8)] {
                    let frame = RetroMotionRig.frame(profile: profile, moment: moment)
                    XCTAssertTrue(frame.lift.isFinite && frame.lean.isFinite)
                    for (source, target) in zip(RetroMotionRig.identity, frame.vertices) {
                        XCTAssertTrue(target.x.isFinite && target.y.isFinite)
                        XCTAssertLessThanOrEqual(abs(target.x - source.x), RetroMotionRig.maximumDisplacement + 0.00001)
                        XCTAssertLessThanOrEqual(abs(target.y - source.y), RetroMotionRig.maximumDisplacement + 0.00001)
                    }
                    // Both triangles of every cell must retain their winding. A
                    // positive area rules out inverted limbs/tears from mesh folds.
                    for y in 0..<RetroMotionRig.rows {
                        for x in 0..<RetroMotionRig.columns {
                            let i = y * (RetroMotionRig.columns + 1) + x
                            let a = frame.vertices[i], b = frame.vertices[i + 1]
                            let c = frame.vertices[i + RetroMotionRig.columns + 1]
                            let d = frame.vertices[i + RetroMotionRig.columns + 2]
                            func cross(_ u: SIMD2<Float>, _ v: SIMD2<Float>) -> Float { u.x * v.y - u.y * v.x }
                            XCTAssertGreaterThan(cross(b - a, c - a), 0.001, "Folded \(id) at \(p).")
                            XCTAssertGreaterThan(cross(d - b, c - b), 0.001, "Folded \(id) at \(p).")
                        }
                    }
                }
            }
        }
    }

    func testReducedMotionAndAuthoredArtAreNeverDeformed() {
        for (id, archetype, _) in examples {
            let profile = RetroMotionProfile(sourceID: id, archetype: archetype)
            for p: Float in [0, 0.25, 0.5, 0.75, 1] {
                let reduced = RetroMotionRig.frame(profile: profile, moment: .action(p), reduceMotion: true)
                XCTAssertEqual(reduced.vertices, RetroMotionRig.identity)
                XCTAssertEqual(reduced.lift, 0); XCTAssertEqual(reduced.lean, 0)
                let authored = RetroMotionProfile(sourceID: id, archetype: archetype, authoredPoses: true)
                XCTAssertEqual(RetroMotionRig.frame(profile: authored, moment: .action(p)).vertices, RetroMotionRig.identity)
            }
            for invalid: Float in [.nan, .infinity, -.infinity] {
                let frame = RetroMotionRig.frame(profile: profile, moment: .action(invalid))
                XCTAssertTrue(frame.vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite })
            }
        }
    }

    @MainActor
    func testAllCatalogAndCustomSourcesResolveToTheirActualAnatomy() {
        let manifest = RetroAssetStore.shared.manifest!
        XCTAssertEqual(Animals.all.count, 143)
        for animal in Animals.all {
            let profile = RetroMotionProfile.resolve(for: animal, manifest: manifest)
            XCTAssertEqual(profile.sourceID, animal.id)
            let sprite = manifest.sprites[animal.id]!
            let expected = RetroMotionProfile(sourceID: animal.id, archetype: sprite.archetype)
            XCTAssertEqual(profile.anatomy, expected.anatomy)
            let idle = sprite.frames["idle"]!
            XCTAssertEqual(profile.authoredPoses, ["anticipation", "attack", "reaction"].allSatisfy { sprite.frames[$0] != nil && sprite.frames[$0] != idle })
        }
        XCTAssertEqual(RetroMotionProfile.resolve(for: custom("Blue Lion"), manifest: manifest).authoredPoses, true)
        XCTAssertEqual(RetroMotionProfile.resolve(for: custom("Ice Octopus"), manifest: manifest).anatomy, .tentacle)
        for source in RetroCustomRecipe.baseIDs {
            let animal = custom(source)
            let profile = RetroMotionProfile.resolve(for: animal, manifest: manifest)
            XCTAssertEqual(profile.sourceID, source)
            XCTAssertEqual(profile.anatomy, RetroMotionProfile(sourceID: source, archetype: manifest.customBases![source]!.archetype).anatomy)
        }
        XCTAssertFalse(RetroMotionProfile(sourceID: "chicken", archetype: "biped").airborne)
    }

#if DEBUG
    @MainActor
    func testProductionSceneAppliesInternalMotionAndClearsItForReducedMotion() {
        let view = SKView(frame: .zero)
        let cheetah = Animals.all.first { $0.id == "cheetah" }!
        let scene = RetroBattleScene(sessionID: UUID(), teamA: [cheetah], teamB: [custom("Slime")], environment: .grassland)
        scene.didMove(to: view)
        scene.accept(.draw)
        scene.renderDiagnostic(elapsed: 0.25)
        let nodes = scene.children.flatMap { $0.children }.compactMap { $0 as? SKSpriteNode }
        let meshes = nodes.compactMap { $0.warpGeometry as? SKWarpGeometryGrid }
        XCTAssertEqual(meshes.count, 2, "Both single-frame participants must receive internal articulation.")
        XCTAssertTrue(meshes.allSatisfy { $0.vertexCount == RetroMotionRig.identity.count })
        scene.reduceMotion = true
        scene.renderDiagnostic(elapsed: 0.3)
        XCTAssertTrue(nodes.allSatisfy { $0.warpGeometry == nil }, "Changing accessibility settings must clear an already active warp.")
        scene.stop()

        let authored = RetroBattleScene(sessionID: UUID(), teamA: [Animals.lion], teamB: [custom("Blue Lion")], environment: .grassland)
        authored.didMove(to: view)
        authored.accept(.draw)
        authored.renderDiagnostic(elapsed: 0.4)
        let authoredNodes = authored.children.flatMap { $0.children }.compactMap { $0 as? SKSpriteNode }
        XCTAssertTrue(authoredNodes.allSatisfy { $0.warpGeometry == nil }, "Both catalog and custom authored families retain their artist's poses.")
        authored.stop()
    }

    @MainActor
    func testProductionSceneMotionContactSheets() throws {
        let rows = [
            ("cheetah", "horse"), ("robot", "knight"), ("barn_owl", "crow"),
            ("barracuda", "swordfish"), ("electric_eel", "hydra"), ("scorpion", "centipede"),
            ("octopus", "kraken"), ("slime", "ghost"), ("tiger", "great_white_shark"),
            ("bald_eagle", "cobra")
        ]
        // Capture the exact SpriteKit scene at ready / windup / advance / contact /
        // recovery / settle, including authored frame selection and facing flips.
        let moments: [Double] = [0, 0.23, 0.40, 0.54, 0.75, 1.01]
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 480, height: 280))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        for group in 0..<2 {
            let subset = Array(rows[(group * 5)..<(group * 5 + 5)])
            var snapshots: [[UIImage]] = []
            for pair in subset {
                let left = Animals.all.first { $0.id == pair.0 } ?? custom(pair.0)
                let right = Animals.all.first { $0.id == pair.1 } ?? custom(pair.1)
                let scene = RetroBattleScene(sessionID: UUID(), teamA: [left], teamB: [right], environment: .grassland)
                scene.didMove(to: view)
                scene.accept(.victory(side: 0, mvpID: left.id))
                var frames: [UIImage] = []
                for time in moments {
                    scene.renderDiagnostic(elapsed: time)
                    let texture = try XCTUnwrap(view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)))
                    frames.append(UIImage(cgImage: texture.cgImage()))
                }
                scene.stop()
                snapshots.append(frames)
            }
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: 1440, height: 850), format: format).image { context in
                UIColor(white: 0.96, alpha: 1).setFill(); context.fill(CGRect(x: 0, y: 0, width: 1440, height: 850))
                for (row, frames) in snapshots.enumerated() {
                    for (column, image) in frames.enumerated() {
                        let origin = CGPoint(x: CGFloat(column * 240), y: CGFloat(row * 170))
                        image.draw(in: CGRect(x: origin.x, y: origin.y + 25, width: 240, height: 140))
                        let label = "\(subset[row].0)  t=\(moments[column])"
                        (label as NSString).draw(at: CGPoint(x: origin.x + 5, y: origin.y + 5), withAttributes: [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black])
                    }
                }
            }
            let attachment = XCTAttachment(image: sheet)
            attachment.name = "retro-motion-contact-sheet-\(group + 1)"; attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertFalse(snapshots.isEmpty)
        }
    }
#endif

    private func custom(_ name: String) -> Animal {
        Animal(id: "custom_motion_\(name)", name: name, emoji: "", category: .fantasy, pixelColor: "#769BBA", size: 3, isCustom: true)
    }
}
