import SwiftUI

// MARK: - Home Screen — Animal Arena Jr.
// Matches screenshots/01_home.png — light, bouncy, sticker aesthetic.

struct KidsHomeView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared
    @State private var showSettings = false
    @State private var showTournament = false
    @State private var showBook = false
    @State private var showHallOfFame = false
    @State private var goToPicker = false
    @State private var showCoinShop = false
    @State private var showMeleeUnlock = false
    @State private var goToMelee = false
    // One-tap quick battles (Daily Challenge, Surprise Me, first-run auto-battle).
    @State private var quickFighters: (Animal, Animal)? = nil
    @State private var goToQuickBattle = false
    @State private var homeMatchupToken = UUID()
    // Daily mystery sticker reveal.
    @State private var mysteryReveal: Animal? = nil
    @State private var showMysteryCoins = false
    @State private var giftWiggle = false
    // Onboarding: How to Play walkthrough + first-launch welcome offer.
    @State private var showHowToPlay = false
    @State private var showWelcome = false
    // One-time proactive "unlock everything" offer at a happy moment.
    @State private var showPaywall = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    // Rotating hero pair
    private let heroPairs: [(String, String, Color, Color)] = [
        ("🦁", "🐯", Kids.sun, Kids.peach),
        ("🐻", "🐺", Kids.peach, Kids.grape),
        ("🦈", "🐙", Kids.sky, Kids.pink),
        ("🐉", "🦄", Kids.grape, Kids.pink),
    ]
    @State private var pairIndex = 0
    @State private var pairTimer: Timer?

    // Mount bounce-in
    @State private var appeared = false
    // Ambient floats
    @State private var animalBob: CGFloat = 0
    @State private var vsPulse: CGFloat = 1
    @State private var btnBreath: CGFloat = 1
    // Each ANIMAL word rocks independently — different durations + opposite
    // start points so they're naturally out of sync.
    @State private var titleTiltTop:    Double = -3   // rocks -3° → +3°
    @State private var titleTiltBottom: Double =  2   // rocks +2° → -2°
    @State private var titlePulse: CGFloat = 1.0      // unified pulse 1.0 ↔ 1.04

    var body: some View {
        NavigationStack {
            ZStack {
                SkyBG(variant: .day)

                // Top chrome
                //
                // .zIndex(1) is critical: the GeometryReader/ScrollView sibling
                // below is rendered AFTER this chrome in the ZStack, and a
                // SwiftUI ScrollView captures touches across its entire frame
                // (not just where content is drawn). Without the zIndex bump,
                // the ScrollView eats taps on the trophy/sticker/settings
                // buttons. The Spacer at the bottom of this VStack only pushes
                // the row to the top — it doesn't make the chrome itself
                // hit-test-only-on-the-top-row.
                VStack {
                    HStack(alignment: .top) {
                        CoinChip(count: coins.balance)
                            .scaleEffect(appeared ? 1 : 0.4)
                            .opacity(appeared ? 1 : 0)
                        // Daily mystery sticker — only when one's waiting.
                        if settings.mysteryStickerAvailable {
                            Button {
                                claimMysterySticker()
                            } label: {
                                Text("🎁")
                                    .font(.system(size: isIPad ? 26 : 22))
                                    .frame(width: isIPad ? 50 : 44, height: isIPad ? 50 : 44)
                                    .background(
                                        Circle().fill(Kids.pink)
                                            .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
                                    )
                                    .rotationEffect(.degrees(giftWiggle ? -8 : 8))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 6)
                            .scaleEffect(appeared ? 1 : 0.4)
                            .opacity(appeared ? 1 : 0)
                            .accessibilityLabel("Open today's mystery sticker")
                        }
                        Spacer()
                        HStack(spacing: isIPad ? 16 : 10) {
                            KidIconBtn(icon: "🏆", fill: Kids.sun) { showHallOfFame = true }
                            KidIconBtn(icon: "📔", fill: Kids.pink) { showBook = true }
                            KidIconBtn(icon: "⚙️", fill: Kids.sky) { showSettings = true }
                        }
                        .scaleEffect(appeared ? 1 : 0.4)
                        .opacity(appeared ? 1 : 0)
                    }
                    .padding(.horizontal, isIPad ? 28 : 18)
                    .padding(.top, isIPad ? 14 : 8)
                    Spacer()
                        .allowsHitTesting(false)  // let taps fall through to the ScrollView below
                }
                .zIndex(1)

                // Main stack — capped to a phone-ish max width on iPad so the
                // layout stays cohesive instead of spreading to the screen edges.
                // Wrapped in a ScrollView so iPad-landscape (shorter height) doesn't
                // clip the bottom rows; in portrait there's normally no scroll needed.
                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack {
                            Spacer(minLength: 0)
                            VStack(spacing: 0) {

                                Spacer().frame(height: isLandscape ? (isIPad ? 70 : 36) : (isIPad ? 110 : 64))

                        // Sticker-word title: ANIMAL / vs / ANIMAL
                        // Each ANIMAL has its own ambient rock — outer scale-only for pulse.
                        // Internal `tilt` is the resting angle; the external rotationEffect
                        // adds the dynamic wobble on top of it.
                        VStack(spacing: isIPad ? -10 : -6) {
                            StickerWord(text: "ANIMAL", fill: Kids.sun,
                                        fontSize: isLandscape ? (isIPad ? 60 : 40) : (isIPad ? 80 : 50), tilt: -3)
                                .scaleEffect(appeared ? 1 : 0.2)
                                .rotationEffect(.degrees(appeared ? titleTiltTop : -20))
                                .opacity(appeared ? 1 : 0)
                            // White "vs" pill (per design)
                            Text("vs")
                                .font(Kids.fredoka(isIPad ? 32 : 20, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .padding(.horizontal, isIPad ? 22 : 14)
                                .padding(.vertical, isIPad ? 4 : 2)
                                .background(
                                    Capsule().fill(.white)
                                        .overlay(Capsule().stroke(Kids.ink, lineWidth: isIPad ? 4 : 3))
                                )
                                .shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 3)
                                .zIndex(2)
                                .padding(.vertical, isIPad ? -6 : -4)
                                .opacity(appeared ? 1 : 0)
                            StickerWord(text: "ANIMAL", fill: Kids.pink,
                                        fontSize: isLandscape ? (isIPad ? 60 : 40) : (isIPad ? 80 : 50), tilt: 2)
                                .scaleEffect(appeared ? 1 : 0.2)
                                .rotationEffect(.degrees(appeared ? titleTiltBottom : 20))
                                .opacity(appeared ? 1 : 0)
                        }
                        .scaleEffect(titlePulse)              // unified ambient pulse

                        // Subtitle
                        Text("who would win?")
                            .font(Kids.nunito(isIPad ? 22 : 14, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .padding(.top, isIPad ? 24 : 14)
                            .opacity(appeared ? 1 : 0)

                        // Always-available "How to Play" — discoverable, never forced.
                        Button {
                            HapticsService.shared.tap()
                            showHowToPlay = true
                        } label: {
                            HStack(spacing: 5) {
                                Text("❓").font(.system(size: 13))
                                Text("How to Play")
                                    .font(Kids.fredoka(13, weight: .bold))
                                    .foregroundColor(Kids.ink)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.85)).overlay(Capsule().stroke(Kids.ink.opacity(0.5), lineWidth: 2)))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, isIPad ? 12 : 8)
                        .opacity(appeared ? 1 : 0)
                        .accessibilityLabel("How to play")

                        Spacer().frame(height: isLandscape ? (isIPad ? 12 : 8) : (isIPad ? 26 : 14))

                        // Hero pair with VS star
                        ZStack {
                            HStack {
                                AnimalBubble(
                                    emoji: heroPairs[pairIndex].0,
                                    size: isLandscape ? (isIPad ? 100 : 72) : (isIPad ? 140 : 86),
                                    tint: heroPairs[pairIndex].2,
                                    tilt: -6
                                )
                                .offset(y: animalBob)
                                .transition(.scale.combined(with: .opacity))
                                Spacer()
                                AnimalBubble(
                                    emoji: heroPairs[pairIndex].1,
                                    size: isLandscape ? (isIPad ? 100 : 72) : (isIPad ? 140 : 86),
                                    tint: heroPairs[pairIndex].3,
                                    tilt: 6
                                )
                                .offset(y: -animalBob)
                                .transition(.scale.combined(with: .opacity))
                            }
                            .padding(.horizontal, isIPad ? 80 : 60)
                            // No .id(pairIndex) — it caused the HStack to be torn down
                            // on every pair swap, which wiped the repeatForever bounce
                            // CA animation on the new layer.

                            StarSticker(text: "VS", size: isIPad ? 72 : 46, fill: Kids.pink)
                                .scaleEffect(vsPulse)
                                .rotationEffect(.degrees(vsPulse > 1 ? 4 : -4))
                        }
                        .scaleEffect(appeared ? 1 : 0.5)
                        .opacity(appeared ? 1 : 0)

                        Spacer().frame(height: isLandscape ? (isIPad ? 12 : 8) : (isIPad ? 24 : 14))

                        // Streak badge
                        if settings.currentStreak >= 1 {
                            StreakPill(days: settings.currentStreak)
                                .scaleEffect(appeared ? 1 : 0.3)
                                .opacity(appeared ? 1 : 0)
                                .padding(.bottom, isIPad ? 20 : 12)
                        } else {
                            Spacer().frame(height: isIPad ? 8 : 4)
                        }

                        // Daily Challenge — a fresh featured matchup every day.
                        dailyChallengeCard
                            .padding(.horizontal, isIPad ? 40 : 22)
                            .padding(.bottom, isIPad ? 16 : 10)
                            .offset(y: appeared ? 0 : 40)
                            .opacity(appeared ? 1 : 0)

                        // CTAs
                        KidButton(title: "LET'S BATTLE!", icon: "⚡", color: Kids.grass, size: .xl) {
                            HapticsService.shared.tap()
                            goToPicker = true
                        }
                        .scaleEffect(btnBreath)
                        // Extra padding on iPad so the button stops looking like a slab
                        .padding(.horizontal, isIPad ? 90 : 24)
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)

                        // Surprise Me — instant random matchup, no picking.
                        Button {
                            startSurprise()
                        } label: {
                            HStack(spacing: 8) {
                                Text("🎲").font(.system(size: 18))
                                Text("SURPRISE ME!")
                                    .font(Kids.fredoka(16, weight: .bold))
                                    .foregroundColor(Kids.ink)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(
                                Capsule().fill(.white)
                                    .overlay(Capsule().stroke(Kids.ink, lineWidth: 2.5))
                            )
                            .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, isIPad ? 14 : 10)
                        .offset(y: appeared ? 0 : 40)
                        .opacity(appeared ? 1 : 0)
                        .accessibilityLabel("Surprise Me — start a random battle")

                        Spacer().frame(height: isLandscape ? (isIPad ? 12 : 8) : (isIPad ? 22 : 14))

                        // Fact of the Day — teaches something every day, even
                        // before a battle. Rotates deterministically by date.
                        factOfTheDayCard
                            .padding(.horizontal, isIPad ? 40 : 22)
                            .padding(.bottom, isIPad ? 14 : 10)
                            .offset(y: appeared ? 0 : 50)
                            .opacity(appeared ? 1 : 0)

                        // Progress chips row — iPad puts both chips side-by-side to use
                        // the horizontal space and shorten the otherwise huge vertical sprawl.
                        progressChipsRow
                            .offset(y: appeared ? 0 : 50)
                            .opacity(appeared ? 1 : 0)

                        // Bottom breathing room before the safe-area edge. The
                        // owl "tap an animal to swap buddies" tip used to live
                        // here, but the round, thickly-outlined creature circles
                        // already look obviously tappable, and the giant green
                        // LET'S BATTLE button anchors the primary action — the
                        // tip was redundant chrome that nagged experienced kids
                        // and confused new ones ("buddies" reads as teammates
                        // when these are opponents).
                        if isLandscape {
                            Color.clear.frame(height: isIPad ? 24 : 12)
                        } else if isIPad {
                            Color.clear.frame(height: 40)
                        } else {
                            Color.clear.frame(height: 30)
                        }
                            }
                            .frame(maxWidth: isIPad ? 580 : .infinity)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: geo.size.height)  // fill the viewport in portrait
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $goToPicker) {
                KidsAnimalPickerView()
            }
            .navigationDestination(isPresented: $goToMelee) {
                MeleeSetupView()
            }
            .navigationDestination(isPresented: $goToQuickBattle) {
                if let pair = quickFighters {
                    KidsBattleView(fighter1: pair.0, fighter2: pair.1,
                                   environment: .grassland, arenaEffectsEnabled: false,
                                   onNextChallenger: { winner in
                                       quickFighters = (winner, QuickMatchups.opponent(excluding: winner))
                                       homeMatchupToken = UUID()
                                   })
                        .id(homeMatchupToken)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.05)) {
                appeared = true
            }
            startRotation()
            startAmbient()
            maybeOfferHowToPlay()
            maybeShowPaywall()
        }
        .onDisappear { pairTimer?.invalidate() }
        .fullScreenCover(isPresented: $showSettings) { KidsSettingsView() }
        .fullScreenCover(isPresented: $showBook) { KidsStickerBookView() }
        .fullScreenCover(isPresented: $showHallOfFame) { KidsHallOfFameView() }
        .sheet(isPresented: $showCoinShop) {
            KidsCoinShopSheet(isPresented: $showCoinShop)
        }
        .onReceive(NotificationCenter.default.publisher(for: KidsCoinShop.openNotification)) { _ in
            showCoinShop = true
        }
        // Real tournament flow — setup → creature picker → bracket preview →
        // round wagers → battles → results → champion. (The legacy UI; the
        // Kids-styled bracket view was a static visual demo without logic.)
        .fullScreenCover(isPresented: $showTournament) {
            TournamentRootView()
        }
        .sheet(isPresented: $showMeleeUnlock) {
            MeleeUnlockSheet(isPresented: $showMeleeUnlock)
        }
        .sheet(item: $mysteryReveal) { a in
            MysteryStickerSheet(animal: a)
        }
        .alert("Wow — you've collected EVERY sticker! 🏆", isPresented: $showMysteryCoins) {
            Button("Yay!", role: .cancel) {}
        } message: {
            Text("Here's 50 bonus coins instead 🪙")
        }
        .fullScreenCover(isPresented: $showHowToPlay) { HowToPlayView() }
        .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
        .alert("👋 Welcome to Animal vs Animal!", isPresented: $showWelcome) {
            Button("Watch a battle! ▶️") { startSurprise() }
            Button("Show me how 👀") { showHowToPlay = true }
            Button("I'll explore", role: .cancel) {}
        } message: {
            Text("New here? Watch a quick battle, see the how-to, or jump right in!")
        }
    }

    private func claimMysterySticker() {
        guard settings.mysteryStickerAvailable else { return }
        settings.lastMysteryStickerDay = UserSettings.todayStamp
        HapticsService.shared.medium()
        let owned = StickerCollection.shared.collected
        let pool = QuickMatchups.pool().filter { !owned.contains($0.id) }
        if let pick = pool.randomElement() {
            _ = StickerCollection.shared.collect(pick)
            mysteryReveal = pick
        } else {
            // Collection complete — reward coins instead, and TELL the kid why
            // (otherwise the gift just silently vanishes with no reveal).
            CoinStore.shared.earn(50)
            SoundService.shared.play(.coin)
            showMysteryCoins = true
        }
    }

    // MARK: - Progress chips row
    // Vertical stack on iPhone, side-by-side on iPad (when both items exist)
    // so we use the tablet's horizontal space instead of stacking like a phone.
    @ViewBuilder
    private var progressChipsRow: some View {
        let tournamentUnlocked = settings.isTournamentUnlocked
        let nextPack = nextPackProgress()

        if isIPad, !tournamentUnlocked, let next = nextPack {
            VStack(spacing: 12) {
                // Common case: both are unlock chips → put them side-by-side
                HStack(spacing: 12) {
                    UnlockCounterChip(
                        emoji: "🏆", label: "Tournament Mode",
                        current: settings.totalBattleCount,
                        total: UserSettings.tournamentBattleThreshold,
                        color: Kids.grape
                    )
                    UnlockCounterChip(
                        emoji: next.emoji, label: "Next: \(next.name)",
                        current: settings.totalBattleCount,
                        total: next.threshold,
                        color: next.color
                    )
                }
                meleeRow
            }
            .padding(.horizontal, 30)
        } else {
            // Phone, or one of the items is missing/replaced by a button — stack vertically
            VStack(spacing: isIPad ? 14 : 10) {
                if tournamentUnlocked {
                    KidButton(title: "TOURNAMENT MODE", icon: "🏆", color: Kids.grape, size: .md) {
                        // One-time wager seed so first-time entrants can actually
                        // bet (idempotent; only tops up below the seed amount).
                        // Was previously only called from the dead BattleView.
                        CoinStore.shared.awardTournamentSeedIfNeeded()
                        showTournament = true
                    }
                    .padding(.horizontal, isIPad ? 100 : 40)
                } else {
                    UnlockCounterChip(
                        emoji: "🏆", label: "Tournament Mode",
                        current: settings.totalBattleCount,
                        total: UserSettings.tournamentBattleThreshold,
                        color: Kids.grape
                    )
                    .padding(.horizontal, isIPad ? 40 : 22)
                }
                meleeRow
                if let next = nextPack {
                    UnlockCounterChip(
                        emoji: next.emoji, label: "Next: \(next.name)",
                        current: settings.totalBattleCount,
                        total: next.threshold,
                        color: next.color
                    )
                    .padding(.horizontal, isIPad ? 40 : 22)
                }
            }
        }
    }

    // MELEE entry tile — unlocked path renders a CTA, locked path renders the
    // unlock-progress chip that opens the unlock sheet on tap.
    @ViewBuilder
    private var meleeRow: some View {
        if settings.isMeleeUnlocked {
            KidButton(title: "MELEE MODE", icon: "⚔️", color: Kids.pink, size: .md) {
                HapticsService.shared.tap()
                goToMelee = true
            }
            .padding(.horizontal, isIPad ? 100 : 40)
        } else {
            Button {
                HapticsService.shared.tap()
                showMeleeUnlock = true
            } label: {
                UnlockCounterChip(
                    emoji: "⚔️", label: "Melee — Team battles",
                    current: settings.totalBattleCount,
                    total: UserSettings.meleeBattleThreshold,
                    color: Kids.pink
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, isIPad ? 40 : 22)
        }
    }

    // MARK: - Fact of the Day

    private var factOfTheDayAnimal: Animal {
        let pool = Animals.all.filter { !$0.isCustom && AnimalFacts.facts(for: $0.id) != nil }
        guard !pool.isEmpty else { return Animals.all[0] }
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(UserSettings.todayStamp &+ 7)))
        return pool[rng.int(pool.count)]
    }

    private var factOfTheDayCard: some View {
        let a = factOfTheDayAnimal
        let fact = AnimalFacts.facts(for: a.id)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Kids.sky)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                CreatureIcon(animal: a, size: 34)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text("FACT OF THE DAY")
                    .font(Kids.fredoka(10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                // Name the creature, so the fact (written as "It is…") always
                // says what it's about.
                Text(a.name)
                    .font(Kids.fredoka(13, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(fact?.coolFact ?? "")
                    .font(Kids.nunito(11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }

    // MARK: - Daily Challenge card

    @ViewBuilder
    private var dailyChallengeCard: some View {
        let pair = QuickMatchups.daily(stamp: UserSettings.todayStamp)
        let available = settings.dailyChallengeAvailable
        Button {
            guard available else { return }
            startDailyChallenge()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Kids.sun)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    Text(available ? "📅" : "✅").font(.system(size: 22))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(available ? "DAILY CHALLENGE" : "DAILY DONE!")
                        .font(Kids.fredoka(13, weight: .bold))
                        .foregroundColor(Kids.ink)
                    if available {
                        HStack(spacing: 5) {
                            Text(pair.0.emoji).font(.system(size: 16))
                            Text("vs").font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)
                            Text(pair.1.emoji).font(.system(size: 16))
                            Text("· +30 🪙").font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)
                        }
                    } else {
                        Text("Come back tomorrow for a new one!")
                            .font(Kids.nunito(11, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
                Spacer()
                if available {
                    Text("▶").font(Kids.fredoka(16, weight: .bold)).foregroundColor(Kids.ink)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(available ? Color(hex: "#FFF6E0") : .white)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
            )
            .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!available)
    }

    // MARK: - Quick-battle launchers

    private func startDailyChallenge() {
        quickFighters = QuickMatchups.daily(stamp: UserSettings.todayStamp)
        homeMatchupToken = UUID()
        if settings.dailyChallengeAvailable {
            settings.lastDailyChallengeDay = UserSettings.todayStamp
            CoinStore.shared.earn(30)   // daily bonus
        }
        HapticsService.shared.tap()
        SoundService.shared.play(.whoosh)
        goToQuickBattle = true
    }

    private func startSurprise() {
        quickFighters = QuickMatchups.surprise()
        homeMatchupToken = UUID()
        HapticsService.shared.tap()
        SoundService.shared.play(.whoosh)
        goToQuickBattle = true
    }

    /// Show the proactive "unlock everything" offer ONCE, after the kid has
    /// clearly engaged (8+ battles), to non-payers. Never nags again.
    @AppStorage("paywall.shownOnce") private var paywallShownOnce = false
    private func maybeShowPaywall() {
        guard !paywallShownOnce,
              !settings.adsRemoved,
              settings.totalBattleCount >= 8,
              !showWelcome, !goToPicker, !goToMelee, !goToQuickBattle else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Re-check at fire time AND only consume the one-shot flag when the
            // paywall actually presents — so a user who navigates away in the
            // 0.6s window isn't permanently skipped, and it never stacks on
            // another cover/alert.
            guard !showWelcome, !showHowToPlay, !goToPicker, !goToMelee, !goToQuickBattle else { return }
            paywallShownOnce = true
            showPaywall = true
        }
    }

    /// On the very first launch, gently OFFER the How-to-Play walkthrough (not a
    /// forced tutorial — they can wave it off and explore). Runs once.
    private func maybeOfferHowToPlay() {
        guard !settings.hasSeenFirstBattle else { return }
        settings.hasSeenFirstBattle = true
        // Let the home animate in first, then surface the welcome offer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard !goToPicker, !goToMelee, !goToQuickBattle else { return }
            showWelcome = true
        }
    }

    private func startRotation() {
        pairTimer?.invalidate()
        pairTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                pairIndex = (pairIndex + 1) % heroPairs.count
            }
        }
    }

    private func startAmbient() {
        // Respect Reduce Motion — kids with vestibular sensitivity (or parents
        // who set it for them) should not get six perpetual wobble loops.
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            animalBob = -6
        }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            vsPulse = 1.1
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            btnBreath = 1.025
        }
        // Title rocks — each ANIMAL on its own clock so they wobble independently
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            titleTiltTop = 3      // top rocks from -3° to +3°
        }
        withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
            titleTiltBottom = -2  // bottom rocks from +2° to -2°
        }
        // Pulse stays unified on the outer VStack
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            titlePulse = 1.04
        }
        // Gift icon wiggle to draw the eye to the daily mystery.
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            giftWiggle = true
        }
    }

    // Returns the *next* battle-threshold pack the player can earn for free.
    private func nextPackProgress() -> (name: String, emoji: String, threshold: Int, color: Color)? {
        if !settings.isPrehistoricUnlocked {
            return ("Dino Pack", "🦖", UserSettings.prehistoricBattleThreshold, Kids.sun)
        }
        if !settings.isFantasyUnlocked {
            return ("Fantasy Pack", "🧚", UserSettings.fantasyBattleThreshold, Kids.grape)
        }
        if !settings.isMythicUnlocked {
            return ("Mythic Beasts", "⚡", UserSettings.mythicBattleThreshold, Kids.sunDeep)
        }
        return nil
    }
}

// MARK: - Unlock counter chip

struct UnlockCounterChip: View {
    let emoji: String
    let label: String
    let current: Int
    let total: Int
    let color: Color

    private var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(current) / Double(total), 1.0)
    }
    private var remaining: Int { max(0, total - current) }

    var body: some View {
        HStack(spacing: 12) {
            // Big colored emoji tile
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                Text(emoji).font(.system(size: 22))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(Kids.fredoka(13, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer()
                    Text("\(current) / \(total)")
                        .font(Kids.fredoka(12, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                CounterBar(progress: progress, fill: color)
                    .frame(height: 10)
                if remaining > 0 {
                    Text("\(remaining) more battle\(remaining == 1 ? "" : "s") to unlock!")
                        .font(Kids.nunito(10, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }
}

// Slim, low-chrome progress bar — drop-in for ProgressPill but visually
// quieter so it doesn't compete with the chip's outer stroke.
private struct CounterBar: View {
    var progress: Double   // 0…1
    var fill: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#F0EBF7"))
                Capsule()
                    .fill(LinearGradient(colors: [fill.opacity(0.85), fill],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * CGFloat(max(0, min(1, progress)))))
            }
        }
    }
}
