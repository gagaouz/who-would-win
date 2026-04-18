import SwiftUI

/// Shown when a user taps a locked mythic animal or the Mythic category pill.
/// Two unlock paths: earn 500 battles (free) or buy the Mythic Beasts Pack.
struct MythicUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var showStoreAlert = false

    private var battlesRemaining: Int {
        max(0, UserSettings.mythicBattleThreshold - settings.totalBattleCount)
    }
    private var progress: Double { settings.mythicUnlockProgress }

    private let accent = Color(hex: "#C0A000")
    private let deep   = Color(hex: "#7A6600")

    var body: some View {
        ZStack {
            ScreenBackground(style: .unlock)
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        ZStack {
                            Circle().fill(.ultraThinMaterial).frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 8) {
                            Text("⚡")
                                .font(.system(size: 64))
                                .shadow(color: accent.opacity(0.7), radius: 20, x: 0, y: 0)

                            Text("MYTHIC BEASTS")
                                .font(Theme.bungee(24))
                                .foregroundStyle(LinearGradient(
                                    colors: [accent, Theme.orange],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .shadow(color: accent.opacity(0.5), radius: 8, x: 0, y: 0)

                            Text("12 legendary beasts from ancient mythology")
                                .font(Theme.bungee(14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }

                        // Creature preview grid
                        creaturePreviewRow

                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 8)

                        // Free path
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("FREE PATH")
                                        .font(Theme.bungee(11))
                                        .foregroundColor(.white.opacity(0.35))
                                        .tracking(1.5)
                                    Text("Play 500 Battles")
                                        .font(Theme.bungee(17))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(settings.totalBattleCount)")
                                        .font(Theme.bungee(22))
                                        .foregroundColor(accent)
                                    Text("/ 500")
                                        .font(Theme.bungee(13))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 14)
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(LinearGradient(
                                            colors: [accent, Theme.orange],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .frame(width: geo.size.width * CGFloat(progress), height: 14)
                                        .shadow(color: accent.opacity(0.5), radius: 4, x: 0, y: 0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                                    if progress > 0.02 && progress < 1.0 {
                                        Text("⚡")
                                            .font(.system(size: 10))
                                            .offset(x: geo.size.width * CGFloat(progress) - 8, y: -1)
                                    }
                                }
                            }
                            .frame(height: 14)

                            if battlesRemaining > 0 {
                                Text("\(battlesRemaining) more battle\(battlesRemaining == 1 ? "" : "s") to go!")
                                    .font(Theme.bungee(13))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                        )

                        // Coin unlock path
                        CoinUnlockSection(
                            cost: CoinStore.shared.mythicCost,
                            accentColor: accent,
                            onUnlock: {
                                settings.mythicUnlocked = true
                                isPresented = false
                            }
                        )

                        HStack(spacing: 12) {
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                            Text("OR UNLOCK NOW")
                                .font(Theme.bungee(11))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(1.5)
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                        }

                        // Purchase button
                        Button {
                            Task {
                                if let product = store.mythicPackProduct {
                                    let ok = await store.purchase(product)
                                    if ok { isPresented = false }
                                } else {
                                    #if DEBUG
                                    settings.mythicUnlocked = true
                                    isPresented = false
                                    #else
                                    await store.loadProducts()
                                    showStoreAlert = true
                                    #endif
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text("⚡").font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Mythic Beasts Pack")
                                        .font(Theme.bungee(14))
                                    Text(store.mythicPackProduct.map { $0.displayPrice } ?? "$2.99")
                                        .font(Theme.bungee(12))
                                }
                                Spacer()
                                if store.isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                }
                            }
                        }
                        .buttonStyle(MegaButtonStyle(color: .orange, height: 58, cornerRadius: 18, fontSize: 17))
                        .disabled(store.isPurchasing)

                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill").font(.system(size: 11)).foregroundColor(Theme.gold)
                            Text("Also included in Premium subscription")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }

                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("Store Unavailable", isPresented: $showStoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Couldn't load products. Please check your connection and try again.")
        }
    }

    private var creaturePreviewRow: some View {
        let creatures: [(String, String)] = [
            ("🦅", "Thunder"), ("🦁", "Manticore"), ("🐉", "Wyvern"),
            ("🦄", "Kirin"), ("🦅", "Roc"), ("🐇", "Jackalope")
        ]
        return HStack(spacing: 0) {
            ForEach(creatures, id: \.1) { pair in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#332D08").opacity(0.8), Color(hex: "#1A1604")],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(accent.opacity(0.3), lineWidth: 1))
                        Text(pair.0).font(.system(size: 22)).blur(radius: 2.5).opacity(0.7)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Text(pair.1)
                        .font(Theme.bungee(8))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
