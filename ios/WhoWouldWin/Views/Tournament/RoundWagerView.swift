import SwiftUI

/// Round-level wagering screen. Restyled for Animal Arena Jr.
struct RoundWagerView: View {
    let tournament: Tournament
    let roundIndex: Int
    let onDone: () -> Void

    @ObservedObject private var coinStore = CoinStore.shared
    @ObservedObject private var manager = TournamentManager.shared
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @AppStorage("tournamentQuickMode") private var quickMode: Bool = false
    @State private var activeSheet: SheetID? = nil
    @State private var showGCSwap = false
    @State private var isBuyingCoins = false
    @State private var appeared = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private enum SheetID: Identifiable {
        case matchup(UUID)
        var id: String { switch self { case .matchup(let u): return u.uuidString } }
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
            SkyBG()

            ScrollView {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(spacing: isIPad ? 20 : 14) {
                        header
                        quickModeCard
                        if coinStore.balance < coinStore.tournamentMatchupWagerFloor {
                            earnCoinsCard
                        }
                        matchupsCard
                        if tournament.grandChampion != nil {
                            grandChampionCard
                        }
                        continueButton
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
        .sheet(item: $activeSheet) { id in
            switch id {
            case .matchup(let uuid):
                if let matchup = round.first(where: { $0.id == uuid }) {
                    MatchupWagerSheet(
                        matchup: matchup,
                        multiplier: multiplier,
                        onPlace: { pickedId, amount in
                            _ = manager.placeMatchupWager(matchupId: uuid,
                                                         pickedFighterId: pickedId,
                                                         amount: amount)
                            activeSheet = nil
                        },
                        onCancel: { activeSheet = nil }
                    )
                    // On iPad, `.medium` is a tiny form sheet that clips content
                    // (sticker title cut, "Place Bet" button squashed). Force
                    // `.large` only on iPad; keep both detents on phone where
                    // `.medium` is a reasonable half-height.
                    .presentationDetents(isIPad ? [.large] : [.medium, .large])
                    .presentationDragIndicator(.visible)
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
            .presentationDetents(isIPad ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            VStack(spacing: isIPad ? 6 : 4) {
                StickerWord(text: "PLACE YOUR BETS", fill: Kids.sun, fontSize: isIPad ? 26 : 18, tilt: -2)
                Text("Matchup payout: \(String(format: "%.1f", multiplier))×")
                    .font(Kids.nunito(isIPad ? 15 : 11, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            Spacer()
            CoinChip(count: coinStore.balance)
        }
    }

    // MARK: - Quick Mode

    private var quickModeCard: some View {
        Button {
            HapticsService.shared.tap()
            withAnimation(.easeInOut(duration: 0.2)) { quickMode.toggle() }
        } label: {
            HStack(spacing: isIPad ? 14 : 10) {
                ZStack {
                    RetroPanelShape(cornerRadius: 12, style: .continuous)
                        .fill(quickMode ? Kids.sun : Kids.panel)
                        .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                        .frame(width: isIPad ? 60 : 44, height: isIPad ? 60 : 44)
                    Text(quickMode ? "⚡" : "🐢").font(.system(size: isIPad ? 30 : 22))
                }
                VStack(alignment: .leading, spacing: isIPad ? 4 : 2) {
                    Text(quickMode ? "QUICK MODE: ON" : "QUICK MODE: OFF")
                        .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                    Text(quickMode ? "Instant results — no animation" : "Full animated battles")
                        .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                Spacer()
                KidToggle(isOn: Binding(get: { quickMode }, set: { quickMode = $0 }))
            }
            .padding(.horizontal, isIPad ? 18 : 12).padding(.vertical, isIPad ? 14 : 10)
            .background(card)
            .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Earn coins

    private var earnCoinsCard: some View {
        let canWatch = coinStore.canWatchAdForCoins && adManager.coinAdIsReady
        let adsLeft  = coinStore.adsRemainingToday
        let coinProduct = storeKit.coins1000Product

        return VStack(spacing: isIPad ? 12 : 8) {
            HStack(spacing: isIPad ? 12 : 8) {
                KidsGoldCoin(size: isIPad ? 32 : 24)
                VStack(alignment: .leading, spacing: isIPad ? 4 : 2) {
                    Text("NEED COINS TO WAGER")
                        .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(Kids.ink)
                    Text("Watch a quick ad to earn 75 coins — or buy a coin pack.")
                        .font(Kids.nunito(isIPad ? 15 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Button {
                adManager.showRewardedAdForCoins { rewarded in
                    if rewarded { CoinStore.shared.recordAdWatched() }
                }
            } label: {
                HStack(spacing: isIPad ? 9 : 6) {
                    Image(systemName: "play.rectangle.fill").font(.system(size: isIPad ? 16 : 12))
                    Text(canWatch ? "WATCH AD → EARN 75"
                                  : adManager.coinAdIsReady ? "DAILY LIMIT REACHED" : "AD LOADING…")
                        .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                        .foregroundColor(Kids.ink)
                    if canWatch { KidsGoldCoin(size: isIPad ? 20 : 14) }
                }
                .frame(maxWidth: .infinity, minHeight: isIPad ? 56 : 42)
                .background(
                    RetroPanelShape(cornerRadius: 14, style: .continuous)
                        .fill(Kids.grass)
                        .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canWatch)
            .opacity(canWatch ? 1 : 0.55)

            if let product = coinProduct {
                Button {
                    isBuyingCoins = true
                    Task {
                        _ = await StoreKitManager.shared.purchase(product)
                        isBuyingCoins = false
                    }
                } label: {
                    HStack(spacing: isIPad ? 9 : 6) {
                        KidsGoldCoin(size: isIPad ? 20 : 14)
                        Text(isBuyingCoins ? "PURCHASING…" : "BUY 1,000 — \(product.displayPrice)")
                            .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                    .frame(maxWidth: .infinity, minHeight: isIPad ? 56 : 42)
                    .background(
                        RetroPanelShape(cornerRadius: 14, style: .continuous)
                            .fill(Kids.sun)
                            .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isBuyingCoins)
                .opacity(isBuyingCoins ? 0.6 : 1)
            }

            if !coinStore.canWatchAdForCoins {
                Text("Daily ad limit reached — come back tomorrow.")
                    .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .multilineTextAlignment(.center)
            } else if adsLeft > 0 {
                Text("\(adsLeft) ad\(adsLeft == 1 ? "" : "s") remaining today")
                    .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            }
        }
        .padding(isIPad ? 18 : 12)
        .background(
            RetroPanelShape(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.sun, lineWidth: 2.5))
        )
        .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 3)
    }

    // MARK: - Matchups card

    private var matchupsCard: some View {
        VStack(alignment: .leading, spacing: isIPad ? 14 : 10) {
            HStack(spacing: isIPad ? 9 : 6) {
                RetroSymbol("⚔️", size: isIPad ? 22 : 16)
                Text(tournament.size.roundName(for: roundIndex).uppercased())
                    .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Kids.ink)
                Spacer()
            }
            ForEach(round) { matchup in
                matchupWagerRow(matchup)
            }
        }
        .padding(isIPad ? 20 : 14)
        .background(card)
        .compositingGroup().shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 4)
    }

    private func matchupWagerRow(_ matchup: Matchup) -> some View {
        Button {
            if matchup.wager == nil { activeSheet = .matchup(matchup.id) }
        } label: {
            VStack(spacing: isIPad ? 12 : 8) {
                HStack(spacing: isIPad ? 9 : 6) {
                    fighterChip(matchup.fighter1,
                                isPicked: matchup.wager?.pickedFighterId == matchup.fighter1.id)
                    StarSticker(text: "VS", size: isIPad ? 44 : 32, fill: Kids.pink)
                    fighterChip(matchup.fighter2,
                                isPicked: matchup.wager?.pickedFighterId == matchup.fighter2.id)
                    // Quick mode ignores arenas entirely — showing the matchup's
                    // (inert) arena taught kids to wager coins on an advantage
                    // that never applies. Only show it when effects are real.
                    if !quickMode {
                        RetroSymbol(matchup.environment.emoji, size: isIPad ? 24 : 18)
                    }
                }
                if let wager = matchup.wager {
                    HStack(spacing: isIPad ? 9 : 6) {
                        Text("✓")
                            .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: isIPad ? 24 : 18, height: isIPad ? 24 : 18)
                            .background(RetroPanelShape().fill(Kids.grass).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5)))
                        let name = matchup.wager?.pickedFighterId == matchup.fighter1.id ? matchup.fighter1.name : matchup.fighter2.name
                        Text("\(wager.amount)")
                            .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                            .foregroundColor(Kids.ink)
                        KidsGoldCoin(size: isIPad ? 16 : 12)
                        Text("on \(name)")
                            .font(Kids.nunito(isIPad ? 16 : 12, weight: .bold))
                            .foregroundColor(Kids.ink)
                    }
                } else {
                    HStack(spacing: isIPad ? 7 : 5) {
                        RetroSymbol("➕", size: isIPad ? 16 : 12)
                        Text("Tap to place wager (\(String(format: "%.1f", multiplier))×)")
                            .font(Kids.nunito(isIPad ? 15 : 11, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                    }
                }
            }
            .padding(.vertical, isIPad ? 12 : 8).padding(.horizontal, isIPad ? 12 : 8)
            .background(
                RetroPanelShape(cornerRadius: 14, style: .continuous)
                    .fill(matchup.wager != nil ? Kids.sun.opacity(0.2) : Kids.panel)
                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous)
                        .stroke(matchup.wager != nil ? Kids.sun : Kids.ink.opacity(0.2),
                                lineWidth: matchup.wager != nil ? 2 : 1.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(matchup.wager != nil)
    }

    private func fighterChip(_ a: Animal, isPicked: Bool) -> some View {
        VStack(spacing: isIPad ? 4 : 2) {
            TournyFighterMini(animal: a, size: isIPad ? 50 : 36)
            Text(a.name)
                .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                .foregroundColor(isPicked ? Kids.ink : Kids.ink.opacity(0.8))
                .lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grand Champion card

    @ViewBuilder
    private var grandChampionCard: some View {
        if let gc = tournament.grandChampion,
           let pick = tournament.bracket.allFighters.first(where: { $0.id == gc.pickedFighterId }) {
            let alive = tournament.bracket.aliveFighters.contains(where: { $0.id == gc.pickedFighterId })
            VStack(spacing: isIPad ? 14 : 10) {
                HStack(spacing: isIPad ? 14 : 10) {
                    TournyFighterMini(animal: pick, size: isIPad ? 60 : 44)
                    VStack(alignment: .leading, spacing: isIPad ? 4 : 2) {
                        Text("👑 GRAND CHAMPION PICK")
                            .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(Kids.ink)
                        Text(pick.name)
                            .font(Kids.fredoka(isIPad ? 22 : 16, weight: .bold))
                            .foregroundColor(Kids.ink)
                        HStack(spacing: isIPad ? 6 : 4) {
                            Text("\(gc.amount)")
                                .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                                .foregroundColor(Kids.ink)
                            KidsGoldCoin(size: isIPad ? 15 : 11)
                            Text("· \(String(format: "%.2f", gc.multiplier))×")
                                .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                                .foregroundColor(Kids.inkSoft)
                        }
                    }
                    Spacer()
                    if !alive {
                        Text("OUT")
                            .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, isIPad ? 12 : 8).padding(.vertical, isIPad ? 6 : 4)
                            .background(RetroPanelShape().fill(Kids.pink).overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5)))
                    }
                }
                if tournament.canSwapGrandChampion {
                    Button {
                        HapticsService.shared.tap()
                        showGCSwap = true
                    } label: {
                        Text(alive ? "BUY OUT — SWAP PICK" : "RESCUE — PICK A SURVIVOR")
                            .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                            .foregroundColor(Kids.ink)
                            .frame(maxWidth: .infinity, minHeight: isIPad ? 54 : 40)
                            .background(
                                RetroPanelShape(cornerRadius: 12, style: .continuous)
                                    .fill(Kids.grape)
                                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).fill(Kids.sheen))
                                    .overlay(RetroPanelShape(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2))
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Locked for the final")
                        .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
            }
            .padding(isIPad ? 18 : 12)
            .background(
                RetroPanelShape(cornerRadius: 16, style: .continuous)
                    .fill(.white)
                    .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.sun, lineWidth: 2.5))
            )
            .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 3)
        }
    }

    // MARK: - Continue

    private var continueButton: some View {
        KidButton(title: "START THE ROUND", icon: "▶️", color: Kids.grass, size: .lg) {
            HapticsService.shared.tap()
            onDone()
        }
    }

    private var card: some View {
        RetroPanelShape(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
    }
}

// MARK: - Mini avatar shared across this file

private struct TournyFighterMini: View {
    let animal: Animal
    var size: CGFloat = 36
    var body: some View {
        AnimalBubble(animal: animal, size: size, tint: Kids.sun)
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

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    init(matchup: Matchup, multiplier: Double,
         onPlace: @escaping (_ pickedFighterId: String, _ amount: Int) -> Void,
         onCancel: @escaping () -> Void) {
        self.matchup = matchup
        self.multiplier = multiplier
        self.onPlace = onPlace
        self.onCancel = onCancel
        self._amount = State(initialValue: Double(CoinStore.shared.tournamentMatchupWagerFloor))
    }

    private var maxWager: Int { TournamentManager.shared.maxMatchupWager }
    private var minWager: Int { CoinStore.shared.tournamentMatchupWagerFloor }
    private var amountInt: Int { Int(amount.rounded(.down)) }

    private var wagerStep: Double {
        let span = maxWager - minWager
        if span >= 50 { return 5 }
        if span >= 10 { return 2 }
        return 1
    }

    var body: some View {
        ZStack {
            SkyBG()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: isIPad ? 20 : 14) {
                    StickerWord(text: "PLACE WAGER", fill: Kids.sun, fontSize: isIPad ? 32 : 22, tilt: -2)
                        .rotationEffect(.degrees(-2))
                        .padding(.top, isIPad ? 22 : 16)

                    HStack(spacing: isIPad ? 18 : 12) {
                        pickButton(matchup.fighter1)
                        StarSticker(text: "VS", size: isIPad ? 52 : 38, fill: Kids.pink)
                        pickButton(matchup.fighter2)
                    }
                    .padding(.horizontal, isIPad ? 22 : 16)

                    wagerBlock

                    Spacer()

                    HStack(spacing: isIPad ? 12 : 8) {
                        KidsMiniButton(emoji: "✕", label: "Cancel", color: Kids.creamDeep) { onCancel() }
                        Button {
                            if let p = picked, amountInt >= minWager, amountInt <= maxWager {
                                HapticsService.shared.tap()
                                onPlace(p, amountInt)
                            }
                        } label: {
                            HStack(spacing: isIPad ? 7 : 5) {
                                RetroSymbol("🪙", size: isIPad ? 18 : 14)
                                Text("Place Bet")
                                    .font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                                    .foregroundColor(Kids.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: isIPad ? 56 : 42)
                            .background(
                                RetroPanelShape(cornerRadius: 14, style: .continuous)
                                    .fill(picked == nil || amountInt < minWager || amountInt > maxWager
                                          ? Kids.creamDeep : Kids.grass)
                                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                            )
                            .compositingGroup().shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(picked == nil || amountInt < minWager || amountInt > maxWager)
                        .opacity((picked == nil || amountInt < minWager || amountInt > maxWager) ? 0.6 : 1)
                    }
                    .padding(.horizontal, isIPad ? 26 : 18)
                    .padding(.bottom, isIPad ? 26 : 18)
                }
                .frame(maxWidth: isIPad ? 720 : .infinity)
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            let lo = Double(minWager)
            let hi = Double(max(minWager, maxWager))
            if amount < lo || amount > hi { amount = lo }
        }
    }

    @ViewBuilder
    private var wagerBlock: some View {
        if maxWager > minWager {
            VStack(spacing: isIPad ? 12 : 8) {
                HStack {
                    Text("YOUR WAGER")
                        .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                    Spacer()
                    HStack(spacing: isIPad ? 6 : 4) {
                        Text("\(amountInt)")
                            .font(Kids.fredoka(isIPad ? 24 : 18, weight: .bold))
                            .foregroundColor(Kids.ink)
                        KidsGoldCoin(size: isIPad ? 22 : 16)
                    }
                }
                Slider(value: $amount, in: Double(minWager)...Double(maxWager), step: wagerStep)
                    .tint(Kids.sun)
                HStack {
                    Text("MIN \(minWager)")
                    Spacer()
                    Text("MAX \(maxWager) (10%)")
                }
                .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                HStack(spacing: isIPad ? 6 : 4) {
                    Text("Payout if correct: \(Int((Double(amountInt) * multiplier).rounded(.down)))")
                        .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                        .foregroundColor(Kids.ink)
                    KidsGoldCoin(size: isIPad ? 16 : 12)
                }
                .padding(.top, isIPad ? 6 : 4)
            }
            .padding(isIPad ? 20 : 14)
            .background(card)
            .compositingGroup().shadow(color: Kids.ink.opacity(0.06), radius: 0, x: 0, y: 3)
            .padding(.horizontal, isIPad ? 26 : 18)
        } else if maxWager == minWager {
            VStack(spacing: isIPad ? 9 : 6) {
                HStack {
                    Text("FIXED WAGER")
                        .font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Kids.ink)
                    Spacer()
                    HStack(spacing: isIPad ? 6 : 4) {
                        Text("\(minWager)")
                            .font(Kids.fredoka(isIPad ? 24 : 18, weight: .bold))
                            .foregroundColor(Kids.ink)
                        KidsGoldCoin(size: isIPad ? 22 : 16)
                    }
                }
                Text("Minimum wager only — earn more coins to bet higher.")
                    .font(Kids.nunito(isIPad ? 13 : 10, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
                    .multilineTextAlignment(.center)
                HStack(spacing: isIPad ? 6 : 4) {
                    Text("Payout if correct: \(Int((Double(minWager) * multiplier).rounded(.down)))")
                        .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                        .foregroundColor(Kids.ink)
                    KidsGoldCoin(size: isIPad ? 16 : 12)
                }
                .padding(.top, isIPad ? 6 : 4)
            }
            .padding(isIPad ? 20 : 14)
            .background(card)
            .padding(.horizontal, isIPad ? 26 : 18)
        } else {
            Text("Not enough coins to wager. Minimum is \(minWager).")
                .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                .foregroundColor(Kids.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, isIPad ? 26 : 18)
        }
    }

    private func pickButton(_ a: Animal) -> some View {
        Button {
            HapticsService.shared.tap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { picked = a.id }
        } label: {
            VStack(spacing: isIPad ? 6 : 4) {
                TournyFighterMini(animal: a, size: isIPad ? 82 : 60)
                Text(a.name)
                    .font(Kids.fredoka(isIPad ? 16 : 12, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isIPad ? 18 : 12)
            .background(
                RetroPanelShape(cornerRadius: 16, style: .continuous)
                    .fill(picked == a.id ? Kids.sun : Color.white)
                    .overlay(picked == a.id ? RetroPanelShape(cornerRadius: 16, style: .continuous).fill(Kids.sheen) : nil)
                    .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: picked == a.id ? 3 : 2.5))
            )
            .compositingGroup().shadow(color: Kids.ink.opacity(picked == a.id ? 0.18 : 0.08), radius: 0, x: 0, y: picked == a.id ? 4 : 2)
        }
        .buttonStyle(.plain)
    }

    private var card: some View {
        RetroPanelShape(cornerRadius: 16, style: .continuous)
            .fill(Color.white)
            .overlay(RetroPanelShape(cornerRadius: 16, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
    }
}

// MARK: - Grand Champion swap sheet

private struct GrandChampionSwapSheet: View {
    let tournament: Tournament
    let onSwap: (_ newId: String) -> Void
    let onCancel: () -> Void

    @State private var picked: String? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private var newMultiplier: Double {
        let r = tournament.currentRoundIndex ?? 0
        return WagerMultipliers.grandChampion(lockedAtRoundIndex: r)
    }

    var body: some View {
        ZStack {
            SkyBG()

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: isIPad ? 20 : 14) {
                    StickerWord(text: "SWAP CHAMPION", fill: Kids.grape, fontSize: isIPad ? 26 : 18, tilt: -2)
                        .padding(.top, isIPad ? 26 : 18)

                    Text("New multiplier: \(String(format: "%.2f", newMultiplier))× — wager stays the same")
                        .font(Kids.nunito(isIPad ? 16 : 12, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, isIPad ? 32 : 24)

                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: isIPad ? 14 : 10), count: isIPad ? 4 : 3), spacing: isIPad ? 14 : 10) {
                            ForEach(tournament.bracket.aliveFighters) { animal in
                                SwapPickCard(animal: animal, selected: picked == animal.id, isIPad: isIPad) {
                                    HapticsService.shared.tap()
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) {
                                        picked = animal.id
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, isIPad ? 22 : 16).padding(.vertical, isIPad ? 16 : 12)
                    }

                    HStack(spacing: isIPad ? 12 : 8) {
                        KidsMiniButton(emoji: "✕", label: "Cancel", color: Kids.creamDeep) { onCancel() }
                        Button {
                            if let p = picked { onSwap(p) }
                        } label: {
                            HStack(spacing: isIPad ? 7 : 5) {
                                RetroSymbol("🔄", size: isIPad ? 18 : 14)
                                Text("Swap").font(Kids.fredoka(isIPad ? 17 : 13, weight: .bold))
                                    .foregroundColor(Kids.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: isIPad ? 56 : 42)
                            .background(
                                RetroPanelShape(cornerRadius: 14, style: .continuous)
                                    .fill(picked == nil ? Kids.creamDeep : Kids.grape)
                                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen))
                                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(picked == nil)
                        .opacity(picked == nil ? 0.6 : 1)
                    }
                    .padding(.horizontal, isIPad ? 26 : 18)
                    .padding(.bottom, isIPad ? 26 : 18)
                }
                .frame(maxWidth: isIPad ? 720 : .infinity)
                Spacer(minLength: 0)
            }
        }
    }
}

private struct SwapPickCard: View {
    let animal: Animal
    let selected: Bool
    let isIPad: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                RetroPanelShape(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Kids.grape : Color.white)
                    .overlay(selected ? RetroPanelShape(cornerRadius: 14, style: .continuous).fill(Kids.sheen) : nil)
                    .overlay(RetroPanelShape(cornerRadius: 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
                    .aspectRatio(1, contentMode: .fit)
                VStack(spacing: isIPad ? 4 : 2) {
                    RetroCreatureArtwork(animal: animal, size: isIPad ? 62 : 46)
                    Text(animal.name)
                        .font(Kids.fredoka(isIPad ? 13 : 10, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .lineLimit(1).minimumScaleFactor(0.65)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if selected {
                    RetroPanelShape().fill(Kids.grass)
                        .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 2))
                        .frame(width: isIPad ? 28 : 20, height: isIPad ? 28 : 20)
                        .overlay(Text("✓").font(Kids.fredoka(isIPad ? 15 : 11, weight: .bold)).foregroundColor(Kids.ink))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
