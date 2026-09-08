import SwiftUI
import StoreKit

// MARK: - Coin Shop — Animal Arena Jr.
// Standalone sheet you can pop from any CoinChip tap. Shows current balance,
// every way to earn coins, "watch ad" CTA, and the StoreKit "Buy 1,000 coins"
// purchase. Mirrors what's in the Settings → Coin Bank section.

struct KidsCoinShopSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var coins = CoinStore.shared
    @ObservedObject private var settings = UserSettings.shared
    @StateObject private var store = StoreKitManager.shared
    @State private var appeared = false
    @State private var balancePulse: CGFloat = 1

    // Real-money purchase gating + Ask-to-Buy notice. The gate runs whatever
    // purchase was queued in `gatedAction` (coins or the Everything Bundle).
    @State private var showParentGate = false
    @State private var gatedAction: (() -> Void)? = nil
    @State private var showAskToBuyNotice = false

    /// Bundle has nothing left to grant — hide its card.
    private var ownsEverything: Bool {
        settings.adsRemoved
            && settings.isFantasyUnlocked && settings.isPrehistoricUnlocked
            && settings.isMythicUnlocked && settings.isOlympusUnlocked
            && settings.isMeleeUnlocked && settings.hasAllEnvironments
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#FFE6B8"), Color(hex: "#FFC5B8")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Floating coin sparkles
            GeometryReader { _ in
                ForEach(0..<8, id: \.self) { i in
                    let x = CGFloat([28, 340, 60, 320, 90, 300, 50, 330][i])
                    let y = CGFloat([100, 130, 240, 270, 420, 460, 600, 640][i])
                    Text("✨")
                        .font(.system(size: CGFloat(10 + (i % 3) * 3)))
                        .foregroundColor(Kids.sun.opacity(0.6))
                        .position(x: x, y: y)
                }
            }
            .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 16) {

                    // Close button
                    HStack {
                        Spacer()
                        Button { isPresented = false } label: {
                            ZStack {
                                Circle().fill(.white)
                                    .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Kids.ink)
                            }
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).padding(.top, 6)

                    // Hero
                    VStack(spacing: 6) {
                        KidsGoldCoin(size: 72)
                            .scaleEffect(balancePulse)
                            .shadow(color: Kids.ink.opacity(0.12), radius: 0, x: 0, y: 5)
                        StickerWord(text: "COIN BANK", fill: Kids.sun, fontSize: 32, tilt: -2)
                            .rotationEffect(.degrees(appeared ? -2 : -15))
                            .scaleEffect(appeared ? 1 : 0.3)
                    }

                    // Balance card
                    VStack(spacing: 6) {
                        Text("Your balance")
                            .font(Kids.nunito(12, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                        HStack(spacing: 8) {
                            KidsGoldCoin(size: 36)
                            Text(coins.balance.abbreviatedKidsCount)
                                .font(Kids.fredoka(48, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .scaleEffect(balancePulse)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white)
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                    )
                    .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
                    .padding(.horizontal, 18)

                    // Earn list
                    VStack(spacing: 8) {
                        Text("EARN COINS")
                            .font(Kids.fredoka(11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Kids.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        earnRow(icon: "⚔️", title: "Battle a match-up", reward: "+10")
                        earnRow(icon: "🌅", title: "First battle each day", reward: "+25")
                        earnRow(icon: "🎬", title: "Watch a quick video", reward: "+75",
                                action: {
                            AdManager.shared.showRewardedAdForCoins { granted in
                                if granted { CoinStore.shared.recordAdWatched() }
                            }
                        }, disabled: !coins.canWatchAdForCoins,
                           sublabel: coins.canWatchAdForCoins ? "\(coins.adsRemainingToday) left today" : "Come back tomorrow!")
                        earnRow(icon: "🔥", title: "3+ day streak bonus", reward: "+\(coins.streakBonus3Days)")
                        earnRow(icon: "👑", title: "Premium subscribers", reward: "2× coins!")
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white)
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                    )
                    .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
                    .padding(.horizontal, 18)

                    // Buy coins
                    VStack(spacing: 8) {
                        Text("OR BUY MORE")
                            .font(Kids.fredoka(11, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Kids.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)

                        KidButton(
                            title: store.coins1000Product.map { "Buy 1,000 Coins — \($0.displayPrice)" } ?? "Buy 1,000 Coins — $1.99",
                            color: Kids.sun, size: .lg
                        ) {
                            // Real-money purchase — parental gate first.
                            gatedAction = buyCoins
                            showParentGate = true
                        }
                        Text("Coins are added instantly and never expire.")
                            .font(Kids.nunito(10, weight: .bold))
                            .foregroundColor(Kids.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white)
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Kids.ink, lineWidth: 3))
                    )
                    .shadow(color: Kids.ink.opacity(0.07), radius: 0, x: 0, y: 3)
                    .padding(.horizontal, 18)

                    // Everything Bundle — the one-and-done parent option
                    if !ownsEverything {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Text("🎁").font(.system(size: 18))
                                Text("EVERYTHING BUNDLE")
                                    .font(Kids.fredoka(11, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(Kids.inkSoft)
                                Spacer()
                                Text("BEST VALUE")
                                    .font(Kids.fredoka(9, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Capsule().fill(Kids.pink).overlay(Capsule().stroke(Kids.ink, lineWidth: 1.5)))
                            }
                            .padding(.horizontal, 4)

                            KidButton(
                                title: store.everythingBundleProduct.map { "Unlock Everything — \($0.displayPrice)" } ?? "Unlock Everything — $14.99",
                                color: Kids.grape, size: .lg
                            ) {
                                gatedAction = buyBundle
                                showParentGate = true
                            }
                            Text("Every creature pack + Melee + Arenas + No Ads, forever.")
                                .font(Kids.nunito(10, weight: .bold))
                                .foregroundColor(Kids.inkSoft)
                                .multilineTextAlignment(.center)
                                .padding(.top, 2)
                            Text("👑 Premium families already have every pack, no ads, and 2× coins — see Settings.")
                                .font(Kids.nunito(9, weight: .bold))
                                .foregroundColor(Kids.inkSoft.opacity(0.8))
                                .multilineTextAlignment(.center)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(.white)
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Kids.sun, lineWidth: 3.5))
                        )
                        .shadow(color: Kids.ink.opacity(0.09), radius: 0, x: 0, y: 4)
                        .padding(.horizontal, 18)
                    }

                    Color.clear.frame(height: 30)
                }
                .scaleEffect(appeared ? 1 : 0.95)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { balancePulse = 1.06 }
            // The earn-coins video is available to everyone (incl. paid users,
            // whose launch preload is skipped for privacy) — load it now so
            // the button is ready by the time they tap it.
            AdManager.shared.preloadRewardedForCoinsIfNeeded()
        }
        .parentGate(isPresented: $showParentGate) {
            gatedAction?()
            gatedAction = nil
        }
        .alert("📨 Asked your grown-up!", isPresented: $showAskToBuyNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your purchase will arrive when they say yes.")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Runs only after the parental gate has been passed.
    private func buyCoins() {
        Task { @MainActor in
            if store.coins1000Product == nil { await store.loadProducts() }
            guard let p = store.coins1000Product else { return }
            if await store.purchase(p) == .pending {
                showAskToBuyNotice = true
            }
        }
    }

    /// Runs only after the parental gate has been passed.
    private func buyBundle() {
        Task { @MainActor in
            if store.everythingBundleProduct == nil { await store.loadProducts() }
            guard let p = store.everythingBundleProduct else { return }
            if await store.purchase(p) == .pending {
                showAskToBuyNotice = true
            }
        }
    }

    @ViewBuilder
    private func earnRow(icon: String, title: String, reward: String,
                          action: (() -> Void)? = nil, disabled: Bool = false,
                          sublabel: String? = nil) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Kids.cream)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Kids.ink, lineWidth: 2))
                    .frame(width: 40, height: 40)
                Text(icon).font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Kids.fredoka(13, weight: .bold))
                    .foregroundColor(Kids.ink)
                if let s = sublabel {
                    Text(s).font(Kids.nunito(10, weight: .bold)).foregroundColor(Kids.inkSoft)
                }
            }
            Spacer()
            if let action = action {
                Button {
                    HapticsService.shared.tap()
                    action()
                } label: {
                    Text(reward)
                        .font(Kids.fredoka(13, weight: .bold))
                        .foregroundColor(Kids.ink)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            Capsule().fill(disabled ? Color(hex: "#E8DFF5") : Kids.grass)
                                .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
                        )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
                .opacity(disabled ? 0.6 : 1)
            } else {
                Text(reward)
                    .font(Kids.fredoka(13, weight: .bold))
                    .foregroundColor(Kids.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Kids.sun).overlay(Capsule().stroke(Kids.ink, lineWidth: 2)))
            }
        }
    }
}
