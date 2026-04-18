package com.whowouldin.whowouldwin.service

import android.app.Activity
import android.content.Context
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ConsumeParams
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Android port of iOS StoreKitManager.swift using Google Play Billing Library 7.
 *
 * Product IDs mirror the iOS bundle. Reuse the same dotted identifiers in Play
 * Console: one-time "inapp" for packs/removeAds, and two "subs" for monthly/annual.
 *
 * State is exposed via StateFlows:
 *   - products     — the resolved ProductDetails list
 *   - purchases    — all currently active Purchase objects
 *   - isConnected  — BillingClient connection state
 *
 * Singleton — access via BillingManager.instance(context).
 */
class BillingManager private constructor(private val appContext: Context) : PurchasesUpdatedListener {

    companion object {
        private const val TAG = "BillingManager"

        // MARK: - Product IDs (verbatim from iOS StoreKitManager)
        const val REMOVE_ADS_ID        = "com.whowouldin.removeads"
        const val PREMIUM_MONTHLY_ID   = "com.whowouldin.premium.monthly"
        const val PREMIUM_ANNUAL_ID    = "com.whowouldin.premium.annual"
        const val FANTASY_PACK_ID      = "com.whowouldin.fantasypack"
        const val PREHISTORIC_PACK_ID  = "com.whowouldin.prehistoricpack"
        const val MYTHIC_PACK_ID       = "com.whowouldin.mythicpack"
        const val OLYMPUS_PACK_ID      = "com.whowouldin.olympuspack"
        const val ENVIRONMENTS_PACK_ID = "com.whowouldin.environmentspack"
        const val COINS_1000_ID        = "com.whowouldin.coins1000"

        /** One-time purchases (INAPP). */
        val inappProductIds: List<String> = listOf(
            REMOVE_ADS_ID, FANTASY_PACK_ID, PREHISTORIC_PACK_ID, MYTHIC_PACK_ID,
            OLYMPUS_PACK_ID, ENVIRONMENTS_PACK_ID, COINS_1000_ID,
        )

        /** Subscriptions (SUBS). */
        val subsProductIds: List<String> = listOf(PREMIUM_MONTHLY_ID, PREMIUM_ANNUAL_ID)

        /** Consumable products — must be consumed after purchase (not just acknowledged). */
        val consumableProductIds: Set<String> = setOf(COINS_1000_ID)

        @Volatile private var INSTANCE: BillingManager? = null

        fun instance(context: Context): BillingManager =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: BillingManager(context.applicationContext).also { INSTANCE = it }
            }
    }

    // region Public state

    private val _products = MutableStateFlow<List<ProductDetails>>(emptyList())
    val products: StateFlow<List<ProductDetails>> = _products.asStateFlow()

    private val _purchases = MutableStateFlow<List<Purchase>>(emptyList())
    val purchases: StateFlow<List<Purchase>> = _purchases.asStateFlow()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    // endregion

    private val billingClient: BillingClient = BillingClient.newBuilder(appContext)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    /** Establishes the connection to Play Billing and kicks off initial queries. */
    fun connect(onReady: (() -> Unit)? = null) {
        if (_isConnected.value) { onReady?.invoke(); return }
        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingServiceDisconnected() {
                _isConnected.value = false
                Log.w(TAG, "Billing service disconnected.")
            }
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    _isConnected.value = true
                    queryProducts()
                    queryPurchases()
                    onReady?.invoke()
                } else {
                    _isConnected.value = false
                    _lastError.value = result.debugMessage
                    Log.w(TAG, "Billing setup failed: ${result.debugMessage}")
                }
            }
        })
    }

    // region Queries

    private fun queryProducts() {
        fun buildParams(ids: List<String>, type: String): QueryProductDetailsParams =
            QueryProductDetailsParams.newBuilder()
                .setProductList(ids.map { id ->
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(id)
                        .setProductType(type)
                        .build()
                })
                .build()

        billingClient.queryProductDetailsAsync(
            buildParams(inappProductIds, BillingClient.ProductType.INAPP)
        ) { _, inappList ->
            billingClient.queryProductDetailsAsync(
                buildParams(subsProductIds, BillingClient.ProductType.SUBS)
            ) { _, subsList ->
                _products.value = (inappList + subsList)
            }
        }
    }

    private fun queryPurchases() {
        val inappParams = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.INAPP).build()
        val subsParams = QueryPurchasesParams.newBuilder()
            .setProductType(BillingClient.ProductType.SUBS).build()
        billingClient.queryPurchasesAsync(inappParams) { _, inappPurchases ->
            billingClient.queryPurchasesAsync(subsParams) { _, subsPurchases ->
                val all = inappPurchases + subsPurchases
                _purchases.value = all
                all.forEach { handlePurchase(it) }
            }
        }
    }

    /** Re-queries owned purchases. Mirrors iOS restorePurchases(). */
    fun restorePurchases() {
        if (!_isConnected.value) {
            connect { queryPurchases() }
        } else {
            queryPurchases()
        }
    }

    // endregion

    // region Purchase

    /**
     * Launch the purchase flow. `productId` must map to an already-loaded ProductDetails.
     * Returns false synchronously if the flow couldn't even be launched.
     */
    fun purchase(activity: Activity, productId: String): Boolean {
        val details = _products.value.firstOrNull { it.productId == productId } ?: run {
            _lastError.value = "Product not loaded: $productId"
            return false
        }

        val offerToken = details.subscriptionOfferDetails?.firstOrNull()?.offerToken
        val productParams = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .apply { if (offerToken != null) setOfferToken(offerToken) }
            .build()

        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(productParams))
            .build()

        val result = billingClient.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            _lastError.value = result.debugMessage
            return false
        }
        return true
    }

    // endregion

    // region PurchasesUpdatedListener

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode == BillingClient.BillingResponseCode.OK && purchases != null) {
            purchases.forEach { handlePurchase(it) }
            _purchases.value = purchases.toList()
        } else if (result.responseCode == BillingClient.BillingResponseCode.USER_CANCELED) {
            // User cancelled — nothing to do.
        } else {
            _lastError.value = result.debugMessage
            Log.w(TAG, "Purchases updated error: ${result.debugMessage}")
        }
    }

    // endregion

    // region Acknowledge / Consume

    private fun handlePurchase(purchase: Purchase) {
        if (purchase.purchaseState != Purchase.PurchaseState.PURCHASED) return

        // Apply entitlements for every product in the purchase.
        purchase.products.forEach { applyEntitlement(it) }

        // Consumables must be consumed (not acknowledged) — consume implies ack.
        val hasConsumable = purchase.products.any { it in consumableProductIds }
        if (hasConsumable) {
            val params = ConsumeParams.newBuilder().setPurchaseToken(purchase.purchaseToken).build()
            billingClient.consumeAsync(params) { res, _ ->
                if (res.responseCode != BillingClient.BillingResponseCode.OK) {
                    Log.w(TAG, "Consume failed: ${res.debugMessage}")
                }
            }
        } else {
            acknowledgeInAppPurchase(purchase)
        }
    }

    /** Public so callers can re-acknowledge if necessary. */
    fun acknowledgeInAppPurchase(purchase: Purchase) {
        if (purchase.isAcknowledged) return
        val params = AcknowledgePurchaseParams.newBuilder()
            .setPurchaseToken(purchase.purchaseToken)
            .build()
        billingClient.acknowledgePurchase(params) { res ->
            if (res.responseCode != BillingClient.BillingResponseCode.OK) {
                Log.w(TAG, "Acknowledge failed: ${res.debugMessage}")
            }
        }
    }

    private fun applyEntitlement(productId: String) {
        val settings = com.whowouldin.whowouldwin.data.UserSettings.instance(appContext)
        when (productId) {
            REMOVE_ADS_ID -> settings.setHasRemovedAds(true)
            PREMIUM_MONTHLY_ID, PREMIUM_ANNUAL_ID -> {
                settings.setIsSubscribed(true)
                settings.setHasRemovedAds(true)
                settings.setFantasyUnlocked(true)
                settings.setPrehistoricUnlocked(true)
                settings.setMythicUnlocked(true)
                settings.setEnvironmentsUnlocked(true)
            }
            FANTASY_PACK_ID      -> settings.setFantasyUnlocked(true)
            PREHISTORIC_PACK_ID  -> settings.setPrehistoricUnlocked(true)
            MYTHIC_PACK_ID       -> settings.setMythicUnlocked(true)
            OLYMPUS_PACK_ID      -> settings.setOlympusUnlocked(true)
            ENVIRONMENTS_PACK_ID -> settings.setEnvironmentsUnlocked(true)
            COINS_1000_ID -> {
                com.whowouldin.whowouldwin.service.CoinStore.instance(appContext)
                    .awardCoinPurchase(1000)
            }
        }
    }

    // endregion
}
