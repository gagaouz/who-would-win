import SwiftUI

// MARK: - Gold Coin Icon

struct GoldCoin: View {
    var size: CGFloat = 20

    private let goldLight = Color(hex: "#FFE566")
    private let goldMid   = Color(hex: "#FFD700")
    private let goldDark  = Color(hex: "#B8860B")

    var body: some View {
        ZStack {
            // Outer rim
            Circle()
                .fill(LinearGradient(
                    colors: [goldLight, goldDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .frame(width: size, height: size)
            // Inner face
            Circle()
                .fill(LinearGradient(
                    colors: [goldMid, goldDark.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom))
                .frame(width: size * 0.76, height: size * 0.76)
            // Symbol
            Text("C")
                .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                .foregroundColor(goldLight.opacity(0.9))
        }
        .shadow(color: goldMid.opacity(0.5), radius: size * 0.12, x: 0, y: size * 0.06)
    }
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
                            .foregroundColor(Color(hex: "#FFD700"))
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: coinStore.balance)
                    }
                    .padding(.horizontal, hPad)
                    .padding(.vertical, vPad)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#FFD700").opacity(0.15))
                            .overlay(Capsule().stroke(Color(hex: "#FFD700").opacity(0.4), lineWidth: 1))
                    )

                    if showProgress, let pack = coinStore.nextPack {
                        VStack(spacing: 2) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.08))
                                    Capsule()
                                        .fill(Color(hex: "#FFD700").opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(coinStore.nextPackProgress))
                                }
                            }
                            .frame(height: 4)
                            .frame(width: size == .compact ? 60 : size == .regular ? 80 : 110)

                            Text("\(pack.emoji) \(pack.name)")
                                .font(.system(size: size == .large ? 10 : 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }

                // Green dot — ad reward available
                if adManager.coinAdReady && coinStore.canWatchAdForCoins {
                    Circle()
                        .fill(Color.green)
                        .frame(width: dotSize, height: dotSize)
                        .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 1))
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
    @Environment(\.dismiss) private var dismiss

    private let gold = Color(hex: "#FFD700")

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
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundColor(gold)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4), value: coinStore.balance)
                            Text("Battle Coins")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.top, 8)

                        // Progress toward next pack
                        if let pack = coinStore.nextPack {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("\(pack.emoji) Next: \(pack.name) Pack")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                    Spacer()
                                    Text("\(coinStore.balance) / \(pack.cost)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(gold.opacity(0.7))
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08))
                                        RoundedRectangle(cornerRadius: 6)
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
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(gold.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 16)
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
                                            .font(.system(size: 14, weight: .black, design: .rounded))
                                            .foregroundColor(gold)
                                    } else if isNotReady {
                                        ProgressView().tint(.white.opacity(0.4)).scaleEffect(0.8)
                                    }
                                }
                                .foregroundColor(isNotReady ? .white.opacity(0.4) : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isNotReady
                                              ? AnyShapeStyle(Color.white.opacity(0.12))
                                              : AnyShapeStyle(LinearGradient(
                                                colors: [Color(hex: "#1A3A2A"), Color(hex: "#0F2A1A")],
                                                startPoint: .leading, endPoint: .trailing)))
                                        .overlay(RoundedRectangle(cornerRadius: 16)
                                            .stroke(isNotReady ? Color.white.opacity(0.2) : Color.green.opacity(0.4), lineWidth: 1))
                                )
                            }
                            .buttonStyle(PressableButtonStyle())
                            .disabled(isWatchingAd || isNotReady)
                            .onAppear { AdManager.shared.preloadRewardedForCoinsIfNeeded() }
                        }

                        // Buy coins IAP — always visible (lazy-loads product on
                        // tap if ASC hasn't returned it yet). This is the
                        // primary entry point Apple's reviewer tests.
                        Button {
                            isBuyingCoins = true
                            Task {
                                if storeKit.coins1000Product == nil {
                                    await StoreKitManager.shared.loadProducts()
                                }
                                if let product = storeKit.coins1000Product {
                                    _ = await StoreKitManager.shared.purchase(product)
                                } else {
                                    storeKit.lastError = "Coin pack is temporarily unavailable. Please try again in a moment."
                                }
                                isBuyingCoins = false
                            }
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
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(gold)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#DAA520"), Color(hex: "#8B6914")],
                                        startPoint: .leading, endPoint: .trailing))
                                    .overlay(RoundedRectangle(cornerRadius: 16)
                                        .stroke(gold.opacity(0.4), lineWidth: 1))
                            )
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(isBuyingCoins)

                        // Earn rates card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HOW TO EARN")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                                .tracking(1.5)

                            earnRow(icon: "⚔️", label: "Every battle",
                                    value: "+\(coinStore.coinsPerBattle)")
                            Divider().background(Color.white.opacity(0.07))
                            earnRow(icon: "☀️", label: "First battle of the day",
                                    value: "+\(coinStore.dailyFirstBattleBonus) bonus")
                            Divider().background(Color.white.opacity(0.07))
                            earnRow(icon: "📺", label: "Watch an ad (up to \(coinStore.maxDailyAds)/day)",
                                    value: "+\(coinStore.coinsPerAd)")
                            if !UserSettings.shared.isSubscribed {
                                Divider().background(Color.white.opacity(0.07))
                                earnRow(icon: "👑", label: "Premium subscription",
                                        value: "2× per battle")
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.12))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1))
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
    }

    private func earnRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Text(icon).font(.system(size: 14))
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
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

/// Drop-in "Buy 1,000 Coins" IAP button.  Always visible — shows the live
/// App Store price when the product is loaded, falls back to "$1.99" otherwise.
struct BuyCoinsButton: View {
    @ObservedObject private var storeKit = StoreKitManager.shared
    @State private var isBuying = false
    private let gold = Color(hex: "#FFD700")

    private var displayPrice: String {
        storeKit.coins1000Product?.displayPrice ?? "$1.99"
    }

    var body: some View {
        Button {
            isBuying = true
            Task {
                // If the product didn't load on init (flaky network, ASC lag),
                // reload right before the purchase so the reviewer doesn't get
                // stuck on a silent no-op tap.
                if storeKit.coins1000Product == nil {
                    await StoreKitManager.shared.loadProducts()
                }
                if let product = storeKit.coins1000Product {
                    _ = await StoreKitManager.shared.purchase(product)
                } else {
                    storeKit.lastError = "Coin pack is temporarily unavailable. Please try again in a moment."
                }
                isBuying = false
            }
        } label: {
            HStack(spacing: 10) {
                if isBuying {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    GoldCoin(size: 18)
                }
                Text(isBuying ? "Purchasing…" : "Buy 1,000 Coins — \(displayPrice)")
                    .font(Theme.bungee(14))
                    .foregroundColor(.white)
                Spacer()
                if !isBuying {
                    Text("+1,000")
                        .font(Theme.bungee(12))
                        .foregroundColor(gold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#DAA520"), Color(hex: "#8B6914")],
                        startPoint: .leading, endPoint: .trailing))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(gold.opacity(0.5), lineWidth: 1))
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isBuying)
    }
}
