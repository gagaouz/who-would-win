package com.whowouldin.whowouldwin.service

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.MobileAds
import com.google.android.gms.ads.RequestConfiguration
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.google.android.gms.ads.rewarded.RewardedAd
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Android port of iOS AdManager.swift.
 *
 * Uses Google Mobile Ads SDK 23.4.0. Defaults to Google's TEST ad unit IDs —
 * replace in a RELEASE build before shipping.
 *
 * Public surface mirrors iOS:
 *   - configure(context)                          — COPPA/underage flags + init
 *   - preloadInterstitialIfNeeded()
 *   - preloadRewardedIfNeeded()
 *   - preloadRewardedForCoinsIfNeeded()
 *   - showInterstitialIfNeeded(activity, completion)
 *   - showRewardedAdForCustomCreature(activity, completion)
 *   - showRewardedAdForCoins(activity, completion)
 *   - userHasPaidForAdRemoval(): Boolean
 *
 * Reward callbacks fire with `true` if the user earned the reward.
 */
class AdManager private constructor(private val appContext: Context) {

    // region Ad Unit IDs — TEST defaults
    //
    // From https://developers.google.com/admob/android/test-ads:
    //   App ID (manifest):              ca-app-pub-3940256099942544~3347511713
    //   Interstitial:                   ca-app-pub-3940256099942544/1033173712
    //   Rewarded:                       ca-app-pub-3940256099942544/5224354917
    //
    // These can be overridden per-build-variant by providing BuildConfig fields
    // later; kept as constants here for clarity.

    private val interstitialAdUnitId = "ca-app-pub-3940256099942544/1033173712"
    private val rewardedAdUnitId     = "ca-app-pub-3940256099942544/5224354917"
    private val coinRewardedAdUnitId = "ca-app-pub-3940256099942544/5224354917"

    // endregion

    // region State

    private var interstitial: InterstitialAd? = null
    private var rewardedAd: RewardedAd? = null
    private var rewardedAdForCoins: RewardedAd? = null

    private val _isShowingAd = MutableStateFlow(false)
    val isShowingAd: StateFlow<Boolean> = _isShowingAd.asStateFlow()

    private val _coinAdReady = MutableStateFlow(false)
    val coinAdReady: StateFlow<Boolean> = _coinAdReady.asStateFlow()

    // endregion

    /** True when the user has paid to remove ads. */
    fun userHasPaidForAdRemoval(): Boolean {
        val settings = com.whowouldin.whowouldwin.data.UserSettings.instance(appContext)
        return settings.hasRemovedAdsNow || settings.isSubscribedNow
    }

    // region Preloading

    fun preloadAll() {
        preloadInterstitialIfNeeded()
        preloadRewardedIfNeeded()
        preloadRewardedForCoinsIfNeeded()
    }

    fun preloadInterstitialIfNeeded() {
        if (userHasPaidForAdRemoval() || interstitial != null) return
        InterstitialAd.load(
            appContext,
            interstitialAdUnitId,
            buildRequest(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(ad: InterstitialAd) {
                    interstitial = ad
                    Log.d(TAG, "Interstitial loaded.")
                }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    interstitial = null
                    Log.w(TAG, "Interstitial failed to load: ${error.message}")
                }
            }
        )
    }

    fun preloadRewardedIfNeeded() {
        if (userHasPaidForAdRemoval() || rewardedAd != null) return
        RewardedAd.load(
            appContext,
            rewardedAdUnitId,
            buildRequest(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewardedAd = ad
                    Log.d(TAG, "Rewarded ad loaded.")
                }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    rewardedAd = null
                    Log.w(TAG, "Rewarded failed to load: ${error.message}")
                }
            }
        )
    }

    fun preloadRewardedForCoinsIfNeeded() {
        if (rewardedAdForCoins != null) return
        RewardedAd.load(
            appContext,
            coinRewardedAdUnitId,
            buildRequest(),
            object : RewardedAdLoadCallback() {
                override fun onAdLoaded(ad: RewardedAd) {
                    rewardedAdForCoins = ad
                    _coinAdReady.value = true
                    Log.d(TAG, "Coin rewarded ad loaded.")
                }
                override fun onAdFailedToLoad(error: LoadAdError) {
                    rewardedAdForCoins = null
                    _coinAdReady.value = false
                    Log.w(TAG, "Coin rewarded failed to load: ${error.message}")
                }
            }
        )
    }

    // endregion

    // region Show

    /**
     * Shows an interstitial if allowed (user hasn't paid AND UserSettings.shouldShowAd).
     * Completion fires when the ad is dismissed OR immediately if skipped.
     */
    fun showInterstitialIfNeeded(activity: Activity, completion: (() -> Unit)? = null) {
        if (userHasPaidForAdRemoval()) {
            completion?.invoke(); preloadInterstitialIfNeeded(); return
        }
        val shouldShow = com.whowouldin.whowouldwin.data.UserSettings.instance(appContext).shouldShowAd
        if (!shouldShow) {
            completion?.invoke(); preloadInterstitialIfNeeded(); return
        }
        val ad = interstitial
        if (ad == null) {
            completion?.invoke(); preloadInterstitialIfNeeded(); return
        }
        presentInterstitial(activity, ad, completion)
    }

    fun showInterstitialForTournamentRound(activity: Activity, completion: (() -> Unit)? = null) {
        if (userHasPaidForAdRemoval()) {
            completion?.invoke(); preloadInterstitialIfNeeded(); return
        }
        val ad = interstitial ?: run {
            completion?.invoke(); preloadInterstitialIfNeeded(); return
        }
        presentInterstitial(activity, ad, completion)
    }

    fun showRewardedAdForCustomCreature(activity: Activity, completion: (Boolean) -> Unit) {
        if (userHasPaidForAdRemoval()) { completion(true); return }
        val ad = rewardedAd ?: run {
            // Don't block the user if the ad isn't ready.
            completion(true); preloadRewardedIfNeeded(); return
        }
        presentRewarded(activity, ad, isCoinAd = false, completion)
    }

    fun showRewardedAdForCoins(activity: Activity, completion: (Boolean) -> Unit) {
        val ad = rewardedAdForCoins ?: run {
            preloadRewardedForCoinsIfNeeded(); completion(false); return
        }
        presentRewarded(activity, ad, isCoinAd = true, completion)
    }

    // endregion

    // region Private

    private fun presentInterstitial(activity: Activity, ad: InterstitialAd, completion: (() -> Unit)?) {
        _isShowingAd.value = true
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                _isShowingAd.value = false
                interstitial = null
                preloadInterstitialIfNeeded()
                completion?.invoke()
            }
            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                _isShowingAd.value = false
                interstitial = null
                preloadInterstitialIfNeeded()
                completion?.invoke()
            }
        }
        ad.show(activity)
    }

    private fun presentRewarded(
        activity: Activity,
        ad: RewardedAd,
        isCoinAd: Boolean,
        completion: (Boolean) -> Unit,
    ) {
        _isShowingAd.value = true
        var earned = false
        ad.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() {
                _isShowingAd.value = false
                if (isCoinAd) {
                    rewardedAdForCoins = null
                    _coinAdReady.value = false
                    preloadRewardedForCoinsIfNeeded()
                } else {
                    rewardedAd = null
                    preloadRewardedIfNeeded()
                }
                completion(earned)
            }
            override fun onAdFailedToShowFullScreenContent(error: AdError) {
                _isShowingAd.value = false
                if (isCoinAd) {
                    rewardedAdForCoins = null
                    _coinAdReady.value = false
                    preloadRewardedForCoinsIfNeeded()
                } else {
                    rewardedAd = null
                    preloadRewardedIfNeeded()
                }
                completion(false)
            }
        }
        ad.show(activity) { earned = true }
    }

    private fun buildRequest(): AdRequest = AdRequest.Builder().build()

    // endregion

    companion object {
        private const val TAG = "AdManager"

        @Volatile private var INSTANCE: AdManager? = null

        fun instance(context: Context): AdManager =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: AdManager(context.applicationContext).also { INSTANCE = it }
            }

        /**
         * Call once at app launch. Applies COPPA / underage-of-consent flags
         * (this app targets kids) then initializes the SDK.
         */
        fun configure(context: Context) {
            val config = RequestConfiguration.Builder()
                .setTagForChildDirectedTreatment(
                    RequestConfiguration.TAG_FOR_CHILD_DIRECTED_TREATMENT_TRUE
                )
                .setTagForUnderAgeOfConsent(
                    RequestConfiguration.TAG_FOR_UNDER_AGE_OF_CONSENT_TRUE
                )
                .setMaxAdContentRating(RequestConfiguration.MAX_AD_CONTENT_RATING_G)
                .build()
            MobileAds.setRequestConfiguration(config)
            MobileAds.initialize(context.applicationContext) { status ->
                Log.d(
                    TAG,
                    "Mobile Ads initialized. Adapters: ${status.adapterStatusMap.keys.joinToString()}"
                )
            }
        }
    }
}
