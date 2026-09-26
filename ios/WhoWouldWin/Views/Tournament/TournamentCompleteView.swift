import SwiftUI

/// Final screen of a tournament run. Shows the champion, the grand-champion payout
/// (if any), net coin delta, and buttons to play again or return home.
struct TournamentCompleteView: View {
    let tournament: Tournament
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    @ObservedObject private var manager = TournamentManager.shared
    @ObservedObject private var coinStore = CoinStore.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var didResolveGC = false
    @State private var grandChampionPayout: Int = 0
    @State private var confettiShowing = true
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private var champion: Animal? {
        tournament.bracket.rounds.last?.first?.winningFighter
    }

    var body: some View {
        ZStack {
            SkyBG(variant: .sunset)

            if confettiShowing && !reduceMotion {
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: isIPad ? 22 : 16) {
                        Spacer().frame(height: isIPad ? 50 : 30)

                        // Tournament Champion banner
                        Text("TOURNAMENT CHAMPION")
                            .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Kids.sun)
                            .padding(.horizontal, isIPad ? 26 : 18).padding(.vertical, isIPad ? 10 : 7)
                            .background(
                                RetroPanelShape().fill(Kids.ink)
                                    .overlay(RetroPanelShape().stroke(Kids.sun, lineWidth: 3))
                            )
                            .compositingGroup().shadow(color: Kids.ink.opacity(0.21), radius: 0, x: 0, y: 5)

                            .scaleEffect(appeared ? 1 : 0.4)

                        if let c = champion {
                            VStack(spacing: -2) {
                                StickerWord(text: c.name.uppercased(), fill: Kids.sun, fontSize: isIPad ? 52 : 36, tilt: -3)

                                    .scaleEffect(appeared ? 1 : 0.3)
                                StickerWord(text: "WINS IT ALL!", fill: Kids.pink, fontSize: isIPad ? 36 : 26, tilt: 2)

                                    .scaleEffect(appeared ? 1 : 0.3)
                            }

                            FighterPortrait(animal: c, size: isIPad ? 220 : 150, ringColor: Kids.peach)
                                .scaleEffect(appeared ? 1 : 0.4)
                        } else {
                            Text("Final not decided")
                                .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                                .foregroundColor(Kids.inkSoft)
                        }

                        // Tournament summary card
                        summaryCard
                            .padding(.horizontal, isIPad ? 28 : 18)
                            .offset(y: appeared ? 0 : 40)

                        // Bracket diagram card
                        VStack(alignment: .leading, spacing: isIPad ? 14 : 10) {
                            HStack(spacing: isIPad ? 8 : 6) {
                                RetroSymbol("🌳", size: isIPad ? 22 : 16)
                                Text("BRACKET")
                                    .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Kids.ink)
                            }
                            TournamentBracketDiagram(bracket: tournament.bracket,
                                                     highlightedRoundIndex: tournament.size.totalRounds - 1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(isIPad ? 20 : 14)
                        .background(card)
                        .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
                        .padding(.horizontal, isIPad ? 28 : 18)
                        .opacity(appeared ? 1 : 0)

                        // Action buttons
                        VStack(spacing: isIPad ? 12 : 8) {
                            KidButton(title: "PLAY ANOTHER", icon: "🎉", color: Kids.grass, size: .lg) {
                                HapticsService.shared.tap()
                                onPlayAgain()
                            }
                            HStack(spacing: isIPad ? 12 : 8) {
                                KidsMiniButton(emoji: "📤", label: "Share", color: Kids.grape) {
                                    showShareSheet = true
                                }
                                KidsMiniButton(emoji: "🏠", label: "Home", color: Kids.sky) {
                                    onExit()
                                }
                            }
                        }
                        .padding(.horizontal, isIPad ? 28 : 18)
                        .padding(.top, isIPad ? 10 : 6)
                        .opacity(appeared ? 1 : 0)

                        Spacer(minLength: isIPad ? 50 : 30)
                    }
                    .frame(maxWidth: isIPad ? 760 : .infinity)
                    Spacer(minLength: 0)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didResolveGC else { return }
            didResolveGC = true
            grandChampionPayout = manager.resolveGrandChampionPayout()

            // Achievement tracking (unchanged)
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

            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { appeared = true }
            HapticsService.shared.success()

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                withAnimation { confettiShowing = false }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                BattleShareSheet(
                    image: img,
                    caption: "🏆 \(champion?.name ?? "???") just won the tournament in Animal vs Animal!"
                )
            } else {
                ProgressView("Preparing share…")
                    .padding()
                    .task { await renderShareImage() }
            }
        }
    }

    @MainActor
    private func renderShareImage() async {
        shareImage = await TournamentShareCard.renderWithCachedImages(
            tournament: tournament,
            grandChampionPayout: grandChampionPayout,
            netCoinDelta: manager.netCoinDelta
        )
    }

    private var card: some View {
        RetroPanelShape(cornerRadius: 20, style: .continuous)
            .fill(.white)
            .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        VStack(spacing: isIPad ? 14 : 10) {
            HStack(spacing: isIPad ? 8 : 6) {
                RetroSymbol("📊", size: isIPad ? 22 : 16)
                Text("TOURNAMENT SUMMARY")
                    .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Kids.ink)
                Spacer()
            }
            summaryRow("Rounds", "\(tournament.size.totalRounds)")
            summaryRow("Fighters", "\(tournament.bracket.allFighters.count)")
            if settings.wageringEnabled {
                summaryRow("Wagers placed",
                           "\(tournament.bracket.rounds.flatMap { $0 }.compactMap { $0.wager }.count)")
                if let gc = tournament.grandChampion {
                    Rectangle()
                        .fill(Kids.ink.opacity(0.12))
                        .frame(height: 1)
                    grandChampionSummary(gc)
                }
                Rectangle()
                    .fill(Kids.ink.opacity(0.12))
                    .frame(height: 1)
                HStack {
                    Text("NET COIN DELTA")
                        .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                    Spacer()
                    let net = manager.netCoinDelta
                    HStack(spacing: isIPad ? 7 : 5) {
                        Text(net >= 0 ? "+\(net)" : "\(net)")
                            .font(Kids.fredoka(isIPad ? 24 : 18, weight: .bold))
                            .foregroundColor(net >= 0 ? Kids.grassDeep : Kids.pinkDeep)
                        KidsGoldCoin(size: isIPad ? 24 : 18)
                    }
                }
            }
        }
        .padding(isIPad ? 20 : 14)
        .background(card)
        .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
    }

    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(Kids.nunito(isIPad ? 15 : 12, weight: .bold))
                .foregroundColor(Kids.inkSoft)
            Spacer()
            Text(value)
                .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                .foregroundColor(Kids.ink)
        }
    }

    private func grandChampionSummary(_ gc: GrandChampionWager) -> some View {
        VStack(alignment: .leading, spacing: isIPad ? 8 : 6) {
            HStack {
                Text("GRAND CHAMPION PICK")
                    .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Kids.inkSoft)
                Spacer()
                Text("\(String(format: "%.2f", gc.multiplier))×")
                    .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
            HStack {
                if let pick = tournament.bracket.allFighters.first(where: { $0.id == gc.pickedFighterId }) {
                    HStack(spacing: isIPad ? 8 : 6) {
                        FighterPickerMini(animal: pick, isIPad: isIPad)
                        Text(pick.name)
                            .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                }
                Spacer()
                if grandChampionPayout > 0 {
                    HStack(spacing: isIPad ? 6 : 4) {
                        Text("+\(grandChampionPayout)")
                            .font(Kids.fredoka(isIPad ? 19 : 15, weight: .bold))
                            .foregroundColor(Kids.grassDeep)
                        KidsGoldCoin(size: isIPad ? 18 : 14)
                    }
                } else {
                    HStack(spacing: isIPad ? 6 : 4) {
                        Text("-\(gc.amount)")
                            .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                            .foregroundColor(Kids.pinkDeep)
                        KidsGoldCoin(size: isIPad ? 18 : 14)
                    }
                }
            }
        }
    }
}

// MARK: - Mini avatar reused below

private struct FighterPickerMini: View {
    let animal: Animal
    let isIPad: Bool
    var body: some View {
        AnimalBubble(animal: animal, size: isIPad ? 38 : 28, tint: Kids.sun)
    }
}
