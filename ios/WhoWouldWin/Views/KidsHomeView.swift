import SwiftUI

// MARK: - Home — the retro arena
// Keeps the original navigation and progression actions in one native home.

struct KidsHomeView: View {
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared
    @ObservedObject private var customFighters = CustomFighterService.shared
    @State private var showMyFighters = false
    @State private var selectedSavedFighter: Animal?
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var matchupHeaderHeight: CGFloat = 42
    @ScaledMetric(relativeTo: .headline) private var matchupActionHeight: CGFloat = 47
    // Keep the displayed fighters stable until the player changes the page.
    @State private var heroPairs = QuickMatchups.previewDeck()
    @State private var pairIndex = 0

    private var homeMotionActive: Bool {
        !showMyFighters && !showSettings && !showTournament && !showBook && !showHallOfFame
            && !goToPicker && !showCoinShop && !showMeleeUnlock && !goToMelee && !goToQuickBattle
            && mysteryReveal == nil && !showMysteryCoins && !showHowToPlay && !showWelcome && !showPaywall
    }

    private var matchupNameHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? matchupHeaderHeight * 1.5 : matchupHeaderHeight
    }

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
                            KidButton(title: "PICK YOUR FIGHTERS", icon: "▶", color: Kids.pink, size: .lg) {
                                HapticsService.shared.tap()
                                selectedSavedFighter = nil
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
                                .background(StickerShape(shape: RetroPanelShape(), fill: Kids.panel))
                            }
                            .buttonStyle(KidButtonPressStyle())
                            .accessibilityLabel("Surprise Me — start a random battle")
                            .accessibilityIdentifier("home.surpriseBattle")
                        }
                        Button { selectedSavedFighter = nil; showMyFighters = true } label: {
                            Label("My Fighters", systemImage: "person.3.fill")
                                .font(Kids.fredoka(17)).foregroundColor(Kids.grassDeep)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(StickerShape(shape: RetroPanelShape(), fill: Kids.panel))
                        }.accessibilityIdentifier("home.myFighters")
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
                .arcadeMotionViewport(active: homeMotionActive)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $goToPicker) {
                KidsAnimalPickerView(initialFighter: selectedSavedFighter)
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
            refreshUnavailableMatchups()
            maybeOfferHowToPlay()
            maybeShowPaywall()
        }
        .sheet(isPresented: $showMyFighters, onDismiss: {
            if selectedSavedFighter != nil { goToPicker = true }
        }) {
            MyFightersView { animal in
                selectedSavedFighter = animal
                showMyFighters = false
            }
        }
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
        .alert("Wow — you've collected EVERY sticker!", isPresented: $showMysteryCoins) {
            Button("Yay!", role: .cancel) {}
        } message: {
            Text("Here's 50 bonus coins instead.")
        }
        .fullScreenCover(isPresented: $showHowToPlay) { HowToPlayView() }
        .fullScreenCover(isPresented: $showPaywall) { PaywallView() }
        .alert("Welcome to Animal vs Animal!", isPresented: $showWelcome) {
            Button("Watch a battle!") { startSurprise() }
            Button("Show me how") { showHowToPlay = true }
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
        RetroAnimatedLogo(isIPad: isIPad)
            .padding(.vertical, 2)
    }

    private var heroConsole: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Rectangle().fill(Kids.sky).frame(width: 6, height: 6)
                Text("INSTANT BATTLE").font(Kids.pixel(9))
                Spacer()
                Text("READY!").font(Kids.pixel(8)).foregroundColor(Kids.sun)
            }
            .foregroundColor(Kids.panel)
            .padding(.horizontal, 13).padding(.vertical, 13)

            // Native paging lets horizontal swipes coexist with the home scroll.
            // Each page is a real button: the captured pair is the pair we launch.
            TabView(selection: $pairIndex) {
                ForEach(heroPairs.indices, id: \.self) { index in
                    matchupCard(heroPairs[index], selected: index == pairIndex)
                        .padding(.horizontal, 3)
                        .accessibilityHidden(index != pairIndex)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: (isIPad ? 200 : 170) + matchupNameHeight + matchupActionHeight)

            HStack(spacing: 8) {
                matchupArrow("chevron.left", label: "Previous matchup", identifier: "home.previousMatchup", step: -1)
                Spacer(minLength: 0)
                VStack(spacing: 7) {
                    HStack(spacing: 7) {
                        ForEach(heroPairs.indices, id: \.self) { index in
                            Rectangle().fill(index == pairIndex ? Kids.pink : Kids.outlineStrong.opacity(0.45))
                                .frame(width: index == pairIndex ? 20 : 7, height: 5)
                        }
                    }.accessibilityHidden(true)
                    Text("SWIPE TO FIND A MATCH")
                        .font(Kids.pixel(7)).foregroundColor(Kids.panel)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Matchup")
                .accessibilityValue("\(pairIndex + 1) of \(heroPairs.count)")
                .accessibilityIdentifier("home.matchupPage")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: moveMatchup(1)
                    case .decrement: moveMatchup(-1)
                    @unknown default: break
                    }
                }
                Spacer(minLength: 0)
                matchupArrow("chevron.right", label: "Next matchup", identifier: "home.nextMatchup", step: 1)
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
        }
        .background(StickerShape(shape: RetroPanelShape(), fill: Kids.console, strokeWidth: 2))
        .shadow(color: Kids.ink.opacity(0.22), radius: 0, x: 0, y: 5)
    }

    private func matchupCard(_ fighters: (Animal, Animal), selected: Bool) -> some View {
        Button {
            startFeaturedBattle(fighters)
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    Text(fighters.0.name.uppercased()).frame(maxWidth: .infinity, alignment: .leading)
                    Text("VS").font(Kids.pixel(12)).foregroundColor(Kids.sun)
                    Text(fighters.1.name.uppercased()).frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(Kids.pixel(8))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(Kids.panel)
                .padding(.horizontal, 11)
                .frame(height: matchupNameHeight)
                .background(Kids.console)
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RetroHomeLandscape()
                        HStack(alignment: .bottom) {
                            LivingCreatureArtwork(animal: fighters.0, size: min(geo.size.width * 0.43, geo.size.height - 12, 180), enabled: selected)
                            Spacer(minLength: 4)
                            LivingCreatureArtwork(animal: fighters.1, size: min(geo.size.width * 0.43, geo.size.height - 12, 180), enabled: selected, delay: 2.4)
                                .scaleEffect(x: -1, y: 1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 12)
                    }
                }
                .frame(height: isIPad ? 200 : 170)
                HStack(spacing: 10) {
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .black))
                    Text("TAP TO BATTLE").font(Kids.pixel(11))
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .black))
                }
                .foregroundColor(Kids.ink)
                .frame(maxWidth: .infinity, minHeight: matchupActionHeight)
                .background(Kids.sky)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start featured battle")
        .accessibilityValue("\(fighters.0.name) versus \(fighters.1.name)")
        .accessibilityHint("Starts a battle with these two fighters. Swipe left or right for more matchups.")
        .accessibilityIdentifier("home.heroBattle")
    }

    private func matchupArrow(_ symbol: String, label: String, identifier: String, step: Int) -> some View {
        Button { moveMatchup(step) } label: {
            Image(systemName: symbol).font(.system(size: 15, weight: .black))
                .foregroundColor(Kids.sky)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func moveMatchup(_ step: Int) {
        guard !heroPairs.isEmpty else { return }
        HapticsService.shared.tap()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            pairIndex = (pairIndex + step + heroPairs.count) % heroPairs.count
        }
    }

    private func refreshUnavailableMatchups() {
        // An expired entitlement can remove a featured fighter while a sheet is
        // open. Refresh on return, preserving all existing battle/unlock rules.
        if heroPairs.isEmpty || heroPairs.contains(where: { !settings.isAvailable($0.0) || !settings.isAvailable($0.1) }) {
            heroPairs = QuickMatchups.previewDeck()
            pairIndex = 0
        }
    }

    private func startFeaturedBattle(_ pair: (Animal, Animal)) {
        guard !goToQuickBattle else { return }
        guard settings.isAvailable(pair.0), settings.isAvailable(pair.1) else {
            refreshUnavailableMatchups()
            return
        }
        quickFighters = pair
        homeMatchupToken = UUID()
        HapticsService.shared.tap()
        SoundService.shared.play(.whoosh)
        goToQuickBattle = true
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
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
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
                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.07), radius: 4, x: 0, y: 3)
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
                        .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
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
                    .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
            )
            .compositingGroup().shadow(color: Kids.shadow.opacity(0.07), radius: 4, x: 0, y: 3)
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

    // Returns the *next* battle-threshold pack the player can earn for free.
    private func nextPackProgress() -> (name: String, emoji: String, threshold: Int, color: Color)? {
        if !settings.isPrehistoricUnlocked {
            return ("Dino Pack", "🦖", UserSettings.prehistoricBattleThreshold, Kids.sun)
        }
        if !settings.isFantasyUnlocked {
            return ("Fantasy Pack", "🧚", UserSettings.fantasyBattleThreshold, Kids.grape)
        }
        if !settings.isMythicUnlocked {
            return ("Mythic Beasts", "⚡", UserSettings.mythicBattleThreshold, Kids.sun)
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
                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
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
                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
        )
        .compositingGroup().shadow(color: Kids.shadow.opacity(0.07), radius: 4, x: 0, y: 3)
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


/// A sunset arcade stage: original sprite assets stay sharp over a quiet grid.
private struct RetroHomeLandscape: View {
    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(Path(bounds), with: .linearGradient(
                Gradient(colors: [Color(hex: "#4E306C"), Color(hex: "#BE6689"), Kids.peach]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let sunSide = min(size.height * 0.63, 112)
            let sunRect = CGRect(x: (size.width - sunSide) / 2, y: 8, width: sunSide, height: sunSide)
            var sunset = context
            sunset.clip(to: Path(ellipseIn: sunRect))
            sunset.fill(Path(sunRect), with: .linearGradient(
                Gradient(colors: [Kids.sun, Kids.peach, Kids.pink]),
                startPoint: sunRect.origin, endPoint: CGPoint(x: sunRect.midX, y: sunRect.maxY)))
            for row in 0..<5 {
                let y = sunRect.midY + CGFloat(row) * 10
                sunset.fill(Path(CGRect(x: sunRect.minX, y: y, width: sunSide, height: CGFloat(row + 1))),
                            with: .color(Color(hex: "#965278")))
            }
            // Pixel skyline gives the stage a cabinet-game horizon.
            let floorY = size.height - 24
            for (index, x) in stride(from: CGFloat(0), to: size.width, by: 17).enumerated() {
                let height = CGFloat([15, 27, 18, 36, 22, 12][index % 6])
                context.fill(Path(CGRect(x: x, y: floorY - height, width: 13, height: height)),
                             with: .color(Kids.console.opacity(0.28)))
            }
            context.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: 24)), with: .color(Kids.console))
            context.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: 3)), with: .color(Kids.sky))
            var grid = Path()
            for x in stride(from: CGFloat(-30), to: size.width + 30, by: 30) {
                grid.move(to: CGPoint(x: size.width / 2 + (x - size.width / 2) * 0.88, y: floorY + 3))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in [floorY + 9, floorY + 19] {
                grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(Kids.pink.opacity(0.6)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
