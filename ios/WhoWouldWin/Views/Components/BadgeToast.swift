import SwiftUI

/// A celebratory "NEW BADGE!" pill that drops in from the top, holds, and slides
/// back out. Used on the battle result screen to surface a just-earned
/// achievement WHERE it's earned (instead of it only appearing silently in Game
/// Center). Pair with `AchievementFeed.popNext()`.
struct BadgeToast: View {
    let title: String          // e.g. "First Fight"
    var emoji: String = "🏅"
    var kicker: String = "NEW BADGE!"   // also used for "NEW STICKER!"
    var fill: Color = Kids.sun
    var onDismiss: () -> Void

    @State private var shown = false

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 26))
            VStack(alignment: .leading, spacing: 1) {
                Text(kicker)
                    .font(Kids.fredoka(11, weight: .bold))
                    .foregroundColor(Kids.ink.opacity(0.55))
                Text(title)
                    .font(Kids.fredoka(16, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(
            Capsule().fill(fill)
                .overlay(Capsule().stroke(Kids.ink, lineWidth: 3))
        )
        .shadow(color: Kids.ink.opacity(0.18), radius: 0, x: 0, y: 5)
        .scaleEffect(shown ? 1 : 0.6)
        .offset(y: shown ? 0 : -90)
        .opacity(shown ? 1 : 0)
        .onAppear {
            SoundService.shared.play(.badge)
            HapticsService.shared.success()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { shown = true }
            // Auto-dismiss after a beat so it doesn't cover the result.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeIn(duration: 0.3)) { shown = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDismiss() }
            }
        }
    }
}
