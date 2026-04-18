import SwiftUI

/// Final screen of a tournament run. Shows the champion, the grand-champion payout
/// (if any), net coin delta, and buttons to play again or return home.
struct TournamentCompleteView: View {
    let tournament: Tournament
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var manager = TournamentManager.shared
    @State private var didResolveGC = false
    @State private var grandChampionPayout: Int = 0
    @State private var confettiShowing = true
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil

    private var champion: Animal? {
        tournament.bracket.rounds.last?.first?.winningFighter
    }

    var body: some View {
        ZStack {
            Theme.battleBg(scheme).ignoresSafeArea()
            if confettiShowing {
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 18) {
                    trophy

                    championCard

                    GamePanel(headerText: "TOURNAMENT SUMMARY", headerColor: .gold) {
                        VStack(spacing: 12) {
                            summaryRow("Rounds", "\(tournament.size.totalRounds)")
                            summaryRow("Fighters", "\(tournament.bracket.allFighters.count)")
                            summaryRow("Wagers placed",
                                       "\(tournament.bracket.rounds.flatMap { $0 }.compactMap { $0.wager }.count)")
                            if let gc = tournament.grandChampion {
                                Divider().overlay(Color.white.opacity(0.2))
                                grandChampionSummary(gc)
                            }
                            Divider().overlay(Color.white.opacity(0.2))
                            HStack {
                                Text("NET COIN DELTA")
                                    .font(Theme.bungee(13))
                                    .foregroundColor(.white.opacity(0.7))
                                    .tracking(1)
                                Spacer()
                                let net = manager.netCoinDelta
                                HStack(spacing: 5) {
                                    Text(net >= 0 ? "+\(net)" : "\(net)")
                                        .font(Theme.bungee(18))
                                        .foregroundColor(net >= 0 ? Theme.neonGrn : Theme.red.opacity(0.9))
                                    GoldCoin(size: 18)
                                }
                            }
                        }
                    }

                    GamePanel(headerText: "BRACKET", headerColor: .purple) {
                        TournamentBracketDiagram(bracket: tournament.bracket,
                                                 highlightedRoundIndex: tournament.size.totalRounds - 1)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 10) {
                        Button(action: { showShareSheet = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("SHARE CHAMPION")
                            }
                        }
                        .buttonStyle(MegaButtonStyle(color: .purple, height: 56, cornerRadius: 18, fontSize: 16))

                        Button(action: onPlayAgain) {
                            Text("PLAY ANOTHER")
                        }
                        .buttonStyle(MegaButtonStyle(color: .orange, height: 60, cornerRadius: 18, fontSize: 18))

                        Button(action: onExit) {
                            Text("BACK TO HOME")
                                .font(Theme.bungee(14))
                                .foregroundColor(.white.opacity(0.65))
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didResolveGC else { return }
            didResolveGC = true
            grandChampionPayout = manager.resolveGrandChampionPayout()

            // ── Achievement tracking ──
            let t = tournament
            let allWagers = t.bracket.rounds.flatMap { $0 }.compactMap { $0.wager }
            let correctWagers = zip(
                t.bracket.rounds.flatMap { $0 },
                t.bracket.rounds.flatMap { $0 }.map { $0.result }
            ).filter { matchup, result in
                guard let w = matchup.wager, let r = result else { return false }
                return w.pickedFighterId == r.winner
            }.count
            let allWagersCorrect = !allWagers.isEmpty && correctWagers == allWagers.count
            let totalWagered = allWagers.reduce(0) { $0 + $1.amount }
            let gcWon = t.grandChampion.map { gc in
                champion?.id == gc.pickedFighterId
            } ?? false

            AchievementTracker.shared.checkTournamentAchievements(
                bracketSize: t.size.rawValue,
                championCategory: champion?.category,
                grandChampionWon: gcWon,
                allWagersCorrect: allWagersCorrect,
                totalWagered: totalWagered,
                totalWon: grandChampionPayout + manager.netCoinDelta
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation { confettiShowing = false }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage ?? renderShareImage() {
                BattleShareSheet(
                    image: img,
                    caption: "🏆 \(champion?.name ?? "???") just won the tournament in Animal vs Animal!"
                )
            } else {
                Text("Preparing share…").padding()
            }
        }
    }

    @MainActor
    private func renderShareImage() -> UIImage? {
        let img = TournamentShareCard.render(tournament: tournament,
                                             grandChampionPayout: grandChampionPayout,
                                             netCoinDelta: manager.netCoinDelta)
        shareImage = img
        return img
    }

    // MARK: - Subviews

    private var trophy: some View {
        Text("🏆")
            .font(.system(size: 72))
            .shadow(color: Theme.gold.opacity(0.6), radius: 14)
    }

    @ViewBuilder
    private var championCard: some View {
        if let c = champion {
            VStack(spacing: 8) {
                Text("CHAMPION")
                    .font(Theme.bungee(12))
                    .foregroundColor(Theme.gold)
                    .tracking(2)
                AnimalAvatar(animal: c, size: 88, cornerRadius: 16)
                Text(c.name)
                    .font(Theme.bungee(22))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(colors: [Theme.gold.opacity(0.25), Theme.orange.opacity(0.15)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Theme.gold, lineWidth: 2)
            )
            .shadow(color: Theme.gold.opacity(0.35), radius: 18, x: 0, y: 6)
        } else {
            Text("Final not decided")
                .font(Theme.bungee(14))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.bungee(13))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(Theme.bungee(14))
                .foregroundColor(.white)
        }
    }

    private func grandChampionSummary(_ gc: GrandChampionWager) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("GRAND CHAMPION PICK")
                    .font(Theme.bungee(12))
                    .foregroundColor(.white.opacity(0.7))
                    .tracking(1)
                Spacer()
                Text("\(String(format: "%.2f", gc.multiplier))×")
                    .font(Theme.bungee(12))
                    .foregroundColor(.white.opacity(0.7))
            }
            HStack {
                if let pick = tournament.bracket.allFighters.first(where: { $0.id == gc.pickedFighterId }) {
                    HStack(spacing: 6) {
                        AnimalAvatar(animal: pick, size: 22, cornerRadius: 6)
                        Text(pick.name)
                            .font(Theme.bungee(14))
                            .foregroundColor(.white)
                    }
                }
                Spacer()
                if grandChampionPayout > 0 {
                    HStack(spacing: 4) {
                        Text("+\(grandChampionPayout)")
                            .font(Theme.bungee(16))
                            .foregroundColor(Theme.neonGrn)
                        GoldCoin(size: 16)
                    }
                } else {
                    HStack(spacing: 4) {
                        Text("-\(gc.amount)")
                            .font(Theme.bungee(14))
                            .foregroundColor(Theme.red.opacity(0.9))
                        GoldCoin(size: 14)
                    }
                }
            }
        }
    }
}
