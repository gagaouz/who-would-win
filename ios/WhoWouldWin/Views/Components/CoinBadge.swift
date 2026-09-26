import SwiftUI

// MARK: - Gold Coin Icon

struct GoldCoin: View {
    var size: CGFloat = 20
    var body: some View { KidsGoldCoin(size: size) }
}

// MARK: - Coin Badge Size

enum CoinBadgeSize { case compact, regular, large }

// MARK: - Coin Badge (always tappable — opens CoinsHubSheet)

struct CoinBadge: View {
    @ObservedObject var coinStore   = CoinStore.shared
    @ObservedObject private var adManager = AdManager.shared
    @State private var showCoinsHub = false
    var size: CoinBadgeSize = .regular
    var showProgress: Bool  = false

    var body: some View {
        Button { showCoinsHub = true } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    HStack(spacing: size == .compact ? 3 : 5) {
                        GoldCoin(size: emojiSize)
                        Text(coinStore.formattedBalance)
                            .font(Theme.bungee(textSize))
                            .foregroundColor(Kids.peachDeep)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: coinStore.balance)
                    }
                    .padding(.horizontal, hPad)
                    .padding(.vertical, vPad)
                    .background(
                        RetroPanelShape()
                            .fill(Kids.peachDeep.opacity(0.15))
                            .overlay(RetroPanelShape().stroke(Kids.peachDeep.opacity(0.4), lineWidth: 1))
                    )

                    if showProgress, let pack = coinStore.nextPack {
                        VStack(spacing: 2) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RetroPanelShape().fill(Kids.ink.opacity(0.08))
                                    RetroPanelShape()
                                        .fill(Kids.peachDeep.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(coinStore.nextPackProgress))
                                }
                            }
                            .frame(height: 4)
                            .frame(width: size == .compact ? 60 : size == .regular ? 80 : 110)

                            Text(pack.name)
                                .font(.system(size: size == .large ? 10 : 9, weight: .semibold, design: .rounded))
                                .foregroundColor(Kids.ink.opacity(0.4))
                        }
                    }
                }

                // Green dot — ad reward available
                if adManager.coinAdReady && coinStore.canWatchAdForCoins {
                    Rectangle()
                        .fill(Kids.grassDeep)
                        .frame(width: dotSize, height: dotSize)
                        .overlay(Rectangle().stroke(Color.black.opacity(0.3), lineWidth: 1))
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .sheet(isPresented: $showCoinsHub) { CoinsHubSheet() }
    }

    private var emojiSize: CGFloat {
        switch size { case .compact: return 12; case .regular: return 14; case .large: return 20 }
    }
    private var textSize: CGFloat {
        switch size { case .compact: return 12; case .regular: return 14; case .large: return 18 }
    }
    private var hPad: CGFloat {
        switch size { case .compact: return 8; case .regular: return 10; case .large: return 14 }
    }
    private var vPad: CGFloat {
        switch size { case .compact: return 4; case .regular: return 5; case .large: return 8 }
    }
    private var dotSize: CGFloat {
        switch size { case .compact: return 7; case .regular: return 8; case .large: return 10 }
    }
}

// MARK: - Coins Hub Sheet

struct CoinsHubSheet: View {
    @ObservedObject private var coinStore  = CoinStore.shared
    @ObservedObject private var adManager  = AdManager.shared
    @ObservedObject private var storeKit = StoreKitManager.shared
    @State private var isWatchingAd = false
    @State private var isBuyingCoins = false
    @State private var showParentGate = false
    @State private var showAskToBuyNotice = false
    @Environment(\.dismiss) private var dismiss

    private let gold = Kids.peachDeep

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground(style: .home).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Balance hero
                        VStack(spacing: 6) {
                            GoldCoin(size: 56)
                            Text(coinStore.formattedBalance)
                                .onAppear {
                                    // Refresh products whenever the coin hub is
                                    // opened — catches cases where the initial
                                    // load at app start failed.
                                    Task { await StoreKitManager.shared.loadProducts() }
                                }
                                .font(Theme.bungee(48))
                                .foregroundColor(gold)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4), value: coinStore.balance)
                            Text("Battle Coins")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Kids.ink.opacity(0.4))
                        }
                        .padding(.top, 8)

                        // Progress toward next pack
                        if let pack = coinStore.nextPack {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Next: \(pack.name) Pack")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(Kids.ink.opacity(0.8))
                                    Spacer()
                                    Text("\(coinStore.balance) / \(pack.cost)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(gold.opacity(0.7))
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RetroPanelShape(cornerRadius: 6).fill(Kids.ink.opacity(0.08))
                                        RetroPanelShape(cornerRadius: 6)
                                            .fill(LinearGradient(
                                                colors: [gold.opacity(0.6), gold],
                                                startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * CGFloat(coinStore.nextPackProgress))
                                    }
                                }
                                .frame(height: 10)

                                if coinStore.canAfford(pack.cost) {
                                    Text("✅ You can afford this pack! Open a pack to spend your coins.")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(gold.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                } else {
                                    let battlesLeft = max(0, pack.cost - coinStore.balance)
                                    Text("~\(Int(ceil(Double(battlesLeft) / Double(coinStore.coinsPerBattle)))) battles to go")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(Kids.ink.opacity(0.35))
                                }
                            }
                            .padding(16)
                            .background(
                                RetroPanelShape(cornerRadius: 16)
                                    .fill(gold.opacity(0.06))
                                    .overlay(RetroPanelShape(cornerRadius: 16)
                                        .stroke(gold.opacity(0.2), lineWidth: 1))
                            )
                        } else {
                            Text("🎉 You've unlocked all packs!")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(gold)
                        }

                        // Watch Ad for Coins
                        if coinStore.canWatchAdForCoins {
                            let adReady = adManager.coinAdReady
                            let isNotReady = !adReady && !isWatchingAd
                            Button {
                                guard adManager.coinAdReady else { return }
                                isWatchingAd = true
                                AdManager.shared.showRewardedAdForCoins { success in
                                    Task { @MainActor in
                                        isWatchingAd = false
                                        if success { CoinStore.shared.recordAdWatched() }
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    if isWatchingAd {
                                        ProgressView().tint(.white).scaleEffect(0.9)
                                    } else {
                                        Image(systemName: isNotReady ? "clock.fill" : "play.rectangle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isWatchingAd ? "Starting ad…" :
                                             isNotReady  ? "Loading ad…" :
                                             "Watch Ad — Earn +\(coinStore.coinsPerAd)")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                        if adReady && !isWatchingAd {
                                            Text("\(coinStore.adsRemainingToday) of \(coinStore.maxDailyAds) remaining today")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .opacity(0.6)
                                        }
                                    }
                                    Spacer()
                                    if adReady && !isWatchingAd {
                                        GoldCoin(size: 20)
                                        Text("+\(coinStore.coinsPerAd)")
                                            .font(Theme.bungee(14))
                                            .foregroundColor(gold)
                                    } else if isNotReady {
                                        ProgressView().tint(.white.opacity(0.4)).scaleEffect(0.8)
                                    }
                                }
                                .foregroundColor(isNotReady ? .white.opacity(0.4) : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RetroPanelShape(cornerRadius: 16)
                                        .fill(isNotReady
                                              ? AnyShapeStyle(Kids.ink.opacity(0.12))
                                              : AnyShapeStyle(LinearGradient(
                                                colors: [Color(hex: "#1A3A2A"), Color(hex: "#0F2A1A")],
                                                startPoint: .leading, endPoint: .trailing)))
                                        .overlay(RetroPanelShape(cornerRadius: 16)
                                            .stroke(isNotReady ? Kids.ink.opacity(0.2) : Kids.grassDeep.opacity(0.4), lineWidth: 1))
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(isWatchingAd || isNotReady)
                            .onAppear { AdManager.shared.preloadRewardedForCoinsIfNeeded() }
                        }

                        // Buy coins IAP — always visible (lazy-loads product on
                        // tap if ASC hasn't returned it yet). This is the
                        // primary entry point Apple's reviewer tests.
                        // Real-money purchase, so the parental gate comes first.
                        Button {
                            guard !isBuyingCoins else { return }
                            showParentGate = true
                        } label: {
                            HStack(spacing: 10) {
                                if isBuyingCoins {
                                    ProgressView().tint(.white).scaleEffect(0.9)
                                } else {
                                    GoldCoin(size: 22)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isBuyingCoins ? "Purchasing…" : "Buy 1,000 Coins")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                    Text(storeKit.coins1000Product?.displayPrice ?? "$1.99")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .opacity(0.6)
                                }
                                Spacer()
                                if !isBuyingCoins {
                                    Text("+1,000")
                                        .font(Theme.bungee(14))
                                        .foregroundColor(gold)
                                }
                            }
                            .foregroundColor(Kids.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RetroPanelShape(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#DAA520"), Color(hex: "#8B6914")],
                                        startPoint: .leading, endPoint: .trailing))
                                    .overlay(RetroPanelShape(cornerRadius: 16)
                                        .stroke(gold.opacity(0.4), lineWidth: 1))
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(isBuyingCoins)

                        // Earn rates card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HOW TO EARN")
                                .font(Theme.bungee(11))
                                .foregroundColor(Kids.ink.opacity(0.3))
                                .tracking(1.5)

                            earnRow(icon: "⚔️", label: "Every battle",
                                    value: "+\(coinStore.coinsPerBattle)")
                            Divider().background(Kids.ink.opacity(0.07))
                            earnRow(icon: "☀️", label: "First battle of the day",
                                    value: "+\(coinStore.dailyFirstBattleBonus) bonus")
                            Divider().background(Kids.ink.opacity(0.07))
                            earnRow(icon: "📺", label: "Watch an ad (up to \(coinStore.maxDailyAds)/day)",
                                    value: "+\(coinStore.coinsPerAd)")
                            if !UserSettings.shared.isSubscribed {
                                Divider().background(Kids.ink.opacity(0.07))
                                earnRow(icon: "👑", label: "Premium subscription",
                                        value: "2× per battle")
                            }
                        }
                        .padding(16)
                        .background(
                            RetroPanelShape(cornerRadius: 16)
                                .fill(Kids.ink.opacity(0.12))
                                .overlay(RetroPanelShape(cornerRadius: 16)
                                    .stroke(Kids.ink.opacity(0.2), lineWidth: 1))
                        )

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Battle Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(gold)
                }
            }
        }
        .parentGate(isPresented: $showParentGate) { buyCoins() }
        .alert("📨 Asked your grown-up!", isPresented: $showAskToBuyNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your coins will arrive when they say yes.")
        }
    }

    /// Runs only after the parental gate has been passed.
    private func buyCoins() {
        isBuyingCoins = true
        Task { @MainActor in
            if storeKit.coins1000Product == nil {
                await StoreKitManager.shared.loadProducts()
            }
            if let product = storeKit.coins1000Product {
                if await StoreKitManager.shared.purchase(product) == .pending {
                    showAskToBuyNotice = true
                }
            } else {
                storeKit.lastError = "Coin pack is temporarily unavailable. Please try again in a moment."
            }
            isBuyingCoins = false
        }
    }

    private func earnRow(icon: String, label: String, value: String) -> some View {
        HStack {
            RetroSymbol(icon, size: 14)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Kids.ink.opacity(0.6))
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(gold.opacity(0.8))
                GoldCoin(size: 13)
            }
        }
    }
}

// MARK: - Buy Coins Button (reusable)

/// Drop-in "Buy 1,000 Coins" IAP button. Kids-themed pill matching the rest
/// of the UI overhaul — sun fill, ink stroke, Fredoka font.
struct BuyCoinsButton: View {
    @ObservedObject private var storeKit = StoreKitManager.shared
    @State private var isBuying = false
    @State private var showParentGate = false
    @State private var showAskToBuyNotice = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    private var displayPrice: String {
        storeKit.coins1000Product?.displayPrice ?? "$1.99"
    }

    var body: some View {
        Button {
            HapticsService.shared.tap()
            guard !isBuying else { return }
            // Real-money purchase — parental gate before StoreKit.
            showParentGate = true
        } label: {
            HStack(spacing: isIPad ? 12 : 8) {
                if isBuying {
                    ProgressView().tint(Kids.ink).scaleEffect(isIPad ? 1.0 : 0.85)
                } else {
                    KidsGoldCoin(size: isIPad ? 26 : 20)
                }
                Text(isBuying ? "Purchasing…" : "BUY 1,000 COINS")
                    .font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold))
                    .foregroundColor(Kids.ink)
                Spacer(minLength: 0)
                if !isBuying {
                    Text(displayPrice)
                        .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                        .foregroundColor(Kids.ink.opacity(0.7))
                        .padding(.horizontal, isIPad ? 10 : 7)
                        .padding(.vertical, isIPad ? 5 : 3)
                        .background(
                            RetroPanelShape().fill(.white)
                                .overlay(RetroPanelShape().stroke(Kids.ink, lineWidth: 1.5))
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, isIPad ? 18 : 14)
            .padding(.vertical, isIPad ? 14 : 11)
            .background(
                RetroPanelShape(cornerRadius: isIPad ? 18 : 14, style: .continuous)
                    .fill(Kids.sun)
                    .overlay(RetroPanelShape(cornerRadius: isIPad ? 18 : 14, style: .continuous).fill(Kids.sheen))
                    .overlay(RetroPanelShape(cornerRadius: isIPad ? 18 : 14, style: .continuous).stroke(Kids.ink, lineWidth: 2.5))
            )
            .compositingGroup().shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 3)
            .opacity(isBuying ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isBuying)
        .parentGate(isPresented: $showParentGate) { buyCoins() }
        .alert("📨 Asked your grown-up!", isPresented: $showAskToBuyNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your coins will arrive when they say yes.")
        }
    }

    /// Runs only after the parental gate has been passed.
    private func buyCoins() {
        isBuying = true
        Task { @MainActor in
            // If the product didn't load on init (flaky network, ASC lag),
            // reload right before the purchase so the user doesn't get
            // stuck on a silent no-op tap.
            if storeKit.coins1000Product == nil {
                await StoreKitManager.shared.loadProducts()
            }
            if let product = storeKit.coins1000Product {
                if await StoreKitManager.shared.purchase(product) == .pending {
                    showAskToBuyNotice = true
                }
            } else {
                storeKit.lastError = "Coin pack is temporarily unavailable. Please try again in a moment."
            }
            isBuying = false
        }
    }
}
