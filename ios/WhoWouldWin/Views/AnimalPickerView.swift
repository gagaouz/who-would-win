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
    @State private var fightButtonGlowRadius: CGFloat = 10
    @State private var emptySlotPulse: CGFloat = 1.0
    @State private var showFantasyUnlockSheet = false
    @State private var showPrehistoricUnlockSheet = false
    @State private var showMythicUnlockSheet = false
    @State private var showOlympusUnlockSheet = false
    @State private var showAdGateFailedAlert = false
    @FocusState private var searchFocused: Bool
    @StateObject private var speech = SpeechService()

    // Cheat code: tap VS ×2 then FIGHTERS ×6
    @State private var olympusCheatStep = 0
    @State private var showOlympusReveal = false
    @State private var showEnvironmentsPackSheet = false
    @State private var lockedEnvironmentForAd: BattleEnvironment? = nil

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
            Theme.mainBg.ignoresSafeArea()
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
                            Text("Back")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("PICK YOUR")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textTertiary)
                            .tracking(2)
                        Text("FIGHTERS")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(cheat.olympusUnlocked ? Theme.olympusAccent : Theme.textPrimary)
                            .onTapGesture { handleCheatFightersTap() }
                    }

                    Spacer()

                    // Balance spacer
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("Back").font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.clear)
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
                        .foregroundColor(Theme.textTertiary)

                    TextField("Search or add any animal...", text: $viewModel.searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
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
                                .foregroundColor(Theme.textTertiary)
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
                        .fill(Theme.cardFill)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.cardBorder, lineWidth: 1))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .onChange(of: speech.transcript) { newValue in
                    guard !newValue.isEmpty else { return }
                    viewModel.searchText = newValue
                    // Stop immediately if the transcript already matches a built-in animal.
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    let matched = Animals.all.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
                    if matched { speech.stopListening() }
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

                    // Locked animal prompt
                    if let locked = viewModel.lockedAnimal {
                        HStack(spacing: 14) {
                            Text("🔒")
                                .font(.system(size: 28))
                                .frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(locked.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Text("Unlock this pack to use \(locked.name)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
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
                                .fill(Theme.cardFill)
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .stroke(Theme.purple.opacity(0.4), lineWidth: 1.5))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }

                    // Custom animal row
                    if let custom = viewModel.customAnimal {
                        Button(action: {
                            AdManager.shared.showRewardedAdForCustomCreature { granted in
                                if granted {
                                    viewModel.selectAnimal(custom)
                                } else {
                                    showAdGateFailedAlert = true
                                }
                            }
                        }) {
                            HStack(spacing: 14) {
                                Group {
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
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                                .background(Circle().fill(Color.white.opacity(0.1)))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Battle as \"\(custom.name)\"")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Custom animal")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Theme.yellow)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Theme.cardFill)
                                    .overlay(RoundedRectangle(cornerRadius: 18)
                                        .stroke(Theme.yellow.opacity(0.35), lineWidth: 1.5))
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .alert("Ad Not Available", isPresented: $showAdGateFailedAlert) {
                            Button("Remove Ads — $4.99") {
                                Task {
                                    if let product = await StoreKitManager.shared.removeAdsProduct {
                                        _ = await StoreKitManager.shared.purchase(product)
                                    }
                                }
                            }
                            Button("Restore Purchases") {
                                Task { await StoreKitManager.shared.restorePurchases() }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Watch a short ad to battle with your custom creature, or remove ads permanently for $4.99.")
                        }
                    }
                }
                .scrollDismissesKeyboard(.immediately)

                // Environment picker — between animal grid and FIGHT button
                EnvironmentPickerStrip(
                    selected: $viewModel.selectedEnvironment,
                    onLockedTap: { env in
                        HapticsService.shared.tap()
                        let settings = UserSettings.shared
                        if env.tier == .earned {
                            // Earned tier: offer to buy pack or wait
                            showEnvironmentsPackSheet = true
                        } else {
                            // Premium tier: offer watch-ad or buy pack
                            lockedEnvironmentForAd = env
                        }
                    }
                )
                .padding(.bottom, 6)

                // FIGHT button — lives below ScrollView so cards are hard-clipped at the boundary
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.clear, Theme.bgDeep],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 28)
                    .allowsHitTesting(false)

                    Button(action: {
                        if bothSelected {
                            HapticsService.shared.medium()
                            navigateToBattle = true
                        }
                    }) {
                        HStack(spacing: 12) {
                            if bothSelected {
                                Text("⚔️").font(.system(size: 22))
                                Text("FIGHT!")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("⚔️").font(.system(size: 22))
                            } else {
                                Text("Pick 2 animals to fight")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    bothSelected
                                        ? AnyShapeStyle(LinearGradient(
                                            colors: [Theme.orange, Theme.yellow],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        : AnyShapeStyle(Theme.cardFill)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22)
                                        .stroke(
                                            bothSelected ? Color.white.opacity(0.2) : Theme.cardBorder,
                                            lineWidth: 1
                                        )
                                )
                        )
                        .shadow(
                            color: bothSelected ? Theme.orange.opacity(0.6) : .clear,
                            radius: bothSelected ? fightButtonGlowRadius : 0,
                            x: 0, y: 6
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(!bothSelected)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .animation(.easeInOut(duration: 0.3), value: bothSelected)
                }
                .background(Theme.bgDeep)
            }
            } // end else
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToBattle) {
            if let f1 = viewModel.fighter1, let f2 = viewModel.fighter2 {
                BattleView(fighter1: f1, fighter2: f2, environment: viewModel.selectedEnvironment)
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
        .sheet(isPresented: $showEnvironmentsPackSheet) {
            EnvironmentsPackSheet(isPresented: $showEnvironmentsPackSheet)
        }
        .alert(
            "Unlock \(lockedEnvironmentForAd?.name ?? "Arena")",
            isPresented: Binding(
                get: { lockedEnvironmentForAd != nil },
                set: { if !$0 { lockedEnvironmentForAd = nil } }
            )
        ) {
            Button("Watch Ad — Try Once") {
                guard let env = lockedEnvironmentForAd else { return }
                AdManager.shared.showRewardedAdForCustomCreature { granted in
                    if granted {
                        viewModel.selectedEnvironment = env
                    }
                    lockedEnvironmentForAd = nil
                }
            }
            Button("Unlock All Arenas — $2.99") {
                Task {
                    if let product = await StoreKitManager.shared.environmentsPackProduct {
                        _ = await StoreKitManager.shared.purchase(product)
                    }
                    lockedEnvironmentForAd = nil
                }
            }
            Button("Cancel", role: .cancel) { lockedEnvironmentForAd = nil }
        } message: {
            if let env = lockedEnvironmentForAd {
                Text("The \(env.name) arena is a premium environment. Watch a short ad for one free battle, or unlock all 9 arenas forever for $2.99.")
            }
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
                            Text("Back").font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    VStack(spacing: 2) {
                        Text("PICK YOUR")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textTertiary).tracking(2)
                        Text("FIGHTERS")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(cheat.olympusUnlocked ? Theme.olympusAccent : Theme.textPrimary)
                            .onTapGesture { handleCheatFightersTap() }
                    }
                    Spacer()
                    // Invisible balance
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .bold))
                        Text("Back").font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.clear)
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
                        .font(.system(size: 15, weight: .medium)).foregroundColor(Theme.textTertiary)
                    TextField("Search or add any animal...", text: $viewModel.searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(Theme.textPrimary).autocorrectionDisabled()
                        .textInputAutocapitalization(.never).tint(Theme.orange)
                        .focused($searchFocused).submitLabel(.done)
                        .onSubmit { searchFocused = false }
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15)).foregroundColor(Theme.textTertiary)
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
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardFill)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder, lineWidth: 1)))
                .padding(.horizontal, 20).padding(.bottom, 12)

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
                            CategoryPill(category: category, isSelected: viewModel.selectedCategory == category, isLocked: isLocked) {
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
                    .padding(.horizontal, 20).padding(.vertical, 4)
                }
                .padding(.bottom, 12)

                Spacer()

                // Environment picker
                EnvironmentPickerStrip(selected: $viewModel.selectedEnvironment, onLockedTap: { env in
                    HapticsService.shared.tap()
                    if env.tier == .earned { showEnvironmentsPackSheet = true }
                    else { lockedEnvironmentForAd = env }
                })
                .padding(.bottom, 6)

                // Fight button
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.clear, Theme.bgDeep], startPoint: .top, endPoint: .bottom)
                        .frame(height: 20).allowsHitTesting(false)
                    Button(action: {
                        if bothSelected { HapticsService.shared.medium(); navigateToBattle = true }
                    }) {
                        HStack(spacing: 12) {
                            if bothSelected {
                                Text("⚔️").font(.system(size: 22))
                                Text("FIGHT!").font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(.white)
                                Text("⚔️").font(.system(size: 22))
                            } else {
                                Text("Pick 2 animals to fight")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 64)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(bothSelected
                                    ? AnyShapeStyle(LinearGradient(colors: [Theme.orange, Theme.yellow], startPoint: .leading, endPoint: .trailing))
                                    : AnyShapeStyle(Theme.cardFill))
                                .overlay(RoundedRectangle(cornerRadius: 22)
                                    .stroke(bothSelected ? Color.white.opacity(0.2) : Theme.cardBorder, lineWidth: 1))
                        )
                        .shadow(color: bothSelected ? Theme.orange.opacity(0.6) : .clear,
                                radius: bothSelected ? fightButtonGlowRadius : 0, x: 0, y: 6)
                    }
                    .buttonStyle(PressableButtonStyle()).disabled(!bothSelected)
                    .padding(.horizontal, 20).padding(.bottom, 32)
                    .animation(.easeInOut(duration: 0.3), value: bothSelected)
                }
                .background(Theme.bgDeep)
            }
            .frame(width: 360)
            .background(Color.black.opacity(0.12))

            // Divider
            Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)

            // ── Right animal grid ────────────────────────────────────────
            ScrollView {
                LazyVGrid(columns: landscapeGridColumns, spacing: 12) {
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
                            Text(locked.name).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Theme.textPrimary)
                            Text("Unlock this pack to use \(locked.name)").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(Theme.textSecondary)
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
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardFill)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.purple.opacity(0.4), lineWidth: 1.5)))
                    .padding(.horizontal, 20).padding(.bottom, 24)
                }

                // Custom animal row
                if let custom = viewModel.customAnimal {
                    Button(action: {
                        AdManager.shared.showRewardedAdForCustomCreature { granted in
                            if granted { viewModel.selectAnimal(custom) }
                            else { showAdGateFailedAlert = true }
                        }
                    }) {
                        HStack(spacing: 14) {
                            Group {
                                if let imageURL = viewModel.customAnimalImageURL {
                                    AsyncImage(url: imageURL) { phase in
                                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                                        else if case .failure = phase { Text(viewModel.customAnimalEmoji).font(.system(size: 28)) }
                                        else { ProgressView().tint(.white) }
                                    }
                                } else {
                                    Text(viewModel.customAnimalEmoji).font(.system(size: 28))
                                }
                            }
                            .frame(width: 48, height: 48).clipShape(Circle()).background(Circle().fill(Color.white.opacity(0.1)))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Battle as \"\(custom.name)\"").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Theme.textPrimary)
                                Text("Custom animal").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(Theme.yellow)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cardFill)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.yellow.opacity(0.35), lineWidth: 1.5)))
                        .padding(.horizontal, 20).padding(.bottom, 24)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .scrollDismissesKeyboard(.immediately)
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
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            animal != nil ? accentColor.opacity(0.7) : Theme.cardBorder,
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
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
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
                                    .foregroundColor(Theme.textTertiary)
                                    .scaleEffect(emptyPulseScale)
                                Text(label)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textTertiary)
                                    .tracking(0.5)
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
            HStack(spacing: 5) {
                Text(Theme.categoryEmoji(category))
                    .font(.system(size: 13))
                Text(Theme.categoryLabel(category))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
            Theme.mainBg.ignoresSafeArea()

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
