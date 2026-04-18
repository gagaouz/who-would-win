package com.whowouldin.whowouldwin.service

import android.app.Activity
import android.content.Context
import android.util.Log
import com.google.android.gms.games.AuthenticationResult
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Android port of iOS GameCenterManager.swift using Google Play Games Services v2.
 *
 * v2 drops the old GoogleSignIn-based auth flow; PlayGamesSdk.initialize(context)
 * is all that's required at app start, and PlayGames.getGamesSignInClient() handles
 * sign-in/silent-auth automatically on the device.
 *
 * Leaderboard + achievement IDs below are *iOS-shaped* placeholders. Replace with
 * the real IDs from Play Console (format: CgkIxxxxxxxxxx) before shipping.
 */
class PlayGamesManager private constructor(private val appContext: Context) {

    // MARK: - Leaderboard IDs
    // Placeholders — these must be replaced with the real Play Console IDs
    // once the game is registered. Using the iOS identifier strings as markers
    // so a later codemod can find and replace all four in one pass.
    enum class Leaderboard(val id: String) {
        TOTAL_BATTLES    ("com.whowouldin.leaderboard.totalBattles"),
        TOURNAMENTS_WON  ("com.whowouldin.leaderboard.tournamentsWon"),
        LONGEST_STREAK   ("com.whowouldin.leaderboard.longestStreak"),
        PEAK_COINS       ("com.whowouldin.leaderboard.peakCoins"),
    }

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()

    private val _playerId = MutableStateFlow<String?>(null)
    val playerId: StateFlow<String?> = _playerId.asStateFlow()

    private val reportedThisSession: MutableSet<String> = mutableSetOf()

    /**
     * Attempts silent sign-in. PGS v2 surfaces a prompt automatically if
     * the device has a Play Games identity available.
     */
    fun authenticate() {
        val client = PlayGames.getGamesSignInClient(ContextActivityBridge.current ?: return noActivity())
        client.isAuthenticated.addOnCompleteListener { task ->
            val result: AuthenticationResult? = task.result
            if (task.isSuccessful && result?.isAuthenticated == true) {
                onAuthenticated()
            } else {
                client.signIn().addOnCompleteListener { signInTask ->
                    val signedIn = signInTask.isSuccessful &&
                        signInTask.result?.isAuthenticated == true
                    if (signedIn) onAuthenticated()
                    else Log.i(TAG, "Play Games sign-in declined/failed.")
                }
            }
        }
    }

    private fun onAuthenticated() {
        _isAuthenticated.value = true
        PlayGames.getPlayersClient(ContextActivityBridge.current ?: return)
            .currentPlayer
            .addOnSuccessListener { player -> _playerId.value = player.playerId }
        submitCurrentStatsToLeaderboards()
    }

    private fun noActivity() {
        Log.w(TAG, "authenticate() called with no Activity registered.")
    }

    /** Reports a one-shot achievement (mirrors iOS reportAchievement). Idempotent per session. */
    fun reportAchievement(achievementId: String) {
        if (!_isAuthenticated.value) return
        if (!reportedThisSession.add(achievementId)) return
        PlayGames.getAchievementsClient(ContextActivityBridge.current ?: return)
            .unlock(achievementId)
    }

    /** Reports a progressive achievement (increments toward total steps). */
    fun reportProgress(achievementId: String, steps: Int) {
        if (!_isAuthenticated.value || steps <= 0) return
        PlayGames.getAchievementsClient(ContextActivityBridge.current ?: return)
            .setSteps(achievementId, steps)
    }

    /** Submits a score to a leaderboard. Best-score leaderboards keep the max. */
    fun reportScore(leaderboard: Leaderboard, value: Long) {
        if (!_isAuthenticated.value || value <= 0L) return
        PlayGames.getLeaderboardsClient(ContextActivityBridge.current ?: return)
            .submitScore(leaderboard.id, value)
    }

    /** Show the full achievements UI. */
    fun presentAchievements(activity: Activity, requestCode: Int = 9001) {
        PlayGames.getAchievementsClient(activity)
            .achievementsIntent
            .addOnSuccessListener { intent -> activity.startActivityForResult(intent, requestCode) }
    }

    /** Show the full leaderboards UI. */
    fun presentLeaderboards(activity: Activity, requestCode: Int = 9002) {
        PlayGames.getLeaderboardsClient(activity)
            .allLeaderboardsIntent
            .addOnSuccessListener { intent -> activity.startActivityForResult(intent, requestCode) }
    }

    private fun submitCurrentStatsToLeaderboards() {
        val s = com.whowouldin.whowouldwin.data.UserSettings.instance(appContext)
        reportScore(Leaderboard.TOTAL_BATTLES, s.totalBattleCountNow.toLong())
        reportScore(Leaderboard.LONGEST_STREAK, s.longestStreakNow.toLong())
    }

    companion object {
        private const val TAG = "PlayGamesManager"

        @Volatile private var INSTANCE: PlayGamesManager? = null

        fun instance(context: Context): PlayGamesManager =
            INSTANCE ?: synchronized(this) {
                INSTANCE ?: PlayGamesManager(context.applicationContext).also { INSTANCE = it }
            }

        /** Call once in Application.onCreate. */
        fun configure(context: Context) {
            PlayGamesSdk.initialize(context.applicationContext)
        }
    }
}

/**
 * Minimal bridge so the manager can call PGS client factories that require an
 * Activity (a Context is not enough for several v2 APIs). Activities should
 * register themselves in onResume and clear in onPause.
 */
object ContextActivityBridge {
    @Volatile var current: Activity? = null
}
