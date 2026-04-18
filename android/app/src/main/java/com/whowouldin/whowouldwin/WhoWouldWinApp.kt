package com.whowouldin.whowouldwin

import android.app.Application
import com.whowouldin.whowouldwin.service.AdManager
import com.whowouldin.whowouldwin.service.PlayGamesManager

/**
 * Application class — single instance, created before any Activity.
 * Initializes Mobile Ads (COPPA/underage flags) and the Play Games SDK at
 * launch. BillingClient is intentionally NOT created here; BillingManager
 * builds it lazily on first use so we don't pay the startup cost.
 */
class WhoWouldWinApp : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this

        // Ads: set child-directed / underage flags, then init SDK.
        AdManager.configure(this)

        // Play Games Services v2: SDK init is mandatory for games using PGS.
        PlayGamesManager.configure(this)
    }

    companion object {
        lateinit var instance: WhoWouldWinApp
            private set
    }
}
