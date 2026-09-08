import SwiftUI

/// A compact visualization of a tournament bracket.
/// Each round is a column; each matchup is a small card showing the two fighters
/// and, if resolved, the winner highlighted. Used in BracketPreviewView,
/// RoundWagerView headers, and TournamentCompleteView.
struct TournamentBracketDiagram: View {
    let bracket: Bracket
    /// Optional round index to highlight (e.g. the current round)
    var highlightedRoundIndex: Int? = nil
    /// When true, the diagram is scrollable horizontally.
    var scrollable: Bool = true

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    var body: some View {
        let content = HStack(alignment: .center, spacing: isIPad ? 18 : 12) {
            ForEach(Array(bracket.rounds.enumerated()), id: \.offset) { (roundIdx, round) in
                VStack(spacing: isIPad ? 14 : 10) {
                    Text(roundLabel(roundIdx))
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .tracking(1)
                        .padding(.horizontal, isIPad ? 12 : 8).padding(.vertical, isIPad ? 5 : 3)
                        .background(
                            Capsule().fill(Kids.sun)
                                .overlay(Capsule().stroke(Kids.ink, lineWidth: 1.5))
                        )

                    if round.isEmpty {
                        ForEach(0..<max(1, placeholderCount(for: roundIdx)), id: \.self) { _ in
                            placeholderCard
                        }
                    } else {
                        ForEach(round) { matchup in
                            matchupCard(matchup)
                        }
                    }
                }
                .opacity(highlightedRoundIndex == nil || highlightedRoundIndex == roundIdx ? 1.0 : 0.55)
            }
        }
        .padding(.horizontal, isIPad ? 14 : 8)
        .padding(.vertical, isIPad ? 10 : 6)

        if scrollable {
            ScrollView(.horizontal, showsIndicators: false) { content }
        } else {
            content
        }
    }

    // MARK: - Helpers

    private func roundLabel(_ roundIdx: Int) -> String {
        let size: BracketSize
        switch bracket.rounds.count {
        case 2: size = .four
        case 3: size = .eight
        case 4: size = .sixteen
        default: size = .four
        }
        return size.roundName(for: roundIdx).uppercased()
    }

    private func placeholderCount(for roundIdx: Int) -> Int {
        let total = bracket.rounds.count
        let remaining = total - roundIdx
        switch remaining {
        case 1: return 1
        case 2: return 2
        case 3: return 4
        case 4: return 8
        default: return 1
        }
    }

    @ViewBuilder
    private func matchupCard(_ matchup: Matchup) -> some View {
        VStack(spacing: isIPad ? 5 : 3) {
            fighterRow(matchup.fighter1,
                       isWinner: matchup.winningFighter?.id == matchup.fighter1.id,
                       isLoser:  matchup.losingFighter?.id == matchup.fighter1.id)
            Rectangle()
                .fill(Kids.ink.opacity(0.15))
                .frame(height: 1)
            fighterRow(matchup.fighter2,
                       isWinner: matchup.winningFighter?.id == matchup.fighter2.id,
                       isLoser:  matchup.losingFighter?.id == matchup.fighter2.id)
        }
        .padding(.vertical, isIPad ? 10 : 6)
        .padding(.horizontal, isIPad ? 12 : 8)
        .frame(width: isIPad ? 188 : 128)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 16 : 12, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: isIPad ? 16 : 12, style: .continuous).stroke(Kids.ink, lineWidth: 2))
        )
        .shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 2)
    }

    @ViewBuilder
    private func fighterRow(_ animal: Animal, isWinner: Bool, isLoser: Bool) -> some View {
        HStack(spacing: isIPad ? 7 : 5) {
            DiagramMini(animal: animal, isIPad: isIPad)
            Text(animal.name)
                .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                .foregroundColor(isLoser ? Kids.inkSoft.opacity(0.5) : Kids.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .strikethrough(isLoser)
            Spacer(minLength: 0)
            if isWinner {
                Text("👑")
                    .font(.system(size: isIPad ? 15 : 11))
            }
        }
    }

    private var placeholderCard: some View {
        VStack(spacing: isIPad ? 5 : 3) {
            HStack {
                Text("???").font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold)).foregroundColor(Kids.inkSoft.opacity(0.5))
                Spacer()
            }
            Rectangle().fill(Kids.ink.opacity(0.1)).frame(height: 1)
            HStack {
                Text("???").font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold)).foregroundColor(Kids.inkSoft.opacity(0.5))
                Spacer()
            }
        }
        .padding(.vertical, isIPad ? 10 : 6)
        .padding(.horizontal, isIPad ? 12 : 8)
        .frame(width: isIPad ? 188 : 128)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#F7F2FF"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Kids.ink.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        )
    }
}

private struct DiagramMini: View {
    let animal: Animal
    let isIPad: Bool
    private var bundledImage: UIImage? {
        guard let name = animal.creatureAssetName else { return nil }
        return UIImage(named: name)
    }
    var body: some View {
        let outer: CGFloat = isIPad ? 30 : 22
        let inner: CGFloat = isIPad ? 22 : 16
        ZStack {
            Circle().fill(.white)
                .overlay(Circle().stroke(Kids.ink, lineWidth: 1.5))
                .frame(width: outer, height: outer)
            Group {
                if let ui = bundledImage {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    Text(animal.emoji).font(.system(size: isIPad ? 16 : 12))
                }
            }
            .frame(width: inner, height: inner)
            .clipShape(Circle())
        }
    }
}
