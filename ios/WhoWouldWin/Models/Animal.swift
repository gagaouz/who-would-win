import Foundation

struct Animal: Identifiable, Hashable, Sendable, Codable {
    let id: String          // snake_case, e.g. "lion"
    let name: String        // Display name, e.g. "Lion"
    let emoji: String       // Single emoji
    let category: AnimalCategory
    let pixelColor: String  // Hex color string, e.g. "#8B4513"
    let size: Int           // 1–5, used for sprite scaling
    let isCustom: Bool      // true for user-typed free-text animals
    let imageURL: URL?      // real photo URL for custom animals (Wikipedia / Pollinations)

    init(id: String, name: String, emoji: String, category: AnimalCategory, pixelColor: String, size: Int, isCustom: Bool = false, imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.pixelColor = pixelColor
        self.size = size
        self.isCustom = isCustom
        self.imageURL = imageURL
    }

    /// Returns the asset catalog name if a custom illustration exists for this animal.
    /// Returns nil for custom (user-typed) animals. All built-in animals return a name;
    /// the call site checks UIImage(named:) != nil before using it.
    var creatureAssetName: String? {
        guard !isCustom else { return nil }
        return "creature_\(id)"
    }
}

enum AnimalCategory: String, CaseIterable, Sendable, Codable {
    case all        = "ALL"
    case land       = "LAND"
    case sea        = "SEA"
    case air        = "AIR"
    case insect     = "BUGS"
    case prehistoric = "DINOS"   // unlocks at 100 battles
    case fantasy    = "FANTASY"  // unlocks at 250 battles
    case mythic     = "MYTHIC"   // unlocks at 500 battles
    case olympus    = "OLYMPUS"  // hidden — cheat code only, resets on app kill
}

// MARK: - AnimalStats

struct AnimalStats {
    let speed: Int    // 0–100
    let power: Int    // 0–100
    let agility: Int  // 0–100
    let defense: Int  // 0–100

    /// Generates environment-adjusted stats. Calls the base generator then applies the
    /// per-category multiplier for the chosen environment.
    static func generate(for animal: Animal, environment: BattleEnvironment) -> AnimalStats {
        let base = generate(for: animal)
        return environment.multiplier(for: animal.category).apply(to: base)
    }

    /// Generates deterministic stats for any animal based on its id + size + category.
    static func generate(for animal: Animal) -> AnimalStats {
        // Deterministic hash from id so the same animal always gets the same stats.
        let h = animal.id.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        func component(_ seed: Int) -> Int { abs((h &+ seed &* 7919) % 41) }  // 0–40

        let sizeBonus = (animal.size - 1) * 9  // 0, 9, 18, 27, 36 for sizes 1–5

        // Gods bypass normal stat generation — all stats land 80–97
        if animal.category == .olympus {
            func godComp(_ seed: Int) -> Int { abs((h &+ seed &* 7919) % 18) } // 0–17
            return AnimalStats(
                speed:   min(97, godComp(1) + 80),
                power:   min(97, godComp(2) + 83),
                agility: min(97, godComp(3) + 79),
                defense: min(97, godComp(4) + 81)
            )
        }

        var spd = 0, pwr = 0, agi = 0, def = 0
        switch animal.category {
        case .air:        spd = 28; agi = 22; pwr = -12; def = -18
        case .sea:        spd = 10; agi =  5; pwr =  10; def =   5
        case .insect:     spd = 12; agi = 18; pwr = -22; def = -12
        case .prehistoric: spd = -8; pwr =  26; def = 18; agi = -12
        case .fantasy:    spd = 10; pwr = 18; agi = 10; def = 10
        case .mythic:     spd = 14; pwr = 24; agi = 14; def = 14
        default: break  // .land, .all
        }

        func clamp(_ v: Int) -> Int { min(97, max(12, v)) }
        return AnimalStats(
            speed:   clamp(component(1) + sizeBonus / 2 + spd + 30),
            power:   clamp(component(2) + sizeBonus     + pwr + 20),
            agility: clamp(component(3) + sizeBonus / 2 + agi + 30),
            defense: clamp(component(4) + sizeBonus     + def + 20)
        )
    }
}
