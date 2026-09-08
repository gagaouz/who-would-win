import SwiftUI

/// A friendly, skippable "How to Play" walkthrough — an OFFER, not a forced
/// tutorial. Four swipeable cards covering the whole loop: pick fighters →
/// choose a place → cheer for your pick → see who wins and why. Reachable any
/// time from Home, and offered (never forced) on the first launch.
struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }
    @State private var page = 0

    private struct Step {
        let emoji: String
        let title: String
        let body: String
        let color: Color
    }

    private let steps: [Step] = [
        Step(emoji: "🥊", title: "1. Pick Two Fighters",
             body: "Choose any two animals to face off — a lion, a shark, even a dragon! Can't find the one you want? Tap “Make Your Own” and type ANY creature you can dream up.",
             color: Kids.sun),
        Step(emoji: "🌋", title: "2. Pick a Place (if you want!)",
             body: "Battle in the jungle, ocean, volcano and more. It matters! A shark rules the ocean but flops on land — the place can change who wins.",
             color: Kids.grass),
        Step(emoji: "👏", title: "3. Cheer For Your Pick",
             body: "As the fight builds up, tap the animal YOU think will win to cheer them on and fill their crowd meter. Picked a side? Let’s see if you called it!",
             color: Kids.pink),
        Step(emoji: "🏆", title: "4. See Who Wins — and WHY",
             body: "Watch the winner grab the crown, then read the battle story and the real reason they won. Win battles to collect stickers, trophies and new animal packs!",
             color: Kids.grape),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFE9BA"), Kids.pink.opacity(0.45), Kids.grape.opacity(0.4)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("HOW TO PLAY")
                        .font(Kids.fredoka(isIPad ? 24 : 19, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Spacer()
                    Button { dismiss() } label: {
                        Text("Skip")
                            .font(Kids.fredoka(15, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Capsule().fill(.white).overlay(Capsule().stroke(Kids.ink.opacity(0.4), lineWidth: 2)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.top, 16)

                TabView(selection: $page) {
                    ForEach(steps.indices, id: \.self) { i in
                        stepCard(steps[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxWidth: isIPad ? 560 : .infinity)

                KidButton(title: page < steps.count - 1 ? "NEXT" : "LET'S PLAY!",
                          icon: page < steps.count - 1 ? "👉" : "⚡",
                          color: Kids.grass, size: .lg) {
                    HapticsService.shared.tap()
                    if page < steps.count - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { page += 1 }
                    } else {
                        dismiss()
                    }
                }
                .padding(.horizontal, isIPad ? 120 : 32)
                .padding(.bottom, isIPad ? 30 : 22)
            }
        }
    }

    @ViewBuilder
    private func stepCard(_ s: Step) -> some View {
        VStack(spacing: isIPad ? 22 : 16) {
            Spacer()
            ZStack {
                Circle().fill(s.color)
                    .overlay(Circle().fill(Kids.sheen))
                    .overlay(Circle().stroke(Kids.ink, lineWidth: 4))
                    .frame(width: isIPad ? 180 : 140, height: isIPad ? 180 : 140)
                    .shadow(color: Kids.ink.opacity(0.12), radius: 0, x: 0, y: 6)
                Text(s.emoji).font(.system(size: isIPad ? 92 : 72))
            }
            Text(s.title)
                .font(Kids.fredoka(isIPad ? 26 : 21, weight: .bold))
                .foregroundColor(Kids.ink)
                .multilineTextAlignment(.center)
            Text(s.body)
                .font(Kids.nunito(isIPad ? 17 : 14, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, isIPad ? 30 : 26)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
