import SwiftUI

/// The reveal for the once-a-day Mystery Sticker. Shows a gift that "opens" to
/// a freshly-collected creature, with confetti. A tiny daily delight that gives
/// kids a reason to come back even when they don't feel like battling.
struct MysteryStickerSheet: View {
    let animal: Animal
    @Environment(\.dismiss) private var dismiss
    @State private var opened = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Kids.grape.opacity(0.5), Kids.pink.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if opened {
                ConfettiView().ignoresSafeArea().allowsHitTesting(false)
            }

            VStack(spacing: 20) {
                Text(opened ? "NEW STICKER!" : "DAILY MYSTERY")
                    .font(Kids.fredoka(14, weight: .bold))
                    .foregroundColor(Kids.ink.opacity(0.6))
                    .tracking(1)

                if opened {
                    FighterPortrait(animal: animal, size: 170, ringColor: Kids.sun)
                        .transition(.scale.combined(with: .opacity))
                    StickerWord(text: animal.name.uppercased(), fill: Kids.sun,
                                fontSize: 30, tilt: -2)
                    Text("Added to your sticker book 📖")
                        .font(Kids.nunito(14, weight: .bold))
                        .foregroundColor(Kids.ink)
                } else {
                    Text("🎁")
                        .font(.system(size: 120))
                        .scaleEffect(opened ? 1.2 : 1)
                }

                Button {
                    if opened {
                        dismiss()
                    } else {
                        SoundService.shared.play(.win)
                        HapticsService.shared.success()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { opened = true }
                    }
                } label: {
                    Text(opened ? "YAY!" : "OPEN IT!")
                        .font(Kids.fredoka(18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40).padding(.vertical, 14)
                        .background(
                            Capsule().fill(Kids.grass)
                                .overlay(Capsule().fill(Kids.sheen))
                                .overlay(Capsule().stroke(Kids.ink, lineWidth: 3))
                        )
                        .shadow(color: Kids.ink.opacity(0.15), radius: 0, x: 0, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}
