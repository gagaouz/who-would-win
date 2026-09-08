import SwiftUI
import StoreKit

/// Shown when the user taps a locked fantasy creature or the Fantasy pill.
/// Restyled to use the shared `KidsUnlockSheet` aesthetic.
struct FantasyUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared

    var body: some View {
        KidsUnlockSheet(
            isPresented: $isPresented,
            config: .init(
                title: "FANTASY PACK",
                emoji: "🧚",
                color: Kids.grape,
                darkAccent: Color(hex: "#4A2E7A"),
                blurb: "12 magical creatures await — dragons, unicorns, phoenix and more!",
                preview: [("🐉","Dragon"),("🦄","Unicorn"),("🐙","Kraken"),("🔥","Phoenix"),("🐲","Hydra")],
                coinCost: CoinStore.shared.fantasyCost,
                battleThreshold: UserSettings.fantasyBattleThreshold,
                battlesPlayed: settings.totalBattleCount,
                progress: settings.fantasyUnlockProgress,
                isCoinAffordable: coins.canAfford(CoinStore.shared.fantasyCost),
                onCoinUnlock: {
                    if coins.spend(CoinStore.shared.fantasyCost) {
                        settings.fantasyUnlocked = true
                        isPresented = false
                    }
                },
                product: store.fantasyPackProduct,
                fallbackPrice: "$1.99",
                onBuy: {
                    if let p = store.fantasyPackProduct {
                        return await store.purchase(p)
                    }
                    #if DEBUG
                    settings.fantasyUnlocked = true
                    return .success
                    #else
                    await store.loadProducts()
                    return .failed
                    #endif
                },
                onRestore: { Task { await store.restorePurchases() } }
            )
        )
    }
}
