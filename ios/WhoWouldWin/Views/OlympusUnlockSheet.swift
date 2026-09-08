import SwiftUI
import StoreKit

struct OlympusUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared

    var body: some View {
        KidsUnlockSheet(
            isPresented: $isPresented,
            config: .init(
                title: "OLYMPUS",
                emoji: "🔱",
                color: Color(hex: "#E0B040"),
                darkAccent: Color(hex: "#5C3A00"),
                blurb: "The mighty gods of Olympus — Zeus, Poseidon, Hades and more!",
                preview: [("⚡","Zeus"),("🔱","Poseidon"),("💀","Hades"),("🏹","Apollo"),("🦉","Athena")],
                coinCost: CoinStore.shared.olympusCost,
                battleThreshold: UserSettings.olympusBattleThreshold,
                battlesPlayed: settings.totalBattleCount,
                progress: settings.olympusUnlockProgress,
                isCoinAffordable: coins.canAfford(CoinStore.shared.olympusCost),
                onCoinUnlock: {
                    if coins.spend(CoinStore.shared.olympusCost) {
                        settings.olympusUnlocked = true
                        isPresented = false
                    }
                },
                product: store.olympusPackProduct,
                fallbackPrice: "$4.99",
                onBuy: {
                    if let p = store.olympusPackProduct {
                        return await store.purchase(p)
                    }
                    #if DEBUG
                    settings.olympusUnlocked = true
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
