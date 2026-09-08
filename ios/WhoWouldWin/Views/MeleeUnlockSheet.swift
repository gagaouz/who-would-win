import SwiftUI
import StoreKit

struct MeleeUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared

    var body: some View {
        KidsUnlockSheet(
            isPresented: $isPresented,
            config: .init(
                title: "MELEE",
                emoji: "⚔️",
                color: Kids.grape,
                darkAccent: Color(hex: "#3A1F66"),
                blurb: "Team battles! 2v1, 3v2, 4v4 — pick your squad and clash!",
                preview: [("🦁","Lion"),("🐉","Dragon"),("🦈","Shark"),("🦅","Eagle"),("🦖","T-Rex")],
                coinCost: CoinStore.shared.meleeCost,
                battleThreshold: UserSettings.meleeBattleThreshold,
                battlesPlayed: settings.totalBattleCount,
                progress: settings.meleeUnlockProgress,
                isCoinAffordable: coins.canAfford(CoinStore.shared.meleeCost),
                onCoinUnlock: {
                    if coins.spend(CoinStore.shared.meleeCost) {
                        settings.meleeUnlocked = true
                        isPresented = false
                    }
                },
                product: store.meleePackProduct,
                fallbackPrice: "$2.99",
                onBuy: {
                    if let p = store.meleePackProduct {
                        return await store.purchase(p)
                    }
                    #if DEBUG
                    settings.meleeUnlocked = true
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
