import SwiftUI

// Legacy in-battle "you unlocked X!" banner components. The legacy BattleView
// still references these — kept as minimal stubs so the codebase compiles.
// The Kids* flow has its own celebrations and does not use these.

struct FantasyUnlockedBanner: View {
    @Binding var isShowing: Bool
    var body: some View {
        unlockBanner(emoji: "🧚", title: "FANTASY UNLOCKED!", color: Color(hex: "#7B5EA7"))
            .onAppear { autoDismiss() }
    }
    private func autoDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { isShowing = false }
        }
    }
}

struct TournamentUnlockedBanner: View {
    @Binding var isShowing: Bool
    var body: some View {
        unlockBanner(emoji: "🏆", title: "TOURNAMENT MODE!", color: Color(hex: "#FFD43B"))
            .onAppear { autoDismiss() }
    }
    private func autoDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { isShowing = false }
        }
    }
}

struct OlympusUnlockedBanner: View {
    @Binding var isShowing: Bool
    var body: some View {
        unlockBanner(emoji: "🔱", title: "OLYMPUS UNLOCKED!", color: Color(hex: "#E0B040"))
            .onAppear { autoDismiss() }
    }
    private func autoDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { isShowing = false }
        }
    }
}

// FirstCustomBanner already defined in BattleView.swift — don't redeclare here.

// MARK: - Shared banner UI (intentionally simple — the kids flow does its own thing)
@ViewBuilder
private func unlockBanner(emoji: String, title: String, color: Color) -> some View {
    HStack(spacing: 10) {
        Text(emoji).font(.system(size: 28))
        Text(title)
            .font(Theme.bungee(14))
            .foregroundColor(.white)
            .tracking(1)
    }
    .padding(.horizontal, 18).padding(.vertical, 10)
    .background(
        Capsule().fill(color)
            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 2))
    )
    .shadow(color: color.opacity(0.30), radius: 12, x: 0, y: 6)
    .transition(.scale.combined(with: .opacity))
}
