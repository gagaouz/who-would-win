import SwiftUI

// MARK: - Battle + Result — Animal Arena Jr.
// Matches screenshots/04_battle.png + 05_result.png

struct KidsBattleView: View {
    let fighter1: Animal
    let fighter2: Animal
    /// King-of-the-hill: keep the winner and queue a fresh challenger. When nil,
    /// the "Next Challenger" CTA is hidden (e.g. if presented outside the picker).
    let onNextChallenger: ((Animal) -> Void)?

    @State private var currentEnvironment: BattleEnvironment
    @State private var currentArenaEffects: Bool
    @State private var showArenaSheet = false
    // Staged copies of the "New Arena" sheet's choices. The sheet writes
    // through its bindings the moment a tile/toggle is touched, so binding it
    // straight to currentEnvironment/currentArenaEffects let a swiped-away
    // sheet corrupt the next Rematch (env changed, effects still off).
    // These commit to the real state only when LET'S GO is pressed.
    @State private var pendingEnvironment: BattleEnvironment = .grassland
    @State private var pendingArenaEffects = true

    @StateObject private var viewModel: BattleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    // Per-fighter "crowd cheer" the kid builds by tapping a side they're rooting
    // for. The meters are cosmetic crowd support (they do NOT change the
    // deterministic winner) — their payoff is the "did your pick win?" reveal on
    // the result screen, which makes the whole build a prediction game.
    @State private var cheer1: Double = 0.14
    @State private var cheer2: Double = 0.14
    @State private var cheerTaps1 = 0
    @State private var cheerTaps2 = 0
    /// The in-flight battle orchestration task, cancelled on disappear.
    @State private var battleTask: Task<Void, Never>? = nil
    @State private var didStart = false

    init(fighter1: Animal, fighter2: Animal,
         environment: BattleEnvironment, arenaEffectsEnabled: Bool,
         onNextChallenger: ((Animal) -> Void)? = nil) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        self.onNextChallenger = onNextChallenger
        _currentEnvironment = State(initialValue: environment)
        _currentArenaEffects = State(initialValue: arenaEffectsEnabled)
        _viewModel = StateObject(wrappedValue: BattleViewModel(
            fighter1: fighter1, fighter2: fighter2,
            environment: environment, arenaEffectsEnabled: arenaEffectsEnabled,
            isQuickMode: false))
    }

    var body: some View {
        ZStack {
            gradientBG.ignoresSafeArea()

            // The accepted answer and the scene completion share one session.
            if let result = viewModel.battleResult, viewModel.animationComplete {
                ResultContent(
                    fighter1: fighter1, fighter2: fighter2, result: result,
                    battleID: viewModel.presentationID,
                    environment: currentEnvironment,
                    arenaEffectsEnabled: currentArenaEffects,
                    cheeredFighter: cheeredFighter,
                    onRematch: { Task { await restart() } },
                    onTryNewArena: {
                        // Seed the sheet: keep the current arena for context and
                        // default effects ON (opening "New Arena" means you want
                        // one) — but the kid's toggle choice is honored on
                        // commit, no more force-true override.
                        pendingEnvironment = currentEnvironment
                        pendingArenaEffects = true
                        showArenaSheet = true
                    },
                    onNextChallenger: onNextChallenger,
                    onClose: { dismiss() }
                )
                .accessibilityIdentifier("battle.result")
                .transition(.opacity)
            } else {
                RetroBattleStage(
                    sessionID: viewModel.presentationID,
                    teamA: [fighter1], teamB: [fighter2],
                    environment: currentEnvironment,
                    arenaEffectsEnabled: currentArenaEffects,
                    outcome: RetroBattleOutcome.solo(viewModel.battleResult, first: fighter1, second: fighter2),
                    pickedSide: cheeredSide,
                    onCheer: { registerCheer(side: $0) },
                    onClose: { dismiss() },
                    onComplete: { [session = viewModel.presentationID] in viewModel.animationDidComplete(for: session) }
                )
                .id(viewModel.presentationID)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showArenaSheet) {
            KidsPreBattleView(
                fighter1: fighter1, fighter2: fighter2,
                selectedEnvironment: $pendingEnvironment,
                arenaEffectsEnabled: $pendingArenaEffects,
                isPresented: $showArenaSheet,
                onStart: {
                    // Commit the staged choices only on LET'S GO — swiping the
                    // sheet away leaves the current fight's settings untouched,
                    // and the effects toggle's value is respected as chosen.
                    currentEnvironment = pendingEnvironment
                    currentArenaEffects = pendingArenaEffects
                    showArenaSheet = false
                    Task { await restart() }
                }
            )
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            appeared = true
            battleTask = Task { await viewModel.startBattle() }
        }
        .onDisappear {
            battleTask?.cancel()
            battleTask = nil
            viewModel.cancelBattle()
        }
    }

    /// The fighter the kid is rooting for (the side they've cheered most), or
    /// nil if they haven't cheered. Drives the "MY PICK" badge and the result
    /// screen's "did your pick win?" payoff.
    private var cheeredFighter: Animal? {
        if cheerTaps1 == 0 && cheerTaps2 == 0 { return nil }
        return cheerTaps1 >= cheerTaps2 ? fighter1 : fighter2
    }
    /// 0 = no pick yet, 1 = fighter1, 2 = fighter2.
    private var cheeredSide: Int {
        if cheerTaps1 == 0 && cheerTaps2 == 0 { return 0 }
        return cheerTaps1 >= cheerTaps2 ? 1 : 2
    }

    /// Cheer for one fighter — fills THAT fighter's crowd meter, with a tap blip
    /// + light haptic. Picking a side is the whole point: it turns the wait into
    /// "who do YOU think wins?".
    private func registerCheer(side: Int) {
        SoundService.shared.play(.tap, volume: 0.7)
        HapticsService.shared.tap()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            if side == 1 {
                cheerTaps1 += 1
                cheer1 = min(1.0, cheer1 + 0.07)
            } else {
                cheerTaps2 += 1
                cheer2 = min(1.0, cheer2 + 0.07)
            }
        }
    }

    private var gradientBG: LinearGradient {
        LinearGradient(colors: [Kids.cream, Kids.cream], startPoint: .top, endPoint: .bottom)
    }

    @MainActor
    private func restart() async {
        // Sync the latest env choice into the viewmodel
        viewModel.environment = currentEnvironment
        viewModel.arenaEffectsEnabled = currentArenaEffects
        // Cancel the old fetch before giving the new presentation an identity.
        battleTask?.cancel()
        viewModel.rematch()
        // Reset both cheer meters + relaunch the build
        cheer1 = 0.14; cheer2 = 0.14
        cheerTaps1 = 0; cheerTaps2 = 0
        battleTask = Task { await viewModel.startBattle() }
    }
}

// MARK: - Battle (animating) content

private struct BattleContent: View {
    let fighter1: Animal
    let fighter2: Animal
    let environment: BattleEnvironment
    let arenaEffectsEnabled: Bool
    /// Per-fighter crowd-cheer fill (0–1). The kid grows their side by tapping it.
    let cheer1: Double
    let cheer2: Double
    /// Which fighter the kid is rooting for: 0 none, 1 fighter1, 2 fighter2.
    let cheeredSide: Int
    let vsPulse: CGFloat
    let bob: CGFloat
    let appeared: Bool
    /// Pulses true for a fraction of a second on each scripted clash beat.
    let clashFlash: Bool
    /// Spoiler-free telegraph of how even the fight looks.
    let preview: BattleInsight.MatchupPreview
    /// SpriteKit animation has finished but the Claude narration hasn't
    /// arrived yet. Swaps the bottom text for an active "judges deliberating"
    /// panel so the user doesn't think the app is frozen.
    let isJudging: Bool
    /// Cheer for a side (1 or 2).
    let onCheer: (Int) -> Void
    let onClose: () -> Void

    // Heartbeat for the "judges voting" bar — proves the screen is alive.
    @State private var judgingPulse: CGFloat = 1.0
    // Continuous bounce on the cheer prompt + a quick pop on each fighter tap.
    @State private var cheerBounce = false
    @State private var pop1 = false
    @State private var pop2 = false

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: close + (optional) arena pill
            HStack {
                KidIconBtn(icon: "✕", fill: .white) { onClose() }
                Spacer()
                if arenaEffectsEnabled {
                    HStack(spacing: 6) {
                        RetroSymbol(environment.emoji, size: 16)
                        Text("\(environment.name.uppercased()) ARENA")
                            .font(Kids.fredoka(13, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        RetroPanelShape().fill(.white)
                            .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                    )
                    .compositingGroup()
                    .shadow(color: Kids.shadow.opacity(0.07), radius: 4, x: 0, y: 3)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16).padding(.top, 10)

            // Title sticker
            Text("THE BIG MATCH-UP!")
                .font(Kids.fredoka(22, weight: .bold))
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

            // Fighters row — TAP a fighter to cheer for it. Each side fills its
            // own crowd meter; the side you cheer most becomes "MY PICK". The VS
            // star "clashes" (jolts bigger) on each beat.
            HStack(spacing: 10) {
                cheerColumn(fighter1, side: 1, tint: Kids.sun, bobY: bob, fill: cheer1, popped: pop1)
                    .offset(x: clashFlash ? 6 : 0)
                StarSticker(text: clashFlash ? "💥" : "VS", size: 46, fill: Kids.pink)
                    .scaleEffect(vsPulse * (clashFlash ? 1.35 : 1.0))
                cheerColumn(fighter2, side: 2, tint: Kids.peach, bobY: -bob, fill: cheer2, popped: pop2)
                    .offset(x: clashFlash ? -6 : 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .animation(.easeInOut(duration: 0.14), value: clashFlash)

            // Spoiler-free telegraph: how even does this look?
            if !isJudging {
                Text(preview.hype)
                    .font(Kids.fredoka(13, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(
                        RetroPanelShape().fill(preview.isClose ? Kids.grass : Kids.sky)
                            .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                    )
                    .padding(.top, 12)
            }

            // Prompt / status card. Before the verdict: "cheer for who you think
            // wins!". While waiting on narration: "JUDGES VOTING".
            VStack(spacing: 8) {
                if isJudging {
                    HStack(spacing: 6) {
                        RetroSymbol("⚖️", size: 16).scaleEffect(judgingPulse)
                        Text("JUDGES VOTING")
                            .font(Kids.fredoka(14, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                    HStack(spacing: 6) {
                        TraitChip(emoji: fighter1.emoji, label: "Power!", color: Kids.sun)
                        TraitChip(emoji: fighter2.emoji, label: "Speed!", color: Kids.peach)
                    }
                } else {
                    Text(cheerPrompt)
                        .font(Kids.fredoka(15, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .multilineTextAlignment(.center)
                        .scaleEffect(cheerBounce ? 1.05 : 0.97)
                    Text(cheeredSide == 0
                         ? "Tap your favorite to make their crowd ROAR!"
                         : "Keep tapping — cheer them on!")
                        .font(Kids.nunito(11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(
                RetroPanelShape(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
            )
            .compositingGroup()
            .shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 4)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .animation(.easeInOut(duration: 0.25), value: isJudging)

            Spacer()

            // Bottom status indicator. Swaps to an active "judging" panel
            // when the SpriteKit fight is over but the narration hasn't
            // arrived yet.
            JudgingIndicator(isJudging: isJudging)
                .padding(.bottom, 40)
        }
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cheerBounce = true
            }
        }
        .onChange(of: isJudging) { judging in
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            if judging {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    judgingPulse = 0.97
                }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { judgingPulse = 1.0 }
            }
        }
    }

    private var cheerPrompt: String {
        switch cheeredSide {
        case 1:  return "GO, \(fighter1.name.uppercased())! 👏"
        case 2:  return "GO, \(fighter2.name.uppercased())! 👏"
        default: return "👏 CHEER FOR WHO YOU THINK WINS!"
        }
    }

    /// A fighter you can TAP to cheer for. Filling its crowd meter is how the kid
    /// roots for a side; the most-cheered fighter shows a "MY PICK" badge.
    @ViewBuilder
    private func cheerColumn(_ a: Animal, side: Int, tint: Color,
                             bobY: CGFloat, fill: Double, popped: Bool) -> some View {
        let isPick = cheeredSide == side
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                FighterPortrait(animal: a, size: 84, ringColor: isPick ? Kids.grass : tint)
                    .offset(y: bobY)
                    .scaleEffect(popped ? 1.12 : 1.0)
                if isPick {
                    Text("MY PICK")
                        .font(Kids.fredoka(9, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1)))
                        .offset(y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Text(a.name.uppercased())
                .font(Kids.fredoka(12, weight: .bold))
                .foregroundColor(Kids.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(
                    RetroPanelShape().fill(tint)
                        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                )
            // This fighter's own crowd-cheer meter.
            ProgressPill(progress: fill, fill: tint)
                .frame(width: 96, height: 12)
                .overlay(
                    RetroSymbol("📣", size: 9)
                        .opacity(fill > 0.25 ? 1 : 0)
                        .padding(.leading, 5),
                    alignment: .leading
                )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        // One VoiceOver element per fighter, announced as a button, instead
        // of a pile of emoji and meters read one by one.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPick ? "Cheer for \(a.name). Your pick." : "Cheer for \(a.name)")
        .accessibilityHint("Tap to cheer for who you think will win")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            guard !isJudging else { return }
            onCheer(side)
            if side == 1 { pop1 = true } else { pop2 = true }
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                if side == 1 { pop1 = false } else { pop2 = false }
            }
        }
    }
}

// MARK: - Judging indicator
//
// Shown while we're waiting for the Claude-generated narration to arrive
// after the SpriteKit fight ends. Cycles through "judge" messages with an
// animated dot trail and a gentle bouncing emoji so the user can see the
// app is actively working, not frozen.
//
// While the fight is still animating (isJudging == false) it just shows
// the original "The animals are battling…" copy.
//
// Shared between KidsBattleView and the tournament battle view — keep
// internal so both can use it.
struct JudgingIndicator: View {
    let isJudging: Bool

    @State private var messageIdx = 0
    @State private var dots = 0
    @State private var emojiBob: CGFloat = 0
    @State private var msgTimer: Timer? = nil
    @State private var dotTimer: Timer? = nil

    private let messages: [(String, String)] = [
        ("🎙️", "The judges are deliberating"),
        ("📊", "Counting up the votes"),
        ("⚖️", "Weighing every move"),
        ("🐾", "Who fought hardest"),
        ("🏆", "Final decision incoming"),
    ]

    var body: some View {
        Group {
            if isJudging {
                let (emoji, label) = messages[messageIdx % messages.count]
                HStack(spacing: 10) {
                    // No .id on the container: identity must stay stable or the
                    // repeatForever bob is killed and both timers get rebuilt on
                    // every message cycle. The emoji's string changes in place
                    // (same identity), so the in-flight bob animation survives.
                    RetroSymbol(emoji, size: 22)
                        .offset(y: emojiBob)
                    Text(label + String(repeating: ".", count: dots))
                        .font(Kids.nunito(14, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .frame(minWidth: 200, alignment: .leading)
                        .id(messageIdx)              // crossfade scope: label only
                        .transition(.opacity)
                }
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(
                    RetroPanelShape().fill(.white)
                        .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                )
                .compositingGroup()
                .shadow(color: Kids.shadow.opacity(0.10), radius: 4, x: 0, y: 4)
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    // Bouncing emoji — continuous spring motion (skip under Reduce Motion).
                    if !UIAccessibility.isReduceMotionEnabled {
                        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                            emojiBob = -4
                        }
                    }
                    // Cycle judge messages every 1.8s.
                    msgTimer?.invalidate()
                    msgTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { _ in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            messageIdx += 1
                        }
                    }
                    // Animate trailing "." every 0.35s.
                    dotTimer?.invalidate()
                    dotTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                        dots = (dots + 1) % 4
                    }
                }
                .onDisappear {
                    msgTimer?.invalidate(); msgTimer = nil
                    dotTimer?.invalidate(); dotTimer = nil
                }
            } else {
                Text("The animals are battling...")
                    .font(Kids.nunito(14, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isJudging)
    }
}

private struct TraitChip: View {
    let emoji: String
    let label: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            RetroSymbol(emoji, size: 12)
            Text(label).font(Kids.fredoka(10, weight: .bold)).foregroundColor(Kids.ink)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(RetroPanelShape().fill(color).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
    }
}

// MARK: - Result content

private struct ResultContent: View {
    let fighter1: Animal
    let fighter2: Animal
    let result: BattleResult
    let battleID: UUID
    let environment: BattleEnvironment
    let arenaEffectsEnabled: Bool
    /// The fighter the kid cheered for during the build (their prediction), or
    /// nil if they didn't cheer. Drives the "did your pick win?" payoff.
    let cheeredFighter: Animal?
    let onRematch: () -> Void
    let onTryNewArena: () -> Void
    /// King-of-the-hill: keep the winner, queue a fresh challenger. Nil hides the CTA.
    let onNextChallenger: ((Animal) -> Void)?
    let onClose: () -> Void

    @State private var appeared = false
    @State private var crownDropped = false
    @State private var showRemoveAdsHint = false
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false
    @StateObject private var speech = SpeechService()
    @ObservedObject private var feed = AchievementFeed.shared
    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Captured exactly once, when the result first appears.
    @State private var didRunSideEffects = false
    @State private var coinsEarned = 0
    @State private var showCoins = false
    @State private var winRecordText: String? = nil
    @State private var badgeName: String? = nil
    @State private var newStickerName: String? = nil
    /// Cancellable handle for the delayed auto-read-aloud so leaving the screen
    /// fast can't trigger ghost narration over the next screen.
    @State private var ttsWork: DispatchWorkItem? = nil

    private var winner: Animal? {
        if result.winner == fighter1.id { return fighter1 }
        if result.winner == fighter2.id { return fighter2 }
        return nil
    }
    private var loser: Animal? {
        guard let w = winner else { return nil }
        return w.id == fighter1.id ? fighter2 : fighter1
    }
    private var closeness: BattleInsight.Closeness? {
        guard let w = winner, let l = loser else { return nil }
        return BattleInsight.closeness(winner: w, loser: l)
    }
    /// Did the kid's cheered pick win? nil = didn't cheer, true = called it.
    private var calledIt: Bool? {
        guard let pick = cheeredFighter, let w = winner else { return nil }
        return pick.id == w.id
    }
    /// Caption that ships alongside the shared image + App Store link.
    private var shareCaption: String {
        if let w = winner, let l = loser {
            return "\(w.emoji) \(w.name) just beat \(l.emoji) \(l.name) in Animal vs Animal! Who would YOU pick?"
        }
        return "Who would win? Find out in Animal vs Animal!"
    }
    private var whyLine: String? {
        guard let w = winner, let l = loser else { return nil }
        // Prefer the cloud's battle-specific reason (emoji-stripped — an all-emoji
        // why must fall through to the local reason, not render an empty card).
        if let aiWhy = result.why?.withoutEmoji, !aiWhy.isEmpty {
            return aiWhy
        }
        return BattleInsight.why(winner: w, loser: l)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Triumphant golden sunburst behind the winner (sibling of the
            // tournament champion's rays). Sits above the gradient, behind the
            // content; only on a win.
            if winner != nil {
                WinnerSunburst(color: Kids.sun.opacity(0.40), centerY: 0.22)
                    .ignoresSafeArea()
            }

            scrollContent

            // One-shot confetti celebration on a win.
            if winner != nil {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Just-earned achievement, surfaced where it's earned.
            if let name = badgeName {
                BadgeToast(title: name) {
                    badgeName = nil
                    showNextBadgeIfIdle()
                }
                .padding(.top, 6)
                .zIndex(3)
            }
            // New sticker collected — the collection loop's payoff (shown below
            // any badge toast so the two don't overlap).
            if let sticker = newStickerName {
                BadgeToast(title: sticker, emoji: "📗", kicker: "NEW STICKER!", fill: Kids.sky) {
                    newStickerName = nil
                }
                .padding(.top, badgeName != nil ? 70 : 6)
                .zIndex(2)
            }
        }
        .onAppear {
            runSideEffectsIfNeeded()
            if AdManager.shared.suggestRemoveAds {
                showRemoveAdsHint = true
                AdManager.shared.suggestRemoveAds = false
            }
            if reduceMotion {
                appeared = true; crownDropped = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) { appeared = true }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.12)) { crownDropped = true }
            }
            showNextBadgeIfIdle()
        }
        .onChange(of: feed.queue) { _ in showNextBadgeIfIdle() }
        .onDisappear { cancelAutoRead() }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                // Include a caption + App Store link so a shared result is also a
                // tappable invite to install (the viral loop was a dead-end image).
                ShareSheet(items: [img, shareCaption, AppConfig.appStoreURL])
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    KidIconBtn(icon: "✕", fill: .white) { proceed(onClose) }
                }
                .padding(.horizontal, 16).padding(.top, 10)

                // Crown "slams" down from above with a bounce.
                RetroSymbol("👑", size: 54)
                    .scaleEffect(crownDropped ? 1 : 1.7)
                    .offset(y: crownDropped ? 0 : -46)
                    .rotationEffect(.degrees(crownDropped ? 0 : -22))
                    .opacity(crownDropped ? 1 : 0)

                if let w = winner {
                    StickerWord(text: "\(w.name.uppercased()) WINS!",
                                fill: Kids.peach, fontSize: 32, tilt: -2)
                        .rotationEffect(.degrees(appeared ? -2 : -20))
                        .scaleEffect(appeared ? 1 : 0.3)

                    // Catalog and custom creatures share the cached sprite artwork.
                    FighterPortrait(animal: w, size: 150, ringColor: Kids.peach)
                        .scaleEffect(appeared ? 1 : 0.4)

                    // Outcome summary — one tidy row of pills (your pick · how
                    // close) plus the win record, instead of several stacked
                    // full-width capsules with caption sentences.
                    resultChips(winner: w)

                    // Coins-land chip (keeps its own little landing animation).
                    if showCoins && coinsEarned > 0 {
                        coinChip
                    }
                } else {
                    StickerWord(text: "IT'S A TIE!", fill: Kids.sky, fontSize: 32, tilt: -2)
                        .scaleEffect(appeared ? 1 : 0.3)
                    HStack(spacing: 12) {
                        AnimalBubble(animal: fighter1, size: 100, tint: Kids.sun, tilt: -4)
                        AnimalBubble(animal: fighter2, size: 100, tint: Kids.peach, tilt: 4)
                    }
                    if showCoins && coinsEarned > 0 { coinChip }
                }

                // Battle narration card (plays out the match). AI text is
                // de-emojified — the model sometimes emits emoji that render as
                // empty placeholder boxes on device. Guard against an empty
                // string (e.g. a cached all-emoji result) leaving a blank card.
                if result.isOfflineFallback {
                    Text("Offline result")
                        .font(Kids.nunito(12, weight: .bold)).foregroundColor(Kids.inkSoft)
                        .accessibilityIdentifier("battle.offlineIndicator")
                }
                let story = result.narration.withoutEmoji
                if !story.isEmpty {
                    infoCard(tag: "BATTLE STORY", tagColor: Kids.pink, text: story)
                }

                // WHY did the winner win? — one-line, plain-biology lesson.
                if let why = whyLine {
                    infoCard(tag: "WHY?", tagColor: Kids.grass, text: why.withoutEmoji)
                }

                // Tale of the Tape — side-by-side real stats (the educational
                // payoff). Only shows when both fighters have curated facts; gate
                // at the call site so custom creatures don't leave a phantom gap.
                let tape = TaleOfTheTapeView(left: fighter1, right: fighter2)
                if tape.hasData {
                    tape.padding(.horizontal, 18)
                        .opacity(appeared ? 1 : 0)
                }

                // Fun-fact card (educational tidbit about the winner)
                let fact = result.funFact.withoutEmoji
                if !fact.isEmpty {
                    infoCard(tag: "FUN FACT", tagColor: Kids.sun, text: fact)
                }

                // Read-aloud button — large, friendly, the star of the card.
                readAloudButton

                // Primary CTA — king-of-the-hill if available, else new match-up.
                if let w = winner, onNextChallenger != nil {
                    KidButton(title: "NEXT CHALLENGER", icon: "⚔️", color: Kids.grass, size: .lg) {
                        HapticsService.shared.medium()
                        SoundService.shared.play(.whoosh)
                        proceed { onNextChallenger?(w) }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)

                    Button {
                        HapticsService.shared.tap()
                        proceed(onClose)
                    } label: {
                        Text("Pick two new fighters")
                            .font(Kids.fredoka(13, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                } else {
                    KidButton(title: "NEW MATCH-UP!", icon: "🎉", color: Kids.grass, size: .lg) {
                        HapticsService.shared.tap()
                        proceed(onClose)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                }

                // Secondary actions — three sticker-styled mini buttons
                HStack(spacing: 8) {
                    KidsMiniButton(emoji: "🔁", label: "Rematch", color: Kids.peach) {
                        proceed(onRematch)
                    }
                    .accessibilityIdentifier("battle.rematch")
                    KidsMiniButton(emoji: "🌍", label: "New Arena", color: Kids.grape) {
                        onTryNewArena()
                    }
                    .accessibilityIdentifier("battle.newArena")
                    KidsMiniButton(emoji: "📤", label: "Share", color: Kids.sky) {
                        HapticsService.shared.medium()
                        // Pre-fetch custom-creature photos so they actually make it
                        // onto the rendered card (ImageRenderer is synchronous and
                        // AsyncImage wouldn't have loaded in time).
                        Task {
                            let img = await KidsShareCard.renderWithCachedImages(
                                fighter1: fighter1, fighter2: fighter2, result: result,
                                environment: environment,
                                arenaEffectsEnabled: arenaEffectsEnabled
                            )
                            await MainActor.run {
                                shareImage = img
                                if shareImage != nil { showShareSheet = true }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                // Gentle, parent-directed upsell. Appears once after every 4th
                // interstitial (flag set by AdManager), then clears itself.
                if showRemoveAdsHint {
                    Button {
                        HapticsService.shared.tap()
                        KidsCoinShop.present()
                    } label: {
                        HStack(spacing: 6) {
                            RetroSymbol("🚫", size: 13)
                            Text("Grown-ups: you can remove ads forever")
                                .font(Kids.nunito(11, weight: .bold))
                                .foregroundColor(Kids.inkSoft)
                                .underline()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(RetroPanelShape().fill(.white.opacity(0.7)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }

                Color.clear.frame(height: 40)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Result chips (your-pick · how-close · win record)

    @ViewBuilder
    private func resultChips(winner w: Animal) -> some View {
        VStack(spacing: 7) {
            // One compact row of pills: did your pick win, and how close was it.
            HStack(spacing: 8) {
                if let called = calledIt {
                    chip(called ? "GREAT CALL!" : "NICE TRY", called ? Kids.grass : Kids.sky)
                }
                if let c = closeness {
                    chip(c.label, Kids.sun)
                }
            }
            // Per-animal win record — a quiet caption, not another capsule.
            if let rec = winRecordText {
                Text(rec)
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .opacity(appeared ? 1 : 0)
        .padding(.horizontal, 18)
    }

    private func chip(_ text: String, _ tint: Color) -> some View {
        Text(text)
            .font(Kids.fredoka(12, weight: .bold))
            .foregroundColor(Kids.ink)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 13).padding(.vertical, 6)
            .background(
                RetroPanelShape().fill(tint)
                    .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
            )
    }

    private var coinChip: some View {
        HStack(spacing: 6) {
            // The app's drawn gold coin, not the 🪙 emoji — matches the coin
            // shop / wager rows so currency looks the same everywhere.
            KidsGoldCoin(size: 18)
            Text("+\(coinsEarned)")
                .font(Kids.fredoka(18, weight: .bold))
                .foregroundColor(Kids.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .background(
            RetroPanelShape().fill(Kids.sun)
                .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
        )
        .compositingGroup()
        .shadow(color: Kids.shadow.opacity(0.12), radius: 4, x: 0, y: 4)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Reusable info card

    @ViewBuilder
    private func infoCard(tag: String, tagColor: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tag)
                .font(Kids.fredoka(11, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RetroPanelShape().fill(tagColor).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
            Text(text)
                .accessibilityIdentifier(tag == "BATTLE STORY" ? "battle.narration" : "battle.info.\(tag)")
                .font(Kids.nunito(13, weight: .bold))
                .foregroundColor(Kids.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RetroPanelShape(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
        .compositingGroup()
        .shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 4)
        .padding(.horizontal, 18)
        .opacity(appeared ? 1 : 0)
    }

    private var readAloudButton: some View {
        Button {
            HapticsService.shared.tap()
            if speech.isSpeaking {
                speech.stopSpeaking()
            } else {
                speech.speak("\(result.narration.withoutEmoji) \(result.funFact.withoutEmoji)")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: speech.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 18, weight: .bold))
                Text(speech.isSpeaking ? "Stop reading" : "Read it to me!")
                    .font(Kids.fredoka(16, weight: .bold))
            }
            .foregroundColor(Kids.ink)
            .padding(.horizontal, 20).padding(.vertical, 11)
            .background(
                RetroPanelShape().fill(Kids.sky)
                    .overlay(RetroPanelShape().fill(Kids.sheen))
                    .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
            )
            .compositingGroup()
            .shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    // MARK: - Side effects (run once)

    private func runSideEffectsIfNeeded() {
        guard !didRunSideEffects else { return }
        didRunSideEffects = true
        guard RetroBattleSettlement.claim(battleID) else { return }

        // Drop any badge backlog earned OUTSIDE a battle (melee/tournament/voice
        // search/shop) so the only "NEW BADGE!" toasts shown here belong to THIS
        // battle. Stale cross-mode badges otherwise misattribute to this result.
        AchievementFeed.shared.clear()

        // Count the battle + update the streak FIRST (coin bonus reads streak).
        let streakMilestoneBonus = UserSettings.shared.recordBattle()

        // Award coins, the one-time first-custom-creature bonus, and a small
        // "you called it!" bonus for correctly predicting the winner — capturing
        // the full delta so the coins-land chip reflects everything awarded.
        let before = CoinStore.shared.balance
        CoinStore.shared.earnBattleCoins(milestoneBonus: streakMilestoneBonus)
        if fighter1.isCustom || fighter2.isCustom {
            CoinStore.shared.earnFirstCustomBonus()
        }
        if let predictedCorrectly = calledIt {
            // Track prediction accuracy (drives the Grown-Up "what they're
            // learning" panel) and reward a correct call.
            UserSettings.shared.recordPrediction(correct: predictedCorrectly)
            if predictedCorrectly { CoinStore.shared.earn(5) }
        }
        coinsEarned = max(0, CoinStore.shared.balance - before)

        // Collect both fighters as stickers — and CELEBRATE a new one (the
        // collection loop used to pay off invisibly).
        let owned = StickerCollection.shared.collected
        let newCount = StickerCollection.shared.collectBoth(fighter1, fighter2)
        if newCount > 0 {
            let fresh = [fighter1, fighter2].filter { !owned.contains($0.id) }
            newStickerName = newCount == 1 ? (fresh.first?.name ?? "New sticker!")
                                           : "\(newCount) new stickers!"
        }

        // Per-animal win record (winner only).
        if let w = winner {
            let n = UserSettings.shared.recordWin(for: w.id)
            winRecordText = Self.winRecordLabel(n: n, name: w.name)
        }

        // Battle achievements — previously NEVER checked in the kids flow, so
        // milestone/variety badges weren't being awarded in production at all.
        // Environment is nil when no arena was in play (Quick Fight) so arena
        // badges can't be earned from the inert sentinel environment.
        AchievementTracker.shared.checkBattleAchievements(
            fighter1: fighter1, fighter2: fighter2,
            result: result,
            environment: arenaEffectsEnabled ? environment : nil)

        // Victory fanfare (gentle pop on a tie) + slam haptic.
        SoundService.shared.play(winner != nil ? .win : .pop)
        HapticsService.shared.success()

        // Ask for an App Store rating at this happy moment (throttled; only on a
        // win). Previously the live app never asked.
        if winner != nil {
            RatingsPrompt.maybeAsk(totalBattles: UserSettings.shared.totalBattleCount)
        }

        // Coins land a beat later so they don't collide with the fanfare.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            SoundService.shared.play(.coin)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showCoins = true }
        }

        // Auto-read the story aloud when narration is enabled — but NOT while
        // VoiceOver is running (it would talk over VoiceOver's own reading), and
        // via a CANCELLABLE work item so leaving the screen fast can't fire a
        // ghost narration over the next screen.
        if settings.narrationEnabled && !UIAccessibility.isVoiceOverRunning {
            let work = DispatchWorkItem {
                guard !speech.isSpeaking else { return }
                speech.speak("\(result.narration.withoutEmoji) \(result.funFact.withoutEmoji)")
            }
            ttsWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
        }
    }

    /// Cancels the pending auto-read and stops any in-progress speech.
    private func cancelAutoRead() {
        ttsWork?.cancel()
        ttsWork = nil
        speech.stopSpeaking()
    }

    /// Leaving the result screen: stop the read-aloud, then show a (frequency-
    /// capped, paid-user-exempt) interstitial at the natural screen break before
    /// running the requested action. AdManager fires the ad only every 3rd
    /// battle and calls the completion immediately otherwise, so most taps are
    /// instant. This is the ONLY interstitial in the 1v1 loop.
    private func proceed(_ action: @escaping () -> Void) {
        cancelAutoRead()
        AdManager.shared.showInterstitialIfNeeded { action() }
    }

    private func showNextBadgeIfIdle() {
        guard badgeName == nil, let next = feed.popNext() else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { badgeName = next }
    }

    /// "Lion's 1st win! 🎉" / "Lion's 3rd win!"
    static func winRecordLabel(n: Int, name: String) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13: suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(name)'s \(n)\(suffix) win!"
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct KidsMiniButton: View {
    let emoji: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            HapticsService.shared.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                RetroSymbol(emoji, size: 16)
                Text(label)
                    .font(Kids.fredoka(13, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RetroPanelShape(cornerRadius: 14, style: .continuous)
                    .fill(color)
                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
            )
            .compositingGroup()
            .shadow(color: Kids.shadow.opacity(0.08), radius: 4, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared retro result portrait

struct FighterPortrait: View {
    let animal: Animal
    var size: CGFloat = 150
    var ringColor: Color = Kids.peach

    var body: some View {
        RetroCreatureArtwork(animal: animal, size: size - 22)
            .frame(width: size, height: size)
            .background(RetroPanelShape().fill(ringColor.opacity(0.24)))
            .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
            .compositingGroup()
            .shadow(color: Kids.shadow.opacity(0.11), radius: 4, x: 0, y: 5)
            .accessibilityLabel(animal.name)
    }
}

extension String {
    /// Strips emoji / pictographic symbols (and their variation selectors and
    /// joiners) from a string. AI-generated narration and fun facts occasionally
    /// include emoji that render as empty placeholder boxes (tofu) in the app's
    /// custom fonts — this keeps user-facing copy to plain words. Letters,
    /// digits, "#"/"*", and normal punctuation (em-dashes, arrows) are preserved.
    var withoutEmoji: String {
        let kept = unicodeScalars.filter { s in
            let v = s.value
            if (0x1F000...0x1FAFF).contains(v) { return false }   // emoji & pictographs
            if (0x2600...0x27BF).contains(v)  { return false }    // misc symbols + dingbats
            if (0x2B00...0x2BFF).contains(v)  { return false }    // misc symbols & arrows (emoji)
            if (0xFE00...0xFE0F).contains(v)  { return false }    // variation selectors
            if (0x1F1E6...0x1F1FF).contains(v) { return false }   // regional indicators (flags)
            if v == 0x200D { return false }                        // zero-width joiner
            if v == 0x20E3 { return false }                        // combining enclosing keycap (1️⃣)
            // Catch any remaining emoji-presentation scalars (e.g. ⚖ U+2696 + FE0F).
            if s.properties.isEmojiPresentation { return false }
            if s.properties.isEmoji && v >= 0x2190 { return false }
            return true
        }
        return String(String.UnicodeScalarView(kept))
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
