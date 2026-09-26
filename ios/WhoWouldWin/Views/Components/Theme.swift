import SwiftUI

/// Compatibility tokens for older components, backed by the single retro theme.
struct Theme {
    static var bgDeep: Color { Kids.cream }
    static var bgMid: Color { Kids.cream }
    static var bgNavy: Color { Kids.creamDeep }
    static var bgCard: Color { Kids.panel }
    static var bgSurface: Color { Kids.creamDeep }
    static var textPrimary: Color { Kids.ink }
    static var textSecondary: Color { Kids.inkSoft }
    static var textTertiary: Color { Kids.inkSoft }
    static var cardFill: Color { Kids.panel }
    static var cardBorder: Color { Kids.ink.opacity(0.6) }
    static var divider: Color { Kids.ink.opacity(0.16) }
    static let orange = Kids.peachDeep
    static let yellow = Kids.sun
    static let gold = Kids.sun
    static let purple = Kids.grapeDeep
    static let cyan = Kids.sky
    static let teal = Kids.skyDeep
    static let red = Kids.pinkDeep
    static let neonGrn = Kids.grass
    static let blue = Kids.skyDeep
    static let btnOrangeTop = Kids.peach
    static let btnOrangeMid = Kids.peach
    static let btnOrangeBot = Kids.peach
    static let btnOrangeShadow = Kids.peachDeep
    static let btnGreenTop = Kids.grass
    static let btnGreenMid = Kids.grass
    static let btnGreenBot = Kids.grass
    static let btnGreenShadow = Kids.grassDeep
    static let btnPurpleTop = Kids.grape
    static let btnPurpleMid = Kids.grape
    static let btnPurpleBot = Kids.grape
    static let btnPurpleShadow = Kids.grapeDeep
    static let btnGoldTop = Kids.sun
    static let btnGoldMid = Kids.sun
    static let btnGoldBot = Kids.sun
    static let btnGoldShadow = Kids.sunDeep
    static let btnBlueTop = Kids.sky
    static let btnBlueMid = Kids.sky
    static let btnBlueBot = Kids.sky
    static let btnBlueShadow = Kids.skyDeep
    static let btnRedTop = Kids.pink
    static let btnRedMid = Kids.pink
    static let btnRedBot = Kids.pink
    static let btnRedShadow = Kids.pinkDeep
    static let landAccent = Kids.grassDeep
    static let seaAccent = Kids.skyDeep
    static let airAccent = Kids.sky
    static let insectAccent = Kids.grass
    static let fantasyAccent = Kids.grape
    static let prehistoricAccent = Kids.peach
    static let mythicAccent = Kids.sunDeep
    static let olympusAccent = Kids.sun
    static var mainBg: LinearGradient { homeBg }
    static func homeBg(_ scheme: ColorScheme) -> LinearGradient { flat(Kids.cream) }
    static func battleBg(_ scheme: ColorScheme) -> LinearGradient { flat(Kids.cream) }
    static func unlockBg(_ scheme: ColorScheme) -> LinearGradient { flat(Kids.cream) }
    static var homeBg: LinearGradient { flat(Kids.cream) }
    static var battleBg: LinearGradient { flat(Kids.cream) }
    static var unlockBg: LinearGradient { flat(Kids.cream) }
    static var ctaGradient: LinearGradient { flat(Kids.sun) }
    static var purpleGradient: LinearGradient { flat(Kids.grape) }
    private static func flat(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color, color], startPoint: .top, endPoint: .bottom)
    }
    static func categoryGradient(_ cat: AnimalCategory) -> LinearGradient { flat(categoryAccent(cat)) }
    static func categoryAccent(_ cat: AnimalCategory) -> Color {
        switch cat {
        case .land: return landAccent
        case .sea: return seaAccent
        case .air: return airAccent
        case .insect: return insectAccent
        case .pets: return Kids.peach
        case .farm: return Kids.grass
        case .fantasy: return fantasyAccent
        case .prehistoric: return prehistoricAccent
        case .mythic: return mythicAccent
        case .olympus: return olympusAccent
        case .all: return Kids.grassDeep
        }
    }
    static func categoryEmoji(_ cat: AnimalCategory) -> String {
        switch cat {
        case .all:         return "🌍"
        case .land:        return "🌿"
        case .sea:         return "🌊"
        case .air:         return "☁️"
        case .insect:      return "🐛"
        case .pets:        return "🐶"
        case .farm:        return "🚜"
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
        case .pets:        return "Pets"
        case .farm:        return "Farm"
        case .fantasy:     return "Fantasy"
        case .prehistoric: return "Dinos"
        case .mythic:      return "Mythic"
        case .olympus:     return "Olympus"
        }
    }


    static func bungee(_ size: CGFloat) -> Font { size >= 26 ? Kids.pixel(size * 0.66) : Kids.fredoka(size) }
    static func lilita(_ size: CGFloat) -> Font { Kids.fredoka(size) }
    static func display(_ size: CGFloat) -> Font { Kids.pixel(max(10, size * 0.66)) }
    static func headline(_ size: CGFloat) -> Font { Kids.fredoka(size) }
    static func bodyFont(_ size: CGFloat) -> Font { Kids.nunito(size, weight: .medium) }
    static func labelFont(_ size: CGFloat) -> Font { Kids.nunito(size, weight: .semibold) }
}
