package com.whowouldin.whowouldwin.service

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.whowouldin.whowouldwin.data.UserSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.launch
import java.util.Calendar

/**
 * Android port of iOS CoinStore.swift.
 * Tracks coin balance, earn rates, daily ad limits, and pack progress.
 * All UserDefaults keys and numeric constants are preserved verbatim.
 */
private val Context.coinDataStore by preferencesDataStore(name = "coin_store")

private object CoinKeys {
    val BALANCE                    = intPreferencesKey("coin.balance")
    val WELCOMED                   = booleanPreferencesKey("coin.welcomed")
    val LAST_AD_DATE               = longPreferencesKey("coin.lastAdDate")
    val DAILY_AD_COUNT             = intPreferencesKey("coin.dailyAdCount")
    val LAST_BATTLE_DATE           = longPreferencesKey("coin.lastBattleDate")
    val FIRST_CUSTOM_AWARDED       = booleanPreferencesKey("coin.firstCustomAwarded")
    val TOURNAMENT_SEED_AWARDED    = booleanPreferencesKey("coin.tournamentSeedAwarded")
}

class CoinStore private constructor(private val appContext: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val ds get() = appContext.coinDataStore

    // region Published state

    private val _balance = MutableStateFlow(0)
    val balance: StateFlow<Int> = _balance.asStateFlow()

    private val _earnAnimationAmount = MutableStateFlow(0)
    val earnAnimationAmount: StateFlow<Int> = _earnAnimationAmount.asStateFlow()

    private val _showEarnAnimation = MutableStateFlow(false)
    val showEarnAnimation: StateFlow<Boolean> = _showEarnAnimation.asStateFlow()

    // endregion

    // Earn rates
    val coinsPerBattle         = 10
    val coinsPerBattleSub      = 20
    val dailyFirstBattleBonus  = 25
    val coinsPerAd             = 75
    val maxDailyAds            = 8

    // Pack costs — calibrated to ~2 weeks casual play for the cheapest pack
    val prehistoricCost    =   300
    val fantasyCost        =   800
    val mythicCost         = 1_500
    val olympusCost        = 5_000
    val customCreatureCost =   150

    // Tournament costs and floors
    val tournamentBracketRerollCost     = 50
    val tournamentCustomCreatureCost    = 25    // charged once at bracket commit
    val tournamentMatchupWagerFloor     = 10
    val tournamentGrandChampionFloor    = 50
    val tournamentMatchupWagerMaxPct    = 0.10  // 10% of current balance
    val tournamentGrandChampionMaxPct   = 0.50  // 50% of balance at placement
    val tournamentSeedAmount            = 200   // one-time top-up on tournament unlock
    val tournamentDailyFreeLimit        = 2     // free tournaments per calendar day
    val tournamentExtraEntryCost        = 500   // coin cost for each tournament past the daily free limit

    // Streak bonus tiers
    val streakBonus3Days = 10   // +10 coins/battle at 3+ day streak
    val streakBonus7Days = 20   // +20 coins/battle at 7+ day streak

    // region Progress toward next pack

    data class PackProgress(val name: String, val emoji: String, val cost: Int)

    /** The cheapest pack the user hasn't unlocked yet, or null if all unlocked. */
    val nextPack: PackProgress?
        get() {
            val s = UserSettings.instance(appContext)
            return when {
                !s.isPrehistoricUnlocked -> PackProgress("Prehistoric", "\uD83E\uDD95", prehistoricCost)
                !s.isFantasyUnlocked     -> PackProgress("Fantasy",     "\uD83E\uDDD9", fantasyCost)
                !s.isMythicUnlocked      -> PackProgress("Mythic",      "\uD83D\uDD31", mythicCost)
                !s.isOlympusUnlocked     -> PackProgress("Gods",        "\u26A1",       olympusCost)
                else -> null
            }
        }

    /** 0.0–1.0 progress toward nextPack based on current balance. */
    val nextPackProgress: Double
        get() {
            val pack = nextPack ?: return 1.0
            return minOf(_balance.value.toDouble() / pack.cost.toDouble(), 1.0)
        }

    // endregion

    init {
        // One-time welcome bonus + keep _balance in sync with DataStore.
        scope.launch {
            ds.edit { prefs ->
                if (prefs[CoinKeys.WELCOMED] != true) {
                    prefs[CoinKeys.BALANCE] = 50
                    prefs[CoinKeys.WELCOMED] = true
                }
            }
        }
        scope.launch {
            ds.data.collect { prefs ->
                _balance.value = prefs[CoinKeys.BALANCE] ?: 0
            }
        }
    }

    // region Formatting

    val formattedBalance: String
        get() {
            val b = _balance.value
            if (b >= 1_000) {
                val k = b.toDouble() / 1_000.0
                return if (k == k.toInt().toDouble()) "${k.toInt()}k"
                else String.format("%.1fk", k)
            }
            return "$b"
        }

    // endregion

    // region Daily-ad tracking

    val dailyAdsWatched: Int
        get() = runBlockingRead { prefs ->
            val last = prefs[CoinKeys.LAST_AD_DATE] ?: 0L
            if (last == 0L || !isDateInToday(last)) 0
            else prefs[CoinKeys.DAILY_AD_COUNT] ?: 0
        }

    val canWatchAdForCoins: Boolean get() = dailyAdsWatched < maxDailyAds
    val adsRemainingToday: Int      get() = maxOf(0, maxDailyAds - dailyAdsWatched)

    val isFirstBattleToday: Boolean
        get() = runBlockingRead { prefs ->
            val last = prefs[CoinKeys.LAST_BATTLE_DATE] ?: 0L
            last == 0L || !isDateInToday(last)
        }

    // endregion

    // region Earn / spend

    fun earnBattleCoins() {
        val settings = UserSettings.instance(appContext)
        val base = if (settings.isSubscribedNow) coinsPerBattleSub else coinsPerBattle
        var total = base
        if (isFirstBattleToday) {
            total += dailyFirstBattleBonus
            scope.launch { ds.edit { it[CoinKeys.LAST_BATTLE_DATE] = System.currentTimeMillis() } }
        }
        val streak = settings.currentStreakNow
        when {
            streak >= 7 -> total += streakBonus7Days
            streak >= 3 -> total += streakBonus3Days
        }
        earn(total)
    }

    /**
     * Awards 50 bonus coins for the user's first-ever custom creature battle.
     * Returns `true` if the bonus was actually awarded on this call so the caller
     * can show a one-time celebration banner.
     */
    fun earnFirstCustomBonus(onResult: (Boolean) -> Unit = {}) {
        scope.launch {
            var awarded = false
            ds.edit { prefs ->
                if (prefs[CoinKeys.FIRST_CUSTOM_AWARDED] != true) {
                    prefs[CoinKeys.FIRST_CUSTOM_AWARDED] = true
                    awarded = true
                }
            }
            if (awarded) earn(50)
            onResult(awarded)
        }
    }

    /**
     * One-time top-up the moment Tournament Mode unlocks, so first-time players
     * always have enough coins to actually wager. If the player already has more
     * than the seed amount, this is a no-op. Idempotent.
     */
    fun awardTournamentSeedIfNeeded() {
        scope.launch {
            var shouldAward = false
            ds.edit { prefs ->
                if (prefs[CoinKeys.TOURNAMENT_SEED_AWARDED] != true) {
                    prefs[CoinKeys.TOURNAMENT_SEED_AWARDED] = true
                    shouldAward = true
                }
            }
            if (shouldAward) {
                val deficit = tournamentSeedAmount - _balance.value
                if (deficit > 0) earn(deficit)
            }
        }
    }

    /**
     * Awards coins for an in-app purchase. Not subject to the daily cap
     * since the player paid real money.
     */
    fun awardCoinPurchase(amount: Int) {
        earn(amount)
    }

    fun recordAdWatched() {
        scope.launch {
            ds.edit { prefs ->
                val current = if ((prefs[CoinKeys.LAST_AD_DATE] ?: 0L).let { it > 0L && isDateInToday(it) })
                    (prefs[CoinKeys.DAILY_AD_COUNT] ?: 0) else 0
                prefs[CoinKeys.DAILY_AD_COUNT] = current + 1
                prefs[CoinKeys.LAST_AD_DATE] = System.currentTimeMillis()
            }
            earn(coinsPerAd)
        }
    }

    fun earn(amount: Int) {
        scope.launch {
            ds.edit { prefs ->
                val newBalance = (prefs[CoinKeys.BALANCE] ?: 0) + amount
                prefs[CoinKeys.BALANCE] = newBalance
                _balance.value = newBalance
            }
            _earnAnimationAmount.value = amount
            _showEarnAnimation.value = true
            HapticsService.instance(appContext).medium()
            AchievementTracker.instance(appContext).checkCoinAchievements(_balance.value)
            // TODO(v1.1): Report peakCoins to Play Games leaderboard
            delay(2_500)
            _showEarnAnimation.value = false
        }
    }

    fun canAfford(cost: Int): Boolean = _balance.value >= cost

    /** Atomic spend — returns true if successful. */
    fun spend(amount: Int): Boolean {
        if (_balance.value < amount) return false
        scope.launch {
            ds.edit { prefs ->
                val cur = prefs[CoinKeys.BALANCE] ?: 0
                if (cur >= amount) {
                    val newBalance = cur - amount
                    prefs[CoinKeys.BALANCE] = newBalance
                    _balance.value = newBalance
                }
            }
            HapticsService.instance(appContext).medium()
            AchievementTracker.instance(appContext).trackCoinsSpent(amount)
        }
        return true
    }

    fun resetForTesting() {
        scope.launch {
            ds.edit { prefs ->
                prefs[CoinKeys.BALANCE] = 50
                prefs[CoinKeys.WELCOMED] = false
                prefs.remove(CoinKeys.LAST_AD_DATE)
                prefs.remove(CoinKeys.DAILY_AD_COUNT)
                prefs.remove(CoinKeys.LAST_BATTLE_DATE)
                prefs.remove(CoinKeys.TOURNAMENT_SEED_AWARDED)
                _balance.value = 50
            }
        }
    }

    // endregion

    // region helpers

    private fun isDateInToday(millis: Long): Boolean {
        val a = Calendar.getInstance().apply { timeInMillis = millis }
        val b = Calendar.getInstance()
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
               a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    }

    /** Synchronous DataStore read. Avoids adding suspend to every call site. */
    private fun <T> runBlockingRead(block: (Preferences) -> T): T = runBlocking {
        block(ds.data.first())
    }

    // endregion

    companion object {
        @Volatile private var INSTANCE: CoinStore? = null
        fun instance(context: Context): CoinStore {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: CoinStore(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
}
