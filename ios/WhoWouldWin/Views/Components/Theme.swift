import SwiftUI

// MARK: - App-wide Design System

struct Theme {

    // MARK: Backgrounds
    static let bgDeep    = Color(hex: "#0E0B22")
    static let bgMid     = Color(hex: "#180B32")
    static let bgNavy    = Color(hex: "#0B1528")
    static let bgCard    = Color(hex: "#1E1640")
    static let bgSurface = Color(hex: "#251D4F")

    // MARK: Brand
    static let orange   = Color(hex: "#FF5722")
    static let yellow   = Color(hex: "#FFD60A")
    static let gold     = Color(hex: "#FFD700")
    static let purple   = Color(hex: "#9B5DE5")
    static let cyan     = Color(hex: "#00CFCF")
    static let teal     = Color(hex: "#06D6A0")
    static let red      = Color(hex: "#FF3A5C")
    static let neonGrn  = Color(hex: "#39FF14")

    // MARK: Category accents
    static let landAccent    = Color(hex: "#D4622A")
    static let seaAccent     = Color(hex: "#1B87CC")
    static let airAccent     = Color(hex: "#5DADE2")
    static let insectAccent  = Color(hex: "#38A169")
    static let fantasyAccent = Color(hex: "#C77DFF")

    // MARK: Gradients
    static var mainBg: LinearGradient {
        LinearGradient(
            colors: [bgDeep, bgMid, bgNavy],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var ctaGradient: LinearGradient {
        LinearGradient(colors: [orange, yellow], startPoint: .leading, endPoint: .trailing)
    }

    static var purpleGradient: LinearGradient {
        LinearGradient(colors: [purple, Color(hex: "#C461F5")], startPoint: .leading, endPoint: .trailing)
    }

    static func categoryGradient(_ cat: AnimalCategory) -> LinearGradient {
        switch cat {
        case .land:
            return LinearGradient(
                colors: [Color(hex: "#5C2508"), Color(hex: "#2E1204")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .sea:
            return LinearGradient(
                colors: [Color(hex: "#083870"), Color(hex: "#041B38")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .air:
            return LinearGradient(
                colors: [Color(hex: "#102E65"), Color(hex: "#081630")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .insect:
            return LinearGradient(
                colors: [Color(hex: "#154C15"), Color(hex: "#0A260A")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .fantasy:
            return LinearGradient(
                colors: [Color(hex: "#3B1067"), Color(hex: "#1A0535")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .all:
            return LinearGradient(
                colors: [Color.white.opacity(0.09), Color.white.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    static func categoryAccent(_ cat: AnimalCategory) -> Color {
        switch cat {
        case .land:   return landAccent
        case .sea:    return seaAccent
        case .air:    return airAccent
        case .insect:  return insectAccent
        case .fantasy: return fantasyAccent
        case .all:     return .white.opacity(0.5)
        }
    }

    static func categoryEmoji(_ cat: AnimalCategory) -> String {
        switch cat {
        case .all:    return "🌍"
        case .land:   return "🌿"
        case .sea:    return "🌊"
        case .air:    return "☁️"
        case .insect:  return "🐛"
        case .fantasy: return "✨"
        }
    }

    static func categoryLabel(_ cat: AnimalCategory) -> String {
        switch cat {
        case .all:    return "All"
        case .land:   return "Land"
        case .sea:    return "Sea"
        case .air:    return "Air"
        case .insect:  return "Bugs"
        case .fantasy: return "Fantasy"
        }
    }

    // MARK: Typography helpers
    static func display(_ size: CGFloat) -> Font  { .system(size: size, weight: .black,    design: .rounded) }
    static func headline(_ size: CGFloat) -> Font { .system(size: size, weight: .bold,     design: .rounded) }
    static func bodyFont(_ size: CGFloat) -> Font { .system(size: size, weight: .medium,   design: .rounded) }
    static func labelFont(_ size: CGFloat) -> Font{ .system(size: size, weight: .semibold, design: .rounded) }
}
