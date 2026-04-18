import SwiftUI
import SpriteKit
import UIKit
import StoreKit

struct BattleView: View {
    let fighter1: Animal
    let fighter2: Animal
    /// When set, this battle is part of a tournament. The post-battle UI hides the
    /// Rematch / New Battle / Share buttons and shows a single CONTINUE button that
    /// invokes this callback with the final result. The tournament host is responsible
    /// for recording the matchup result and advancing the tournament phase.
    let onTournamentComplete: ((BattleResult) -> Void)?
    @State private var displayEnvironment: BattleEnvironment
    @StateObject private var viewModel: BattleViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    private var introOffset: CGFloat { UIScreen.main.bounds.width * 1.1 }

    // MARK: - Animation State

    @State private var fighter1Offset: CGFloat
    @State private var fighter2Offset: CGFloat
    @State private var vsScale: CGFloat = 0.1
    @State private var vsOpacity: Double = 0

    @State private var resultsPanelOffset: CGFloat = 700
    @State private var winnerPhotoURL: URL? = nil
    @State private var showConfetti = false

    @State private var battleScene: BattleScene
    @State private var battleRound: Int = 0
    @State private var showFantasyBanner = false
    @State private var showOlympusBanner = false
    @State private var showTournamentBanner = false
    @State private var showFirstCustomBanner = false
    @State private var showShareSheet = false
    @State private var showVoiceQualityPrompt = false
    @State private var shareImage: UIImage? = nil
    @State private var fighter1Image: UIImage? = nil
    @State private var fighter2Image: UIImage? = nil
    @State private var showArenaSheet = false
    @Environment(\.requestReview) private var requestReview

    // Tournament draw-elimination state
    // First draw → retry in a new arena; second draw → settle with a kid-friendly tiebreaker.
    // Banners are tap-to-dismiss so the user has time to read them.
    @State private var tournamentDrawRetryCount: Int = 0
    @State private var showTournamentOvertimeBanner: Bool = false
    @State private var showTournamentTiebreakerBanner: Bool = false
    @State private var tiebreakerTitle: String = ""
    @State private var tiebreakerSubtitle: String = ""
    @State private var pendingTournamentDrawContinuation: (() -> Void)? = nil

    @StateObject private var speech = SpeechService()
    @ObservedObject private var coinStore = CoinStore.shared

    // MARK: - Init

    init(fighter1: Animal,
         fighter2: Animal,
         environment: BattleEnvironment = .grassland,
         arenaEffectsEnabled: Bool = false,
         quickMode: Bool = false,
         tournamentContext: String? = nil,
         onTournamentComplete: ((BattleResult) -> Void)? = nil) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        self.onTournamentComplete = onTournamentComplete
        _displayEnvironment = State(initialValue: environment)
        let offscreen = UIScreen.main.bounds.width * 1.1
        _fighter1Offset = State(initialValue: -offscreen)
        _fighter2Offset = State(initialValue: offscreen)
        _viewModel = StateObject(wrappedValue: BattleViewModel(fighter1: fighter1, fighter2: fighter2, environment: environment, arenaEffectsEnabled: arenaEffectsEnabled, isQuickMode: quickMode, tournamentContext: tournamentContext))
        _battleScene = State(initialValue: BattleScene(
            fighter1: fighter1,
            fighter2: fighter2,
            size: CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height * 0.55
            ),
            environment: environment
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            animatedBackground

            switch viewModel.phase {
            case .intro:
                introPhaseView
            case .animating, .fetchingResult:
                animatingPhaseView
            case .revealing, .complete:
                revealingPhaseView
            }

            // Confetti overlay — shown on winner reveal
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Fantasy unlock milestone banner
            if showFantasyBanner {
                VStack {
                    FantasyUnlockedBanner(isShowing: $showFantasyBanner)
                        .padding(.top, 60)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Tournament unlock milestone banner
            if showTournamentBanner {
                VStack {
                    TournamentUnlockedBanner(isShowing: $showTournamentBanner)
                        .padding(.top, 60)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Olympus unlock milestone banner
            if showOlympusBanner {
                VStack {
                    OlympusUnlockedBanner(isShowing: $showOlympusBanner)
                        .padding(.top, 60)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // First custom creature celebration banner (+50 coin bonus)
            if showFirstCustomBanner {
                VStack {
                    FirstCustomBanner(isShowing: $showFirstCustomBanner)
                        .padding(.top, 60)
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Tournament draw interceptor — "OVERTIME!" (switching arenas)
            if showTournamentOvertimeBanner {
                tournamentDrawBanner(
                    title: "OVERTIME!",
                    subtitle: "Too close to call — switching arenas!",
                    emoji: "⚡",
                    glow: Theme.orange
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(25)
            }

            // Tournament draw interceptor — "TIEBREAKER!" (kid-friendly fallback)
            if showTournamentTiebreakerBanner {
                tournamentDrawBanner(
                    title: tiebreakerTitle,
                    subtitle: tiebreakerSubtitle,
                    emoji: "🎲",
                    glow: Theme.gold
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(25)
            }

            // Coin earn animation overlay
            if coinStore.showEarnAnimation {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        GoldCoin(size: 18)
                        Text("+\(coinStore.earnAnimationAmount)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "#FFD700"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#FFD700").opacity(0.18))
                            .overlay(Capsule().stroke(Color(hex: "#FFD700").opacity(0.45), lineWidth: 1.5))
                    )
                    .shadow(color: Color(hex: "#FFD700").opacity(0.4), radius: 8, x: 0, y: 0)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.7).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 80)
                .allowsHitTesting(false)
                .zIndex(20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Better Voice Available 🎙️", isPresented: $showVoiceQualityPrompt) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Play Anyway") {
                if let r = viewModel.battleResult {
                    speech.speak(r.narration + (r.funFact.isEmpty ? "" : ". Fun fact: \(r.funFact)"))
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Download a free Premium voice for natural, human-sounding narration.\n\nGo to:\nSettings → Accessibility → Spoken Content → Voices → English\n\nTap any voice marked \"Premium\" to download it free.")
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                BattleShareSheet(
                    image: img,
                    caption: {
                        if let r = viewModel.battleResult {
                            let winner = r.winner == fighter1.id ? fighter1.name : fighter2.name
                            return r.winner == "draw"
                                ? "\(fighter1.name) vs \(fighter2.name) — it's a DRAW! 🤯"
                                : "\(winner) beats \(r.winner == fighter1.id ? fighter2.name : fighter1.name)! 🏆🔥"
                        }
                        return ""
                    }()
                )
                    .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
            }
        }
        .sheet(isPresented: $showArenaSheet) {
            // If arena effects were off the previous round, the battle was a
            // neutral fight — the grasslands backdrop was just visual. Pass
            // `nil` so the picker doesn't lie about a "CURRENT" arena.
            ArenaPickerSheet(
                isPresented: $showArenaSheet,
                current: viewModel.arenaEffectsEnabled ? displayEnvironment : nil
            ) { newEnv in
                switchArena(to: newEnv)
            }
        }
        .task(id: battleRound) {
            // Load best image for each fighter: pack-creature asset or custom photo.
            async let img1: UIImage? = loadFighterImage(fighter1)
            async let img2: UIImage? = loadFighterImage(fighter2)
            let (image1, image2) = await (img1, img2)
            fighter1Image = image1
            fighter2Image = image2
            if let img = image1 { battleScene.setFighterImage(img, forFighter: 1) }
            if let img = image2 { battleScene.setFighterImage(img, forFighter: 2) }

            battleScene.onAnimationComplete = {
                Task { @MainActor in viewModel.animationDidComplete() }
            }
            await viewModel.startBattle()
        }
        .onChange(of: viewModel.phase) { newPhase in
            // Belt-and-suspenders: explicitly kick off the scene if didMove(to:) didn't fire.
            // One runloop tick delay lets SwiftUI mount the SpriteView before we call in.
            if newPhase == .animating {
                DispatchQueue.main.async {
                    battleScene.beginBattle()
                }
            }

            if newPhase == .revealing, let result = viewModel.battleResult {
                // Tournaments can't end in a draw. If one slips through, take over the
                // result flow: first draw re-runs the fight in a different arena; second
                // draw is settled with a client-side kid-friendly tiebreaker scenario.
                if onTournamentComplete != nil && result.winner == "draw" {
                    handleTournamentDraw()
                    return
                }

                battleScene.setBattleResult(result)

                // Haptic feedback on result reveal
                if result.winner == "draw" {
                    HapticsService.shared.warning()
                } else {
                    HapticsService.shared.success()
                }

                if result.winner != "draw" {
                    let winnerAnimal = result.winner == fighter1.id ? fighter1 : fighter2
                    winnerPhotoURL = nil
                    Task { winnerPhotoURL = await fetchWikipediaPhotoURL(for: winnerAnimal.name) }
                    // Trigger confetti after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showConfetti = true
                    }
                }
            }

            // Record completed battle and check ad gate / fantasy milestone
            if newPhase == .complete {
                let justHitMilestone = UserSettings.shared.justUnlockedFantasy
                let justHitOlympus   = UserSettings.shared.justUnlockedOlympus
                let justHitTournament = UserSettings.shared.justUnlockedTournament
                UserSettings.shared.recordBattle()
                // Tournament battles don't earn normal battle coins — coin flow is wager-driven.
                if onTournamentComplete == nil {
                    CoinStore.shared.earnBattleCoins()
                }

                // First custom creature bonus (+50 coins, once ever) — show celebration banner
                if onTournamentComplete == nil && (fighter1.isCustom || fighter2.isCustom) {
                    if CoinStore.shared.earnFirstCustomBonus() {
                        HapticsService.shared.success()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                showFirstCustomBanner = true
                            }
                        }
                    }
                }

                // Fantasy milestone celebration (fires once, the battle that crosses 250)
                if justHitMilestone {
                    HapticsService.shared.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showFantasyBanner = true
                        }
                    }
                }

                // Olympus milestone celebration (fires once at 10,000)
                if justHitOlympus {
                    HapticsService.shared.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showOlympusBanner = true
                        }
                    }
                }

                // Tournament milestone celebration (fires once at 30)
                if justHitTournament {
                    HapticsService.shared.success()
                    // Also seed 200 starter coins for the first tournament
                    CoinStore.shared.awardTournamentSeedIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showTournamentBanner = true
                        }
                    }
                }

                // ── Achievement tracking ──
                if let result = viewModel.battleResult {
                    AchievementTracker.shared.checkBattleAchievements(
                        fighter1: fighter1,
                        fighter2: fighter2,
                        result: result,
                        environment: displayEnvironment
                    )
                    AchievementTracker.shared.checkStreakAchievements(streak: UserSettings.shared.currentStreak)
                    AchievementTracker.shared.checkCoinAchievements(balance: CoinStore.shared.balance)
                    AchievementTracker.shared.checkPackAchievements()
                }

                // App Store review prompt — request after 5th battle
                if UserSettings.shared.totalBattleCount == 5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        requestReview()
                    }
                }

                // Ad will be shown when user taps Rematch or New Battle
            }
        }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        LinearGradient(
            colors: [displayEnvironment.bgTop, displayEnvironment.bgBottom],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - PHASE 1: Intro

    private var introPhaseView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()

                HStack(alignment: .center, spacing: 0) {
                    fighterCard(animal: fighter1, accentColor: Theme.orange)
                        .frame(width: geo.size.width * 0.38)
                        .offset(x: fighter1Offset)

                    Spacer()

                    Text("VS")
                        .font(.custom("PressStart2P-Regular", size: 26))
                        .foregroundColor(Theme.orange)
                        .shadow(color: Theme.orange.opacity(0.8), radius: 10, x: 0, y: 0)
                        .scaleEffect(vsScale)
                        .opacity(vsOpacity)

                    Spacer()

                    fighterCard(animal: fighter2, accentColor: Theme.cyan)
                        .frame(width: geo.size.width * 0.38)
                        .offset(x: fighter2Offset)
                }
                .padding(.horizontal, 12)

                Spacer()

                HStack(spacing: 16) {
                    simpleHealthBar(color: Theme.orange)
                    simpleHealthBar(color: Theme.cyan)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 52)
                .opacity(vsOpacity)
            }
        }
        .onAppear { playIntroAnimation() }
    }

    private func fighterCard(animal: Animal, accentColor: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 96, height: 96)
                    .blur(radius: 14)

                if let assetName = animal.creatureAssetName,
                   let img = UIImage(named: assetName) {
                    // Generated artwork — paid pack creatures
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 82, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accentColor.opacity(0.5), lineWidth: 2))
                } else if let url = animal.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(width: 82, height: 82).clipShape(Circle())
                                .overlay(Circle().stroke(accentColor.opacity(0.5), lineWidth: 2))
                        default:
                            Text(animal.emoji).font(.system(size: 80))
                        }
                    }
                } else {
                    Text(animal.emoji).font(.system(size: 80))
                }
            }

            Text(animal.name.uppercased())
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(accentColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .shadow(color: accentColor.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(accentColor.opacity(0.3), lineWidth: 1.5))
        )
        .shadow(color: accentColor.opacity(0.15), radius: 12, x: 0, y: 6)
    }

    private func simpleHealthBar(color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width)
            }
        }
        .frame(height: 10)
    }

    private func playIntroAnimation() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { fighter1Offset = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { fighter2Offset = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) {
                vsScale = 1.0
                vsOpacity = 1.0
            }
            // Heavy clash impact when VS appears
            HapticsService.shared.heavy()
        }
    }

    // MARK: - PHASE 2: Animating

    private var animatingPhaseView: some View {
        VStack(spacing: 0) {
            SpriteView(scene: battleScene)
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.55)
                .ignoresSafeArea(edges: .top)
                .onAppear { battleScene.beginBattle() }

            battleProgressPanel
        }
        .ignoresSafeArea(edges: .top)
    }

    private var battleProgressPanel: some View {
        // Use environment-adjusted stats so bars reflect the terrain effect
        let stats1 = AnimalStats.generate(for: fighter1, environment: displayEnvironment)
        let stats2 = AnimalStats.generate(for: fighter2, environment: displayEnvironment)
        let strength1 = (stats1.power + stats1.defense) / 2
        let strength2 = (stats2.power + stats2.defense) / 2

        return VStack(spacing: 0) {
            // Environment badge + fighter badges row
            VStack(spacing: 6) {
                // Arena label — only shown when arena effects are active
                if viewModel.arenaEffectsEnabled {
                    HStack(spacing: 5) {
                        Text(displayEnvironment.emoji).font(.system(size: 13))
                        Text(displayEnvironment.name.uppercased())
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(displayEnvironment.accentColor)
                            .tracking(1.5)
                        Text("ARENA")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(displayEnvironment.accentColor.opacity(0.6))
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(displayEnvironment.accentColor.opacity(0.12))
                            .overlay(Capsule().stroke(displayEnvironment.accentColor.opacity(0.3), lineWidth: 1))
                    )
                }

                HStack(spacing: 0) {
                    fighterTurnBadge(animal: fighter1, image: fighter1Image, color: Theme.orange)
                    Text("⚔️").font(.system(size: 24))
                        .frame(width: 44)
                    fighterTurnBadge(animal: fighter2, image: fighter2Image, color: Theme.cyan)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 12)

            // Stat comparison card
            VStack(spacing: 0) {
                HStack {
                    Rectangle()
                        .fill(LinearGradient(colors: [.clear, Theme.orange.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                    Text("BATTLE STATS")
                        .font(Theme.bungee(8))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                        .padding(.horizontal, 10)
                    Rectangle()
                        .fill(LinearGradient(colors: [Theme.cyan.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                }
                .padding(.bottom, 10)

                VStack(spacing: 9) {
                    statRow(label: "SPEED",    v1: stats1.speed,   v2: stats2.speed)
                    statRow(label: "POWER",    v1: stats1.power,   v2: stats2.power)
                    statRow(label: "AGILITY",  v1: stats1.agility, v2: stats2.agility)
                    statRow(label: "DEFENSE",  v1: stats1.defense, v2: stats2.defense)
                    statRow(label: "STRENGTH", v1: strength1,      v2: strength2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func fighterTurnBadge(animal: Animal, image: UIImage?, color: Color) -> some View {
        VStack(spacing: 4) {
            if let img = image {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                Text(animal.emoji).font(.system(size: 26))
            }
            Text(animal.name.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    /// Head-to-head stat row: F1 bar fills from right, F2 bar fills from left.
    private func statRow(label: String, v1: Int, v2: Int) -> some View {
        HStack(spacing: 8) {
            // F1 bar (orange, fills from right toward center)
            GeometryReader { geo in
                ZStack(alignment: .trailing) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Theme.orange.opacity(0.5), Theme.orange],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(v1) / 100)
                }
            }
            .frame(height: 9)

            Text(label)
                .font(Theme.bungee(7))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 52)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // F2 bar (cyan, fills from left toward center)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Theme.cyan, Theme.cyan.opacity(0.5)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(v2) / 100)
                }
            }
            .frame(height: 9)
        }
    }

    // MARK: - PHASE 3 & 4: Revealing / Complete

    private var revealingPhaseView: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                SpriteView(scene: battleScene)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.55)
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        LinearGradient(
                            stops: [
                                .init(color: Color.black.opacity(0.6), location: 0.0),
                                .init(color: Color.black.opacity(0.6), location: 0.30),
                                .init(color: .clear, location: 0.55),
                                .init(color: Color.black.opacity(0.4), location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            HStack {
                Spacer(minLength: 0)
                resultsCard
                    .frame(maxWidth: isIPad ? 720 : .infinity)
                Spacer(minLength: 0)
            }
            .offset(y: resultsPanelOffset)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    resultsPanelOffset = 0
                }
            }
        }
    }

    private var resultsCard: some View {
        Group {
            if let result = viewModel.battleResult {
                let isDraw = result.winner == "draw"
                let winnerAnimal = result.winner == fighter1.id ? fighter1 : fighter2
                let winnerAccent = result.winner == fighter1.id ? Theme.orange : Theme.cyan

                VStack(spacing: 0) {
                    // Drag pill — drag down to peek at the battle scene beneath
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 40, height: 5)
                        .padding(.top, 14)
                        .padding(.bottom, 18)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if value.translation.height > 0 {
                                        resultsPanelOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 150 {
                                        withAnimation(.spring(response: 0.4)) {
                                            resultsPanelOffset = 700
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3)) {
                                            resultsPanelOffset = 0
                                        }
                                    }
                                }
                        )

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {

                            // Trophy + winner name
                            if isDraw {
                                VStack(spacing: 8) {
                                    Text("⚔️")
                                        .font(.system(size: 60))
                                    Text("IT'S A DRAW!")
                                        .font(Theme.bungee(26))
                                        .foregroundColor(Theme.gold)
                                        .shadow(color: Theme.gold.opacity(0.4), radius: 8, x: 0, y: 0)
                                    Text("Neither fighter could claim victory — their strengths were too evenly matched.")
                                        .font(Theme.bungee(13))
                                        .foregroundColor(.white.opacity(0.65))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                        .padding(.top, 2)
                                }
                            } else {
                                VStack(spacing: 6) {
                                    Text("🏆")
                                        .font(.system(size: 60))
                                        .shadow(color: Theme.gold.opacity(0.6), radius: 12, x: 0, y: 0)

                                    Text("WINNER!")
                                        .font(Theme.bungee(13))
                                        .foregroundColor(.white.opacity(0.6))
                                        .tracking(3)

                                    Text(winnerAnimal.name.uppercased())
                                        .font(Theme.bungee(26))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [winnerAccent, Theme.gold],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .multilineTextAlignment(.center)
                                        .shadow(color: winnerAccent.opacity(0.5), radius: 10, x: 0, y: 0)
                                }
                            }

                            // Environment badge — only shown when arena effects are active
                            if viewModel.arenaEffectsEnabled {
                            HStack(spacing: 5) {
                                Text(displayEnvironment.emoji).font(.system(size: 12))
                                Text("\(displayEnvironment.name.uppercased()) ARENA")
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundColor(displayEnvironment.accentColor)
                                    .tracking(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(displayEnvironment.accentColor.opacity(0.12))
                                    .overlay(Capsule().stroke(displayEnvironment.accentColor.opacity(0.3), lineWidth: 1))
                            )
                            } // end arenaEffectsEnabled

                            // Winner photo — full Wikipedia photo, fitted (never zoomed/cropped).
                            // Uses a dark letterbox background instead of a blurred crop of the image
                            // itself, so the photo always shows at its true framing.
                            if !isDraw, let photoURL = winnerPhotoURL {
                                AsyncImage(url: photoURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity, maxHeight: 190)
                                            .padding(8)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .fill(Color.black.opacity(0.35))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(
                                                        LinearGradient(colors: [winnerAccent, Theme.gold], startPoint: .leading, endPoint: .trailing),
                                                        lineWidth: 2
                                                    )
                                            )
                                            .shadow(color: winnerAccent.opacity(0.35), radius: 12, x: 0, y: 6)
                                            .padding(.horizontal, 12)
                                    case .failure:
                                        EmptyView()
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(maxWidth: .infinity).frame(height: 190)
                                            .overlay(ProgressView().tint(Theme.gold))
                                            .padding(.horizontal, 12)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }

                            // Offline badge
                            if result.isOfflineFallback {
                                HStack(spacing: 6) {
                                    Text("⚡")
                                        .font(.system(size: 13))
                                    Text("Offline result")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color(hex: "#FFB347"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "#FFB347").opacity(0.15))
                                        .overlay(Capsule().stroke(Color(hex: "#FFB347").opacity(0.4), lineWidth: 1))
                                )
                            }

                            // Narration (typewriter)
                            Text(viewModel.narrationDisplayed)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 4)
                                .animation(.easeIn(duration: 0.03), value: viewModel.narrationDisplayed)

                            // Speaker button
                            if viewModel.phase == .complete, !result.narration.isEmpty {
                                Button(action: {
                                    let settings = UserSettings.shared
                                    if !SpeechService.hasHighQualityVoice && !settings.hasSeenVoiceQualityPrompt {
                                        settings.hasSeenVoiceQualityPrompt = true
                                        showVoiceQualityPrompt = true
                                    } else {
                                        speech.speak(result.narration + (result.funFact.isEmpty ? "" : ". Fun fact: \(result.funFact)"))
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: speech.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                            .font(.system(size: 15, weight: .medium))
                                        Text(speech.isSpeaking ? "Stop" : "Read Aloud")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(speech.isSpeaking ? Theme.orange : .white.opacity(0.6))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(speech.isSpeaking ? Theme.orange.opacity(0.15) : Color.white.opacity(0.12))
                                            .overlay(Capsule().stroke(
                                                speech.isSpeaking ? Theme.orange.opacity(0.4) : Color.white.opacity(0.2),
                                                lineWidth: 1
                                            ))
                                    )
                                }
                                .buttonStyle(PressableButtonStyle())
                            }

                            // Fun fact
                            if !result.funFact.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 6) {
                                        Text("✨")
                                        Text("FUN FACT")
                                            .font(.system(size: 12, weight: .black, design: .rounded))
                                            .foregroundColor(Theme.teal)
                                            .tracking(1.5)
                                    }

                                    Text(result.funFact)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Theme.teal.opacity(0.07))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.teal.opacity(0.25), lineWidth: 1.5))
                                )
                            }

                            // Action buttons
                            if viewModel.phase == .complete {
                                resultActionButtons
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 60)
                    }
                }
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 30, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 30
                    )
                    .fill(.ultraThinMaterial)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 30, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0, topTrailingRadius: 30
                        )
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                )
            }
        }
    }

    // MARK: - Result Action Buttons (extracted to avoid type-check timeout)

    @ViewBuilder
    private var resultActionButtons: some View {
        if let onTournamentComplete = onTournamentComplete {
            // ── Tournament mode: single CONTINUE button only ──────────
            VStack(spacing: 10) {
                Button {
                    if let result = viewModel.battleResult {
                        HapticsService.shared.medium()
                        onTournamentComplete(result)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("🏆").font(.system(size: 18))
                        Text("CONTINUE TOURNAMENT")
                    }
                }
                .buttonStyle(MegaButtonStyle(color: .gold, height: 60, cornerRadius: 18, fontSize: 16))
                .disabled(viewModel.battleResult == nil)
            }
        } else {
        VStack(spacing: 10) {

            // ── Primary: New Arena ───────────────────────────────
            Button {
                HapticsService.shared.tap()
                showArenaSheet = true
            } label: {
                HStack(spacing: 10) {
                    Text(displayEnvironment.emoji).font(.system(size: 20))
                    Text("TRY NEW ARENA")
                        .font(Theme.bungee(16))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(
                            colors: [displayEnvironment.accentColor.opacity(0.85),
                                     displayEnvironment.accentColor],
                            startPoint: .leading, endPoint: .trailing
                        ))
                )
                .shadow(color: displayEnvironment.accentColor.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(PressableButtonStyle())

            // ── Secondary row: Share + Rematch ───────────────────
            HStack(spacing: 10) {
                if let result = viewModel.battleResult {
                    Button {
                        HapticsService.shared.medium()
                        shareImage = BattleShareCard.render(
                            fighter1: fighter1,
                            fighter2: fighter2,
                            result: result,
                            environment: displayEnvironment,
                            arenaEffectsEnabled: viewModel.arenaEffectsEnabled,
                            image1: fighter1Image,
                            image2: fighter2Image
                        )
                        if shareImage != nil { showShareSheet = true }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Share")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.65))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 13)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1))
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                Button {
                    guard !AdManager.shared.isShowingAd else { return }
                    AdManager.shared.showInterstitialIfNeeded {
                        showConfetti = false
                        battleRound += 1
                        battleScene.reset()
                        viewModel.rematch()
                        winnerPhotoURL = nil
                        withAnimation(.spring(response: 0.4)) {
                            resultsPanelOffset = 700
                            fighter1Offset = -introOffset
                            fighter2Offset = introOffset
                            vsScale = 0.1
                            vsOpacity = 0
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("🔄").font(.system(size: 13))
                        Text("Rematch")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 13)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(AdManager.shared.isShowingAd)
            }

            // ── Tertiary: New Battle ─────────────────────────────
            Button {
                guard !AdManager.shared.isShowingAd else { return }
                AdManager.shared.showInterstitialIfNeeded { dismiss() }
            } label: {
                HStack(spacing: 6) {
                    Text("🐾")
                        .font(.system(size: 14))
                    Text("New Battle")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.orange)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Theme.orange.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 13)
                            .stroke(Theme.orange.opacity(0.35), lineWidth: 1))
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(AdManager.shared.isShowingAd)
        }
        }  // end else (non-tournament mode)
    }

    // MARK: - Tournament Draw Elimination

    /// Called from `.onChange(of: viewModel.phase)` when a tournament battle resolves
    /// to a draw. First draw re-runs the fight in a different arena; second draw is
    /// resolved with a client-side kid-friendly tiebreaker scenario that picks a winner.
    /// Both banners wait for the user to tap CONTINUE so they have time to read them.
    private func handleTournamentDraw() {
        HapticsService.shared.warning()
        tournamentDrawRetryCount += 1

        if tournamentDrawRetryCount == 1 {
            // Retry in a different arena — sometimes a draw is just an arena-balance quirk.
            pendingTournamentDrawContinuation = {
                let newEnv = pickDifferentTournamentArena()
                withAnimation(.easeOut(duration: 0.25)) {
                    showTournamentOvertimeBanner = false
                }
                pendingTournamentDrawContinuation = nil
                // Slight delay so the banner fully dismisses before the arena swap kicks in.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    switchArena(to: newEnv)
                }
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showTournamentOvertimeBanner = true
            }
        } else {
            // Settle with a silly tiebreaker so the bracket can advance.
            let tiebreaker = synthesizeTiebreakerResult()
            tiebreakerTitle = tiebreaker.title
            tiebreakerSubtitle = tiebreaker.subtitle
            pendingTournamentDrawContinuation = {
                withAnimation(.easeOut(duration: 0.25)) {
                    showTournamentTiebreakerBanner = false
                }
                pendingTournamentDrawContinuation = nil
                // Feed the synthesized result into the next battle run so the normal
                // reveal flow (typewriter, confetti, results panel) picks it up.
                viewModel.forcedResult = tiebreaker.result
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    rerunCurrentBattle()
                }
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showTournamentTiebreakerBanner = true
            }
        }
    }

    /// Kicks off a fresh battle run in the current arena (no env change).
    /// Used when injecting a forcedResult after a second draw.
    private func rerunCurrentBattle() {
        showConfetti = false
        battleRound += 1
        battleScene.reset()
        viewModel.rematch()
        winnerPhotoURL = nil
        withAnimation(.spring(response: 0.4)) {
            resultsPanelOffset = 700
            fighter1Offset = -introOffset
            fighter2Offset = introOffset
            vsScale = 0.1
            vsOpacity = 0
        }
    }

    /// Picks a random free-tier arena different from the current one so the
    /// rematch always feels like a venue change.
    private func pickDifferentTournamentArena() -> BattleEnvironment {
        let pool: [BattleEnvironment] = [.grassland, .ocean, .sky, .arctic, .desert]
        let candidates = pool.filter { $0 != displayEnvironment }
        return candidates.randomElement() ?? .grassland
    }

    /// Builds a randomized kid-friendly tiebreaker `BattleResult` that always
    /// picks a winner. Used only when two consecutive draws happen in tournament mode.
    private func synthesizeTiebreakerResult() -> (result: BattleResult, title: String, subtitle: String) {
        // Coin flip who wins
        let fighter1Wins = Bool.random()
        let winner  = fighter1Wins ? fighter1 : fighter2
        let loser   = fighter1Wins ? fighter2 : fighter1

        // Pick a silly scenario
        struct Scenario {
            let title: String
            let subtitle: String
            let narrate: (String, String) -> String
            let funFact: (String) -> String
        }
        let scenarios: [Scenario] = [
            Scenario(
                title: "THUMB WRESTLING!",
                subtitle: "Best of three, winner takes all.",
                narrate: { w, l in "After two ties, the judges called for a THUMB WRESTLING showdown! \(w) pinned \(l)'s thumb in a photo finish and took the win." },
                funFact: { w in "\(w) has surprisingly strong thumbs for a creature this size." }
            ),
            Scenario(
                title: "ROCK PAPER SCISSORS!",
                subtitle: "One throw, best of one.",
                narrate: { w, l in "Locked in a tie, the fight came down to ROCK PAPER SCISSORS. \(w) threw rock, \(l) threw scissors, and the crowd went wild!" },
                funFact: { w in "\(w) is apparently a rock-paper-scissors prodigy." }
            ),
            Scenario(
                title: "STARING CONTEST!",
                subtitle: "Don't blink or you lose.",
                narrate: { w, l in "After two draws the champions squared up for a STARING CONTEST. \(l) blinked first and \(w) claimed the trophy!" },
                funFact: { w in "\(w) can hold a glare longer than you'd ever believe." }
            ),
            Scenario(
                title: "COIN FLIP!",
                subtitle: "Heads or tails for all the glory.",
                narrate: { w, l in "The ref tossed a giant coin high into the air. It landed on \(w)'s side, leaving \(l) to shake hands and plot a rematch." },
                funFact: { w in "\(w) is having a very lucky day." }
            ),
            Scenario(
                title: "LIMBO CONTEST!",
                subtitle: "How low can you go?",
                narrate: { w, l in "Two draws in a row meant only one thing — LIMBO! \(w) bent like a noodle while \(l) tipped the bar and lost the round." },
                funFact: { w in "\(w) is secretly very bendy." }
            ),
            Scenario(
                title: "SANDCASTLE BUILD-OFF!",
                subtitle: "Tallest castle in two minutes.",
                narrate: { w, l in "With the score dead-even, the fighters were handed buckets for a SANDCASTLE BUILD-OFF. \(w)'s castle towered over \(l)'s and took the win." },
                funFact: { w in "\(w) has a surprising talent for architecture." }
            ),
            Scenario(
                title: "CANNONBALL SPLASH!",
                subtitle: "Biggest splash wins.",
                narrate: { w, l in "After two draws, the battle moved to the pool for a CANNONBALL contest. \(w) made a splash so big the judges got drenched — an easy win over \(l)!" },
                funFact: { w in "\(w) is a certified splash champion." }
            ),
            Scenario(
                title: "HIDE AND SEEK!",
                subtitle: "Find your opponent in 60 seconds.",
                narrate: { w, l in "Neither could land the knockout blow, so it came down to HIDE AND SEEK. \(w) found \(l) in record time and won the round." },
                funFact: { w in "\(w) has an amazing nose for finding hidden things." }
            ),
            Scenario(
                title: "DANCE-OFF!",
                subtitle: "Who's got the best moves?",
                narrate: { w, l in "With no clear winner, the fighters cranked the music for a DANCE-OFF. \(w) busted out moves so cool the crowd voted \(l) out." },
                funFact: { w in "\(w) has rhythm you would not expect." }
            ),
            Scenario(
                title: "BUBBLE GUM BUBBLE!",
                subtitle: "Blow the biggest bubble.",
                narrate: { w, l in "The fighters were handed bubble gum. \(w) blew a bubble the size of a beach ball while \(l)'s popped early. Champion crowned!" },
                funFact: { w in "\(w) can blow enormous bubbles. Who knew?" }
            )
        ]
        let pick = scenarios.randomElement()!

        let result = BattleResult(
            winner: winner.id,
            narration: pick.narrate(winner.name, loser.name),
            funFact: pick.funFact(winner.name),
            winnerHealthPercent: 55,
            loserHealthPercent: 45
        )
        return (result, pick.title, pick.subtitle)
    }

    // MARK: - Tournament Draw Banner

    /// Full-screen centered banner shown when a tournament draw is intercepted.
    /// Waits for the user to tap CONTINUE before running the continuation, so the
    /// message has time to register.
    private func tournamentDrawBanner(title: String, subtitle: String, emoji: String, glow: Color) -> some View {
        ZStack {
            // Dim backdrop — tapping anywhere outside also advances.
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { pendingTournamentDrawContinuation?() }

            VStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 68))
                Text(title)
                    .font(Theme.bungee(28))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .multilineTextAlignment(.center)
                    .shadow(color: glow.opacity(0.8), radius: 14, x: 0, y: 0)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(Theme.bungee(15))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    HapticsService.shared.medium()
                    pendingTournamentDrawContinuation?()
                } label: {
                    Text("CONTINUE")
                }
                .buttonStyle(MegaButtonStyle(color: .gold, height: 54, cornerRadius: 16, fontSize: 16))
                .padding(.top, 8)
                .padding(.horizontal, 10)

                Text("tap anywhere to continue")
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(0.5)
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(glow.opacity(0.7), lineWidth: 2)
                    )
                    .shadow(color: glow.opacity(0.5), radius: 20, x: 0, y: 0)
            )
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Switch Arena

    private func switchArena(to newEnv: BattleEnvironment) {
        // Allow the switch if either the environment is different, OR effects
        // were previously off — picking grasslands after a no-arena fight is
        // still a meaningful transition (neutral → grasslands with effects on).
        let sameEnv = newEnv == displayEnvironment
        let alreadyHadEffects = viewModel.arenaEffectsEnabled
        guard !sameEnv || !alreadyHadEffects else { return }
        viewModel.environment = newEnv
        displayEnvironment = newEnv
        // Explicitly picking a new arena from the winner card means "I want the
        // arena to matter" — re-enable arena effects so the new environment
        // actually influences the rematch.
        viewModel.arenaEffectsEnabled = true
        battleScene = BattleScene(
            fighter1: fighter1,
            fighter2: fighter2,
            size: CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height * 0.55
            ),
            environment: newEnv
        )
        showConfetti = false
        battleRound += 1
        viewModel.rematch()
        winnerPhotoURL = nil
        withAnimation(.spring(response: 0.4)) {
            resultsPanelOffset = 700
            fighter1Offset = -420
            fighter2Offset = 420
            vsScale = 0.1
            vsOpacity = 0
        }
    }

}

// MARK: - Arena Picker Sheet

struct ArenaPickerSheet: View {
    @Binding var isPresented: Bool
    /// The arena the previous battle was fought in, or `nil` if the battle was
    /// neutral (arena effects off). When nil, no grid cell is badged "CURRENT".
    let current: BattleEnvironment?
    let onSelect: (BattleEnvironment) -> Void

    @ObservedObject private var settings = UserSettings.shared
    @State private var selected: BattleEnvironment
    @State private var showPackSheet = false

    init(isPresented: Binding<Bool>, current: BattleEnvironment?, onSelect: @escaping (BattleEnvironment) -> Void) {
        self._isPresented = isPresented
        self.current = current
        self.onSelect = onSelect
        // Preselect the current arena if there was one; otherwise default to
        // grassland so the confirm-button label reads sensibly on open.
        self._selected = State(initialValue: current ?? .grassland)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .battle).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 4) {
                        Text("CHOOSE YOUR ARENA")
                            .font(Theme.bungee(18))
                            .foregroundColor(.white)
                        Text(current == nil
                             ? "Last round had no arena — pick one to add effects"
                             : "Same fighters — new battleground")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    // Environment grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(BattleEnvironment.allCases) { env in
                            let isUnlocked = settings.isEnvironmentUnlocked(env)
                            let isSel = env == selected
                            // Only show a "CURRENT" badge if there actually WAS
                            // an arena last round — otherwise the grasslands
                            // default would falsely claim to be the battle venue.
                            let isCur = current != nil && env == current

                            Button {
                                if isUnlocked {
                                    selected = env
                                    HapticsService.shared.tap()
                                } else {
                                    showPackSheet = true
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isSel ? env.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    isSel ? env.accentColor : Color.white.opacity(0.12),
                                                    lineWidth: isSel ? 2 : 1
                                                )
                                        )

                                    VStack(spacing: 5) {
                                        Text(env.emoji)
                                            .font(.system(size: 28))
                                            .opacity(isUnlocked ? 1.0 : 0.4)
                                        Text(env.name.uppercased())
                                            .font(.system(size: 9, weight: .black, design: .rounded))
                                            .foregroundColor(isSel ? env.accentColor : .white.opacity(0.6))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.6)
                                        if isCur {
                                            Text("CURRENT")
                                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                                .foregroundColor(env.accentColor.opacity(0.7))
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 6)

                                    if !isUnlocked {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.black.opacity(0.45))
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Confirm button
                    Button {
                        // Trigger onSelect unless they picked the same arena
                        // they were already fighting in — STAY is a no-op.
                        if selected != current {
                            onSelect(selected)
                        }
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Text(selected.emoji)
                            Text(current != nil && selected == current
                                 ? "STAY IN THIS ARENA"
                                 : "FIGHT IN \(selected.name.uppercased())!")
                                .font(Theme.bungee(14))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(
                                    colors: [selected.accentColor, selected.accentColor.opacity(0.7)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        )
                        .shadow(color: selected.accentColor.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { isPresented = false }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .sheet(isPresented: $showPackSheet) {
            EnvironmentsPackSheet(isPresented: $showPackSheet)
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let xFraction: CGFloat
        let size: CGSize
        let fallDuration: Double
        let delay: Double
        let rotationStart: Double
        let rotationEnd: Double
    }

    private let pieces: [Piece] = {
        let colors: [Color] = [
            Theme.gold, Theme.orange, Theme.purple, Theme.cyan, Theme.teal, Theme.red, .white,
            Color(hex: "#FF69B4"), Color(hex: "#7CFC00"), Color(hex: "#00BFFF")
        ]
        return (0..<55).map { i in
            Piece(
                id: i,
                color: colors[i % colors.count],
                xFraction: CGFloat(i) / 55.0 * 0.92 + 0.04,
                size: CGSize(width: CGFloat.random(in: 7...15), height: CGFloat.random(in: 5...9)),
                fallDuration: Double.random(in: 1.8...3.5),
                delay: Double.random(in: 0...1.4),
                rotationStart: Double.random(in: 0...360),
                rotationEnd: Double.random(in: 400...760)
            )
        }
    }()

    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .rotationEffect(.degrees(isAnimating ? piece.rotationEnd : piece.rotationStart))
                    .position(
                        x: piece.xFraction * geo.size.width,
                        y: isAnimating ? geo.size.height + 30 : -20
                    )
                    .opacity(isAnimating ? 0 : 0.9)
                    .animation(
                        .easeIn(duration: piece.fallDuration).delay(piece.delay),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            // Small delay before triggering so SwiftUI renders positions first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Ad Prompt Sheet (shown every 3rd battle once 5+ battles played)

struct AdPromptSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        ZStack {
            ScreenBackground(style: .battle).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("🎮")
                    .font(.system(size: 64))
                    .padding(.bottom, 14)

                Text("ENJOYING THE APP?")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Remove ads forever with a one-time purchase and keep the battles going!")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    // Remove Ads CTA
                    Button {
                        Task {
                            if let product = store.removeAdsProduct {
                                let success = await store.purchase(product)
                                if success { isPresented = false }
                            } else {
                                #if DEBUG
                                settings.hasRemovedAds = true
                                isPresented = false
                                #else
                                await store.loadProducts()
                                #endif
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("🚫")
                            Text(store.removeAdsProduct.map { "Remove Ads — \($0.displayPrice)" } ?? "Remove Ads — $4.99")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(colors: [Theme.orange, Theme.yellow], startPoint: .leading, endPoint: .trailing))
                        )
                        .shadow(color: Theme.orange.opacity(0.45), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 24)

                    // Not now
                    Button { isPresented = false } label: {
                        Text("NOT NOW")
                            .font(Theme.bungee(13))
                            .tracking(1)
                            .foregroundColor(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 40)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Fighter Image Loader

extension BattleView {
    /// Returns the best available UIImage for use in the SpriteKit battle scene.
    /// Priority: pack-creature asset → custom photo → nil (falls back to emoji sprite).
    func loadFighterImage(_ animal: Animal) async -> UIImage? {
        if let assetName = animal.creatureAssetName,
           let img = UIImage(named: assetName) {
            return img
        }
        if animal.isCustom {
            return await AnimalImageService.shared.image(for: animal)
        }
        return nil
    }
}

// MARK: - Wikipedia Photo Fetch

extension BattleView {
    func fetchWikipediaPhotoURL(for name: String) async -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let thumbnail = json["thumbnail"] as? [String: Any],
               let source = thumbnail["source"] as? String {
                return URL(string: source)
            }
        } catch {}
        return nil
    }
}

// MARK: - First Custom Creature Celebration Banner
// Shown once, after the user finishes their FIRST battle with a custom creature.
// Paired with the +50 coin bonus from CoinStore.earnFirstCustomBonus().

struct FirstCustomBanner: View {
    @Binding var isShowing: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("✨ FIRST CUSTOM BATTLE! ✨")
                .font(Theme.bungee(16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.neonGrn, Theme.gold, Theme.orange],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Theme.neonGrn.opacity(0.6), radius: 8, x: 0, y: 0)
                .multilineTextAlignment(.center)

            Text("You created your first custom fighter!")
                .font(Theme.lilita(14))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                GoldCoin(size: 16)
                Text("+50 bonus coins!")
                    .font(Theme.lilita(14))
                    .foregroundColor(Theme.gold)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.neonGrn.opacity(0.5), lineWidth: 1.5)
                )
        )
        .shadow(color: Theme.neonGrn.opacity(0.3), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 28)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.4)) { isShowing = false }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BattleView(
            fighter1: Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4),
            fighter2: Animal(id: "tiger", name: "Tiger", emoji: "🐯", category: .land, pixelColor: "#FF8C00", size: 4)
        )
    }
}
