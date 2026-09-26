import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - MeleeShareCard
//
// Shareable team-battle result card in the Animal Arena Jr. aesthetic.
// Mirrors KidsShareCard but for N-vs-M rosters: brand pill, big winner banner,
// MVP hero portrait, both team rosters with health bars, narration excerpt,
// fun-fact card, and an App-Store QR-code footer.

struct MeleeShareCard: View {
    let teamA: [Animal]
    let teamB: [Animal]
    let result: MeleeResult
    // Kept for source compatibility; portraits read the shared retro art cache.
    var teamAImages: [UIImage?] = []
    var teamBImages: [UIImage?] = []

    private var winningIsA: Bool { result.winningTeam == .A }
    private var winningTeam: [Animal] { winningIsA ? teamA : teamB }
    private var winningImages: [UIImage?] { winningIsA ? teamAImages : teamBImages }

    private var mvpAnimal: Animal? {
        winningTeam.first(where: { $0.id == result.mvp }) ?? winningTeam.first
    }
    private var narrationExcerpt: String {
        let t = result.narration.withoutEmoji.trimmingCharacters(in: .whitespaces)
        return t.hasSuffix(".") ? t : t + "."
    }

    var body: some View {
        ZStack(alignment: .top) {
            Kids.cream.ignoresSafeArea()

            // Confetti sprinkles for delight
            confetti

            VStack(spacing: 0) {
                // Branding pill
                HStack(spacing: 5) {
                    RetroSymbol("⚔️", size: 12)
                    Text("MELEE MODE")
                        .font(Kids.fredoka(11, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(.white)
                    RetroSymbol("⚔️", size: 12)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(RetroPanelShape().fill(Kids.ink).overlay(RetroPanelShape().stroke(.white, lineWidth: 2)))
                .padding(.top, 24)

                Text("who would win? team battle")
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(Kids.ink.opacity(0.6))
                    .tracking(1.5)
                    .padding(.top, 6)
                    .padding(.bottom, 10)

                // Crown + winner banner
                RetroSymbol("👑", size: 42)
                StickerWord(text: "TEAM \(result.winningTeam.rawValue) WINS!",
                            fill: Kids.sun, fontSize: 32, tilt: -2)
                    .rotationEffect(.degrees(-2))
                    .padding(.bottom, 12)

                // MVP hero
                mvpHero
                    .padding(.bottom, 14)

                // Both team rows
                VStack(spacing: 10) {
                    teamRow(label: "TEAM A", team: teamA, images: teamAImages,
                            tint: Kids.sun, isWinner: winningIsA,
                            healthPct: result.teamAHealth)
                    teamRow(label: "TEAM B", team: teamB, images: teamBImages,
                            tint: Kids.pink, isWinner: !winningIsA,
                            healthPct: result.teamBHealth)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

                // Narration card
                narrationCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                // Fun fact card
                funFactCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                Spacer(minLength: 0)

                // Footer
                footer
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: 390)
        .frame(minHeight: 760)
    }

    // MARK: - MVP hero

    private var mvpHero: some View {
        VStack(spacing: 8) {
            Group {
                if let mvp = mvpAnimal {
                    AnimalBubble(animal: mvp, size: 144, tint: Kids.sun)
                }
            }
            .compositingGroup().shadow(color: Kids.ink.opacity(0.15), radius: 0, x: 0, y: 5)

            HStack(spacing: 5) {
                Text("MVP")
                    .font(Kids.fredoka(11, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .tracking(1.5)
                if let mvp = mvpAnimal {
                    Text("— \(mvp.name.uppercased())")
                        .font(Kids.fredoka(11, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(
                RetroPanelShape().fill(Kids.sun)
                    .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2))
            )
        }
    }

    // MARK: - Team rows

    private func teamRow(label: String, team: [Animal], images: [UIImage?],
                         tint: Color, isWinner: Bool, healthPct: Int) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(Kids.fredoka(11, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .tracking(1.5)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(RetroPanelShape().fill(tint).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))
                if isWinner {
                    Text("WINNERS")
                        .font(Kids.fredoka(9, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .tracking(1)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5)))
                } else {
                    Text("DEFEATED")
                        .font(Kids.fredoka(9, weight: .bold))
                        .foregroundColor(Kids.ink.opacity(0.7))
                        .tracking(1)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RetroPanelShape().fill(Color.white.opacity(0.7)).overlay(RetroPanelShape().stroke(Kids.ink.opacity(0.4), lineWidth: 1.5)))
                }
                Spacer(minLength: 0)
                Text("\(healthPct)%")
                    .font(Kids.fredoka(11, weight: .bold))
                    .foregroundColor(Kids.ink)
            }

            // Roster portraits
            HStack(spacing: 6) {
                ForEach(Array(team.enumerated()), id: \.offset) { (idx, animal) in
                    let img = idx < images.count ? images[idx] : nil
                    rosterPortrait(animal: animal, customImage: img, accent: tint)
                }
                Spacer(minLength: 0)
            }

            // Health bar
            healthBar(pct: healthPct, accent: isWinner ? Kids.grass : tint)
        }
        .padding(10)
        .background(
            RetroPanelShape(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isWinner ? 0.92 : 0.55))
                .overlay(
                    RetroPanelShape(cornerRadius: 18, style: .continuous)
                        .stroke(Kids.ink, lineWidth: isWinner ? 3 : 2)
                )
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(isWinner ? 0.16 : 0.08), radius: 0, x: 0, y: 4)
        .opacity(isWinner ? 1.0 : 0.85)
    }

    private func rosterPortrait(animal: Animal, customImage: UIImage?, accent: Color) -> some View {
        let portraitSize: CGFloat = 56
        return VStack(spacing: 3) {
            AnimalBubble(animal: animal, size: portraitSize, tint: accent)
            Text(animal.name.uppercased())
                .font(Kids.fredoka(8, weight: .bold))
                .foregroundColor(Kids.ink)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(maxWidth: portraitSize + 6)
        }
    }

    private func healthBar(pct: Int, accent: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RetroPanelShape().fill(Color.white.opacity(0.65))
                    .overlay(RetroPanelShape().stroke(Kids.ink.opacity(0.3), lineWidth: 1))
                RetroPanelShape()
                    .fill(accent)
                    .frame(width: max(2, geo.size.width * CGFloat(pct) / 100))
            }
        }
        .frame(height: 10)
    }

    // MARK: - Narration + fun fact

    private var narrationCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BATTLE STORY")
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RetroPanelShape().fill(Kids.pink).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5)))
            Text("\u{201C}\(narrationExcerpt)\u{201D}")
                .font(Kids.nunito(13, weight: .bold))
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
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    private var funFactCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FUN FACT")
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5)))
            Text(result.funFact.withoutEmoji)
                .font(Kids.nunito(13, weight: .bold))
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
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
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
                    .overlay(RetroPanelShape(cornerRadius: 10).stroke(Kids.ink, lineWidth: 2))
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
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
    }

    // MARK: - Confetti

    private var confetti: some View {
        let pieces: [(String, CGFloat, CGFloat, Double, CGFloat)] = [
            ("✨", 30, 80, -14, 22), ("⭐", 350, 100, 16, 20),
            ("🎉", 60, 640, -8, 26), ("✨", 340, 620, 14, 18),
            ("⭐", 18, 360, -10, 16), ("✨", 360, 380, 12, 16),
            ("🎊", 28, 510, 8, 22),  ("⭐", 340, 500, -8, 18),
            ("⚔️", 24, 200, -6, 18), ("✨", 366, 220, 10, 14),
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

    // MARK: - Renderers

    @MainActor
    static func render(teamA: [Animal], teamB: [Animal], result: MeleeResult,
                       teamAImages: [UIImage?] = [], teamBImages: [UIImage?] = []) -> UIImage? {
        let card = MeleeShareCard(teamA: teamA, teamB: teamB, result: result,
                                  teamAImages: teamAImages, teamBImages: teamBImages)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Prepare the shared pixel art cache before synchronous export.
    @MainActor
    static func renderWithCachedImages(teamA: [Animal], teamB: [Animal],
                                       result: MeleeResult) async -> UIImage? {
        await RetroAssetStore.shared.prepare(teamA + teamB)
        return render(teamA: teamA, teamB: teamB, result: result)
    }
}
