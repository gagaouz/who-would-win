import SwiftUI
import StoreKit

/// A proactive, parent-gated "unlock everything" offer shown ONCE at a happy
/// moment (after the kid has played a bit), rather than only when they tap a
/// locked pack. Leads with the one-time Everything Bundle (highest-converting,
/// no subscription anxiety) and offers a free Premium trial as the alternative.
/// All purchases go through the parental gate.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreKitManager.shared
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isIPad: Bool { sizeClass == .regular }

    @State private var showGate = false
    @State private var pendingPurchase: Product?
    @State private var busy = false
    @State private var statusMessage: String?

    private var bundle: Product? { store.everythingBundleProduct }
    private var premiumAnnual: Product? { store.premiumAnnualProduct }

    var body: some View {
        ZStack {
            SkyBG()

            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Text("✕").font(Kids.fredoka(16, weight: .bold)).foregroundColor(Kids.ink)
                                .frame(width: 44, height: 44)
                                .background(RetroPanelShape().fill(.white).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16).padding(.top, 10)

                    RetroSymbol("🎉", size: 64)
                    StickerWord(text: "UNLOCK EVERYTHING!", fill: Kids.sun, fontSize: isIPad ? 30 : 24, tilt: -2)

                    VStack(spacing: 8) {
                        benefit("🦖", "Every animal pack — Dinos, Fantasy, Mythic & Gods")
                        benefit("🌍", "All battle arenas")
                        benefit("⚔️", "Melee team battles")
                        benefit("🚫", "No more ads")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RetroPanelShape(cornerRadius: 20, style: .continuous).fill(.white)
                            .overlay(RetroPanelShape(cornerRadius: 20, style: .continuous).stroke(Kids.outline, lineWidth: 1.25))
                    )
                    .padding(.horizontal, 20)

                    // Hero: one-time Everything Bundle. While products are still
                    // loading we show a loading label and (re)trigger a load on
                    // tap instead of a dead button.
                    KidButton(title: bundle.map { "GET IT ALL — \($0.displayPrice)" } ?? "Loading…",
                              icon: "🎁", color: Kids.grass, size: .lg) {
                        if bundle != nil {
                            requestPurchase(bundle)
                        } else {
                            statusMessage = "Just a sec — loading the store…"
                            Task { await store.loadProducts() }
                        }
                    }
                    .padding(.horizontal, 24)
                    if let msg = statusMessage {
                        Text(msg).font(Kids.nunito(12, weight: .bold)).foregroundColor(Kids.ink)
                            .multilineTextAlignment(.center).padding(.horizontal, 24)
                    }
                    Text("One-time purchase · yours forever")
                        .font(Kids.nunito(11, weight: .bold)).foregroundColor(Kids.inkSoft)

                    // Alternative: Premium (with free trial when configured).
                    if let prem = premiumAnnual {
                        Button { requestPurchase(prem) } label: {
                            VStack(spacing: 2) {
                                Text(store.introOfferLabel(for: prem) ?? "Go Premium")
                                    .font(Kids.fredoka(15, weight: .bold)).foregroundColor(Kids.ink)
                                Text("then \(prem.displayPrice)/year · everything + 2× coins")
                                    .font(Kids.nunito(10, weight: .bold)).foregroundColor(Kids.inkSoft)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(RetroPanelShape().fill(.white).overlay(RetroPanelShape().stroke(Kids.outline, lineWidth: 1.25)))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 30)
                    }

                    Button { dismiss() } label: {
                        Text("Maybe later")
                            .font(Kids.fredoka(13, weight: .bold)).foregroundColor(Kids.inkSoft).underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    Text("Purchases are approved by a grown-up. Restore anytime in Settings.")
                        .font(Kids.nunito(9, weight: .bold)).foregroundColor(Kids.inkSoft.opacity(0.8))
                        .multilineTextAlignment(.center).padding(.horizontal, 30)

                    Color.clear.frame(height: 24)
                }
                .frame(maxWidth: isIPad ? 560 : .infinity)
                .frame(maxWidth: .infinity)
            }
            if busy { Color.black.opacity(0.2).ignoresSafeArea(); ProgressView().tint(.white) }
        }
        // Every purchase passes through the Kids-Category parental gate.
        .parentGate(isPresented: $showGate) { Task { await purchase() } }
    }

    private func benefit(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            RetroSymbol(emoji, size: 18).frame(width: 24)
            Text(text).font(Kids.nunito(13, weight: .bold)).foregroundColor(Kids.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }

    private func requestPurchase(_ product: Product?) {
        guard let product else { return }
        HapticsService.shared.tap()
        pendingPurchase = product
        showGate = true
    }

    private func purchase() async {
        guard let product = pendingPurchase else { return }
        busy = true
        let outcome = await store.purchase(product)
        busy = false
        switch outcome {
        case .success:
            dismiss()
        case .pending:
            // Ask-to-Buy: the request went to a grown-up. The Transaction.updates
            // listener applies the entitlement when they approve.
            statusMessage = "📨 Asked a grown-up! They'll get a message to approve it."
        case .cancelled:
            statusMessage = nil
        case .failed:
            statusMessage = "Hmm, that didn't go through. Please try again."
        }
    }
}
