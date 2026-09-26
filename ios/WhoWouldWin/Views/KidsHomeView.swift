import SwiftUI

// MARK: - Home — the retro arena
// Keeps the original navigation and progression actions in one native home.

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
    // Onboarding: How to Play walkthrough + first-launch welcome offer.
    @State private var showHowToPlay = false
    @State private var showWelcome = false
    // One-time proactive "unlock everything" offer at a happy moment.
    @State private var showPaywall = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    // Stable gameplay IDs, shared with the roster and the retro asset provider.
    private let heroPairs: [(String, String)] = [
        ("lion", "gorilla"), ("grizzly_bear", "wolf"),
        ("great_white_shark", "octopus"), ("dragon", "unicorn")
    ]
    @State private var pairIndex = 0
    @State private var pairTimer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                SkyBG()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: isIPad ? 22 : 18) {
                        homeToolbar
                        homeWordmark
                        heroConsole
                        VStack(spacing: 12) {
                            KidButton(title: "LET'S BATTLE!", icon: "▶", color: Kids.sun, size: .lg) {
                                HapticsService.shared.tap()
                                goToPicker = true
                            }
                            .accessibilityIdentifier("home.pickFighters")
                            Button {
                                startSurprise()
                            } label: {
                                HStack(spacing: 9) {
                                    RetroSymbol("🎲", size: 18)
                                    Text("SURPRISE ME!").font(Kids.fredoka(16))
                                    Spacer()
                                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(Kids.ink)
                                .padding(14)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(RetroPanelShape().fill(Kids.cream))
                                .overlay(RetroPanelShape().strokeBorder(Kids.ink.opacity(0.5), lineWidth: 2))
                            }
                            .buttonStyle(KidButtonPressStyle())
                            .accessibilityLabel("Surprise Me — start a random battle")
                            .accessibilityIdentifier("home.surpriseBattle")
                        }
                        if settings.currentStreak >= 1 {
                            StreakPill(days: settings.currentStreak)
                        }
                        dailyChallengeCard
                        factOfTheDayCard
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Rectangle().fill(Kids.grassDeep).frame(width: 7, height: 7)
                                Text("MORE WAYS TO PLAY").font(Kids.pixel(10)).foregroundColor(Kids.grassDeep)
                            }
                            progressChipsRow
                        }
                        Button {
                            HapticsService.shared.tap()
                            showHowToPlay = true
                        } label: {
                            Label("How to Play", systemImage: "questionmark.circle")
                                .font(Kids.nunito(15)).foregroundColor(Kids.inkSoft)
                                .frame(minHeight: 44)
                        }
                        .accessibilityLabel("How to play")
                        .accessibilityIdentifier("home.howToPlay")
                        Text("PICK A CREATURE. MAKE A LEGEND.")
                            .font(Kids.nunito(10, weight: .heavy)).tracking(1.2)
                            .foregroundColor(Kids.inkSoft)
                            .padding(.bottom, 18)
                    }
                    .padding(.horizontal, isIPad ? 28 : 18)
                    .padding(.top, 12)
                    .frame(maxWidth: isIPad ? 650 : 520)
                    .frame(maxWidth: .infinity)
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
            startRotation()
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

    private var homeToolbar: some View {
        HStack(spacing: 8) {
            CoinChip(count: coins.balance)
            if settings.mysteryStickerAvailable {
                KidIconBtn(icon: "🎁", fill: Kids.grass, a11yLabel: "Open today's mystery sticker") {
                    claimMysterySticker()
                }
                .accessibilityIdentifier("home.mysterySticker")
            }
            Spacer(minLength: 0)
            KidIconBtn(icon: "🏆", fill: Kids.cream) { showHallOfFame = true }
            KidIconBtn(icon: "📔", fill: Kids.cream) { showBook = true }
            KidIconBtn(icon: "⚙️", fill: Kids.cream) { showSettings = true }
        }
    }

    private var homeWordmark: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text("ANIMAL").foregroundColor(Kids.ink)
                    Text("vs").foregroundColor(Kids.grassDeep)
                    Text("ANIMAL").foregroundColor(Kids.ink)
                }.font(Kids.pixel(isIPad ? 20 : 14))
                VStack(spacing: 7) {
                    Text("ANIMAL").foregroundColor(Kids.ink)
                    Text("vs ANIMAL").foregroundColor(Kids.grassDeep)
                }.font(Kids.pixel(18))
            }
            Text("BIG MATCHUPS. LITTLE PIXELS.")
                .font(Kids.nunito(10, weight: .heavy)).tracking(2)
                .foregroundColor(Kids.inkSoft)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Animal versus Animal. Big matchups, little pixels.")
    }

    private var heroFighters: (Animal, Animal) {
        let pair = heroPairs[pairIndex]
        let left = Animals.all.first(where: { $0.id == pair.0 }) ?? Animals.all[0]
        let right = Animals.all.first(where: { $0.id == pair.1 }) ?? Animals.all[1]
        return (left, right)
    }

    private var heroConsole: some View {
        let fighters = heroFighters
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Rectangle().fill(Kids.grass).frame(width: 6, height: 6)
                Text("ANIMAL ARENA").font(Kids.pixel(9))
                Spacer()
                Text("READY").font(Kids.nunito(10, weight: .heavy)).tracking(1.5)
            }
            .foregroundColor(Kids.cream)
            .padding(.horizontal, 13).padding(.vertical, 14)
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text(fighters.0.name.uppercased()).frame(maxWidth: .infinity, alignment: .leading)
                    Text("VS").font(Kids.pixel(12)).foregroundColor(Kids.sun)
                    Text(fighters.1.name.uppercased()).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(Kids.nunito(11, weight: .heavy))
                .foregroundColor(Kids.cream)
                .padding(12)
                .background(Kids.ink)
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RetroHomeLandscape()
                        HStack(alignment: .bottom) {
                            RetroCreatureArtwork(animal: fighters.0, size: min(geo.size.width * 0.43, 180))
                            Spacer(minLength: 4)
                            RetroCreatureArtwork(animal: fighters.1, size: min(geo.size.width * 0.43, 180))
                                .scaleEffect(x: -1, y: 1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 16)
                    }
                }
                .frame(height: isIPad ? 220 : 174)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 9, weight: .bold)).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THE MATCHUP").font(Kids.pixel(8)).foregroundColor(Kids.grassDeep)
                        Text("Every creature has a story. Who will win yours?")
                            .font(Kids.nunito(15, weight: .heavy)).foregroundColor(Kids.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundColor(Kids.grassDeep)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Kids.panel)
            }
            .overlay(Rectangle().strokeBorder(Kids.ink, lineWidth: 3))
            .padding(.horizontal, 10)
            HStack {
                Text("143 CREATURES")
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { _ in Rectangle().fill(Kids.ink).frame(width: 14, height: 3) }
                }.accessibilityHidden(true)
                Spacer()
                Text("LET'S PLAY")
            }
            .font(Kids.nunito(8, weight: .heavy)).tracking(1)
            .foregroundColor(Kids.cream.opacity(0.65)).padding(12)
        }
        .background(RetroPanelShape(cornerRadius: 18).fill(Kids.console))
        .overlay(RetroPanelShape(cornerRadius: 18).strokeBorder(Kids.ink, lineWidth: 3))
        .compositingGroup().shadow(color: Kids.ink, radius: 0, x: 0, y: 5)
        .compositingGroup().shadow(color: Kids.creamDeep, radius: 0, x: 0, y: 10)
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
            .padding(.horizontal, 0)
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
                    .accessibilityIdentifier("home.tournamentMode")
                    .padding(.horizontal, 0)
                } else {
                    UnlockCounterChip(
                        emoji: "🏆", label: "Tournament Mode",
                        current: settings.totalBattleCount,
                        total: UserSettings.tournamentBattleThreshold,
                        color: Kids.grape
                    )
                    .padding(.horizontal, 0)
                }
                meleeRow
                if let next = nextPack {
                    UnlockCounterChip(
                        emoji: next.emoji, label: "Next: \(next.name)",
                        current: settings.totalBattleCount,
                        total: next.threshold,
                        color: next.color
                    )
                    .padding(.horizontal, 0)
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
            .padding(.horizontal, 0)
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
            .padding(.horizontal, 0)
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
                RetroPanelShape(cornerRadius: 12, style: .continuous)
                    .fill(Kids.sky)
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
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
                    .font(Kids.nunito(13, weight: .semibold))
                    .foregroundColor(Kids.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .background(
            RetroPanelShape(cornerRadius: 18, style: .continuous)
                .fill(Kids.cream)
                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
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
                    RetroPanelShape(cornerRadius: 12, style: .continuous)
                        .fill(Kids.sun)
                        .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                        .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    RetroSymbol(available ? "📅" : "✅", size: 22)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(available ? "DAILY CHALLENGE" : "DAILY DONE!")
                        .font(Kids.fredoka(13, weight: .bold))
                        .foregroundColor(Kids.ink)
                    if available {
                        HStack(spacing: 5) {
                            CreatureIcon(animal: pair.0, size: 28)
                            Text("vs").font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)
                            CreatureIcon(animal: pair.1, size: 28)
                            Text("+30").font(Kids.nunito(12, weight: .heavy)).foregroundColor(Kids.inkSoft)
                            KidsGoldCoin(size: 14)
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
                    Image(systemName: "play.fill").font(.system(size: 16, weight: .bold)).foregroundColor(Kids.ink)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .background(
                RetroPanelShape(cornerRadius: 18, style: .continuous)
                    .fill(available ? Kids.panel : .white)
                    .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
            )
            .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
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
        #if DEBUG
        // Keep native screenshot fixtures between carousel transitions.
        guard !(AppConfig.isUITesting && AppConfig.isIsolatedTestBuild) else { return }
        #endif
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        pairTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            withAnimation(.easeOut(duration: 0.12)) {
                pairIndex = (pairIndex + 1) % heroPairs.count
            }
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
                RetroPanelShape(cornerRadius: 12, style: .continuous)
                    .fill(color)
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                RetroSymbol(emoji, size: 22)
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
            RetroPanelShape(cornerRadius: 18, style: .continuous)
                .fill(Kids.cream)
                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
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
                Rectangle()
                    .fill(Kids.creamDeep)
                Rectangle()
                    .fill(LinearGradient(colors: [fill.opacity(0.85), fill],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * CGFloat(max(0, min(1, progress)))))
            }
        }
    }
}


/// Quiet pixel landscape for the home preview; no timer, gameplay or assets.
private struct RetroHomeLandscape: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#EFE1AE")))
            let unit: CGFloat = 5
            let horizon = (size.height * 0.55 / unit).rounded() * unit
            for row in 0..<4 {
                let base = horizon + CGFloat(row) * 16
                let color = ["#BEC296", "#94A477", "#6E895F", "#496845"][row]
                for x in stride(from: CGFloat.zero, to: size.width, by: unit) {
                    let lift = CGFloat(Int(sin(Double(x / 49 + CGFloat(row))) * 4)) * unit
                    context.fill(Path(CGRect(x: x, y: base + lift, width: unit, height: size.height - base - lift)), with: .color(Color(hex: color)))
                }
            }
            let sunX = (size.width * 0.57 / unit).rounded() * unit
            let sunY: CGFloat = 22
            context.fill(Path(CGRect(x: sunX, y: sunY, width: 30, height: 30)), with: .color(Kids.sun.opacity(0.5)))
            context.fill(Path(CGRect(x: sunX + 5, y: sunY - 5, width: 20, height: 40)), with: .color(Kids.sun.opacity(0.35)))
            context.fill(Path(CGRect(x: 0, y: size.height - 29, width: size.width, height: 29)), with: .color(Color(hex: "#B99C64")))
            context.fill(Path(CGRect(x: 0, y: size.height - 32, width: size.width, height: 5)), with: .color(Kids.grassDeep))
            for x in stride(from: CGFloat(8), to: size.width, by: 29) {
                context.fill(Path(CGRect(x: x, y: size.height - 16, width: 5, height: 3)), with: .color(Kids.peachDeep.opacity(0.45)))
            }
        }
        .accessibilityHidden(true)
    }
}
