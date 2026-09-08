import SwiftUI

/// One-time Grand Champion wager screen. Player picks one fighter from the full bracket
/// and stakes coins at 5.0× multiplier. Shown once at tournament start (before Round 1 wagers).
struct GrandChampionWagerView: View {
    let tournament: Tournament
    let onConfirm: (_ fighterId: String, _ amount: Int) -> Void
    let onSkip: () -> Void

    @ObservedObject private var coinStore = CoinStore.shared
    @State private var pickedId: String? = nil
    @State private var amount: Double = 0
    @State private var appeared = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: isIPad ? 14 : 10), count: isIPad ? 4 : 3)
    }
    private var maxWager: Int { TournamentManager.shared.maxGrandChampionWager }
    private var minWager: Int { CoinStore.shared.tournamentGrandChampionFloor }
    private var amountInt: Int { Int(amount.rounded(.down)) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFE9BA"), Kids.sun.opacity(0.5), Kids.peach.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: isIPad ? 20 : 14) {
                        header
                        explainer
                        pickerGrid
                        if pickedId != nil { wagerSlider }
                        confirmButtons
                    }
                    .padding(.horizontal, isIPad ? 24 : 16)
                    .padding(.top, isIPad ? 18 : 12)
                    .padding(.bottom, isIPad ? 40 : 28)
                    .frame(maxWidth: isIPad ? 720 : .infinity)
                    .scaleEffect(appeared ? 1 : 0.96)
                    .opacity(appeared ? 1 : 0)
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: isIPad ? 6 : 4) {
                StickerWord(text: "GRAND CHAMPION", fill: Kids.sun, fontSize: isIPad ? 28 : 20, tilt: -2)
                Text("Pick the winner — 5.0× payout")
                    .font(Kids.nunito(isIPad ? 15 : 11, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            Spacer()
            CoinChip(count: coinStore.balance)
        }
    }

    private var explainer: some View {
        VStack(spacing: isIPad ? 6 : 4) {
            HStack(spacing: isIPad ? 9 : 6) {
                Text("🏆").font(.system(size: isIPad ? 22 : 16))
                Text("High-risk, high-reward")
                    .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            Text("Pick once. You can buy-out later for a smaller multiplier.")
                .font(Kids.nunito(isIPad ? 15 : 11, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, isIPad ? 14 : 10).padding(.horizontal, isIPad ? 20 : 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Kids.sun, lineWidth: 2.5))
        )
        .shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 3)
    }

    private var pickerGrid: some View {
        LazyVGrid(columns: columns, spacing: isIPad ? 14 : 10) {
            ForEach(tournament.bracket.allFighters) { animal in
                GrandPickCard(animal: animal, selected: pickedId == animal.id, isIPad: isIPad) {
                    HapticsService.shared.tap()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                        pickedId = animal.id
                    }
                    if amountInt < minWager { amount = Double(minWager) }
                }
            }
        }
    }

    @ViewBuilder
    private var wagerSlider: some View {
        if maxWager > minWager {
            VStack(spacing: isIPad ? 12 : 8) {
                HStack {
                    Text("YOUR WAGER")
                        .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                    Spacer()
                    HStack(spacing: isIPad ? 7 : 5) {
                        Text("\(amountInt)")
                            .font(Kids.fredoka(isIPad ? 26 : 20, weight: .bold))
                            .foregroundColor(Kids.ink)
                        KidsGoldCoin(size: isIPad ? 24 : 18)
                    }
                }
                Slider(value: $amount, in: Double(minWager)...Double(maxWager), step: 5)
                    .tint(Kids.sun)
                HStack {
                    Text("MIN \(minWager)")
                    Spacer()
                    Text("MAX \(maxWager) (50%)")
                }
                .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                .foregroundColor(Kids.inkSoft)
            }
            .padding(isIPad ? 20 : 14)
            .background(card)
            .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
        } else if maxWager == minWager && minWager > 0 {
            VStack(spacing: isIPad ? 9 : 6) {
                HStack {
                    Text("FIXED WAGER")
                        .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                    Spacer()
                    HStack(spacing: isIPad ? 7 : 5) {
                        Text("\(minWager)")
                            .font(Kids.fredoka(isIPad ? 26 : 20, weight: .bold))
                            .foregroundColor(Kids.ink)
                        KidsGoldCoin(size: isIPad ? 24 : 18)
                    }
                }
                Text("Earn more coins to unlock variable wagers")
                    .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
            .padding(isIPad ? 20 : 14)
            .background(card)
            .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
            .onAppear { amount = Double(minWager) }
        } else {
            VStack(spacing: isIPad ? 14 : 10) {
                Text("You need at least \(minWager) coins to place a Grand Champion wager.")
                    .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, isIPad ? 12 : 8)
                BuyCoinsButton()
            }
        }
    }

    private var confirmButtons: some View {
        VStack(spacing: isIPad ? 9 : 6) {
            KidButton(title: "LOCK IN (5.0× PAYOUT)", icon: "🏆",
                      color: Kids.grass, size: .lg) {
                if let id = pickedId, amountInt >= minWager, amountInt <= maxWager {
                    HapticsService.shared.tap()
                    onConfirm(id, amountInt)
                }
            }
            .disabled(pickedId == nil || amountInt < minWager || amountInt > maxWager)
            .opacity((pickedId == nil || amountInt < minWager || amountInt > maxWager) ? 0.55 : 1.0)

            Button(action: onSkip) {
                Text("Skip — no grand champion bet")
                    .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .padding(.vertical, isIPad ? 12 : 8)
                    .underline()
            }
            .buttonStyle(.plain)
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
    }
}

// MARK: - Pick card

private struct GrandPickCard: View {
    let animal: Animal
    let selected: Bool
    let isIPad: Bool
    let onTap: () -> Void

    private var bundledImage: UIImage? {
        guard let name = animal.creatureAssetName else { return nil }
        return UIImage(named: name)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Kids.sun : Color.white)
                    .overlay(selected ? RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Kids.sheen) : nil)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Kids.ink, lineWidth: selected ? 3 : 2.5)
                    )
                    .aspectRatio(1, contentMode: .fit)

                VStack(spacing: isIPad ? 4 : 2) {
                    if let ui = bundledImage {
                        Image(uiImage: ui).resizable().scaledToFit().frame(width: isIPad ? 68 : 50, height: isIPad ? 68 : 50)
                    } else {
                        Text(animal.emoji).font(.system(size: isIPad ? 46 : 34))
                    }
                    Text(animal.name)
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.65)
                        .padding(.horizontal, isIPad ? 6 : 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selected {
                    Circle().fill(Kids.grass)
                        .overlay(Circle().stroke(Kids.ink, lineWidth: 2))
                        .frame(width: isIPad ? 32 : 24, height: isIPad ? 32 : 24)
                        .overlay(Text("✓").font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold)).foregroundColor(Kids.ink))
                        .offset(x: 4, y: -6)
                }
            }
            .rotationEffect(.degrees(selected ? -2 : 0))
            .shadow(color: Kids.ink.opacity(selected ? 0.18 : 0.08), radius: 0, x: 0, y: selected ? 3 : 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
        }
        .buttonStyle(.plain)
    }
}
