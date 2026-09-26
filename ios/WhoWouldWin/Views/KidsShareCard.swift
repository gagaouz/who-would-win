import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - KidsShareCard
//
// Comprehensive battle-result share card in the Animal Arena Jr. aesthetic.
// Mirrors the depth of the legacy BattleShareCard: both fighter panels with
// WINNER/DEFEATED badges, big winner banner, health bars, narration, fun fact,
// arena badge (when relevant), and an App-Store QR-code footer.

struct KidsShareCard: View {
    let fighter1: Animal
    let fighter2: Animal
    let result: BattleResult
    var environment: BattleEnvironment = .grassland
    var arenaEffectsEnabled: Bool = false
    // Kept for source compatibility; rendering reads the prepared retro art cache.
    var fighter1Image: UIImage? = nil
    var fighter2Image: UIImage? = nil

    private var isDraw: Bool { result.winner == "draw" }
    private var winnerAnimal: Animal { result.winner == fighter1.id ? fighter1 : fighter2 }
    private var loserAnimal:  Animal { result.winner == fighter1.id ? fighter2 : fighter1 }
    private var winnerHP: Int { result.winnerHealthPercent }
    private var loserHP:  Int { result.loserHealthPercent }

    private var excerpt: String {
        let t = result.narration.withoutEmoji.trimmingCharacters(in: .whitespaces)
        // Add a period only when the text doesn't already end with terminal
        // punctuation — narration usually ends with "!", which made "…wins!."
        guard let last = t.last, !".!?…".contains(last) else { return t }
        return t + "."
    }

    var body: some View {
        ZStack(alignment: .top) {
            Kids.cream.ignoresSafeArea()

            // Confetti sprinkles for delight
            confetti

            VStack(spacing: 0) {
                // Branding
                HStack(spacing: 5) {
                    Image(systemName: "sparkle").foregroundColor(Kids.sun)
                    Text("ANIMAL VS ANIMAL")
                        .font(Kids.fredoka(11, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(.white)
                    Image(systemName: "sparkle").foregroundColor(Kids.sun)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(RetroPanelShape().fill(Kids.ink).overlay(RetroPanelShape().stroke(.white, lineWidth: 2)))
                .padding(.top, 24)

                Text("who would win?")
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(Kids.ink.opacity(0.6))
                    .tracking(1.5)
                    .padding(.top, 6)
                    .padding(.bottom, 14)

                // Fighter row
                HStack(alignment: .top, spacing: 0) {
                    fighterPanel(fighter1, customImage: fighter1Image, accent: Kids.sun)
                    StarSticker(text: "VS", size: 52, fill: Kids.pink)
                        .padding(.top, 28)
                        .zIndex(1)
                    fighterPanel(fighter2, customImage: fighter2Image, accent: Kids.peach)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

                // Result banner
                if isDraw { drawBanner.padding(.bottom, 12) }
                else      { winnerBanner.padding(.bottom, 10) }

                // Health bars
                if !isDraw {
                    healthBars
                        .padding(.horizontal, 22)
                        .padding(.bottom, 12)
                }

                // Narration card
                narrationCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // Fun fact card
                funFactCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                // Arena badge
                if arenaEffectsEnabled {
                    HStack(spacing: 5) {
                        RetroSymbol(environment.emoji, size: 13)
                        Text("\(environment.name.uppercased()) ARENA")
                            .font(Kids.fredoka(10, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .tracking(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(
                        RetroPanelShape().fill(.white)
                            .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                    )
                    .padding(.bottom, 10)
                }

                Spacer(minLength: 0)

                // QR + App Store footer
                footer
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: 390)
        .frame(minHeight: 620)
    }

    // MARK: - Fighter panel

    private func fighterPanel(_ animal: Animal, customImage: UIImage? = nil, accent: Color) -> some View {
        let isWinner = !isDraw && animal.id == winnerAnimal.id
        let isLoser  = !isDraw && animal.id != winnerAnimal.id
        return VStack(spacing: 6) {
            // Result badge above
            if isWinner {
                Text("WINNER")
                    .font(Kids.fredoka(9, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .tracking(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
            } else if isLoser {
                Text("DEFEATED")
                    .font(Kids.fredoka(9, weight: .bold))
                    .foregroundColor(Kids.ink.opacity(0.7))
                    .tracking(1)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RetroPanelShape().fill(Color.white.opacity(0.7)).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
            } else {
                Color.clear.frame(height: 20)
            }

            AnimalBubble(animal: animal, size: 112, tint: accent)
            .opacity(isLoser ? 0.6 : 1.0)
            .compositingGroup().shadow(color: Kids.shadow.opacity(0.11), radius: 4, x: 0, y: 5)

            Text(animal.name.uppercased())
                .font(Kids.fredoka(13, weight: .bold))
                .foregroundColor(Kids.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(
                    RetroPanelShape().fill(accent)
                        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                )
                .opacity(isLoser ? 0.7 : 1.0)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RetroPanelShape(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(isWinner ? 0.85 : 0.55))
                .overlay(
                    RetroPanelShape(cornerRadius: 22, style: .continuous)
                        .stroke(isWinner ? Kids.grassDeep : Kids.outline, lineWidth: isWinner ? 2 : 1)
                )
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(isWinner ? 0.18 : 0.1), radius: 4, x: 0, y: 4)
    }

    // MARK: - Banners

    private var winnerBanner: some View {
        VStack(spacing: 4) {
            Text("CHAMPION")
                .font(Kids.fredoka(11, weight: .bold))
                .foregroundColor(.white)
                .tracking(3)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(RetroPanelShape().fill(Kids.ink))

            // Custom-creature names can be long; the card is fixed-width and
            // renders synchronously, so clamp rather than let the sticker
            // bleed off the edges.
            StickerWord(text: "\(winnerAnimal.name.uppercased()) WINS!",
                        fill: Kids.sun, fontSize: winnerAnimal.name.count > 12 ? 22 : 30, tilt: -2)
                .rotationEffect(.degrees(-2))
                .frame(maxWidth: 350)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private var drawBanner: some View {
        VStack(spacing: 6) {
            RetroSymbol("🤝", size: 44)
            StickerWord(text: "IT'S A TIE!", fill: Kids.sky, fontSize: 28, tilt: -2)
                .rotationEffect(.degrees(-2))
        }
    }

    // MARK: - Health bars

    private var healthBars: some View {
        VStack(spacing: 6) {
            healthRow(name: winnerAnimal.name, pct: winnerHP, accent: Kids.grass)
            healthRow(name: loserAnimal.name,  pct: loserHP,  accent: Kids.pink)
        }
    }

    private func healthRow(name: String, pct: Int, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text(name.uppercased())
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.ink)
                .frame(width: 78, alignment: .trailing)
                .lineLimit(1).minimumScaleFactor(0.6)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RetroPanelShape().fill(Color.white.opacity(0.5))
                        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1))
                    RetroPanelShape()
                        .fill(accent)
                        .frame(width: max(2, geo.size.width * CGFloat(pct) / 100))
                }
            }
            .frame(height: 9)
            Text("\(pct)%")
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.ink)
                .frame(width: 32, alignment: .leading)
        }
    }

    // MARK: - Narration + fun fact

    private var narrationCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BATTLE STORY")
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RetroPanelShape().fill(Kids.pink).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
            Text("\u{201C}\(excerpt)\u{201D}")
                .font(Kids.nunito(11, weight: .bold))
                .foregroundColor(Kids.ink)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RetroPanelShape(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
    }

    private var funFactCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FUN FACT")
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
            Text(result.funFact.withoutEmoji)
                .font(Kids.nunito(11, weight: .bold))
                .foregroundColor(Kids.ink)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RetroPanelShape(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let qrImage = makeQRCode(size: 52) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .padding(5)
                    .background(RetroPanelShape(cornerRadius: 10).fill(.white))
                    .overlay(RetroPanelShape(cornerRadius: 10).stroke(Kids.outline, lineWidth: 1.25))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Animal vs Animal")
                    .font(Kids.fredoka(13, weight: .bold))
                    .foregroundColor(Kids.ink)
                HStack(spacing: 4) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text("Free on the App Store →")
                        .font(Kids.fredoka(11, weight: .bold))
                        .foregroundColor(Kids.ink)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(
            RetroPanelShape(cornerRadius: 14, style: .continuous)
                .fill(Kids.sun)
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
    }

    // MARK: - Confetti

    private var confetti: some View {
        let pieces: [(String, CGFloat, CGFloat, Double, CGFloat)] = [
            ("✨", 30, 80, -14, 22), ("⭐", 350, 100, 16, 20),
            ("🎉", 60, 540, -8, 26), ("✨", 340, 530, 14, 18),
            ("⭐", 18, 300, -10, 16), ("✨", 360, 320, 12, 16),
            ("🎊", 28, 440, 8, 22),  ("⭐", 340, 430, -8, 18),
        ]
        return ZStack {
            ForEach(0..<pieces.count, id: \.self) { i in
                let p = pieces[i]
                RetroSymbol(p.0, size: p.4)
                    .rotationEffect(.degrees(p.3))
                    .position(x: p.1, y: p.2)
                    .opacity(0.85)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - QR

    private func makeQRCode(size: CGFloat) -> UIImage? {
        let urlString = "https://apps.apple.com/app/id6761319389"
        guard let data = urlString.data(using: .isoLatin1) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let ciImage = filter.outputImage else { return nil }
        let scale = size / ciImage.extent.size.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // MARK: - Renderer

    @MainActor
    static func render(fighter1: Animal, fighter2: Animal, result: BattleResult,
                       environment: BattleEnvironment = .grassland,
                       arenaEffectsEnabled: Bool = false,
                       fighter1Image: UIImage? = nil,
                       fighter2Image: UIImage? = nil) -> UIImage? {
        let card = KidsShareCard(
            fighter1: fighter1, fighter2: fighter2, result: result,
            environment: environment, arenaEffectsEnabled: arenaEffectsEnabled,
            fighter1Image: fighter1Image, fighter2Image: fighter2Image
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Prepare pixel artwork before the synchronous ImageRenderer pass.
    @MainActor
    static func renderWithCachedImages(fighter1: Animal, fighter2: Animal, result: BattleResult,
                                       environment: BattleEnvironment = .grassland,
                                       arenaEffectsEnabled: Bool = false) async -> UIImage? {
        await RetroAssetStore.shared.prepare([fighter1, fighter2])
        return render(
            fighter1: fighter1, fighter2: fighter2, result: result,
            environment: environment, arenaEffectsEnabled: arenaEffectsEnabled,
            fighter1Image: RetroAssetStore.shared.image(for: fighter1),
            fighter2Image: RetroAssetStore.shared.image(for: fighter2)
        )
    }
}
