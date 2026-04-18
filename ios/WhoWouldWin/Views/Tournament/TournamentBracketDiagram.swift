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

    var body: some View {
        let content = HStack(alignment: .center, spacing: 12) {
            ForEach(Array(bracket.rounds.enumerated()), id: \.offset) { (roundIdx, round) in
                VStack(spacing: 10) {
                    Text(roundLabel(roundIdx))
                        .font(Theme.bungee(11))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(1)
                        .padding(.bottom, 2)

                    if round.isEmpty {
                        // Placeholder for unplayed future round
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
        .padding(.horizontal, 8)
        .padding(.vertical, 6)

        if scrollable {
            ScrollView(.horizontal, showsIndicators: false) { content }
        } else {
            content
        }
    }

    // MARK: - Helpers

    private func roundLabel(_ roundIdx: Int) -> String {
        let size: BracketSize
        // Derive from total rounds count (rounds array always has .totalRounds entries)
        switch bracket.rounds.count {
        case 2: size = .four
        case 3: size = .eight
        case 4: size = .sixteen
        default: size = .four
        }
        return size.roundName(for: roundIdx).uppercased()
    }

    private func placeholderCount(for roundIdx: Int) -> Int {
        // total rounds - roundIdx gives number of matches remaining (1 = final)
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
        VStack(spacing: 2) {
            fighterRow(matchup.fighter1,
                       isWinner: matchup.winningFighter?.id == matchup.fighter1.id,
                       isLoser:  matchup.losingFighter?.id == matchup.fighter1.id)
            Rectangle()
                .fill(Color.white.opacity(0.25))
                .frame(height: 0.6)
            fighterRow(matchup.fighter2,
                       isWinner: matchup.winningFighter?.id == matchup.fighter2.id,
                       isLoser:  matchup.losingFighter?.id == matchup.fighter2.id)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(width: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func fighterRow(_ animal: Animal, isWinner: Bool, isLoser: Bool) -> some View {
        HStack(spacing: 5) {
            AnimalAvatar(animal: animal, size: 20, cornerRadius: 5)
            Text(animal.name)
                .font(Theme.bungee(11))
                .foregroundColor(isLoser ? .white.opacity(0.35) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .strikethrough(isLoser)
            Spacer(minLength: 0)
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.gold)
            }
        }
    }

    private var placeholderCard: some View {
        VStack(spacing: 2) {
            HStack { Text("? ? ?").font(Theme.bungee(11)).foregroundColor(.white.opacity(0.35)); Spacer() }
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 0.6)
            HStack { Text("? ? ?").font(Theme.bungee(11)).foregroundColor(.white.opacity(0.35)); Spacer() }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(width: 120)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
    }
}
