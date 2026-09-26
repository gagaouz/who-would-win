import SwiftUI

/// Container view for Tournament Mode. Observes TournamentManager and routes
/// to the correct phase view. Presented as a fullScreenCover from HomeView.
///
/// State machine:
///   no tournament → Setup → (optional) CreaturePicker → startNew() → BracketPreview
///   BracketPreview → GrandChampionWager → RoundWager(0) → RoundBattles(0, 0..n)
///                  → RoundResults(0) → RoundWager(1) → … → Final → Complete
///
/// The "pre-tournament" stage (Setup / Picker) uses local @State because the
/// tournament model doesn't exist yet. Once `startNew()` is called, routing
/// is driven entirely by `tournament.phase`.
struct TournamentRootView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = TournamentManager.shared
    @ObservedObject private var settings = UserSettings.shared

    // Pre-tournament state (only used when activeTournament == nil)
    @State private var preSize: BracketSize = .eight
    @State private var preMode: SelectionMode = .random
    @State private var preStage: PreStage = .setup

    // Quick mode — when on, battles skip animation + API and resolve instantly
    @AppStorage("tournamentQuickMode") private var quickMode: Bool = false

    // Daily cap — when the user has used their free tournaments we show a
    // coin-unlock confirmation sheet instead of silently starting a new run.
    @State private var showDailyCapSheet = false
    @State private var pendingStart: PendingStart?

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private struct PendingStart {
        let size: BracketSize
        let mode: SelectionMode
        let manualPicks: [Animal]
    }

    private enum PreStage { case setup, picking }

    var body: some View {
        NavigationStack {
            content
        }
        .sheet(isPresented: $showDailyCapSheet) {
            dailyCapSheet
        }
    }

    /// Tries to start a tournament, routing through the daily-cap coin gate when
    /// the user has exhausted their free entries. Shows the unlock sheet rather
    /// than silently bouncing the user.
    private func attemptStart(size: BracketSize,
                              mode: SelectionMode,
                              picks: [Animal]) {
        if manager.nextTournamentRequiresCoins {
            pendingStart = PendingStart(size: size, mode: mode, manualPicks: picks)
            showDailyCapSheet = true
            return
        }
        _ = manager.startNew(size: size, selectionMode: mode, manualPicks: picks)
    }

    @ViewBuilder
    private var content: some View {
        if let t = manager.activeTournament {
            phaseRouter(for: t)
        } else {
            switch preStage {
            case .setup:
                TournamentSetupView { size, mode in
                    preSize = size
                    preMode = mode
                    if mode == .random {
                        attemptStart(size: size, mode: .random, picks: [])
                    } else {
                        preStage = .picking
                    }
                }
            case .picking:
                TournamentCreaturePickerView(
                    targetCount: preSize.rawValue,
                    mode: preMode,
                    onContinue: { picks in
                        attemptStart(size: preSize, mode: preMode, picks: picks)
                        preStage = .setup // reset for next time
                    },
                    onBack: {
                        preStage = .setup
                    }
                )
            }
        }
    }

    // MARK: - Phase routing

    @ViewBuilder
    private func phaseRouter(for t: Tournament) -> some View {
        switch t.phase {

        case .setup, .picking:
            // Shouldn't normally reach here — startNew() jumps straight to .preview.
            TournamentSetupView { _, _ in manager.clear() }

        case .preview:
            BracketPreviewView(
                tournament: t,
                onConfirm: {
                    if !settings.wageringEnabled {
                        // Parent has disabled wagering — jump straight to first round battles.
                        manager.setPhase(.roundBattles(roundIndex: 0, matchupIndex: 0))
                    } else if t.grandChampion == nil {
                        manager.setPhase(.grandWager)
                    } else {
                        manager.setPhase(.roundWager(roundIndex: 0))
                    }
                },
                onReroll: { _ = manager.rerollBracket() },
                onForfeit: {
                    manager.forfeit()
                    dismiss()
                }
            )

        case .grandWager:
            if !settings.wageringEnabled {
                // Parental controls — skip the grand champion wager screen entirely.
                Color.clear.onAppear { manager.setPhase(.roundBattles(roundIndex: 0, matchupIndex: 0)) }
            } else {
                GrandChampionWagerView(
                    tournament: t,
                    onConfirm: { id, amount in
                        _ = manager.placeGrandChampion(pickedFighterId: id, amount: amount)
                        manager.setPhase(.roundWager(roundIndex: 0))
                    },
                    onSkip: {
                        manager.setPhase(.roundWager(roundIndex: 0))
                    }
                )
            }

        case .roundWager(let r):
            if !settings.wageringEnabled {
                // Parental controls — skip the per-round wager screen.
                Color.clear.onAppear { manager.setPhase(.roundBattles(roundIndex: r, matchupIndex: 0)) }
            } else {
                RoundWagerView(
                    tournament: t,
                    roundIndex: r,
                    onDone: {
                        manager.setPhase(.roundBattles(roundIndex: r, matchupIndex: 0))
                    }
                )
            }

        case .roundBattles(let r, let m):
            if let matchup = t.bracket.rounds[safe: r]?[safe: m] {
                tournamentBattleView(for: t, round: r, matchupIndex: m, matchup: matchup)
            } else {
                // Shouldn't happen — defensively advance to results
                Color.clear.onAppear { manager.setPhase(.roundResults(roundIndex: r)) }
            }

        case .roundResults(let r):
            RoundResultsView(
                tournament: t,
                roundIndex: r,
                onContinue: {
                    let nextRound = r + 1
                    if nextRound >= t.size.totalRounds {
                        // Final round just finished — no ad before the champion screen.
                        manager.setPhase(.complete)
                    } else {
                        // Show an interstitial between rounds as a natural pacing break.
                        // Completion advances to the next round's wager phase.
                        AdManager.shared.showInterstitialForTournamentRound {
                            manager.setPhase(.roundWager(roundIndex: nextRound))
                        }
                    }
                }
            )

        case .complete:
            TournamentCompleteView(
                tournament: t,
                onPlayAgain: {
                    manager.clear()
                    preStage = .setup
                },
                onExit: {
                    manager.clear()
                    dismiss()
                }
            )
        }
    }

    // MARK: - Battle view wrapper

    @ViewBuilder
    private func tournamentBattleView(for t: Tournament,
                                      round r: Int,
                                      matchupIndex m: Int,
                                      matchup: Matchup) -> some View {
        KidsTournamentBattleView(
            fighter1: matchup.fighter1,
            fighter2: matchup.fighter2,
            environment: matchup.environment,
            arenaEffectsEnabled: !quickMode,
            quickMode: quickMode,
            tournamentContext: tournamentContextString(for: t, roundIndex: r, matchupIndex: m),
            onComplete: { result in
                manager.recordMatchupResult(matchupId: matchup.id, result: result)
                let thisRoundCount = t.bracket.rounds[r].count
                let nextMatchup = m + 1
                if nextMatchup < thisRoundCount {
                    manager.setPhase(.roundBattles(roundIndex: r, matchupIndex: nextMatchup))
                } else {
                    manager.setPhase(.roundResults(roundIndex: r))
                }
            }
        )
        .id("\(r)-\(m)")
    }

    // MARK: - Daily cap sheet

    @ViewBuilder
    private var dailyCapSheet: some View {
        let cost = CoinStore.shared.tournamentExtraEntryCost
        let balance = CoinStore.shared.balance
        let canAfford = balance >= cost
        let limit = CoinStore.shared.tournamentDailyFreeLimit

        ZStack {
            SkyBG()

            VStack(spacing: isIPad ? 22 : 16) {
                RetroSymbol("⏰", size: isIPad ? 96 : 64).padding(.top, isIPad ? 42 : 28)

                StickerWord(text: "DAILY LIMIT", fill: Kids.sun, fontSize: isIPad ? 32 : 22, tilt: -2)

                Text("You've played your \(limit) free tournaments today.\nCome back tomorrow — or unlock one more now.")
                    .font(Kids.nunito(isIPad ? 17 : 13, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, isIPad ? 36 : 24)

                HStack(spacing: isIPad ? 9 : 6) {
                    Text("BALANCE")
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(Kids.inkSoft)
                    Text(balance.abbreviatedKidsCount)
                        .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1)
                    KidsGoldCoin(size: isIPad ? 18 : 14)
                }
                .padding(.horizontal, isIPad ? 20 : 14).padding(.vertical, isIPad ? 10 : 7)
                .background(RetroPanelShape().fill(.white).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))

                VStack(spacing: isIPad ? 14 : 10) {
                    Button {
                        guard let pending = pendingStart else { return }
                        showDailyCapSheet = false
                        _ = manager.startNew(
                            size: pending.size,
                            selectionMode: pending.mode,
                            manualPicks: pending.manualPicks,
                            payWithCoinsIfOverLimit: true
                        )
                        pendingStart = nil
                    } label: {
                        HStack(spacing: isIPad ? 9 : 6) {
                            RetroSymbol("⚡", size: isIPad ? 22 : 16)
                            Text("UNLOCK FOR \(cost)")
                                .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                                .foregroundColor(Kids.ink)
                            KidsGoldCoin(size: isIPad ? 18 : 14)
                        }
                        .frame(maxWidth: .infinity, minHeight: isIPad ? 64 : 50)
                        .background(
                            RetroPanelShape(cornerRadius: 16, style: .continuous)
                                .fill(Kids.sun)
                                .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).fill(Kids.sheen))
                                .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        )
                        .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAfford)
                    .opacity(canAfford ? 1.0 : 0.55)

                    if !canAfford {
                        Text("Need \(cost - balance) more coins — earn more by playing battles.")
                            .font(Kids.fredoka(11, weight: .bold))
                            .foregroundColor(Kids.pinkDeep)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        BuyCoinsButton().padding(.horizontal, 4)
                    } else if canAfford && (balance - cost) < CoinStore.shared.tournamentMatchupWagerFloor {
                        HStack(spacing: 6) {
                            RetroSymbol("⚠️", size: 13)
                            Text("You'll only have \(balance - cost) coin\(balance - cost == 1 ? "" : "s") left — not enough to wager. You can still play, but you can earn coins by watching an ad during the tournament.")
                                .font(Kids.nunito(11, weight: .bold))
                                .foregroundColor(Kids.ink)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(
                            RetroPanelShape(cornerRadius: 12, style: .continuous)
                                .fill(Kids.sun.opacity(0.3))
                                .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.sun, lineWidth: 1.5))
                        )
                        .padding(.horizontal, 4)
                    }

                    Button {
                        showDailyCapSheet = false
                        pendingStart = nil
                        dismiss()
                    } label: {
                        Text("Back to home")
                            .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .padding(.vertical, isIPad ? 14 : 10)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, isIPad ? 34 : 22)
                .frame(maxWidth: isIPad ? 600 : .infinity)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .presentationDetents(isIPad ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Tournament context string

    /// Returns a short server-trusted string describing the current round and matchup.
    /// Kept under 200 chars — the backend trims at 200.
    private func tournamentContextString(for t: Tournament,
                                         roundIndex r: Int,
                                         matchupIndex m: Int) -> String {
        let roundName = t.size.roundName(for: r)
        let total = t.size.totalRounds
        let sizeN = t.size.rawValue
        let matchNum = m + 1
        let matchCount = t.bracket.rounds[r].count
        return "This battle is the \(roundName) of a \(sizeN)-creature single-elimination tournament (round \(r + 1) of \(total), match \(matchNum)/\(matchCount)). Build drama accordingly."
    }
}

// MARK: - Safe array subscripting helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
