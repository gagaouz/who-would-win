import SwiftUI

// Shared view helpers still used by live screens. (The old retro/"mega"
// button styles, panels and VS shield that lived here were removed in 1.1.7
// along with the legacy screens that used them.)

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

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
