import Foundation

/// Decides battle outcomes ON DEVICE, with zero network calls.
///
/// The local counterpart to the backend's `battleResolver.ts`. Preserves the
/// project invariant — **the resolver decides the winner, the model only
/// narrates** — so on-device (Apple Foundation Models) narration can never
/// invent an absurd upset.
///
/// Scoring is `2^tier × envModifier`, ported verbatim from the backend. An
/// earlier version summed `AnimalStats` (0–100 per category), but that
/// compressed range couldn't express that a lion outweighs an army ant a
/// millionfold — so the random roll occasionally crowned the ant. The tier
/// table (`OnDeviceTiers`) fixes that: lion=6, army_ant=1 → a 32× power gap
/// the sharp curve turns into a near-certain lion win.
enum OnDeviceResolver {

    struct Verdict: Equatable {
        let winner: Animal
        let loser: Animal
        let isDraw: Bool
        /// 0–1 confidence the winner wins, for health-bar shaping.
        let dominance: Double
    }

    /// Environment effectiveness multiplier (0 = can't function, 1 = home turf).
    /// Mirrors the server's `envModifier` in backend/src/data/creatures.ts.
    static func envMod(_ id: String, _ env: BattleEnvironment, arenaEnabled: Bool) -> Double {
        guard arenaEnabled else { return 1.0 }
        if OnDeviceTiers.deities.contains(id) { return 1.0 }
        guard OnDeviceTiers.isBuiltIn(id) else {
            // Custom creature — habitat unknown, so mild neutral values.
            switch env {
            case .ocean: return 0.6
            case .sky: return 0.5
            case .grassland, .jungle, .volcano, .desert, .arctic: return 0.9
            case .night, .storm: return 1.0
            }
        }
        let isSea = OnDeviceTiers.sea.contains(id)
        let isAir = OnDeviceTiers.air.contains(id)
        switch env {
        case .ocean:
            if isSea { return 1.0 }
            if OnDeviceTiers.swimmers.contains(id) { return 0.5 }
            return 0.10                       // can't breathe underwater
        case .sky:
            if isAir || OnDeviceTiers.fliers.contains(id) { return 1.0 }
            return 0.05                       // can't fly
        case .grassland, .jungle, .volcano, .desert, .arctic:
            if isSea { return 0.05 }          // stranded out of water
            if isAir { return 0.85 }
            return 1.0
        case .night, .storm:
            return 1.0                        // generic, no strong preference
        }
    }

    /// `2^(effectiveTier) × envMod`.
    private static func power(_ a: Animal, _ env: BattleEnvironment, arenaEnabled: Bool) -> Double {
        pow(2.0, OnDeviceTiers.effectiveTier(for: a.id)) * envMod(a.id, env, arenaEnabled: arenaEnabled)
    }

    /// DETERMINISTIC: the stronger fighter ALWAYS wins — no dice. A crow never
    /// beats a pterodactyl; a tiger always beats a lion. The narration still
    /// varies run to run (fresh story each time), but the *outcome* is fixed by
    /// realistic power, so the game teaches the right answer.
    ///
    /// `rng` is accepted for signature compatibility but unused (kept so callers
    /// don't change). Order-independent: resolve(a,b) and resolve(b,a) agree.
    static func resolve(_ f1: Animal,
                        _ f2: Animal,
                        environment: BattleEnvironment,
                        arenaEffectsEnabled: Bool,
                        rng: inout SystemRandomNumberGenerator) -> Verdict {
        resolve(f1, f2, environment: environment, arenaEffectsEnabled: arenaEffectsEnabled)
    }

    static func resolve(_ f1: Animal,
                        _ f2: Animal,
                        environment: BattleEnvironment,
                        arenaEffectsEnabled: Bool) -> Verdict {

        // Deity vs mortal — decisive.
        let d1 = OnDeviceTiers.deities.contains(f1.id)
        let d2 = OnDeviceTiers.deities.contains(f2.id)
        if d1 != d2 {
            let w = d1 ? f1 : f2, l = d1 ? f2 : f1
            return Verdict(winner: w, loser: l, isDraw: false, dominance: 0.97)
        }

        let e1 = envMod(f1.id, environment, arenaEnabled: arenaEffectsEnabled)
        let e2 = envMod(f2.id, environment, arenaEnabled: arenaEffectsEnabled)
        // Catastrophic environment — a fighter that can't function loses to one
        // that can, regardless of tier (orca on grassland vs a land animal).
        if e1 <= 0.10 && e2 >= 0.5 { return Verdict(winner: f2, loser: f1, isDraw: false, dominance: 0.95) }
        if e2 <= 0.10 && e1 >= 0.5 { return Verdict(winner: f1, loser: f2, isDraw: false, dominance: 0.95) }

        let p1 = power(f1, environment, arenaEnabled: arenaEffectsEnabled)
        let p2 = power(f2, environment, arenaEnabled: arenaEffectsEnabled)

        // Higher power wins, deterministically. Exact ties break by id — the
        // same rule as the server, so both always name the same winner.
        let f1Wins: Bool
        if p1 != p2 {
            f1Wins = p1 > p2
        } else {
            f1Wins = f1.id < f2.id
        }

        let (winner, loser, pw, pl) = f1Wins ? (f1, f2, p1, p2) : (f2, f1, p2, p1)
        // Dominance reflects how lopsided it is (drives the health bars): a
        // near-tie gives a bruising win, a blowout gives a clean one.
        let dominance = (pw + pl) > 0 ? min(0.99, pw / (pw + pl)) : 0.55
        return Verdict(winner: winner, loser: loser, isDraw: false, dominance: dominance)
    }
}
