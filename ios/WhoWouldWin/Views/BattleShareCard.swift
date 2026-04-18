import SwiftUI
import UIKit

// MARK: - Share Card View (renders to UIImage via ImageRenderer)

/// A 390×560pt battle result card rendered for social sharing.
/// Always dark-themed regardless of device settings.
struct BattleShareCard: View {
    let fighter1: Animal
    let fighter2: Animal
    let result: BattleResult
    var environment: BattleEnvironment = .grassland
    var arenaEffectsEnabled: Bool = false
    var image1: UIImage? = nil
    var image2: UIImage? = nil

    // Palette — always dark
    private let bg          = Color(hex: "#07051A")
    private let orange      = Color(hex: "#FF5722")
    private let cyan        = Color(hex: "#00CFCF")
    private let gold        = Color(hex: "#FFD700")
    private let goldLight   = Color(hex: "#FFF0A0")

    private var isDraw: Bool { result.winner == "draw" }
    private var winnerAnimal: Animal  { result.winner == fighter1.id ? fighter1 : fighter2 }
    private var loserAnimal:  Animal  { result.winner == fighter1.id ? fighter2 : fighter1 }
    private var winnerAccent: Color   { result.winner == fighter1.id ? orange : cyan }
    private var loserAccent:  Color   { result.winner == fighter1.id ? cyan : orange }
    private var winnerImage:  UIImage? { result.winner == fighter1.id ? image1 : image2 }
    private var loserImage:   UIImage? { result.winner == fighter1.id ? image2 : image1 }

    private var winnerHP: Int { result.winnerHealthPercent }
    private var loserHP:  Int { result.loserHealthPercent }

    private var excerpt: String {
        let t = result.narration.trimmingCharacters(in: .whitespaces)
        return t.hasSuffix(".") ? t : t + "."
    }

    var body: some View {
        ZStack(alignment: .top) {

            // ── BACKGROUND ──────────────────────────────────────
            bg.ignoresSafeArea()

            // Diagonal split glow: orange top-left, cyan top-right
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    // Orange bloom — fighter 1 side
                    RadialGradient(
                        colors: [orange.opacity(0.45), .clear],
                        center: .init(x: 0.18, y: 0.28),
                        startRadius: 0, endRadius: w * 0.65
                    )
                    // Cyan bloom — fighter 2 side
                    RadialGradient(
                        colors: [cyan.opacity(0.35), .clear],
                        center: .init(x: 0.82, y: 0.28),
                        startRadius: 0, endRadius: w * 0.65
                    )
                    // Gold winner bloom at bottom
                    if !isDraw {
                        RadialGradient(
                            colors: [gold.opacity(0.18), .clear],
                            center: .init(x: 0.5, y: 0.88),
                            startRadius: 0, endRadius: w * 0.55
                        )
                    }
                }
                .frame(width: w, height: h)
            }

            // Star field
            Canvas { ctx, size in
                let stars: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.06,0.04,1.1),(0.18,0.02,0.9),(0.33,0.07,1.0),(0.51,0.03,1.3),
                    (0.66,0.06,0.8),(0.79,0.02,1.1),(0.91,0.05,1.0),(0.96,0.12,0.7),
                    (0.11,0.14,0.8),(0.44,0.11,1.0),(0.72,0.09,0.9),(0.88,0.16,1.1),
                    (0.03,0.22,0.6),(0.27,0.19,0.8),(0.58,0.17,0.7),(0.83,0.24,0.9),
                ]
                for s in stars {
                    let r = s.2
                    let rect = CGRect(x: s.0*size.width - r, y: s.1*size.height - r, width: r*2, height: r*2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.45)))
                }
            }

            VStack(spacing: 0) {

                // ── BRANDING BAR ──────────────────────────────────
                HStack(spacing: 5) {
                    Text("⚡").font(.system(size: 10))
                    Text("ANIMAL VS ANIMAL")
                        .font(Theme.bungee(11))
                        .tracking(2.5)
                        .foregroundColor(orange)
                    Text("⚡").font(.system(size: 10))
                }
                .padding(.top, 18)
                .padding(.bottom, 4)

                Text("Who Would Win?")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.32))
                    .tracking(1.5)
                    .padding(.bottom, 18)

                // ── FIGHTER PANELS ───────────────────────────────
                HStack(alignment: .top, spacing: 0) {
                    // Fighter 1 panel
                    fighterPanel(fighter1, uiImage: image1, accent: orange, align: .trailing)

                    // Centre VS badge
                    ZStack {
                        Circle()
                            .fill(bg)
                            .frame(width: 46, height: 46)
                            .overlay(Circle().stroke(
                                LinearGradient(colors: [orange.opacity(0.7), cyan.opacity(0.7)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 0)
                        Text("VS")
                            .font(.custom("PressStart2P-Regular", size: 10))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 30)
                    .zIndex(1)

                    // Fighter 2 panel
                    fighterPanel(fighter2, uiImage: image2, accent: cyan, align: .leading)
                }
                .padding(.bottom, 16)

                // ── HORIZONTAL RULE ──────────────────────────────
                gradientRule.padding(.bottom, 14)

                // ── RESULT ───────────────────────────────────────
                if isDraw {
                    drawBanner.padding(.bottom, 14)
                } else {
                    winnerBanner.padding(.bottom, 14)
                    healthBars.padding(.horizontal, 22).padding(.bottom, 14)
                }

                // ── NARRATION ────────────────────────────────────
                Text("\u{201C}\(excerpt)\u{201D}")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // ── FUN FACT ────────────────────────────────────────
                HStack(alignment: .top, spacing: 8) {
                    Text("✨")
                        .font(.system(size: 11))
                    Text(result.funFact)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(3)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.04))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.07), lineWidth: 1))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

                gradientRule.padding(.bottom, 10)

                // ── ENVIRONMENT BADGE (only when arena effects active) ──
                if arenaEffectsEnabled {
                    HStack(spacing: 5) {
                        Text(environment.emoji).font(.system(size: 12))
                        Text("\(environment.name.uppercased()) ARENA")
                            .font(Theme.bungee(9))
                            .foregroundColor(environment.accentColor)
                            .tracking(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(environment.accentColor.opacity(0.12))
                            .overlay(Capsule().stroke(environment.accentColor.opacity(0.3), lineWidth: 1))
                    )
                    .padding(.bottom, 10)
                }

                Spacer(minLength: 0)

                // ── FOOTER ───────────────────────────────────────
                HStack(spacing: 12) {
                    // QR code — scannable App Store link
                    if let qrImage = makeQRCode(size: 48) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(.white)
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("🐾 Animal vs Animal")
                            .font(Theme.bungee(11))
                            .foregroundColor(.white.opacity(0.85))
                        HStack(spacing: 4) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(orange)
                            Text("Download free on the App Store →")
                                .font(Theme.bungee(9))
                                .foregroundColor(orange.opacity(0.85))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(orange.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(orange.opacity(0.22), lineWidth: 1))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .frame(width: 390)
        .frame(minHeight: 560)
    }

    // MARK: - Sub-views

    private func fighterPanel(_ animal: Animal, uiImage: UIImage?, accent: Color, align: HorizontalAlignment) -> some View {
        let isWinner = !isDraw && animal.id == winnerAnimal.id
        let isLoser  = !isDraw && animal.id != winnerAnimal.id

        return VStack(spacing: 8) {
            // Result badge above avatar
            if isWinner {
                Text("👑 WINNER")
                    .font(Theme.bungee(8))
                    .foregroundColor(gold)
                    .tracking(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(gold.opacity(0.18)))
            } else if isLoser {
                Text("DEFEATED")
                    .font(Theme.bungee(8))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.07)))
            } else {
                // draw — spacer to keep layout consistent
                Color.clear.frame(height: 22)
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 118, height: 118)
                    .blur(radius: 16)

                if let img = uiImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(
                                    LinearGradient(colors: [accent, accent.opacity(0.3)],
                                                   startPoint: .top, endPoint: .bottom),
                                    lineWidth: isWinner ? 2.5 : 1.5)
                        )
                        .shadow(color: accent.opacity(isWinner ? 1.0 : 0.5), radius: isWinner ? 18 : 10, x: 0, y: 0)
                        .opacity(isLoser ? 0.65 : 1.0)
                } else {
                    Text(animal.emoji)
                        .font(.system(size: 78))
                        .shadow(color: accent.opacity(isWinner ? 1.0 : 0.5), radius: isWinner ? 18 : 10, x: 0, y: 0)
                        .opacity(isLoser ? 0.65 : 1.0)
                }
            }
            .frame(width: 110, height: 110)

            Text(animal.name.uppercased())
                .font(Theme.bungee(13))
                .foregroundColor(isLoser ? accent.opacity(0.5) : accent)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .shadow(color: accent.opacity(isWinner ? 0.5 : 0.2), radius: 4, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(accent.opacity(isWinner ? 0.10 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(accent.opacity(isWinner ? 0.35 : 0.12), lineWidth: isWinner ? 1.5 : 1)
                )
        )
        .padding(.horizontal, 10)
    }

    private var winnerBanner: some View {
        VStack(spacing: 4) {
            Text("🏆  WINNER")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(gold.opacity(0.75))
                .tracking(3)

            Text(winnerAnimal.name.uppercased())
                .font(Theme.bungee(36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [winnerAccent, gold, goldLight, gold, winnerAccent],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: gold.opacity(0.7), radius: 16, x: 0, y: 0)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 20)
        }
    }

    private var drawBanner: some View {
        VStack(spacing: 6) {
            Text("⚔️").font(.system(size: 40))
            Text("IT'S A DRAW!")
                .font(Theme.bungee(26))
                .foregroundStyle(
                    LinearGradient(colors: [orange, gold, cyan], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: gold.opacity(0.5), radius: 12, x: 0, y: 0)
        }
    }

    private var healthBars: some View {
        VStack(spacing: 6) {
            healthRow(name: winnerAnimal.name, pct: winnerHP, accent: winnerAccent)
            healthRow(name: loserAnimal.name,  pct: loserHP,  accent: loserAccent.opacity(0.65))
        }
    }

    private func healthRow(name: String, pct: Int, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text(name.uppercased())
                .font(Theme.bungee(8))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 68, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.7), accent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(pct) / 100)
                }
            }
            .frame(height: 7)

            Text("\(pct)%")
                .font(Theme.bungee(8))
                .foregroundColor(accent)
                .frame(width: 28, alignment: .leading)
        }
    }

    private func makeQRCode(size: CGFloat) -> UIImage? {
        let urlString = "https://apps.apple.com/app/id6761319389"
        guard
            let data = urlString.data(using: .isoLatin1),
            let filter = CIFilter(name: "CIQRCodeGenerator")
        else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scale = size / ciImage.extent.size.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        // UIImage(ciImage:) is lazy and stays blank inside ImageRenderer.
        // Force rasterisation through CIContext → CGImage first.
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private var gradientRule: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, orange.opacity(0.4), cyan.opacity(0.4), .clear],
                startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - Render to UIImage

    @MainActor
    static func render(fighter1: Animal, fighter2: Animal, result: BattleResult,
                       environment: BattleEnvironment = .grassland,
                       arenaEffectsEnabled: Bool = false,
                       image1: UIImage? = nil, image2: UIImage? = nil) -> UIImage? {
        let card = BattleShareCard(fighter1: fighter1, fighter2: fighter2, result: result,
                                   environment: environment, arenaEffectsEnabled: arenaEffectsEnabled,
                                   image1: image1, image2: image2)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

// MARK: - Preview

#Preview("Share Card") {
    let lion   = Animal(id: "lion",  name: "Lion",  emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4)
    let tiger  = Animal(id: "tiger", name: "Tiger", emoji: "🐯", category: .land, pixelColor: "#FF6B00", size: 4)
    let result = BattleResult(
        winner: "tiger",
        narration: "The tiger's incredible strength and deadly claws give it the edge in this epic showdown with powerful attacks and lightning-fast strikes.",
        funFact: "Tigers are the largest cats in the world and can weigh up to 660 pounds!",
        winnerHealthPercent: 72,
        loserHealthPercent: 18
    )
    return BattleShareCard(fighter1: lion, fighter2: tiger, result: result)
        .environment(\.colorScheme, .dark)
}

// MARK: - Share Sheet (UIActivityViewController wrapper)

struct BattleShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    var caption: String = ""

    private var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id6761319389")!
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var items: [Any] = [image]
        let text = caption.isEmpty
            ? "Who would win? 🔥 Find out in Animal vs Animal!"
            : caption
        items.append("\(text)\n\(appStoreURL.absoluteString)")
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
