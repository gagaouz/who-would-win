import SwiftUI

struct AnimalPickerView: View {
    @StateObject private var viewModel = AnimalPickerViewModel()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = UserSettings.shared

    @State private var navigateToBattle = false
    @State private var fightButtonGlowRadius: CGFloat = 10
    @State private var emptySlotPulse: CGFloat = 1.0
    @State private var showFantasyUnlockSheet = false
    @FocusState private var searchFocused: Bool
    @StateObject private var speech = SpeechService()

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var bothSelected: Bool {
        viewModel.fighter1 != nil && viewModel.fighter2 != nil
    }

    var body: some View {
        ZStack {
            Theme.mainBg.ignoresSafeArea()
            StarFieldOverlay().ignoresSafeArea().allowsHitTesting(false)

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
                        .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("PICK YOUR")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(2)
                        Text("FIGHTERS")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
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

                    // VS badge — sits between slots, no overlap
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Theme.orange, Theme.yellow],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 42, height: 42)
                            .shadow(color: Theme.orange.opacity(0.55), radius: 8, x: 0, y: 3)
                        Text("VS")
                            .pixelText(size: 10, color: .white)
                    }
                    .fixedSize()

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
                        .foregroundColor(.white.opacity(0.4))

                    TextField("Search or add any animal...", text: $viewModel.searchText)
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
                                .foregroundColor(.white.opacity(0.4))
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
                        .fill(Color.white.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .onChange(of: speech.transcript) { newValue in
                    if !newValue.isEmpty { viewModel.searchText = newValue }
                }

                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AnimalCategory.allCases, id: \.self) { category in
                            CategoryPill(
                                category: category,
                                isSelected: viewModel.selectedCategory == category,
                                isLocked: category == .fantasy && !settings.isFantasyUnlocked
                            ) {
                                if category == .fantasy && !settings.isFantasyUnlocked {
                                    HapticsService.shared.tap()
                                    showFantasyUnlockSheet = true
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

                // Animal grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.filteredAnimals) { animal in
                            let isSelected = viewModel.fighter1?.id == animal.id || viewModel.fighter2?.id == animal.id
                            let isAnimalLocked = animal.category == .fantasy && !settings.isFantasyUnlocked
                            AnimalCard(
                                animal: animal,
                                isSelected: isSelected,
                                isDisabled: false,
                                isLocked: isAnimalLocked
                            ) {
                                if isAnimalLocked {
                                    HapticsService.shared.tap()
                                    showFantasyUnlockSheet = true
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
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, viewModel.customAnimal != nil ? 8 : 185)

                    // Custom animal row
                    if let custom = viewModel.customAnimal {
                        Button(action: { viewModel.selectAnimal(custom) }) {
                            HStack(spacing: 14) {
                                Group {
                                    if let imageURL = viewModel.customAnimalImageURL {
                                        AsyncImage(url: imageURL) { phase in
                                            switch phase {
                                            case .success(let img): img.resizable().scaledToFill()
                                            case .failure: Text(viewModel.customAnimalEmoji).font(.system(size: 28))
                                            default: ProgressView().tint(.white)
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
                                        .foregroundColor(.white)
                                    Text("Custom animal")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Theme.yellow)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white.opacity(0.07))
                                    .overlay(RoundedRectangle(cornerRadius: 18)
                                        .stroke(Theme.yellow.opacity(0.35), lineWidth: 1.5))
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 130)
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .scrollDismissesKeyboard(.immediately)
            }

            // Floating FIGHT button
            VStack {
                Spacer()

                LinearGradient(
                    colors: [Color.clear, Theme.bgDeep.opacity(0.97)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 70)
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
                                .foregroundColor(.white.opacity(0.35))
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
                                    : AnyShapeStyle(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(
                                        bothSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1),
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
                .background(Theme.bgDeep.opacity(0.97))
                .animation(.easeInOut(duration: 0.3), value: bothSelected)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToBattle) {
            if let f1 = viewModel.fighter1, let f2 = viewModel.fighter2 {
                BattleView(fighter1: f1, fighter2: f2)
            }
        }
        .sheet(isPresented: $showFantasyUnlockSheet) {
            FantasyUnlockSheet(isPresented: $showFantasyUnlockSheet)
        }
        .onAppear { startPulseAnimations() }
    }

    private func startPulseAnimations() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            emptySlotPulse = 0.72
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            fightButtonGlowRadius = 22
        }
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
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            animal != nil ? accentColor.opacity(0.7) : Color.white.opacity(0.14),
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
                                    if let url = animal.imageURL {
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
                                    .foregroundColor(.white.opacity(0.2))
                                    .scaleEffect(emptyPulseScale)
                                Text(label)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.3))
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
        }
    }

    private var textColor: Color {
        category == .all && isSelected ? Color(hex: "#0E0B22") : .white
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text(Theme.categoryEmoji(category))
                    .font(.system(size: 13))
                Text(Theme.categoryLabel(category))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? textColor : .white.opacity(0.7))
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.fantasyAccent.opacity(0.8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(selectedGradient) : AnyShapeStyle(Color.white.opacity(0.1)))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isLocked
                            ? Theme.fantasyAccent.opacity(0.4)
                            : (isSelected ? Color.clear : Color.white.opacity(0.12)),
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

#Preview {
    NavigationStack {
        AnimalPickerView()
    }
}
