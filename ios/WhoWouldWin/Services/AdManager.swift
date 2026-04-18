// AdManager.swift
// Animal vs Animal — centralized AdMob integration
//
// ─────────────────────────────────────────────────────────────────────────────
// AD UNIT IDs
// ─────────────────────────────────────────────────────────────────────────────
// Replace the PRODUCTION strings before submitting to the App Store.
// Get them from: https://apps.admob.com → Apps → Animal vs Animal → Ad units
//
//   Interstitial (full-screen, shown every 3 battles):
//     TEST:       ca-app-pub-3940256099942544/4411468910
//     PRODUCTION: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX   ← replace
//
//   Rewarded (shown before custom-creature access):
//     TEST:       ca-app-pub-3940256099942544/1712485313
//     PRODUCTION: ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX   ← replace
//
//   App ID (goes in Info.plist under GADApplicationIdentifier):
//     TEST:       ca-app-pub-3940256099942544              ← any test device
//     PRODUCTION: ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX   ← your real ID
// ─────────────────────────────────────────────────────────────────────────────

import GoogleMobileAds
import UIKit

@MainActor
final class AdManager: NSObject, ObservableObject {

    static let shared = AdManager()

    // MARK: - Ad Unit IDs

    // Simulator → test IDs. TestFlight → test IDs (production units need App Store review).
    // App Store release → production IDs. Swap the #else block before final submission.
    #if DEBUG
    private static let interstitialAdUnitID  = "ca-app-pub-3940256099942544/4411468910"
    private static let rewardedAdUnitID      = "ca-app-pub-3940256099942544/1712485313"
    private static let coinRewardedAdUnitID  = "ca-app-pub-3940256099942544/1712485313"
    #else
    private static var isTestFlight: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }
    private static var interstitialAdUnitID: String {
        isTestFlight ? "ca-app-pub-3940256099942544/4411468910"
                     : "ca-app-pub-4887593367953664/1197356191"
    }
    private static var rewardedAdUnitID: String {
        isTestFlight ? "ca-app-pub-3940256099942544/1712485313"
                     : "ca-app-pub-4887593367953664/4061419186"
    }
    private static var coinRewardedAdUnitID: String {
        isTestFlight ? "ca-app-pub-3940256099942544/1712485313"
                     : "ca-app-pub-4887593367953664/3537568758"
    }
    #endif

    // MARK: - State

    @Published private(set) var isShowingAd = false

    private var interstitial: GADInterstitialAd?
    private var rewardedAd: GADRewardedAd?          // custom creature gate
    private var rewardedAdForCoins: GADRewardedAd?  // coin-earning — no paid gate

    private var interstitialCompletion: (() -> Void)?
    private var rewardedCompletion: ((Bool) -> Void)?
    private var rewardEarned = false

    // Coin-ad tracking (separate from the creature-gate rewarded slot)
    private var coinAdCompletion: ((Bool) -> Void)?
    private var coinRewardEarned = false
    private var isShowingCoinAd = false

    /// Publishes true when a coin rewarded ad is loaded and ready to show.
    /// Observe this in the UI to show/disable the "Watch Ad" button reactively.
    @Published private(set) var coinAdReady = false

    // MARK: - SDK Setup

    /// Call once at app launch (in WhoWouldWinApp.init or .onAppear).
    /// Sets COPPA / child-directed flags before the SDK starts.
    static func configure() {
        let config = GADMobileAds.sharedInstance().requestConfiguration

        // Required for apps directed at children under COPPA.
        config.tagForChildDirectedTreatment = true

        // Also tag for users under the age of consent (GDPR-adjacent).
        config.tagForUnderAgeOfConsent = true

        // Non-personalized ads only — no behavioral targeting.
        // This is set on every individual request too (see makeRequest()).
        config.maxAdContentRating = .general

        GADMobileAds.sharedInstance().start { status in
            #if DEBUG
            let adapters = status.adapterStatusesByClassName
            print("[AdManager] SDK ready. Adapters: \(adapters.keys.joined(separator: ", "))")
            #endif
        }
    }

    // MARK: - Public helpers

    /// True when the user has paid to remove ads (one-time purchase or active subscription).
    /// All ad-display logic gates through this single check.
    func userHasPaidForAdRemoval() -> Bool {
        // NOTE: hasRemovedAds is written by StoreKitManager.applyEntitlement()
        // after a StoreKit 2 verified transaction — it is NOT based on a raw
        // UserDefaults flag that a user could flip manually.
        UserSettings.shared.hasRemovedAds || UserSettings.shared.isSubscribed
    }

    // MARK: - Interstitial (battle gate)

    /// Call inside BattleView's .complete phase handler, AFTER UserSettings.recordBattle().
    /// Shows a real interstitial if conditions are met; calls completion when done.
    /// Completion fires immediately if the user has paid or no ad is needed.
    func showInterstitialIfNeeded(completion: (() -> Void)? = nil) {
        guard !userHasPaidForAdRemoval() else {
            completion?()
            preloadInterstitialIfNeeded()
            return
        }
        guard UserSettings.shared.shouldShowAd else {
            completion?()
            preloadInterstitialIfNeeded()
            return
        }
        guard let ad = interstitial else {
            // Ad wasn't ready in time — don't block the user.
            #if DEBUG
            print("[AdManager] Interstitial not ready, skipping this battle.")
            #endif
            completion?()
            preloadInterstitialIfNeeded()
            return
        }
        presentInterstitial(ad, completion: completion)
    }

    /// Tournament-specific interstitial shown between rounds. Bypasses the
    /// per-battle counter gate because a completed round is a natural pacing
    /// break. Still respects the ad-removal entitlement.
    func showInterstitialForTournamentRound(completion: (() -> Void)? = nil) {
        guard !userHasPaidForAdRemoval() else {
            completion?()
            preloadInterstitialIfNeeded()
            return
        }
        guard let ad = interstitial else {
            // Not loaded yet — fall through so we don't block the tournament.
            #if DEBUG
            print("[AdManager] Tournament interstitial not ready, skipping.")
            #endif
            completion?()
            preloadInterstitialIfNeeded()
            return
        }
        presentInterstitial(ad, completion: completion)
    }

    // MARK: - Rewarded (custom creature gate)

    /// Show a rewarded ad to unlock custom-creature access for one session.
    /// completion(true)  → reward earned → allow navigation to creature creator.
    /// completion(false) → ad failed or user skipped → show upsell alert instead.
    func showRewardedAdForCustomCreature(completion: @escaping (Bool) -> Void) {
        guard !userHasPaidForAdRemoval() else {
            // Paid users skip directly through.
            completion(true)
            return
        }
        guard let ad = rewardedAd else {
            // No ad loaded yet — grant access anyway so the user isn't blocked.
            #if DEBUG
            print("[AdManager] Rewarded ad not ready, granting free pass.")
            #endif
            completion(true)
            preloadRewardedIfNeeded()
            return
        }
        presentRewarded(ad, completion: completion)
    }

    /// Whether a coin-earning rewarded ad is currently loaded and ready to show.
    var coinAdIsReady: Bool { rewardedAdForCoins != nil }

    /// Show a rewarded ad to earn coins. No paid-user gate — everyone can earn coins.
    /// completion(true) = reward earned. completion(false) = ad not ready / failed / dismissed early.
    func showRewardedAdForCoins(completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAdForCoins else {
            preloadRewardedForCoinsIfNeeded()
            completion(false)
            return
        }
        guard let rootVC = rootViewController() else {
            completion(false)
            return
        }
        // Set up delegate tracking so dismiss/fail always resolves the completion.
        isShowingAd = true
        isShowingCoinAd = true
        coinAdReady = false
        coinAdCompletion = completion
        coinRewardEarned = false
        rewardedAdForCoins = nil
        ad.fullScreenContentDelegate = self
        ad.present(fromRootViewController: rootVC) {
            // Fires only when the full reward is earned (before dismiss).
            self.coinRewardEarned = true
        }
    }

    // MARK: - Preloading

    func preloadAll() {
        preloadInterstitialIfNeeded()
        preloadRewardedIfNeeded()
        preloadRewardedForCoinsIfNeeded()
    }

    /// Preloads the coin-earning rewarded ad. No paid-user gate.
    func preloadRewardedForCoinsIfNeeded() {
        guard rewardedAdForCoins == nil else { return }
        Task {
            do {
                let ad = try await GADRewardedAd.load(
                    withAdUnitID: Self.coinRewardedAdUnitID,
                    request: makeRequest()
                )
                self.rewardedAdForCoins = ad
                self.coinAdReady = true
                #if DEBUG
                print("[AdManager] Coin rewarded ad loaded.")
                #endif
            } catch {
                #if DEBUG
                print("[AdManager] Coin rewarded load failed: \(error.localizedDescription)")
                #endif
                self.rewardedAdForCoins = nil
                self.coinAdReady = false
            }
        }
    }

    func preloadInterstitialIfNeeded() {
        guard !userHasPaidForAdRemoval(), interstitial == nil else { return }
        Task {
            do {
                let ad = try await GADInterstitialAd.load(
                    withAdUnitID: Self.interstitialAdUnitID,
                    request: makeRequest()
                )
                self.interstitial = ad
                self.interstitial?.fullScreenContentDelegate = self
                #if DEBUG
                print("[AdManager] Interstitial loaded.")
                #endif
            } catch {
                #if DEBUG
                print("[AdManager] Interstitial load failed: \(error.localizedDescription)")
                #endif
                self.interstitial = nil
            }
        }
    }

    func preloadRewardedIfNeeded() {
        guard !userHasPaidForAdRemoval(), rewardedAd == nil else { return }
        Task {
            do {
                let ad = try await GADRewardedAd.load(
                    withAdUnitID: Self.rewardedAdUnitID,
                    request: makeRequest()
                )
                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                #if DEBUG
                print("[AdManager] Rewarded ad loaded.")
                #endif
            } catch {
                #if DEBUG
                print("[AdManager] Rewarded load failed: \(error.localizedDescription)")
                #endif
                self.rewardedAd = nil
            }
        }
    }

    // MARK: - Private presentation

    private func presentInterstitial(_ ad: GADInterstitialAd, completion: (() -> Void)?) {
        guard let rootVC = rootViewController() else {
            completion?()
            return
        }
        isShowingAd = true
        interstitialCompletion = completion
        ad.present(fromRootViewController: rootVC)
    }

    private func presentRewarded(_ ad: GADRewardedAd, completion: @escaping (Bool) -> Void) {
        guard let rootVC = rootViewController() else {
            completion(false)
            return
        }
        isShowingAd = true
        rewardEarned = false
        rewardedCompletion = completion
        ad.present(fromRootViewController: rootVC) { [weak self] in
            // This block fires only when a full reward is earned.
            self?.rewardEarned = true
        }
    }

    // MARK: - Helpers

    /// Builds a GADRequest configured for non-personalized ads (required for COPPA).
    private func makeRequest() -> GADRequest {
        let request = GADRequest()
        let extras = GADExtras()
        extras.additionalParameters = ["npa": "1"]   // non-personalized
        request.register(extras)
        return request
    }

    private func rootViewController() -> UIViewController? {
        guard let root = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive })
            .flatMap({ $0 as? UIWindowScene })?
            .windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController
        else { return nil }
        // Walk up the presentation chain to find the topmost presented VC.
        // AdMob must present on top of whatever is currently visible —
        // if a sheet (e.g. CoinsHubSheet) is already on screen, presenting
        // on the root VC below it fails silently and the delegate never fires.
        var top: UIViewController = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private override init() { super.init() }
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            self.isShowingAd = false

            if ad is GADInterstitialAd {
                let completion = self.interstitialCompletion
                self.interstitialCompletion = nil
                self.interstitial = nil
                self.preloadInterstitialIfNeeded()
                completion?()

            } else if ad is GADRewardedAd {
                if self.isShowingCoinAd {
                    // Coin-earning rewarded ad dismissed — resolve with whether reward was earned.
                    let earned = self.coinRewardEarned
                    let completion = self.coinAdCompletion
                    self.coinAdCompletion = nil
                    self.coinRewardEarned = false
                    self.isShowingCoinAd = false
                    self.preloadRewardedForCoinsIfNeeded()
                    completion?(earned)
                } else {
                    // Creature-gate rewarded ad dismissed.
                    let earned = self.rewardEarned
                    let completion = self.rewardedCompletion
                    self.rewardedCompletion = nil
                    self.rewardedAd = nil
                    self.reloadRewardedAfterDismiss()
                    completion?(earned)
                }
            }
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd,
                        didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.isShowingAd = false
            #if DEBUG
            print("[AdManager] Failed to present: \(error.localizedDescription)")
            #endif

            if ad is GADInterstitialAd {
                let completion = self.interstitialCompletion
                self.interstitialCompletion = nil
                self.interstitial = nil
                self.preloadInterstitialIfNeeded()
                completion?()

            } else if ad is GADRewardedAd {
                if self.isShowingCoinAd {
                    let completion = self.coinAdCompletion
                    self.coinAdCompletion = nil
                    self.isShowingCoinAd = false
                    self.preloadRewardedForCoinsIfNeeded()
                    completion?(false)
                } else {
                    let completion = self.rewardedCompletion
                    self.rewardedCompletion = nil
                    self.rewardedAd = nil
                    self.preloadRewardedIfNeeded()
                    completion?(false)
                }
            }
        }
    }

    /// Slight delay before reloading rewarded so the VC dismiss animation completes.
    private func reloadRewardedAfterDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.preloadRewardedIfNeeded()
        }
    }
}
