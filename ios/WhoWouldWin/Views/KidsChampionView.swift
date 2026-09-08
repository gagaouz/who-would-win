import SwiftUI

// MARK: - Tournament Champion — Animal Arena Jr.
// Matches design champion.jsx — trophy, pedestal, champion path.

struct KidsChampionView: View {
    let champion: Animal
    let pathAnimals: [Animal]   // path of defeated foes, oldest → newest
    let onClaim: () -> Void
    let onShare: () -> Void
    let onPlayAgain: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    @State private var appeared = false
    @State private var raySpin: Double = 0
    @State private var trophyBob: CGFloat = 0
    @State private var lionPulse: CGFloat = 1

    var body: some View {
        ZStack {
            // Radial sunburst gradient
            RadialGradient(
                colors: [Kids.sun, Color(hex: "#FF8AC5"), Color(hex: "#4A2E7A")],
                center: .init(x: 0.5, y: 0.3),
                startRadius: 30, endRadius: 600
            ).ignoresSafeArea()

            // Spinning sunburst rays
            SunRays(count: 20, color: .white.opacity(0.18))
                .rotationEffect(.degrees(raySpin))
                .ignoresSafeArea()

            // Confetti decorations
            Confetti()

            // Wrapped in ScrollView so iPad landscape (shorter height) doesn't
            // clip the bottom buttons.
            ScrollView(.vertical, showsIndicators: false) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 14) {
                    Spacer().frame(height: 50)

                // Champion banner pill
                Text("🏆 TOURNAMENT CHAMPION 🏆")
                    .font(Kids.fredoka(12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Kids.sun)
                    .padding(.horizontal, 18).padding(.vertical, 7)
                    .background(
                        Capsule().fill(Kids.ink)
                            .overlay(Capsule().stroke(Kids.sun, lineWidth: 3))
                    )
                    .shadow(color: Kids.ink.opacity(0.21), radius: 0, x: 0, y: 5)
                    .rotationEffect(.degrees(-2))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)

                // Sticker title
                VStack(spacing: -2) {
                    StickerWord(text: champion.name.uppercased(), fill: Kids.sun, fontSize: isIPad ? 70 : 50, tilt: -5)
                        .rotationEffect(.degrees(appeared ? -5 : -25))
                        .scaleEffect(appeared ? 1 : 0.2)
                    StickerWord(text: "WINS IT ALL!", fill: Kids.pink, fontSize: isIPad ? 52 : 36, tilt: 3)
                        .rotationEffect(.degrees(appeared ? 3 : 20))
                        .scaleEffect(appeared ? 1 : 0.2)
                }
                .opacity(appeared ? 1 : 0)
                .padding(.top, 4)

                // Trophy + champion on pedestal
                ZStack(alignment: .top) {
                    VStack(spacing: -4) {
                        // Trophy floating above
                        Text("🏆").font(.system(size: 50))
                            .offset(y: trophyBob)
                            .shadow(color: Kids.ink.opacity(0.21), radius: 0, x: 0, y: 4)

                        // Lion bubble with double ring
                        ZStack {
                            Circle().fill(Kids.sun).frame(width: isIPad ? 230 : 180, height: isIPad ? 230 : 180)
                            Circle().fill(.white).frame(width: isIPad ? 215 : 168, height: isIPad ? 215 : 168)
                            Circle()
                                .fill(LinearGradient(colors: [.white, Color(hex: "#FFE89A")],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(width: isIPad ? 195 : 150, height: isIPad ? 195 : 150)
                                .overlay(Circle().stroke(Kids.ink, lineWidth: isIPad ? 6 : 5))
                            // Image-aware avatar: bundled artwork → custom-creature photo → emoji.
                            Group {
                                if let assetName = champion.creatureAssetName,
                                   let ui = UIImage(named: assetName) {
                                    Image(uiImage: ui).resizable().scaledToFill()
                                } else if champion.isCustom, let url = champion.imageURL {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img):
                                            img.resizable().scaledToFill()
                                        default:
                                            Text(champion.emoji).font(.system(size: isIPad ? 128 : 100))
                                        }
                                    }
                                } else {
                                    Text(champion.emoji).font(.system(size: isIPad ? 128 : 100))
                                }
                            }
                            .frame(width: isIPad ? 168 : 130, height: isIPad ? 168 : 130)
                            .clipShape(Circle())
                            // Glossy sheen
                            Circle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 40, height: 64)
                                .offset(x: -28, y: -34)
                                .rotationEffect(.degrees(-25))
                                .blur(radius: 4)
                                .frame(width: isIPad ? 195 : 150, height: isIPad ? 195 : 150)
                                .clipShape(Circle())
                        }
                        .scaleEffect(lionPulse)

                        // Pedestal
                        ZStack {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 14, bottomLeadingRadius: 4,
                                bottomTrailingRadius: 4, topTrailingRadius: 14,
                                style: .continuous
                            )
                            .fill(Kids.sun)
                            .overlay(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 14, bottomLeadingRadius: 4,
                                    bottomTrailingRadius: 4, topTrailingRadius: 14,
                                    style: .continuous
                                ).fill(Kids.sheen)
                            )
                            .overlay(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 14, bottomLeadingRadius: 4,
                                    bottomTrailingRadius: 4, topTrailingRadius: 14,
                                    style: .continuous
                                ).stroke(Kids.ink, lineWidth: isIPad ? 5 : 4)
                            )
                            Text("1st PLACE")
                                .font(Kids.fredoka(isIPad ? 24 : 18, weight: .bold))
                                .tracking(2)
                                .foregroundColor(Kids.ink)
                        }
                        .frame(width: isIPad ? 280 : 220, height: isIPad ? 52 : 42)
                        .shadow(color: Kids.ink.opacity(0.18), radius: 0, x: 0, y: 6)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

                // Champion's path card
                VStack(spacing: 8) {
                    Text("\(champion.name)'s Champion Path")
                        .font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold))
                        .foregroundColor(Kids.ink)

                    HStack(spacing: 4) {
                        Text(champion.emoji).font(.system(size: isIPad ? 34 : 26))
                        ForEach(Array(pathAnimals.prefix(5).enumerated()), id: \.offset) { _, a in
                            Text("›")
                                .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                                .foregroundColor(Kids.grass)
                            ZStack(alignment: .topTrailing) {
                                Circle().fill(Color(hex: "#F6F0FF"))
                                    .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                                    .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)
                                Text(a.emoji).font(.system(size: isIPad ? 20 : 16))
                                    .opacity(0.6)
                                    .frame(width: isIPad ? 40 : 32, height: isIPad ? 40 : 32)
                                Circle().fill(Kids.grass)
                                    .overlay(Circle().stroke(Kids.ink, lineWidth: 1.5))
                                    .frame(width: 14, height: 14)
                                    .overlay(Text("✓").font(.system(size: 8, weight: .bold)).foregroundColor(Kids.ink))
                                    .offset(x: 4, y: -4)
                            }
                        }
                        Text("🏆").font(.system(size: isIPad ? 28 : 22))
                    }

                    Text("\(pathAnimals.count) WINS IN A ROW! 🔥")
                        .font(Kids.fredoka(13, weight: .bold))
                        .foregroundColor(Kids.pink)
                        .padding(.top, 2)
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Kids.ink, lineWidth: 4))
                )
                .shadow(color: Kids.ink.opacity(0.15), radius: 0, x: 0, y: 8)
                .padding(.horizontal, 18)
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)

                Spacer(minLength: 6)

                // CTAs
                KidButton(title: "CLAIM GOLDEN TROPHY", icon: "🏆", color: Kids.grass, size: .lg) {
                    HapticsService.shared.success()
                    onClaim()
                }
                .padding(.horizontal, 20)

                HStack(spacing: 8) {
                    KidButton(title: "SHARE", icon: nil, color: Kids.pink, size: .sm) { onShare() }
                    KidButton(title: "PLAY AGAIN", icon: nil, color: Kids.sky, size: .sm) { onPlayAgain() }
                }
                .padding(.bottom, 30)
                }
                .frame(maxWidth: isIPad ? 640 : .infinity)
                Spacer(minLength: 0)
            }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.05)) {
                appeared = true
            }
            // Perpetual celebration motion is skipped under Reduce Motion —
            // the entrance spring above is enough.
            if !UIAccessibility.isReduceMotionEnabled {
                withAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) {
                    raySpin = 360
                }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    trophyBob = -8
                }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    lionPulse = 1.04
                }
            }
            HapticsService.shared.success()
        }
    }
}

private struct SunRays: View {
    let count: Int
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width/2, y: geo.size.height * 0.4)
            let r = max(geo.size.width, geo.size.height) * 1.4
            ZStack {
                ForEach(0..<count, id: \.self) { i in
                    Path { p in
                        let a = Double(i) * (.pi * 2) / Double(count)
                        p.move(to: c)
                        p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                    }
                    .stroke(color, lineWidth: 26)
                }
            }
        }
    }
}

private struct Confetti: View {
    private let pieces: [(CGFloat, CGFloat, String, Double, CGFloat)] = [
        (30, 80, "🎉", -14, 30),(330, 90, "✨", 16, 26),(350, 180, "⭐", -8, 32),
        (20, 200, "🎊", 12, 28),(40, 760, "⭐", 10, 28),(330, 740, "🎉", -20, 30),
    ]
    var body: some View {
        GeometryReader { _ in
            ForEach(0..<pieces.count, id: \.self) { i in
                let p = pieces[i]
                Text(p.2)
                    .font(.system(size: p.4))
                    .rotationEffect(.degrees(p.3))
                    .position(x: p.0, y: p.1)
            }
        }
        .allowsHitTesting(false)
    }
}
