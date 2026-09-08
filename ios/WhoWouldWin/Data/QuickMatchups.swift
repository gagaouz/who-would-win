import Foundation

/// A tiny deterministic RNG (LCG) so the Daily Challenge is the SAME matchup all
/// day and across a kid's devices, without storing anything server-side.
struct SeededRNG {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func int(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }
}

/// Builds one-tap matchups for the home screen (Daily Challenge + Surprise Me).
/// Only ever pairs animals the player has actually unlocked.
enum QuickMatchups {

    /// Unlocked, non-custom roster.
    static func pool() -> [Animal] {
        let p = Animals.all.filter { !$0.isCustom && UserSettings.shared.isAvailable($0) }
        return p.count >= 2 ? p : Animals.all.filter { !$0.isCustom }
    }

    /// The full, fixed non-custom roster — stable ordering that never shifts with
    /// unlock state. The Daily Challenge seeds off THIS (not the unlock-filtered
    /// `pool()`) so the same calendar day always yields the same matchup even if
    /// the kid unlocks a pack mid-day. It also means the daily can occasionally
    /// feature a not-yet-unlocked creature — a free taste of premium content.
    static func fullRoster() -> [Animal] {
        Animals.all.filter { !$0.isCustom }
    }

    /// Deterministic daily pairing seeded by the day stamp — stable for 24h,
    /// independent of what the kid has unlocked.
    static func daily(stamp: Int) -> (Animal, Animal) {
        let p = fullRoster()
        guard p.count >= 2 else { return fallback() }
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(stamp)))
        let i = rng.int(p.count)
        var j = rng.int(p.count)
        if j == i { j = (j + 1) % p.count }
        return (p[i], p[j])
    }

    /// A random fresh matchup. Biases toward animals the kid has seen win less
    /// often, so "Surprise Me" tends to surface under-used creatures.
    static func surprise() -> (Animal, Animal) {
        let p = pool()
        guard p.count >= 2 else { return fallback() }
        let settings = UserSettings.shared
        // Weight: animals with fewer recorded wins are likelier to appear.
        func pick() -> Animal {
            let maxWins = (p.map { settings.wins(for: $0.id) }.max() ?? 0) + 1
            // Two draws, keep the less-seen one — cheap "fresh" bias.
            let a = p.randomElement()!
            let b = p.randomElement()!
            return (maxWins - settings.wins(for: a.id)) >= (maxWins - settings.wins(for: b.id)) ? a : b
        }
        let first = pick()
        var second = pick()
        var guardCount = 0
        while second.id == first.id && guardCount < 12 { second = p.randomElement()!; guardCount += 1 }
        return (first, second)
    }

    /// A random unlocked opponent that isn't the given animal (king-of-the-hill).
    static func opponent(excluding animal: Animal) -> Animal {
        let p = pool().filter { $0.id != animal.id }
        return p.randomElement()
            ?? Animals.all.first { $0.id != animal.id && !$0.isCustom }
            ?? animal
    }

    private static func fallback() -> (Animal, Animal) {
        let all = Animals.all.filter { !$0.isCustom }
        return (all.first ?? Animals.all[0], all.dropFirst().first ?? Animals.all[1])
    }
}
