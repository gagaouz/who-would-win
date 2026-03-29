import SwiftUI
import SpriteKit
import UIKit

struct BattleView: View {
    let fighter1: Animal
    let fighter2: Animal
    @StateObject private var viewModel: BattleViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Animation State

    // Intro
    @State private var fighter1Offset: CGFloat = -420
    @State private var fighter2Offset: CGFloat = 420
    @State private var vsScale: CGFloat = 0.1
    @State private var vsOpacity: Double = 0

    // Calculating dots
    @State private var dotCount: Int = 0
    @State private var dotTimer: Timer? = nil
    @State private var calculatingPulse: Double = 1.0

    // Results
    @State private var resultsPanelOffset: CGFloat = 700
    @State private var bgHueShift: Double = 0
    @State private var winnerPhotoURL: URL? = nil

    // SpriteKit scene — created once
    @State private var battleScene: BattleScene

    // Rematch counter — incrementing re-fires .task
    @State private var battleRound: Int = 0

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
            // Animated background gradient
            animatedBackground

            switch viewModel.phase {
            case .intro:
                introPhaseView
            case .animating, .fetchingResult:
                animatingPhaseView
            case .revealing, .complete:
                revealingPhaseView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Fetch and apply real images for custom animals to the battle sprites
            async let img1: UIImage? = fighter1.isCustom
                ? AnimalImageService.shared.image(for: fighter1) : nil
            async let img2: UIImage? = fighter2.isCustom
                ? AnimalImageService.shared.image(for: fighter2) : nil
            let (image1, image2) = await (img1, img2)
            if let img = image1 { battleScene.setFighterImage(img, forFighter: 1) }
            if let img = image2 { battleScene.setFighterImage(img, forFighter: 2) }
        }
        .task(id: battleRound) {
            // Wire up callback BEFORE starting battle
            battleScene.onAnimationComplete = {
                Task { @MainActor in
                    viewModel.animationDidComplete()
                }
            }
            await viewModel.startBattle()
        }
        .onChange(of: viewModel.phase) { newPhase in
            if newPhase == .revealing, let result = viewModel.battleResult {
                battleScene.setBattleResult(result)
                // Fetch real winner photo from Wikipedia
                if result.winner != "draw" {
                    let winnerAnimal = result.winner == fighter1.id ? fighter1 : fighter2
                    winnerPhotoURL = nil
                    Task {
                        winnerPhotoURL = await fetchWikipediaPhotoURL(for: winnerAnimal.name)
                    }
                }
            }
        }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: "#0A0A1A"),
                Color(hex: "#12082A")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: true)) {
                bgHueShift = 1
            }
        }
    }

    // MARK: - PHASE 1: Intro

    private var introPhaseView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()

                // Fighter cards row
                HStack(alignment: .center, spacing: 0) {
                    // Fighter 1 card — slides in from left
                    fighterCard(animal: fighter1, mirrored: false)
                        .frame(width: geo.size.width * 0.42)
                        .offset(x: fighter1Offset)

                    Spacer()

                    // VS label — slams from above
                    Text("VS")
                        .font(.custom("PressStart2P-Regular", size: 28))
                        .foregroundColor(Color(hex: "#FF6B35"))
                        .shadow(color: Color(hex: "#FF6B35").opacity(0.7), radius: 8, x: 0, y: 0)
                        .scaleEffect(vsScale)
                        .opacity(vsOpacity)

                    Spacer()

                    // Fighter 2 card — slides in from right
                    fighterCard(animal: fighter2, mirrored: true)
                        .frame(width: geo.size.width * 0.42)
                        .offset(x: fighter2Offset)
                }
                .padding(.horizontal, 12)

                Spacer()

                // Health bar indicators at bottom
                HStack(spacing: 16) {
                    simpleHealthBar(color: Color(hex: "#39FF14"))
                    simpleHealthBar(color: Color(hex: "#39FF14"))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(vsOpacity)  // Fade in with VS
            }
        }
        .onAppear {
            playIntroAnimation()
        }
    }

    private func fighterCard(animal: Animal, mirrored: Bool) -> some View {
        VStack(spacing: 10) {
            // Photo or emoji with glow
            ZStack {
                Circle()
                    .fill(Color(hex: animal.pixelColor).opacity(0.18))
                    .frame(width: 88, height: 88)
                    .blur(radius: 12)

                if let url = animal.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        default:
                            Text(animal.emoji).font(.system(size: 80))
                        }
                    }
                } else {
                    Text(animal.emoji)
                        .font(.system(size: 80))
                }
            }

            Text(animal.name.uppercased())
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#FFD700"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func simpleHealthBar(color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: geo.size.width)
            }
        }
        .frame(height: 8)
    }

    private func playIntroAnimation() {
        // AudioManager.shared.playIntro()  // Audio disabled

        // Fighter 1 slides in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
            fighter1Offset = 0
        }

        // Fighter 2 slides in slightly after
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                fighter2Offset = 0
            }
        }

        // VS slams in from above with spring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) {
                vsScale = 1.0
                vsOpacity = 1.0
            }
        }
    }

    // MARK: - PHASE 2: Animating

    private var animatingPhaseView: some View {
        VStack(spacing: 0) {
            // SpriteKit fills top 55%
            SpriteView(scene: battleScene)
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.55)
                .ignoresSafeArea(edges: .top)

            // Bottom 45% — dark glass panel
            calculatingPanel
                .frame(maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            startDotAnimation()
        }
        .onDisappear {
            stopDotAnimation()
        }
    }

    private var calculatingPanel: some View {
        VStack(spacing: 24) {
            Spacer()

            // "CALCULATING WINNER..." with animated dots
            HStack(spacing: 4) {
                Text("CALCULATING WINNER")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(String(repeating: ".", count: dotCount))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#FFD700"))
                    .frame(width: 24, alignment: .leading)
            }
            .opacity(calculatingPulse)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    calculatingPulse = 0.4
                }
            }

            // Decorative stat icons
            HStack(spacing: 32) {
                battleStatIcon(icon: "⚡", label: "Speed")
                battleStatIcon(icon: "💪", label: "Strength")
                battleStatIcon(icon: "🛡️", label: "Defense")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            Color.white.opacity(0.05)
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func battleStatIcon(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 28))
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.5))
        }
    }

    private func startDotAnimation() {
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
            dotCount = (dotCount % 3) + 1
        }
    }

    private func stopDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = nil
    }

    // MARK: - PHASE 3: Revealing / Complete

    private var revealingPhaseView: some View {
        ZStack(alignment: .bottom) {
            // SpriteKit at top
            VStack(spacing: 0) {
                SpriteView(scene: battleScene)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.height * 0.55)
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Color(hex: "#0A0A1A").opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Results card slides up from bottom
            resultsCard
                .offset(y: resultsPanelOffset)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
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

                VStack(spacing: 0) {
                    // Drag indicator pill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    VStack(spacing: 16) {

                        // Trophy / draw icon
                        Text(isDraw ? "⚔️" : "🏆")
                            .font(.system(size: 52))

                        // Winner label
                        if isDraw {
                            Text("IT'S A DRAW!")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(Color(hex: "#FFD700"))
                        } else {
                            VStack(spacing: 4) {
                                Text("WINNER!")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.6))
                                    .tracking(2)

                                Text(winnerAnimal.name.uppercased())
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(Color(hex: "#FFD700"))
                                    .multilineTextAlignment(.center)
                                    .shadow(color: Color(hex: "#FFD700").opacity(0.45), radius: 8, x: 0, y: 0)
                            }
                        }

                        // Real winner photo (Wikipedia)
                        if !isDraw, let photoURL = winnerPhotoURL {
                            AsyncImage(url: photoURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color(hex: "#FFD700").opacity(0.5), lineWidth: 1.5)
                                        )
                                        .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 4)
                                case .failure:
                                    EmptyView()
                                case .empty:
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 160)
                                        .overlay(
                                            ProgressView()
                                                .tint(Color(hex: "#FFD700"))
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }

                        // Offline badge
                        if result.isOfflineFallback {
                            HStack(spacing: 5) {
                                Text("⚡")
                                    .font(.system(size: 12))
                                Text("Offline result")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(hex: "#FFB347"))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#FFB347").opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(hex: "#FFB347").opacity(0.4), lineWidth: 1)
                                    )
                            )
                        }

                        // Narration (typewriter)
                        Text(viewModel.narrationDisplayed)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 4)
                            .animation(.easeIn(duration: 0.03), value: viewModel.narrationDisplayed)

                        // Fun fact section
                        if !result.funFact.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text("FUN FACT ✨")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "#39FF14"))
                                }

                                Text(result.funFact)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(3)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color(hex: "#39FF14").opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }

                        // Action buttons
                        HStack(spacing: 14) {
                            Button {
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
                                Text("REMATCH")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "#FF6B35"), Color(hex: "#FF4500")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                    .shadow(color: Color(hex: "#FF6B35").opacity(0.4), radius: 8, x: 0, y: 4)
                            }

                            Button {
                                dismiss()
                            } label: {
                                Text("NEW BATTLE")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                                            )
                                    )
                            }
                        }
                        .padding(.top, 4)

                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
                }
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 28
                    )
                    .fill(.ultraThinMaterial)
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 28
                        )
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                )
            }
        }
    }
}

// MARK: - Wikipedia Photo Fetch

extension BattleView {
    /// Looks up the animal on Wikipedia and returns the thumbnail image URL.
    func fetchWikipediaPhotoURL(for name: String) async -> URL? {
        let encoded = name
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string:
            "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
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

// MARK: - Preview

#Preview {
    NavigationStack {
        BattleView(
            fighter1: Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4),
            fighter2: Animal(id: "tiger", name: "Tiger", emoji: "🐯", category: .land, pixelColor: "#FF8C00", size: 4)
        )
    }
}
