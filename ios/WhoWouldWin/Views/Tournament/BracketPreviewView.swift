import SwiftUI

/// Shows the full first-round bracket. Player can CONFIRM to advance to grand-champion
/// wagering, or RE-ROLL (if unused) to shuffle seeding for 50 coins.
struct BracketPreviewView: View {
    let tournament: Tournament
    let onConfirm: () -> Void
    let onReroll: () -> Void
    let onForfeit: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var coinStore = CoinStore.shared
    @State private var showForfeitConfirm = false
    @State private var showRerollNotAffordable = false

    private var rerollCost: Int { CoinStore.shared.tournamentBracketRerollCost }

    var body: some View {
        ZStack {
            Theme.battleBg(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — always visible, never scrolls
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                // Scrollable middle: compact matchup list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        Text("ROUND 1 MATCHUPS")
                            .font(Theme.bungee(10))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 2)

                        ForEach(tournament.bracket.rounds.first ?? []) { matchup in
                            matchupRow(matchup)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                // Action buttons — always pinned at bottom
                actionButtons
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Forfeit tournament?",
               isPresented: $showForfeitConfirm) {
            Button("Forfeit", role: .destructive) { onForfeit() }
            Button("Keep playing", role: .cancel) { }
        } message: {
            Text("Your bracket will be cleared. Already-spent coins are not refunded.")
        }
        .alert("Not enough coins",
               isPresented: $showRerollNotAffordable) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need \(rerollCost) coins to re-roll.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { showForfeitConfirm = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("\(tournament.size.rawValue)-FIGHTER BRACKET")
                    .font(Theme.bungee(18))
                    .foregroundColor(.white)
                Text("Preview & confirm")
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            CoinBadge(size: .compact)
        }
    }

    // MARK: - Matchup row (compact single-line — no wagering yet)

    private func matchupRow(_ matchup: Matchup) -> some View {
        HStack(spacing: 6) {
            AnimalAvatar(animal: matchup.fighter1, size: 22)
            Text(matchup.fighter1.name)
                .font(Theme.bungee(9))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("VS")
                .font(Theme.bungee(8))
                .foregroundColor(Theme.gold)
                .fixedSize()
            Text(matchup.fighter2.name)
                .font(Theme.bungee(9))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity, alignment: .trailing)
            AnimalAvatar(animal: matchup.fighter2, size: 22)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: onConfirm) {
                Text("LOOKS GOOD — CONTINUE")
            }
            .buttonStyle(MegaButtonStyle(color: .orange, height: 60, cornerRadius: 18, fontSize: 18))

            if !tournament.rerollUsed {
                Button {
                    if coinStore.balance >= rerollCost {
                        // TournamentManager.rerollBracket() handles the spend + ledger.
                        onReroll()
                    } else {
                        showRerollNotAffordable = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "dice.fill")
                        Text("RE-ROLL BRACKET — \(rerollCost)")
                        GoldCoin(size: 14)
                    }
                }
                .buttonStyle(MegaButtonStyle(color: .purple, height: 48, cornerRadius: 16, fontSize: 14))

                if coinStore.balance < rerollCost {
                    BuyCoinsButton()
                }
            } else {
                Text("Re-roll already used")
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}
