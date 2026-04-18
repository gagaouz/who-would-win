import SwiftUI

/// Round-level wagering screen. Player may place a wager on each matchup, or tap CONTINUE
/// without wagering. Also shows the current Grand Champion and a "Buy Out" option
/// that lets the player swap their GC pick (with a lower locked multiplier) — unless
/// we are in the final round.
struct RoundWagerView: View {
    let tournament: Tournament
    let roundIndex: Int
    let onDone: () -> Void

    @Environment(\.colorScheme) private var scheme
    @ObservedObject private var coinStore = CoinStore.shared
    @ObservedObject private var manager = TournamentManager.shared
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @AppStorage("tournamentQuickMode") private var quickMode: Bool = false
    @State private var activeSheet: SheetID? = nil
    @State private var showGCSwap = false
    @State private var isBuyingCoins = false

    private enum SheetID: Identifiable {
        case matchup(UUID)
        var id: String {
            switch self {
            case .matchup(let u): return u.uuidString
            }
        }
    }

    private var round: [Matchup] {
        guard let t = manager.activeTournament,
              t.bracket.rounds.indices.contains(roundIndex) else { return [] }
        return t.bracket.rounds[roundIndex]
    }

    private var multiplier: Double {
        WagerMultipliers.matchup(for: roundIndex, in: tournament.size)
    }

    var body: some View {
        ZStack {
            Theme.battleBg(scheme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header

                    quickModeCard

                    // If the player can't afford any wagers, offer a rewarded
                    // ad so they can earn coins without leaving the tournament.
                    if coinStore.balance < coinStore.tournamentMatchupWagerFloor {
                        earnCoinsCard
                    }

                    GamePanel(headerText: tournament.size.roundName(for: roundIndex).uppercased(),
                              headerColor: .orange) {
                        VStack(spacing: 10) {
                            ForEach(round) { matchup in
                                matchupWagerRow(matchup)
                            }
                        }
                    }

                    if tournament.grandChampion != nil {
                        grandChampionCard
                    }

                    continueButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(item: $activeSheet) { id in
            switch id {
            case .matchup(let uuid):
                if let matchup = round.first(where: { $0.id == uuid }) {
                    MatchupWagerSheet(
                        matchup: matchup,
                        multiplier: multiplier,
                        onPlace: { pickedId, amount in
                            _ = manager.placeMatchupWager(
                                matchupId: uuid,
                                pickedFighterId: pickedId,
                                amount: amount
                            )
                            activeSheet = nil
                        },
                        onCancel: { activeSheet = nil }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
        }
        .sheet(isPresented: $showGCSwap) {
            GrandChampionSwapSheet(
                tournament: tournament,
                onSwap: { newId in
                    _ = manager.swapGrandChampion(toPickedFighterId: newId)
                    showGCSwap = false
                },
                onCancel: { showGCSwap = false }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: 2) {
                Text("PLACE YOUR BETS")
                    .font(Theme.bungee(18))
                    .foregroundColor(.white)
                Text("Matchup payout: \(String(format: "%.1f", multiplier))×")
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.75))
            }
            Spacer()
            CoinBadge(size: .compact)
        }
    }

    // MARK: - Quick Mode card

    /// Prominent toggle letting the player decide whether THIS round's battles
    /// run as full animated battles or instant AI quick decisions. Setting
    /// persists across rounds via @AppStorage but can be flipped before every
    /// round — so the escape hatch is always right here.
    private var quickModeCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { quickMode.toggle() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(quickMode ? Theme.gold.opacity(0.25) : Color.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                    Image(systemName: quickMode ? "bolt.fill" : "bolt")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(quickMode ? Theme.gold : .white.opacity(0.7))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(quickMode ? "QUICK MODE: ON" : "QUICK MODE: OFF")
                        .font(Theme.bungee(12))
                        .foregroundColor(quickMode ? Theme.gold : .white)
                        .tracking(1)
                    Text(quickMode
                         ? "Instant AI results — no animation"
                         : "Full animated battles")
                        .font(Theme.bungee(10))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                // Custom switch visual
                ZStack(alignment: quickMode ? .trailing : .leading) {
                    Capsule()
                        .fill(quickMode ? Theme.gold.opacity(0.6) : Color.white.opacity(0.15))
                        .frame(width: 44, height: 24)
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .padding(2)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(quickMode ? Theme.gold.opacity(0.08) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(quickMode ? Theme.gold.opacity(0.5) : Color.white.opacity(0.15),
                            lineWidth: 1.2)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Earn coins card (shown when balance < wager floor)

    private var earnCoinsCard: some View {
        let canWatch = coinStore.canWatchAdForCoins && adManager.coinAdIsReady
        let adsLeft  = coinStore.adsRemainingToday
        let coinProduct = storeKit.coins1000Product

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "coins.and.bills")
                    .foregroundColor(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NOT ENOUGH COINS TO WAGER")
                        .font(Theme.bungee(11))
                        .foregroundColor(Theme.gold)
                        .tracking(0.5)
                    Text("Watch a short ad to earn 75 coins — or buy a coin pack to wager freely.")
                        .font(Theme.bungee(11))
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Rewarded ad button
            Button {
                adManager.showRewardedAdForCoins { rewarded in
                    if rewarded { CoinStore.shared.recordAdWatched() }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                    Text(canWatch ? "WATCH AD → EARN 75" : adManager.coinAdIsReady ? "DAILY LIMIT REACHED" : "AD LOADING…")
                    if canWatch { GoldCoin(size: 14) }
                }
            }
            .buttonStyle(MegaButtonStyle(color: .green, height: 46, cornerRadius: 14, fontSize: 13))
            .disabled(!canWatch)
            .opacity(canWatch ? 1 : 0.5)

            // Buy coin pack button
            if let product = coinProduct {
                Button {
                    isBuyingCoins = true
                    Task {
                        _ = await StoreKitManager.shared.purchase(product)
                        isBuyingCoins = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bag.fill")
                        Text(isBuyingCoins ? "PURCHASING…" : "BUY 1,000 coins — \(product.displayPrice)")
                    }
                }
                .buttonStyle(MegaButtonStyle(color: .gold, height: 46, cornerRadius: 14, fontSize: 13))
                .disabled(isBuyingCoins)
                .opacity(isBuyingCoins ? 0.6 : 1)
            }

            if !coinStore.canWatchAdForCoins {
                Text("Daily ad limit reached — come back tomorrow for more free coins.")
                    .font(Theme.bungee(10))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            } else if adsLeft > 0 {
                Text("\(adsLeft) ad\(adsLeft == 1 ? "" : "s") remaining today")
                    .font(Theme.bungee(10))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.4), lineWidth: 1.2))
    }

    // MARK: - Matchup wager row

    private func matchupWagerRow(_ matchup: Matchup) -> some View {
        Button {
            if matchup.wager == nil { activeSheet = .matchup(matchup.id) }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    fighterChip(matchup.fighter1,
                                isPicked: matchup.wager?.pickedFighterId == matchup.fighter1.id)
                    VSShield(size: 30, fontSize: 10)
                    fighterChip(matchup.fighter2,
                                isPicked: matchup.wager?.pickedFighterId == matchup.fighter2.id)
                    envBadge(matchup.environment)
                }
                if let wager = matchup.wager {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Theme.gold)
                        let name = matchup.wager?.pickedFighterId == matchup.fighter1.id ? matchup.fighter1.name : matchup.fighter2.name
                        Text("\(wager.amount)")
                            .font(Theme.bungee(12))
                            .foregroundColor(Theme.gold)
                        GoldCoin(size: 12)
                        Text("on \(name)")
                            .font(Theme.bungee(12))
                            .foregroundColor(Theme.gold)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Tap to place wager (\(String(format: "%.1f", multiplier))×)")
                    }
                    .font(Theme.bungee(11))
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(matchup.wager != nil ? Theme.gold.opacity(0.7) : Color.white.opacity(0.18),
                            lineWidth: matchup.wager != nil ? 1.6 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(matchup.wager != nil)
    }

    private func fighterChip(_ a: Animal, isPicked: Bool) -> some View {
        VStack(spacing: 2) {
            AnimalAvatar(animal: a, size: 30)
            Text(a.name)
                .font(Theme.bungee(11))
                .foregroundColor(isPicked ? Theme.gold : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func envBadge(_ env: BattleEnvironment) -> some View {
        Text(env.emoji).font(.system(size: 16)).frame(width: 28)
    }

    // MARK: - Grand Champion card

    @ViewBuilder
    private var grandChampionCard: some View {
        if let gc = tournament.grandChampion,
           let pick = tournament.bracket.allFighters.first(where: { $0.id == gc.pickedFighterId }) {
            let alive = tournament.bracket.aliveFighters.contains(where: { $0.id == gc.pickedFighterId })
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    AnimalAvatar(animal: pick, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GRAND CHAMPION PICK")
                            .font(Theme.bungee(11))
                            .foregroundColor(Theme.gold)
                            .tracking(1.5)
                        Text(pick.name)
                            .font(Theme.bungee(16))
                            .foregroundColor(.white)
                        HStack(spacing: 4) {
                            Text("\(gc.amount)")
                                .font(Theme.bungee(11))
                                .foregroundColor(.white.opacity(0.7))
                            GoldCoin(size: 11)
                            Text("· \(String(format: "%.2f", gc.multiplier))×")
                                .font(Theme.bungee(11))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    if !alive {
                        Text("ELIMINATED")
                            .font(Theme.bungee(10))
                            .foregroundColor(Theme.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.red.opacity(0.2)))
                    }
                }
                if tournament.canSwapGrandChampion {
                    Button { showGCSwap = true } label: {
                        Text(alive ? "BUY OUT — SWAP PICK" : "RESCUE — PICK A SURVIVOR")
                    }
                    .buttonStyle(MegaButtonStyle(color: .purple, height: 42, cornerRadius: 14, fontSize: 12))
                } else {
                    Text("Locked for the final")
                        .font(Theme.bungee(10))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold.opacity(0.45), lineWidth: 1.2))
        }
    }

    // MARK: - Continue

    private var continueButton: some View {
        Button(action: onDone) {
            Text("START THE ROUND")
        }
        .buttonStyle(MegaButtonStyle(color: .orange, height: 60, cornerRadius: 18, fontSize: 18))
    }
}

// MARK: - Matchup wager sheet

private struct MatchupWagerSheet: View {
    let matchup: Matchup
    let multiplier: Double
    let onPlace: (_ pickedFighterId: String, _ amount: Int) -> Void
    let onCancel: () -> Void

    @ObservedObject private var coinStore = CoinStore.shared
    @State private var picked: String? = nil
    @State private var amount: Double

    init(matchup: Matchup,
         multiplier: Double,
         onPlace: @escaping (_ pickedFighterId: String, _ amount: Int) -> Void,
         onCancel: @escaping () -> Void) {
        self.matchup = matchup
        self.multiplier = multiplier
        self.onPlace = onPlace
        self.onCancel = onCancel
        // Initialize amount to the wager floor so the Slider's initial value is
        // never out of range (Slider fatal-errors on out-of-range values in iOS 17+).
        self._amount = State(initialValue: Double(CoinStore.shared.tournamentMatchupWagerFloor))
    }

    private var maxWager: Int { TournamentManager.shared.maxMatchupWager }
    private var minWager: Int { CoinStore.shared.tournamentMatchupWagerFloor }
    private var amountInt: Int { Int(amount.rounded(.down)) }

    /// Slider step sized to always fit within the wager range. iOS Slider
    /// fatal-errors in `Normalizing.init(min:max:stride:)` when the step is
    /// larger than `max - min`, so we shrink the step for small ranges.
    private var wagerStep: Double {
        let span = maxWager - minWager
        if span >= 50 { return 5 }
        if span >= 10 { return 2 }
        return 1
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("PLACE WAGER")
                .font(Theme.bungee(18))
                .foregroundColor(.white)
                .padding(.top, 18)

            HStack(spacing: 12) {
                pickButton(matchup.fighter1)
                VSShield(size: 34, fontSize: 12)
                pickButton(matchup.fighter2)
            }
            .padding(.horizontal, 16)

            if maxWager > minWager {
                VStack(spacing: 8) {
                    HStack {
                        Text("WAGER")
                            .font(Theme.bungee(11))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(amountInt)")
                                .font(Theme.bungee(18))
                                .foregroundColor(Theme.gold)
                            GoldCoin(size: 16)
                        }
                    }
                    Slider(
                        value: $amount,
                        in: Double(minWager)...Double(maxWager),
                        step: wagerStep
                    ).tint(Theme.gold)
                    HStack {
                        Text("MIN \(minWager)")
                        Spacer()
                        Text("MAX \(maxWager) (10%)")
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                    HStack(spacing: 4) {
                        Text("Payout if correct: \(Int((Double(amountInt) * multiplier).rounded(.down)))")
                            .font(Theme.bungee(12))
                            .foregroundColor(.white.opacity(0.75))
                        GoldCoin(size: 12)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
            } else if maxWager == minWager {
                // Range is a single point — Slider would crash here, so just
                // show the fixed amount and let the player confirm or cancel.
                VStack(spacing: 8) {
                    HStack {
                        Text("WAGER")
                            .font(Theme.bungee(11))
                            .foregroundColor(.white.opacity(0.6))
                            .tracking(1)
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(minWager)")
                                .font(Theme.bungee(18))
                                .foregroundColor(Theme.gold)
                            GoldCoin(size: 16)
                        }
                    }
                    Text("Minimum wager only — earn more coins to bet higher.")
                        .font(Theme.bungee(11))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 4) {
                        Text("Payout if correct: \(Int((Double(minWager) * multiplier).rounded(.down)))")
                            .font(Theme.bungee(12))
                            .foregroundColor(.white.opacity(0.75))
                        GoldCoin(size: 12)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
            } else {
                Text("Not enough coins to wager. Minimum is \(minWager).")
                    .font(Theme.bungee(12))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onCancel) { Text("CANCEL") }
                    .buttonStyle(MegaButtonStyle(color: .blue, height: 50, cornerRadius: 16, fontSize: 13))

                Button {
                    if let p = picked, amountInt >= minWager, amountInt <= maxWager {
                        onPlace(p, amountInt)
                    }
                } label: { Text("PLACE BET") }
                    .buttonStyle(MegaButtonStyle(color: .orange, height: 50, cornerRadius: 16, fontSize: 13))
                    .disabled(picked == nil || amountInt < minWager || amountInt > maxWager)
                    .opacity((picked == nil || amountInt < minWager || amountInt > maxWager) ? 0.5 : 1)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.battleBg.ignoresSafeArea())
        .onAppear {
            // Clamp amount into the current valid range — the init set it to
            // minWager, but maxWager depends on balance which can change.
            let lo = Double(minWager)
            let hi = Double(max(minWager, maxWager))
            if amount < lo || amount > hi {
                amount = lo
            }
        }
    }

    private func pickButton(_ a: Animal) -> some View {
        Button { picked = a.id } label: {
            VStack(spacing: 4) {
                AnimalAvatar(animal: a, size: 48)
                Text(a.name)
                    .font(Theme.bungee(12))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(picked == a.id ? Theme.gold.opacity(0.35) : Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(picked == a.id ? Theme.gold : Color.white.opacity(0.2),
                            lineWidth: picked == a.id ? 2 : 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Grand Champion swap sheet

private struct GrandChampionSwapSheet: View {
    let tournament: Tournament
    let onSwap: (_ newId: String) -> Void
    let onCancel: () -> Void

    @State private var picked: String? = nil

    private var newMultiplier: Double {
        let r = tournament.currentRoundIndex ?? 0
        return WagerMultipliers.grandChampion(lockedAtRoundIndex: r)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("SWAP GRAND CHAMPION")
                .font(Theme.bungee(16))
                .foregroundColor(.white)
                .padding(.top, 18)

            Text("New multiplier: \(String(format: "%.2f", newMultiplier))× · wager stays the same")
                .font(Theme.bungee(12))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(tournament.bracket.aliveFighters) { animal in
                        AnimalCard(
                            animal: animal,
                            isSelected: picked == animal.id,
                            isDisabled: false,
                            isLocked: false,
                            onTap: { picked = animal.id }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            HStack(spacing: 10) {
                Button(action: onCancel) { Text("CANCEL") }
                    .buttonStyle(MegaButtonStyle(color: .blue, height: 48, cornerRadius: 14, fontSize: 13))
                Button {
                    if let p = picked { onSwap(p) }
                } label: { Text("SWAP") }
                    .buttonStyle(MegaButtonStyle(color: .purple, height: 48, cornerRadius: 14, fontSize: 13))
                    .disabled(picked == nil)
                    .opacity(picked == nil ? 0.5 : 1)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.battleBg.ignoresSafeArea())
    }
}
