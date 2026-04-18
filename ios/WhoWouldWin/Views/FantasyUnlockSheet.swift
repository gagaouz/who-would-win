import SwiftUI

/// Shown when a user taps a locked fantasy animal or the Fantasy category pill.
/// Two unlock paths: earn 50 battles (free) or buy the $1.99 Fantasy Pack.
struct FantasyUnlockSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var store = StoreKitManager.shared
    @ObservedObject private var settings = UserSettings.shared

    private var battlesRemaining: Int {
        max(0, UserSettings.fantasyBattleThreshold - settings.totalBattleCount)
    }

    private var progress: Double { settings.fantasyUnlockProgress }

    var body: some View {
        ZStack {
            // Background
            ScreenBackground(style: .unlock)

            // Subtle star shimmer
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 32, height: 32)
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
                            Text("✨")
                                .font(.system(size: 64))
                                .shadow(color: Theme.fantasyAccent.opacity(0.7), radius: 20, x: 0, y: 0)

                            Text("FANTASY REALM")
                                .font(Theme.bungee(24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Theme.fantasyAccent, Color(hex: "#E040FB"), Color(hex: "#C77DFF")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .shadow(color: Theme.fantasyAccent.opacity(0.5), radius: 8, x: 0, y: 0)

                            Text("12 legendary creatures await")
                                .font(Theme.bungee(14))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        // Creature preview grid
                        creaturePreviewRow

                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                            .padding(.horizontal, 8)

                        // Free path: Battle progress
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("FREE PATH")
                                        .font(Theme.bungee(11))
                                        .foregroundColor(.white.opacity(0.35))
                                        .tracking(1.5)
                                    Text("Play 250 Battles")
                                        .font(Theme.bungee(17))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(settings.totalBattleCount)")
                                        .font(Theme.bungee(22))
                                        .foregroundColor(Theme.fantasyAccent)
                                    Text("/ 250")
                                        .font(Theme.bungee(13))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                            }

                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Track
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 14)

                                    // Fill
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            LinearGradient(
                                                colors: [Theme.fantasyAccent, Color(hex: "#E040FB")],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(progress), height: 14)
                                        .shadow(color: Theme.fantasyAccent.opacity(0.5), radius: 4, x: 0, y: 0)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                                    // Sparkle at the progress tip
                                    if progress > 0.02 && progress < 1.0 {
                                        Text("✨")
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                                )
                        )

                        // Coin unlock path
                        CoinUnlockSection(
                            cost: CoinStore.shared.fantasyCost,
                            accentColor: Theme.fantasyAccent,
                            onUnlock: {
                                settings.fantasyUnlocked = true
                                isPresented = false
                            }
                        )

                        // OR divider
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                            Text("OR UNLOCK NOW")
                                .font(Theme.bungee(11))
                                .foregroundColor(.white.opacity(0.35))
                                .tracking(1.5)
                            Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                        }

                        // Paid CTA — Fantasy Pack
                        Button {
                            Task {
                                if let product = store.fantasyPackProduct {
                                    let ok = await store.purchase(product)
                                    if ok { isPresented = false }
                                } else {
                                    #if DEBUG
                                    settings.fantasyUnlocked = true
                                    isPresented = false
                                    #else
                                    await store.loadProducts()
                                    #endif
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Text("✨")
                                    .font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Unlock Fantasy Pack")
                                        .font(Theme.bungee(14))
                                    Text(store.fantasyPackProduct.map { $0.displayPrice } ?? "$1.99")
                                        .font(Theme.bungee(12))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                        }
                        .buttonStyle(MegaButtonStyle(color: .purple, height: 58, cornerRadius: 18, fontSize: 17))
                        .disabled(store.isPurchasing)

                        // Also included in Premium note
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.gold)
                            Text("Also included in Premium subscription")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                        }

                        // Restore
                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("RESTORE PURCHASES")
                                .font(Theme.bungee(11))
                                .tracking(1)
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
    }

    // MARK: - Creature preview

    private var creaturePreviewRow: some View {
        let creatures: [(String, String)] = [
            ("🐉", "Dragon"), ("🦄", "Unicorn"), ("🐙", "Kraken"),
            ("🐂", "Minotaur"), ("🔥", "Phoenix"), ("🐲", "Hydra")
        ]
        return HStack(spacing: 0) {
            ForEach(creatures, id: \.0) { emoji, name in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#3B1067").opacity(0.8), Color(hex: "#1A0535")],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Theme.fantasyAccent.opacity(0.3), lineWidth: 1))

                        // Lock overlay
                        Text(emoji)
                            .font(.system(size: 22))
                            .blur(radius: 2.5)
                            .opacity(0.7)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Text(name)
                        .font(Theme.bungee(8))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Milestone celebration shown in BattleView

struct FantasyUnlockedBanner: View {
    @Binding var isShowing: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("✨ FANTASY UNLOCKED! ✨")
                .font(Theme.bungee(18))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.fantasyAccent, Color(hex: "#E040FB"), Theme.gold],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Theme.fantasyAccent.opacity(0.6), radius: 8, x: 0, y: 0)

            Text("You've unlocked 12 legendary creatures!")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.fantasyAccent.opacity(0.5), lineWidth: 1.5)
                )
        )
        .shadow(color: Theme.fantasyAccent.opacity(0.3), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 28)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.4)) { isShowing = false }
            }
        }
    }
}

// MARK: - Tournament milestone banner (shown in BattleView at 30 battles)

struct TournamentUnlockedBanner: View {
    @Binding var isShowing: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("🏆 TOURNAMENT MODE UNLOCKED! 🏆")
                .font(Theme.bungee(16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.gold, Color(hex: "#FFF59D"), Theme.gold],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Theme.gold.opacity(0.6), radius: 8, x: 0, y: 0)
                .multilineTextAlignment(.center)

            Text("Build 4, 8, or 16-fighter brackets!")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.gold.opacity(0.5), lineWidth: 1.5)
                )
        )
        .shadow(color: Theme.gold.opacity(0.3), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 28)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation(.easeOut(duration: 0.4)) { isShowing = false }
            }
        }
    }
}

// MARK: - Olympus milestone banner (shown in BattleView at 10,000 battles)

struct OlympusUnlockedBanner: View {
    @Binding var isShowing: Bool

    private let gold   = Color(hex: "#FFD700")
    private let purple = Color(hex: "#4A0E8F")

    var body: some View {
        VStack(spacing: 8) {
            Text("⚡ MOUNT OLYMPUS UNLOCKED! ⚡")
                .font(Theme.bungee(16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [gold, Color(hex: "#FFF8DC"), gold],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: gold.opacity(0.8), radius: 10, x: 0, y: 0)
                .multilineTextAlignment(.center)

            Text("10,000 battles — the gods await you!")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(colors: [gold.opacity(0.7), purple.opacity(0.5)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: gold.opacity(0.35), radius: 18, x: 0, y: 6)
        .padding(.horizontal, 28)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.4)) { isShowing = false }
            }
        }
    }
}
