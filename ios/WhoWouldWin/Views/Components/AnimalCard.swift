import SwiftUI

struct AnimalCard: View {
    let animal: Animal
    let isSelected: Bool
    let isDisabled: Bool
    var isLocked: Bool = false
    let onTap: () -> Void

    private var accentColor: Color { Theme.categoryAccent(animal.category) }

    var body: some View {
        Button(action: {
            if !isDisabled { onTap() }
        }) {
            ZStack(alignment: .topTrailing) {
                // Card body
                VStack(spacing: 5) {
                    Text(animal.emoji)
                        .font(.system(size: 40))
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                        .blur(radius: isLocked ? 3 : 0)

                    Text(animal.name)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? accentColor : .white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .blur(radius: isLocked ? 2.5 : 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.categoryGradient(animal.category))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? accentColor : Color.white.opacity(0.09),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
                .shadow(
                    color: isSelected ? accentColor.opacity(0.35) : .black.opacity(0.25),
                    radius: isSelected ? 8 : 3,
                    x: 0, y: isSelected ? 4 : 2
                )

                // Lock overlay for fantasy animals
                if isLocked {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.45))
                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.fantasyAccent)
                                .shadow(color: Theme.fantasyAccent.opacity(0.6), radius: 4, x: 0, y: 0)
                            Text("LOCKED")
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .foregroundColor(Theme.fantasyAccent.opacity(0.9))
                                .tracking(1)
                        }
                    }
                }

                // Selected ✕ badge — top-right
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Theme.red)
                            .frame(width: 20, height: 20)
                            .shadow(color: Theme.red.opacity(0.5), radius: 3, x: 0, y: 1)
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(.white)
                    }
                    .offset(x: 5, y: -5)
                }
            }
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .opacity(isDisabled ? 0.32 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: 10) {
        AnimalCard(animal: Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4), isSelected: false, isDisabled: false, onTap: {})
        AnimalCard(animal: Animal(id: "shark", name: "Great White Shark", emoji: "🦈", category: .sea, pixelColor: "#5588AA", size: 4), isSelected: true, isDisabled: false, onTap: {})
        AnimalCard(animal: Animal(id: "eagle", name: "Bald Eagle", emoji: "🦅", category: .air, pixelColor: "#8B4513", size: 2), isSelected: false, isDisabled: true, onTap: {})
    }
    .padding()
    .background(Theme.mainBg)
}
