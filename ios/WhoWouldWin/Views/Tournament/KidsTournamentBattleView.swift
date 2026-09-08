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
    @State private var failsafeTimer: Timer? = nil
    @State private var animationTimerWork: DispatchWorkItem? = nil

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
            // NOTE: there used to be a hidden triple-tap-to-forfeit gesture here
            // as an escape hatch for stuck battles. Removed: an excited kid
            // triple-tapping mid-battle would silently wipe their whole
            // tournament (bracket + wagers, no confirmation). The 25s failsafe
            // below already guarantees the battle can never get stuck.
            gradientBG.ignoresSafeArea()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Group {
                    // Same fix as KidsBattleView: show the result as soon as
                    // narration arrives AND the animation timer has fired.
                    // The view-model's .complete phase only ticks AFTER a 6s
                    // typewriter the result panel doesn't even render — gating
                    // on it would freeze the cheer meter at full for that whole
                    // window.
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
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            if quickMode, !didNotify {
                                // Quick mode resolves instantly — auto-advance.
                                didNotify = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    onComplete(result)
                                }
                            }
                        }
                    } else {
                        BuildContent(
                            fighter1: fighter1, fighter2: fighter2,
                            environment: environment,
                            arenaEffectsEnabled: arenaEffectsEnabled,
                            cheerProgress: cheerProgress,
                            vsPulse: vsPulse, bob: bob,
                            appeared: appeared,
                            tournamentTag: tournamentTag,
                            isIPad: isIPad,
                            // True while the SpriteKit fight is over but the
                            // narration still hasn't arrived — flips the cheer
                            // meter + bottom text to the active "judging" UI.
                            isJudging: viewModel.animationComplete && viewModel.battleResult == nil
                        )
                    }
                }
                .frame(maxWidth: isIPad ? 680 : .infinity)
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { vsPulse = 1.12 }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { bob = -6 }
            withAnimation(.easeIn(duration: quickMode ? 1.2 : 6.0)) { cheerProgress = 0.95 }
            // onAppear can re-fire (transition quirks, sheets) — never start a
            // second battle task or stack duplicate timers on this view model.
            guard !didStart else { return }
            didStart = true
            Task { await viewModel.startBattle() }
            if !quickMode {
                // Match the cheer-fill duration (6s easeIn) so the animation
                // signal fires the instant the meter visually maxes out.
                // Cancellable work item so backing out of the battle doesn't
                // leave a stray closure mutating a dismissed view's model.
                let work = DispatchWorkItem { viewModel.animationDidComplete() }
                animationTimerWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: work)
            }
            // Failsafe: if the battle hasn't completed after 25 seconds, force it.
            // This prevents the tournament from getting stuck if the result never arrives.
            // IMPORTANT: the rescue condition must mirror the RESULT GATE above
            // (battleResult != nil && animationComplete) — it used to check
            // `phase != .complete`, which quick mode satisfies immediately,
            // so a stuck quick battle was never rescued.
            failsafeTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: false) { _ in
                if viewModel.battleResult == nil || !viewModel.animationComplete {
                    // Force the result panel to appear by marking animation complete
                    // and ensuring battleResult is set. The winner is the
                    // stat-favored fighter for THIS arena — never a fixed slot,
                    // which used to silently crown fighter1 on every timeout.
                    if viewModel.battleResult == nil {
                        // Quick mode carries a real-but-INERT random arena —
                        // the timeout winner must be picked with neutral stats,
                        // matching the env-less fight the kid actually watched.
                        let statEnv: BattleEnvironment = arenaEffectsEnabled ? environment : .grassland
                        let s1 = AnimalStats.generate(for: fighter1, environment: statEnv)
                        let s2 = AnimalStats.generate(for: fighter2, environment: statEnv)
                        let score1 = s1.speed + s1.power + s1.agility + s1.defense
                        let score2 = s2.speed + s2.power + s2.agility + s2.defense
                        let w  = score1 >= score2 ? fighter1 : fighter2
                        let l  = score1 >= score2 ? fighter2 : fighter1
                        let fallback = BattleResult(
                            winner: w.id,
                            narration: "What a marathon! The \(w.name) and the \(l.name) traded blow after blow until the judges called it — the \(w.name) edges out the win and roars in triumph!",
                            funFact: "Even the closest battles have a winner — stamina and grit decide the ones that go the distance!",
                            winnerHealthPercent: 45,
                            loserHealthPercent: 12,
                            isOfflineFallback: true
                        )
                        viewModel.battleResult = fallback
                    }
                    viewModel.animationDidComplete()
                }
                failsafeTimer?.invalidate()
                failsafeTimer = nil
            }
        }
        .onDisappear {
            failsafeTimer?.invalidate()
            failsafeTimer = nil
            animationTimerWork?.cancel()
            animationTimerWork = nil
        }
    }

    private var gradientBG: LinearGradient {
        if viewModel.phase == .complete {
            return LinearGradient(
                colors: [Color(hex: "#FFE6B8"), Kids.pink, Kids.grape],
                startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(
            colors: [Color(hex: "#FFD9B0"), Color(hex: "#FFB6C9"), Color(hex: "#C6A8F5")],
            startPoint: .top, endPoint: .bottom)
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
                    Text("🏆").font(.system(size: isIPad ? 18 : 14))
                    Text(tournamentTag)
                        .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(
                    Capsule().fill(Kids.sun)
                        .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
                )
                .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)

                Spacer()

                if arenaEffectsEnabled {
                    HStack(spacing: 5) {
                        Text(environment.emoji).font(.system(size: isIPad ? 18 : 14))
                        Text(environment.name.uppercased())
                            .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.white).overlay(Capsule().stroke(Kids.ink, lineWidth: 2)))
                    .shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10)

            Text("THE BIG MATCH-UP!")
                .font(Kids.fredoka(isIPad ? 30 : 22, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Kids.sun)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                )
                .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
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
                    Text(isJudging ? "⚖️" : "🎺")
                        .font(.system(size: isIPad ? 18 : 14))
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
            )
            .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
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
                    Capsule().fill(tint)
                        .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
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
                Text("👑").font(.system(size: isIPad ? 66 : 50))
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

                // Compact narration card
                VStack(alignment: .leading, spacing: 6) {
                    Text("BATTLE STORY")
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Kids.pink).overlay(Capsule().stroke(Kids.ink, lineWidth: 1.5)))
                    Text(result.narration.withoutEmoji)
                        .font(Kids.nunito(isIPad ? 16 : 12, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                )
                .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
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
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) {
                appeared = true
            }
            HapticsService.shared.success()
            SoundService.shared.play(.win)   // victory fanfare (was silent)
        }
    }
}
