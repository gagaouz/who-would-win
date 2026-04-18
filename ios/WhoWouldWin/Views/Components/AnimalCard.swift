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
                // Card body — 3D embossed style
                VStack(spacing: 5) {
                    Group {
                        if let assetName = animal.creatureAssetName,
                           let img = UIImage(named: assetName) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else if animal.isCustom, let url = animal.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                default:
                                    Text(animal.emoji).font(.system(size: 36))
                                }
                            }
                            .frame(width: 44, height: 44)
                        } else {
                            Text(animal.emoji)
                                .font(.system(size: 40))
                        }
                    }
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
                    .blur(radius: isLocked ? 3 : 0)

                    Text(animal.name)
                        .font(Theme.bungee(11))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .frame(height: 28, alignment: .top)
                        .blur(radius: isLocked ? 2.5 : 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 4)
                .background(
                    ZStack {
                        // Bottom 3D edge
                        RoundedRectangle(cornerRadius: 14)
                            .fill(accentColor.opacity(0.7))
                            .offset(y: 4)

                        // Main card face
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.categoryGradient(animal.category))

                        // Dark inset — lets category color bleed through
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.65))
                            .padding(3)

                        // Top shine
                        VStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.white.opacity(0)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(height: 30)
                                .padding(.horizontal, 3)
                                .padding(.top, 2)
                            Spacer()
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? Color.white : Color.white.opacity(0.2),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .shadow(
                    color: isSelected ? accentColor.opacity(0.5) : .black.opacity(0.2),
                    radius: isSelected ? 10 : 4,
                    x: 0, y: isSelected ? 4 : 3
                )

                // Lock overlay
                if isLocked {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.45))
                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.fantasyAccent)
                                .shadow(color: Theme.fantasyAccent.opacity(0.6), radius: 4)
                            Text("LOCKED")
                                .font(.system(size: 7, weight: .black, design: .rounded))
                                .foregroundColor(Theme.fantasyAccent.opacity(0.9))
                                .tracking(1)
                        }
                    }
                }

                // Selected X badge
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
            .scaleEffect(isSelected ? 1.06 : 1.0)
            .opacity(isDisabled ? 0.32 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isDisabled)
    }
}

#Preview {
    HStack(spacing: 10) {
        AnimalCard(animal: Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4), isSelected: false, isDisabled: false, onTap: {})
        AnimalCard(animal: Animal(id: "shark", name: "Great White Shark", emoji: "🦈", category: .sea, pixelColor: "#5588AA", size: 4), isSelected: true, isDisabled: false, onTap: {})
        AnimalCard(animal: Animal(id: "eagle", name: "Bald Eagle", emoji: "🦅", category: .air, pixelColor: "#8B4513", size: 2), isSelected: false, isDisabled: true, onTap: {})
    }
    .padding()
    .background(Theme.homeBg)
}
