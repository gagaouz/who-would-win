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

// MARK: - GradientButtonStyle (Primary CTA)

struct GradientButtonStyle: ButtonStyle {
    var gradient: LinearGradient = LinearGradient(
        colors: [Color(hex: "#FF6B35"), Color(hex: "#FFD700")],
        startPoint: .leading,
        endPoint: .trailing
    )
    var shadowColor: Color = Color(hex: "#FF6B35")
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Capsule()
                    .fill(gradient)
            )
            .shadow(color: shadowColor.opacity(configuration.isPressed ? 0.2 : 0.5), radius: 12, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - RetroButtonStyle (Legacy / Backward Compatibility)

struct RetroButtonStyle: ButtonStyle {
    var backgroundColor: Color = Color(hex: "#FFD700")
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
