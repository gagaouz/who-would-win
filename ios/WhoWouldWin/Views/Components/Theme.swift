import SwiftUI

// MARK: - App-wide Design System

struct Theme {

    // MARK: Adaptive Backgrounds
    // Each color uses UIColor's dynamic provider so it responds to
    // `.preferredColorScheme` applied at the root.

    static var bgDeep: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.949, green: 0.941, blue: 1.000, alpha: 1)  // #F2F0FF
                : UIColor(red: 0.055, green: 0.043, blue: 0.133, alpha: 1)  // #0E0B22
        })
    }
    static var bgMid: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.910, green: 0.898, blue: 1.000, alpha: 1)  // #E8E5FF
                : UIColor(red: 0.094, green: 0.043, blue: 0.196, alpha: 1)  // #180B32
        })
    }
    static var bgNavy: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.929, green: 0.941, blue: 1.000, alpha: 1)  // #EDF0FF
                : UIColor(red: 0.043, green: 0.082, blue: 0.157, alpha: 1)  // #0B1528
        })
    }
    static var bgCard: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? .white
                : UIColor(red: 0.118, green: 0.086, blue: 0.251, alpha: 1)  // #1E1640
        })
    }
    static var bgSurface: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.961, green: 0.949, blue: 1.000, alpha: 1)  // #F5F2FF
                : UIColor(red: 0.145, green: 0.114, blue: 0.310, alpha: 1)  // #251D4F
        })
    }

    // MARK: Adaptive Text

    /// Primary text — white in dark mode, deep purple in light mode.
    static var textPrimary: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.098, green: 0.059, blue: 0.251, alpha: 1)  // #190F40
                : .white
        })
    }
    /// Secondary text — ~55 % white in dark, medium purple in light.
    static var textSecondary: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.318, green: 0.251, blue: 0.522, alpha: 0.85)
                : UIColor.white.withAlphaComponent(0.55)
        })
    }
    /// Tertiary / placeholder text — ~30 % white in dark, light purple in light.
    static var textTertiary: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.42, green: 0.36, blue: 0.60, alpha: 0.65)
                : UIColor.white.withAlphaComponent(0.30)
        })
    }

    // MARK: Adaptive Surfaces

    /// Card / cell fill — replaces `Color.white.opacity(0.07)` on dark.
    static var cardFill: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor.white.withAlphaComponent(0.88)
                : UIColor.white.withAlphaComponent(0.07)
        })
    }
    /// Card border — replaces `Color.white.opacity(0.12)` on dark.
    static var cardBorder: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.65, green: 0.60, blue: 0.88, alpha: 0.45)
                : UIColor.white.withAlphaComponent(0.12)
        })
    }
    /// Divider — replaces `Color.white.opacity(0.08)` on dark.
    static var divider: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .light
                ? UIColor(red: 0.65, green: 0.60, blue: 0.88, alpha: 0.30)
                : UIColor.white.withAlphaComponent(0.08)
        })
    }

    // MARK: Brand (same on both themes — work on any background)
    static let orange   = Color(hex: "#FF5722")
    static let yellow   = Color(hex: "#FFD60A")
    static let gold     = Color(hex: "#FFD700")
    static let purple   = Color(hex: "#9B5DE5")
    static let cyan     = Color(hex: "#00CFCF")
    static let teal     = Color(hex: "#06D6A0")
    static let red      = Color(hex: "#FF3A5C")
    static let neonGrn  = Color(hex: "#39FF14")

    // MARK: Category accents
    static let landAccent       = Color(hex: "#D4622A")
    static let seaAccent        = Color(hex: "#1B87CC")
    static let airAccent        = Color(hex: "#5DADE2")
    static let insectAccent     = Color(hex: "#38A169")
    static let fantasyAccent    = Color(hex: "#C77DFF")
    static let prehistoricAccent = Color(hex: "#C8820A")
    static let mythicAccent     = Color(hex: "#C0A000")
    static let olympusAccent    = Color(hex: "#FFD700")

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
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.00, green: 0.969, blue: 0.941, alpha: 1)  // #FFF7F0
                        : UIColor(red: 0.361, green: 0.145, blue: 0.031, alpha: 1) // #5C2508
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.00, green: 0.929, blue: 0.886, alpha: 1)  // #FFEDE2
                        : UIColor(red: 0.180, green: 0.071, blue: 0.016, alpha: 1) // #2E1204
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .sea:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.918, green: 0.949, blue: 1.000, alpha: 1)  // #EAF2FF
                        : UIColor(red: 0.031, green: 0.220, blue: 0.439, alpha: 1)  // #083870
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.875, green: 0.925, blue: 1.000, alpha: 1)  // #DFECFF
                        : UIColor(red: 0.016, green: 0.106, blue: 0.220, alpha: 1)  // #041B38
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .air:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.929, green: 0.949, blue: 1.000, alpha: 1)  // #EDF2FF
                        : UIColor(red: 0.063, green: 0.180, blue: 0.396, alpha: 1)  // #102E65
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.882, green: 0.922, blue: 1.000, alpha: 1)  // #E1EBFF
                        : UIColor(red: 0.031, green: 0.086, blue: 0.188, alpha: 1)  // #081630
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .insect:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.918, green: 1.000, blue: 0.929, alpha: 1)  // #EAFFED
                        : UIColor(red: 0.082, green: 0.298, blue: 0.082, alpha: 1)  // #154C15
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.867, green: 0.961, blue: 0.882, alpha: 1)  // #DDF5E1
                        : UIColor(red: 0.039, green: 0.149, blue: 0.039, alpha: 1)  // #0A260A
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .fantasy:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.969, green: 0.929, blue: 1.000, alpha: 1)  // #F7EDFF
                        : UIColor(red: 0.231, green: 0.063, blue: 0.404, alpha: 1)  // #3B1067
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.929, green: 0.855, blue: 1.000, alpha: 1)  // #EDDAFF
                        : UIColor(red: 0.102, green: 0.020, blue: 0.208, alpha: 1)  // #1A0535
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .prehistoric:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.000, green: 0.957, blue: 0.882, alpha: 1)  // #FFF4E1
                        : UIColor(red: 0.306, green: 0.192, blue: 0.031, alpha: 1)  // #4E3108
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.000, green: 0.922, blue: 0.800, alpha: 1)  // #FFEBCC
                        : UIColor(red: 0.176, green: 0.102, blue: 0.016, alpha: 1)  // #2D1A04
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .mythic:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.000, green: 0.976, blue: 0.882, alpha: 1)  // #FFF9E1
                        : UIColor(red: 0.200, green: 0.176, blue: 0.031, alpha: 1)  // #332D08
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.000, green: 0.957, blue: 0.800, alpha: 1)  // #FFF4CC
                        : UIColor(red: 0.102, green: 0.086, blue: 0.016, alpha: 1)  // #1A1604
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .olympus:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.000, green: 0.980, blue: 0.800, alpha: 1)  // #FFFACC
                        : UIColor(red: 0.250, green: 0.220, blue: 0.020, alpha: 1)  // #403805
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 1.000, green: 0.957, blue: 0.700, alpha: 1)  // #FFF4B2
                        : UIColor(red: 0.140, green: 0.120, blue: 0.010, alpha: 1)  // #241E02
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .all:
            return LinearGradient(
                colors: [
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor.white.withAlphaComponent(0.9)
                        : UIColor.white.withAlphaComponent(0.09)
                    }),
                    Color(UIColor { $0.userInterfaceStyle == .light
                        ? UIColor(red: 0.961, green: 0.949, blue: 1.000, alpha: 0.9)
                        : UIColor.white.withAlphaComponent(0.04)
                    })
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
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
        case .all:         return .white.opacity(0.5)
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
    static func display(_ size: CGFloat) -> Font  { .system(size: size, weight: .black,    design: .rounded) }
    static func headline(_ size: CGFloat) -> Font { .system(size: size, weight: .bold,     design: .rounded) }
    static func bodyFont(_ size: CGFloat) -> Font { .system(size: size, weight: .medium,   design: .rounded) }
    static func labelFont(_ size: CGFloat) -> Font{ .system(size: size, weight: .semibold, design: .rounded) }
}
