import SwiftUI
import SpriteKit
import UIKit
import StoreKit

struct BattleView: View {
    let fighter1: Animal
    let fighter2: Animal
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
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    @State private var fighter1Image: UIImage? = nil
    @State private var fighter2Image: UIImage? = nil
    @State private var showArenaSheet = false
    @Environment(\.requestReview) private var requestReview

    @StateObject private var speech = SpeechService()

    // MARK: - Init

    init(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, arenaEffectsEnabled: Bool = true) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        _displayEnvironment = State(initialValue: environment)
        let offscreen = UIScreen.main.bounds.width * 1.1
        _fighter1Offset = State(initialValue: -offscreen)
        _fighter2Offset = State(initialValue: offscreen)
        _viewModel = StateObject(wrappedValue: BattleViewModel(fighter1: fighter1, fighter2: fighter2, environment: environment, arenaEffectsEnabled: arenaEffectsEnabled))
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

            // Olympus unlock milestone banner
            if showOlympusBanner {
                VStack {
                    OlympusUnlockedBanner(isShowing: $showOlympusBanner)
                        .padding(.top, 60)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                BattleShareSheet(image: img)
                    .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
            }
        }
        .sheet(isPresented: $showArenaSheet) {
            ArenaPickerSheet(
                isPresented: $showArenaSheet,
                current: displayEnvironment
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
                UserSettings.shared.recordBattle()

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
                // Arena label
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
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
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
                .font(.system(size: 7, weight: .black, design: .rounded))
                .foregroundColor(Theme.textSecondary)
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
                                .init(color: Theme.bgDeep, location: 0.0),
                                .init(color: Theme.bgDeep, location: 0.30),
                                .init(color: .clear, location: 0.55),
                                .init(color: Theme.bgDeep.opacity(0.7), location: 1.0)
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
                        .fill(Theme.divider)
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
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.gold)
                                        .shadow(color: Theme.gold.opacity(0.4), radius: 8, x: 0, y: 0)
                                }
                            } else {
                                VStack(spacing: 6) {
                                    Text("🏆")
                                        .font(.system(size: 60))
                                        .shadow(color: Theme.gold.opacity(0.6), radius: 12, x: 0, y: 0)

                                    Text("WINNER!")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textSecondary)
                                        .tracking(3)

                                    Text(winnerAnimal.name.uppercased())
                                        .font(.system(size: 26, weight: .black, design: .rounded))
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

                            // Environment badge
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

                            // Winner photo
                            if !isDraw, let photoURL = winnerPhotoURL {
                                AsyncImage(url: photoURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: .infinity)
                                            .frame(maxHeight: 240)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(
                                                        LinearGradient(colors: [winnerAccent, Theme.gold], startPoint: .leading, endPoint: .trailing),
                                                        lineWidth: 2
                                                    )
                                            )
                                            .shadow(color: winnerAccent.opacity(0.35), radius: 12, x: 0, y: 6)
                                    case .failure:
                                        EmptyView()
                                    case .empty:
                                        RoundedRectangle(cornerRadius: 18)
                                            .fill(Color.white.opacity(0.05))
                                            .frame(maxWidth: .infinity).frame(height: 160)
                                            .overlay(ProgressView().tint(Theme.gold))
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
                                .foregroundColor(Theme.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 4)
                                .animation(.easeIn(duration: 0.03), value: viewModel.narrationDisplayed)

                            // Speaker button
                            if viewModel.phase == .complete, !result.narration.isEmpty {
                                Button(action: {
                                    speech.speak(result.narration + (result.funFact.isEmpty ? "" : ". Fun fact: \(result.funFact)"))
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: speech.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2")
                                            .font(.system(size: 15, weight: .medium))
                                        Text(speech.isSpeaking ? "Stop" : "Read Aloud")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundColor(speech.isSpeaking ? Theme.orange : Theme.textSecondary)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(speech.isSpeaking ? Theme.orange.opacity(0.15) : Theme.cardFill)
                                            .overlay(Capsule().stroke(
                                                speech.isSpeaking ? Theme.orange.opacity(0.4) : Theme.cardBorder,
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
                                        .foregroundColor(Theme.textPrimary)
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
                        .stroke(Theme.cardBorder, lineWidth: 1)
                    )
                )
            }
        }
    }

    // MARK: - Result Action Buttons (extracted to avoid type-check timeout)

    @ViewBuilder
    private var resultActionButtons: some View {
        VStack(spacing: 12) {
            // Share button
            if let result = viewModel.battleResult {
                Button {
                    HapticsService.shared.medium()
                    shareImage = BattleShareCard.render(
                        fighter1: fighter1,
                        fighter2: fighter2,
                        result: result,
                        environment: displayEnvironment,
                        image1: fighter1Image,
                        image2: fighter2Image
                    )
if shareImage != nil { showShareSheet = true }
                } label: {
                    shareButtonLabel
                }
                .buttonStyle(PressableButtonStyle())
            }

            // Try New Arena — environment picker
            Button {
                HapticsService.shared.tap()
                showArenaSheet = true
            } label: {
                HStack(spacing: 8) {
                    Text(displayEnvironment.emoji).font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TRY NEW ARENA")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Same fighters, different terrain")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(displayEnvironment.accentColor.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(displayEnvironment.accentColor.opacity(0.4), lineWidth: 1.5))
                )
            }
            .buttonStyle(PressableButtonStyle())

            // Rematch
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
                HStack(spacing: 8) {
                    Text("🔄")
                    Text("REMATCH!")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(
                            colors: [Theme.orange, Theme.yellow],
                            startPoint: .leading, endPoint: .trailing
                        ))
                )
                .shadow(color: Theme.orange.opacity(0.45), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(AdManager.shared.isShowingAd)

            // New Battle
            Button {
                guard !AdManager.shared.isShowingAd else { return }
                AdManager.shared.showInterstitialIfNeeded { dismiss() }
            } label: {
                HStack(spacing: 8) {
                    Text("🐾")
                    Text("NEW BATTLE")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Theme.cardFill)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder, lineWidth: 1.5))
                )
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(AdManager.shared.isShowingAd)
        }
    }

    // MARK: - Switch Arena

    private func switchArena(to newEnv: BattleEnvironment) {
        guard newEnv != displayEnvironment else { return }
        viewModel.environment = newEnv
        displayEnvironment = newEnv
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

    private var shareButtonLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .bold))
            Text("SHARE THIS BATTLE")
                .font(.system(size: 16, weight: .black, design: .rounded))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: [Theme.gold, Theme.orange],
                    startPoint: .leading, endPoint: .trailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1))
        )
        .shadow(color: Theme.gold.opacity(0.4), radius: 12, x: 0, y: 5)
    }
}

// MARK: - Arena Picker Sheet

struct ArenaPickerSheet: View {
    @Binding var isPresented: Bool
    let current: BattleEnvironment
    let onSelect: (BattleEnvironment) -> Void

    @ObservedObject private var settings = UserSettings.shared
    @State private var selected: BattleEnvironment
    @State private var showPackSheet = false

    init(isPresented: Binding<Bool>, current: BattleEnvironment, onSelect: @escaping (BattleEnvironment) -> Void) {
        self._isPresented = isPresented
        self.current = current
        self.onSelect = onSelect
        self._selected = State(initialValue: current)
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.mainBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 4) {
                        Text("CHOOSE YOUR ARENA")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Same fighters — new battleground")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    // Environment grid
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(BattleEnvironment.allCases) { env in
                            let isUnlocked = settings.isEnvironmentUnlocked(env)
                            let isSel = env == selected
                            let isCur = env == current

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
                                            .foregroundColor(isSel ? env.accentColor : Theme.textSecondary)
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
                        if selected != current {
                            onSelect(selected)
                        }
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Text(selected.emoji)
                            Text(selected == current ? "STAY IN THIS ARENA" : "FIGHT IN \(selected.name.uppercased())!")
                                .font(.system(size: 16, weight: .black, design: .rounded))
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
                        .foregroundColor(Theme.textSecondary)
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
            Theme.mainBg.ignoresSafeArea()
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                Text("🎮")
                    .font(.system(size: 64))
                    .padding(.bottom, 14)

                Text("ENJOYING THE APP?")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.bottom, 8)

                Text("Remove ads forever with a one-time purchase and keep the battles going!")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textSecondary)
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
                        Text("Not now")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textTertiary)
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

#Preview {
    NavigationStack {
        BattleView(
            fighter1: Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4),
            fighter2: Animal(id: "tiger", name: "Tiger", emoji: "🐯", category: .land, pixelColor: "#FF8C00", size: 4)
        )
    }
}
