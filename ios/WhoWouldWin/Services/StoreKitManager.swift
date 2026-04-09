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

    static let allProductIDs: Set<String> = [
        removeAdsID, premiumMonthlyID, premiumAnnualID,
        fantasyPackID, prehistoricPackID, mythicPackID
    ]

    // MARK: - Published state

    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var lastError: String? = nil

    // Convenience
    var removeAdsProduct:      Product? { products.first { $0.id == Self.removeAdsID } }
    var premiumMonthlyProduct: Product? { products.first { $0.id == Self.premiumMonthlyID } }
    var premiumAnnualProduct:  Product? { products.first { $0.id == Self.premiumAnnualID } }
    var fantasyPackProduct:    Product? { products.first { $0.id == Self.fantasyPackID } }
    var prehistoricPackProduct: Product? { products.first { $0.id == Self.prehistoricPackID } }
    var mythicPackProduct:      Product? { products.first { $0.id == Self.mythicPackID } }

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

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            // Products not configured in ASC yet — that's fine for now
            products = []
        }
    }

    // MARK: - Purchase

    /// Returns `true` if the purchase completed and was verified.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await applyEntitlement(for: transaction.productID)
                await transaction.finish()
                return true
            case .pending:
                // Waiting for Ask-to-Buy approval — nothing to do right now
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
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

    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                await applyEntitlement(for: transaction.productID)
                await transaction.finish()
            }
        }
    }

    // MARK: - Private helpers

    private func applyEntitlement(for productID: String) async {
        switch productID {
        case Self.removeAdsID:
            UserSettings.shared.hasRemovedAds = true
        case Self.premiumMonthlyID, Self.premiumAnnualID:
            UserSettings.shared.isSubscribed        = true
            UserSettings.shared.hasRemovedAds       = true  // premium removes ads
            UserSettings.shared.fantasyUnlocked     = true  // premium unlocks all packs
            UserSettings.shared.prehistoricUnlocked = true
            UserSettings.shared.mythicUnlocked      = true
        case Self.fantasyPackID:
            UserSettings.shared.fantasyUnlocked = true
        case Self.prehistoricPackID:
            UserSettings.shared.prehistoricUnlocked = true
        case Self.mythicPackID:
            UserSettings.shared.mythicUnlocked = true
        default:
            break
        }
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
                    await self.applyEntitlement(for: transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }
}
