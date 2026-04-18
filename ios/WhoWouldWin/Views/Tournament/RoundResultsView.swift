import SwiftUI

/// Shown after every round of a tournament, breaking down the wager payouts.
/// On appear, it calls TournamentManager.resolveRoundPayouts() ONCE and displays
/// the returned breakdown.
struct RoundResultsView: View {
    let tournament: Tournament
    let roundIndex: Int
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var manager = TournamentManager.shared
    @State private var lines: [RoundPayoutLine] = []
    @State private var didResolve: Bool = false

    var body: some View {
        ZStack {
            Theme.battleBg(scheme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    GamePanel(headerText: "PAYOUTS", headerColor: .gold) {
                        if lines.isEmpty {
                            Text("No wagers this round.")
                                .font(Theme.bungee(12))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.vertical, 12)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(lines) { line in
                                    payoutRow(line)
                                }
                                Divider().overlay(Color.white.opacity(0.2))
                                roundTotalRow
                            }
                        }
                    }

                    Button(action: onContinue) {
                        Text(isFinalRound ? "SEE CHAMPION" : "NEXT ROUND")
                    }
                    .buttonStyle(MegaButtonStyle(color: .orange, height: 60, cornerRadius: 18, fontSize: 18))
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didResolve else { return }
            didResolve = true
            lines = manager.resolveRoundPayouts()
        }
    }

    // MARK: - Derived

    private var isFinalRound: Bool {
        roundIndex == tournament.size.totalRounds - 1
    }

    private var roundNetDelta: Int {
        lines.reduce(0) { $0 + $1.delta }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text("\(tournament.size.roundName(for: roundIndex).uppercased()) RESULTS")
                    .font(Theme.bungee(18))
                    .foregroundColor(.white)
                Text("Round \(roundIndex + 1) of \(tournament.size.totalRounds)")
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            CoinBadge(size: .compact)
        }
    }

    // MARK: - Payout row

    private func payoutRow(_ line: RoundPayoutLine) -> some View {
        HStack(spacing: 8) {
            Image(systemName: line.won ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(line.won ? Theme.neonGrn : Theme.red.opacity(0.85))
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 2) {
                Text("WINNER: \(line.winnerName)")
                    .font(Theme.bungee(12))
                    .foregroundColor(.white)
                if line.wagered > 0 {
                    HStack(spacing: 4) {
                        Text("Wagered \(line.wagered)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                        GoldCoin(size: 11)
                    }
                } else {
                    Text("No wager")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            Spacer()

            if line.wagered > 0 {
                HStack(spacing: 4) {
                    Text(line.delta >= 0 ? "+\(line.delta)" : "\(line.delta)")
                        .font(Theme.bungee(14))
                        .foregroundColor(line.won ? Theme.neonGrn : Theme.red.opacity(0.9))
                    GoldCoin(size: 14)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    private var roundTotalRow: some View {
        HStack {
            Text("ROUND NET")
                .font(Theme.bungee(13))
                .foregroundColor(.white.opacity(0.7))
                .tracking(1)
            Spacer()
            HStack(spacing: 4) {
                Text(roundNetDelta >= 0 ? "+\(roundNetDelta)" : "\(roundNetDelta)")
                    .font(Theme.bungee(16))
                    .foregroundColor(roundNetDelta >= 0 ? Theme.neonGrn : Theme.red.opacity(0.9))
                GoldCoin(size: 14)
            }
        }
        .padding(.top, 6)
    }
}
