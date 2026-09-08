import SwiftUI

/// Shown after every round of a tournament, breaking down the wager payouts.
/// On appear, it calls TournamentManager.resolveRoundPayouts() ONCE and displays
/// the returned breakdown.
struct RoundResultsView: View {
    let tournament: Tournament
    let roundIndex: Int
    let onContinue: () -> Void

    @ObservedObject private var manager = TournamentManager.shared
    @ObservedObject private var coinStore = CoinStore.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var lines: [RoundPayoutLine] = []
    @State private var didResolve: Bool = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFE9BA"), Kids.peach.opacity(0.6), Kids.pink.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Text(settings.wageringEnabled ? "🪙" : "🏅").font(.system(size: 16))
                            Text(settings.wageringEnabled ? "PAYOUTS" : "ROUND WINNERS")
                                .font(Kids.fredoka(13, weight: .bold))
                                .tracking(1)
                                .foregroundColor(Kids.ink)
                        }
                        if lines.isEmpty {
                            Text(settings.wageringEnabled ? "No wagers this round." : "Winners advance to the next round.")
                                .font(Kids.nunito(12, weight: .bold))
                                .foregroundColor(Kids.inkSoft)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(lines) { line in
                                    payoutRow(line)
                                }
                                if settings.wageringEnabled {
                                    Rectangle()
                                        .fill(Kids.ink.opacity(0.15))
                                        .frame(height: 1)
                                    roundTotalRow
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(card)
                    .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 4)

                    KidButton(title: isFinalRound ? "SEE CHAMPION!" : "NEXT ROUND",
                              icon: isFinalRound ? "🏆" : "▶️",
                              color: Kids.grass, size: .lg) {
                        HapticsService.shared.tap()
                        onContinue()
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
                .scaleEffect(appeared ? 1 : 0.96)
                .opacity(appeared ? 1 : 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            guard !didResolve else { return }
            didResolve = true
            lines = manager.resolveRoundPayouts()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { appeared = true }
        }
    }

    private var isFinalRound: Bool {
        roundIndex == tournament.size.totalRounds - 1
    }

    private var roundNetDelta: Int {
        lines.reduce(0) { $0 + $1.delta }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Kids.ink, lineWidth: 3))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            if settings.wageringEnabled {
                HStack {
                    Spacer()
                    CoinChip(count: coinStore.balance)
                }
            }
            StickerWord(text: "\(tournament.size.roundName(for: roundIndex).uppercased()) RESULTS",
                        fill: Kids.sun, fontSize: 18, tilt: -2)
                .rotationEffect(.degrees(-2))
            Text("Round \(roundIndex + 1) of \(tournament.size.totalRounds)")
                .font(Kids.nunito(11, weight: .bold))
                .foregroundColor(Kids.ink)
        }
        .padding(.top, 6)
    }

    // MARK: - Payout row

    private func payoutRow(_ line: RoundPayoutLine) -> some View {
        // Three states: won wager (green ✓), lost wager (pink ✕), no wager (neutral 🪙)
        let hasWager = line.wagered > 0 && settings.wageringEnabled
        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(hasWager ? (line.won ? Kids.grass : Kids.pink) : Color(hex: "#E1D5F0"))
                    .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                    .frame(width: 30, height: 30)
                if hasWager {
                    Text(line.won ? "✓" : "✕")
                        .font(Kids.fredoka(14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("👑")
                        .font(.system(size: 14))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("WINNER: \(line.winnerName)")
                    .font(Kids.fredoka(12, weight: .bold))
                    .foregroundColor(Kids.ink)
                if settings.wageringEnabled {
                    if line.wagered > 0 {
                        HStack(spacing: 4) {
                            Text("Wagered \(line.wagered)")
                                .font(Kids.nunito(11, weight: .bold))
                                .foregroundColor(Kids.inkSoft)
                            KidsGoldCoin(size: 11)
                        }
                    } else {
                        Text("No wager")
                            .font(Kids.nunito(11, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                    }
                } else {
                    Text("Advances to the next round")
                        .font(Kids.nunito(11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
            }

            Spacer()

            if hasWager {
                HStack(spacing: 4) {
                    Text(line.delta >= 0 ? "+\(line.delta)" : "\(line.delta)")
                        .font(Kids.fredoka(14, weight: .bold))
                        .foregroundColor(line.won ? Kids.grass : Kids.pink)
                    KidsGoldCoin(size: 14)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#F7F2FF"))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Kids.ink.opacity(0.2), lineWidth: 1.5))
        )
    }

    private var roundTotalRow: some View {
        HStack {
            Text("ROUND NET")
                .font(Kids.fredoka(13, weight: .bold))
                .tracking(1)
                .foregroundColor(Kids.ink)
            Spacer()
            HStack(spacing: 4) {
                Text(roundNetDelta >= 0 ? "+\(roundNetDelta)" : "\(roundNetDelta)")
                    .font(Kids.fredoka(16, weight: .bold))
                    .foregroundColor(roundNetDelta >= 0 ? Kids.grass : Kids.pink)
                KidsGoldCoin(size: 14)
            }
        }
        .padding(.top, 6)
    }
}
