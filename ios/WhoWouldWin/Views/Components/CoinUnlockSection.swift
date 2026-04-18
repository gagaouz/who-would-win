import SwiftUI

struct CoinUnlockSection: View {
    let cost: Int
    let accentColor: Color
    let onUnlock: () -> Void

    @ObservedObject private var coinStore = CoinStore.shared
    @ObservedObject private var adManager = AdManager.shared
    @State private var showInsufficientAlert = false
    @State private var isWatchingAd = false

    private var canAfford: Bool { coinStore.canAfford(cost) }
    private var needed: Int { max(0, cost - coinStore.balance) }

    var body: some View {
        VStack(spacing: 10) {
            // Header row
            HStack(spacing: 0) {
                HStack(spacing: 5) {
                    GoldCoin(size: 12)
                    Text("UNLOCK WITH COINS")
                        .font(Theme.bungee(11))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .tracking(1.5)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Balance:")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                    GoldCoin(size: 12)
                    Text("\(coinStore.formattedBalance)")
                        .font(Theme.bungee(12))
                        .foregroundColor(Color(hex: "#FFD700"))
                }
            }

            // Spend button
            Button(action: {
                if canAfford {
                    coinStore.spend(cost)
                    onUnlock()
                } else {
                    showInsufficientAlert = true
                }
            }) {
                HStack(spacing: 10) {
                    GoldCoin(size: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spend \(cost.formatted()) coins")
                            .font(Theme.bungee(16))
                            .foregroundColor(canAfford ? .white : .white.opacity(0.6))
                        if !canAfford {
                            Text("Need \(needed.formatted()) more")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    Spacer()
                    if canAfford {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            canAfford
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: "#FFD700"), Color(hex: "#F59E0B")],
                                startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    canAfford ? Color(hex: "#FFD700").opacity(0.5) : Color.white.opacity(0.2),
                                    lineWidth: 1)
                        )
                )
                .shadow(
                    color: canAfford ? Color(hex: "#FFD700").opacity(0.45) : .clear,
                    radius: 10, x: 0, y: 4)
            }
            .buttonStyle(PressableButtonStyle())

            // Premium upsell — shown when can't afford AND out of daily ads
            if !canAfford && !coinStore.canWatchAdForCoins && !UserSettings.shared.isSubscribed {
                VStack(spacing: 6) {
                    Text("Out of daily ads?")
                        .font(Theme.bungee(12))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Go Premium for 2\u{00D7} coin earn rate!")
                        .font(Theme.bungee(13))
                        .foregroundColor(Theme.gold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.gold.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.gold.opacity(0.2), lineWidth: 1))
                )
            }

            // Buy coins via IAP (shown when can't afford)
            if !canAfford {
                BuyCoinsButton()
            }

            // Watch ad for more coins (shown when can't afford AND ads remain)
            if !canAfford && coinStore.canWatchAdForCoins {
                let adReady = adManager.coinAdReady
                Button(action: {
                    guard adManager.coinAdReady else { return }
                    isWatchingAd = true
                    AdManager.shared.showRewardedAdForCoins { success in
                        Task { @MainActor in
                            isWatchingAd = false
                            if success {
                                CoinStore.shared.recordAdWatched()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        if isWatchingAd {
                            ProgressView().tint(.white.opacity(0.6)).scaleEffect(0.8)
                        } else if !adReady {
                            ProgressView().tint(.white.opacity(0.35)).scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 13))
                        }
                        Text(isWatchingAd
                             ? "Starting ad…"
                             : !adReady
                               ? "Loading ad…"
                               : "+\(coinStore.coinsPerAd) coins  Watch Ad  (\(coinStore.adsRemainingToday) left today)")
                            .font(Theme.bungee(13))
                    }
                    .foregroundColor(!adReady || isWatchingAd ? .white.opacity(0.35) : .white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(!adReady || isWatchingAd ? Color.white.opacity(0.12) : accentColor.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(!adReady || isWatchingAd ? Color.white.opacity(0.2).opacity(0.5) : accentColor.opacity(0.4), lineWidth: 1))
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(isWatchingAd || !adReady)
                .onAppear { AdManager.shared.preloadRewardedForCoinsIfNeeded() }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#FFD700").opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: "#FFD700").opacity(0.2), lineWidth: 1))
        )
        .alert("Not Enough Coins", isPresented: $showInsufficientAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You need \(needed.formatted()) more coins. Keep battling to earn more, or watch ads for a quick boost!")
        }
    }
}
