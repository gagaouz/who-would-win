import SwiftUI
import UIKit

// MARK: - Tournament Share Card
//
// Shares the final state of a completed tournament — the champion hero card plus
// a compact bracket visualization. Mirrors the look of `BattleShareCard` (dark
// cosmic background, gold/orange/cyan palette, app store QR footer) so both
// share assets look like siblings.

struct TournamentShareCard: View {
    let tournament: Tournament
    let grandChampionPayout: Int
    let netCoinDelta: Int

    // Palette — always dark (matches BattleShareCard)
    private let bg          = Color(hex: "#07051A")
    private let orange      = Color(hex: "#FF5722")
    private let cyan        = Color(hex: "#00CFCF")
    private let gold        = Color(hex: "#FFD700")
    private let goldLight   = Color(hex: "#FFF0A0")

    private var champion: Animal? {
        tournament.bracket.rounds.last?.first?.winningFighter
    }

    private var championImage: UIImage? {
        guard let c = champion, let name = c.creatureAssetName else { return nil }
        return UIImage(named: name)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // ── BACKGROUND ──────────────────────────────────────
            bg.ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    RadialGradient(
                        colors: [gold.opacity(0.35), .clear],
                        center: .init(x: 0.5, y: 0.25),
                        startRadius: 0, endRadius: w * 0.75
                    )
                    RadialGradient(
                        colors: [orange.opacity(0.35), .clear],
                        center: .init(x: 0.12, y: 0.55),
                        startRadius: 0, endRadius: w * 0.6
                    )
                    RadialGradient(
                        colors: [cyan.opacity(0.25), .clear],
                        center: .init(x: 0.88, y: 0.55),
                        startRadius: 0, endRadius: w * 0.6
                    )
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
                    Text("TOURNAMENT RESULT")
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

                // ── CHAMPION HERO ─────────────────────────────────
                championHero
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)

                gradientRule.padding(.bottom, 14)

                // ── BRACKET VISUALIZATION ─────────────────────────
                bracketSummary
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                gradientRule.padding(.bottom, 12)

                // ── STATS ROW ─────────────────────────────────────
                HStack(spacing: 12) {
                    statBox(label: "FIGHTERS", value: "\(tournament.bracket.allFighters.count)")
                    statBox(label: "ROUNDS", value: "\(tournament.size.totalRounds)")
                    statBox(label: "NET",
                            value: netCoinDelta >= 0 ? "+\(netCoinDelta) coins" : "\(netCoinDelta) coins",
                            tint: netCoinDelta >= 0 ? Color(hex: "#69F0AE") : Color(hex: "#FF8A80"))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)

                Spacer(minLength: 0)

                // ── FOOTER ───────────────────────────────────────
                footer
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: 390)
        .frame(minHeight: 620)
    }

    // MARK: - Champion hero

    private var championHero: some View {
        VStack(spacing: 10) {
            Text("🏆 CHAMPION 🏆")
                .font(Theme.bungee(11))
                .foregroundColor(gold)
                .tracking(2.5)

            ZStack {
                Circle()
                    .fill(gold.opacity(0.22))
                    .frame(width: 168, height: 168)
                    .blur(radius: 22)

                if let img = championImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(
                                    LinearGradient(colors: [gold, goldLight, gold],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 2.5)
                        )
                        .shadow(color: gold.opacity(0.8), radius: 20, x: 0, y: 0)
                } else if let c = champion {
                    Text(c.emoji)
                        .font(.system(size: 120))
                        .shadow(color: gold.opacity(0.8), radius: 20, x: 0, y: 0)
                }
            }
            .frame(width: 168, height: 168)

            Text((champion?.name ?? "???").uppercased())
                .font(Theme.bungee(28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [orange, gold, goldLight, gold, orange],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: gold.opacity(0.8), radius: 16, x: 0, y: 0)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if tournament.grandChampion != nil, grandChampionPayout > 0 {
                HStack(spacing: 6) {
                    Text("GRAND CHAMPION HIT")
                        .font(Theme.bungee(8))
                        .foregroundColor(gold.opacity(0.75))
                        .tracking(1.5)
                    Text("+\(grandChampionPayout) coins")
                        .font(Theme.bungee(10))
                        .foregroundColor(Color(hex: "#69F0AE"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(gold.opacity(0.14)))
                .overlay(Capsule().stroke(gold.opacity(0.35), lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(gold.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(gold.opacity(0.35), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Bracket summary

    private var bracketSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BRACKET")
                    .font(Theme.bungee(10))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(2)
                Spacer()
                Text("\(tournament.size.rawValue) FIGHTERS")
                    .font(Theme.bungee(9))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(1.5)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(tournament.bracket.rounds.enumerated()), id: \.offset) { (roundIdx, round) in
                    VStack(spacing: 6) {
                        Text(roundLabel(roundIdx))
                            .font(Theme.bungee(7))
                            .foregroundColor(gold.opacity(0.65))
                            .tracking(1)
                        ForEach(round) { matchup in
                            matchupMiniCard(matchup)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func matchupMiniCard(_ m: Matchup) -> some View {
        let winner = m.winningFighter
        return VStack(spacing: 2) {
            fighterMiniRow(m.fighter1, isWinner: winner?.id == m.fighter1.id)
            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 0.5)
            fighterMiniRow(m.fighter2, isWinner: winner?.id == m.fighter2.id)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
        )
    }

    private func fighterMiniRow(_ a: Animal, isWinner: Bool) -> some View {
        HStack(spacing: 3) {
            if let assetName = a.creatureAssetName, let img = UIImage(named: assetName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Text(a.emoji).font(.system(size: 10))
            }
            Text(a.name)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundColor(isWinner ? gold : .white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 5, weight: .bold))
                    .foregroundColor(gold)
            }
        }
    }

    private func roundLabel(_ idx: Int) -> String {
        tournament.size.roundName(for: idx).uppercased()
    }

    // MARK: - Stats row

    private func statBox(label: String, value: String, tint: Color = Color(hex: "#FFD700")) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(Theme.bungee(8))
                .foregroundColor(.white.opacity(0.45))
                .tracking(1)
            Text(value)
                .font(Theme.bungee(14))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
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
    }

    private var gradientRule: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, gold.opacity(0.4), orange.opacity(0.4), .clear],
                startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
            .padding(.horizontal, 16)
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
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Render

    @MainActor
    static func render(tournament: Tournament,
                       grandChampionPayout: Int,
                       netCoinDelta: Int) -> UIImage? {
        let card = TournamentShareCard(
            tournament: tournament,
            grandChampionPayout: grandChampionPayout,
            netCoinDelta: netCoinDelta
        )
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
