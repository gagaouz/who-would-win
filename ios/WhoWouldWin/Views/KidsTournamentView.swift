import SwiftUI

// MARK: - Tournament Bracket — Animal Arena Jr.
// Matches design tournament screen — Jungle Cup bracket with WON/out cells,
// connecting lines, CHAMPION trophy slot, "Your Turn" PLAY panel.

struct KidsTournamentView: View {
    /// Eight first-round entrants, paired (0v1, 2v3, 4v5, 6v7).
    let entrants: [Animal]
    /// Indexes 0..<8 whose first-round match is decided. nil = still to play.
    /// value = the winning entrant's index, "out" = the other slot in the pair.
    let firstRoundWinners: [Int?]
    /// Index of the next match to play (the "NOW" highlight).
    let nowMatchIndex: Int
    /// Cup label and round name shown at top.
    let cupName: String
    let roundLabel: String
    let matchNumber: Int
    let matchTotal: Int
    let onPlay: () -> Void
    let onClose: () -> Void

    @State private var appeared = false
    @State private var nowPulse: CGFloat = 1
    @State private var trophySpin: Double = 0

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#3B2470"), Color(hex: "#5E3FA8")],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Confetti-ish stars in bg
            ConfettiStars()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 8) {

                    // Header
                    HStack {
                        KidIconBtn(icon: "✕", fill: .white) { onClose() }
                        Spacer()
                        VStack(spacing: 0) {
                            Text("TOURNAMENT")
                                .font(Kids.fredoka(isIPad ? 14 : 10, weight: .bold))
                                .tracking(3)
                                .foregroundColor(.white.opacity(0.7))
                            Text("\(cupName) 🏆")
                                .font(Kids.fredoka(isIPad ? 26 : 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        ZStack {
                            Circle().fill(Kids.sun)
                                .overlay(Circle().stroke(Kids.ink, lineWidth: 3))
                                .frame(width: 44, height: 44)
                            Text("🏆").font(.system(size: 22))
                        }
                        .shadow(color: Kids.ink.opacity(0.15), radius: 0, x: 0, y: 3)
                    }
                    .padding(.horizontal, 14).padding(.top, 6)

                    // Round badge
                    HStack(spacing: isIPad ? 9 : 6) {
                        Text("MATCH \(matchNumber) / \(matchTotal)")
                            .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, isIPad ? 14 : 10).padding(.vertical, isIPad ? 6 : 4)
                            .background(Capsule().fill(Kids.pink))
                        Text("\(roundLabel) 🔥")
                            .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, isIPad ? 4 : 2)

                    // Bracket
                    BracketView(
                        entrants: entrants,
                        firstRoundWinners: firstRoundWinners,
                        nowMatchIndex: nowMatchIndex,
                        nowPulse: nowPulse,
                        trophySpin: trophySpin,
                        isIPad: isIPad
                    )
                    .padding(.top, 14)
                    .padding(.horizontal, 14)

                    Spacer(minLength: 6)

                    // YOUR TURN panel
                    if nowMatchIndex < 4 {
                        YourTurnPanel(
                            a: entrants[nowMatchIndex * 2],
                            b: entrants[nowMatchIndex * 2 + 1],
                            roundLabel: roundLabel,
                            isIPad: isIPad,
                            onPlay: { HapticsService.shared.tap(); onPlay() }
                        )
                        .padding(.horizontal, 14).padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: isIPad ? 720 : .infinity)
                .scaleEffect(appeared ? 1 : 0.96)
                .opacity(appeared ? 1 : 0)
                Spacer(minLength: 0)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                nowPulse = 1.06
            }
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                trophySpin = 360
            }
        }
    }
}

// MARK: - Bracket View

private struct BracketView: View {
    let entrants: [Animal]
    let firstRoundWinners: [Int?]
    let nowMatchIndex: Int
    let nowPulse: CGFloat
    let trophySpin: Double
    let isIPad: Bool

    private let palette: [Color] = [Kids.sun, Kids.peach, Kids.sky, Kids.grape]

    var body: some View {
        HStack(alignment: .center, spacing: isIPad ? 11 : 8) {
            // Round of 8 column (left)
            VStack(spacing: isIPad ? 16 : 12) {
                ForEach(0..<4, id: \.self) { i in
                    bracketPair(matchIndex: i)
                }
            }
            .frame(maxWidth: .infinity)

            // Connectors + Round of 4 column (middle)
            VStack(spacing: isIPad ? 36 : 28) {
                ForEach(0..<2, id: \.self) { i in
                    semiSlot(roundOf4Index: i)
                }
            }
            .frame(width: isIPad ? 110 : 92)

            // Champion slot (right)
            VStack {
                ZStack {
                    Circle().fill(Kids.sun)
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 3))
                        .frame(width: isIPad ? 72 : 60, height: isIPad ? 72 : 60)
                        .shadow(color: Kids.ink.opacity(0.18), radius: 0, x: 0, y: 4)
                    Text("🏆")
                        .font(.system(size: isIPad ? 40 : 32))
                        .rotationEffect(.degrees(trophySpin / 8))
                }
                Text("CHAMPION")
                    .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: isIPad ? 84 : 70)
        }
    }

    @ViewBuilder
    private func bracketPair(matchIndex: Int) -> some View {
        let a = matchIndex * 2
        let b = matchIndex * 2 + 1
        let winnerIdx = firstRoundWinners[matchIndex]
        let isNow = nowMatchIndex == matchIndex && winnerIdx == nil

        VStack(spacing: 3) {
            cell(slot: a, matchIndex: matchIndex, winnerIdx: winnerIdx, isNow: isNow)
            Text("vs").font(Kids.fredoka(isIPad ? 10 : 8, weight: .bold)).foregroundColor(.white.opacity(0.7))
            cell(slot: b, matchIndex: matchIndex, winnerIdx: winnerIdx, isNow: isNow)
        }
        .scaleEffect(isNow ? nowPulse : 1)
        .overlay(alignment: .topTrailing) {
            if isNow {
                Text("NOW")
                    .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Kids.pink).overlay(Capsule().stroke(Kids.ink, lineWidth: 1.5)))
                    .offset(x: 4, y: -8)
            }
        }
    }

    @ViewBuilder
    private func cell(slot: Int, matchIndex: Int, winnerIdx: Int?, isNow: Bool) -> some View {
        let isWinner = winnerIdx == slot
        let isLoser  = winnerIdx != nil && winnerIdx != slot
        let baseColor = palette[matchIndex]

        HStack(spacing: 5) {
            Text(entrants[slot].emoji).font(.system(size: isIPad ? 18 : 14))
                .opacity(isLoser ? 0.4 : 1)
            if isWinner {
                Text("WON!")
                    .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                    .foregroundColor(Kids.ink)
            } else if isLoser {
                Text("out")
                    .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                    .foregroundColor(Kids.ink.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, minHeight: isIPad ? 28 : 22)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isLoser ? Color(hex: "#BFB1D6") : (isNow ? Kids.grape : baseColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Kids.ink, lineWidth: 2)
                )
        )
        .shadow(color: Kids.ink.opacity(0.11), radius: 0, x: 0, y: 2)
    }

    @ViewBuilder
    private func semiSlot(roundOf4Index: Int) -> some View {
        let leftMatch  = roundOf4Index * 2
        let rightMatch = roundOf4Index * 2 + 1
        let lW = firstRoundWinners[leftMatch]
        let rW = firstRoundWinners[rightMatch]
        VStack(spacing: 4) {
            semiCell(winnerIdx: lW)
            Text("vs").font(Kids.fredoka(isIPad ? 10 : 8, weight: .bold)).foregroundColor(.white.opacity(0.7))
            semiCell(winnerIdx: rW)
        }
    }

    @ViewBuilder
    private func semiCell(winnerIdx: Int?) -> some View {
        HStack {
            if let w = winnerIdx {
                Text(entrants[w].emoji).font(.system(size: isIPad ? 18 : 14))
            } else {
                Text("?")
                    .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                    .foregroundColor(Kids.ink.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, minHeight: isIPad ? 30 : 24)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(winnerIdx == nil ? Color(hex: "#E1D5F0") : Kids.grass)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Kids.ink, lineWidth: 2)
                )
        )
        .shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 2)
    }
}

// MARK: - Your Turn Panel

private struct YourTurnPanel: View {
    let a: Animal
    let b: Animal
    let roundLabel: String
    let isIPad: Bool
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                AnimalBubble(animal: a, size: isIPad ? 48 : 38, tint: Kids.grape, tilt: -3)
                Text("VS")
                    .font(Kids.fredoka(isIPad ? 14 : 11, weight: .bold))
                    .foregroundColor(Kids.ink)
                AnimalBubble(animal: b, size: isIPad ? 48 : 38, tint: Kids.sky, tilt: 3)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("YOUR TURN!")
                    .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                    .foregroundColor(Kids.ink)
                Text("Pick who wins \(roundLabel.lowercased())")
                    .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .lineLimit(2)
            }
            Spacer()
            KidButton(title: "PLAY", icon: nil, color: Kids.grass, size: .sm, action: onPlay)
                .frame(maxWidth: isIPad ? 100 : 84)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 3))
        )
        .shadow(color: Kids.ink.opacity(0.15), radius: 0, x: 0, y: 4)
    }
}

// MARK: - Background sparkles

private struct ConfettiStars: View {
    private let stars: [(CGFloat, CGFloat, CGFloat)] = [
        (40, 110, 8),(330, 130, 10),(60, 280, 6),(340, 320, 8),
        (30, 450, 7),(350, 480, 10),(60, 600, 6),(320, 640, 8),
    ]
    var body: some View {
        GeometryReader { _ in
            ForEach(0..<stars.count, id: \.self) { i in
                let s = stars[i]
                Text("✦")
                    .font(.system(size: s.2))
                    .foregroundColor(.white.opacity(0.5))
                    .position(x: s.0, y: s.1)
            }
        }
        .allowsHitTesting(false)
    }
}
