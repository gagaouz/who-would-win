import SwiftUI

/// Lets the player hand-pick fighters for the tournament.
struct TournamentCreaturePickerView: View {
    let targetCount: Int
    let mode: SelectionMode
    let onContinue: ([Animal]) -> Void
    let onBack: () -> Void

    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coinStore = CoinStore.shared
    @StateObject private var pickerVM = AnimalPickerViewModel()
    @State private var search: String = ""
    @State private var selectedCategory: AnimalCategory = .all
    @State private var selected: [Animal] = []
    @State private var showNotAffordableAlert = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private var columns: [GridItem] {
        let count = isIPad ? 5 : 3
        let spacing: CGFloat = isIPad ? 14 : 10
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }

    var body: some View {
        ZStack {
            SkyBG(variant: .meadow)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: isIPad ? 14 : 10) {
                    header
                    searchBar
                    categoryPills
                    selectionStrip
                    gridView
                    continueBar
                }
                .padding(.horizontal, isIPad ? 24 : 14)
                .frame(maxWidth: isIPad ? 880 : .infinity)
                Spacer(minLength: 0)
            }
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
                Text("←")
                    .font(Kids.fredoka(isIPad ? 26 : 20, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .frame(width: isIPad ? 50 : 38, height: isIPad ? 50 : 38)
                    .background(Circle().fill(.white).overlay(Circle().stroke(Kids.ink, lineWidth: 2.5)))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: isIPad ? 4 : 2) {
                Text(mode == .manual ? "PICK ALL \(targetCount)" : "PICK SOME")
                    .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                    .foregroundColor(Kids.ink)
                Text(progressText)
                    .font(Kids.nunito(isIPad ? 14 : 11, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            Spacer()
            CoinChip(count: coinStore.balance)
        }
        .padding(.top, isIPad ? 14 : 8)
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
        HStack(spacing: isIPad ? 12 : 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: isIPad ? 18 : 14, weight: .semibold))
                .foregroundColor(Kids.inkSoft)
            TextField("Search or add any fighter…", text: $search)
                .font(Kids.nunito(isIPad ? 17 : 13, weight: .bold))
                .foregroundColor(Kids.ink)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: isIPad ? 18 : 14))
                        .foregroundColor(Kids.inkSoft)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, isIPad ? 16 : 12).padding(.vertical, isIPad ? 13 : 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
    }

    // MARK: - Category pills

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isIPad ? 9 : 6) {
                ForEach(availableCategories, id: \.self) { cat in
                    Button {
                        HapticsService.shared.tap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: isIPad ? 6 : 4) {
                            Text(categoryEmoji(cat)).font(.system(size: isIPad ? 18 : 14))
                            Text(categoryLabel(cat))
                                .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                                .foregroundColor(Kids.ink)
                        }
                        .padding(.horizontal, isIPad ? 14 : 10).padding(.vertical, isIPad ? 9 : 6)
                        .background(
                            Capsule().fill(selectedCategory == cat ? categoryColor(cat) : .white)
                                .overlay(selectedCategory == cat ? Capsule().fill(Kids.sheen) : nil)
                                .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
                        )
                        .offset(y: selectedCategory == cat ? -1 : 0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func categoryEmoji(_ c: AnimalCategory) -> String {
        switch c {
        case .all: return "🌈"
        case .land: return "🌳"
        case .sea: return "🌊"
        case .air: return "☁️"
        case .insect: return "🐛"
        case .pets: return "🐶"
        case .farm: return "🚜"
        case .prehistoric: return "🦖"
        case .fantasy: return "🐉"
        case .mythic: return "🔱"
        case .olympus: return "⚡"
        }
    }
    private func categoryLabel(_ c: AnimalCategory) -> String {
        switch c {
        case .all: return "All"
        case .land: return "Land"
        case .sea: return "Sea"
        case .air: return "Air"
        case .insect: return "Bugs"
        case .pets: return "Pets"
        case .farm: return "Farm"
        case .prehistoric: return "Dinos"
        case .fantasy: return "Fantasy"
        case .mythic: return "Mythic"
        case .olympus: return "Olympus"
        }
    }
    private func categoryColor(_ c: AnimalCategory) -> Color {
        switch c {
        case .all: return Kids.pink
        case .land: return Kids.grass
        case .sea: return Kids.sky
        case .air: return Kids.grape
        case .insect: return Kids.peach
        case .pets: return Color(hex: "#F4B6C2")
        case .farm: return Color(hex: "#E8B96E")
        case .prehistoric: return Kids.sun
        case .fantasy: return Kids.grape
        case .mythic: return Kids.sunDeep
        case .olympus: return Kids.sun
        }
    }

    // MARK: - Selection strip

    @ViewBuilder
    private var selectionStrip: some View {
        if !selected.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: isIPad ? 11 : 8) {
                    ForEach(selected) { animal in
                        Button { toggle(animal) } label: {
                            HStack(spacing: isIPad ? 7 : 5) {
                                Text(animal.emoji).font(.system(size: isIPad ? 19 : 14))
                                Text(animal.name)
                                    .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                                    .foregroundColor(Kids.ink)
                                Text("✕")
                                    .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                                    .foregroundColor(Kids.ink.opacity(0.5))
                            }
                            .padding(.vertical, isIPad ? 7 : 5).padding(.horizontal, isIPad ? 13 : 10)
                            .background(
                                Capsule().fill(Kids.sun)
                                    .overlay(Capsule().stroke(Kids.ink, lineWidth: 1.5))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Grid

    private var gridView: some View {
        ScrollView {
            VStack(spacing: isIPad ? 16 : 12) {
                if !filteredAnimals.isEmpty {
                    LazyVGrid(columns: columns, spacing: isIPad ? 14 : 10) {
                        if search.trimmingCharacters(in: .whitespaces).isEmpty {
                            surpriseCard
                        }
                        ForEach(filteredAnimals, id: \.id) { animal in
                            TournamentPickCard(
                                animal: animal,
                                selected: selected.contains(where: { $0.id == animal.id }),
                                disabled: selected.count >= targetCount && !selected.contains(where: { $0.id == animal.id }),
                                isIPad: isIPad
                            ) {
                                HapticsService.shared.tap()
                                toggle(animal)
                            }
                        }
                    }
                    .padding(.horizontal, isIPad ? 6 : 4)
                }

                if filteredAnimals.isEmpty, let custom = pickerVM.customAnimal {
                    customFighterCard(custom)
                }
            }
            .padding(.vertical, 4)
        }
        .clipped()
    }

    private var surpriseCard: some View {
        Button {
            HapticsService.shared.medium()
            if let pick = randomUnlockedPick() {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) {
                    toggle(pick)
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Kids.grape)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Kids.sheen))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                    .aspectRatio(1, contentMode: .fit)
                VStack(spacing: isIPad ? 4 : 2) {
                    Text("🎲").font(.system(size: isIPad ? 56 : 38))
                    Text("SURPRISE!")
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            .shadow(color: Kids.ink.opacity(0.09), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom fighter card

    @ViewBuilder
    private func customFighterCard(_ animal: Animal) -> some View {
        let cost = CoinStore.shared.customCreatureCost
        let canAfford = coinStore.canAfford(cost)
        let alreadyPicked = selected.contains(where: { $0.id == animal.id })
        let slotsFull = selected.count >= targetCount && !alreadyPicked

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Group {
                    if let url = pickerVM.customAnimalImageURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Text(pickerVM.customAnimalEmoji).font(.system(size: 28))
                            }
                        }
                    } else {
                        Text(pickerVM.customAnimalEmoji).font(.system(size: 28))
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add \"\(animal.name)\"")
                        .font(Kids.fredoka(14, weight: .bold))
                        .foregroundColor(Kids.ink)
                    HStack(spacing: 4) {
                        Text("Custom fighter")
                            .font(Kids.nunito(11, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                        Text("· \(cost)")
                            .font(Kids.fredoka(11, weight: .bold))
                            .foregroundColor(Kids.ink)
                        KidsGoldCoin(size: 12)
                    }
                }
                Spacer()
            }

            if alreadyPicked {
                Button { toggle(animal) } label: {
                    Text("✓ Added — tap to remove")
                        .font(Kids.fredoka(13, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Kids.grass)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2))
                        )
                }
                .buttonStyle(.plain)
            } else if slotsFull {
                Text("Bracket full — remove a fighter first")
                    .font(Kids.fredoka(11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .frame(maxWidth: .infinity)
            } else {
                Button {
                    if coinStore.spend(cost) {
                        toggle(animal)
                        search = ""
                    } else {
                        showNotAffordableAlert = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        KidsGoldCoin(size: 16)
                        Text("Add for \(cost) coins")
                            .font(Kids.fredoka(13, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(canAfford ? Kids.sun : Color(hex: "#E8DFF5"))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    )
                    .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
                    .opacity(canAfford ? 1.0 : 0.6)
                }
                .buttonStyle(.plain)
                .disabled(!canAfford)

                if !canAfford {
                    BuyCoinsButton()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.sun, lineWidth: 3))
        )
        .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
    }

    // MARK: - Continue bar

    private var continueBar: some View {
        KidButton(
            title: mode == .manual ? "ROLL BRACKET (\(selected.count)/\(targetCount))" : "ROLL BRACKET",
            icon: "🎲",
            color: continueEnabled ? Kids.grass : Color(hex: "#CDC3E0"),
            size: .lg
        ) {
            HapticsService.shared.tap()
            onContinue(selected)
        }
        .disabled(!continueEnabled)
        .opacity(continueEnabled ? 1.0 : 0.55)
        .padding(.bottom, 8)
    }

    private var continueEnabled: Bool {
        switch mode {
        case .manual: return selected.count == targetCount
        case .hybrid: return selected.count >= 1 && selected.count < targetCount
        case .random: return false
        }
    }

    private var availableCategories: [AnimalCategory] {
        var cats: [AnimalCategory] = [.all, .land, .sea, .air, .insect, .pets, .farm]
        if settings.isPrehistoricUnlocked { cats.append(.prehistoric) }
        if settings.isFantasyUnlocked     { cats.append(.fantasy) }
        if settings.isMythicUnlocked      { cats.append(.mythic) }
        if settings.isOlympusUnlocked     { cats.append(.olympus) }
        return cats
    }

    private var unlockedAnimals: [Animal] {
        Animals.all.filter { animal in
            switch animal.category {
            case .all, .land, .sea, .air, .insect, .pets, .farm: return true
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

    private func randomUnlockedPick() -> Animal? {
        if selected.count >= targetCount { return nil }
        let pool = filteredAnimals.filter { animal in
            !selected.contains(where: { $0.id == animal.id })
        }
        return pool.randomElement()
    }

    private func toggle(_ animal: Animal) {
        if let idx = selected.firstIndex(where: { $0.id == animal.id }) {
            selected.remove(at: idx)
        } else {
            if selected.count >= targetCount { return }
            selected.append(animal)
        }
    }
}

// MARK: - Pick card

private struct TournamentPickCard: View {
    let animal: Animal
    let selected: Bool
    let disabled: Bool
    let isIPad: Bool
    let onTap: () -> Void

    private var bundledImage: UIImage? {
        guard let name = animal.creatureAssetName else { return nil }
        return UIImage(named: name)
    }

    private var cardColor: Color {
        switch animal.category {
        case .land: return Kids.grass
        case .sea: return Kids.sky
        case .air: return Kids.grape
        case .insect: return Kids.peach
        case .pets: return Color(hex: "#F4B6C2")
        case .farm: return Color(hex: "#E8B96E")
        case .prehistoric: return Kids.sun
        case .fantasy: return Kids.grape
        case .mythic: return Kids.pink
        case .olympus: return Kids.sunDeep
        case .all: return Kids.pink
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? cardColor : .white)
                    .overlay(selected ? RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Kids.sheen) : nil)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    .aspectRatio(1, contentMode: .fit)

                VStack(spacing: isIPad ? 4 : 2) {
                    if let ui = bundledImage {
                        Image(uiImage: ui).resizable().scaledToFit().frame(width: isIPad ? 72 : 50, height: isIPad ? 72 : 50)
                    } else {
                        Text(animal.emoji).font(.system(size: isIPad ? 50 : 34))
                    }
                    Text(animal.name)
                        .font(Kids.fredoka(isIPad ? 14 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.65)
                        .padding(.horizontal, isIPad ? 6 : 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selected {
                    Circle().fill(Kids.grass)
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                        .frame(width: isIPad ? 30 : 22, height: isIPad ? 30 : 22)
                        .overlay(Text("✓").font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold)).foregroundColor(Kids.ink))
                        .offset(x: isIPad ? 6 : 4, y: isIPad ? -8 : -6)
                }
            }
            .rotationEffect(.degrees(selected ? -1.5 : 0))
            .offset(y: selected ? -2 : 0)
            .opacity(disabled ? 0.4 : 1.0)
            .shadow(color: Kids.ink.opacity(selected ? 0.16 : 0.08), radius: 0, x: 0, y: selected ? 3 : 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
