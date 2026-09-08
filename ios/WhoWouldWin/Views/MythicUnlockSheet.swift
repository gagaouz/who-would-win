import SwiftUI
import StoreKit

struct MythicUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared

    var body: some View {
        KidsUnlockSheet(
            isPresented: $isPresented,
            config: .init(
                title: "MYTHIC BEASTS",
                emoji: "⚡",
                color: Kids.sunDeep,
                darkAccent: Color(hex: "#7A6600"),
                blurb: "12 legendary creatures from ancient myth — thunderbirds, manticores and more!",
                preview: [("🦅","Thunderbird"),("🦁","Manticore"),("🐦","Roc"),("🐍","Basilisk"),("🦊","Kitsune")],
                coinCost: CoinStore.shared.mythicCost,
                battleThreshold: UserSettings.mythicBattleThreshold,
                battlesPlayed: settings.totalBattleCount,
                progress: settings.mythicUnlockProgress,
                isCoinAffordable: coins.canAfford(CoinStore.shared.mythicCost),
                onCoinUnlock: {
                    if coins.spend(CoinStore.shared.mythicCost) {
                        settings.mythicUnlocked = true
                        isPresented = false
                    }
                },
                product: store.mythicPackProduct,
                fallbackPrice: "$2.99",
                onBuy: {
                    if let p = store.mythicPackProduct {
                        return await store.purchase(p)
                    }
                    #if DEBUG
                    settings.mythicUnlocked = true
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
