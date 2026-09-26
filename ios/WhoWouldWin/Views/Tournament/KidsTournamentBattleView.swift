import SwiftUI

/// Tournament-mode wrapper around KidsBattleView. Identical visual flow
/// (intro → animated build → reveal) but with a tournamentContext string passed
/// to the backend and a callback fired the moment a winner is decided so the
/// TournamentManager can record the matchup result and advance.
///
/// In `quickMode`, the BattleViewModel resolves immediately via the lightweight
/// "quick battle" endpoint — no SkyBG animation gate, just a fast result.
struct KidsTournamentBattleView: View {
    let fighter1: Animal
    let fighter2: Animal
    let environment: BattleEnvironment
    let arenaEffectsEnabled: Bool
    let quickMode: Bool
    let tournamentContext: String
    let onComplete: (BattleResult) -> Void

    @StateObject private var viewModel: BattleViewModel
    @State private var appeared = false
    @State private var cheerProgress: Double = 0.2
    @State private var vsPulse: CGFloat = 1
    @State private var bob: CGFloat = 0
    @State private var didNotify = false
    @State private var didStart = false
    @State private var battleTask: Task<Void, Never>?
    @State private var advanceTask: Task<Void, Never>?

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    init(fighter1: Animal, fighter2: Animal,
         environment: BattleEnvironment, arenaEffectsEnabled: Bool,
         quickMode: Bool, tournamentContext: String,
         onComplete: @escaping (BattleResult) -> Void) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        self.environment = environment
        self.arenaEffectsEnabled = arenaEffectsEnabled
        self.quickMode = quickMode
        self.tournamentContext = tournamentContext
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: BattleViewModel(
            fighter1: fighter1, fighter2: fighter2,
            environment: environment, arenaEffectsEnabled: arenaEffectsEnabled,
            isQuickMode: quickMode, tournamentContext: tournamentContext))
    }

    var body: some View {
        ZStack {
            // Resolution deadlines live in the model, never in a view timer.
            gradientBG.ignoresSafeArea()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    // Reveal only the accepted result after its presentation.
                    if let result = viewModel.battleResult, viewModel.animationComplete {
                        ResultPanel(
                            fighter1: fighter1, fighter2: fighter2, result: result,
                            environment: environment,
                            arenaEffectsEnabled: arenaEffectsEnabled,
                            isIPad: isIPad,
                            onContinue: {
                                guard !didNotify else { return }
                                didNotify = true
                                onComplete(result)
                            }
                        )
                        .accessibilityIdentifier("battle.result")
                        .transition(.opacity)
                        .onAppear {
                            if quickMode, !didNotify {
                                // Quick mode resolves instantly — auto-advance.
                                didNotify = true
                                advanceTask = Task { @MainActor in
                                    do { try await Task.sleep(nanoseconds: 700_000_000) }
                                    catch { return }
                                    guard !Task.isCancelled else { return }
                                    onComplete(result)
                                }
                            }
                        }
                    } else {
                        RetroBattleStage(
                            sessionID: viewModel.presentationID,
                            teamA: [fighter1], teamB: [fighter2],
                            environment: environment, arenaEffectsEnabled: arenaEffectsEnabled,
                            outcome: RetroBattleOutcome.solo(viewModel.battleResult, first: fighter1, second: fighter2),
                            title: tournamentTag,
                            onComplete: { [session = viewModel.presentationID] in
                                viewModel.animationDidComplete(for: session)
                            }
                        )
                        .id(viewModel.presentationID)
                    }
                }
                .frame(maxWidth: isIPad ? 680 : .infinity)
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didStart else { return }
            didStart = true
            battleTask = Task { await viewModel.startBattle() }
        }
        .onDisappear {
            battleTask?.cancel(); battleTask = nil
            advanceTask?.cancel(); advanceTask = nil
            viewModel.cancelBattle()
        }
    }

    private var gradientBG: LinearGradient {
        LinearGradient(colors: [Kids.cream, Kids.cream], startPoint: .top, endPoint: .bottom)
    }

    /// Compact "Quarterfinal · Match 2/4" badge shown atop the build screen.
    private var tournamentTag: String {
        // Heuristic — extract round + match info from the context string if possible.
        // Falls back to "TOURNAMENT MATCH".
        if let range = tournamentContext.range(of: "match "),
           let m = tournamentContext[range.upperBound...].split(separator: ".").first {
            // The context wraps "round X of Y, match A/B" in parens — splitting
            // on "." leaves a trailing ")" we need to strip. Same for any
            // stray whitespace.
            let trimmed = String(m)
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: ")"))
            return "TOURNAMENT · MATCH \(trimmed)"
        }
        return "TOURNAMENT MATCH"
    }
}

// MARK: - Build (animating) content

private struct BuildContent: View {
    let fighter1: Animal
    let fighter2: Animal
    let environment: BattleEnvironment
    let arenaEffectsEnabled: Bool
    let cheerProgress: Double
    let vsPulse: CGFloat
    let bob: CGFloat
    let appeared: Bool
    let tournamentTag: String
    let isIPad: Bool
    /// SpriteKit fight is done, Claude narration hasn't arrived yet.
    /// Drives the meter swap + bottom "judges deliberating" panel.
    let isJudging: Bool

    @State private var judgingPulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Tournament tag pill (replaces the close button — you cannot
                // abandon a tournament battle mid-match).
                HStack(spacing: 6) {
                    RetroSymbol("🏆", size: isIPad ? 18 : 14)
                    Text(tournamentTag)
                        .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(
                    RetroPanelShape().fill(Kids.sun)
                        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                )
                .compositingGroup()
                .shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 3)

                Spacer()

                if arenaEffectsEnabled {
                    HStack(spacing: 5) {
                        RetroSymbol(environment.emoji, size: isIPad ? 18 : 14)
                        Text(environment.name.uppercased())
                            .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(RetroPanelShape().fill(.white).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
                    .compositingGroup()
                    .shadow(color: Kids.shadow.opacity(0.06), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10)

            Text("THE BIG MATCH-UP!")
                .font(Kids.fredoka(isIPad ? 30 : 22, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(
                    RetroPanelShape(cornerRadius: 18, style: .continuous)
                        .fill(Kids.sun)
                        .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
                )
                .compositingGroup()
                .shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 4)
                .rotationEffect(.degrees(-1.5))
                .scaleEffect(vsPulse * 0.95)
                .padding(.top, 14)

            HStack(spacing: 10) {
                fighterCol(fighter1, tint: Kids.sun, bobY: bob)
                StarSticker(text: "VS", size: isIPad ? 60 : 46, fill: Kids.pink)
                    .scaleEffect(vsPulse)
                fighterCol(fighter2, tint: Kids.peach, bobY: -bob)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    RetroSymbol(isJudging ? "⚖️" : "🎺", size: isIPad ? 18 : 14)
                        .scaleEffect(isJudging ? judgingPulse : 1.0)
                    Text(isJudging ? "JUDGES VOTING" : "CROWD CHEER METER")
                        .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .contentTransition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: isJudging)
                ProgressPill(progress: cheerProgress,
                             fill: isJudging ? Kids.grape : Kids.sun)
                    .frame(height: isIPad ? 22 : 18)
                    .overlay(
                        Text(cheerText).font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .contentTransition(.opacity)
                    )
                    // Subtle horizontal heartbeat while judging — visible
                    // proof the screen is alive even though the bar is full.
                    .scaleEffect(x: isJudging ? judgingPulse : 1.0, y: 1.0)
                    .animation(.easeInOut(duration: 0.25), value: isJudging)
            }
            .padding(14)
            .background(
                RetroPanelShape(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
            )
            .compositingGroup()
            .shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 4)
            .padding(.horizontal, 18)
            .padding(.top, 22)

            Spacer()

            // Active bottom indicator. Cycles judge messages with animated
            // dots + bouncing emoji once isJudging flips. Same component as
            // in KidsBattleView.
            JudgingIndicator(isJudging: isJudging)
                .padding(.bottom, 40)
        }
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onChange(of: isJudging) { judging in
            if judging {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    judgingPulse = 0.97
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { judgingPulse = 1.0 }
            }
        }
    }

    private var cheerText: String {
        if isJudging              { return "DECISION TIME!" }
        // Tightened so "GOING WILD!" only appears in the final beat.
        if cheerProgress < 0.40   { return "Warming up…" }
        if cheerProgress < 0.80   { return "Getting exciting!" }
        return "GOING WILD!"
    }

    @ViewBuilder
    private func fighterCol(_ a: Animal, tint: Color, bobY: CGFloat) -> some View {
        VStack(spacing: 6) {
            FighterPortrait(animal: a, size: isIPad ? 108 : 84, ringColor: tint)
                .offset(y: bobY)
            Text(a.name.uppercased())
                .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                .foregroundColor(Kids.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(
                    RetroPanelShape().fill(tint)
                        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                )
            ProgressPill(progress: 0.75, fill: tint)
                .frame(width: isIPad ? 110 : 90, height: isIPad ? 10 : 8)
        }
    }
}

// MARK: - Result panel (in-tournament)

private struct ResultPanel: View {
    let fighter1: Animal
    let fighter2: Animal
    let result: BattleResult
    let environment: BattleEnvironment
    let arenaEffectsEnabled: Bool
    let isIPad: Bool
    let onContinue: () -> Void

    @State private var appeared = false

    private var winner: Animal? {
        if result.winner == fighter1.id { return fighter1 }
        if result.winner == fighter2.id { return fighter2 }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                RetroSymbol("👑", size: isIPad ? 66 : 50)
                    .scaleEffect(appeared ? 1 : 0)
                    .rotationEffect(.degrees(appeared ? 0 : -40))
                    .padding(.top, 30)

                if let w = winner {
                    StickerWord(text: "\(w.name.uppercased()) WINS!",
                                fill: Kids.peach, fontSize: isIPad ? 44 : 32, tilt: -2)
                        .rotationEffect(.degrees(appeared ? -2 : -20))
                        .scaleEffect(appeared ? 1 : 0.3)

                    FighterPortrait(animal: w, size: isIPad ? 170 : 130, ringColor: Kids.peach)
                        .scaleEffect(appeared ? 1 : 0.4)
                } else {
                    StickerWord(text: "IT'S A TIE!", fill: Kids.sky, fontSize: isIPad ? 42 : 30, tilt: -2)
                        .scaleEffect(appeared ? 1 : 0.3)
                }

                if result.isOfflineFallback {
                    Text("Offline result").font(Kids.nunito(12, weight: .bold))
                        .accessibilityIdentifier("battle.offlineIndicator")
                }
                // Compact narration card
                VStack(alignment: .leading, spacing: 6) {
                    Text("BATTLE STORY")
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RetroPanelShape().fill(Kids.pink).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
                    Text(result.narration.withoutEmoji)
                        .accessibilityIdentifier("battle.narration")
                        .font(Kids.nunito(isIPad ? 16 : 12, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RetroPanelShape(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                        .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
                )
                .compositingGroup()
                .shadow(color: Kids.shadow.opacity(0.07), radius: 4, x: 0, y: 3)
                .padding(.horizontal, 18)
                .opacity(appeared ? 1 : 0)

                KidButton(title: "NEXT MATCH-UP", icon: "▶️", color: Kids.grass, size: .lg) {
                    HapticsService.shared.tap()
                    onContinue()
                }
                .padding(.horizontal, 24)
                .padding(.top, 6)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            if UIAccessibility.isReduceMotionEnabled { appeared = true }
            else { withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) { appeared = true } }
            HapticsService.shared.success()
            SoundService.shared.play(.win)   // victory fanfare (was silent)
        }
    }
}
