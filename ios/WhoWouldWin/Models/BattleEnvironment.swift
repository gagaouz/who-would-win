import SwiftUI

// MARK: - BattleEnvironment

enum BattleEnvironment: String, CaseIterable, Codable, Identifiable {
    // Free always
    case grassland
    case ocean
    case sky
    // Earned at battle milestones (or via Environments Pack)
    case arctic
    case desert
    // Premium (Environments Pack or watch ad for 1 try)
    case jungle
    case volcano
    case night
    case storm

    var id: String { rawValue }

    // MARK: - Display

    var name: String {
        switch self {
        case .grassland: return "Grassland"
        case .ocean:     return "Ocean"
        case .sky:       return "Sky"
        case .arctic:    return "Arctic"
        case .desert:    return "Desert"
        case .jungle:    return "Jungle"
        case .volcano:   return "Volcano"
        case .night:     return "Night"
        case .storm:     return "Storm"
        }
    }

    var emoji: String {
        switch self {
        case .grassland: return "🌿"
        case .ocean:     return "🌊"
        case .sky:       return "☁️"
        case .arctic:    return "❄️"
        case .desert:    return "🏜️"
        case .jungle:    return "🌴"
        case .volcano:   return "🌋"
        case .night:     return "🌙"
        case .storm:     return "⚡"
        }
    }

    var tagline: String {
        switch self {
        case .grassland: return "Open plains — no advantage"
        case .ocean:     return "Sea creatures dominate"
        case .sky:       return "Aerial animals take flight"
        case .arctic:    return "Cold-adapted fighters shine"
        case .desert:    return "Speed & stamina rule"
        case .jungle:    return "Agility wins close quarters"
        case .volcano:   return "Raw power in the heat"
        case .night:     return "Mythic hunters emerge"
        case .storm:     return "Fast & fierce survive"
        }
    }

    // MARK: - Tier & Unlock

    enum Tier { case free, earned, premium }

    var tier: Tier {
        switch self {
        case .grassland, .ocean, .sky: return .free
        case .arctic, .desert:         return .earned
        case .jungle, .volcano, .night, .storm: return .premium
        }
    }

    /// Battle count required to unlock earned-tier environments for free.
    /// nil = always available (free tier) or premium-only.
    var battleThreshold: Int? {
        switch self {
        case .arctic:  return 75
        case .desert:  return 150
        default:       return nil
        }
    }

    // MARK: - Theme Colors (for SpriteKit background and UI accents)

    /// Sky gradient top color
    var bgTop: Color {
        switch self {
        case .grassland: return Color(hex: "#0E0B22")
        case .ocean:     return Color(hex: "#050f1f")
        case .sky:       return Color(hex: "#0a1a3a")
        case .arctic:    return Color(hex: "#0a1928")
        case .desert:    return Color(hex: "#1e0e04")
        case .jungle:    return Color(hex: "#051408")
        case .volcano:   return Color(hex: "#1a0404")
        case .night:     return Color(hex: "#020208")
        case .storm:     return Color(hex: "#060d18")
        }
    }

    /// Gradient bottom color
    var bgBottom: Color {
        switch self {
        case .grassland: return Color(hex: "#1C1640")
        case .ocean:     return Color(hex: "#082040")
        case .sky:       return Color(hex: "#1a3060")
        case .arctic:    return Color(hex: "#12283a")
        case .desert:    return Color(hex: "#3a1e08")
        case .jungle:    return Color(hex: "#0d2b12")
        case .volcano:   return Color(hex: "#3a0808")
        case .night:     return Color(hex: "#0a0a20")
        case .storm:     return Color(hex: "#0d1e30")
        }
    }

    /// Accent color for pills, borders, glows
    var accentColor: Color {
        switch self {
        case .grassland: return Color(hex: "#6ECC6E")
        case .ocean:     return Color(hex: "#2196F3")
        case .sky:       return Color(hex: "#64B5F6")
        case .arctic:    return Color(hex: "#90CAF9")
        case .desert:    return Color(hex: "#FFB347")
        case .jungle:    return Color(hex: "#4CAF50")
        case .volcano:   return Color(hex: "#FF5722")
        case .night:     return Color(hex: "#9C27B0")
        case .storm:     return Color(hex: "#FDD835")
        }
    }

    // MARK: - Stat Multipliers

    /// Returns the stat multiplier for an animal category in this environment.
    func multiplier(for category: AnimalCategory) -> EnvironmentMultiplier {
        switch self {
        case .grassland:
            return .neutral

        case .ocean:
            switch category {
            case .sea:         return EnvironmentMultiplier(speed: 1.30, power: 1.15, agility: 1.20, defense: 1.10)
            case .land:        return EnvironmentMultiplier(speed: 0.60, power: 0.80, agility: 0.55, defense: 0.85)
            case .air:         return EnvironmentMultiplier(speed: 0.50, power: 0.55, agility: 0.40, defense: 0.75)
            case .insect:      return EnvironmentMultiplier(speed: 0.70, power: 0.80, agility: 0.60, defense: 0.80)
            case .prehistoric: return EnvironmentMultiplier(speed: 0.85, power: 1.05, agility: 0.80, defense: 1.00)
            case .fantasy:     return EnvironmentMultiplier(speed: 0.90, power: 0.90, agility: 0.90, defense: 0.90)
            case .mythic:      return EnvironmentMultiplier(speed: 0.95, power: 0.95, agility: 0.95, defense: 0.95)
            case .olympus:     return EnvironmentMultiplier(speed: 0.90, power: 1.05, agility: 0.90, defense: 1.00)
            case .all:         return .neutral
            }

        case .sky:
            switch category {
            case .air:         return EnvironmentMultiplier(speed: 1.40, power: 1.10, agility: 1.35, defense: 0.90)
            case .land:        return EnvironmentMultiplier(speed: 0.70, power: 0.85, agility: 0.50, defense: 0.85)
            case .sea:         return EnvironmentMultiplier(speed: 0.30, power: 0.50, agility: 0.25, defense: 0.65)
            case .insect:      return EnvironmentMultiplier(speed: 1.10, power: 0.90, agility: 1.20, defense: 0.85)
            case .prehistoric: return EnvironmentMultiplier(speed: 0.80, power: 1.00, agility: 0.75, defense: 0.90)
            case .fantasy:     return EnvironmentMultiplier(speed: 1.10, power: 1.10, agility: 1.10, defense: 1.00) // dragons fly
            case .mythic:      return EnvironmentMultiplier(speed: 1.05, power: 1.05, agility: 1.05, defense: 1.00)
            case .olympus:     return EnvironmentMultiplier(speed: 1.15, power: 1.10, agility: 1.15, defense: 1.00)
            case .all:         return .neutral
            }

        case .arctic:
            switch category {
            case .sea:         return EnvironmentMultiplier(speed: 1.10, power: 1.05, agility: 1.10, defense: 1.20)
            case .land:        return EnvironmentMultiplier(speed: 0.85, power: 0.95, agility: 0.85, defense: 1.10)
            case .air:         return EnvironmentMultiplier(speed: 0.75, power: 0.80, agility: 0.70, defense: 0.80)
            case .insect:      return EnvironmentMultiplier(speed: 0.40, power: 0.50, agility: 0.40, defense: 0.50)
            case .prehistoric: return EnvironmentMultiplier(speed: 0.90, power: 1.10, agility: 0.85, defense: 1.20) // mammoths
            case .fantasy:     return EnvironmentMultiplier(speed: 0.90, power: 0.95, agility: 0.90, defense: 1.00)
            case .mythic:      return EnvironmentMultiplier(speed: 0.95, power: 1.00, agility: 0.95, defense: 1.05)
            case .olympus:     return .neutral
            case .all:         return .neutral
            }

        case .desert:
            switch category {
            case .land:        return EnvironmentMultiplier(speed: 1.15, power: 1.00, agility: 1.10, defense: 0.90)
            case .sea:         return EnvironmentMultiplier(speed: 0.25, power: 0.50, agility: 0.20, defense: 0.65)
            case .air:         return EnvironmentMultiplier(speed: 1.10, power: 0.95, agility: 1.10, defense: 0.85)
            case .insect:      return EnvironmentMultiplier(speed: 1.20, power: 1.10, agility: 1.20, defense: 1.00) // scorpions rule
            case .prehistoric: return EnvironmentMultiplier(speed: 0.90, power: 1.05, agility: 0.85, defense: 1.00)
            case .fantasy:     return EnvironmentMultiplier(speed: 0.95, power: 0.95, agility: 0.95, defense: 0.95)
            case .mythic:      return EnvironmentMultiplier(speed: 1.00, power: 1.05, agility: 1.00, defense: 1.00)
            case .olympus:     return EnvironmentMultiplier(speed: 1.05, power: 1.05, agility: 1.05, defense: 1.00)
            case .all:         return .neutral
            }

        case .jungle:
            switch category {
            case .land:        return EnvironmentMultiplier(speed: 0.90, power: 1.05, agility: 1.20, defense: 0.90)
            case .sea:         return EnvironmentMultiplier(speed: 0.70, power: 0.75, agility: 0.65, defense: 0.80)
            case .air:         return EnvironmentMultiplier(speed: 0.80, power: 0.90, agility: 0.85, defense: 0.90)
            case .insect:      return EnvironmentMultiplier(speed: 1.00, power: 1.15, agility: 1.10, defense: 1.00)
            case .prehistoric: return EnvironmentMultiplier(speed: 0.85, power: 1.10, agility: 0.90, defense: 1.00)
            case .fantasy:     return EnvironmentMultiplier(speed: 1.10, power: 1.10, agility: 1.10, defense: 1.00)
            case .mythic:      return EnvironmentMultiplier(speed: 1.05, power: 1.10, agility: 1.10, defense: 1.00)
            case .olympus:     return EnvironmentMultiplier(speed: 1.00, power: 1.05, agility: 1.00, defense: 1.00)
            case .all:         return .neutral
            }

        case .volcano:
            switch category {
            case .land:        return EnvironmentMultiplier(speed: 0.80, power: 1.20, agility: 0.75, defense: 0.90)
            case .sea:         return EnvironmentMultiplier(speed: 0.40, power: 0.50, agility: 0.35, defense: 0.60)
            case .air:         return EnvironmentMultiplier(speed: 0.75, power: 0.85, agility: 0.70, defense: 0.80)
            case .insect:      return EnvironmentMultiplier(speed: 0.50, power: 0.60, agility: 0.50, defense: 0.55)
            case .prehistoric: return EnvironmentMultiplier(speed: 1.00, power: 1.30, agility: 0.90, defense: 1.20) // ancient heat-resistance
            case .fantasy:     return EnvironmentMultiplier(speed: 1.10, power: 1.25, agility: 1.00, defense: 1.10) // dragons!
            case .mythic:      return EnvironmentMultiplier(speed: 1.05, power: 1.20, agility: 1.00, defense: 1.10)
            case .olympus:     return EnvironmentMultiplier(speed: 1.00, power: 1.15, agility: 1.00, defense: 1.00)
            case .all:         return .neutral
            }

        case .night:
            switch category {
            case .land:        return EnvironmentMultiplier(speed: 0.90, power: 0.95, agility: 1.00, defense: 0.90)
            case .sea:         return EnvironmentMultiplier(speed: 0.90, power: 0.95, agility: 0.90, defense: 0.90)
            case .air:         return EnvironmentMultiplier(speed: 1.00, power: 1.05, agility: 1.10, defense: 0.95) // owls, bats
            case .insect:      return EnvironmentMultiplier(speed: 1.20, power: 1.10, agility: 1.20, defense: 1.00) // nocturnal insects
            case .prehistoric: return EnvironmentMultiplier(speed: 0.90, power: 1.00, agility: 0.90, defense: 0.95)
            case .fantasy:     return EnvironmentMultiplier(speed: 1.15, power: 1.20, agility: 1.15, defense: 1.10) // dark creatures
            case .mythic:      return EnvironmentMultiplier(speed: 1.20, power: 1.25, agility: 1.20, defense: 1.10) // mythic beings thrive at night
            case .olympus:     return EnvironmentMultiplier(speed: 1.10, power: 1.10, agility: 1.10, defense: 1.00)
            case .all:         return .neutral
            }

        case .storm:
            switch category {
            case .land:        return EnvironmentMultiplier(speed: 0.75, power: 0.90, agility: 0.70, defense: 0.85)
            case .sea:         return EnvironmentMultiplier(speed: 1.20, power: 1.15, agility: 1.10, defense: 0.90) // sea creatures ride storms
            case .air:         return EnvironmentMultiplier(speed: 1.25, power: 1.05, agility: 1.20, defense: 0.80) // eagles in wind
            case .insect:      return EnvironmentMultiplier(speed: 0.40, power: 0.50, agility: 0.40, defense: 0.50) // blown away
            case .prehistoric: return EnvironmentMultiplier(speed: 0.80, power: 1.05, agility: 0.75, defense: 0.95)
            case .fantasy:     return EnvironmentMultiplier(speed: 1.10, power: 1.15, agility: 1.05, defense: 1.00)
            case .mythic:      return EnvironmentMultiplier(speed: 1.10, power: 1.15, agility: 1.10, defense: 1.05)
            case .olympus:     return EnvironmentMultiplier(speed: 1.15, power: 1.20, agility: 1.15, defense: 1.05) // Zeus's domain
            case .all:         return .neutral
            }
        }
    }
}

// MARK: - EnvironmentMultiplier

struct EnvironmentMultiplier {
    let speed: Double
    let power: Double
    let agility: Double
    let defense: Double

    static let neutral = EnvironmentMultiplier(speed: 1.0, power: 1.0, agility: 1.0, defense: 1.0)

    func apply(to stats: AnimalStats) -> AnimalStats {
        AnimalStats(
            speed:   clamp(Int(Double(stats.speed)   * speed)),
            power:   clamp(Int(Double(stats.power)   * power)),
            agility: clamp(Int(Double(stats.agility) * agility)),
            defense: clamp(Int(Double(stats.defense) * defense))
        )
    }

    private func clamp(_ v: Int) -> Int { min(99, max(1, v)) }
}
