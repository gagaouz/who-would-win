package com.whowouldin.whowouldwin

import android.app.Application

/**
 * Application class — single instance, created before any Activity.
 * Initialize singletons, analytics (none in v1), and logging here.
 */
class WhoWouldWinApp : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    companion object {
        lateinit var instance: WhoWouldWinApp
            private set
    }
}
