import SwiftUI

// MARK: - Color(hex:) Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Mega Button Style (Supercell 3D raised)

enum MegaButtonColor {
    case orange, green, purple, gold, blue, red

    var topColor: Color {
        switch self {
        case .orange: return Theme.btnOrangeTop
        case .green:  return Theme.btnGreenTop
        case .purple: return Theme.btnPurpleTop
        case .gold:   return Theme.btnGoldTop
        case .blue:   return Theme.btnBlueTop
        case .red:    return Theme.btnRedTop
        }
    }
    var midColor: Color {
        switch self {
        case .orange: return Theme.btnOrangeMid
        case .green:  return Theme.btnGreenMid
        case .purple: return Theme.btnPurpleMid
        case .gold:   return Theme.btnGoldMid
        case .blue:   return Theme.btnBlueMid
        case .red:    return Theme.btnRedMid
        }
    }
    var botColor: Color {
        switch self {
        case .orange: return Theme.btnOrangeBot
        case .green:  return Theme.btnGreenBot
        case .purple: return Theme.btnPurpleBot
        case .gold:   return Theme.btnGoldBot
        case .blue:   return Theme.btnBlueBot
        case .red:    return Theme.btnRedBot
        }
    }
    var shadowColor: Color {
        switch self {
        case .orange: return Theme.btnOrangeShadow
        case .green:  return Theme.btnGreenShadow
        case .purple: return Theme.btnPurpleShadow
        case .gold:   return Theme.btnGoldShadow
        case .blue:   return Theme.btnBlueShadow
        case .red:    return Theme.btnRedShadow
        }
    }
    var textColor: Color {
        switch self {
        case .gold: return Color(hex: "#1A237E")
        default:    return .white
        }
    }
    var glowColor: Color { midColor }
}

struct MegaButtonStyle: ButtonStyle {
    var color: MegaButtonColor = .orange
    var height: CGFloat = 68
    var cornerRadius: CGFloat = 18
    var fontSize: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.bungee(fontSize))
            .foregroundColor(color.textColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                ZStack {
                    // Bottom shadow edge (3D depth)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(color.shadowColor)
                        .offset(y: pressed ? 2 : 6)

                    // Main button body
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [color.topColor, color.midColor, color.botColor],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                    // Top shine highlight
                    VStack {
                        RoundedRectangle(cornerRadius: cornerRadius - 2)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.35), Color.white.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(height: height * 0.4)
                            .padding(.horizontal, 6)
                            .padding(.top, 3)
                        Spacer()
                    }
                }
            )
            .shadow(color: color.glowColor.opacity(pressed ? 0.2 : 0.4), radius: pressed ? 6 : 14, x: 0, y: pressed ? 2 : 6)
            .offset(y: pressed ? 3 : 0)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: pressed)
    }
}

// MARK: - GradientButtonStyle (Legacy compat — now wraps MegaButtonStyle look)

struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient = LinearGradient(
        colors: [Theme.btnOrangeTop, Theme.btnOrangeMid, Theme.btnOrangeBot],
        startPoint: .top, endPoint: .bottom
    )
    var shadowColor: Color = Theme.btnOrangeShadow
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.bungee(18))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(shadowColor)
                        .offset(y: pressed ? 2 : 5)
                    RoundedRectangle(cornerRadius: 18)
                        .fill(gradient)
                    VStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                            .frame(height: height * 0.4)
                            .padding(.horizontal, 5)
                            .padding(.top, 3)
                        Spacer()
                    }
                }
            )
            .shadow(color: shadowColor.opacity(pressed ? 0.2 : 0.45), radius: pressed ? 4 : 12, x: 0, y: pressed ? 2 : 4)
            .offset(y: pressed ? 2 : 0)
            .scaleEffect(pressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: pressed)
    }
}

// MARK: - RetroButtonStyle (Legacy / Backward Compatibility)

struct RetroButtonStyle: ButtonStyle {
    var backgroundColor: Color = Theme.gold
    var borderColor: Color = .white
    var textColor: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pixelText(size: 12, color: textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(borderColor, lineWidth: 4)
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .shadow(color: .black, radius: 0, x: 0, y: configuration.isPressed ? 0 : 4)
            .animation(.easeInOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Game Panel (frosted glass card)

struct GamePanel<Content: View>: View {
    var headerText: String? = nil
    var headerColor: MegaButtonColor = .orange
    var borderColor: Color = Color.white.opacity(0.25)
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if let header = headerText {
                Text(header)
                    .font(Theme.bungee(18))
                    .foregroundColor(headerColor.textColor)
                    .textCase(.uppercase)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [headerColor.topColor, headerColor.midColor],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: headerColor.midColor.opacity(0.3), radius: 4, y: 2)
            }
            VStack(spacing: 0) {
                content()
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.08))
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(borderColor, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
    }
}

// MARK: - Battle Panel (special glowing version for battle screen)

struct BattlePanel<Content: View>: View {
    var headerText: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Text(headerText)
                .font(Theme.bungee(18))
                .foregroundColor(.white)
                .textCase(.uppercase)
                .tracking(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FF6D00"), Color(hex: "#D50000")],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            VStack(spacing: 0) {
                content()
            }
            .padding(14)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#0D47A1").opacity(0.7), Color(hex: "#1A237E").opacity(0.8)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(hex: "#64B5F6").opacity(0.4), lineWidth: 2)
        )
        .shadow(color: Color(hex: "#2196F3").opacity(0.15), radius: 14, y: 6)
    }
}

// MARK: - Screen Background (bright gradient + glow + particles)

struct ScreenBackground: View {
    enum Style {
        case home, battle, unlock, settings
    }
    var style: Style = .home
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            overlayGlows.ignoresSafeArea()
            if (style == .home || style == .settings) && colorScheme == .light {
                groundStrip.ignoresSafeArea()
            }
        }
    }

    private var gradient: some View {
        Group {
            switch style {
            case .home, .settings:
                Theme.homeBg(colorScheme)
            case .battle:
                Theme.battleBg(colorScheme)
            case .unlock:
                Theme.unlockBg(colorScheme)
            }
        }
    }

    @ViewBuilder
    private var overlayGlows: some View {
        let isDark = colorScheme == .dark
        switch style {
        case .home, .settings:
            ZStack {
                RadialGradient(colors: [Color.yellow.opacity(isDark ? 0.08 : 0.3), .clear],
                               center: .init(x: 0.5, y: 0.05), startRadius: 0, endRadius: 300)
                RadialGradient(colors: [Color.green.opacity(isDark ? 0.05 : 0.15), .clear],
                               center: .init(x: 0.2, y: 0.85), startRadius: 0, endRadius: 200)
                if isDark {
                    RadialGradient(colors: [Color.purple.opacity(0.08), .clear],
                                   center: .init(x: 0.7, y: 0.3), startRadius: 0, endRadius: 250)
                }
            }
        case .battle:
            ZStack {
                RadialGradient(colors: [Color.yellow.opacity(isDark ? 0.06 : 0.15), .clear],
                               center: .init(x: 0.5, y: 0.3), startRadius: 0, endRadius: 200)
                RadialGradient(colors: [Color.red.opacity(isDark ? 0.05 : 0.12), .clear],
                               center: .init(x: 0.2, y: 0.2), startRadius: 0, endRadius: 200)
                RadialGradient(colors: [Theme.cyan.opacity(isDark ? 0.05 : 0.12), .clear],
                               center: .init(x: 0.8, y: 0.2), startRadius: 0, endRadius: 200)
            }
        case .unlock:
            ZStack {
                RadialGradient(colors: [Color(hex: "#E1BEE7").opacity(isDark ? 0.08 : 0.25), .clear],
                               center: .init(x: 0.5, y: 0.15), startRadius: 0, endRadius: 250)
                RadialGradient(colors: [Color(hex: "#64B5F6").opacity(isDark ? 0.04 : 0.1), .clear],
                               center: .init(x: 0.3, y: 0.8), startRadius: 0, endRadius: 200)
            }
        }
    }

    private var groundStrip: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, Color(hex: "#388E3C").opacity(0.4), Color(hex: "#1B5E20").opacity(0.6)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 120)
        }
    }
}

// MARK: - VS Shield (golden pulsing badge)

struct VSShield: View {
    var size: CGFloat = 56
    var fontSize: CGFloat = 18

    var body: some View {
        Text("VS")
            .font(Theme.bungee(fontSize))
            .foregroundColor(Color(hex: "#E65100"))
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#FFF176"), Color(hex: "#FFEB3B"), Color(hex: "#FDD835")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(Color(hex: "#FF8F00"), lineWidth: 4)
            )
            .shadow(color: Color(hex: "#F57C00").opacity(0.45), radius: 3, y: 2)
            .shadow(color: Color(hex: "#FFEB3B").opacity(0.18), radius: 8)
    }
}
