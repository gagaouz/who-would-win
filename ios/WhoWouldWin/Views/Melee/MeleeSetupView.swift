import SwiftUI

/// Team builder for Melee mode. Pick fighters for Team A and Team B, then FIGHT.
struct MeleeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared

    @State private var teamA: [Animal] = []
    @State private var teamB: [Animal] = []
    @State private var teamSizeA: Int = 2
    @State private var teamSizeB: Int = 2
    @State private var activeTeam: MeleeResult.Team = .A
    @State private var search: String = ""
    @State private var selectedCategory: AnimalCategory = .all
    @State private var goToBattle = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private let maxPerTeam = 4

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
                    presetRow
                    teamPanels
                    activeTeamPills
                    categoryPills
                    gridView
                    fightBar
                }
                .padding(.horizontal, isIPad ? 24 : 14)
                .frame(maxWidth: isIPad ? 880 : .infinity)
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $goToBattle) {
            MeleeBattleView(teamA: teamA, teamB: teamB)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Text("←")
                    .font(Kids.fredoka(isIPad ? 26 : 20, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .frame(width: isIPad ? 50 : 38, height: isIPad ? 50 : 38)
                    .background(Circle().fill(.white).overlay(Circle().stroke(Kids.ink, lineWidth: 2.5)))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("BUILD YOUR TEAMS")
                .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                .foregroundColor(Kids.ink)
            Spacer()
            CoinChip(count: coins.balance)
        }
        .padding(.top, isIPad ? 14 : 8)
    }

    // MARK: - Team-size steppers (independent 1–4 per side, so 2v1, 3v2, 4v1 etc. all work)

    private var presetRow: some View {
        HStack(spacing: isIPad ? 14 : 10) {
            sizeStepper(team: .A, color: Kids.sun)
            Text("vs")
                .font(Kids.fredoka(isIPad ? 18 : 14, weight: .bold))
                .foregroundColor(Kids.ink.opacity(0.65))
            sizeStepper(team: .B, color: Kids.pink)
        }
    }

    private func sizeStepper(team: MeleeResult.Team, color: Color) -> some View {
        let size = team == .A ? teamSizeA : teamSizeB
        let label = team == .A ? "TEAM A" : "TEAM B"
        return HStack(spacing: isIPad ? 10 : 7) {
            stepperButton(symbol: "−", disabled: size <= 1) {
                changeSize(team: team, by: -1)
            }
            VStack(spacing: 0) {
                Text(label)
                    .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Kids.ink.opacity(0.6))
                Text("\(size)")
                    .font(Kids.fredoka(isIPad ? 26 : 22, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            .frame(minWidth: isIPad ? 56 : 44)
            stepperButton(symbol: "+", disabled: size >= 4) {
                changeSize(team: team, by: +1)
            }
        }
        .padding(.horizontal, isIPad ? 10 : 8)
        .padding(.vertical, isIPad ? 6 : 4)
        .background(
            Capsule().fill(color.opacity(0.35))
                .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
        )
    }

    private func stepperButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { HapticsService.shared.tap(); action() }) {
            Text(symbol)
                .font(Kids.fredoka(isIPad ? 22 : 18, weight: .bold))
                .foregroundColor(Kids.ink)
                .frame(width: isIPad ? 34 : 28, height: isIPad ? 34 : 28)
                .background(
                    Circle().fill(.white)
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }

    private func changeSize(team: MeleeResult.Team, by delta: Int) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            if team == .A {
                let next = max(1, min(4, teamSizeA + delta))
                teamSizeA = next
                if teamA.count > next {
                    // Stepping down removes already-picked fighters — give a
                    // warning buzz so the removal doesn't feel like a glitch.
                    HapticsService.shared.warning()
                    teamA = Array(teamA.prefix(next))
                }
            } else {
                let next = max(1, min(4, teamSizeB + delta))
                teamSizeB = next
                if teamB.count > next {
                    HapticsService.shared.warning()
                    teamB = Array(teamB.prefix(next))
                }
            }
        }
    }

    // MARK: - Team panels (with current rosters)

    @ViewBuilder
    private var teamPanels: some View {
        if isIPad {
            HStack(alignment: .top, spacing: 12) {
                teamPanel(.A)
                teamPanel(.B)
            }
        } else {
            VStack(spacing: 10) {
                teamPanel(.A)
                teamPanel(.B)
            }
        }
    }

    private func teamPanel(_ team: MeleeResult.Team) -> some View {
        let roster = team == .A ? teamA : teamB
        let size = team == .A ? teamSizeA : teamSizeB
        let tint = team == .A ? Kids.sun : Kids.pink

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TEAM \(team.rawValue)")
                    .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(tint).overlay(Capsule().stroke(Kids.ink, lineWidth: 2)))
                Spacer()
                Text("\(roster.count) / \(size)")
                    .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }

            if roster.isEmpty {
                Text("Tap fighters below to add")
                    .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: isIPad ? 8 : 6) {
                        ForEach(roster) { animal in
                            Button { remove(animal, from: team) } label: {
                                HStack(spacing: isIPad ? 6 : 4) {
                                    Text(animal.emoji).font(.system(size: isIPad ? 18 : 14))
                                    Text(animal.name)
                                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                                        .foregroundColor(Kids.ink)
                                    Text("✕")
                                        .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                                        .foregroundColor(Kids.ink.opacity(0.5))
                                }
                                .padding(.vertical, isIPad ? 6 : 4)
                                .padding(.horizontal, isIPad ? 10 : 8)
                                .background(
                                    Capsule().fill(tint)
                                        .overlay(Capsule().stroke(Kids.ink, lineWidth: 1.5))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(isIPad ? 12 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
    }

    // MARK: - Active-team toggle

    private var activeTeamPills: some View {
        HStack(spacing: isIPad ? 10 : 6) {
            Text("Picking for:")
                .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                .foregroundColor(Kids.inkSoft)
            activeTeamPill(.A, tint: Kids.sun)
            activeTeamPill(.B, tint: Kids.pink)
            Spacer()
        }
    }

    private func activeTeamPill(_ team: MeleeResult.Team, tint: Color) -> some View {
        let selected = activeTeam == team
        return Button {
            HapticsService.shared.tap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                activeTeam = team
            }
        } label: {
            Text("TEAM \(team.rawValue)")
                .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                .foregroundColor(Kids.ink)
                .padding(.horizontal, isIPad ? 14 : 10).padding(.vertical, isIPad ? 8 : 5)
                .background(
                    Capsule().fill(selected ? tint : .white)
                        .overlay(selected ? Capsule().fill(Kids.sheen) : nil)
                        .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
                )
                .offset(y: selected ? -1 : 0)
        }
        .buttonStyle(.plain)
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

    // MARK: - Fighter grid

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: isIPad ? 14 : 10) {
                ForEach(filteredAnimals, id: \.id) { animal in
                    MeleePickCard(
                        animal: animal,
                        inActive: activeRoster.contains(where: { $0.id == animal.id }),
                        inOther: otherRoster.contains(where: { $0.id == animal.id }),
                        disabled: activeRoster.count >= activeTeamSize && !activeRoster.contains(where: { $0.id == animal.id }),
                        activeTint: activeTeam == .A ? Kids.sun : Kids.pink,
                        isIPad: isIPad
                    ) {
                        HapticsService.shared.tap()
                        toggle(animal)
                    }
                }
            }
            .padding(.horizontal, isIPad ? 6 : 4)
            .padding(.vertical, 4)
        }
        .clipped()
    }

    // MARK: - FIGHT bar

    private var fightBar: some View {
        KidButton(
            title: "FIGHT!",
            icon: "⚔️",
            color: canFight ? Kids.grass : Color(hex: "#CDC3E0"),
            size: .lg
        ) {
            HapticsService.shared.tap()
            goToBattle = true
        }
        .disabled(!canFight)
        .opacity(canFight ? 1.0 : 0.55)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    private var activeRoster: [Animal] { activeTeam == .A ? teamA : teamB }
    private var otherRoster:  [Animal] { activeTeam == .A ? teamB : teamA }
    private var activeTeamSize: Int { activeTeam == .A ? teamSizeA : teamSizeB }

    private var canFight: Bool {
        teamA.count >= 1 && teamB.count >= 1
    }

    private func toggle(_ animal: Animal) {
        if activeTeam == .A {
            if let idx = teamA.firstIndex(where: { $0.id == animal.id }) {
                teamA.remove(at: idx)
            } else {
                guard teamA.count < teamSizeA else { return }
                // Disallow same fighter on both teams
                if teamB.contains(where: { $0.id == animal.id }) { return }
                teamA.append(animal)
            }
        } else {
            if let idx = teamB.firstIndex(where: { $0.id == animal.id }) {
                teamB.remove(at: idx)
            } else {
                guard teamB.count < teamSizeB else { return }
                if teamA.contains(where: { $0.id == animal.id }) { return }
                teamB.append(animal)
            }
        }
    }

    private func remove(_ animal: Animal, from team: MeleeResult.Team) {
        if team == .A { teamA.removeAll { $0.id == animal.id } }
        else          { teamB.removeAll { $0.id == animal.id } }
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
}

// MARK: - Pick card (team-aware)

private struct MeleePickCard: View {
    let animal: Animal
    let inActive: Bool
    let inOther: Bool
    let disabled: Bool
    let activeTint: Color
    let isIPad: Bool
    let onTap: () -> Void

    private var bundledImage: UIImage? {
        guard let name = animal.creatureAssetName else { return nil }
        return UIImage(named: name)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(inActive ? activeTint : .white)
                    .overlay(inActive ? RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Kids.sheen) : nil)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    .aspectRatio(1, contentMode: .fit)

                VStack(spacing: isIPad ? 4 : 2) {
                    if let ui = bundledImage {
                        Image(uiImage: ui).resizable().scaledToFit()
                            .frame(width: isIPad ? 72 : 50, height: isIPad ? 72 : 50)
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

                if inActive {
                    Circle().fill(Kids.grass)
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                        .frame(width: isIPad ? 30 : 22, height: isIPad ? 30 : 22)
                        .overlay(Text("✓").font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold)).foregroundColor(Kids.ink))
                        .offset(x: isIPad ? 6 : 4, y: isIPad ? -8 : -6)
                } else if inOther {
                    // Indicate fighter is on the other team
                    Circle().fill(Kids.pink)
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                        .frame(width: isIPad ? 30 : 22, height: isIPad ? 30 : 22)
                        .overlay(Text("✕").font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold)).foregroundColor(Kids.ink))
                        .offset(x: isIPad ? 6 : 4, y: isIPad ? -8 : -6)
                }
            }
            .rotationEffect(.degrees(inActive ? -1.5 : 0))
            .offset(y: inActive ? -2 : 0)
            .opacity(disabled || inOther ? 0.45 : 1.0)
            .shadow(color: Kids.ink.opacity(inActive ? 0.16 : 0.08), radius: 0, x: 0, y: inActive ? 3 : 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: inActive)
        }
        .buttonStyle(.plain)
        .disabled(disabled || inOther)
    }
}
