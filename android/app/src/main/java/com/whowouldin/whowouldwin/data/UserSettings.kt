package com.whowouldin.whowouldwin.data

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.model.EnvTier
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.util.Calendar

/**
 * Android port of iOS UserSettings.swift — central store for user preferences.
 *
 * Persists to DataStore Preferences (replaces iOS UserDefaults).
 * Reactive: every field is exposed as a StateFlow (mirrors iOS `@Published`).
 *
 * All UserDefaults keys are preserved verbatim (e.g. "pref.sound", "iap.fantasy",
 * "stat.battles") for eventual cross-platform cloud-sync reconciliation.
 *
 * Singleton — access via `UserSettings.instance(context)`.
 */
private val Context.userSettingsDataStore by preferencesDataStore(name = "user_settings")

object Keys {
    // Sound & Vibration
    val SOUND_ENABLED              = booleanPreferencesKey("pref.sound")
    val NARRATION_ENABLED          = booleanPreferencesKey("pref.narration")
    val HAPTICS_ENABLED            = booleanPreferencesKey("pref.haptics")
    val VOICE_PROMPT_SEEN          = booleanPreferencesKey("pref.voicePromptSeen")

    // Appearance
    val LIGHT_MODE                 = booleanPreferencesKey("pref.lightMode")

    // Battle tracking
    val TOTAL_BATTLE_COUNT         = intPreferencesKey("stat.battles")
    val CURRENT_STREAK             = intPreferencesKey("stat.streak")
    val LONGEST_STREAK             = intPreferencesKey("stat.longestStreak")
    val LAST_BATTLE_DATE           = longPreferencesKey("stat.lastBattleDate")

    // Tournament unlock
    val TOURNAMENT_UNLOCKED        = booleanPreferencesKey("pref.tournamentUnlocked")
    val HAS_SEEN_TOURNAMENT_BANNER = booleanPreferencesKey("pref.seenTournamentBanner")

    // Purchases
    val HAS_REMOVED_ADS            = booleanPreferencesKey("iap.noads")
    val IS_SUBSCRIBED              = booleanPreferencesKey("iap.sub")
    val FANTASY_UNLOCKED           = booleanPreferencesKey("iap.fantasy")
    val PREHISTORIC_UNLOCKED       = booleanPreferencesKey("iap.prehistoric")
    val MYTHIC_UNLOCKED            = booleanPreferencesKey("iap.mythic")
    val OLYMPUS_UNLOCKED           = booleanPreferencesKey("iap.olympus")
    val ENVIRONMENTS_UNLOCKED      = booleanPreferencesKey("iap.environments")

    // First-run flags
    val HAS_SEEN_DISCLAIMER        = booleanPreferencesKey("hasSeenDisclaimer")
}

class UserSettings private constructor(private val appContext: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val ds get() = appContext.userSettingsDataStore

    // region Flows → StateFlows

    private fun <T> flow(pick: (Preferences) -> T?, default: T): StateFlow<T> =
        ds.data.map { pick(it) ?: default }
            .stateIn(scope, SharingStarted.Eagerly, default)

    // Sound & vibration
    val soundEnabled: StateFlow<Boolean>              = flow({ it[Keys.SOUND_ENABLED] }, true)
    val narrationEnabled: StateFlow<Boolean>          = flow({ it[Keys.NARRATION_ENABLED] }, true)
    val hapticsEnabled: StateFlow<Boolean>            = flow({ it[Keys.HAPTICS_ENABLED] }, true)
    val hasSeenVoiceQualityPrompt: StateFlow<Boolean> = flow({ it[Keys.VOICE_PROMPT_SEEN] }, false)

    // Appearance
    val isLightMode: StateFlow<Boolean> = flow({ it[Keys.LIGHT_MODE] }, false)

    // Battle tracking
    val totalBattleCount: StateFlow<Int> = flow({ it[Keys.TOTAL_BATTLE_COUNT] }, 0)
    val currentStreak: StateFlow<Int>    = flow({ it[Keys.CURRENT_STREAK] }, 0)
    val longestStreak: StateFlow<Int>    = flow({ it[Keys.LONGEST_STREAK] }, 0)

    // Tournament
    val tournamentUnlocked: StateFlow<Boolean>       = flow({ it[Keys.TOURNAMENT_UNLOCKED] }, false)
    val hasSeenTournamentBanner: StateFlow<Boolean>  = flow({ it[Keys.HAS_SEEN_TOURNAMENT_BANNER] }, false)

    // Purchases
    val hasRemovedAds: StateFlow<Boolean>        = flow({ it[Keys.HAS_REMOVED_ADS] }, false)
    val isSubscribed: StateFlow<Boolean>         = flow({ it[Keys.IS_SUBSCRIBED] }, false)
    val fantasyUnlocked: StateFlow<Boolean>      = flow({ it[Keys.FANTASY_UNLOCKED] }, false)
    val prehistoricUnlocked: StateFlow<Boolean>  = flow({ it[Keys.PREHISTORIC_UNLOCKED] }, false)
    val mythicUnlocked: StateFlow<Boolean>       = flow({ it[Keys.MYTHIC_UNLOCKED] }, false)
    val olympusUnlocked: StateFlow<Boolean>      = flow({ it[Keys.OLYMPUS_UNLOCKED] }, false)
    val environmentsUnlocked: StateFlow<Boolean> = flow({ it[Keys.ENVIRONMENTS_UNLOCKED] }, false)

    // endregion

    // region Synchronous accessors (current value snapshot — mirrors iOS's @Published read)

    val soundEnabledNow: Boolean              get() = soundEnabled.value
    val narrationEnabledNow: Boolean          get() = narrationEnabled.value
    val hapticsEnabledNow: Boolean            get() = hapticsEnabled.value
    val isLightModeNow: Boolean               get() = isLightMode.value
    val totalBattleCountNow: Int              get() = totalBattleCount.value
    val currentStreakNow: Int                 get() = currentStreak.value
    val longestStreakNow: Int                 get() = longestStreak.value
    val tournamentUnlockedNow: Boolean        get() = tournamentUnlocked.value
    val hasSeenTournamentBannerNow: Boolean   get() = hasSeenTournamentBanner.value
    val hasRemovedAdsNow: Boolean             get() = hasRemovedAds.value
    val isSubscribedNow: Boolean              get() = isSubscribed.value
    val fantasyUnlockedNow: Boolean           get() = fantasyUnlocked.value
    val prehistoricUnlockedNow: Boolean       get() = prehistoricUnlocked.value
    val mythicUnlockedNow: Boolean            get() = mythicUnlocked.value
    val olympusUnlockedNow: Boolean           get() = olympusUnlocked.value
    val environmentsUnlockedNow: Boolean      get() = environmentsUnlocked.value
    val hasSeenVoiceQualityPromptNow: Boolean get() = hasSeenVoiceQualityPrompt.value

    // endregion

    // region Setters (fire-and-forget suspendable writes)

    fun setSoundEnabled(v: Boolean)              = write(Keys.SOUND_ENABLED, v)
    fun setNarrationEnabled(v: Boolean)          = write(Keys.NARRATION_ENABLED, v)
    fun setHapticsEnabled(v: Boolean)            = write(Keys.HAPTICS_ENABLED, v)
    fun setHasSeenVoiceQualityPrompt(v: Boolean) = write(Keys.VOICE_PROMPT_SEEN, v)
    fun setLightMode(v: Boolean)                 = write(Keys.LIGHT_MODE, v)
    fun setHasRemovedAds(v: Boolean)             = write(Keys.HAS_REMOVED_ADS, v)
    fun setIsSubscribed(v: Boolean)              = write(Keys.IS_SUBSCRIBED, v)
    fun setFantasyUnlocked(v: Boolean)           = write(Keys.FANTASY_UNLOCKED, v)
    fun setPrehistoricUnlocked(v: Boolean)       = write(Keys.PREHISTORIC_UNLOCKED, v)
    fun setMythicUnlocked(v: Boolean)            = write(Keys.MYTHIC_UNLOCKED, v)
    fun setOlympusUnlocked(v: Boolean)           = write(Keys.OLYMPUS_UNLOCKED, v)
    fun setEnvironmentsUnlocked(v: Boolean)      = write(Keys.ENVIRONMENTS_UNLOCKED, v)
    fun setTournamentUnlocked(v: Boolean)        = write(Keys.TOURNAMENT_UNLOCKED, v)
    fun setHasSeenTournamentBanner(v: Boolean)   = write(Keys.HAS_SEEN_TOURNAMENT_BANNER, v)
    fun setTotalBattleCount(v: Int)              = write(Keys.TOTAL_BATTLE_COUNT, v)
    fun setCurrentStreak(v: Int)                 = write(Keys.CURRENT_STREAK, v)
    fun setLongestStreak(v: Int)                 = write(Keys.LONGEST_STREAK, v)

    private fun <T> write(key: Preferences.Key<T>, value: T) {
        scope.launch { ds.edit { it[key] = value } }
    }

    private fun <T> remove(key: Preferences.Key<T>) {
        scope.launch { ds.edit { it.remove(key) } }
    }

    // endregion

    // region Helpers

    /**
     * Call after every completed battle.
     * Increments total count, updates streak, fires achievement checks.
     * PGS (Google Play Games Services) reporting is stubbed — not shipping in v1.
     */
    fun recordBattle() {
        scope.launch {
            ds.edit { prefs ->
                val newCount = (prefs[Keys.TOTAL_BATTLE_COUNT] ?: 0) + 1
                prefs[Keys.TOTAL_BATTLE_COUNT] = newCount
                updateStreakInEdit(prefs)
            }
            // Defer achievement checks so new StateFlow values have propagated.
            val tracker = com.whowouldin.whowouldwin.service.AchievementTracker.instance(appContext)
            tracker.checkStreakAchievements(currentStreakNow)
            tracker.checkPackAchievements()
            // TODO(v1.1): Report totalBattles / longestStreak to Play Games leaderboards
            // TODO(v1.1): CloudSyncService.autoSync()
        }
    }

    /**
     * Consecutive-day streak logic — mirrors iOS updateStreak().
     *  - Same calendar day: no change.
     *  - Previous calendar day: streak + 1.
     *  - Anything older (or never): streak resets to 1.
     */
    private fun updateStreakInEdit(prefs: androidx.datastore.preferences.core.MutablePreferences) {
        val now = System.currentTimeMillis()
        val last = prefs[Keys.LAST_BATTLE_DATE] ?: 0L

        val sameDay = last > 0L && isSameDay(last, now)
        val prevDay = last > 0L && isYesterday(last, now)

        if (last > 0L) {
            when {
                sameDay -> {
                    // Already battled today — streak unchanged.
                }
                prevDay -> {
                    val newStreak = (prefs[Keys.CURRENT_STREAK] ?: 0) + 1
                    prefs[Keys.CURRENT_STREAK] = newStreak
                    val longest = prefs[Keys.LONGEST_STREAK] ?: 0
                    if (newStreak > longest) prefs[Keys.LONGEST_STREAK] = newStreak
                    prefs[Keys.LAST_BATTLE_DATE] = now
                }
                else -> {
                    prefs[Keys.CURRENT_STREAK] = 1
                    prefs[Keys.LAST_BATTLE_DATE] = now
                }
            }
        } else {
            prefs[Keys.CURRENT_STREAK] = 1
            val longest = prefs[Keys.LONGEST_STREAK] ?: 0
            if (longest < 1) prefs[Keys.LONGEST_STREAK] = 1
            prefs[Keys.LAST_BATTLE_DATE] = now
        }
    }

    /** Wipes all progress and purchases — internal testing only. */
    fun resetAllProgressForTesting() {
        scope.launch {
            ds.edit { prefs ->
                prefs[Keys.TOTAL_BATTLE_COUNT]         = 0
                prefs[Keys.CURRENT_STREAK]             = 0
                prefs[Keys.LONGEST_STREAK]             = 0
                prefs[Keys.FANTASY_UNLOCKED]           = false
                prefs[Keys.PREHISTORIC_UNLOCKED]       = false
                prefs[Keys.MYTHIC_UNLOCKED]            = false
                prefs[Keys.OLYMPUS_UNLOCKED]           = false
                prefs[Keys.HAS_REMOVED_ADS]            = false
                prefs[Keys.IS_SUBSCRIBED]              = false
                prefs[Keys.TOURNAMENT_UNLOCKED]        = false
                prefs[Keys.HAS_SEEN_TOURNAMENT_BANNER] = false
                prefs.remove(Keys.LAST_BATTLE_DATE)
            }
            com.whowouldin.whowouldwin.service.CoinStore.instance(appContext).resetForTesting()
        }
    }

    // endregion

    // region Ad gating

    /**
     * Returns true when an interstitial ad should be shown.
     * First 3 battles are ad-free; then every other battle.
     */
    val shouldShowAd: Boolean
        get() {
            if (hasRemovedAdsNow) return false
            if (totalBattleCountNow < 3) return false
            return totalBattleCountNow % 2 == 0
        }

    // endregion

    // region Fantasy / Prehistoric / Mythic / Olympus Access

    /** True if the user has access to fantasy creatures via IAP, subscription, or free milestone. */
    val isFantasyUnlocked: Boolean
        get() = fantasyUnlockedNow || isSubscribedNow || totalBattleCountNow >= fantasyBattleThreshold

    /** True if the user has access to prehistoric creatures via IAP, subscription, or free milestone. */
    val isPrehistoricUnlocked: Boolean
        get() = prehistoricUnlockedNow || isSubscribedNow || totalBattleCountNow >= prehistoricBattleThreshold

    /** True if the user has access to mythic creatures via IAP, subscription, or free milestone. */
    val isMythicUnlocked: Boolean
        get() = mythicUnlockedNow || isSubscribedNow || totalBattleCountNow >= mythicBattleThreshold

    /** True once all three packs are unlocked — reveals the Gods pack as available. */
    val isOlympusVisible: Boolean
        get() = isFantasyUnlocked && isPrehistoricUnlocked && isMythicUnlocked

    /** True if the user has access to the Olympus gods (IAP or 10,000 battles). */
    val isOlympusUnlocked: Boolean
        get() = olympusUnlockedNow || totalBattleCountNow >= olympusBattleThreshold

    /** Progress toward the free fantasy unlock (0.0 – 1.0). */
    val fantasyUnlockProgress: Double
        get() = if (isFantasyUnlocked) 1.0
                else minOf(totalBattleCountNow.toDouble() / fantasyBattleThreshold.toDouble(), 1.0)

    val prehistoricUnlockProgress: Double
        get() = if (isPrehistoricUnlocked) 1.0
                else minOf(totalBattleCountNow.toDouble() / prehistoricBattleThreshold.toDouble(), 1.0)

    val mythicUnlockProgress: Double
        get() = if (isMythicUnlocked) 1.0
                else minOf(totalBattleCountNow.toDouble() / mythicBattleThreshold.toDouble(), 1.0)

    val olympusUnlockProgress: Double
        get() = if (isOlympusUnlocked) 1.0
                else minOf(totalBattleCountNow.toDouble() / olympusBattleThreshold.toDouble(), 1.0)

    /** True the very first time each battle threshold is crossed (triggers celebration). */
    val justUnlockedFantasy: Boolean
        get() = !fantasyUnlockedNow && !isSubscribedNow && totalBattleCountNow == fantasyBattleThreshold
    val justUnlockedPrehistoric: Boolean
        get() = !prehistoricUnlockedNow && !isSubscribedNow && totalBattleCountNow == prehistoricBattleThreshold
    val justUnlockedMythic: Boolean
        get() = !mythicUnlockedNow && !isSubscribedNow && totalBattleCountNow == mythicBattleThreshold
    val justUnlockedOlympus: Boolean
        get() = !olympusUnlockedNow && totalBattleCountNow == olympusBattleThreshold

    // endregion

    // region Tournament Access

    /** True if Tournament Mode is currently usable. */
    val isTournamentUnlocked: Boolean
        get() = tournamentUnlockedNow || isSubscribedNow || totalBattleCountNow >= tournamentBattleThreshold

    /** Progress toward the free tournament unlock (0.0 – 1.0). */
    val tournamentUnlockProgress: Double
        get() = if (isTournamentUnlocked) 1.0
                else minOf(totalBattleCountNow.toDouble() / tournamentBattleThreshold.toDouble(), 1.0)

    val justUnlockedTournament: Boolean
        get() = !tournamentUnlockedNow && !isSubscribedNow && totalBattleCountNow == tournamentBattleThreshold

    // endregion

    // region Environment Access

    /** True if the user can access ALL environments (pack purchase or subscription). */
    val hasAllEnvironments: Boolean
        get() = environmentsUnlockedNow || isSubscribedNow

    /** True if a specific environment is currently usable. */
    fun isEnvironmentUnlocked(env: BattleEnvironment): Boolean = when (env.tier) {
        EnvTier.FREE    -> true
        EnvTier.EARNED  -> hasAllEnvironments || (env.battleThreshold?.let { totalBattleCountNow >= it } ?: false)
        EnvTier.PREMIUM -> hasAllEnvironments
    }

    // endregion

    companion object {
        // Battle thresholds for free pack unlocks (match iOS exactly)
        const val fantasyBattleThreshold     = 250
        const val prehistoricBattleThreshold = 100
        const val mythicBattleThreshold      = 500
        const val olympusBattleThreshold     = 10_000

        /** Battles required to unlock Tournament Mode for free. */
        const val tournamentBattleThreshold  = 30

        @Volatile private var INSTANCE: UserSettings? = null

        fun instance(context: Context): UserSettings {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: UserSettings(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
}

/** Tiny Calendar helpers for consecutive-day logic. */
private fun isSameDay(aMillis: Long, bMillis: Long): Boolean {
    val a = Calendar.getInstance().apply { timeInMillis = aMillis }
    val b = Calendar.getInstance().apply { timeInMillis = bMillis }
    return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
           a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
}

private fun isYesterday(lastMillis: Long, nowMillis: Long): Boolean {
    val yesterday = Calendar.getInstance().apply {
        timeInMillis = nowMillis
        add(Calendar.DAY_OF_YEAR, -1)
    }
    val last = Calendar.getInstance().apply { timeInMillis = lastMillis }
    return yesterday.get(Calendar.YEAR) == last.get(Calendar.YEAR) &&
           yesterday.get(Calendar.DAY_OF_YEAR) == last.get(Calendar.DAY_OF_YEAR)
}
