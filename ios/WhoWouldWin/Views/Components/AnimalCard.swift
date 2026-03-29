import SwiftUI

struct AnimalCard: View {
    let animal: Animal
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    private var categoryGradient: LinearGradient {
        switch animal.category {
        case .land:
            return LinearGradient(
                colors: [Color(hex: "#2D1B69"), Color(hex: "#1a1040")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sea:
            return LinearGradient(
                colors: [Color(hex: "#1E3A5F"), Color(hex: "#0d1f35")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .air:
            return LinearGradient(
                colors: [Color(hex: "#0D4F5C"), Color(hex: "#061f26")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .insect:
            return LinearGradient(
                colors: [Color(hex: "#2D4A1E"), Color(hex: "#152310")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .all:
            return LinearGradient(
                colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        Button(action: {
            if !isDisabled {
                onTap()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Text(animal.emoji)
                        .font(.system(size: 44))
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)

                    Text(animal.name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? Color(hex: "#FFD700") : .white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(categoryGradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color(hex: "#FFD700") : Color.white.opacity(0.08),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                // Selected indicator: golden checkmark + small red × to hint deselect
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#EF4444"))
                            .frame(width: 20, height: 20)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                    }
                    .offset(x: 5, y: -5)
                }
            }
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .opacity(isDisabled ? 0.4 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: 12) {
        AnimalCard(
            animal: Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4),
            isSelected: false,
            isDisabled: false,
            onTap: {}
        )
        AnimalCard(
            animal: Animal(id: "shark", name: "Great White Shark", emoji: "🦈", category: .sea, pixelColor: "#5588AA", size: 4),
            isSelected: true,
            isDisabled: false,
            onTap: {}
        )
        AnimalCard(
            animal: Animal(id: "eagle", name: "Eagle", emoji: "🦅", category: .air, pixelColor: "#8B4513", size: 2),
            isSelected: false,
            isDisabled: true,
            onTap: {}
        )
    }
    .padding()
    .background(
        LinearGradient(
            colors: [Color(hex: "#0A0A1A"), Color(hex: "#12082A"), Color(hex: "#0A1628")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
