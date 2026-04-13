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
            Theme.mainBg.ignoresSafeArea()

            // Subtle star shimmer
            SpreadStarField().ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.cardFill)
                                .frame(width: 32, height: 32)
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
                            Text("✨")
                                .font(.system(size: 64))
                                .shadow(color: Theme.fantasyAccent.opacity(0.7), radius: 20, x: 0, y: 0)

                            Text("FANTASY REALM")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Theme.fantasyAccent, Color(hex: "#E040FB"), Color(hex: "#C77DFF")],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .shadow(color: Theme.fantasyAccent.opacity(0.5), radius: 8, x: 0, y: 0)

                            Text("12 legendary creatures await")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
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
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.textTertiary)
                                        .tracking(1.5)
                                    Text("Play 250 Battles")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.textPrimary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text("\(settings.totalBattleCount)")
                                        .font(.system(size: 22, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.fantasyAccent)
                                    Text("/ 250")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(Theme.textTertiary)
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
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Theme.cardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Theme.fantasyAccent.opacity(0.25), lineWidth: 1.5)
                                )
                        )

                        // OR divider
                        HStack(spacing: 12) {
                            Rectangle().fill(Theme.divider).frame(height: 1)
                            Text("OR UNLOCK NOW")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textTertiary)
                                .tracking(1.5)
                            Rectangle().fill(Theme.divider).frame(height: 1)
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
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text(store.fantasyPackProduct.map { $0.displayPrice } ?? "$1.99")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#7B2FBE"), Color(hex: "#4A1080")],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Theme.fantasyAccent.opacity(0.5), lineWidth: 1.5)
                                    )
                            )
                            .shadow(color: Theme.fantasyAccent.opacity(0.35), radius: 12, x: 0, y: 5)
                        }
                        .buttonStyle(PressableButtonStyle())
                        .disabled(store.isPurchasing)

                        // Also included in Premium note
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.gold)
                            Text("Also included in Premium subscription")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.textTertiary)
                        }

                        // Restore
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
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textTertiary)
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
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.fantasyAccent, Color(hex: "#E040FB"), Theme.gold],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Theme.fantasyAccent.opacity(0.6), radius: 8, x: 0, y: 0)

            Text("You've unlocked 12 legendary creatures!")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textSecondary)
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

// MARK: - Olympus milestone banner (shown in BattleView at 10,000 battles)

struct OlympusUnlockedBanner: View {
    @Binding var isShowing: Bool

    private let gold   = Color(hex: "#FFD700")
    private let purple = Color(hex: "#4A0E8F")

    var body: some View {
        VStack(spacing: 8) {
            Text("⚡ MOUNT OLYMPUS UNLOCKED! ⚡")
                .font(.system(size: 16, weight: .black, design: .rounded))
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
