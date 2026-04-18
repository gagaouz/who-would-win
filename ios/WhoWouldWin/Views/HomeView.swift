import SwiftUI

struct HomeView: View {
    @AppStorage("hasSeenDisclaimer") private var hasSeenDisclaimer = false
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var showDisclaimer = false
    @State private var disclaimerShownThisSession = false
    @State private var playPulse = false
    @State private var titleGlow = false
    // Single bounce value — both animals use it so they always stay level
    @State private var animalBounce: CGFloat = 0
    @State private var vsScale: CGFloat = 1.0

    private let heroPairs: [(String, String)] = [
        ("🦁", "🐯"), ("🦈", "🐊"), ("🦅", "🐺"),
        ("🐘", "🦏"), ("🦍", "🐻"), ("🦁", "🦈")
    ]
    @State private var pairIndex = 0
    @State private var pairTimer: Timer? = nil
    @State private var showTournament = false
    @State private var showResumeSheet = false
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var tournamentManager = TournamentManager.shared
    @Environment(\.horizontalSizeClass) var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .home)

                // Settings gear — top right, coin badge top center
                VStack {
                    HStack {
                        // Settings button — frosted glass circle
                        Button(action: {
                            HapticsService.shared.tap()
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: isIPad ? 22 : 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: isIPad ? 50 : 44, height: isIPad ? 50 : 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, isIPad ? 32 : 20)

                        Spacer()

                        CoinBadge(size: isIPad ? .large : .regular, showProgress: false)

                        Spacer()

                        // Help button — frosted glass circle
                        Button(action: { showHelp = true }) {
                            Text("?")
                                .font(.system(size: isIPad ? 22 : 18, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: isIPad ? 50 : 44, height: isIPad ? 50 : 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, isIPad ? 32 : 20)
                    }
                    .padding(.top, 8)
                    Spacer()
                }

                // Main content — GeometryReader lets us position the hero
                // animals at a consistent screen-proportion on every device
                // instead of relying on a collapsible Spacer.
                GeometryReader { geo in
                  HStack {
                    Spacer(minLength: 0)
                  VStack(spacing: 0) {

                    // Pin the animals to a consistent position below the header.
                    // Phones: 22% of height. iPads: 12% (larger screens need less relative gap).
                    Spacer(minLength: geo.size.height * (isIPad ? 0.12 : 0.22))

                    // Two hero animals
                    HStack(alignment: .center, spacing: 0) {
                        Text(heroPairs[pairIndex].0)
                            .font(.system(size: isIPad ? 140 : 80))
                            .shadow(color: Theme.orange.opacity(0.6), radius: isIPad ? 24 : 12, x: 0, y: 0)
                            .transition(.scale.combined(with: .opacity))

                        Spacer()

                        VSShield(size: isIPad ? 70 : 56, fontSize: isIPad ? 22 : 18)
                            .scaleEffect(vsScale)

                        Spacer()

                        Text(heroPairs[pairIndex].1)
                            .font(.system(size: isIPad ? 140 : 80))
                            .shadow(color: Theme.cyan.opacity(0.6), radius: isIPad ? 24 : 12, x: 0, y: 0)
                            .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.horizontal, isIPad ? 60 : 40)
                    .offset(y: animalBounce)
                    .padding(.bottom, isIPad ? 40 : 28)

                    // Title — bright yellow with orange stroke feel
                    VStack(spacing: isIPad ? 8 : 4) {
                        VStack(spacing: isIPad ? 2 : -2) {
                            Text("ANIMAL")
                                .font(Theme.bungee(isIPad ? 54 : 38))
                                .foregroundColor(Theme.yellow)
                                .shadow(color: Theme.orange, radius: 0, x: 2, y: 2)
                                .shadow(color: Theme.orange, radius: 0, x: -2, y: -2)
                                .shadow(color: Theme.orange, radius: 0, x: 2, y: -2)
                                .shadow(color: Theme.orange, radius: 0, x: -2, y: 2)
                                .shadow(color: Theme.yellow.opacity(titleGlow ? 0.8 : 0.3), radius: titleGlow ? (isIPad ? 28 : 18) : (isIPad ? 14 : 8))

                            Text("VS ANIMAL")
                                .font(Theme.bungee(isIPad ? 44 : 30))
                                .foregroundColor(.white)
                                .shadow(color: Color(hex: "#1565C0"), radius: 0, x: 2, y: 2)
                                .shadow(color: Color(hex: "#1565C0"), radius: 0, x: -2, y: -2)
                                .shadow(color: Color(hex: "#1565C0"), radius: 0, x: 2, y: -2)
                                .shadow(color: Color(hex: "#1565C0"), radius: 0, x: -2, y: 2)
                                .shadow(color: .white.opacity(0.3), radius: 6)
                        }
                        .multilineTextAlignment(.center)

                        Text("Who Would Win?")
                            .font(Theme.bungee(isIPad ? 22 : 16))
                            .foregroundColor(.white.opacity(0.65))
                            .tracking(1)
                    }
                    .padding(.horizontal, 16)

                    Spacer().frame(height: geo.size.height * 0.03)

                    // Streak badge
                    if settings.currentStreak >= 2 {
                        HStack(spacing: 8) {
                            Text("🔥")
                                .font(.system(size: isIPad ? 20 : 15))
                            Text("\(settings.currentStreak) day streak!")
                                .font(.system(size: isIPad ? 17 : 13, weight: .black, design: .rounded))
                                .foregroundColor(Theme.orange)
                        }
                        .padding(.horizontal, isIPad ? 22 : 16)
                        .padding(.vertical, isIPad ? 12 : 8)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().stroke(Theme.orange.opacity(0.5), lineWidth: 2))
                        )
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .padding(.bottom, 10)
                        .transition(.scale.combined(with: .opacity))
                    }

                    Spacer().frame(height: geo.size.height * 0.025)

                    // Big BATTLE button — Supercell mega button style
                    NavigationLink(destination: AnimalPickerView()) {
                        HStack(spacing: isIPad ? 16 : 10) {
                            Text("⚔️").font(.system(size: isIPad ? 38 : 28))
                            Text("LET'S BATTLE!")
                            Text("⚔️").font(.system(size: isIPad ? 38 : 28))
                        }
                    }
                    .buttonStyle(MegaButtonStyle(color: .orange, height: isIPad ? 100 : 78, cornerRadius: isIPad ? 28 : 22, fontSize: isIPad ? 28 : 22))
                    .scaleEffect(playPulse ? 1.025 : 1.0)
                    .padding(.horizontal, isIPad ? 60 : 28)

                    // Tournament button (unlocks at 30 battles)
                    if settings.isTournamentUnlocked {
                        Button {
                            HapticsService.shared.tap()
                            if tournamentManager.hasResumableTournament {
                                showResumeSheet = true
                            } else {
                                showTournament = true
                            }
                        } label: {
                            HStack(spacing: isIPad ? 14 : 8) {
                                Text("🏆").font(.system(size: isIPad ? 28 : 22))
                                Text("TOURNAMENT")
                                Text("🏆").font(.system(size: isIPad ? 28 : 22))
                            }
                        }
                        .buttonStyle(MegaButtonStyle(color: .gold, height: isIPad ? 70 : 58, cornerRadius: isIPad ? 22 : 18, fontSize: isIPad ? 20 : 16))
                        .padding(.horizontal, isIPad ? 60 : 28)
                        .padding(.top, geo.size.height * 0.012)
                    } else {
                        TournamentUnlockNudge(progress: settings.tournamentUnlockProgress,
                                              current: settings.totalBattleCount,
                                              threshold: UserSettings.tournamentBattleThreshold)
                            .frame(maxWidth: isIPad ? 580 : .infinity)
                            .padding(.horizontal, isIPad ? 60 : 28)
                            .padding(.top, geo.size.height * 0.012)
                    }

                    // Custom creature CTA — rotating examples
                    CustomCreatureCTA()
                        .frame(maxWidth: isIPad ? 580 : .infinity)
                        .padding(.horizontal, isIPad ? 60 : 28)
                        .padding(.top, geo.size.height * 0.012)

                    // Pack journey nudge
                    if !settings.isOlympusUnlocked {
                        PackJourneyNudge()
                            .frame(maxWidth: isIPad ? 580 : .infinity)
                            .padding(.top, geo.size.height * 0.015)
                    }

                    Spacer()

                    Text("Just for fun — no real animals are harmed 🐾")
                        .font(.system(size: isIPad ? 14 : 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                  }
                  .frame(maxWidth: isIPad ? 720 : .infinity)
                    Spacer(minLength: 0)
                  } // HStack
                } // GeometryReader
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if !hasSeenDisclaimer && !disclaimerShownThisSession {
                showDisclaimer = true
                disclaimerShownThisSession = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { playPulse = true }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { titleGlow = true }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { animalBounce = -10 }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { vsScale = 1.2 }
            pairTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.4)) {
                    pairIndex = (pairIndex + 1) % heroPairs.count
                }
            }
        }
        .onDisappear {
            pairTimer?.invalidate()
            pairTimer = nil
        }
        .sheet(isPresented: $showHelp) { HelpSheet() }
        .sheet(isPresented: $showSettings, onDismiss: {
            // If Settings asked us to show a Game Center screen, present it now
            // that Settings' sheet has fully finished dismissing. Required because
            // GKGameCenterViewController silently no-ops if presented while a
            // sibling SwiftUI sheet is still mid-dismiss.
            GameCenterManager.shared.flushPending()
        }) { SettingsView() }
        .sheet(isPresented: $showDisclaimer) {
            DisclaimerSheet(hasSeenDisclaimer: $hasSeenDisclaimer)
        }
        .sheet(isPresented: $showResumeSheet) {
            TournamentResumeSheet(
                onResume: {
                    showResumeSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showTournament = true
                    }
                },
                onAbandon: {
                    TournamentManager.shared.forfeit()
                    showResumeSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showTournament = true
                    }
                },
                onCancel: {
                    showResumeSheet = false
                }
            )
            .presentationDetents([.medium])
        }
        // fullScreenCover must be outermost to avoid being blocked by sheet modifiers above
        .fullScreenCover(isPresented: $showTournament) {
            TournamentRootView()
        }
    }
}

// MARK: - Tournament unlock nudge (shown on HomeView when locked)

private struct TournamentUnlockNudge: View {
    let progress: Double
    let current: Int
    let threshold: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("🏆").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TOURNAMENT MODE")
                        .font(Theme.bungee(13))
                        .foregroundColor(Theme.gold)
                        .tracking(1)
                    Text("Unlocks at \(threshold) battles — build your dream bracket!")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                Text("\(current)/\(threshold)")
                    .font(Theme.bungee(12))
                    .foregroundColor(.white.opacity(0.7))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.gold, Theme.orange],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.35), lineWidth: 1.2))
        )
    }
}

// MARK: - Tournament Resume Sheet

private struct TournamentResumeSheet: View {
    let onResume: () -> Void
    let onAbandon: () -> Void
    let onCancel: () -> Void

    @ObservedObject private var manager = TournamentManager.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("🏆")
                .font(.system(size: 50))
                .padding(.top, 24)

            Text("RESUME TOURNAMENT?")
                .font(Theme.bungee(18))
                .foregroundColor(.white)

            if let t = manager.activeTournament {
                Text("\(t.size.rawValue)-fighter bracket in progress")
                    .font(Theme.bungee(13))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: onResume) {
                    Text("CONTINUE")
                }
                .buttonStyle(MegaButtonStyle(color: .orange, height: 58, cornerRadius: 18, fontSize: 16))

                Button(action: onAbandon) {
                    Text("START NEW (ABANDON PROGRESS)")
                        .font(Theme.bungee(12))
                        .foregroundColor(Theme.red.opacity(0.85))
                        .padding(.vertical, 10)
                }
                Button(action: onCancel) {
                    Text("Never mind")
                        .font(Theme.bungee(12))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.battleBg.ignoresSafeArea())
    }
}

// MARK: - Pack Journey Nudge

private struct PackInfo {
    let emoji: String
    let label: String
    let threshold: Int
    let color: Color
    let prevThreshold: Int
}

// MARK: - Custom Creature CTA (rotating examples)

struct CustomCreatureCTA: View {
    private let examples = [
        "Battle as your pet cat!",
        "Try 'Penguin vs Kangaroo'",
        "Can a Hamster beat a Bear?",
        "Fight as a Goldfish!",
        "Create ANY creature!",
    ]
    @State private var currentIndex = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        NavigationLink(destination: AnimalPickerView()) {
            HStack(spacing: 10) {
                Text("✨")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("TYPE ANY CREATURE TO BATTLE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(Theme.yellow)
                        .tracking(1)
                    Text(examples[currentIndex])
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(opacity)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
        .onAppear { startRotation() }
    }

    private func startRotation() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.3)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                currentIndex = (currentIndex + 1) % examples.count
                withAnimation(.easeIn(duration: 0.3)) { opacity = 1.0 }
            }
        }
    }
}

// MARK: - Pack Journey Nudge

struct PackJourneyNudge: View {
    @ObservedObject private var settings = UserSettings.shared

    private let packs: [PackInfo] = [
        PackInfo(emoji: "🦕", label: "DINOS",   threshold: 100,   color: Color(hex: "#FF8F00"), prevThreshold: 0),
        PackInfo(emoji: "🐉", label: "FANTASY",  threshold: 250,   color: Color(hex: "#AB47BC"), prevThreshold: 100),
        PackInfo(emoji: "🔱", label: "MYTHIC",   threshold: 500,   color: Color(hex: "#FDD835"), prevThreshold: 250),
        PackInfo(emoji: "⚡", label: "GODS",     threshold: 10_000, color: Color(hex: "#42A5F5"), prevThreshold: 500),
    ]

    private var visiblePacks: [PackInfo] {
        settings.isOlympusVisible ? packs : Array(packs.prefix(3))
    }

    var body: some View {
        let vp = visiblePacks
        let count = vp.count
        let gap: CGFloat = 3

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(vp.indices, id: \.self) { i in
                    packLabel(vp[i])
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 6)

            GeometryReader { geo in
                let totalGaps = CGFloat(count - 1) * gap
                let segW = (geo.size.width - totalGaps) / CGFloat(count)
                HStack(spacing: gap) {
                    ForEach(vp.indices, id: \.self) { i in
                        segmentBar(vp[i], width: segW)
                    }
                }
            }
            .frame(height: 10)

            HStack {
                Text("⚔️ \(settings.totalBattleCount.formatted()) battles")
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                if settings.isOlympusVisible {
                    Text("10,000 for ⚡ Gods")
                        .foregroundColor(Color(hex: "#42A5F5").opacity(0.6))
                } else {
                    let next = vp.first(where: { !isUnlocked($0) })
                    if let next {
                        Text("\(next.threshold) to unlock \(next.emoji) \(next.label)")
                            .foregroundColor(next.color.opacity(0.8))
                    }
                }
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.top, 7)
        }
        .padding(.horizontal, 28)
    }

    @ViewBuilder
    private func packLabel(_ pack: PackInfo) -> some View {
        let unlocked = isUnlocked(pack)
        VStack(spacing: 2) {
            Text(pack.emoji)
                .font(.system(size: 13))
                .opacity(unlocked ? 1.0 : 0.35)
                .shadow(color: unlocked ? pack.color.opacity(0.8) : .clear, radius: 6, x: 0, y: 0)
            Text(pack.label)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundColor(unlocked ? pack.color : .white.opacity(0.35))
                .tracking(0.5)
        }
    }

    @ViewBuilder
    private func segmentBar(_ pack: PackInfo, width: CGFloat) -> some View {
        let fill = segmentFill(pack)
        let unlocked = isUnlocked(pack)
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.12))
                .frame(width: width, height: 10)
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    unlocked
                    ? LinearGradient(colors: [pack.color, pack.color.opacity(0.75)],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [pack.color.opacity(0.9), pack.color.opacity(0.55)],
                                     startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: width * CGFloat(fill), height: 10)
                .shadow(color: pack.color.opacity(fill > 0 ? 0.5 : 0), radius: 4, x: 0, y: 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: fill)
        }
    }

    private func segmentFill(_ pack: PackInfo) -> Double {
        let b = settings.totalBattleCount
        if b >= pack.threshold { return 1.0 }
        if b <= pack.prevThreshold { return 0.0 }
        return Double(b - pack.prevThreshold) / Double(pack.threshold - pack.prevThreshold)
    }

    private func isUnlocked(_ pack: PackInfo) -> Bool {
        switch pack.label {
        case "DINOS":   return settings.isPrehistoricUnlocked
        case "FANTASY": return settings.isFantasyUnlocked
        case "MYTHIC":  return settings.isMythicUnlocked
        case "GODS":    return settings.isOlympusUnlocked
        default:        return false
        }
    }
}

// MARK: - Spread Star Field (no clusters — evenly distributed)

struct SpreadStarField: View {
    private let stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (0.08, 0.18), (0.25, 0.08), (0.45, 0.15), (0.62, 0.05), (0.80, 0.20),
        (0.93, 0.11), (0.15, 0.32), (0.38, 0.28), (0.57, 0.35), (0.74, 0.30),
        (0.90, 0.40), (0.05, 0.50), (0.22, 0.44), (0.48, 0.52), (0.68, 0.47),
        (0.85, 0.55), (0.12, 0.65), (0.33, 0.60), (0.55, 0.68), (0.72, 0.63),
        (0.92, 0.70), (0.18, 0.80), (0.40, 0.75), (0.60, 0.82), (0.78, 0.77),
        (0.95, 0.85), (0.30, 0.90), (0.52, 0.95), (0.70, 0.88), (0.88, 0.93)
    ].enumerated().map { i, pos in
        let sizes: [CGFloat] =    [1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5, 1.0, 2.0, 1.5,
                                   2.0, 1.0, 1.5, 2.0, 1.0, 1.5, 2.0, 1.0, 1.5, 2.0,
                                   1.0, 1.5, 2.0, 1.0, 1.5, 2.0, 1.0, 1.5, 2.0, 1.0]
        let opacities: [Double] = [0.5, 0.3, 0.7, 0.4, 0.6, 0.3, 0.5, 0.7, 0.4, 0.6,
                                   0.3, 0.7, 0.5, 0.3, 0.6, 0.4, 0.7, 0.3, 0.5, 0.6,
                                   0.4, 0.7, 0.3, 0.5, 0.6, 0.4, 0.7, 0.3, 0.5, 0.6]
        return (pos.0, pos.1, sizes[i % sizes.count], opacities[i % opacities.count])
    }

    var body: some View {
        Canvas { context, size in
            for star in stars {
                let x = star.x * size.width
                let y = star.y * size.height
                let r = star.size / 2
                let rect = CGRect(x: x - r, y: y - r, width: star.size, height: star.size)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.opacity)))
            }
        }
    }
}

// MARK: - Disclaimer Sheet

struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasSeenDisclaimer: Bool
    @State private var dontShowAgain = false

    var body: some View {
        ZStack {
            ScreenBackground(style: .home)

            VStack(spacing: 0) {
                Spacer()

                Text("🐾")
                    .font(.system(size: 70))
                    .padding(.bottom, 20)

                Text("Just For Fun!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)

                VStack(spacing: 14) {
                    disclaimerLine("🎮", "This is a fantasy game — no real animals are involved or harmed.")
                    disclaimerLine("❤️", "We love animals and do not support animal fighting of any kind.")
                    disclaimerLine("🤖", "All battles are decided by AI based on fun facts — it's made up!")
                    disclaimerLine("👨‍👩‍👧", "Best enjoyed with a parent or guardian for younger players.")
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: { dontShowAgain.toggle() }) {
                    HStack(spacing: 10) {
                        Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                            .font(.system(size: 20))
                            .foregroundColor(dontShowAgain ? Theme.orange : .white.opacity(0.6))
                        Text("Don't show again")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.bottom, 16)

                Button(action: {
                    if dontShowAgain { hasSeenDisclaimer = true }
                    dismiss()
                }) {
                    Text("Got it — let's play! ⚔️")
                }
                .buttonStyle(MegaButtonStyle(color: .orange, height: 58, cornerRadius: 18, fontSize: 17))
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }

    private func disclaimerLine(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 30)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Help Sheet

struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ScreenBackground(style: .home)

            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Text("HOW TO PLAY")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.orange.opacity(0.7))
                        .frame(width: 48, height: 3)
                }
                .padding(.top, 36)
                .padding(.bottom, 32)

                VStack(spacing: 22) {
                    HelpRow(number: "1", emoji: "🐾", text: "Pick any two animals from the list.")
                    HelpRow(number: "2", emoji: "⚔️",  text: "Tap FIGHT! to start the battle.")
                    HelpRow(number: "3", emoji: "🎬", text: "Watch the epic battle play out!")
                    HelpRow(number: "4", emoji: "🎓", text: "Learn a fun fact about the winner.")
                }
                .padding(.horizontal, 28)

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Got it!")
                }
                .buttonStyle(MegaButtonStyle(color: .orange, height: 58, cornerRadius: 18, fontSize: 17))
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .presentationDetents([.medium])
    }
}

struct HelpRow: View {
    let number: String
    let emoji: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.orange.opacity(0.2))
                    .overlay(Circle().stroke(Theme.orange.opacity(0.4), lineWidth: 1.5))
                    .frame(width: 40, height: 40)
                Text(emoji)
                    .font(.system(size: 14))
            }

            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}
