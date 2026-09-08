import SwiftUI
import StoreKit

// MARK: - Shared Kids-styled unlock sheet
// Replaces the 4 legacy unlock sheets (Fantasy / Prehistoric / Mythic / Olympus)
// with one reusable component that the per-pack wrappers call into.

struct KidsUnlockSheet: View {
    struct Config {
        let title: String           // e.g. "FANTASY PACK"
        let emoji: String           // e.g. "🧚"
        let color: Color            // primary fill
        let darkAccent: Color       // gradient bottom
        let blurb: String           // "12 magical creatures await!"
        let preview: [(String, String)]   // [(emoji, name), …] preview tiles
        let coinCost: Int
        let battleThreshold: Int
        let battlesPlayed: Int
        let progress: Double         // 0…1
        let isCoinAffordable: Bool
        let onCoinUnlock: () -> Void
        let product: Product?
        let fallbackPrice: String
        /// Performs the real-money StoreKit purchase and reports how it ended.
        /// The sheet itself gates this behind the parental gate, dismisses on
        /// `.success`, and shows the Ask-to-Buy notice on `.pending`.
        let onBuy: @MainActor () async -> StoreKitManager.PurchaseOutcome
        let onRestore: () -> Void
    }

    @Binding var isPresented: Bool
    let config: Config

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    @State private var appeared = false
    @State private var heroBob: CGFloat = 0

    // Real-money purchases only — the coin-unlock path stays ungated.
    @State private var showParentGate = false
    @State private var showAskToBuyNotice = false
    @State private var isBuying = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [config.color, config.darkAccent],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Subtle stars
            GeometryReader { _ in
                ForEach(0..<10, id: \.self) { i in
                    let x = CGFloat([22, 340, 60, 320, 90, 280, 40, 310, 70, 330][i])
                    let y = CGFloat([80, 110, 220, 240, 380, 420, 540, 560, 700, 720][i])
                    Text("✦")
                        .font(.system(size: CGFloat(8 + (i % 3) * 2)))
                        .foregroundColor(.white.opacity(0.4))
                        .position(x: x, y: y)
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        ZStack {
                            Circle().fill(.white)
                                .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
                                .frame(width: 36, height: 36)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Kids.ink)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(spacing: 18) {
                        // Hero emoji
                        Text(config.emoji)
                            .font(.system(size: isIPad ? 100 : 76))
                            .offset(y: heroBob)
                            .scaleEffect(appeared ? 1 : 0.3)

                        // Title sticker
                        StickerWord(text: config.title, fill: Kids.sun, fontSize: isIPad ? 44 : 32, tilt: -2)
                            .rotationEffect(.degrees(appeared ? -2 : -15))
                            .scaleEffect(appeared ? 1 : 0.3)

                        Text(config.blurb)
                            .font(Kids.nunito(isIPad ? 16 : 13, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)
                            .padding(.horizontal, 24)

                        // Preview tiles
                        creaturePreview

                        // Free progress card
                        progressCard

                        // Coin unlock
                        coinUnlockButton

                        // OR divider
                        HStack(spacing: 10) {
                            Rectangle().fill(Color.white.opacity(0.35)).frame(height: 1)
                            Text("OR UNLOCK NOW")
                                .font(Kids.fredoka(isIPad ? 13 : 11, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(1)
                            Rectangle().fill(Color.white.opacity(0.35)).frame(height: 1)
                        }

                        // Paid CTA — parental gate first, then StoreKit.
                        KidButton(
                            title: "Get \(config.title.capitalized)",
                            icon: nil,
                            color: Kids.grass, size: .lg
                        ) {
                            HapticsService.shared.tap()
                            guard !isBuying else { return }
                            showParentGate = true
                        }
                        .overlay(
                            Text(config.product.map { $0.displayPrice } ?? config.fallbackPrice)
                                .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                                .foregroundColor(Kids.ink)
                                .padding(.horizontal, 10).padding(.vertical, 3)
                                .background(Capsule().fill(Kids.sun).overlay(Capsule().stroke(Kids.ink, lineWidth: 2)))
                                .offset(x: 0, y: -38)
                                .rotationEffect(.degrees(-2))
                                .allowsHitTesting(false),
                            alignment: .top
                        )

                        HStack(spacing: 6) {
                            Text("👑")
                            Text("Also included with Premium")
                                .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                        }

                        Button {
                            config.onRestore()
                        } label: {
                            Text("Restore purchases")
                                .font(Kids.fredoka(isIPad ? 13 : 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 30)
                        }
                        .padding(.horizontal, 22)
                        .scaleEffect(appeared ? 1 : 0.95)
                        .frame(maxWidth: isIPad ? 640 : .infinity)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                heroBob = -8
            }
        }
        .parentGate(isPresented: $showParentGate) { startPurchase() }
        .alert("📨 Asked your grown-up!", isPresented: $showAskToBuyNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your purchase will unlock when they say yes.")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Runs only after the parental gate has been passed.
    private func startPurchase() {
        guard !isBuying else { return }
        isBuying = true
        Task { @MainActor in
            let outcome = await config.onBuy()
            isBuying = false
            switch outcome {
            case .success:
                isPresented = false
            case .pending:
                showAskToBuyNotice = true
            case .cancelled, .failed:
                break
            }
        }
    }

    private var creaturePreview: some View {
        HStack(spacing: 6) {
            ForEach(0..<config.preview.count, id: \.self) { i in
                let (emoji, name) = config.preview[i]
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(.white)
                            .overlay(Circle().stroke(Kids.ink, lineWidth: 2.5))
                            .frame(width: isIPad ? 56 : 44, height: isIPad ? 56 : 44)
                            .shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 2)
                        Text(emoji).font(.system(size: isIPad ? 30 : 24))
                    }
                    Text(name)
                        .font(Kids.fredoka(isIPad ? 11 : 9, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .rotationEffect(.degrees(Double(i % 2 == 0 ? -2 : 2)))
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FREE PATH")
                        .font(Kids.fredoka(isIPad ? 12 : 10, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                        .tracking(1)
                    Text("Play \(config.battleThreshold) battles")
                        .font(Kids.fredoka(isIPad ? 18 : 15, weight: .bold))
                        .foregroundColor(Kids.ink)
                }
                Spacer()
                Text("\(config.battlesPlayed)/\(config.battleThreshold)")
                    .font(Kids.fredoka(isIPad ? 17 : 14, weight: .bold))
                    .foregroundColor(Kids.ink)
            }
            ProgressPill(progress: config.progress, fill: Kids.grass)
                .frame(height: isIPad ? 17 : 14)
            let remaining = max(0, config.battleThreshold - config.battlesPlayed)
            if remaining > 0 {
                Text("\(remaining) more battle\(remaining == 1 ? "" : "s") to go!")
                    .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                    .foregroundColor(Kids.inkSoft)
            } else {
                Text("✓ You unlocked it for FREE!")
                    .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                    .foregroundColor(Kids.grass)
            }
        }
        .padding(isIPad ? 18 : 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 3))
        )
        .shadow(color: Kids.ink.opacity(0.10), radius: 0, x: 0, y: 4)
    }

    private var coinUnlockButton: some View {
        Button {
            HapticsService.shared.tap()
            config.onCoinUnlock()
        } label: {
            HStack(spacing: 8) {
                KidsGoldCoin(size: isIPad ? 34 : 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Unlock with Coins")
                        .font(Kids.fredoka(isIPad ? 16 : 13, weight: .bold))
                        .foregroundColor(Kids.ink)
                    Text("\(config.coinCost) coins")
                        .font(Kids.nunito(isIPad ? 13 : 11, weight: .bold))
                        .foregroundColor(Kids.inkSoft)
                }
                Spacer()
                Text(config.isCoinAffordable ? "Use Coins" : "Need more")
                    .font(Kids.fredoka(isIPad ? 15 : 12, weight: .bold))
                    .foregroundColor(config.isCoinAffordable ? Kids.ink : Kids.inkSoft)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        Capsule().fill(config.isCoinAffordable ? Kids.sun : Color(hex: "#E8DFF5"))
                            .overlay(Capsule().stroke(Kids.ink, lineWidth: 2))
                    )
            }
            .padding(isIPad ? 16 : 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Kids.ink, lineWidth: 3))
            )
            .shadow(color: Kids.ink.opacity(0.08), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!config.isCoinAffordable)
        .opacity(config.isCoinAffordable ? 1.0 : 0.7)
    }
}
