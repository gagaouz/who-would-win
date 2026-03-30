import SwiftUI
import SpriteKit
import UIKit

struct BattleView: View {
    let fighter1: Animal
    let fighter2: Animal
    @StateObject private var viewModel: BattleViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Animation State

    @State private var fighter1Offset: CGFloat = -420
    @State private var fighter2Offset: CGFloat = 420
    @State private var vsScale: CGFloat = 0.1
    @State private var vsOpacity: Double = 0

    @State private var resultsPanelOffset: CGFloat = 700
    @State private var winnerPhotoURL: URL? = nil
    @State private var showConfetti = false
    @State private var showAdPrompt = false

    @State private var battleScene: BattleScene
    @State private var battleRound: Int = 0
    @State private var showFantasyBanner = false

    @StateObject private var speech = SpeechService()

    // MARK: - Init

    init(fighter1: Animal, fighter2: Animal) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        _viewModel = StateObject(wrappedValue: BattleViewModel(fighter1: fighter1, fighter2: fighter2))
        _battleScene = State(initialValue: BattleScene(
            fighter1: fighter1,
            fighter2: fighter2,
            size: CGSize(
                width: UIScreen.main.bounds.width,
                height: UIScreen.main.bounds.height * 0.55
            )
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
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            async let img1: UIImage? = fighter1.isCustom ? AnimalImageService.shared.image(for: fighter1) : nil
            async let img2: UIImage? = fighter2.isCustom ? AnimalImageService.shared.image(for: fighter2) : nil
            let (image1, image2) = await (img1, img2)
            if let img = image1 { battleScene.setFighterImage(img, forFighter: 1) }
            if let img = image2 { battleScene.setFighterImage(img, forFighter: 2) }
        }
        .task(id: battleRound) {
            battleScene.onAnimationComplete = {
                Task { @MainActor in viewModel.animationDidComplete() }
            }
            await viewModel.startBattle()
        }
        .onChange(of: viewModel.phase) { newPhase in
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
                UserSettings.shared.recordBattle()

                // Fantasy milestone celebration (fires once, the battle that crosses 50)
                if justHitMilestone {
                    HapticsService.shared.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            showFantasyBanner = true
                        }
                    }
                }

                if UserSettings.shared.shouldShowAd {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showAdPrompt = true
                    }
                }
            }
        }
        .sheet(isPresented: $showAdPrompt) {
            AdPromptSheet(isPresented: $showAdPrompt)
        }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        LinearGradient(
            colors: [Theme.bgDeep, Theme.bgMid],
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
                        .frame(width: geo.size.width * 0.42)
                        .offset(x: fighter1Offset)

                    Spacer()

                    Text("VS")
                        .font(.custom("PressStart2P-Regular", size: 30))
                        .foregroundColor(Theme.orange)
                        .shadow(color: Theme.orange.opacity(0.8), radius: 10, x: 0, y: 0)
                        .scaleEffect(vsScale)
                        .opacity(vsOpacity)

                    Spacer()

                    fighterCard(animal: fighter2, accentColor: Theme.cyan)
                        .frame(width: geo.size.width * 0.42)
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

                if let url = animal.imageURL {
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
                .shadow(color: accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
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

            battleProgressPanel
        }
        .ignoresSafeArea(edges: .top)
    }

    private var battleProgressPanel: some View {
        VStack(spacing: 20) {
            Spacer()

            // Turn indicator
            HStack(spacing: 14) {
                fighterTurnBadge(name: fighter1.name, emoji: fighter1.emoji, color: Theme.orange)
                Text("⚔️")
                    .font(.system(size: 22))
                fighterTurnBadge(name: fighter2.name, emoji: fighter2.emoji, color: Theme.cyan)
            }
            .padding(.horizontal, 28)

            // Pulsing bar
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [Theme.orange.opacity(0.6), Theme.yellow.opacity(0.6), Theme.cyan.opacity(0.6)],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 3)
                .frame(maxWidth: 200)
                .opacity(0.55)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func fighterTurnBadge(name: String, emoji: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 26))
            Text(name.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
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
                            colors: [.clear, Theme.bgDeep.opacity(0.6)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            resultsCard
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
                    // Drag pill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 40, height: 5)
                        .padding(.top, 14)
                        .padding(.bottom, 18)

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
                                        .foregroundColor(.white.opacity(0.55))
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

                            // Winner photo
                            if !isDraw, let photoURL = winnerPhotoURL {
                                AsyncImage(url: photoURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 170)
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
                                            .frame(maxWidth: .infinity).frame(height: 170)
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
                                .foregroundColor(.white.opacity(0.9))
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
                                    .foregroundColor(speech.isSpeaking ? Theme.orange : .white.opacity(0.6))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(speech.isSpeaking ? Theme.orange.opacity(0.15) : Color.white.opacity(0.08))
                                            .overlay(Capsule().stroke(
                                                speech.isSpeaking ? Theme.orange.opacity(0.4) : Color.white.opacity(0.15),
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
                                        .foregroundColor(.white.opacity(0.85))
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
                                VStack(spacing: 12) {
                                    Button {
                                        showConfetti = false
                                        battleRound += 1
                                        battleScene.reset()
                                        viewModel.rematch()
                                        winnerPhotoURL = nil
                                        withAnimation(.spring(response: 0.4)) {
                                            resultsPanelOffset = 700
                                            fighter1Offset = -420
                                            fighter2Offset = 420
                                            vsScale = 0.1
                                            vsOpacity = 0
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

                                    Button {
                                        dismiss()
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text("🐾")
                                            Text("NEW BATTLE")
                                                .font(.system(size: 17, weight: .black, design: .rounded))
                                                .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18)
                                                .fill(Color.white.opacity(0.09))
                                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.22), lineWidth: 1.5))
                                        )
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
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
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                )
            }
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
            StarFieldOverlay().ignoresSafeArea().allowsHitTesting(false)

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
                    .foregroundColor(.white.opacity(0.65))
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
                                settings.hasRemovedAds = true
                                isPresented = false
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
                            .foregroundColor(.white.opacity(0.45))
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
