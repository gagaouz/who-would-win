import Foundation

/// Turns a finished battle into two kid-facing, *jargon-free* pieces of
/// flavor: a "how close was it?" badge and a one-line educational WHY.
///
/// IMPORTANT (see project memory): never leak internal mechanics — no tiers,
/// no stat numbers, no "size 5". Everything here is phrased as plain biology a
/// 6-year-old understands ("much bigger and heavier", "a fierce hunter").
enum BattleInsight {

    // MARK: - How close was it?

    struct Closeness {
        let emoji: String
        let label: String   // short sticker text
        let blurb: String   // one friendly sentence
    }

    /// Derives a closeness badge from the DETERMINISTIC matchup margin (relative
    /// body size), so it always agrees with the WHY line and the pre-fight
    /// telegraph. (It used to read BattleResult.loserHealthPercent, which is a
    /// random 5–25 value — that mislabeled guaranteed stomps as "SO CLOSE!".)
    static func closeness(winner: Animal, loser: Animal) -> Closeness {
        let gap = abs(winner.size - loser.size)
        switch gap {
        case 3...:
            return Closeness(emoji: "💥", label: "BLOWOUT!",
                             blurb: "\(winner.name) barely broke a sweat.")
        case 1...2:
            return Closeness(emoji: "🏆", label: "CLEAR WIN",
                             blurb: "\(winner.name) won fair and square.")
        default: // gap == 0 — genuinely even fight
            return Closeness(emoji: "😅", label: "SO CLOSE!",
                             blurb: "\(loser.name) almost pulled off an upset!")
        }
    }

    // MARK: - Pre-fight telegraph (does NOT reveal the winner)

    struct MatchupPreview {
        let hype: String      // tappable build-up copy
        let isClose: Bool     // true → nail-biter; false → likely lopsided
    }

    /// A spoiler-free read on how even the fight looks, from relative body size
    /// only (so it never hints at *who* wins, just whether it'll be close).
    static func matchupPreview(_ a: Animal, _ b: Animal) -> MatchupPreview {
        let gap = abs(a.size - b.size)
        switch gap {
        case 0:      return MatchupPreview(hype: "Too close to call!", isClose: true)
        case 1:      return MatchupPreview(hype: "Anyone's game!", isClose: true)
        case 2:      return MatchupPreview(hype: "One's got an edge…", isClose: false)
        default:     return MatchupPreview(hype: "A real David vs Goliath!", isClose: false)
        }
    }

    // MARK: - Why did the winner win?

    /// One kid-friendly sentence explaining the deciding factor. Prefers a
    /// SPECIFIC signature reason (the winner's iconic weapon or power) — e.g.
    /// "Medusa's stare turns Wolverine to stone" — because a creature like
    /// Medusa wins by ability, not size. Only when there's no signature does it
    /// fall back to size/diet reasoning (which IS the right lesson for, say,
    /// elephant vs mouse). Never uses game jargon (tiers/stats).
    ///
    /// The cloud backend can also supply an even more specific `why` per battle;
    /// callers should prefer that and use this as the offline/fallback source.
    static func why(winner: Animal, loser: Animal) -> String {
        if let edge = signatureEdge(winner: winner, loser: loser) {
            return edge
        }

        // Custom (user-typed) creatures have no real size/diet data, so the
        // size-based reasoning below would be nonsense ("Biden is bigger and
        // heavier than Trump"). Give a neutral, name-respectful line instead.
        // (The cloud `why` is preferred and far more specific when available.)
        if winner.isCustom || loser.isCustom {
            return "\(winner.name) edged out \(loser.name) when it mattered most."
        }

        let gap = winner.size - loser.size
        let predator = (AnimalFacts.facts(for: winner.id)?.diet == "Carnivore")
        let w = winner.name
        let l = loser.name

        if gap >= 3 {
            return predator
                ? "\(w) is a huge, powerful hunter — far too big for \(l) to handle."
                : "\(w) is so much bigger and heavier that \(l) couldn't keep up."
        } else if gap >= 1 {
            return predator
                ? "\(w) is a bigger, stronger hunter, and that edge beat \(l)."
                : "\(w)'s greater size and weight were too much for \(l)."
        } else if gap == 0 {
            return predator
                ? "Same size, but \(w) is the fiercer hunter — that decided it."
                : "A real toss-up, but \(w) fought just a little harder than \(l)."
        } else {
            // Winner is the SMALLER animal — the upset lesson kids love.
            return "Even though \(w) is smaller, it was quicker and braver than \(l)!"
        }
    }

    /// Iconic, accurate, kid-friendly reason a creature wins by ABILITY rather
    /// than raw size. Covers the gods, myth, and fantasy beasts (where "bigger
    /// and stronger" is wrong or boring) plus a few real/prehistoric animals
    /// with signature weapons. Returns nil → caller uses size/diet reasoning.
    static func signatureEdge(winner: Animal, loser: Animal) -> String? {
        let l = loser.name
        switch winner.id {
        // ── Olympian gods ──
        case "zeus":       return "Zeus hurls lightning bolts \(l) could never dodge."
        case "poseidon":   return "Poseidon commands the seas and storms — \(l) never had a chance."
        case "hades":      return "Hades rules the underworld; his shadow-power overwhelms \(l)."
        case "ares":       return "Ares is the god of war itself — unbeatable against \(l)."
        case "athena":     return "Athena's battle-wisdom outsmarts \(l) at every turn."
        case "apollo":     return "Apollo's blazing sun-arrows strike \(l) from far away."
        case "artemis":    return "Artemis never misses — her hunter's aim finds \(l) instantly."
        case "hermes":     return "Hermes is so lightning-fast that \(l) can't even touch him."
        case "hephaestus": return "Hephaestus forges fire and metal — \(l) can't beat the smith god."
        case "hercules":   return "Hercules has the strength of a god, far too powerful for \(l)."
        case "medusa":     return "Medusa's stare turns \(l) to solid stone!"
        case "kronos":     return "Kronos bends time itself, leaving \(l) helpless."
        // ── Fantasy ──
        case "dragon":     return "The dragon's fiery breath and armored scales overwhelm \(l)."
        case "unicorn":    return "The unicorn's magic horn pierces right through \(l)'s defenses."
        case "griffin":    return "The griffin dives from the sky with talons \(l) can't escape."
        case "kraken":     return "The kraken's giant tentacles drag \(l) down with ease."
        case "minotaur":   return "The minotaur charges with unstoppable bull strength \(l) can't stop."
        case "werewolf":   return "The werewolf's claws and speed are simply too much for \(l)."
        case "hydra":      return "Cut off one head and two grow back — \(l) can't beat the hydra."
        case "phoenix":    return "The phoenix bursts into flame and rises again — \(l) can't keep it down."
        case "kitsune":    return "The kitsune's fox-fire and trickery leave \(l) hopelessly confused."
        case "basilisk":   return "One glance from the basilisk freezes \(l) with deadly fear."
        case "cerberus":   return "Three heads, three sets of jaws — Cerberus surrounds \(l)."
        case "leviathan":  return "The leviathan is a sea-monster the size of a ship; \(l) is tiny beside it."
        // ── Mythic ──
        case "thunderbird":return "The thunderbird summons storms and lightning \(l) can't withstand."
        case "manticore":  return "The manticore's venom stinger-tail jabs \(l) before it can react."
        case "sphinx":     return "The sphinx's riddles and lion strength baffle and overpower \(l)."
        case "chimera":    return "The chimera breathes fire from a lion's body — too fierce for \(l)."
        case "wyvern":     return "The wyvern's venom-tipped tail and wings overwhelm \(l)."
        case "kirin":      return "The kirin's holy, elemental power is far beyond \(l)."
        case "roc":        return "The roc is big enough to carry off elephants — \(l) is easy prey."
        case "baku":       return "The baku devours dreams and fears — \(l) can't fight what it can't see."
        case "nue":        return "The nue's storm magic and shifting shape confuse \(l)."
        case "ammit":      return "Ammit's crocodile jaws and lion strength devour \(l)."
        case "peryton":    return "The peryton's sharp antlers and diving wings strike \(l) hard."
        // ── Real / prehistoric with a signature weapon ──
        case "electric_eel":        return "The electric eel's 600-volt shock stuns \(l) in an instant."
        case "blue_ringed_octopus": return "The blue-ringed octopus carries venom strong enough to drop \(l) fast."
        case "cobra":               return "One venomous cobra bite and \(l) can't go on."
        case "mantis_shrimp":       return "The mantis shrimp punches with the force of a bullet — \(l) feels it."
        case "t_rex":               return "The T-Rex's car-crushing bite is too powerful for \(l) to survive."
        case "ankylosaurus":        return "The ankylosaurus swings its bony club-tail like a wrecking ball at \(l)."
        case "triceratops":         return "The triceratops lowers three sharp horns and charges \(l) like a tank."
        case "megalodon":           return "The megalodon is a shark three times bigger than a great white — \(l) is bite-sized."
        case "electric_ray", "torpedo_ray": return "A jolt of electricity from \(winner.name) leaves \(l) stunned."
        default:
            return nil
        }
    }
}
