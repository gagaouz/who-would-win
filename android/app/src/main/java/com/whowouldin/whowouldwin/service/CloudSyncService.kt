package com.whowouldin.whowouldwin.service

import android.content.Context
import android.util.Log

/**
 * CloudSyncService — Android stub.
 *
 * The iOS version syncs UserDefaults to the iCloud Key-Value Store so
 * progress/purchases/achievements survive app deletion.
 *
 * Android has no direct analog to iCloud KV store. Real implementation
 * options (pick one before shipping):
 *   - Google Drive App Data folder (Drive REST API)
 *   - Firestore/Firebase backed user document keyed on a PGS player id
 *   - Play Games Services SavedGames (snapshot API)
 *
 * This stub preserves the iOS CloudSyncService public API so callers on
 * shared code paths compile; every method logs and returns without any
 * network side effect.
 */
class CloudSyncService private constructor(private val appContext: Context) {

    /** Push local state to the cloud. Mirrors iOS CloudSyncService.syncToCloud / autoSync. */
    fun syncToCloud() {
        Log.i(TAG, "cloud sync not yet configured — syncToCloud() ignored")
    }

    /** Debounced variant — same no-op for now. */
    fun autoSync() {
        Log.i(TAG, "cloud sync not yet configured — autoSync() ignored")
    }

    /** Pull-and-merge remote state into local prefs. */
    fun restoreFromCloud() {
        Log.i(TAG, "cloud sync not yet configured — restoreFromCloud() ignored")
    }

    /** Convenience wrapper mirroring roadmap naming. */
    fun syncCoins() {
        Log.i(TAG, "cloud sync not yet configured — syncCoins() ignored")
    }

    fun syncSettings() {
        Log.i(TAG, "cloud sync not yet configured — syncSettings() ignored")
    }

    companion object {
        private const val TAG = "CloudSyncService"

        @Volatile private var INSTANCE: CloudSyncService? = null

        fun instance(context: Context): CloudSyncService =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: CloudSyncService(context.applicationContext).also { INSTANCE = it }
            }
    }
}
