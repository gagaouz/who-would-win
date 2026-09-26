import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - TournamentShareCard
//
// Restyled to match the new Kids aesthetic. Shows the final state of a completed
// tournament — champion hero on a sunburst, compact Kids-styled bracket diagram,
// stats row, grand-champion payout pill, and an App-Store QR-code footer.

struct TournamentShareCard: View {
    let tournament: Tournament
    let grandChampionPayout: Int
    let netCoinDelta: Int

    private var champion: Animal? {
        tournament.bracket.rounds.last?.first?.winningFighter
    }

    var body: some View {
        ZStack(alignment: .top) {
            Kids.cream.ignoresSafeArea()

            // Confetti sprinkles
            confetti

            VStack(spacing: 0) {

                // Brand pill
                HStack(spacing: 5) {
                    RetroSymbol("🏆", size: 12)
                    Text("TOURNAMENT CHAMPION")
                        .font(Kids.fredoka(11, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(Kids.sun)
                    RetroSymbol("🏆", size: 12)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(
                    RetroPanelShape().fill(Kids.ink)
                        .overlay(RetroPanelShape().stroke(Kids.sun, lineWidth: 2))
                )
                .padding(.top, 24)

                Text("who would win?")
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .tracking(1.5)
                    .padding(.top, 6)
                    .padding(.bottom, 14)

                // Champion hero
                championHero
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)

                // Bracket diagram
                bracketSummary
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)

                // Stats row
                HStack(spacing: 8) {
                    statBox(label: "FIGHTERS", value: "\(tournament.bracket.allFighters.count)", color: Kids.sky)
                    statBox(label: "ROUNDS", value: "\(tournament.size.totalRounds)", color: Kids.grape)
                    statBox(label: "NET",
                            value: netCoinDelta >= 0 ? "+\(netCoinDelta)" : "\(netCoinDelta)",
                            color: netCoinDelta >= 0 ? Kids.grass : Kids.pink,
                            valueSuffix: "🪙")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

                Spacer(minLength: 0)

                // Footer
                footer
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: 390)
        .frame(minHeight: 680)
    }

    // MARK: - Champion hero

    private var championHero: some View {
        VStack(spacing: 10) {
            Text("CHAMPION")
                .font(Kids.fredoka(11, weight: .bold))
                .foregroundColor(Kids.sun)
                .tracking(2.5)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(RetroPanelShape().fill(Kids.ink).overlay(RetroPanelShape().stroke(Kids.sun, lineWidth: 1.5)))

            Group {
                if let c = champion {
                    AnimalBubble(animal: c, size: 178, tint: Kids.sun)
                }
            }
            .compositingGroup().shadow(color: Kids.shadow.opacity(0.15), radius: 4, x: 0, y: 6)

            StickerWord(text: (champion?.name ?? "???").uppercased(),
                        fill: Kids.sun, fontSize: 32, tilt: -3)
                .rotationEffect(.degrees(-3))

            StickerWord(text: "WINS IT ALL!", fill: Kids.pink, fontSize: 22, tilt: 2)
                .rotationEffect(.degrees(2))

            if tournament.grandChampion != nil, grandChampionPayout > 0 {
                HStack(spacing: 5) {
                    Text("GRAND CHAMPION HIT")
                        .font(Kids.fredoka(9, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .tracking(1.5)
                    Text("+\(grandChampionPayout)")
                        .font(Kids.fredoka(11, weight: .bold))
                        .foregroundColor(Kids.ink)
                    KidsGoldCoin(size: 12)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    RetroPanelShape().fill(Kids.sun)
                        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                )
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RetroPanelShape(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .overlay(RetroPanelShape(cornerRadius: 24, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.11), radius: 4, x: 0, y: 5)
    }

    // MARK: - Bracket summary (Kids-styled compact)

    private var bracketSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BRACKET")
                    .font(Kids.fredoka(11, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .tracking(1)
                Spacer()
                Text("\(tournament.size.rawValue) FIGHTERS")
                    .font(Kids.fredoka(10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .tracking(1)
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(tournament.bracket.rounds.enumerated()), id: \.offset) { (roundIdx, round) in
                    VStack(spacing: 5) {
                        Text(roundLabel(roundIdx))
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .font(Kids.fredoka(8, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .tracking(1)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
                        ForEach(round) { matchup in
                            matchupMiniCard(matchup)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(
            RetroPanelShape(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 4)
    }

    private func matchupMiniCard(_ m: Matchup) -> some View {
        let winner = m.winningFighter
        return VStack(spacing: 2) {
            fighterMiniRow(m.fighter1, isWinner: winner?.id == m.fighter1.id)
            Rectangle().fill(Kids.ink.opacity(0.15)).frame(height: 0.8)
            fighterMiniRow(m.fighter2, isWinner: winner?.id == m.fighter2.id)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 5)
        .background(
            RetroPanelShape(cornerRadius: 8, style: .continuous)
                .fill(Kids.panel)
                .overlay(RetroPanelShape(cornerRadius: 8, style: .continuous).stroke(Kids.outline, lineWidth: 1))
        )
    }

    private func fighterMiniRow(_ a: Animal, isWinner: Bool) -> some View {
        HStack(spacing: 3) {
            RetroCreatureArtwork(animal: a, size: 18)
            Text(a.name)
                .font(Kids.nunito(9, weight: .bold))
                .foregroundColor(isWinner ? Kids.ink : Kids.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if isWinner {
                RetroSymbol("👑", size: 7)
            }
        }
    }

    private func roundLabel(_ idx: Int) -> String {
        tournament.size.roundName(for: idx).uppercased()
    }

    // MARK: - Stats

    private func statBox(label: String, value: String, color: Color, valueSuffix: String? = nil) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(Kids.fredoka(9, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .tracking(1)
            HStack(spacing: 2) {
                Text(value)
                    .font(Kids.fredoka(15, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let s = valueSuffix {
                    if s == "🪙" { KidsGoldCoin(size: 12) }
                    else { RetroSymbol(s, size: 12) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RetroPanelShape(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(color, lineWidth: 2.5))
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.07), radius: 4, x: 0, y: 3)
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

    // MARK: - Decoration

    private var sunRays: some View {
        GeometryReader { geo in
            let c = CGPoint(x: geo.size.width/2, y: geo.size.height * 0.25)
            let r = max(geo.size.width, geo.size.height) * 1.2
            ZStack {
                ForEach(0..<16, id: \.self) { i in
                    Path { p in
                        let a = Double(i) * (.pi * 2) / 16
                        p.move(to: c)
                        p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                    }
                    .stroke(Color.white, lineWidth: 22)
                }
            }
        }
    }

    private var confetti: some View {
        let pieces: [(String, CGFloat, CGFloat, Double, CGFloat)] = [
            ("✨", 30, 80, -14, 22), ("⭐", 350, 100, 16, 20),
            ("🎉", 60, 600, -8, 26), ("✨", 340, 590, 14, 18),
            ("⭐", 18, 360, -10, 16), ("✨", 360, 380, 12, 16),
            ("🎊", 28, 480, 8, 22),  ("⭐", 340, 470, -8, 18),
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
    static func renderWithCachedImages(tournament: Tournament,
                                       grandChampionPayout: Int,
                                       netCoinDelta: Int) async -> UIImage? {
        await RetroAssetStore.shared.prepare(tournament.bracket.allFighters)
        return render(tournament: tournament,
                      grandChampionPayout: grandChampionPayout,
                      netCoinDelta: netCoinDelta)
    }

    @MainActor
    static func render(tournament: Tournament,
                       grandChampionPayout: Int,
                       netCoinDelta: Int) -> UIImage? {
        let card = TournamentShareCard(
            tournament: tournament,
            grandChampionPayout: grandChampionPayout,
            netCoinDelta: netCoinDelta
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
