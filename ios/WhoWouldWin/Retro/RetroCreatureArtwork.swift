import SwiftUI

/// Catalog portraits and local custom avatars use the same art as the arena.
struct RetroCreatureArtwork: View {
    let animal: Animal
    let size: CGFloat
    @ObservedObject private var art = RetroAssetStore.shared

    var body: some View {
        Group {
            if let image = art.image(for: animal) {
                Image(uiImage: image).resizable().interpolation(.none).scaledToFit()
                    .padding(size * 0.06)
            } else {
                RetroArtPlaceholder().fill(Color(hex: animal.pixelColor).opacity(0.7))
                    .padding(size * 0.18)
                    .overlay(alignment: .bottomTrailing) {
                        if animal.isCustom {
                            Image(systemName: "sparkle").font(.system(size: max(10, size * 0.15)))
                                .foregroundStyle(Color(hex: "496845"))
                        }
                    }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(animal.name)
        .accessibilityValue(art.artworkDescription(for: animal))
    }
}

/// An intentionally neutral temporary creature token, never a claimed portrait.
struct RetroArtPlaceholder: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [(CGFloat, CGFloat)] = [
            (2, 3), (3, 3), (3, 1), (5, 1), (5, 2), (7, 2), (7, 1), (9, 1),
            (9, 3), (10, 3), (10, 8), (9, 8), (9, 10), (7, 10), (7, 9),
            (5, 9), (5, 10), (3, 10), (3, 8), (2, 8)
        ]
        var path = Path()
        for (index, point) in points.enumerated() {
            let p = CGPoint(x: rect.minX + point.0 / 12 * rect.width, y: rect.minY + point.1 / 12 * rect.height)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
