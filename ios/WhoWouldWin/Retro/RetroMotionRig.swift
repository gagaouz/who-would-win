import Foundation
import simd

/// Silhouette families, not battle abilities. The rig never reads strength, HP or results.
enum RetroMotionAnatomy: String, CaseIterable {
    case quadruped, biped, bird, swimmer, serpent, arthropod, tentacle, amorphous
}

struct RetroMotionProfile: Equatable {
    let anatomy: RetroMotionAnatomy
    let airborne: Bool
    let authoredPoses: Bool
    let sourceID: String

    init(sourceID: String, archetype: String, authoredPoses: Bool = false) {
        self.sourceID = sourceID
        self.authoredPoses = authoredPoses
        airborne = archetype == "flyer" && sourceID != "ghost"
        if ["giant_squid", "octopus", "blue_ringed_octopus", "kraken"].contains(sourceID) {
            anatomy = .tentacle
        } else if ["slime", "ghost"].contains(sourceID) {
            anatomy = .amorphous
        } else if ["chicken", "rooster", "duck", "goose", "turkey", "dodo"].contains(sourceID) {
            anatomy = .bird
        } else {
            switch archetype {
            case "flyer": anatomy = .bird
            case "swimmer": anatomy = .swimmer
            case "serpentine": anatomy = .serpent
            case "arthropod": anatomy = .arthropod
            case "biped", "primate": anatomy = .biped
            default: anatomy = .quadruped
            }
        }
    }

    @MainActor
    static func resolve(for animal: Animal, manifest: RetroSpriteManifest?) -> Self {
        let id: String
        let sprite: RetroSpriteManifest.Sprite?
        if animal.isCustom {
            switch RetroCustomRecipe.make(name: animal.name).source {
            case .catalog(let source): id = source; sprite = manifest?.sprites[source]
            case .base(let source): id = source; sprite = manifest?.customBases?[source]
            }
        } else {
            id = animal.id; sprite = manifest?.sprites[id]
        }
        return Self(sourceID: id, archetype: sprite?.archetype ?? "quadruped", authoredPoses: hasCompleteAuthoredPoses(sprite))
    }

    /// All four semantic poses need their own valid rectangle. Three action keys
    /// pointing at one non-idle frame must not masquerade as a complete family.
    /// The asset tests additionally verify bounds and actual decoded pixel content.
    static func hasCompleteAuthoredPoses(_ sprite: RetroSpriteManifest.Sprite?) -> Bool {
        guard let sprite else { return false }
        let frames = RetroPose.allCases.compactMap { sprite.frames[$0.rawValue] }
        guard frames.count == RetroPose.allCases.count,
              frames.allSatisfy({ $0.count == 4 && $0[0] >= 0 && $0[1] >= 0 && $0[2] > 0 && $0[3] > 0 }) else { return false }
        return Set(frames).count == RetroPose.allCases.count
    }
}

/// A small anchored mesh for an otherwise single-frame sprite. Frame timing is
/// stepped at 12 fps in the scene, so pixel art moves in readable poses instead
/// of continuously melting. Coordinates are normalized, bottom-left first.
/// Local limb fields have a smooth transition into the unmoving body core.
struct RetroMotionRig {
    static let columns = 6
    static let rows = 6
    static let maximumDisplacement: Float = 0.115
    static let identity: [SIMD2<Float>] = (0...rows).flatMap { row in
        (0...columns).map { column in
            SIMD2(Float(column) / Float(columns), Float(row) / Float(rows))
        }
    }

    enum Moment {
        case idle(Float)
        case action(Float)
        case reaction(Float)
    }

    struct Frame {
        let vertices: [SIMD2<Float>]
        /// Separate rigid-body anticipation complements internal articulation.
        let lift: Float
        let lean: Float
    }

    static func frame(profile: RetroMotionProfile, moment: Moment, reduceMotion: Bool = false) -> Frame {
        guard !reduceMotion, !profile.authoredPoses else {
            return Frame(vertices: identity, lift: 0, lean: 0)
        }
        let windup: Float
        let strike: Float
        let recoil: Float
        let gait: Float
        let wave: Float
        let moving: Float
        switch moment {
        case .idle(let time):
            let safe = time.isFinite ? time : 0
            windup = 0; strike = 0; recoil = 0
            gait = sin(safe * 3.4) * 0.18
            wave = safe * 3.4
            moving = 0.2
        case .action(let value):
            let p = bounded(value)
            windup = smooth(p / 0.24) * (1 - smooth((p - 0.24) / 0.18))
            strike = smooth((p - 0.26) / 0.23) * (1 - smooth((p - 0.60) / 0.40))
            recoil = 0
            moving = smooth(p / 0.12) * (1 - smooth((p - 0.82) / 0.18))
            wave = p * .pi * 6
            gait = sin(wave) * moving
        case .reaction(let value):
            let p = bounded(value)
            recoil = sin(p * .pi)
            windup = 0; strike = 0
            gait = 0; wave = p * .pi * 2; moving = 0
        }

        let vertices = identity.map { point -> SIMD2<Float> in
            let x = point.x, y = point.y
            let feet = 1 - smooth(y / 0.43)
            let upper = smooth((y - 0.32) / 0.55)
            let front = smooth((x - 0.45) / 0.43)
            let rear = 1 - smooth(x / 0.45)
            let edge = smooth(abs(x - 0.5) / 0.45)
            var dx: Float = 0
            var dy: Float = 0
            switch profile.anatomy {
            case .quadruped:
                // Alternate fore/hind steps, a planted ribcage, head thrust and tail flick.
                dx = feet * cos(x * .pi * 2) * gait * 0.090
                dy = feet * max(0, sin(x * .pi * 2 + wave)) * moving * 0.062
                dx += front * upper * (strike * 0.080 - windup * 0.060 - recoil * 0.070)
                dy += upper * (-windup * 0.060 + strike * 0.025)
                dy += rear * smooth((y - 0.38) / 0.45) * gait * 0.040
            case .biped:
                // Opposed feet and an arm-led jab, with a stable central torso/head.
                dx = feet * (x - 0.5) * (windup * 0.12 + strike * 0.08)
                dx += feet * (x < 0.5 ? 1 : -1) * gait * 0.060
                dy = feet * max(0, sin(wave + (x < 0.5 ? 0 : .pi))) * moving * 0.055
                let arms = edge * bell(y, center: 0.46, radius: 0.34)
                dx += arms * (strike * 0.105 - windup * 0.075 - recoil * 0.060)
                dy += arms * (windup * 0.055 + strike * 0.030)
                dx += upper * (strike * 0.028 - windup * 0.026 - recoil * 0.065)
                dy -= upper * windup * 0.045
            case .bird:
                // The wing's outer edge rotates around the shoulder, not the face.
                let wings = (1 - front * 0.85) * smooth((y - 0.25) / 0.60)
                dy = wings * (gait * (1 - windup * 0.85) * 0.100 + windup * 0.090 - strike * 0.100)
                dx = wings * (windup * 0.030 - strike * 0.045)
                dx += front * upper * (strike * 0.045 - recoil * 0.065)
                dy += feet * strike * 0.065
            case .swimmer:
                // Tail beats at the peduncle; head and trunk stay recognizable.
                dy = rear * (gait * (1 - windup * 0.8) * 0.110 + windup * 0.045 - strike * 0.055)
                dx = front * (strike * 0.025 - recoil * 0.055)
                dy += feet * bell(x, center: 0.6, radius: 0.3) * gait * 0.040
            case .serpent:
                // A travelling bend is strongest in the tail and fades at the face.
                dy = (1 - front * 0.88) * sin(wave - x * .pi * 2) * moving * 0.083
                dx = front * upper * (strike * 0.085 - windup * 0.080 - recoil * 0.070)
                dy += front * upper * (windup * 0.070 - strike * 0.030)
            case .arthropod:
                // Fast alternating leg groups below a rigid carapace.
                dx = feet * sin(x * .pi * 6 + wave * 2) * moving * 0.065
                dy = feet * max(0, cos(x * .pi * 6 + wave * 2)) * moving * 0.050
                dx += front * (strike * 0.075 - windup * 0.045 - recoil * 0.060)
                dy += front * upper * windup * 0.035
            case .tentacle:
                // Independent lower arms curl; the upper mantle is anchored.
                let arms = 1 - smooth((y - 0.14) / 0.56)
                dx = arms * sin(x * .pi * 3 + wave) * moving * 0.082
                dy = arms * cos(x * .pi * 3 + wave) * moving * 0.075
                dx += arms * (strike * 0.065 - windup * 0.045)
                dx -= upper * recoil * 0.055
                dy -= upper * windup * 0.025
            case .amorphous:
                // Only soft creatures get squash/stretch; the bottom stays planted.
                let squash = windup * 0.090 - strike * 0.060 + recoil * 0.050
                dx = (x - 0.5) * squash * 1.1
                dy = -y * squash
                dx += upper * (strike * 0.055 - recoil * 0.060)
                dy += bell(x, center: 0.5, radius: 0.5) * y * gait * 0.035
            }
            let bound = maximumDisplacement
            return point + SIMD2(max(-bound, min(bound, dx)), max(-bound, min(bound, dy)))
        }
        let lean: Float
        switch profile.anatomy {
        case .bird: lean = windup * 0.065 - strike * 0.100 + recoil * 0.085
        case .swimmer, .serpent, .tentacle: lean = windup * 0.035 - strike * 0.045 + recoil * 0.055
        case .quadruped, .biped, .arthropod, .amorphous: lean = windup * 0.030 - strike * 0.045 + recoil * 0.065
        }
        return Frame(vertices: vertices, lift: strike * (profile.airborne ? 0.045 : 0.018), lean: lean)
    }

    private static func bounded(_ value: Float) -> Float { value.isFinite ? max(0, min(1, value)) : 0 }
    private static func smooth(_ value: Float) -> Float { let x = bounded(value); return x * x * (3 - 2 * x) }
    private static func bell(_ value: Float, center: Float, radius: Float) -> Float {
        1 - smooth(abs(value - center) / radius)
    }
}
