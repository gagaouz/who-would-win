import SwiftUI

// MARK: - App-wide Design System

struct Theme {

    // MARK: Adaptive Backgrounds
    // Bright, vibrant backgrounds — sky blues and greens in dark, lighter pastels in light.

    static var bgDeep: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.918, green: 0.953, blue: 1.000, alpha: 1)  // #EAF3FF
                : UIColor(red: 0.102, green: 0.137, blue: 0.494, alpha: 1)  // #1A237E
        })
    }
    static var bgMid: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.871, green: 0.945, blue: 1.000, alpha: 1)  // #DEF1FF
                : UIColor(red: 0.051, green: 0.278, blue: 0.631, alpha: 1)  // #0D47A1
        })
    }
    static var bgNavy: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.878, green: 0.965, blue: 0.886, alpha: 1)  // #E0F6E2
                : UIColor(red: 0.082, green: 0.396, blue: 0.753, alpha: 1)  // #1565C0
        })
    }
    static var bgCard: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? .white
                : UIColor.white.withAlphaComponent(0.10)
        })
    }
    static var bgSurface: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.941, green: 0.969, blue: 1.000, alpha: 1)  // #F0F7FF
                : UIColor.white.withAlphaComponent(0.08)
        })
    }

    // MARK: Adaptive Text

    /// Primary text — white in dark mode, deep blue in light mode.
    static var textPrimary: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.102, green: 0.137, blue: 0.494, alpha: 1)  // #1A237E
                : .white
        })
    }
    /// Secondary text
    static var textSecondary: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.259, green: 0.310, blue: 0.569, alpha: 0.85)
                : UIColor.white.withAlphaComponent(0.60)
        })
    }
    /// Tertiary / placeholder text
    static var textTertiary: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.36, green: 0.40, blue: 0.60, alpha: 0.60)
                : UIColor.white.withAlphaComponent(0.35)
        })
    }

    // MARK: Adaptive Surfaces

    /// Card / cell fill — frosted glass style
    static var cardFill: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor.white.withAlphaComponent(0.88)
                : UIColor.white.withAlphaComponent(0.12)
        })
    }
    /// Card border
    static var cardBorder: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 0.40)
                : UIColor.white.withAlphaComponent(0.20)
        })
    }
    /// Divider
    static var divider: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 0.25)
                : UIColor.white.withAlphaComponent(0.10)
        })
    }

    // MARK: Brand (same on both themes — work on any background)
    static let orange   = Color(hex: "#FF9800")
    static let yellow   = Color(hex: "#FFEB3B")
    static let gold     = Color(hex: "#FDD835")
    static let purple   = Color(hex: "#BA68C8")
    static let cyan     = Color(hex: "#00E5FF")
    static let teal     = Color(hex: "#26A69A")
    static let red      = Color(hex: "#F44336")
    static let neonGrn  = Color(hex: "#69F0AE")
    static let blue     = Color(hex: "#42A5F5")

    // MARK: Supercell-style 3D button colors
    static let btnOrangeTop    = Color(hex: "#FFB74D")
    static let btnOrangeMid    = Color(hex: "#FF9800")
    static let btnOrangeBot    = Color(hex: "#F57C00")
    static let btnOrangeShadow = Color(hex: "#E65100")

    static let btnGreenTop     = Color(hex: "#69F0AE")
    static let btnGreenMid     = Color(hex: "#4CAF50")
    static let btnGreenBot     = Color(hex: "#388E3C")
    static let btnGreenShadow  = Color(hex: "#1B5E20")

    static let btnPurpleTop    = Color(hex: "#E1BEE7")
    static let btnPurpleMid    = Color(hex: "#BA68C8")
    static let btnPurpleBot    = Color(hex: "#9C27B0")
    static let btnPurpleShadow = Color(hex: "#6A1B9A")

    static let btnGoldTop      = Color(hex: "#FFF176")
    static let btnGoldMid      = Color(hex: "#FFEB3B")
    static let btnGoldBot      = Color(hex: "#FDD835")
    static let btnGoldShadow   = Color(hex: "#F9A825")

    static let btnBlueTop      = Color(hex: "#64B5F6")
    static let btnBlueMid      = Color(hex: "#2196F3")
    static let btnBlueBot      = Color(hex: "#1976D2")
    static let btnBlueShadow   = Color(hex: "#0D47A1")

    static let btnRedTop       = Color(hex: "#EF9A9A")
    static let btnRedMid       = Color(hex: "#F44336")
    static let btnRedBot       = Color(hex: "#D32F2F")
    static let btnRedShadow    = Color(hex: "#B71C1C")

    // MARK: Category accents — bright & saturated
    static let landAccent       = Color(hex: "#FF8F00")
    static let seaAccent        = Color(hex: "#1E88E5")
    static let airAccent        = Color(hex: "#29B6F6")
    static let insectAccent     = Color(hex: "#43A047")
    static let fantasyAccent    = Color(hex: "#AB47BC")
    static let prehistoricAccent = Color(hex: "#FF8F00")
    static let mythicAccent     = Color(hex: "#FDD835")
    static let olympusAccent    = Color(hex: "#42A5F5")

    // MARK: Gradients
    static var mainBg: LinearGradient {
        LinearGradient(
            colors: [bgDeep, bgMid, bgNavy],
            startPoint: .top, endPoint: .bottom
        )
    }

    /// Home screen — light: sky blue → green meadow, dark: deep midnight
    static func homeBg(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .light
        ? LinearGradient(
            colors: [
                Color(hex: "#42A5F5"),
                Color(hex: "#1E88E5"),
                Color(hex: "#43A047"),
                Color(hex: "#2E7D32"),
                Color(hex: "#1B5E20")
            ],
            startPoint: .top, endPoint: .bottom)
        : LinearGradient(
            colors: [
                Color(hex: "#0A0A1A"),
                Color(hex: "#12082A"),
                Color(hex: "#0A1628")
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Battle screen — light: deep electric blue, dark: midnight navy
    static func battleBg(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .light
        ? LinearGradient(
            colors: [
                Color(hex: "#1A237E"),
                Color(hex: "#0D47A1"),
                Color(hex: "#1565C0"),
                Color(hex: "#0D47A1"),
                Color(hex: "#1A237E")
            ],
            startPoint: .top, endPoint: .bottom)
        : LinearGradient(
            colors: [
                Color(hex: "#06060F"),
                Color(hex: "#0D0820"),
                Color(hex: "#0A1228")
            ],
            startPoint: .top, endPoint: .bottom)
    }

    /// Unlock sheet — light: vivid purple, dark: deep purple
    static func unlockBg(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .light
        ? LinearGradient(
            colors: [
                Color(hex: "#9C27B0"),
                Color(hex: "#7B1FA2"),
                Color(hex: "#6A1B9A"),
                Color(hex: "#4A148C")
            ],
            startPoint: .top, endPoint: .bottom)
        : LinearGradient(
            colors: [
                Color(hex: "#1A0A2E"),
                Color(hex: "#12082A"),
                Color(hex: "#0A0A1A")
            ],
            startPoint: .top, endPoint: .bottom)
    }

    // Keep static versions for backward compat (default to light)
    static var homeBg: LinearGradient { homeBg(.light) }
    static var battleBg: LinearGradient { battleBg(.light) }
    static var unlockBg: LinearGradient { unlockBg(.light) }

    static var ctaGradient: LinearGradient {
        LinearGradient(colors: [btnOrangeTop, btnOrangeMid, btnOrangeBot],
                       startPoint: .top, endPoint: .bottom)
    }

    static var purpleGradient: LinearGradient {
        LinearGradient(colors: [btnPurpleTop, btnPurpleMid, btnPurpleBot],
                       startPoint: .top, endPoint: .bottom)
    }

    static func categoryGradient(_ cat: AnimalCategory) -> LinearGradient {
        switch cat {
        case .land:
            return LinearGradient(colors: [Color(hex: "#FFB74D"), Color(hex: "#FF8F00")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sea:
            return LinearGradient(colors: [Color(hex: "#64B5F6"), Color(hex: "#1E88E5")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .air:
            return LinearGradient(colors: [Color(hex: "#81D4FA"), Color(hex: "#29B6F6")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .insect:
            return LinearGradient(colors: [Color(hex: "#81C784"), Color(hex: "#43A047")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fantasy:
            return LinearGradient(colors: [Color(hex: "#CE93D8"), Color(hex: "#AB47BC")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .prehistoric:
            return LinearGradient(colors: [Color(hex: "#FFB74D"), Color(hex: "#FF8F00")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .mythic:
            return LinearGradient(colors: [Color(hex: "#FFF176"), Color(hex: "#FDD835")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .olympus:
            return LinearGradient(colors: [Color(hex: "#90CAF9"), Color(hex: "#42A5F5")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .all:
            return LinearGradient(colors: [Color(hex: "#64B5F6"), Color(hex: "#42A5F5")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func categoryAccent(_ cat: AnimalCategory) -> Color {
        switch cat {
        case .land:        return landAccent
        case .sea:         return seaAccent
        case .air:         return airAccent
        case .insect:      return insectAccent
        case .fantasy:     return fantasyAccent
        case .prehistoric: return prehistoricAccent
        case .mythic:      return mythicAccent
        case .olympus:     return olympusAccent
        case .all:         return blue
        }
    }

    static func categoryEmoji(_ cat: AnimalCategory) -> String {
        switch cat {
        case .all:         return "🌍"
        case .land:        return "🌿"
        case .sea:         return "🌊"
        case .air:         return "☁️"
        case .insect:      return "🐛"
        case .fantasy:     return "✨"
        case .prehistoric: return "🦖"
        case .mythic:      return "⚡"
        case .olympus:     return "🏛️"
        }
    }

    static func categoryLabel(_ cat: AnimalCategory) -> String {
        switch cat {
        case .all:         return "All"
        case .land:        return "Land"
        case .sea:         return "Sea"
        case .air:         return "Air"
        case .insect:      return "Bugs"
        case .fantasy:     return "Fantasy"
        case .prehistoric: return "Dinos"
        case .mythic:      return "Mythic"
        case .olympus:     return "Olympus"
        }
    }

    // MARK: Typography helpers

    /// Bungee — chunky display font for big titles (ANIMAL VS ANIMAL, VS, WINNER!, section headers)
    static func bungee(_ size: CGFloat) -> Font { .custom("Bungee-Regular", size: size) }

    /// Lilita One — bold kid-friendly font for buttons, card labels, sub-headers
    static func lilita(_ size: CGFloat) -> Font { .custom("LilitaOne-Regular", size: size) }

    // System rounded fallbacks
    static func display(_ size: CGFloat) -> Font  { .system(size: size, weight: .black,    design: .rounded) }
    static func headline(_ size: CGFloat) -> Font { .system(size: size, weight: .bold,     design: .rounded) }
    static func bodyFont(_ size: CGFloat) -> Font { .system(size: size, weight: .medium,   design: .rounded) }
    static func labelFont(_ size: CGFloat) -> Font{ .system(size: size, weight: .semibold, design: .rounded) }
}
