import SwiftUI

struct AnimalPickerView: View {
    @StateObject private var viewModel = AnimalPickerViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var cheat = CheatState.shared

    private var isIPad: Bool { sizeClass == .regular }
    private var hPad: CGFloat { isIPad ? 28 : 20 }

    @State private var navigateToBattle = false
    @State private var showPreBattleSheet = false
    @State private var fightButtonGlowRadius: CGFloat = 10
    @State private var emptySlotPulse: CGFloat = 1.0
    @State private var showFantasyUnlockSheet = false
    @State private var showPrehistoricUnlockSheet = false
    @State private var showMythicUnlockSheet = false
    @State private var showOlympusUnlockSheet = false
    @FocusState private var searchFocused: Bool
    @StateObject private var speech = SpeechService()
    @ObservedObject private var coinStore = CoinStore.shared
    @AppStorage("custom.hintShown") private var customHintShownCount: Int = 0
    @AppStorage("custom.freeUsed") private var customFreeUsed: Bool = false

    // Cheat code: tap VS ×2 then FIGHTERS ×6
    @State private var olympusCheatStep = 0
    @State private var showOlympusReveal = false

    private var standardColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: isIPad ? 5 : 3)
    }
    private let landscapeGridColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var bothSelected: Bool {
        viewModel.fighter1 != nil && viewModel.fighter2 != nil
    }

    var body: some View {
        GeometryReader { geo in
        ZStack {
            ScreenBackground(style: .home).ignoresSafeArea()
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            if isIPad && geo.size.width > geo.size.height {
                iPadLandscapeBody
            } else {
            VStack(spacing: 0) {

                // Nav bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                            Text("BACK")
                                .font(Theme.bungee(12))
                                .tracking(1)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("PICK YOUR")
                            .font(Theme.bungee(11))
                            .foregroundColor(.white.opacity(0.35))
                            .tracking(2)
                        Text("FIGHTERS")
                            .font(Theme.bungee(18))
                            .foregroundColor(cheat.olympusUnlocked ? Theme.olympusAccent : .white)
                            .onTapGesture { handleCheatFightersTap() }
                    }

                    Spacer()

                    CoinBadge(size: .compact)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 18)

                // Fighter slots
                HStack(spacing: 10) {
                    FighterSlot(
                        animal: viewModel.fighter1,
                        label: "Fighter 1",
                        emptyPulseScale: emptySlotPulse,
                        accentColor: Theme.orange,
                        onClear: { viewModel.clear(1) }
                    )

                    // VS badge — sits between slots; also first trigger of cheat code
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: cheat.olympusUnlocked
                                    ? [Theme.olympusAccent, Color(hex: "#B8860B")]
                                    : [Theme.orange, Theme.yellow],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 42, height: 42)
                            .shadow(color: (cheat.olympusUnlocked ? Theme.olympusAccent : Theme.orange).opacity(0.55), radius: 8, x: 0, y: 3)
                        Text("VS")
                            .pixelText(size: 10, color: .white)
                    }
                    .fixedSize()
                    .onTapGesture { handleCheatVSTap() }

                    FighterSlot(
                        animal: viewModel.fighter2,
                        label: "Fighter 2",
                        emptyPulseScale: emptySlotPulse,
                        accentColor: Theme.cyan,
                        onClear: { viewModel.clear(2) }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))

                    TextField("Search or create ANY creature...", text: $viewModel.searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .tint(Theme.orange)
                        .focused($searchFocused)
                        .submitLabel(.done)
                        .onSubmit { searchFocused = false }

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                    }

                    // Mic button
                    Button(action: {
                        if speech.isListening {
                            speech.stopListening()
                        } else {
                            speech.transcript = ""
                            searchFocused = false
                            speech.startListening()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(speech.isListening ? Theme.orange.opacity(0.2) : Color.white.opacity(0.08))
                                .frame(width: 32, height: 32)
                            Image(systemName: speech.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(speech.isListening ? Theme.orange : .white.opacity(0.5))
                                .scaleEffect(speech.isListening ? 1.15 : 1.0)
                                .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: speech.isListening)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .onChange(of: speech.transcript) { newValue in
                    guard !newValue.isEmpty else { return }
                    viewModel.searchText = newValue
                    // Stop immediately if the transcript already matches a built-in animal.
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    let matched = Animals.all.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
                    if matched {
                        speech.stopListening()
                        AchievementTracker.shared.trackVoiceSearch()
                    }
                }

                // Custom creature hint (shown first 3 visits)
                if customHintShownCount < 3 && viewModel.searchText.isEmpty {
                    HStack(spacing: 6) {
                        Text("✨")
                            .font(.system(size: 13))
                        Text("Try typing 'Penguin', 'Hamster', or even your pet's name!")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.yellow.opacity(0.9))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
                    .onAppear { customHintShownCount += 1 }
                    .transition(.opacity)
                }

                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AnimalCategory.allCases.filter {
                            $0 != .olympus || cheat.olympusUnlocked || settings.isOlympusVisible
                        }, id: \.self) { category in
                            let isLocked: Bool = {
                                switch category {
                                case .fantasy:     return !settings.isFantasyUnlocked
                                case .prehistoric: return !settings.isPrehistoricUnlocked
                                case .mythic:      return !settings.isMythicUnlocked
                                case .olympus:     return !settings.isOlympusUnlocked && !cheat.olympusUnlocked
                                default:           return false
                                }
                            }()
                            CategoryPill(
                                category: category,
                                isSelected: viewModel.selectedCategory == category,
                                isLocked: isLocked
                            ) {
                                if isLocked {
                                    HapticsService.shared.tap()
                                    switch category {
                                    case .fantasy:     showFantasyUnlockSheet = true
                                    case .prehistoric: showPrehistoricUnlockSheet = true
                                    case .mythic:      showMythicUnlockSheet = true
                                    case .olympus:     showOlympusUnlockSheet = true
                                    default: break
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        viewModel.selectedCategory = category
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
                .padding(.bottom, 12)

                // Animal grid — hard-clipped by ScrollView bounds (no partial cards at bottom)
                ScrollView {
                    LazyVGrid(columns: standardColumns, spacing: 10) {
                        // Random pick — first cell in the grid when browsing (not searching)
                        if viewModel.searchText.isEmpty {
                            RandomPickCard {
                                if let pick = randomUnlockedPick() {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                                        viewModel.select(pick)
                                    }
                                }
                            }
                        }
                        ForEach(viewModel.filteredAnimals) { animal in
                            let isSelected = viewModel.fighter1?.id == animal.id || viewModel.fighter2?.id == animal.id
                            let isAnimalLocked: Bool = {
                                switch animal.category {
                                case .fantasy:     return !settings.isFantasyUnlocked
                                case .prehistoric: return !settings.isPrehistoricUnlocked
                                case .mythic:      return !settings.isMythicUnlocked
                                case .olympus:     return !settings.isOlympusUnlocked && !cheat.olympusUnlocked
                                default:           return false
                                }
                            }()
                            AnimalCard(
                                animal: animal,
                                isSelected: isSelected,
                                isDisabled: false,
                                isLocked: isAnimalLocked
                            ) {
                                if isAnimalLocked {
                                    HapticsService.shared.tap()
                                    switch animal.category {
                                    case .fantasy:     showFantasyUnlockSheet = true
                                    case .prehistoric: showPrehistoricUnlockSheet = true
                                    case .mythic:      showMythicUnlockSheet = true
                                    case .olympus:     showOlympusUnlockSheet = true
                                    default: break
                                    }
                                } else {
                                    HapticsService.shared.tap()
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                                        if isSelected {
                                            if viewModel.fighter1?.id == animal.id { viewModel.clear(1) }
                                            else if viewModel.fighter2?.id == animal.id { viewModel.clear(2) }
                                        } else {
                                            viewModel.select(animal)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, hPad)
                    .padding(.top, 4)
                    .padding(.bottom, 16)

                    // Empty state when search yields no results
                    if viewModel.filteredAnimals.isEmpty && !viewModel.searchText.isEmpty {
                        VStack(spacing: 12) {
                            Text("🔍")
                                .font(.system(size: 40))
                            Text("No animals found")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Try a different search, or just type any creature name to battle with it!")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                    }

                    // Locked animal prompt
                    if let locked = viewModel.lockedAnimal {
                        HStack(spacing: 14) {
                            Text("🔒")
                                .font(.system(size: 28))
                                .frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(locked.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Unlock this pack to use \(locked.name)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Button("Unlock") {
                                HapticsService.shared.tap()
                                switch locked.category {
                                case .fantasy:     showFantasyUnlockSheet = true
                                case .prehistoric: showPrehistoricUnlockSheet = true
                                case .mythic:      showMythicUnlockSheet = true
                                case .olympus:     showOlympusUnlockSheet = true
                                default: break
                                }
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Theme.purple))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.purple.opacity(0.4), lineWidth: 1.5))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }

                    // Custom animal row — free first use, then dual path: coins OR ad
                    if let custom = viewModel.customAnimal {
                        let canAfford = coinStore.canAfford(CoinStore.shared.customCreatureCost)
                        VStack(spacing: 8) {
                            // Header
                            HStack(spacing: 14) {
                                customAnimalAvatar
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .background(Circle().fill(Color.white.opacity(0.1)))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Battle as \"\(custom.name)\"")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(customFreeUsed ? "Choose how to unlock" : "First custom battle FREE!")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(customFreeUsed ? .white.opacity(0.5) : Theme.neonGrn)
                                }
                                Spacer()
                            }

                            if !customFreeUsed {
                                // Free first use — big green button
                                Button {
                                    customFreeUsed = true
                                    viewModel.selectAnimal(custom)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text("✨").font(.system(size: 14))
                                        Text("BATTLE FREE")
                                            .font(.system(size: 15, weight: .black, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background(RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient(colors: [Theme.neonGrn, Theme.teal], startPoint: .leading, endPoint: .trailing)))
                                    .shadow(color: Theme.neonGrn.opacity(0.4), radius: 8, y: 3)
                                }
                                .buttonStyle(PressableButtonStyle())
                            } else {
                                // Two buttons side by side
                                HStack(spacing: 10) {
                                    // Coin path
                                    Button {
                                        if coinStore.spend(CoinStore.shared.customCreatureCost) {
                                            viewModel.selectAnimal(custom)
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            GoldCoin(size: 12)
                                            Text("\(CoinStore.shared.customCreatureCost)")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(canAfford ? Theme.gold : .white.opacity(0.35))
                                        .frame(maxWidth: .infinity).frame(height: 38)
                                        .background(RoundedRectangle(cornerRadius: 12)
                                            .fill(canAfford ? Theme.gold.opacity(0.15) : Color.white.opacity(0.06))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(canAfford ? Theme.gold.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)))
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                    .disabled(!canAfford)
                                    .opacity(canAfford ? 1.0 : 0.5)

                                    // Ad path
                                    Button {
                                        AdManager.shared.showRewardedAdForCustomCreature { granted in
                                            if granted { viewModel.selectAnimal(custom) }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.rectangle.fill").font(.system(size: 12))
                                            Text("Free Ad")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(Theme.neonGrn)
                                        .frame(maxWidth: .infinity).frame(height: 38)
                                        .background(RoundedRectangle(cornerRadius: 12)
                                            .fill(Theme.neonGrn.opacity(0.12))
                                            .overlay(RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.neonGrn.opacity(0.35), lineWidth: 1)))
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }

                                // Buy coins shortcut when coin path is unaffordable
                                if !canAfford {
                                    BuyCoinsButton()
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.yellow.opacity(0.35), lineWidth: 1.5))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
                .scrollDismissesKeyboard(.immediately)

                // Action buttons — lives below ScrollView so cards are hard-clipped at the boundary
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.4)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 28)
                    .allowsHitTesting(false)

                    if bothSelected {
                        HStack(spacing: 12) {
                            // Direct FIGHT — no arena effects
                            Button(action: {
                                HapticsService.shared.medium()
                                viewModel.arenaEffectsEnabled = false
                                viewModel.selectedEnvironment = .grassland
                                navigateToBattle = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("⚔️").font(.system(size: 20))
                                    Text("FIGHT")
                                        .font(Theme.bungee(18))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(LinearGradient(
                                            colors: [Theme.orange, Theme.yellow],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .overlay(RoundedRectangle(cornerRadius: 22)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1))
                                )
                                .shadow(color: Theme.orange.opacity(0.6), radius: fightButtonGlowRadius, x: 0, y: 6)
                            }
                            .buttonStyle(PressableButtonStyle())

                            // CHOOSE ARENA — opens sheet
                            Button(action: {
                                HapticsService.shared.tap()
                                // If user explicitly chose the arena path, default effects ON —
                                // the previous "FIGHT" (arenaless) battle may have left this
                                // toggled off. User can still flip it off inside the sheet.
                                viewModel.arenaEffectsEnabled = true
                                showPreBattleSheet = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("🏟️").font(.system(size: 20))
                                    Text("CHOOSE\nARENA")
                                        .font(Theme.bungee(13))
                                        .foregroundColor(Theme.orange)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(1)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(RoundedRectangle(cornerRadius: 22)
                                            .stroke(Theme.orange.opacity(0.5), lineWidth: 1.5))
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else {
                        Text("Pick 2 animals to fight")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1))
                            )
                            .padding(.horizontal, 24)
                            .padding(.bottom, 40)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: bothSelected)
                .background(Color.black.opacity(0.4))
            }
            } // end else
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToBattle) {
            if let f1 = viewModel.fighter1, let f2 = viewModel.fighter2 {
                BattleView(fighter1: f1, fighter2: f2, environment: viewModel.selectedEnvironment, arenaEffectsEnabled: viewModel.arenaEffectsEnabled)
            }
        }
        .sheet(isPresented: $showPreBattleSheet) {
            if let f1 = viewModel.fighter1, let f2 = viewModel.fighter2 {
                PreBattleSheet(
                    fighter1: f1,
                    fighter2: f2,
                    isPresented: $showPreBattleSheet,
                    selectedEnvironment: $viewModel.selectedEnvironment,
                    arenaEffectsEnabled: $viewModel.arenaEffectsEnabled,
                    onFight: { navigateToBattle = true }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
        .sheet(isPresented: $showFantasyUnlockSheet) {
            FantasyUnlockSheet(isPresented: $showFantasyUnlockSheet)
        }
        .sheet(isPresented: $showPrehistoricUnlockSheet) {
            PrehistoricUnlockSheet(isPresented: $showPrehistoricUnlockSheet)
        }
        .sheet(isPresented: $showMythicUnlockSheet) {
            MythicUnlockSheet(isPresented: $showMythicUnlockSheet)
        }
        .sheet(isPresented: $showOlympusUnlockSheet) {
            OlympusUnlockSheet(isPresented: $showOlympusUnlockSheet)
        }
        .onAppear { startPulseAnimations() }
        // Olympus reveal overlay
        .overlay {
            if showOlympusReveal {
                OlympusRevealOverlay {
                    withAnimation(.easeOut(duration: 0.4)) { showOlympusReveal = false }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showOlympusReveal)
        } // end GeometryReader
    }

    // MARK: - iPad Landscape Split Layout

    @ViewBuilder private var iPadLandscapeBody: some View {
        HStack(spacing: 0) {
            // ── Left control panel ──────────────────────────────────────
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                            Text("BACK").font(Theme.bungee(12)).tracking(1)
                        }
                        .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    VStack(spacing: 2) {
                        Text("PICK YOUR")
                            .font(Theme.bungee(11))
                            .foregroundColor(.white.opacity(0.35)).tracking(2)
                        Text("FIGHTERS")
                            .font(Theme.bungee(18))
                            .foregroundColor(cheat.olympusUnlocked ? Theme.olympusAccent : .white)
                            .onTapGesture { handleCheatFightersTap() }
                    }
                    Spacer()
                    CoinBadge(size: .compact)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 18)

                // Fighter slots
                HStack(spacing: 10) {
                    FighterSlot(animal: viewModel.fighter1, label: "Fighter 1",
                                emptyPulseScale: emptySlotPulse, accentColor: Theme.orange,
                                onClear: { viewModel.clear(1) })
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: cheat.olympusUnlocked
                                    ? [Theme.olympusAccent, Color(hex: "#B8860B")]
                                    : [Theme.orange, Theme.yellow],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 42, height: 42)
                            .shadow(color: (cheat.olympusUnlocked ? Theme.olympusAccent : Theme.orange).opacity(0.55), radius: 8, x: 0, y: 3)
                        Text("VS").pixelText(size: 10, color: .white)
                    }
                    .fixedSize().onTapGesture { handleCheatVSTap() }
                    FighterSlot(animal: viewModel.fighter2, label: "Fighter 2",
                                emptyPulseScale: emptySlotPulse, accentColor: Theme.cyan,
                                onClear: { viewModel.clear(2) })
                }
                .padding(.horizontal, 20).padding(.bottom, 18)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium)).foregroundColor(.white.opacity(0.35))
                    TextField("Search or create ANY creature...", text: $viewModel.searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white).autocorrectionDisabled()
                        .textInputAutocapitalization(.never).tint(Theme.orange)
                        .focused($searchFocused).submitLabel(.done)
                        .onSubmit { searchFocused = false }
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15)).foregroundColor(.white.opacity(0.35))
                        }.buttonStyle(.plain)
                    }
                    Button(action: {
                        if speech.isListening { speech.stopListening() }
                        else { speech.transcript = ""; searchFocused = false; speech.startListening() }
                    }) {
                        ZStack {
                            Circle().fill(speech.isListening ? Theme.orange.opacity(0.2) : Color.white.opacity(0.08)).frame(width: 32, height: 32)
                            Image(systemName: speech.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(speech.isListening ? Theme.orange : .white.opacity(0.5))
                                .scaleEffect(speech.isListening ? 1.15 : 1.0)
                                .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: speech.isListening)
                        }
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1)))
                .padding(.horizontal, 20).padding(.bottom, 12)

                // Category grid (iPad has room for a proper grid)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(AnimalCategory.allCases.filter {
                        $0 != .olympus || cheat.olympusUnlocked || settings.isOlympusVisible
                    }, id: \.self) { category in
                        let isLocked: Bool = {
                            switch category {
                            case .fantasy:     return !settings.isFantasyUnlocked
                            case .prehistoric: return !settings.isPrehistoricUnlocked
                            case .mythic:      return !settings.isMythicUnlocked
                            case .olympus:     return !settings.isOlympusUnlocked && !cheat.olympusUnlocked
                            default:           return false
                            }
                        }()
                        CategoryPill(category: category, isSelected: viewModel.selectedCategory == category, isLocked: isLocked, enlarged: true) {
                            if isLocked {
                                HapticsService.shared.tap()
                                switch category {
                                case .fantasy:     showFantasyUnlockSheet = true
                                case .prehistoric: showPrehistoricUnlockSheet = true
                                case .mythic:      showMythicUnlockSheet = true
                                case .olympus:     showOlympusUnlockSheet = true
                                default: break
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.selectedCategory = category }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                Spacer()

                // Action buttons
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.clear, Color.black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 20).allowsHitTesting(false)
                    if bothSelected {
                        VStack(spacing: 10) {
                            // Direct FIGHT — no arena effects
                            Button(action: {
                                HapticsService.shared.medium()
                                viewModel.arenaEffectsEnabled = false
                                viewModel.selectedEnvironment = .grassland
                                navigateToBattle = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("⚔️").font(.system(size: 20))
                                    Text("FIGHT")
                                        .font(Theme.bungee(18))
                                        .foregroundColor(.white)
                                    Text("⚔️").font(.system(size: 20))
                                }
                                .frame(maxWidth: .infinity).frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(LinearGradient(colors: [Theme.orange, Theme.yellow], startPoint: .leading, endPoint: .trailing))
                                        .overlay(RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1))
                                )
                                .shadow(color: Theme.orange.opacity(0.6), radius: fightButtonGlowRadius, x: 0, y: 6)
                            }
                            .buttonStyle(PressableButtonStyle())

                            // CHOOSE ARENA — opens sheet
                            Button(action: {
                                HapticsService.shared.tap()
                                // Default arena effects ON when user explicitly picks the arena
                                // path — prior arenaless FIGHT may have set this to false.
                                viewModel.arenaEffectsEnabled = true
                                showPreBattleSheet = true
                            }) {
                                HStack(spacing: 8) {
                                    Text("🏟️").font(.system(size: 18))
                                    Text("CHOOSE ARENA")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.orange)
                                }
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(RoundedRectangle(cornerRadius: 18)
                                            .stroke(Theme.orange.opacity(0.5), lineWidth: 1.5))
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                        .padding(.horizontal, 20).padding(.bottom, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else {
                        Text("Pick 2 animals to fight")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(maxWidth: .infinity).frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 22)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1))
                            )
                            .padding(.horizontal, 20).padding(.bottom, 32)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: bothSelected)
                .background(Color.black.opacity(0.4))
            }
            .frame(width: 360)
            .background(Color.black.opacity(0.12))

            // Divider
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)

            // ── Right animal grid ────────────────────────────────────────
            ScrollView {
                LazyVGrid(columns: landscapeGridColumns, spacing: 12) {
                    // Random pick — first cell when browsing
                    if viewModel.searchText.isEmpty {
                        RandomPickCard {
                            if let pick = randomUnlockedPick() {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                                    viewModel.select(pick)
                                }
                            }
                        }
                    }
                    ForEach(viewModel.filteredAnimals) { animal in
                        let isSelected = viewModel.fighter1?.id == animal.id || viewModel.fighter2?.id == animal.id
                        let isAnimalLocked: Bool = {
                            switch animal.category {
                            case .fantasy:     return !settings.isFantasyUnlocked
                            case .prehistoric: return !settings.isPrehistoricUnlocked
                            case .mythic:      return !settings.isMythicUnlocked
                            case .olympus:     return !settings.isOlympusUnlocked && !cheat.olympusUnlocked
                            default:           return false
                            }
                        }()
                        AnimalCard(animal: animal, isSelected: isSelected, isDisabled: false, isLocked: isAnimalLocked) {
                            if isAnimalLocked {
                                HapticsService.shared.tap()
                                switch animal.category {
                                case .fantasy:     showFantasyUnlockSheet = true
                                case .prehistoric: showPrehistoricUnlockSheet = true
                                case .mythic:      showMythicUnlockSheet = true
                                case .olympus:     showOlympusUnlockSheet = true
                                default: break
                                }
                            } else {
                                HapticsService.shared.tap()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                                    if isSelected {
                                        if viewModel.fighter1?.id == animal.id { viewModel.clear(1) }
                                        else if viewModel.fighter2?.id == animal.id { viewModel.clear(2) }
                                    } else {
                                        viewModel.select(animal)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 16)

                // Locked animal prompt
                if let locked = viewModel.lockedAnimal {
                    HStack(spacing: 14) {
                        Text("🔒").font(.system(size: 28)).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(locked.name).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                            Text("Unlock this pack to use \(locked.name)").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Button("Unlock") {
                            HapticsService.shared.tap()
                            switch locked.category {
                            case .fantasy:     showFantasyUnlockSheet = true
                            case .prehistoric: showPrehistoricUnlockSheet = true
                            case .mythic:      showMythicUnlockSheet = true
                            case .olympus:     showOlympusUnlockSheet = true
                            default: break
                            }
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(Theme.purple))
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.purple.opacity(0.4), lineWidth: 1.5)))
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }

                // Custom animal row — dual path: coins OR ad
                if let custom = viewModel.customAnimal {
                    let canAfford = coinStore.canAfford(CoinStore.shared.customCreatureCost)
                    VStack(spacing: 8) {
                        HStack(spacing: 14) {
                            Group {
                                if let imageURL = viewModel.customAnimalImageURL {
                                    AsyncImage(url: imageURL) { phase in
                                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                                        else if case .failure = phase { Text(viewModel.customAnimalEmoji).font(.system(size: 28)) }
                                        else { ProgressView().tint(.white) }
                                    }
                                } else { Text(viewModel.customAnimalEmoji).font(.system(size: 28)) }
                            }
                            .frame(width: 48, height: 48).clipShape(Circle()).background(Circle().fill(Color.white.opacity(0.1)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Battle as \"\(custom.name)\"").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                                Text("Choose how to unlock").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                        }
                        HStack(spacing: 10) {
                            Button {
                                if coinStore.spend(CoinStore.shared.customCreatureCost) { viewModel.selectAnimal(custom) }
                            } label: {
                                HStack(spacing: 4) {
                                    GoldCoin(size: 12)
                                    Text("\(CoinStore.shared.customCreatureCost)").font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(canAfford ? Theme.gold : .white.opacity(0.35))
                                .frame(maxWidth: .infinity).frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 12).fill(canAfford ? Theme.gold.opacity(0.15) : Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(canAfford ? Theme.gold.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)))
                            }.buttonStyle(PressableButtonStyle()).disabled(!canAfford).opacity(canAfford ? 1.0 : 0.5)

                            Button {
                                AdManager.shared.showRewardedAdForCustomCreature { granted in
                                    if granted { viewModel.selectAnimal(custom) }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.rectangle.fill").font(.system(size: 12))
                                    Text("Free Ad").font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(Theme.neonGrn)
                                .frame(maxWidth: .infinity).frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.neonGrn.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.neonGrn.opacity(0.35), lineWidth: 1)))
                            }.buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.yellow.opacity(0.35), lineWidth: 1.5)))
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // MARK: - Helpers

    @ViewBuilder private var customAnimalAvatar: some View {
        if let imageURL = viewModel.customAnimalImageURL {
            AsyncImage(url: imageURL) { phase in
                if case .success(let img) = phase {
                    img.resizable().scaledToFill()
                } else if case .failure = phase {
                    Text(viewModel.customAnimalEmoji).font(.system(size: 28))
                } else {
                    ProgressView().tint(.white)
                }
            }
        } else {
            Text(viewModel.customAnimalEmoji).font(.system(size: 28))
        }
    }

    // MARK: - Animations

    private func startPulseAnimations() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            emptySlotPulse = 0.72
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            fightButtonGlowRadius = 22
        }
    }

    // MARK: - Random pick

    /// Picks a random creature from the currently-filtered list that is
    /// unlocked AND not already in either fighter slot. Returns nil if
    /// the pool is empty (all filtered creatures are locked or picked).
    private func randomUnlockedPick() -> Animal? {
        let pool = viewModel.filteredAnimals.filter { animal in
            // Exclude locked
            switch animal.category {
            case .fantasy:     if !settings.isFantasyUnlocked { return false }
            case .prehistoric: if !settings.isPrehistoricUnlocked { return false }
            case .mythic:      if !settings.isMythicUnlocked { return false }
            case .olympus:     if !settings.isOlympusUnlocked && !cheat.olympusUnlocked { return false }
            default: break
            }
            // Exclude already-picked
            if animal == viewModel.fighter1 || animal == viewModel.fighter2 { return false }
            return true
        }
        return pool.randomElement()
    }

    // MARK: - Cheat code: VS ×2 then FIGHTERS ×6

    private func handleCheatVSTap() {
        guard !cheat.olympusUnlocked else { return }
        if olympusCheatStep < 2 {
            olympusCheatStep += 1
            HapticsService.shared.tap()
        } else {
            olympusCheatStep = 0  // tapping VS after already having 2 resets
        }
    }

    private func handleCheatFightersTap() {
        guard !cheat.olympusUnlocked else { return }
        if olympusCheatStep >= 2 {
            olympusCheatStep += 1
            HapticsService.shared.tap()
            if olympusCheatStep >= 8 {
                triggerOlympusUnlock()
            }
        } else {
            olympusCheatStep = 0
        }
    }

    private func triggerOlympusUnlock() {
        HapticsService.shared.medium()
        cheat.olympusUnlocked = true
        showOlympusReveal = true
        // Auto-dismiss after 3.2 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.4)) { showOlympusReveal = false }
        }
        // Switch to Olympus tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedCategory = .olympus
            }
        }
    }
}

// MARK: - Olympus Reveal Overlay

struct OlympusRevealOverlay: View {
    let onDismiss: () -> Void
    @State private var lightningOpacity: Double = 0
    @State private var textScale: CGFloat = 0.4
    @State private var textOpacity: Double = 0
    @State private var boltOffset: CGFloat = -60

    var body: some View {
        ZStack {
            // Flash backdrop
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            // Gold rays
            RadialGradient(
                colors: [Theme.olympusAccent.opacity(0.45), Color.clear],
                center: .center, startRadius: 0, endRadius: 300
            )
            .ignoresSafeArea()
            .opacity(lightningOpacity)

            VStack(spacing: 20) {
                // Lightning bolts
                HStack(spacing: 18) {
                    Text("⚡️").font(.system(size: 44))
                        .offset(y: boltOffset).opacity(lightningOpacity)
                    Text("🏛️").font(.system(size: 64))
                        .scaleEffect(textScale).opacity(textOpacity)
                    Text("⚡️").font(.system(size: 44))
                        .offset(y: boltOffset).opacity(lightningOpacity)
                }

                Text("MOUNT OLYMPUS")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.olympusAccent, Color.white, Theme.olympusAccent],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .shadow(color: Theme.olympusAccent.opacity(0.8), radius: 12)
                    .scaleEffect(textScale)
                    .opacity(textOpacity)

                Text("UNLOCKED")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Theme.olympusAccent)
                    .tracking(6)
                    .opacity(textOpacity)

                Text("The gods have descended.\nChoose wisely.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)

                Button(action: onDismiss) {
                    Text("Enter Olympus")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#0E0B22"))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.olympusAccent))
                        .shadow(color: Theme.olympusAccent.opacity(0.6), radius: 10)
                }
                .buttonStyle(PressableButtonStyle())
                .opacity(textOpacity)
            }
            .padding(32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                lightningOpacity = 1
                boltOffset = 0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
                textScale = 1
                textOpacity = 1
            }
        }
        .onTapGesture { onDismiss() }
    }
}

// MARK: - Fighter Slot

struct FighterSlot: View {
    let animal: Animal?
    let label: String
    let emptyPulseScale: CGFloat
    let accentColor: Color
    let onClear: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            animal != nil ? accentColor.opacity(0.7) : Color.white.opacity(0.2),
                            lineWidth: animal != nil ? 2 : 1
                        )
                )
                .shadow(
                    color: animal != nil ? accentColor.opacity(0.25) : .clear,
                    radius: 10, x: 0, y: 4
                )
                .frame(height: 108)
                .overlay(
                    Group {
                        if let animal = animal {
                            VStack(spacing: 6) {
                                Group {
                                    if let assetName = animal.creatureAssetName,
                                       let img = UIImage(named: assetName) {
                                        // Generated artwork for paid pack creatures
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 50, height: 50)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else if let url = animal.imageURL {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFill()
                                                    .frame(width: 50, height: 50).clipShape(Circle())
                                            default:
                                                Text(animal.emoji).font(.system(size: 42))
                                            }
                                        }
                                    } else {
                                        Text(animal.emoji).font(.system(size: 42))
                                    }
                                }

                                Text(animal.name)
                                    .font(Theme.bungee(11))
                                    .foregroundColor(accentColor)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.65)
                                    .padding(.horizontal, 8)
                            }
                        } else {
                            VStack(spacing: 8) {
                                Text("?")
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                                    .scaleEffect(emptyPulseScale)
                                Text(label)
                                    .font(Theme.bungee(10))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture { if animal != nil { onClear() } }

            // Remove badge
            if animal != nil {
                Button(action: onClear) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .black))
                        Text("REMOVE")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.red))
                    .shadow(color: Theme.red.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .offset(y: 14)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, animal != nil ? 14 : 0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: animal?.id)
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let category: AnimalCategory
    let isSelected: Bool
    var isLocked: Bool = false
    var enlarged: Bool = false
    let onTap: () -> Void

    private var selectedGradient: LinearGradient {
        switch category {
        case .all:
            return LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        case .land:
            return LinearGradient(colors: [Color(hex: "#8B5CF6"), Color(hex: "#6d28d9")], startPoint: .leading, endPoint: .trailing)
        case .sea:
            return LinearGradient(colors: [Color(hex: "#2563EB"), Color(hex: "#1d4ed8")], startPoint: .leading, endPoint: .trailing)
        case .air:
            return LinearGradient(colors: [Color(hex: "#0891B2"), Color(hex: "#0e7490")], startPoint: .leading, endPoint: .trailing)
        case .insect:
            return LinearGradient(colors: [Color(hex: "#65A30D"), Color(hex: "#4d7c0f")], startPoint: .leading, endPoint: .trailing)
        case .fantasy:
            return LinearGradient(colors: [Color(hex: "#7B2FBE"), Color(hex: "#4A1080")], startPoint: .leading, endPoint: .trailing)
        case .prehistoric:
            return LinearGradient(colors: [Color(hex: "#C8820A"), Color(hex: "#8B5A0A")], startPoint: .leading, endPoint: .trailing)
        case .mythic:
            return LinearGradient(colors: [Color(hex: "#C0A000"), Color(hex: "#8B7500")], startPoint: .leading, endPoint: .trailing)
        case .olympus:
            return LinearGradient(colors: [Color(hex: "#FFD700"), Color(hex: "#B8860B"), Color(hex: "#FFD700")], startPoint: .leading, endPoint: .trailing)
        }
    }

    // Unselected background — visible on both light and dark
    private var unselectedBg: AnyShapeStyle {
        AnyShapeStyle(Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(white: 0.0, alpha: 0.08)
                : UIColor(white: 1.0, alpha: 0.10)
        }))
    }

    // Unselected text — readable on both
    private var unselectedTextColor: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(white: 0.15, alpha: 1)
                : UIColor(white: 1.0, alpha: 0.75)
        })
    }

    // Unselected border
    private var unselectedBorder: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .light
                ? UIColor(white: 0.0, alpha: 0.18)
                : UIColor(white: 1.0, alpha: 0.12)
        })
    }

    private var textColor: Color {
        if isSelected {
            return category == .all ? Color(hex: "#0E0B22") : .white
        }
        return unselectedTextColor
    }

    var body: some View {
        Button(action: onTap) {
            if enlarged {
                VStack(spacing: 4) {
                    Text(Theme.categoryEmoji(category))
                        .font(.system(size: 22))
                    HStack(spacing: 4) {
                        Text(Theme.categoryLabel(category))
                            .font(Theme.bungee(13))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.categoryAccent(category).opacity(0.9))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? AnyShapeStyle(selectedGradient) : unselectedBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isLocked
                                ? Theme.categoryAccent(category).opacity(0.5)
                                : (isSelected ? Color.clear : unselectedBorder),
                            lineWidth: isLocked ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isSelected ? Theme.categoryAccent(category).opacity(0.4) : .clear,
                    radius: 6, x: 0, y: 3
                )
            } else {
                HStack(spacing: 5) {
                    Text(Theme.categoryEmoji(category))
                        .font(.system(size: 13))
                    Text(Theme.categoryLabel(category))
                        .font(Theme.bungee(13))
                        .foregroundColor(textColor)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.categoryAccent(category).opacity(0.9))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(selectedGradient) : unselectedBg)
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLocked
                                ? Theme.categoryAccent(category).opacity(0.5)
                                : (isSelected ? Color.clear : unselectedBorder),
                            lineWidth: isLocked ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isSelected ? Theme.categoryAccent(category).opacity(0.4) : .clear,
                    radius: 6, x: 0, y: 3
                )
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - EnvironmentPickerStrip

struct EnvironmentPickerStrip: View {
    @Binding var selected: BattleEnvironment
    let onLockedTap: (BattleEnvironment) -> Void
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                Text("CHOOSE ARENA")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.35))
                    .tracking(2)
                    .padding(.horizontal, 10)
                Rectangle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BattleEnvironment.allCases) { env in
                        let isUnlocked = settings.isEnvironmentUnlocked(env)
                        let isSelected = selected == env
                        EnvironmentCard(
                            env: env,
                            isSelected: isSelected,
                            isUnlocked: isUnlocked
                        ) {
                            if isUnlocked {
                                HapticsService.shared.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selected = env
                                }
                            } else {
                                onLockedTap(env)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 8)
    }
}

struct EnvironmentCard: View {
    let env: BattleEnvironment
    let isSelected: Bool
    let isUnlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    // Background glow when selected
                    if isSelected {
                        Circle()
                            .fill(env.accentColor.opacity(0.25))
                            .frame(width: 48, height: 48)
                            .blur(radius: 6)
                    }

                    Circle()
                        .fill(isSelected
                              ? AnyShapeStyle(LinearGradient(
                                    colors: [env.accentColor.opacity(0.35), env.accentColor.opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                              : AnyShapeStyle(Color.white.opacity(isUnlocked ? 0.08 : 0.04)))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle().stroke(
                                isSelected ? env.accentColor : Color.white.opacity(isUnlocked ? 0.15 : 0.07),
                                lineWidth: isSelected ? 2 : 1
                            )
                        )
                        .shadow(color: isSelected ? env.accentColor.opacity(0.5) : .clear, radius: 8, x: 0, y: 3)

                    if isUnlocked {
                        Text(env.emoji)
                            .font(.system(size: 22))
                    } else {
                        ZStack {
                            Text(env.emoji)
                                .font(.system(size: 22))
                                .opacity(0.3)
                            Text("🔒")
                                .font(.system(size: 13))
                                .offset(x: 10, y: 10)
                        }
                    }
                }

                Text(env.name.uppercased())
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(isSelected ? env.accentColor : Color.white.opacity(isUnlocked ? 0.55 : 0.25))
                    .lineLimit(1)

                // Tier badge
                if !isUnlocked {
                    Group {
                        if let threshold = env.battleThreshold {
                            Text("\(threshold) battles")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#FFB347").opacity(0.8))
                        } else {
                            Text("PACK")
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .foregroundColor(Theme.purple.opacity(0.9))
                        }
                    }
                } else if env.tier == .premium {
                    Text("PREMIUM")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundColor(Theme.purple.opacity(0.7))
                } else {
                    Text(" ")
                        .font(.system(size: 7))
                }
            }
            .frame(width: 56)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - EnvironmentsPackSheet

struct EnvironmentsPackSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var storeKit = StoreKitManager.shared

    private let premiumEnvs: [BattleEnvironment] = [.jungle, .volcano, .night, .storm]

    var body: some View {
        ZStack {
            ScreenBackground(style: .home).ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("🌍")
                                .font(.system(size: 52))
                            Text("UNLOCK ALL ARENAS")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .tracking(1)
                            Text("9 unique environments that change\nthe outcome of every battle")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.55))
                                .multilineTextAlignment(.center)
                        }

                        // Environment grid preview
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(BattleEnvironment.allCases.filter { $0 != .grassland }) { env in
                                HStack(spacing: 10) {
                                    Text(env.emoji).font(.system(size: 24))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(env.name)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text(env.tagline)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(Color.white.opacity(0.45))
                                            .lineLimit(2)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(env.accentColor.opacity(0.08))
                                        .overlay(RoundedRectangle(cornerRadius: 14)
                                            .stroke(env.accentColor.opacity(0.25), lineWidth: 1))
                                )
                            }
                        }
                        .padding(.horizontal, 4)

                        // Purchase button
                        Button {
                            Task {
                                if let product = await StoreKitManager.shared.environmentsPackProduct {
                                    let success = await StoreKitManager.shared.purchase(product)
                                    if success { isPresented = false }
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if storeKit.isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("🌍")
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Unlock All Arenas")
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                        if let product = storeKit.environmentsPackProduct {
                                            Text(product.displayPrice)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white.opacity(0.75))
                                        } else {
                                            Text("$2.99")
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white.opacity(0.75))
                                        }
                                    }
                                    Spacer()
                                    Text("One-time")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(.white.opacity(0.12)))
                                }
                            }
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#4CAF50"), Color(hex: "#2E7D32")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                            )
                            .shadow(color: Color(hex: "#4CAF50").opacity(0.45), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(storeKit.isPurchasing)

                        Button("Restore Purchases") {
                            Task { await StoreKitManager.shared.restorePurchases() }
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.4))

                        Button("Maybe Later") { isPresented = false }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.35))
                            .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AnimalPickerView()
    }
}
