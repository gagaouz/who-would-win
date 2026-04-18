import SwiftUI

/// One-time Grand Champion wager screen. Player picks one fighter from the full bracket
/// and stakes coins at 5.0× multiplier. Shown once at tournament start (before Round 1 wagers).
///
/// A player can also SKIP this and not place a grand champion wager at all.
struct GrandChampionWagerView: View {
    let tournament: Tournament
    let onConfirm: (_ fighterId: String, _ amount: Int) -> Void
    let onSkip: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var coinStore = CoinStore.shared
    @State private var pickedId: String? = nil
    @State private var amount: Double = 0   // slider value

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var maxWager: Int { TournamentManager.shared.maxGrandChampionWager }
    private var minWager: Int { CoinStore.shared.tournamentGrandChampionFloor }
    private var amountInt: Int { Int(amount.rounded(.down)) }

    var body: some View {
        ZStack {
            Theme.battleBg(scheme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header

                    explainer

                    pickerGrid

                    if pickedId != nil {
                        wagerSlider
                    }

                    confirmButtons
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text("GRAND CHAMPION")
                    .font(Theme.bungee(18))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.gold, Color(hex: "#FFF59D"), Theme.gold],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .shadow(color: Theme.gold.opacity(0.6), radius: 6)
                Text("Pick the whole-tournament winner — 5.0× payout")
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.75))
            }
            Spacer()
            CoinBadge(size: .compact)
        }
    }

    private var explainer: some View {
        VStack(spacing: 6) {
            Text("🏆 High-risk, high-reward")
                .font(Theme.bungee(13))
                .foregroundColor(Theme.gold)
            Text("Pick your bet once. You can buy-out later for a smaller multiplier.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Picker grid

    private var pickerGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(tournament.bracket.allFighters) { animal in
                AnimalCard(
                    animal: animal,
                    isSelected: pickedId == animal.id,
                    isDisabled: false,
                    isLocked: false,
                    onTap: {
                        pickedId = animal.id
                        if amountInt < minWager { amount = Double(minWager) }
                    }
                )
            }
        }
    }

    // MARK: - Wager slider

    @ViewBuilder
    private var wagerSlider: some View {
        if maxWager > minWager {
            // Normal slider path — strict inequality guarantees SwiftUI Slider's
            // upperBound > lowerBound assertion holds.
            VStack(spacing: 8) {
                HStack {
                    Text("WAGER")
                        .font(Theme.bungee(12))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1.5)
                    Spacer()
                    HStack(spacing: 5) {
                        Text("\(amountInt)")
                            .font(Theme.bungee(20))
                            .foregroundColor(Theme.gold)
                        GoldCoin(size: 18)
                    }
                }
                Slider(
                    value: $amount,
                    in: Double(minWager)...Double(maxWager),
                    step: 5
                )
                .tint(Theme.gold)
                HStack {
                    Text("MIN \(minWager)")
                    Spacer()
                    Text("MAX \(maxWager) (50%)")
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
        } else if maxWager == minWager && minWager > 0 {
            // Fixed-wager path — user has exactly enough for the minimum bet.
            // Showing a Slider here would crash (zero-width range assertion).
            VStack(spacing: 8) {
                HStack {
                    Text("FIXED WAGER")
                        .font(Theme.bungee(12))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1.5)
                    Spacer()
                    HStack(spacing: 5) {
                        Text("\(minWager)")
                            .font(Theme.bungee(20))
                            .foregroundColor(Theme.gold)
                        GoldCoin(size: 18)
                    }
                }
                Text("Earn more coins to unlock variable wagers")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.18), lineWidth: 1))
            .onAppear { amount = Double(minWager) }
        } else {
            VStack(spacing: 10) {
                Text("You need at least \(minWager) coins to place a Grand Champion wager.")
                    .font(Theme.bungee(12))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 8)
                BuyCoinsButton()
            }
        }
    }

    // MARK: - Confirm buttons

    private var confirmButtons: some View {
        VStack(spacing: 10) {
            Button {
                if let id = pickedId, amountInt >= minWager, amountInt <= maxWager {
                    onConfirm(id, amountInt)
                }
            } label: {
                Text("LOCK IN (5.0× PAYOUT)")
            }
            .buttonStyle(MegaButtonStyle(color: .gold, height: 60, cornerRadius: 18, fontSize: 16))
            .disabled(pickedId == nil || amountInt < minWager || amountInt > maxWager)
            .opacity((pickedId == nil || amountInt < minWager || amountInt > maxWager) ? 0.5 : 1.0)

            Button(action: onSkip) {
                Text("SKIP — NO GRAND CHAMPION BET")
                    .font(Theme.bungee(13))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.vertical, 8)
            }
        }
    }
}
