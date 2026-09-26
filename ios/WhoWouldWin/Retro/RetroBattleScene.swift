import SpriteKit
import UIKit

/// A visual performance of an already accepted outcome. No health simulation,
/// random winner selection, network requests or persistence live in this scene.
@MainActor
final class RetroBattleScene: SKScene {
    private struct Performer {
        let animal: Animal
        let side: Int
        let slot: Int
        let sprite: SKSpriteNode
        let shadow: SKSpriteNode
        let home: CGPoint
        let extent: CGFloat
        let profile: RetroMotionProfile
    }
    private struct RigKey: Hashable {
        let anatomy: RetroMotionAnatomy
        let airborne: Bool
        let kind: Int
        let frame: Int
    }
    private struct RigPose {
        let geometry: SKWarpGeometryGrid
        let lift: CGFloat
        let lean: CGFloat
    }
    // Quantized poses are shared by every creature with the same anatomy.
    // At most 8 families × (24 idle + 13 action + 13 reaction) small grids.
    private var rigPoses: [RigKey: RigPose] = [:]

    let sessionID: UUID
    private let teams: [[Animal]]
    private let arena: BattleEnvironment
    private var performers: [Performer] = []
    private var textures: [String: [RetroPose: SKTexture]] = [:]
    private let actionLayer = SKNode()
    private let effectLayer = SKNode()
    private var clock = RetroPresentationClock()
    private var ambientClock = RetroPresentationClock()
    private var outcome: RetroBattleOutcome?
    private var completed = false
    private var stopped = false
    private var lastImpact = -1
    private var built = false
    private var pendingArtworkRefresh = false
    var reduceMotion = false
    var active = true {
        didSet {
            isPaused = !active
            if !active { clock.pause(); ambientClock.pause() }
        }
    }
    var onFinished: (() -> Void)?
    var onCaption: ((String) -> Void)?
    private var lastCaption = ""

    init(sessionID: UUID, teamA: [Animal], teamB: [Animal], environment: BattleEnvironment) {
        self.sessionID = sessionID
        self.teams = [Array(teamA.prefix(4)), Array(teamB.prefix(4))]
        self.arena = environment
        super.init(size: CGSize(width: 480, height: 280))
        scaleMode = .aspectFit
        backgroundColor = RetroArenaArtwork.rgb(0xf0e3b8)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        guard !built else { return }
        built = true
        let texture = SKTexture(image: RetroArenaArtwork.image(for: arena))
        texture.filteringMode = .nearest
        let background = SKSpriteNode(texture: texture, size: size)
        background.position = CGPoint(x: 240, y: 140)
        background.zPosition = -100
        addChild(background)
        addChild(actionLayer)
        effectLayer.zPosition = 100
        addChild(effectLayer)
        preparePerformers()
    }

    func accept(_ value: RetroBattleOutcome?) {
        guard outcome == nil, let value else { return }
        outcome = value
        clock.reset()
        lastImpact = -1
        caption("The challengers make their move!")
    }

    func skip() {
        guard outcome != nil else { return }
        finish()
    }

    func refreshArtwork() { pendingArtworkRefresh = true }

    func stop() {
        stopped = true
        active = false
        onFinished = nil
        onCaption = nil
        removeAllActions()
        effectLayer.removeAllChildren()
    }

    private func preparePerformers() {
        for side in 0...1 {
            let count = teams[side].count
            for (slot, animal) in teams[side].enumerated() {
                let multiple = count > 1
                let row = multiple ? slot / 2 : 0
                let column = multiple ? slot % 2 : 0
                let x: CGFloat = multiple ? (side == 0 ? 70 + CGFloat(column) * 73 : 410 - CGFloat(column) * 73) : (side == 0 ? 123 : 357)
                let y: CGFloat = 56 + CGFloat(row) * 55
                let extent: CGFloat = multiple ? 71 : 112
                let shadow = SKSpriteNode(color: RetroArenaArtwork.rgb(0x3e5e46), size: CGSize(width: extent * 0.58, height: 5))
                shadow.alpha = 0.55
                shadow.position = CGPoint(x: x, y: y)
                shadow.zPosition = CGFloat(5 - row)
                actionLayer.addChild(shadow)
                let sprite = SKSpriteNode()
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
                sprite.position = CGPoint(x: x, y: y + 1)
                sprite.xScale = side == 0 ? 1 : -1
                sprite.zPosition = CGFloat(20 - row * 5 + slot)
                actionLayer.addChild(sprite)
                let performer = Performer(animal: animal, side: side, slot: slot, sprite: sprite, shadow: shadow, home: CGPoint(x: x, y: y + 1), extent: extent, profile: RetroMotionProfile.resolve(for: animal, manifest: RetroAssetStore.shared.manifest))
                performers.append(performer)
                installTextures(for: animal)
                pose(.idle, for: performer)
            }
        }
    }

    private func installTextures(for animal: Animal) {
        guard textures[animal.id] == nil else { return }
        var frames: [RetroPose: SKTexture] = [:]
        for pose in RetroPose.allCases {
            if let image = RetroAssetStore.shared.image(for: animal, pose: pose) {
                let texture = SKTexture(image: image)
                texture.filteringMode = .nearest
                frames[pose] = texture
            }
        }
        if frames.isEmpty {
            let texture = SKTexture(image: placeholder(for: animal))
            texture.filteringMode = .nearest
            frames[.idle] = texture
        }
        textures[animal.id] = frames
    }

    private func placeholder(for animal: Animal) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { renderer in
            let c = renderer.cgContext
            c.setAllowsAntialiasing(false)
            c.setFillColor(RetroArenaArtwork.rgb(0x6e8560).cgColor)
            for rect in [CGRect(x: 9, y: 28, width: 37, height: 23), CGRect(x: 33, y: 16, width: 23, height: 27), CGRect(x: 11, y: 49, width: 9, height: 11), CGRect(x: 39, y: 48, width: 9, height: 12)] { c.fill(rect) }
            c.setFillColor(RetroArenaArtwork.rgb(0xf4e2ac).cgColor)
            c.fill(CGRect(x: 47, y: 23, width: 3, height: 3))
        }
    }

    private func pose(_ pose: RetroPose, for performer: Performer) {
        guard let texture = textures[performer.animal.id]?[pose] ?? textures[performer.animal.id]?[.idle] else { return }
        if performer.sprite.texture !== texture {
            performer.sprite.texture = texture
            let source = texture.size()
            let idle = textures[performer.animal.id]?[.idle]?.size() ?? source
            let scale = performer.extent / max(idle.width, idle.height, 1)
            performer.sprite.size = CGSize(width: (source.width * scale).rounded(), height: (source.height * scale).rounded())
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard active, built, !completed else { return }
        let ambient = ambientClock.tick(currentTime, active: active)
        let t = outcome == nil ? 0 : clock.tick(currentTime, active: active)
        render(elapsed: t, ambient: ambient)
    }

#if DEBUG
    /// Deterministic snapshots exercise the production renderer without waiting
    /// for wall-clock animation. This entry point is absent from Release builds.
    func renderDiagnostic(elapsed: TimeInterval, ambient: TimeInterval = 0) {
        guard built, !stopped else { return }
        render(elapsed: max(0, elapsed), ambient: max(0, ambient))
    }
#endif

    private func render(elapsed t: TimeInterval, ambient: TimeInterval) {
        if pendingArtworkRefresh && (outcome == nil || t < 0.25 || t.truncatingRemainder(dividingBy: 1.04) > 0.95) {
            pendingArtworkRefresh = false
            textures.removeAll()
            for performer in performers { installTextures(for: performer.animal) }
        }
        effectLayer.removeAllChildren()
        actionLayer.position = .zero
        for performer in performers {
            performer.sprite.position = performer.home
            performer.shadow.position = CGPoint(x: performer.home.x, y: performer.home.y - 1)
            performer.sprite.xScale = performer.side == 0 ? 1 : -1
            performer.sprite.yScale = 1
            performer.sprite.zRotation = 0
            performer.sprite.alpha = 1
            performer.sprite.zPosition = CGFloat(20 - (performer.slot / 2) * 5 + performer.slot)
            pose(.idle, for: performer)
            applyRig(to: performer, kind: 0, progress: ambient + Double(performer.slot) * 0.23)
            if !reduceMotion {
                if performer.profile.airborne {
                    performer.sprite.position.y += 7 + CGFloat(sin(ambient * 3 + Double(performer.slot))) * 3
                } else if [.swimmer, .tentacle].contains(performer.profile.anatomy) {
                    performer.sprite.position.y += 3 + CGFloat(sin(ambient * 2)) * 2
                }
            }
        }
        guard let outcome else { return }
        if reduceMotion {
            caption("The result is ready.")
            if t >= 0.45 { finish() }
            return
        }
        // Every roster slot gets a turn before the accepted MVP's flourish.
        let exchangeCount = max(5, max(teams[0].count, teams[1].count) * 2 + 1)
        let celebrationStart = Double(exchangeCount) * 1.04
        if t < celebrationStart {
            let beat = min(exchangeCount - 1, Int(t / 1.04))
            let local = (t - Double(beat) * 1.04) / 1.04
            let side = beat == exchangeCount - 1 ? (outcome.winningSide ?? 0) : beat % 2
            let roster = performers.filter { $0.side == side }
            let opponents = performers.filter { $0.side != side }
            guard !roster.isEmpty, !opponents.isEmpty else { finish(); return }
            var actor = roster[(beat / 2) % roster.count]
            if beat == exchangeCount - 1, case .victory(_, let mvp) = outcome,
               let featured = roster.first(where: { $0.animal.id == mvp }) { actor = featured }
            let target = opponents[(beat / 2) % opponents.count]
            exchange(actor: actor, target: target, progress: local, beat: beat)
        } else {
            for performer in performers {
                if let side = outcome.winningSide {
                    if performer.side == side {
                        performer.sprite.position.y += CGFloat(abs(sin((t - celebrationStart) * 5))) * 9
                        stars(around: performer.sprite.position, time: t, count: teams[side].count > 2 ? 3 : 6)
                    } else {
                        pose(.reaction, for: performer)
                        applyRig(to: performer, kind: 2, progress: 0.42)
                        performer.sprite.yScale = 0.98
                    }
                }
            }
            caption(outcome.winningSide == nil ? "An evenly matched finish!" : "What a finish!")
            if t >= celebrationStart + 1.45 { finish() }
        }
    }

    private func exchange(actor: Performer, target: Performer, progress p: Double, beat: Int) {
        let direction: CGFloat = actor.side == 0 ? 1 : -1
        actor.sprite.zPosition = 40
        let distance = max(0, abs(target.home.x - actor.home.x) - (actor.extent + target.extent) * 0.45)
        let advance: CGFloat
        if p < 0.28 {
            pose(.anticipation, for: actor)
            advance = -CGFloat(p / 0.28) * 6
        } else if p < 0.56 {
            pose(.attack, for: actor)
            let fraction = min(1, (p - 0.28) / 0.23)
            advance = distance * CGFloat(fraction * fraction * (3 - 2 * fraction))
        } else {
            let fraction = min(1, (p - 0.56) / 0.44)
            advance = distance * CGFloat(1 - fraction * fraction * (3 - 2 * fraction))
        }
        applyRig(to: actor, kind: 1, progress: p)
        actor.sprite.position.x += direction * advance
        actor.sprite.position.y += (target.home.y - actor.home.y) * (distance > 0 ? advance / distance : 0)
        actor.shadow.position.x = actor.sprite.position.x
        actor.shadow.position.y += (target.home.y - actor.home.y) * (distance > 0 ? advance / distance : 0)
        if p > 0.28 && p < 0.56 {
            let stride = CGFloat(sin((p - 0.28) / 0.28 * .pi))
            switch actor.profile.anatomy {
            case .quadruped, .biped, .amorphous: actor.sprite.position.y += stride * 5
            case .bird:
                actor.sprite.position.y += stride * (actor.profile.airborne ? 16 : 7)
                actor.sprite.zRotation -= direction * stride * 0.09
            case .swimmer, .tentacle:
                actor.sprite.position.y += stride * 3
                actor.sprite.zRotation += direction * stride * 0.045
            case .serpent:
                actor.sprite.zRotation += direction * CGFloat(sin(p * 26)) * 0.025
            case .arthropod:
                actor.sprite.position.y += CGFloat(abs(sin(p * 72))).rounded() * 2
            }
        }
        if p > 0.49 && p < 0.83 {
            pose(.reaction, for: target)
            applyRig(to: target, kind: 2, progress: (p - 0.49) / 0.34)
            target.sprite.position.x += direction * CGFloat(sin((p - 0.49) / 0.34 * .pi)) * 7
            let contact = CGPoint(x: target.sprite.position.x - direction * target.extent * 0.3, y: target.sprite.position.y + target.sprite.size.height * 0.55)
            impact(at: contact, progress: (p - 0.49) / 0.34)
            if lastImpact != beat {
                lastImpact = beat
                SoundService.shared.play(.whoosh, volume: 0.4)
                HapticsService.shared.tap()
                caption("\(actor.animal.name) makes a move!")
            }
            if p > 0.53 && p < 0.64 { actionLayer.position.x = CGFloat(sin(p * 150)).rounded() }
        }
        if p > 0.28 && p < 0.68 {
            let color: UInt32 = arena == .ocean ? 0xadd7cd : arena == .arctic ? 0xe8eed8 : 0xdcc18c
            for i in 0..<4 {
                pixel(x: actor.sprite.position.x - direction * CGFloat(25 + i * 7), y: actor.home.y + CGFloat(i % 2) * 3, width: 5, height: 3, color: color, alpha: CGFloat(0.7 - p * 0.6))
            }
        }
    }

    private func pixel(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, color: UInt32, alpha: CGFloat = 1) {
        let node = SKSpriteNode(color: RetroArenaArtwork.rgb(color), size: CGSize(width: width, height: height))
        node.position = CGPoint(x: x.rounded(), y: y.rounded())
        node.alpha = alpha
        effectLayer.addChild(node)
    }

    private func impact(at point: CGPoint, progress: Double) {
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let distance = CGFloat(6 + progress * 26)
            pixel(x: point.x + CGFloat(cos(angle)) * distance, y: point.y + CGFloat(sin(angle)) * distance, width: i % 2 == 0 ? 5 : 3, height: 3, color: i % 2 == 0 ? 0xffedba : 0xe5b573, alpha: CGFloat(1 - progress))
        }
    }

    private func stars(around point: CGPoint, time: Double, count: Int) {
        for i in 0..<count {
            let angle = Double(i) * .pi * 2 / Double(count) + time * 0.35
            let x = point.x + CGFloat(cos(angle)) * 37
            let y = point.y + 74 + CGFloat(sin(angle)) * 15
            pixel(x: x, y: y, width: 6, height: 2, color: 0xffe5a2)
            pixel(x: x, y: y, width: 2, height: 6, color: 0xffe5a2)
        }
    }

    private func caption(_ value: String) {
        guard value != lastCaption else { return }
        lastCaption = value
        onCaption?(value)
    }

    private func finish() {
        guard outcome != nil, !completed else { return }
        completed = true
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.stopped else { return }
            self.onFinished?()
        }
    }

    private func applyRig(to performer: Performer, kind: Int, progress: Double) {
        guard !reduceMotion, !performer.profile.authoredPoses else {
            performer.sprite.warpGeometry = nil
            return
        }
        let safe = progress.isFinite ? max(0, progress) : 0
        let frame = kind == 0 ? Int(safe.truncatingRemainder(dividingBy: 2) * 12) : min(12, Int(safe * 12))
        let key = RigKey(anatomy: performer.profile.anatomy, airborne: performer.profile.airborne, kind: kind, frame: frame)
        let rig: RigPose
        if let cached = rigPoses[key] {
            rig = cached
        } else {
            let moment: RetroMotionRig.Moment
            switch kind {
            case 1: moment = .action(Float(frame) / 12)
            case 2: moment = .reaction(Float(frame) / 12)
            default: moment = .idle(Float(frame) / 24 * .pi * 2 / 3.4)
            }
            let sample = RetroMotionRig.frame(profile: performer.profile, moment: moment)
            let geometry = SKWarpGeometryGrid(columns: RetroMotionRig.columns, rows: RetroMotionRig.rows,
                                               sourcePositions: RetroMotionRig.identity, destinationPositions: sample.vertices)
            rig = RigPose(geometry: geometry, lift: CGFloat(sample.lift), lean: CGFloat(sample.lean))
            rigPoses[key] = rig
        }
        performer.sprite.warpGeometry = rig.geometry
        // The mesh is already subdivided into 36 cells; extra adaptive subdivision
        // would soften pixel edges and consume GPU work without adding articulation.
        performer.sprite.subdivisionLevels = 0
        performer.sprite.position.y += rig.lift * performer.extent
        performer.sprite.zRotation = rig.lean * (performer.side == 0 ? 1 : -1)
    }
}
