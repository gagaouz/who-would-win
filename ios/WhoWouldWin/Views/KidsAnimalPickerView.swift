import SwiftUI

// MARK: - Picker Screen — Animal Arena Jr.
// Full feature parity with the legacy AnimalPickerView, restyled.

struct KidsAnimalPickerView: View {
    @StateObject private var viewModel = AnimalPickerViewModel()
    @ObservedObject private var coins = CoinStore.shared
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var cheat = CheatState.shared
    @StateObject private var speech = SpeechService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    @State private var navigateToBattle = false
    /// Bumped to force a fresh battle view for king-of-the-hill "Next Challenger".
    @State private var matchupToken = UUID()
    @State private var showArenaSheet = false
    @State private var showCoinShop = false
    @State private var showFantasyUnlock = false
    @State private var showPrehistoricUnlock = false
    @State private var showMythicUnlock = false
    @State private var showOlympusUnlock = false
    @FocusState private var searchFocused: Bool

    @AppStorage("custom.hintShown") private var customHintShownCount = 0
    @AppStorage("custom.freeUsed") private var customFreeUsed = false

    private var categories: [(AnimalCategory, String, String, Color)] {
        var list: [(AnimalCategory, String, String, Color)] = [
            (.all,    "All",    "🌈", Kids.pink),
            (.land,   "Land",   "🌳", Kids.grass),
            (.sea,    "Sea",    "🌊", Kids.sky),
            (.air,    "Air",    "☁️", Kids.grape),
            (.insect, "Bugs",   "🐛", Kids.peach),
            (.pets,   "Pets",   "🐶", Kids.peach),
            (.farm,   "Farm",   "🚜", Kids.grass),
        ]
        list.append((.prehistoric, "Dinos",   "🦖", Kids.sun))
        list.append((.fantasy,     "Fantasy", "🐉", Kids.grape))
        list.append((.mythic,      "Mythic",  "🔱", Kids.sunDeep))
        if cheat.olympusUnlocked || settings.isOlympusVisible {
            list.append((.olympus, "Olympus", "⚡", Kids.sun))
        }
        return list
    }

    var body: some View {
        ZStack {
            SkyBG(variant: .meadow)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    topBar
                    fighterCard
                    searchBar
                    if let err = speech.dictationError {
                        HStack(spacing: 5) {
                            RetroSymbol("🎤", size: isIPad ? 14 : 11)
                            Text(err)
                                .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, isIPad ? 20 : 14)
                        .padding(.top, 6)
                        .transition(.opacity)
                    } else if customHintShownCount < 3 && viewModel.searchText.isEmpty {
                        customHint
                    }
                    categoryPills
                    gridScroll
                }
                .frame(maxWidth: isIPad ? 720 : .infinity)
                Spacer(minLength: 0)
            }

            // Bottom action panel (lives ABOVE the scroll content)
            VStack { Spacer(); bottomActions }
                .ignoresSafeArea(.keyboard)
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToBattle) {
            if let f1 = viewModel.fighter1, let f2 = viewModel.fighter2 {
                KidsBattleView(fighter1: f1, fighter2: f2,
                               environment: viewModel.selectedEnvironment,
                               arenaEffectsEnabled: viewModel.arenaEffectsEnabled,
                               onNextChallenger: { winner in
                                   // Keep the winner, queue a fresh challenger, and
                                   // rebuild the battle view (new id → fresh fight).
                                   viewModel.setupNextChallenger(winner: winner)
                                   matchupToken = UUID()
                               })
                    .id(matchupToken)
            }
        }
        .sheet(isPresented: $showArenaSheet) {
            if let f1 = viewModel.fighter1, let f2 = viewModel.fighter2 {
                KidsPreBattleView(
                    fighter1: f1, fighter2: f2,
                    selectedEnvironment: $viewModel.selectedEnvironment,
                    arenaEffectsEnabled: $viewModel.arenaEffectsEnabled,
                    isPresented: $showArenaSheet,
                    onStart: {
                        showArenaSheet = false
                        navigateToBattle = true
                    }
                )
            }
        }
        .onAppear { BattleService.shared.warmUp() }   // wake the backend before battle
        .sheet(isPresented: $showCoinShop) { KidsCoinShopSheet(isPresented: $showCoinShop) }
        .onReceive(NotificationCenter.default.publisher(for: KidsCoinShop.openNotification)) { _ in
            showCoinShop = true
        }
        .sheet(isPresented: $showFantasyUnlock)     { FantasyUnlockSheet(isPresented: $showFantasyUnlock) }
        .sheet(isPresented: $showPrehistoricUnlock) { PrehistoricUnlockSheet(isPresented: $showPrehistoricUnlock) }
        .sheet(isPresented: $showMythicUnlock)      { MythicUnlockSheet(isPresented: $showMythicUnlock) }
        .sheet(isPresented: $showOlympusUnlock)     { OlympusUnlockSheet(isPresented: $showOlympusUnlock) }
        .onChange(of: speech.transcript) { newValue in
            guard !newValue.isEmpty else { return }
            viewModel.searchText = newValue
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            let matched = Animals.all.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
            if matched {
                speech.stopListening()
                AchievementTracker.shared.trackVoiceSearch()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            KidIconBtn(icon: "←", fill: .white) { dismiss() }
            Spacer()
            Text("PICK YOUR BUDDIES")
                .font(Kids.fredoka(isIPad ? 28 : 20, weight: .bold))
                .foregroundColor(Kids.ink)
            Spacer()
            CoinChip(count: coins.balance)
        }
        .padding(.horizontal, isIPad ? 24 : 16)
        .padding(.top, isIPad ? 12 : 8)
    }

    // MARK: - Fighter card

    private var fighterCard: some View {
        HStack(spacing: isIPad ? 10 : 6) {
            KidsFighterSlot(animal: viewModel.fighter1, tint: Kids.sun, isIPad: isIPad) { viewModel.clear(1) }
            StarSticker(text: "VS", size: isIPad ? 60 : 44, fill: Kids.pink)
            KidsFighterSlot(animal: viewModel.fighter2, tint: Kids.peach, isIPad: isIPad) { viewModel.clear(2) }
        }
        .padding(.horizontal, isIPad ? 14 : 8).padding(.vertical, isIPad ? 14 : 10)
        .background(
            RetroPanelShape(cornerRadius: 26, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 26, style: .continuous).stroke(Kids.ink, lineWidth: 3.5))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
        .padding(.horizontal, isIPad ? 20 : 14)
        .padding(.top, isIPad ? 16 : 12)
    }

    // MARK: - Search bar with voice

    private var searchBar: some View {
        HStack(spacing: isIPad ? 12 : 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: isIPad ? 18 : 14, weight: .semibold))
                .foregroundColor(Kids.inkSoft)

            TextField("Search or create ANY creature...", text: $viewModel.searchText)
                .font(Kids.nunito(isIPad ? 17 : 13, weight: .bold))
                .foregroundColor(Kids.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .tint(Kids.pink)
                .focused($searchFocused)
                .submitLabel(.done)
                .onSubmit { searchFocused = false }

            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isIPad ? 18 : 14))
                        .foregroundColor(Kids.inkSoft)
                }.buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button {
                if speech.isListening {
                    speech.stopListening()
                } else {
                    speech.transcript = ""
                    searchFocused = false
                    speech.startListening()
                }
            } label: {
                ZStack {
                    RetroPanelShape().fill(speech.isListening ? Kids.pink : Color.white)
                        .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2))
                        .frame(width: isIPad ? 40 : 30, height: isIPad ? 40 : 30)
                    Image(systemName: speech.isListening ? "mic.fill" : "mic")
                        .font(.system(size: isIPad ? 17 : 13, weight: .bold))
                        .foregroundColor(speech.isListening ? .white : Kids.ink)
                }
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, isIPad ? 18 : 12).padding(.vertical, isIPad ? 13 : 9)
        .background(
            RetroPanelShape(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
        .padding(.horizontal, isIPad ? 20 : 14)
        .padding(.top, isIPad ? 14 : 10)
    }

    private var customHint: some View {
        HStack(spacing: isIPad ? 7 : 5) {
            RetroSymbol("✨", size: isIPad ? 17 : 13)
            Text("Try 'Penguin', 'Hamster', or even your pet's name!")
                .font(Kids.nunito(isIPad ? 14 : 11, weight: .bold))
                .foregroundColor(Kids.ink)
        }
        .padding(.horizontal, isIPad ? 16 : 12).padding(.vertical, isIPad ? 6 : 4)
        .background(RetroPanelShape().fill(Kids.sun.opacity(0.5)).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5)))
        .padding(.top, isIPad ? 8 : 6)
        .onAppear { customHintShownCount += 1 }
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isIPad ? 9 : 6) {
                ForEach(categories, id: \.0) { (cat, label, emoji, color) in
                    let locked = isCategoryLocked(cat)
                    KidsCategoryPill(
                        label: label, emoji: emoji, color: color,
                        active: viewModel.selectedCategory == cat,
                        locked: locked,
                        isIPad: isIPad
                    )
                    .onTapGesture {
                        HapticsService.shared.tap()
                        if locked {
                            switch cat {
                            case .fantasy:     showFantasyUnlock = true
                            case .prehistoric: showPrehistoricUnlock = true
                            case .mythic:      showMythicUnlock = true
                            case .olympus:     showOlympusUnlock = true
                            default: break
                            }
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                viewModel.selectedCategory = cat
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, isIPad ? 20 : 14)
            .padding(.vertical, isIPad ? 8 : 6) // top + bottom breathing room so the pill shadows aren't clipped
        }
        .padding(.top, isIPad ? 16 : 12)
        .padding(.bottom, isIPad ? 6 : 4)
    }

    // MARK: - Grid

    private var gridScroll: some View {
        ScrollView {
            let gridSpacing: CGFloat = isIPad ? 14 : 10
            let columnCount = isIPad ? 5 : 3
            let cols = Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columnCount)
            LazyVGrid(columns: cols, spacing: gridSpacing) {
                if viewModel.searchText.isEmpty {
                    surpriseCard
                    makeYourOwnCard
                }
                ForEach(viewModel.filteredAnimals, id: \.id) { animal in
                    let locked = isAnimalLocked(animal)
                    KidsAnimalCard(
                        animal: animal,
                        selected: viewModel.fighter1?.id == animal.id || viewModel.fighter2?.id == animal.id,
                        locked: locked,
                        isIPad: isIPad
                    )
                    .onTapGesture {
                        HapticsService.shared.tap()
                        if locked {
                            switch animal.category {
                            case .fantasy:     showFantasyUnlock = true
                            case .prehistoric: showPrehistoricUnlock = true
                            case .mythic:      showMythicUnlock = true
                            case .olympus:     showOlympusUnlock = true
                            default: break
                            }
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                                if viewModel.fighter1?.id == animal.id { viewModel.clear(1) }
                                else if viewModel.fighter2?.id == animal.id { viewModel.clear(2) }
                                else { viewModel.select(animal) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, isIPad ? 20 : 14)
            .padding(.top, isIPad ? 14 : 10)

            // Empty / locked / custom prompts
            if viewModel.filteredAnimals.isEmpty && !viewModel.searchText.isEmpty {
                emptyState
            }
            if let locked = viewModel.lockedAnimal {
                lockedAnimalPrompt(locked)
            }
            if let custom = viewModel.customAnimal {
                customAnimalCard(custom)
            }

            // Spacer to clear bottom action panel
            Color.clear.frame(height: isIPad ? 170 : 150)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var surpriseCard: some View {
        Button {
            HapticsService.shared.medium()
            if let pick = randomUnlockedPick() {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                    viewModel.select(pick)
                }
            }
        } label: {
            ZStack {
                RetroPanelShape(cornerRadius: 22, style: .continuous)
                    .fill(Kids.grape)
                    .overlay(RetroPanelShape(cornerRadius: 22, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 22, style: .continuous).stroke(Kids.ink, lineWidth: 3.5))
                    .aspectRatio(1, contentMode: .fit)
                VStack(spacing: isIPad ? 3 : 2) {
                    RetroSymbol("🎲", size: isIPad ? 50 : 42)
                    Text("SURPRISE ME!")
                        .font(Kids.fredoka(isIPad ? 13 : 11, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .compositingGroup().shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // Non-text entry point so kids discover they can battle ANY creature —
    // tapping focuses the search field and pops the keyboard.
    private var makeYourOwnCard: some View {
        Button {
            HapticsService.shared.tap()
            searchFocused = true
        } label: {
            ZStack {
                RetroPanelShape(cornerRadius: 22, style: .continuous)
                    .fill(Kids.pink)
                    .overlay(RetroPanelShape(cornerRadius: 22, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: 22, style: .continuous).stroke(Kids.ink, lineWidth: 3.5))
                    .aspectRatio(1, contentMode: .fit)
                VStack(spacing: isIPad ? 3 : 2) {
                    RetroSymbol("✏️", size: isIPad ? 48 : 40)
                    Text("MAKE YOUR OWN!")
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .compositingGroup().shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: isIPad ? 11 : 8) {
            RetroSymbol("🔍", size: isIPad ? 50 : 38)
            Text("No animals found")
                .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                .foregroundColor(Kids.ink)
            Text("Try typing any creature name to battle with it!")
                .font(Kids.nunito(isIPad ? 15 : 12, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(isIPad ? 26 : 20)
        .frame(maxWidth: .infinity)
    }

    private func lockedAnimalPrompt(_ a: Animal) -> some View {
        HStack(spacing: isIPad ? 14 : 10) {
            RetroSymbol("🔒", size: isIPad ? 32 : 24)
            VStack(alignment: .leading, spacing: isIPad ? 3 : 2) {
                Text(a.name)
                    .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                    .foregroundColor(Kids.ink)
                Text("Unlock the pack to use \(a.name)")
                    .font(Kids.nunito(isIPad ? 14 : 11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
            Spacer()
            Button("Unlock") {
                switch a.category {
                case .fantasy:     showFantasyUnlock = true
                case .prehistoric: showPrehistoricUnlock = true
                case .mythic:      showMythicUnlock = true
                case .olympus:     showOlympusUnlock = true
                default: break
                }
            }
            .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
            .foregroundColor(Kids.ink)
            .padding(.horizontal, isIPad ? 16 : 12).padding(.vertical, isIPad ? 8 : 6)
            .background(RetroPanelShape().fill(Kids.grape).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2)))
        }
        .padding(isIPad ? 16 : 12)
        .background(
            RetroPanelShape(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .padding(.horizontal, isIPad ? 20 : 14)
        .padding(.top, isIPad ? 18 : 14)
    }

    private func customAnimalCard(_ custom: Animal) -> some View {
        let canAfford = coins.canAfford(CoinStore.shared.customCreatureCost)
        return VStack(spacing: isIPad ? 13 : 10) {
            HStack(spacing: isIPad ? 14 : 10) {
                // The local retro avatar is prepared after the fighter is selected.
                CustomAnimalAvatar(animal: custom, size: isIPad ? 64 : 50)
                VStack(alignment: .leading, spacing: isIPad ? 3 : 2) {
                    Text("Battle as \"\(custom.name)\"")
                        .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text(customFreeUsed ? "Choose how to unlock" : "First custom battle FREE!")
                        .font(Kids.nunito(isIPad ? 14 : 11, weight: .bold))
                        .foregroundColor(customFreeUsed ? Kids.inkSoft : Kids.grassDeep)
                }
                Spacer()
            }

            Text("We'll give your fighter a retro avatar, made on your device.")
                .font(Kids.nunito(isIPad ? 14 : 12, weight: .semibold))
                .foregroundColor(Kids.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !customFreeUsed {
                KidButton(title: "BATTLE FREE!", icon: "✨", color: Kids.grass, size: .md) {
                    customFreeUsed = true
                    viewModel.selectAnimal(custom)
                }
            } else {
                HStack(spacing: isIPad ? 10 : 8) {
                    Button {
                        // Re-entrancy guard: selection is idempotent but the
                        // spend is not — a rapid double-tap used to charge a
                        // kid twice for one pick.
                        let alreadyPicked = viewModel.fighter1?.id == custom.id
                                         || viewModel.fighter2?.id == custom.id
                        guard !alreadyPicked else { return }
                        if coins.spend(CoinStore.shared.customCreatureCost) {
                            viewModel.selectAnimal(custom)
                        }
                    } label: {
                        HStack(spacing: isIPad ? 6 : 4) {
                            KidsGoldCoin(size: isIPad ? 18 : 14)
                            Text("\(CoinStore.shared.customCreatureCost)")
                                .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                        }
                        .foregroundColor(canAfford ? Kids.ink : Kids.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: isIPad ? 50 : 40)
                        .background(
                            RetroPanelShape(cornerRadius: 14, style: .continuous)
                                .fill(canAfford ? Kids.sun : Kids.panel)
                                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2))
                        )
                    }
                    .disabled(!canAfford)

                    Button {
                        AdManager.shared.showRewardedAdForCustomCreature { granted in
                            if granted { viewModel.selectAnimal(custom) }
                        }
                    } label: {
                        HStack(spacing: isIPad ? 6 : 4) {
                            Image(systemName: "play.rectangle.fill").font(.system(size: isIPad ? 16 : 12))
                            Text("Free Ad").font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                        }
                        .foregroundColor(Kids.ink)
                        .frame(maxWidth: .infinity, minHeight: isIPad ? 50 : 40)
                        .background(
                            RetroPanelShape(cornerRadius: 14, style: .continuous)
                                .fill(Kids.grass)
                                .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2))
                        )
                    }
                }
            }
        }
        .padding(isIPad ? 16 : 12)
        .background(
            RetroPanelShape(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 18, style: .continuous).stroke(Kids.sun, lineWidth: 3))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
        .padding(.horizontal, isIPad ? 20 : 14)
        .padding(.top, isIPad ? 18 : 14)
    }

    // MARK: - Bottom CTAs
    //
    // No background overlay — the buttons / owl tip sit directly on whatever
    // the SkyBG renders. Avoids the visible "band" the previous fade caused.

    private var bottomActions: some View {
        VStack(spacing: isIPad ? 10 : 8) {
            if viewModel.canFight {
                HStack(spacing: isIPad ? 10 : 8) {
                    KidButton(title: "QUICK FIGHT!", icon: "⚡", color: Kids.sun, size: .md) {
                        HapticsService.shared.medium()
                        viewModel.arenaEffectsEnabled = false
                        viewModel.selectedEnvironment = .grassland
                        navigateToBattle = true
                    }
                    KidButton(title: "PICK ARENA", icon: "🌍", color: Kids.grass, size: .md) {
                        HapticsService.shared.tap()
                        viewModel.arenaEffectsEnabled = true
                        showArenaSheet = true
                    }
                }
                .frame(maxWidth: isIPad ? 720 : .infinity)
                .padding(.horizontal, isIPad ? 20 : 14)
            } else {
                HStack {
                    RetroSymbol("🦉", size: isIPad ? 24 : 18)
                    Text("Tap 2 buddies to start your match-up!")
                        .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                        .foregroundColor(Kids.ink)
                }
                .padding(.horizontal, isIPad ? 20 : 14).padding(.vertical, isIPad ? 12 : 9)
                .background(RetroPanelShape().fill(.white).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5)))
                .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
            }
        }
        .padding(.bottom, isIPad ? 36 : 30)
    }

    // MARK: - Helpers

    private func isCategoryLocked(_ c: AnimalCategory) -> Bool {
        switch c {
        case .fantasy:     return !settings.isFantasyUnlocked
        case .prehistoric: return !settings.isPrehistoricUnlocked
        case .mythic:      return !settings.isMythicUnlocked
        case .olympus:     return !settings.isOlympusUnlocked && !cheat.olympusUnlocked
        default:           return false
        }
    }

    private func isAnimalLocked(_ a: Animal) -> Bool {
        isCategoryLocked(a.category)
    }

    private func randomUnlockedPick() -> Animal? {
        let pool = Animals.all.filter { a in
            switch a.category {
            case .fantasy:     return settings.isFantasyUnlocked
            case .prehistoric: return settings.isPrehistoricUnlocked
            case .mythic:      return settings.isMythicUnlocked
            case .olympus:     return settings.isOlympusUnlocked || cheat.olympusUnlocked
            default:           return true
            }
        }
        let candidates = pool.filter { $0 != viewModel.fighter1 && $0 != viewModel.fighter2 }
        return candidates.randomElement()
    }
}

// MARK: - Fighter slot

private struct KidsFighterSlot: View {
    let animal: Animal?
    let tint: Color
    var isIPad: Bool = false
    let onClear: () -> Void

    private var bubbleSize: CGFloat { isIPad ? 108 : 76 }

    var body: some View {
        VStack(spacing: isIPad ? 8 : 6) {
            if let a = animal {
                ZStack(alignment: .topTrailing) {
                    AnimalBubble(animal: a, size: bubbleSize, tint: tint, tilt: 0)
                    Button(action: onClear) {
                        Text("✕")
                            .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .frame(width: isIPad ? 28 : 22, height: isIPad ? 28 : 22)
                            .background(RetroPanelShape().fill(Kids.ink))
                    }
                    .offset(x: isIPad ? 6 : 4, y: isIPad ? -6 : -4)
                }
                Text(a.name.uppercased())
                    .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .lineLimit(1).minimumScaleFactor(0.55)
                    .padding(.horizontal, isIPad ? 11 : 8).padding(.vertical, isIPad ? 5 : 3)
                    .background(
                        RetroPanelShape().fill(tint)
                            .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2))
                    )
                    .frame(maxWidth: isIPad ? 140 : 100)
            } else {
                ZStack {
                    RetroPanelShape()
                        .strokeBorder(Kids.ink.opacity(0.35), style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                        .background(RetroPanelShape().fill(Color.white.opacity(0.5)))
                        .frame(width: bubbleSize, height: bubbleSize)
                    Text("?").font(Kids.fredoka(isIPad ? 44 : 32, weight: .bold)).foregroundColor(Kids.ink.opacity(0.4))
                }
                Text("PICK ONE")
                    .font(Kids.nunito(isIPad ? 13 : 10, weight: .heavy)).tracking(1)
                    .foregroundColor(Kids.inkSoft)
                    .padding(.horizontal, isIPad ? 11 : 8).padding(.vertical, isIPad ? 5 : 3)
                    .background(RetroPanelShape().fill(Color.white.opacity(0.7)))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Category pill

private struct KidsCategoryPill: View {
    let label: String
    let emoji: String
    let color: Color
    let active: Bool
    let locked: Bool
    var isIPad: Bool = false
    var body: some View {
        HStack(spacing: isIPad ? 6 : 4) {
            RetroSymbol(locked ? "🔒" : emoji, size: isIPad ? 19 : 16).font(.system(size: isIPad ? 19 : 15))
            Text(label)
                .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                .foregroundColor(locked ? Kids.inkSoft : Kids.ink)
        }
        .padding(.horizontal, isIPad ? 16 : 11)
        .frame(height: isIPad ? 48 : 38)
        .background(
            RetroPanelShape().fill(locked ? Kids.panel : (active ? color : .white))
                .overlay(active && !locked ? RetroPanelShape().fill(Kids.sheen) : nil)
                .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(active ? 0.18 : 0.08), radius: 0, x: 0, y: active ? 3 : 2)
        .offset(y: active ? -1 : 0)
    }
}

// MARK: - Grid card

private struct KidsAnimalCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animal: Animal
    let selected: Bool
    let locked: Bool
    var isIPad: Bool = false

    private var cardColor: Color {
        switch animal.category {
        case .land:        return Kids.grass
        case .sea:         return Kids.sky
        case .air:         return Kids.grape
        case .insect:      return Kids.peach
        case .pets:        return Kids.peach
        case .farm:        return Kids.grass
        case .prehistoric: return Kids.sun
        case .fantasy:     return Kids.grape
        case .mythic:      return Kids.pink
        case .olympus:     return Kids.sunDeep
        case .all:         return Kids.pink
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RetroPanelShape(cornerRadius: 20, style: .continuous)
                .fill(locked ? Kids.panel : (selected ? cardColor : .white))
                .overlay(
                    Group {
                        if selected { RetroPanelShape(cornerRadius: 20, style: .continuous).fill(Kids.sheen) }
                    }
                )
                .overlay(
                    RetroPanelShape(cornerRadius: 20, style: .continuous)
                        .stroke(Kids.ink, lineWidth: 3)
                )
                .aspectRatio(1, contentMode: .fit)

            VStack(spacing: isIPad ? 3 : 2) {
                RetroCreatureArtwork(animal: animal, size: isIPad ? 72 : 60)
                    .opacity(locked ? 0.3 : 1)
                    .overlay {
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: isIPad ? 28 : 24, weight: .bold))
                                .foregroundColor(Kids.ink)
                        }
                    }
                Text(animal.name)
                    .font(Kids.fredoka(isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(locked ? Kids.inkSoft : Kids.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, isIPad ? 6 : 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if selected {
                RetroPanelShape().fill(Kids.grass)
                    .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2.5))
                    .frame(width: isIPad ? 32 : 26, height: isIPad ? 32 : 26)
                    .overlay(Text("✓").font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold)).foregroundColor(Kids.ink))
                    .offset(x: isIPad ? 6 : 4, y: isIPad ? -8 : -6)
            }
        }

        .offset(y: selected ? -2 : 0)
        .compositingGroup().shadow(color: Kids.ink.opacity(selected ? 0.18 : 0.1), radius: 0, x: 0, y: selected ? 4 : 3)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: selected)
        // Read as "Lion, selected" / "Dragon, locked" rather than emoji names.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(animal.name)
        .accessibilityValue(locked ? "Locked" : selected ? "Selected" : "")
        .accessibilityHint(locked ? "Tap to see how to unlock" : "Tap to pick this fighter")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - CustomAnimalAvatar
// The same cached pixel portrait is used in selection, battle, and sharing.
private struct CustomAnimalAvatar: View {
    let animal: Animal
    var size: CGFloat = 50

    var body: some View {
        RetroCustomCreaturePreview(size: size)
            .accessibilityLabel("Preview for \(animal.name). A retro avatar is made on your device after selection.")
    }
}
