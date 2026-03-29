import SwiftUI

struct PixelTextModifier: ViewModifier {
    let size: CGFloat
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(.custom("PressStart2P-Regular", size: size).weight(.bold))
            // fallback handled by SwiftUI automatically if font missing
            .foregroundColor(color)
            .shadow(color: .black.opacity(0.8), radius: 2, x: 2, y: 2)
    }
}

extension View {
    func pixelText(size: CGFloat = 14, color: Color = .white) -> some View {
        modifier(PixelTextModifier(size: size, color: color))
    }
}
