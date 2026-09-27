import SwiftUI

/// The original home title's independent rocking, rebuilt as a compact arcade logo.
/// Its artwork stays a fixed size for legibility; VoiceOver reads the title once.
struct RetroAnimatedLogo: View {
    let isIPad: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var animationStart = Date()

    init(isIPad: Bool = false) {
        self.isIPad = isIPad
    }

    private var isAnimating: Bool {
        isVisible && !reduceMotion && scenePhase == .active
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 288, geometry.size.height / 136)

            TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !isAnimating)) { timeline in
                let time = isAnimating ? timeline.date.timeIntervalSince(animationStart) : 0
                logo(time: time)
                    .scaleEffect(scale)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(maxWidth: isIPad ? 352 : 320)
        .frame(height: isIPad ? 160 : 136)
        // A decorative wordmark should not grow until it clips at accessibility sizes.
        .dynamicTypeSize(.medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Animal versus Animal")
        .accessibilityAddTraits(.isHeader)
        .allowsHitTesting(false)
        .onAppear {
            animationStart = Date()
            isVisible = true
        }
        .onDisappear { isVisible = false }
    }

    private func logo(time: TimeInterval) -> some View {
        ZStack {
            // Small stepped rays hold the middle line together without a large panel.
            HStack(spacing: 62) {
                rays(color: Kids.sky, pointsRight: true)
                rays(color: Kids.pink, pointsRight: false)
            }
            .position(x: 144, y: 68)

            word(colors: [Kids.sun, Kids.peach, Kids.pink])
                .rotationEffect(.degrees(-2 + sin(time * 2 * .pi / 4.2) * 2.2))
                .position(x: 141, y: 34)

            word(colors: [Kids.sky, Kids.grass])
                .rotationEffect(.degrees(2 - sin(time * 2 * .pi / 5.1) * 1.8))
                .position(x: 141, y: 103)

            Text("VS")
                .font(Kids.pixel(16))
                .foregroundStyle(Kids.ink)
                .offset(y: 1)
                .frame(width: 53, height: 29)
                .background {
                    LogoBadge()
                        .fill(Kids.ink)
                        .offset(x: 3, y: 4)
                    LogoBadge()
                        .fill(Kids.pink)
                        .overlay {
                            LogoBadge().stroke(Kids.ink, lineWidth: 2)
                        }
                }
                .rotationEffect(.degrees(sin(time * 2 * .pi / 4.8) * 2))
                .position(x: 144, y: 68)
        }
        .frame(width: 288, height: 136)
        .scaleEffect(1 + sin(time * 2 * .pi / 5.8) * 0.012)
    }

    private func word(colors: [Color]) -> some View {
        Text("ANIMAL")
            .font(Kids.pixel(38))
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .background {
                ZStack {
                    // Whole-pixel offsets make solid, stepped edges instead of a soft glow.
                    ForEach(1..<7) { step in
                        Text("ANIMAL")
                            .foregroundStyle(Kids.ink)
                            .offset(x: CGFloat(step), y: CGFloat(step))
                    }
                    ForEach(0..<8) { index in
                        Text("ANIMAL")
                            .foregroundStyle(Kids.ink)
                            .offset(x: outlineOffsets[index].width, y: outlineOffsets[index].height)
                    }
                }
                .font(Kids.pixel(38))
            }
            .fixedSize()
    }

    private var outlineOffsets: [CGSize] {
        [CGSize(width: -2, height: -2), CGSize(width: 0, height: -2),
         CGSize(width: 2, height: -2), CGSize(width: 2, height: 0),
         CGSize(width: 2, height: 2), CGSize(width: 0, height: 2),
         CGSize(width: -2, height: 2), CGSize(width: -2, height: 0)]
    }

    private func rays(color: Color, pointsRight: Bool) -> some View {
        VStack(alignment: pointsRight ? .trailing : .leading, spacing: 3) {
            Rectangle().fill(color).frame(width: 26, height: 3)
            Rectangle().fill(color).frame(width: 42, height: 3)
            Rectangle().fill(Kids.sun).frame(width: 32, height: 3)
        }
    }

    private struct LogoBadge: Shape {
        func path(in rect: CGRect) -> Path {
            let step: CGFloat = 5
            return Path { path in
                path.move(to: CGPoint(x: rect.minX + step, y: rect.minY))
                path.addLines([
                    CGPoint(x: rect.maxX - step, y: rect.minY),
                    CGPoint(x: rect.maxX - step, y: rect.minY + step),
                    CGPoint(x: rect.maxX, y: rect.minY + step),
                    CGPoint(x: rect.maxX, y: rect.maxY - step),
                    CGPoint(x: rect.maxX - step, y: rect.maxY - step),
                    CGPoint(x: rect.maxX - step, y: rect.maxY),
                    CGPoint(x: rect.minX + step, y: rect.maxY),
                    CGPoint(x: rect.minX + step, y: rect.maxY - step),
                    CGPoint(x: rect.minX, y: rect.maxY - step),
                    CGPoint(x: rect.minX, y: rect.minY + step),
                    CGPoint(x: rect.minX + step, y: rect.minY + step)
                ])
                path.closeSubpath()
            }
        }
    }
}
