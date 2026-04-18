import SwiftUI

/// Shown when the user taps the locked Olympus category.
/// Reveals only after all three other packs are unlocked.
/// Two unlock paths: earn 10,000 battles (free) or buy for $19.99.
struct OlympusUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared
    @State private var showStoreAlert = false

    private var battlesRemaining: Int {
        max(0, UserSettings.olympusBattleThreshold - settings.totalBattleCount)
    }
    private var progress: Double { settings.olympusUnlockProgress }

    private let gold   = Color(hex: "#FFD700")
    private let deep   = Color(hex: "#8B6914")
    private let purple = Color(hex: "#4A0E8F")

    var body: some View {
        ZStack {
            ScreenBackground(style: .unlock)
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Close
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
                            Text("🏛️⚡️🏛️")
                                .font(.system(size: 52))
                                .shadow(color: gold.opacity(0.9), radius: 30, x: 0, y: 0)

                            Text("MOUNT OLYMPUS")
                                .font(Theme.bungee(28))
                                .foregroundStyle(LinearGradient(
                                    colors: [gold, Color(hex: "#FFF8DC"), gold],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .shadow(color: gold.opacity(0.8), radius: 12, x: 0, y: 0)

                            Text("The ultimate pack — 12 Greek gods and legends")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)

                            Text("YOU UNLOCKED ALL PACKS!")
                                .font(Theme.bungee(11))
                                .foregroundColor(gold)
                                .tracking(1.5)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(gold.opacity(0.15))
                                        .overlay(Capsule().stroke(gold.opacity(0.4), lineWidth: 1))
                                )
                        }

                        // God preview
                        godPreviewRow

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
                                    Text("Play 10,000 Battles")
                                        .font(Theme.bungee(17))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(settings.totalBattleCount)")
                                        .font(Theme.bungee(22))
                                        .foregroundColor(gold)
                                    Text("/ 10,000")
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
                                            colors: [purple, gold],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .frame(width: geo.size.width * CGFloat(progress), height: 14)
                                        .shadow(color: gold.opacity(0.6), radius: 4, x: 0, y: 0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
                                    if progress > 0.01 && progress < 1.0 {
                                        Text("⚡️")
                                            .font(.system(size: 10))
                                            .offset(x: geo.size.width * CGFloat(progress) - 8, y: -1)
                                    }
                                }
                            }
                            .frame(height: 14)

                            if battlesRemaining > 0 {
                                Text("\(battlesRemaining.formatted()) more battle\(battlesRemaining == 1 ? "" : "s") to go!")
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
                            cost: CoinStore.shared.olympusCost,
                            accentColor: gold,
                            onUnlock: {
                                settings.olympusUnlocked = true
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
                                if let product = store.olympusPackProduct {
                                    let ok = await store.purchase(product)
                                    if ok { isPresented = false }
                                } else {
                                    #if DEBUG
                                    settings.olympusUnlocked = true
                                    isPresented = false
                                    #else
                                    await store.loadProducts()
                                    showStoreAlert = true
                                    #endif
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text("⚡️").font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Mount Olympus Pack")
                                        .font(Theme.bungee(14))
                                    Text(store.olympusPackProduct.map { $0.displayPrice } ?? "$19.99")
                                        .font(Theme.bungee(12))
                                }
                                Spacer()
                                if store.isPurchasing {
                                    ProgressView().tint(Color(hex: "#1A237E"))
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                }
                            }
                        }
                        .buttonStyle(MegaButtonStyle(color: .gold, height: 58, cornerRadius: 18, fontSize: 17))
                        .disabled(store.isPurchasing)

                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(Theme.bungee(13))
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

    private var godPreviewRow: some View {
        let gods: [(String, String)] = [
            ("⚡️", "Zeus"), ("🔱", "Poseidon"), ("💀", "Hades"),
            ("🪖", "Ares"), ("🦉", "Athena"), ("☀️", "Apollo")
        ]
        return HStack(spacing: 0) {
            ForEach(gods, id: \.1) { pair in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#2A1A00").opacity(0.9), Color(hex: "#0D0800")],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(gold.opacity(0.4), lineWidth: 1))
                        Text(pair.0).font(.system(size: 22)).blur(radius: 2.5).opacity(0.7)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(gold.opacity(0.9))
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
