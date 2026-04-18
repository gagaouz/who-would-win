import SwiftUI

/// Lets the player hand-pick fighters for the tournament.
///
/// - `.manual` mode: player must select exactly `targetCount` fighters, then CONTINUE is enabled.
/// - `.hybrid` mode: player may select 1..<targetCount fighters; the remainder will be auto-filled
///                   when the tournament is created.
///
/// On CONTINUE, passes the picked animals out to the parent which calls
/// `TournamentManager.startNew(size:selectionMode:manualPicks:)`.
struct TournamentCreaturePickerView: View {
    let targetCount: Int
    let mode: SelectionMode    // .manual or .hybrid
    let onContinue: ([Animal]) -> Void
    let onBack: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coinStore = CoinStore.shared
    @StateObject private var pickerVM = AnimalPickerViewModel()
    @State private var search: String = ""
    @State private var selectedCategory: AnimalCategory = .all
    @State private var selected: [Animal] = []
    @State private var showNotAffordableAlert = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            Theme.battleBg(scheme).ignoresSafeArea()

            VStack(spacing: 12) {
                header
                searchBar
                categoryPills
                selectionStrip
                gridView
                continueBar
            }
            .padding(.horizontal, 16)
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: search) { newValue in
            pickerVM.searchText = newValue
        }
        .alert("Not Enough Coins", isPresented: $showNotAffordableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You need \(CoinStore.shared.customCreatureCost) coins to add a custom fighter.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Spacer()
            VStack(spacing: 2) {
                Text(mode == .manual ? "PICK ALL \(targetCount)" : "PICK SOME")
                    .font(Theme.bungee(18))
                    .foregroundColor(.white)
                Text(progressText)
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.75))
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 8)
    }

    private var progressText: String {
        switch mode {
        case .manual: return "\(selected.count) / \(targetCount)"
        case .hybrid: return "\(selected.count) picked — rest random"
        case .random: return ""
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField("Search or add any fighter…", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundColor(.white)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories, id: \.self) { cat in
                    Button { selectedCategory = cat } label: {
                        HStack(spacing: 5) {
                            Text(Theme.categoryEmoji(cat))
                            Text(Theme.categoryLabel(cat).uppercased())
                                .font(Theme.bungee(11))
                                .tracking(1)
                        }
                        .foregroundColor(selectedCategory == cat ? .white : .white.opacity(0.6))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(selectedCategory == cat
                                      ? Theme.categoryAccent(cat).opacity(0.45)
                                      : Color.white.opacity(0.08))
                        )
                        .overlay(
                            Capsule().stroke(
                                selectedCategory == cat ? Theme.categoryAccent(cat) : Color.white.opacity(0.15),
                                lineWidth: selectedCategory == cat ? 1.8 : 1
                            )
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Selection strip (shows picked fighters)

    @ViewBuilder
    private var selectionStrip: some View {
        if !selected.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(selected) { animal in
                        Button { toggle(animal) } label: {
                            HStack(spacing: 6) {
                                AnimalAvatar(animal: animal, size: 20, cornerRadius: 5)
                                Text(animal.name)
                                    .font(Theme.bungee(12))
                                    .foregroundColor(.white)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule().fill(Theme.gold.opacity(0.35))
                            )
                            .overlay(Capsule().stroke(Theme.gold, lineWidth: 1.2))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Grid

    private var gridView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !filteredAnimals.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        // Random pick — first cell when browsing (hidden during active search)
                        if search.trimmingCharacters(in: .whitespaces).isEmpty {
                            RandomPickCard {
                                if let pick = randomUnlockedPick() {
                                    toggle(pick)
                                }
                            }
                        }
                        ForEach(filteredAnimals, id: \.id) { animal in
                            AnimalCard(
                                animal: animal,
                                isSelected: selected.contains(where: { $0.id == animal.id }),
                                isDisabled: selected.count >= targetCount
                                    && !selected.contains(where: { $0.id == animal.id }),
                                isLocked: false,
                                onTap: { toggle(animal) }
                            )
                        }
                    }
                    .padding(.horizontal, 4) // prevents scale/badge visual bleed at grid edges
                }

                // Custom fighter — when search has no built-in matches
                if filteredAnimals.isEmpty, let custom = pickerVM.customAnimal {
                    customFighterCard(custom)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .clipped() // clips scaleEffect(1.06) overflow from selected cards
    }

    // MARK: - Custom fighter card

    @ViewBuilder
    private func customFighterCard(_ animal: Animal) -> some View {
        let cost = CoinStore.shared.customCreatureCost
        let canAfford = coinStore.canAfford(cost)
        let alreadyPicked = selected.contains(where: { $0.id == animal.id })
        let slotsFull = selected.count >= targetCount && !alreadyPicked

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Group {
                    if let url = pickerVM.customAnimalImageURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase { img.resizable().scaledToFill() }
                            else { Text(pickerVM.customAnimalEmoji).font(.system(size: 28)) }
                        }
                    } else {
                        Text(pickerVM.customAnimalEmoji).font(.system(size: 28))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .background(Circle().fill(Color.white.opacity(0.1)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Add \"\(animal.name)\"")
                        .font(Theme.bungee(14))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Text("Custom fighter · \(cost)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                        GoldCoin(size: 12)
                    }
                }
                Spacer()
            }

            if alreadyPicked {
                Button { toggle(animal) } label: {
                    Text("✓ Added — tap to remove")
                        .font(Theme.bungee(12))
                        .foregroundColor(Theme.gold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.15)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
            } else if slotsFull {
                Text("Bracket full — remove a fighter first")
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    if coinStore.spend(cost) {
                        toggle(animal)
                        // Clear the search box as visual confirmation that the custom
                        // fighter was successfully added to the bracket.
                        search = ""
                    } else {
                        showNotAffordableAlert = true
                    }
                } label: {
                    let btnBg: AnyShapeStyle = canAfford
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.gold.opacity(0.4), Theme.gold.opacity(0.2)],
                                                       startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.white.opacity(0.07))
                    let btnStroke: Color = canAfford ? Theme.gold.opacity(0.5) : Color.white.opacity(0.15)
                    HStack(spacing: 8) {
                        GoldCoin(size: 18)
                        Text("Add for \(cost) coins")
                            .font(Theme.bungee(14))
                            .foregroundColor(canAfford ? .white : .white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(btnBg))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(btnStroke, lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(!canAfford)

                if !canAfford {
                    BuyCoinsButton()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1))
        )
    }

    // MARK: - Continue bar

    private var continueBar: some View {
        VStack(spacing: 6) {
            Button {
                onContinue(selected)
            } label: {
                Text(mode == .manual ? "ROLL BRACKET (\(selected.count)/\(targetCount))" : "ROLL BRACKET")
            }
            .buttonStyle(MegaButtonStyle(
                color: continueEnabled ? .orange : .blue,
                height: 62, cornerRadius: 20, fontSize: 18
            ))
            .disabled(!continueEnabled)
            .opacity(continueEnabled ? 1.0 : 0.5)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Derived

    private var continueEnabled: Bool {
        switch mode {
        case .manual: return selected.count == targetCount
        case .hybrid: return selected.count >= 1 && selected.count < targetCount
        case .random: return false
        }
    }

    private var availableCategories: [AnimalCategory] {
        var cats: [AnimalCategory] = [.all, .land, .sea, .air, .insect]
        if settings.isPrehistoricUnlocked { cats.append(.prehistoric) }
        if settings.isFantasyUnlocked     { cats.append(.fantasy) }
        if settings.isMythicUnlocked      { cats.append(.mythic) }
        if settings.isOlympusUnlocked     { cats.append(.olympus) }
        return cats
    }

    private var unlockedAnimals: [Animal] {
        Animals.all.filter { animal in
            switch animal.category {
            case .all, .land, .sea, .air, .insect: return true
            case .prehistoric: return settings.isPrehistoricUnlocked
            case .fantasy:     return settings.isFantasyUnlocked
            case .mythic:      return settings.isMythicUnlocked
            case .olympus:     return settings.isOlympusUnlocked
            }
        }
    }

    private var filteredAnimals: [Animal] {
        var list = unlockedAnimals
        if selectedCategory != .all {
            list = list.filter { $0.category == selectedCategory }
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.name.lowercased().contains(q) }
        }
        return list
    }

    // MARK: - Random pick

    /// Random element from the currently-visible unlocked animals that
    /// aren't already in the selected bracket, and with room to add.
    private func randomUnlockedPick() -> Animal? {
        // Respect the bracket size — don't add if already full
        if selected.count >= targetCount { return nil }
        let pool = filteredAnimals.filter { animal in
            !selected.contains(where: { $0.id == animal.id })
        }
        return pool.randomElement()
    }

    // MARK: - Actions

    private func toggle(_ animal: Animal) {
        if let idx = selected.firstIndex(where: { $0.id == animal.id }) {
            selected.remove(at: idx)
        } else {
            if mode == .manual && selected.count >= targetCount { return }
            if selected.count >= targetCount { return } // hybrid too
            selected.append(animal)
        }
    }
}
