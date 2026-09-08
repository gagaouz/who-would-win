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

    private var championImage: UIImage? {
        guard let c = champion, let name = c.creatureAssetName else { return nil }
        return UIImage(named: name)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Sunburst-style radial background
            RadialGradient(
                colors: [Kids.sun, Color(hex: "#FF8AC5"), Color(hex: "#4A2E7A")],
                center: .init(x: 0.5, y: 0.25),
                startRadius: 30, endRadius: 540
            )
            .ignoresSafeArea()

            // Rays behind the champion
            sunRays
                .opacity(0.18)
                .allowsHitTesting(false)

            // Confetti sprinkles
            confetti

            VStack(spacing: 0) {

                // Brand pill
                HStack(spacing: 5) {
                    Text("🏆").font(.system(size: 12))
                    Text("TOURNAMENT CHAMPION")
                        .font(Kids.fredoka(11, weight: .bold))
                        .tracking(2.5)
                        .foregroundColor(Kids.sun)
                    Text("🏆").font(.system(size: 12))
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(
                    Capsule().fill(Kids.ink)
                        .overlay(Capsule().stroke(Kids.sun, lineWidth: 2))
                )
                .padding(.top, 24)

                Text("who would win?")
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
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
            Text("👑 CHAMPION 👑")
                .font(Kids.fredoka(11, weight: .bold))
                .foregroundColor(Kids.sun)
                .tracking(2.5)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Capsule().fill(Kids.ink).overlay(Capsule().stroke(Kids.sun, lineWidth: 1.5)))

            ZStack {
                Circle()
                    .fill(Kids.sun)
                    .frame(width: 178, height: 178)
                Circle()
                    .fill(.white)
                    .frame(width: 162, height: 162)
                Circle()
                    .stroke(Kids.ink, lineWidth: 5)
                    .frame(width: 178, height: 178)
                Group {
                    if let img = championImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else if let c = champion {
                        Text(c.emoji).font(.system(size: 100))
                    }
                }
                .frame(width: 148, height: 148)
                .clipShape(Circle())
                // Glossy sheen blob
                Ellipse()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 60)
                    .offset(x: -30, y: -34)
                    .rotationEffect(.degrees(-25))
                    .blur(radius: 4)
                    .frame(width: 148, height: 148)
                    .clipShape(Circle())
            }
            .shadow(color: Kids.ink.opacity(0.15), radius: 0, x: 0, y: 6)

            StickerWord(text: (champion?.name ?? "???").uppercased(),
                        fill: Kids.sun, fontSize: 32, tilt: -3)
                .rotationEffect(.degrees(-3))

            StickerWord(text: "WINS IT ALL!", fill: Kids.pink, fontSize: 22, tilt: 2)
                .rotationEffect(.degrees(2))

            if tournament.grandChampion != nil, grandChampionPayout > 0 {
                HStack(spacing: 5) {
                    Text("✨ GRAND CHAMPION HIT")
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
                    Capsule().fill(Kids.sun)
                        .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
                )
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Kids.ink, lineWidth: 3))
        )
        .shadow(color: Kids.ink.opacity(0.11), radius: 0, x: 0, y: 5)
    }

    // MARK: - Bracket summary (Kids-styled compact)

    private var bracketSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🌳 BRACKET")
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
                            .font(Kids.fredoka(8, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .tracking(1)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Capsule().fill(Kids.sun).overlay(Capsule().stroke(Kids.ink, lineWidth: 1)))
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
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
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: "#F7F2FF"))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Kids.ink.opacity(0.25), lineWidth: 1))
        )
    }

    private func fighterMiniRow(_ a: Animal, isWinner: Bool) -> some View {
        HStack(spacing: 3) {
            ZStack {
                Circle().fill(.white)
                    .overlay(Circle().stroke(Kids.ink, lineWidth: 1))
                    .frame(width: 14, height: 14)
                if let assetName = a.creatureAssetName, let img = UIImage(named: assetName) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 11, height: 11).clipShape(Circle())
                } else {
                    Text(a.emoji).font(.system(size: 8))
                }
            }
            Text(a.name)
                .font(Kids.fredoka(7, weight: .bold))
                .foregroundColor(isWinner ? Kids.ink : Kids.inkSoft.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            if isWinner {
                Text("👑").font(.system(size: 7))
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
                    Text(s).font(.system(size: 12))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
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
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Kids.ink, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("🦁 Animal vs Animal")
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Kids.sun)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
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
                Text(p.0)
                    .font(.system(size: p.4))
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
