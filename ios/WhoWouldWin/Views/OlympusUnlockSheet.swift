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
            Theme.mainBg.ignoresSafeArea()
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Close
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        ZStack {
                            Circle().fill(Theme.cardFill).frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
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
                            Text("⚡️")
                                .font(.system(size: 72))
                                .shadow(color: gold.opacity(0.9), radius: 30, x: 0, y: 0)

                            Text("MOUNT OLYMPUS")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(
                                    colors: [gold, Color(hex: "#FFF8DC"), gold],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .shadow(color: gold.opacity(0.8), radius: 12, x: 0, y: 0)

                            Text("The ultimate pack — 12 Greek gods and legends")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)

                            Text("YOU UNLOCKED ALL PACKS!")
                                .font(.system(size: 11, weight: .black, design: .rounded))
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
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.textTertiary)
                                        .tracking(1.5)
                                    Text("Play 10,000 Battles")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(settings.totalBattleCount)")
                                        .font(.system(size: 22, weight: .black, design: .rounded))
                                        .foregroundColor(gold)
                                    Text("/ 10,000")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.textTertiary)
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
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Theme.cardFill)
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .stroke(gold.opacity(0.25), lineWidth: 1.5))
                        )

                        HStack(spacing: 12) {
                            Rectangle().fill(Theme.divider).frame(height: 1)
                            Text("OR UNLOCK NOW")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textTertiary)
                                .tracking(1.5)
                            Rectangle().fill(Theme.divider).frame(height: 1)
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
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(store.olympusPackProduct.map { $0.displayPrice } ?? "$19.99")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                                if store.isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(LinearGradient(
                                        colors: [purple, Color(hex: "#2A0A5E"), deep],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(gold.opacity(0.6), lineWidth: 1.5)
                                    )
                            )
                            .shadow(color: gold.opacity(0.3), radius: 14, x: 0, y: 5)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(store.isPurchasing)

                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.textTertiary)
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
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
