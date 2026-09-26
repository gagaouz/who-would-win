import SwiftUI

/// The team resolver owns the answer; the shared stage only performs it.
struct MeleeBattleView: View {
    let teamA: [Animal]
    let teamB: [Animal]
    @StateObject private var viewModel: MeleeViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var didStart = false
    @State private var battleTask: Task<Void, Never>?
    private var isIPad: Bool { sizeClass == .regular }

    init(teamA: [Animal], teamB: [Animal]) {
        self.teamA = teamA; self.teamB = teamB
        _viewModel = StateObject(wrappedValue: MeleeViewModel(teamA: teamA, teamB: teamB))
    }

    var body: some View {
        ZStack {
            SkyBG(variant: .meadow)
            if let result = viewModel.result, viewModel.animationComplete {
                ResultContent(result: result, teamA: teamA, teamB: teamB, isIPad: isIPad,
                              onAgain: { dismiss() }, onClose: { dismiss() })
                    .accessibilityIdentifier("battle.result")
                    .transition(.opacity)
                    .onAppear {
                        guard RetroBattleSettlement.claim(viewModel.presentationID) else { return }
                        let bonus = UserSettings.shared.recordBattle()
                        CoinStore.shared.earnBattleCoins(milestoneBonus: bonus)
                    }
            } else {
                RetroBattleStage(
                    sessionID: viewModel.presentationID, teamA: teamA, teamB: teamB,
                    environment: viewModel.environment,
                    arenaEffectsEnabled: viewModel.arenaEffectsEnabled,
                    outcome: RetroBattleOutcome.team(viewModel.result), title: "TEAM BATTLE",
                    onClose: { dismiss() },
                    onComplete: { [session = viewModel.presentationID] in
                        viewModel.animationDidComplete(for: session)
                    }
                )
                .id(viewModel.presentationID)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            guard !didStart else { return }
            didStart = true
            battleTask = Task { await viewModel.startBattle() }
        }
        .onDisappear {
            battleTask?.cancel(); battleTask = nil
            viewModel.cancelBattle()
        }
    }
}

// MARK: - Battle (animating) content

private struct BattleContent: View {
    let teamA: [Animal]
    let teamB: [Animal]
    let cheerProgress: Double
    let vsPulse: CGFloat
    let bob: CGFloat
    let appeared: Bool
    let isJudging: Bool
    let isIPad: Bool
    let onClose: () -> Void

    @State private var judgingPulse: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                KidIconBtn(icon: "✕", fill: .white) { onClose() }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16).padding(.top, 10)

            // Title sticker
            Text("TEAM A vs TEAM B")
                .font(Kids.fredoka(isIPad ? 26 : 20, weight: .bold))
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

            // Team rows
            VStack(spacing: isIPad ? 14 : 10) {
                teamRow(label: "TEAM A", team: teamA, tint: Kids.sun, bobY: bob)
                StarSticker(text: "VS", size: isIPad ? 56 : 44, fill: Kids.pink)
                    .scaleEffect(vsPulse)
                teamRow(label: "TEAM B", team: teamB, tint: Kids.pink, bobY: -bob)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            // Cheer meter
            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    RetroSymbol(isJudging ? "⚖️" : "🎺", size: 14)
                        .scaleEffect(isJudging ? judgingPulse : 1.0)
                    Text(isJudging ? "JUDGES VOTING" : "CROWD CHEER METER")
                        .font(Kids.fredoka(12, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .contentTransition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: isJudging)
                ProgressPill(progress: cheerProgress, fill: isJudging ? Kids.grape : Kids.sun)
                    .frame(height: 18)
                    .overlay(
                        Text(cheerText).font(Kids.fredoka(10, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .contentTransition(.opacity)
                    )
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
            .padding(.top, 18)

            Spacer()

            JudgingIndicator(isJudging: isJudging)
                .padding(.bottom, 40)
        }
        .scaleEffect(appeared ? 1 : 0.95)
        .opacity(appeared ? 1 : 0)
        .onChange(of: isJudging) { judging in
            // Perpetual pulse — skipped under Reduce Motion (mirrors the 1v1).
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

    private var cheerText: String {
        if isJudging              { return "DECISION TIME!" }
        if cheerProgress < 0.40   { return "Warming up..." }
        if cheerProgress < 0.80   { return "Getting exciting!" }
        return "GOING WILD!"
    }

    private func teamRow(label: String, team: [Animal], tint: Color, bobY: CGFloat) -> some View {
        // Sizes scale down a bit as the roster grows so 4-fighter teams fit.
        let portraitSize: CGFloat = {
            let base: CGFloat = isIPad ? 90 : 64
            if team.count >= 4 { return base * 0.78 }
            if team.count == 3 { return base * 0.88 }
            return base
        }()
        return VStack(spacing: 6) {
            Text(label)
                .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(RetroPanelShape().fill(tint).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
            HStack(spacing: isIPad ? 10 : 6) {
                ForEach(team) { animal in
                    VStack(spacing: 4) {
                        FighterPortrait(animal: animal, size: portraitSize, ringColor: tint)
                            .offset(y: bobY)
                        Text(animal.name.uppercased())
                            .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }
}

// MARK: - Result content

private struct ResultContent: View {
    let result: MeleeResult
    let teamA: [Animal]
    let teamB: [Animal]
    let isIPad: Bool
    let onAgain: () -> Void
    let onClose: () -> Void

    @State private var appeared = false
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet: Bool = false
    @State private var isPreparingShare: Bool = false
    @StateObject private var speech = SpeechService()

    private var winningTeam: [Animal] {
        result.winningTeam == .A ? teamA : teamB
    }

    private var mvpAnimal: Animal? {
        winningTeam.first(where: { $0.id == result.mvp }) ?? winningTeam.first
    }

    var body: some View {
        ZStack {
            // Triumphant sunburst behind the team winner — same idea as the
            // tournament champion / 1v1 winner, in a cooler color to suit melee.
            WinnerSunburst(color: Kids.sky.opacity(0.40), centerY: 0.20)
                .ignoresSafeArea()

            ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                    KidIconBtn(icon: "✕", fill: .white) { onClose() }
                }
                .padding(.horizontal, 16).padding(.top, 10)

                RetroSymbol("👑", size: isIPad ? 64 : 50)
                    .scaleEffect(appeared ? 1 : 0)
                    .rotationEffect(.degrees(appeared ? 0 : -40))

                StickerWord(text: "TEAM \(result.winningTeam.rawValue) WINS!",
                            fill: Kids.peach,
                            fontSize: isIPad ? 44 : 30,
                            tilt: -2)
                    .rotationEffect(.degrees(appeared ? -2 : -20))
                    .scaleEffect(appeared ? 1 : 0.3)

                // MVP portrait
                if let mvp = mvpAnimal {
                    VStack(spacing: 6) {
                        FighterPortrait(animal: mvp, size: isIPad ? 170 : 130, ringColor: Kids.sun)
                            .scaleEffect(appeared ? 1 : 0.4)
                        Text("MVP · \(mvp.name.uppercased())")
                            .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(RetroPanelShape().fill(Kids.sun).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
                    }
                }

                // Winning team roster (smaller portraits)
                HStack(spacing: isIPad ? 10 : 6) {
                    ForEach(winningTeam) { animal in
                        VStack(spacing: 4) {
                            FighterPortrait(animal: animal,
                                            size: isIPad ? 70 : 54,
                                            ringColor: Kids.peach)
                            Text(animal.name)
                                .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
                .opacity(appeared ? 1 : 0)

                // Narration
                if result.isOfflineFallback {
                    Text("Offline result").font(Kids.nunito(12, weight: .bold))
                        .accessibilityIdentifier("battle.offlineIndicator")
                }
                infoCard(title: "BATTLE STORY", titleColor: Kids.pink, body: result.narration.withoutEmoji)
                    .opacity(appeared ? 1 : 0)

                // Fun fact
                infoCard(title: "FUN FACT", titleColor: Kids.sun, body: result.funFact.withoutEmoji)
                    .opacity(appeared ? 1 : 0)

                // Read aloud
                Button {
                    if speech.isSpeaking {
                        speech.stopSpeaking()
                    } else {
                        speech.speak("\(result.narration.withoutEmoji) \(result.funFact.withoutEmoji)")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: speech.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.system(size: 14, weight: .bold))
                        Text(speech.isSpeaking ? "Stop reading" : "Read it to me!")
                            .font(Kids.fredoka(13, weight: .bold))
                    }
                    .foregroundColor(Kids.ink)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        RetroPanelShape().fill(Kids.sky)
                            .overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                KidButton(title: "BATTLE AGAIN", icon: "🔁", color: Kids.grass, size: .lg) {
                    HapticsService.shared.tap()
                    onAgain()
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                // Share button — renders the MeleeShareCard off-screen with
                // pre-fetched custom-creature photos, then presents the system
                // share sheet.
                KidsMiniButton(emoji: "📤", label: isPreparingShare ? "Preparing..." : "Share", color: Kids.grape) {
                    guard !isPreparingShare else { return }
                    HapticsService.shared.medium()
                    isPreparingShare = true
                    Task {
                        let img = await MeleeShareCard.renderWithCachedImages(
                            teamA: teamA, teamB: teamB, result: result
                        )
                        await MainActor.run {
                            shareImage = img
                            isPreparingShare = false
                            if shareImage != nil { showShareSheet = true }
                        }
                    }
                }
                .padding(.horizontal, 48)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                // Roster-based caption — "Team A" means nothing to someone
                // receiving the share outside the app.
                let winners = result.winningTeam == .A ? teamA : teamB
                let losers  = result.winningTeam == .A ? teamB : teamA
                let winEmoji  = winners.map(\.emoji).joined()
                let loseEmoji = losers.map(\.emoji).joined()
                BattleShareSheet(
                    image: img,
                    caption: "🏆 \(winEmoji) beat \(loseEmoji) in an epic team melee! Who would win? Find out in Animal vs Animal!"
                )
            } else {
                Text("Preparing share...").padding()
            }
        }
        .onAppear {
            if UIAccessibility.isReduceMotionEnabled { appeared = true }
            else { withAnimation(.spring(response: 0.55, dampingFraction: 0.55).delay(0.1)) { appeared = true } }
            HapticsService.shared.success()
            SoundService.shared.play(.win)   // victory fanfare (was silent)
        }
        .onDisappear { speech.stopSpeaking() }
        }   // ZStack (sunburst behind the result)
    }

    private func infoCard(title: String, titleColor: Color, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(Kids.fredoka(11, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RetroPanelShape().fill(titleColor).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
            Text(body)
                .accessibilityIdentifier(title == "BATTLE STORY" ? "battle.narration" : "battle.info.\(title)")
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
    }
}
