import SwiftUI

// MARK: - New Animal Unlock Celebration — Animal Arena Jr.
// Matches screenshots/08_unlock.png — "NEW FRIEND UNLOCKED ✨ MEET SHARKY!"

struct KidsUnlockView: View {
    let animal: Animal
    let onBattle: () -> Void
    let onAddToBook: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    @State private var appeared = false
    @State private var rayRotate: Double = 0
    @State private var animalBob: CGFloat = 0

    var body: some View {
        ZStack {
            // Sunburst background
            LinearGradient(colors: [Kids.pink, Color(hex: "#F2BFE8"), Kids.grape],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Rotating rays behind hero
            SunburstRays()
                .rotationEffect(.degrees(rayRotate))
                .opacity(0.55)
                .blendMode(.screen)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 18) {
                Spacer().frame(height: 20)

                // Pill label
                Text("✨ NEW FRIEND UNLOCKED ✨")
                    .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(
                        Capsule().fill(Kids.ink)
                            .overlay(Capsule().stroke(Color.white, lineWidth: 2))
                    )
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)

                // MEET / NAME stickers
                VStack(spacing: -4) {
                    StickerWord(text: "MEET", fill: Kids.pink, fontSize: isIPad ? 60 : 44, tilt: -2)
                        .rotationEffect(.degrees(appeared ? -2 : -15))
                        .scaleEffect(appeared ? 1 : 0.2)
                        .opacity(appeared ? 1 : 0)
                    StickerWord(text: "\(animal.name.uppercased())!", fill: Kids.sun, fontSize: isIPad ? 60 : 44, tilt: 2)
                        .rotationEffect(.degrees(appeared ? 2 : 15))
                        .scaleEffect(appeared ? 1 : 0.2)
                        .opacity(appeared ? 1 : 0)
                }

                // Hero bubble
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white, Kids.cream],
                                             center: .center, startRadius: 0, endRadius: 120))
                        .overlay(Circle().stroke(Kids.sun, lineWidth: 6))
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 4).padding(3))
                        .frame(width: isIPad ? 240 : 180, height: isIPad ? 240 : 180)
                        .shadow(color: Kids.ink.opacity(0.11), radius: 0, x: 0, y: 6)
                    Text(animal.emoji).font(.system(size: isIPad ? 130 : 100))
                        .offset(y: animalBob)
                }
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)

                // Superpowers
                VStack(spacing: 8) {
                    Text("\(animal.name)'s Superpowers!")
                        .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                        .foregroundColor(Kids.ink)
                    let stats = AnimalStats.generate(for: animal)
                    HStack(spacing: 8) {
                        PowerChip(icon: "⚡", label: "\(stats.speed)", color: Kids.sky, isIPad: isIPad)
                        PowerChip(icon: "💪", label: "\(stats.power)", color: Kids.pink, isIPad: isIPad)
                        PowerChip(icon: "🛡️", label: "\(stats.defense)", color: Kids.grape, isIPad: isIPad)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                )
                .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)

                // Battle button
                KidButton(title: "BATTLE WITH \(animal.name.uppercased())", icon: "⚡",
                          color: Kids.grass, size: .lg) {
                    HapticsService.shared.tap()
                    onBattle()
                }
                .padding(.horizontal, isIPad ? 50 : 30)
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)

                Button {
                    onAddToBook()
                    dismiss()
                } label: {
                    Text("Add to Sticker Book →")
                        .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .underline()
                }
                .opacity(appeared ? 1 : 0)

                Spacer()
                }
                .frame(maxWidth: isIPad ? 650 : .infinity)
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.5).delay(0.1)) {
                appeared = true
            }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rayRotate = 360
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animalBob = -8
            }
        }
    }
}

private struct PowerChip: View {
    let icon: String
    let label: String
    let color: Color
    var isIPad: Bool = false
    var body: some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: isIPad ? 17 : 14))
            Text(label)
                .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                .foregroundColor(Kids.ink)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2))
        )
    }
}

// Simple 16-ray sunburst
private struct SunburstRays: View {
    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            let r = max(geo.size.width, geo.size.height)
            ZStack {
                ForEach(0..<16, id: \.self) { i in
                    Path { p in
                        let angle = Double(i) * (360.0/16.0) * .pi / 180
                        let spread: Double = .pi / 32
                        let p1 = CGPoint(
                            x: c.x + cos(angle - spread) * r,
                            y: c.y + sin(angle - spread) * r)
                        let p2 = CGPoint(
                            x: c.x + cos(angle + spread) * r,
                            y: c.y + sin(angle + spread) * r)
                        p.move(to: c)
                        p.addLine(to: p1)
                        p.addLine(to: p2)
                        p.closeSubpath()
                    }
                    .fill(i.isMultiple(of: 2) ? Color.white.opacity(0.5) : Color(hex: "#FFD8EE").opacity(0.6))
                }
            }
        }
        .ignoresSafeArea()
    }
}
