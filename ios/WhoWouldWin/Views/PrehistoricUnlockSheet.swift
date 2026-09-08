import SwiftUI
import StoreKit

struct PrehistoricUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared
    @ObservedObject private var coins = CoinStore.shared

    var body: some View {
        KidsUnlockSheet(
            isPresented: $isPresented,
            config: .init(
                title: "DINO PACK",
                emoji: "🦖",
                color: Kids.sun,
                darkAccent: Color(hex: "#8B5A0A"),
                blurb: "12 ancient titans — T-Rex, Megalodon, Mammoth and more!",
                preview: [("🦖","T-Rex"),("🦕","Brachio"),("🦣","Mammoth"),("🐉","Raptor"),("🐊","Sarcos")],
                coinCost: CoinStore.shared.prehistoricCost,
                battleThreshold: UserSettings.prehistoricBattleThreshold,
                battlesPlayed: settings.totalBattleCount,
                progress: settings.prehistoricUnlockProgress,
                isCoinAffordable: coins.canAfford(CoinStore.shared.prehistoricCost),
                onCoinUnlock: {
                    if coins.spend(CoinStore.shared.prehistoricCost) {
                        settings.prehistoricUnlocked = true
                        isPresented = false
                    }
                },
                product: store.prehistoricPackProduct,
                fallbackPrice: "$1.99",
                onBuy: {
                    if let p = store.prehistoricPackProduct {
                        return await store.purchase(p)
                    }
                    #if DEBUG
                    settings.prehistoricUnlocked = true
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
