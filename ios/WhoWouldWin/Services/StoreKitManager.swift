import StoreKit
import Combine

/// StoreKit 2 manager.  Handles loading products, purchasing, and restoring.
/// Works gracefully when products aren't yet configured in App Store Connect —
/// every method just silently does nothing / returns false.
@MainActor
final class StoreKitManager: ObservableObject {

    static let shared = StoreKitManager()

    // MARK: - Product IDs

    static let removeAdsID       = "com.whowouldin.removeads"
    static let premiumMonthlyID  = "com.whowouldin.premium.monthly"
    static let premiumAnnualID   = "com.whowouldin.premium.annual"
    static let fantasyPackID     = "com.whowouldin.fantasypack"
    static let prehistoricPackID = "com.whowouldin.prehistoricpack"
    static let mythicPackID      = "com.whowouldin.mythicpack"
    static let olympusPackID      = "com.whowouldin.olympuspack"
    // NOTE: was "com.whowouldin.WhoWouldWin.melee_pack" — a product that never
    // existed in App Store Connect, so the melee Buy button could never load.
    // Renamed to match the com.whowouldin.* convention; safe because no
    // purchase of the old ID can exist.
    static let meleePackID        = "com.whowouldin.meleepack"
    static let environmentsPackID = "com.whowouldin.environmentspack"
    static let coins1000ID        = "com.whowouldin.coins1000"   // consumable: 1000 coins for $1.99
    // Bigger coin tiers — a "best value" ladder so players are funnelled toward
    // a purchase instead of facing a single $1.99/1k option next to a 100k god.
    // NOTE: these must be CREATED in App Store Connect (consumables) before the
    // buttons appear; until then they simply don't load (handled gracefully).
    static let coins5000ID        = "com.whowouldin.coins5000"   // ~$6.99
    static let coins12000ID       = "com.whowouldin.coins12000"  // ~$12.99 (best value)
    /// One-time "everything" purchase: every creature pack + arenas + melee + remove ads.
    static let everythingBundleID = "com.whowouldin.everythingbundle"

    static let allProductIDs: Set<String> = [
        removeAdsID, premiumMonthlyID, premiumAnnualID,
        fantasyPackID, prehistoricPackID, mythicPackID, olympusPackID,
        meleePackID, environmentsPackID, coins1000ID, coins5000ID, coins12000ID,
        everythingBundleID
    ]

    /// "Try 7 days FREE" style label when a subscription has a free-trial intro
    /// offer AND this Apple ID is still eligible for it; nil otherwise. Gating on
    /// eligibility avoids promising a free trial to a user who'd be charged.
    func introOfferLabel(for product: Product?) -> String? {
        guard premiumIntroEligible,
              let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        let unit: String
        switch p.unit {
        case .day:   unit = p.value == 1 ? "day" : "days"
        case .week:  unit = p.value == 1 ? "week" : "weeks"
        case .month: unit = p.value == 1 ? "month" : "months"
        case .year:  unit = p.value == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        return "Try \(p.value) \(unit) FREE"
    }

    // MARK: - Published state

    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var lastError: String? = nil
    /// Whether THIS Apple ID can still receive the Premium free-trial intro offer
    /// (false once consumed). Computed after products load; gates the trial label
    /// so we never advertise "free trial" to someone who'd be charged immediately.
    @Published private(set) var premiumIntroEligible = false

    // Convenience
    var removeAdsProduct:      Product? { products.first { $0.id == Self.removeAdsID } }
    var premiumMonthlyProduct: Product? { products.first { $0.id == Self.premiumMonthlyID } }
    var premiumAnnualProduct:  Product? { products.first { $0.id == Self.premiumAnnualID } }
    var fantasyPackProduct:    Product? { products.first { $0.id == Self.fantasyPackID } }
    var prehistoricPackProduct: Product? { products.first { $0.id == Self.prehistoricPackID } }
    var mythicPackProduct:      Product? { products.first { $0.id == Self.mythicPackID } }
    var olympusPackProduct:       Product? { products.first { $0.id == Self.olympusPackID } }
    var meleePackProduct:         Product? { products.first { $0.id == Self.meleePackID } }
    var environmentsPackProduct:  Product? { products.first { $0.id == Self.environmentsPackID } }
    var coins1000Product:         Product? { products.first { $0.id == Self.coins1000ID } }
    var everythingBundleProduct:  Product? { products.first { $0.id == Self.everythingBundleID } }

    // MARK: - Init

    private var transactionListenerTask: Task<Void, Never>?

    private init() {
        transactionListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Load products

    /// Load products from App Store Connect. Retries on transient failures so
    /// the reviewer / user doesn't end up with an empty Buy button because of
    /// a flaky first network call.
    func loadProducts() async {
        // Up to 4 attempts with growing backoff (≈ 0.5s, 1.5s, 4.5s)
        for attempt in 0..<4 {
            do {
                let fetched = try await Product.products(for: Self.allProductIDs)
                if !fetched.isEmpty {
                    products = fetched.sorted { $0.price < $1.price }
                    // Intro-offer eligibility is per subscription group; checking
                    // one Premium product is enough. Drives whether we show the
                    // "free trial" label at all.
                    if let sub = (premiumAnnualProduct ?? premiumMonthlyProduct)?.subscription {
                        premiumIntroEligible = await sub.isEligibleForIntroOffer
                    }
                    return
                }
            } catch {
                // swallow and retry
            }
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: UInt64(0.5 * pow(3.0, Double(attempt)) * 1_000_000_000))
            }
        }
        // Give up silently — UI handles missing product by showing fallback text
        // and triggering another reload when the user actually taps Buy.
    }

    // MARK: - Purchase

    /// How a purchase attempt ended. `.pending` means Ask to Buy — the kid's
    /// request was sent to a parent/guardian and the entitlement will be
    /// applied by the `Transaction.updates` listener if/when they approve.
    enum PurchaseOutcome: Equatable {
        case success
        case pending
        case cancelled
        case failed
    }

    @discardableResult
    func purchase(_ product: Product) async -> PurchaseOutcome {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await applyEntitlement(for: transaction)
                await transaction.finish()
                return .success
            case .pending:
                // Ask to Buy — waiting for a parent/guardian to approve.
                // listenForTransactions() applies the entitlement when the
                // approved transaction arrives via Transaction.updates.
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            lastError = error.localizedDescription
            return .failed
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Entitlement checks

    /// Full reconciliation: recompute every entitlement flag from the CURRENT
    /// active transactions, so a cancelled/refunded/expired subscription
    /// actually DROPS its benefits (no-ads, packs, 2× coins). Permanent
    /// purchases (individual packs, the Everything Bundle) stay in
    /// currentEntitlements, so they survive. Called on launch.
    func refreshEntitlements() async {
        // StoreKit-readiness guard: only reconcile when StoreKit is actually
        // responsive. Otherwise a transient blank snapshot at cold launch could
        // momentarily strip a paying subscriber. currentEntitlements is cached/
        // offline-safe once products have loaded.
        if products.isEmpty { await loadProducts() }

        var active = Set<String>()
        var sawAny = false
        for await result in Transaction.currentEntitlements {
            sawAny = true
            if let transaction = try? checkVerified(result) {
                active.insert(transaction.productID)
                // Consumables (coin packs) still need exactly-once processing.
                if let coins = Self.coinAmount(for: transaction.productID),
                   markConsumableProcessed(transaction.id) {
                    CoinStore.shared.awardCoinPurchase(coins)
                }
                await transaction.finish()
            }
        }
        // If StoreKit never came up (no products AND no entitlements seen), skip
        // — don't revoke a subscriber off a blank, untrustworthy snapshot.
        guard !products.isEmpty || sawAny else { return }
        applyActiveEntitlements(active)
    }

    /// Reconcile entitlement flags from the CURRENT active transactions.
    ///
    /// Only `isSubscribed` is REVOCABLE — it's the sole subscription flag, and a
    /// cancelled/refunded/expired sub must drop it (the rest of premium's value —
    /// no-ads, all packs, 2× coins — flows through the computed `isXUnlocked`/ad
    /// checks that OR-in `isSubscribed`, so it drops automatically).
    ///
    /// The PERMANENT bools are only ever ADDED here, never cleared — because the
    /// same stored bool can also have been set by a COIN redemption or a free
    /// battle-milestone, which leave no StoreKit transaction. Clearing them would
    /// wipe a coin-bought pack the kid already paid coins for.
    private func applyActiveEntitlements(_ active: Set<String>) {
        let s = UserSettings.shared
        let hasPremium = active.contains(Self.premiumMonthlyID) || active.contains(Self.premiumAnnualID)
        let hasBundle  = active.contains(Self.everythingBundleID)
        s.isSubscribed = hasPremium   // the ONLY revocable flag

        if active.contains(Self.removeAdsID)       || hasBundle { s.hasRemovedAds = true }
        if active.contains(Self.fantasyPackID)     || hasBundle { s.fantasyUnlocked = true }
        if active.contains(Self.prehistoricPackID) || hasBundle { s.prehistoricUnlocked = true }
        if active.contains(Self.mythicPackID)      || hasBundle { s.mythicUnlocked = true }
        if active.contains(Self.olympusPackID)     || hasBundle { s.olympusUnlocked = true }
        if active.contains(Self.meleePackID)       || hasBundle { s.meleeUnlocked = true }
        if active.contains(Self.environmentsPackID) || hasBundle { s.environmentsUnlocked = true }
    }

    // MARK: - Private helpers

    private func applyEntitlement(for transaction: Transaction) async {
        switch transaction.productID {
        case Self.removeAdsID:
            UserSettings.shared.hasRemovedAds = true
        case Self.premiumMonthlyID, Self.premiumAnnualID:
            // Premium grants ONLY the revocable subscription flag. Its no-ads /
            // all-packs / 2× coins value is delivered through the computed
            // isXUnlocked + ad checks that OR-in isSubscribed — so when the sub
            // lapses, that access correctly disappears (instead of being baked
            // into permanent bools that could never be revoked).
            UserSettings.shared.isSubscribed = true
        case Self.everythingBundleID:
            // One-time bundle: every pack + arenas + melee + no ads. Permanent.
            UserSettings.shared.hasRemovedAds        = true
            UserSettings.shared.fantasyUnlocked      = true
            UserSettings.shared.prehistoricUnlocked  = true
            UserSettings.shared.mythicUnlocked       = true
            UserSettings.shared.olympusUnlocked      = true
            UserSettings.shared.meleeUnlocked        = true
            UserSettings.shared.environmentsUnlocked = true
        case Self.fantasyPackID:
            UserSettings.shared.fantasyUnlocked = true
        case Self.prehistoricPackID:
            UserSettings.shared.prehistoricUnlocked = true
        case Self.mythicPackID:
            UserSettings.shared.mythicUnlocked = true
        case Self.olympusPackID:
            UserSettings.shared.olympusUnlocked = true
        case Self.meleePackID:
            UserSettings.shared.meleeUnlocked = true
        case Self.environmentsPackID:
            UserSettings.shared.environmentsUnlocked = true
        case Self.coins1000ID, Self.coins5000ID, Self.coins12000ID:
            // Consumable — award coins exactly once per transaction ID.
            // The same transaction can be delivered more than once (e.g. via
            // purchase() AND Transaction.updates if a finish() never reached
            // the App Store), so record the ID before awarding. Both happen
            // synchronously on the MainActor with no suspension in between,
            // making the check-record-award effectively atomic.
            if let coins = Self.coinAmount(for: transaction.productID),
               markConsumableProcessed(transaction.id) {
                CoinStore.shared.awardCoinPurchase(coins)
            }
        default:
            break
        }
    }

    /// Coins granted by a consumable product ID, or nil if not a coin pack.
    static func coinAmount(for productID: String) -> Int? {
        switch productID {
        case coins1000ID:  return 1000
        case coins5000ID:  return 5000
        case coins12000ID: return 12000
        default:           return nil
        }
    }

    // MARK: - Consumable idempotency

    private static let processedConsumableIDsKey = "iap.processedConsumableTxIDs"

    /// Records a finished consumable transaction ID. Returns `true` if the ID
    /// was newly recorded (caller should award), `false` if it was already
    /// processed (caller must skip the award — but still finish the transaction).
    private func markConsumableProcessed(_ id: UInt64) -> Bool {
        let key = String(id)
        var ids = UserDefaults.standard.stringArray(forKey: Self.processedConsumableIDsKey) ?? []
        guard !ids.contains(key) else { return false }
        ids.append(key)
        UserDefaults.standard.set(ids, forKey: Self.processedConsumableIDsKey)
        return true
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    /// Background listener for transactions that complete outside the app
    /// (e.g. Ask-to-Buy approvals, subscription renewals).
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    // Reconcile the FULL entitlement set on every update so that
                    // renewals, new purchases AND revocations/refunds/expirations
                    // are all reflected (a refund must drop the benefit, not just
                    // a purchase grant it).
                    await self.refreshEntitlements()
                }
            }
        }
    }
}
