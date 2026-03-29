import SwiftUI

struct AnimalPickerView: View {
    @StateObject private var viewModel = AnimalPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToBattle = false
    @State private var fightButtonGlowRadius: CGFloat = 8
    @State private var emptySlotPulse: CGFloat = 1.0

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var bothSelected: Bool {
        viewModel.fighter1 != nil && viewModel.fighter2 != nil
    }

    private var appBackground: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#0A0A1A"),
                Color(hex: "#12082A"),
                Color(hex: "#0A1628")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // Custom navigation bar
                HStack(spacing: 0) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("CHOOSE YOUR FIGHTERS")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Spacer()

                    // Balance the back button width
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)

                // Fighter slots
                HStack(spacing: 0) {
                    FighterSlot(
                        animal: viewModel.fighter1,
                        emptyPulseScale: emptySlotPulse,
                        onClear: { viewModel.clear(1) }
                    )

                    // VS badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B35"), Color(hex: "#FFD700")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: Color(hex: "#FF6B35").opacity(0.5), radius: 8, x: 0, y: 2)

                        Text("VS")
                            .pixelText(size: 10, color: .white)
                    }
                    .zIndex(1)
                    .padding(.horizontal, -10)

                    FighterSlot(
                        animal: viewModel.fighter2,
                        emptyPulseScale: emptySlotPulse,
                        onClear: { viewModel.clear(2) }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))

                    TextField("Search animals...", text: $viewModel.searchText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .tint(Color(hex: "#FF6B35"))

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Category filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AnimalCategory.allCases, id: \.self) { category in
                            CategoryPill(
                                category: category,
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    viewModel.selectedCategory = category
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
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.filteredAnimals) { animal in
                            let isSelected = viewModel.fighter1?.id == animal.id || viewModel.fighter2?.id == animal.id
                            AnimalCard(
                                animal: animal,
                                isSelected: isSelected,
                                isDisabled: false
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    if isSelected {
                                        // Deselect: figure out which slot and clear it
                                        if viewModel.fighter1?.id == animal.id {
                                            viewModel.clear(1)
                                        } else if viewModel.fighter2?.id == animal.id {
                                            viewModel.clear(2)
                                        }
                                    } else {
                                        viewModel.select(animal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, viewModel.customAnimal != nil ? 8 : 120)

                    // Custom animal row — appears when search has text but no matches
                    if let custom = viewModel.customAnimal {
                        Button(action: { viewModel.selectAnimal(custom) }) {
                            HStack(spacing: 14) {
                                Group {
                                    if let imageURL = viewModel.customAnimalImageURL {
                                        AsyncImage(url: imageURL) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFill()
                                            case .failure:
                                                Text(viewModel.customAnimalEmoji)
                                                    .font(.system(size: 28))
                                            default:
                                                ProgressView()
                                                    .tint(.white)
                                            }
                                        }
                                    } else {
                                        Text(viewModel.customAnimalEmoji)
                                            .font(.system(size: 28))
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                                .background(Circle().fill(Color.white.opacity(0.1)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Battle as \"\(custom.name)\"")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("Custom animal")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Color(hex: "#FFD700"))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.07))
                                    .overlay(RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1))
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 120)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Floating FIGHT! button
            VStack {
                Spacer()

                // Fade gradient behind button
                LinearGradient(
                    colors: [Color.clear, Color(hex: "#0A0A1A").opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                .allowsHitTesting(false)

                Button(action: {
                    if bothSelected {
                        navigateToBattle = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Text("⚔️")
                            .font(.system(size: 20))
                        Text(bothSelected ? "FIGHT!" : "Pick 2 animals")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(bothSelected ? .white : .white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        Capsule()
                            .fill(
                                bothSelected
                                    ? LinearGradient(
                                        colors: [Color(hex: "#FF6B35"), Color(hex: "#FFD700")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.07)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                      )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        bothSelected ? Color.clear : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(
                        color: bothSelected ? Color(hex: "#FF6B35").opacity(0.5) : Color.clear,
                        radius: fightButtonGlowRadius,
                        x: 0, y: 4
                    )
                }
                .buttonStyle(.plain)
                .disabled(!bothSelected)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .background(Color(hex: "#0A0A1A").opacity(0.95))
                .animation(.easeInOut(duration: 0.3), value: bothSelected)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToBattle) {
            if let f1 = viewModel.fighter1, let f2 = viewModel.fighter2 {
                BattleView(fighter1: f1, fighter2: f2)
            }
        }
        .onAppear {
            startPulseAnimations()
        }
    }

    private func startPulseAnimations() {
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            emptySlotPulse = 0.7
        }

        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            fightButtonGlowRadius = 20
        }
    }
}

// MARK: - Fighter Slot

struct FighterSlot: View {
    let animal: Animal?
    let emptyPulseScale: CGFloat
    let onClear: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            animal != nil ? Color(hex: "#FFD700").opacity(0.5) : Color.white.opacity(0.12),
                            lineWidth: animal != nil ? 1.5 : 1
                        )
                )
                .frame(height: 100)
                .overlay(
                    Group {
                        if let animal = animal {
                            VStack(spacing: 5) {
                                Group {
                                    if let url = animal.imageURL {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFill()
                                            default:
                                                Text(animal.emoji).font(.system(size: 36))
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                        .clipShape(Circle())
                                    } else {
                                        Text(animal.emoji)
                                            .font(.system(size: 40))
                                    }
                                }
                                Text(animal.name)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "#FFD700"))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .padding(.horizontal, 8)
                            }
                        } else {
                            VStack(spacing: 6) {
                                Text("?")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.25))
                                    .scaleEffect(emptyPulseScale)

                                Text("Tap to pick")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                    }
                )
                // Tap the whole slot card to clear when filled
                .contentShape(Rectangle())
                .onTapGesture {
                    if animal != nil {
                        onClear()
                    }
                }

            // Red pill "REMOVE" badge at the bottom of the slot when filled
            if animal != nil {
                Button(action: onClear) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("REMOVE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#EF4444"))
                    )
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
    let onTap: () -> Void

    var label: String {
        switch category {
        case .all: return "All"
        case .land: return "Land"
        case .sea: return "Sea"
        case .air: return "Air"
        case .insect: return "Bugs"
        }
    }

    var selectedGradient: LinearGradient {
        switch category {
        case .all:
            return LinearGradient(
                colors: [Color.white.opacity(0.8), Color.white.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .land:
            return LinearGradient(
                colors: [Color(hex: "#8B5CF6"), Color(hex: "#6d28d9")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .sea:
            return LinearGradient(
                colors: [Color(hex: "#3B82F6"), Color(hex: "#1d4ed8")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .air:
            return LinearGradient(
                colors: [Color(hex: "#06B6D4"), Color(hex: "#0284c7")],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .insect:
            return LinearGradient(
                colors: [Color(hex: "#84CC16"), Color(hex: "#4d7c0f")],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var selectedTextColor: Color {
        category == .all ? Color(hex: "#0A0A1A") : .white
    }

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? selectedTextColor : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected
                                ? AnyShapeStyle(selectedGradient)
                                : AnyShapeStyle(Color.white.opacity(0.1))
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.clear : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AnimalPickerView()
    }
}
