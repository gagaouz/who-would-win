package com.whowouldin.whowouldwin.service

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalCategory
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.model.BattleResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.util.Calendar

/**
 * Android port of iOS AchievementTracker.swift.
 *
 * Checks game events against 76 achievement definitions. Tracking state persists
 * in DataStore.
 *
 * Google Play Games Services (PGS) integration is **stubbed for v1**: the IDs and
 * per-event logic are fully preserved, but the "report" calls are no-ops with
 * TODO markers. When PGS is wired in v1.1, fill in `reportAchievement` /
 * `reportProgress` / `reportScore`.
 */
private val Context.achievementDataStore by preferencesDataStore(name = "achievements")

class AchievementTracker private constructor(private val appContext: Context) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val ds get() = appContext.achievementDataStore

    // region Achievement IDs — reverse-domain format, matched to iOS

    enum class AchievementID(val rawValue: String) {
        // Battle Milestones (9)
        firstFight("com.whowouldin.achievement.firstFight"),
        tenBattles("com.whowouldin.achievement.tenBattles"),
        fiftyBattles("com.whowouldin.achievement.fiftyBattles"),
        hundredBattles("com.whowouldin.achievement.hundredBattles"),
        twoFiftyBattles("com.whowouldin.achievement.twoFiftyBattles"),
        fiveHundredBattles("com.whowouldin.achievement.fiveHundredBattles"),
        thousandBattles("com.whowouldin.achievement.thousandBattles"),
        fiveThousandBattles("com.whowouldin.achievement.fiveThousandBattles"),
        tenThousandBattles("com.whowouldin.achievement.tenThousandBattles"),

        // Category Mashups (8)
        surfAndTurf("com.whowouldin.achievement.surfAndTurf"),
        whenPigsFly("com.whowouldin.achievement.whenPigsFly"),
        bugZapper("com.whowouldin.achievement.bugZapper"),
        prehistoricShowdown("com.whowouldin.achievement.prehistoricShowdown"),
        mythVsMyth("com.whowouldin.achievement.mythVsMyth"),
        godFight("com.whowouldin.achievement.godFight"),
        fantasyRumble("com.whowouldin.achievement.fantasyRumble"),
        categoryCollector("com.whowouldin.achievement.categoryCollector"),

        // Upsets (5)
        davidVsGoliath("com.whowouldin.achievement.davidVsGoliath"),
        godSlayer("com.whowouldin.achievement.godSlayer"),
        bugSquasher("com.whowouldin.achievement.bugSquasher"),
        dodoRevenge("com.whowouldin.achievement.dodoRevenge"),
        shrimpKing("com.whowouldin.achievement.shrimpKing"),

        // Specific Animal Wins (12)
        honeyDontCare("com.whowouldin.achievement.honeyDontCare"),
        holdMyHoney("com.whowouldin.achievement.holdMyHoney"),
        releaseTheKraken("com.whowouldin.achievement.releaseTheKraken"),
        thunderstruck("com.whowouldin.achievement.thunderstruck"),
        kingOfTheJungle("com.whowouldin.achievement.kingOfTheJungle"),
        jaws("com.whowouldin.achievement.jaws"),
        cleverGirl("com.whowouldin.achievement.cleverGirl"),
        phoenixRising("com.whowouldin.achievement.phoenixRising"),
        stoneCold("com.whowouldin.achievement.stoneCold"),
        herculeanEffort("com.whowouldin.achievement.herculeanEffort"),
        threeHeadedTerror("com.whowouldin.achievement.threeHeadedTerror"),
        dragonSlayer("com.whowouldin.achievement.dragonSlayer"),

        // Environment (8)
        homeTurf("com.whowouldin.achievement.homeTurf"),
        fishOutOfWater("com.whowouldin.achievement.fishOutOfWater"),
        fireWalker("com.whowouldin.achievement.fireWalker"),
        stormChaser("com.whowouldin.achievement.stormChaser"),
        nightHunter("com.whowouldin.achievement.nightHunter"),
        frozenFight("com.whowouldin.achievement.frozenFight"),
        jungleFever("com.whowouldin.achievement.jungleFever"),
        worldTraveler("com.whowouldin.achievement.worldTraveler"),

        // Tournament (10)
        tournamentRookie("com.whowouldin.achievement.tournamentRookie"),
        bracketBuster("com.whowouldin.achievement.bracketBuster"),
        grandChampion("com.whowouldin.achievement.grandChampion"),
        perfectBracket("com.whowouldin.achievement.perfectBracket"),
        highRoller("com.whowouldin.achievement.highRoller"),
        kaChing("com.whowouldin.achievement.kaChing"),
        landLubber("com.whowouldin.achievement.landLubber"),
        seaSupremacy("com.whowouldin.achievement.seaSupremacy"),
        airForceOne("com.whowouldin.achievement.airForceOne"),
        tournamentVeteran("com.whowouldin.achievement.tournamentVeteran"),

        // Coins (4)
        piggyBank("com.whowouldin.achievement.piggyBank"),
        fatCat("com.whowouldin.achievement.fatCat"),
        dragonsHoard("com.whowouldin.achievement.dragonsHoard"),
        bigSpender("com.whowouldin.achievement.bigSpender"),

        // Streaks (4)
        onARoll("com.whowouldin.achievement.onARoll"),
        dedicated("com.whowouldin.achievement.dedicated"),
        unstoppable("com.whowouldin.achievement.unstoppable"),
        obsessed("com.whowouldin.achievement.obsessed"),

        // Pack Unlocks (5)
        jurassicSpark("com.whowouldin.achievement.jurassicSpark"),
        onceUponATime("com.whowouldin.achievement.onceUponATime"),
        mythMaker("com.whowouldin.achievement.mythMaker"),
        ascendingOlympus("com.whowouldin.achievement.ascendingOlympus"),
        gottaCatchEmAll("com.whowouldin.achievement.gottaCatchEmAll"),

        // Custom Creatures (3)
        creatureCreator("com.whowouldin.achievement.creatureCreator"),
        imaginationStation("com.whowouldin.achievement.imaginationStation"),
        madScientist("com.whowouldin.achievement.madScientist"),

        // Fun / Weird (8)
        closeCall("com.whowouldin.achievement.closeCall"),
        flawlessVictory("com.whowouldin.achievement.flawlessVictory"),
        itsADraw("com.whowouldin.achievement.itsADraw"),
        offlineWarrior("com.whowouldin.achievement.offlineWarrior"),
        voiceCommander("com.whowouldin.achievement.voiceCommander"),
        nightOwl("com.whowouldin.achievement.nightOwl"),
        earlyBird("com.whowouldin.achievement.earlyBird"),
        marathoner("com.whowouldin.achievement.marathoner"),
    }

    // endregion

    // region Tracking Keys

    private object Key {
        val EARNED                = stringSetPreferencesKey("achievement.earned")
        val ENVIRONMENTS_WON      = stringSetPreferencesKey("achievement.environmentsWon")
        val CUSTOM_CREATURES_USED = stringSetPreferencesKey("achievement.customCreaturesUsed")
        val TOTAL_COINS_SPENT     = intPreferencesKey("achievement.totalCoinsSpent")
        val TOURNAMENTS_COMPLETED = intPreferencesKey("achievement.tournamentsCompleted")
        val SESSION_BATTLE_COUNT  = intPreferencesKey("achievement.sessionBattleCount")
        val CATEGORIES_BATTLED    = stringSetPreferencesKey("achievement.categoriesBattled")
        val UNIQUE_ANIMALS_USED   = stringSetPreferencesKey("achievement.uniqueAnimalsUsed")
    }

    // endregion

    // region Earned-set helpers (synchronous reads via runBlocking since call sites are plentiful)

    private fun earnedSet(): Set<String> = runBlocking {
        ds.data.first()[Key.EARNED] ?: emptySet()
    }

    private fun isEarned(id: AchievementID): Boolean = id.rawValue in earnedSet()

    private fun markEarned(id: AchievementID) {
        scope.launch {
            var didMark = false
            ds.edit { prefs ->
                val existing = prefs[Key.EARNED] ?: emptySet()
                if (id.rawValue !in existing) {
                    prefs[Key.EARNED] = existing + id.rawValue
                    didMark = true
                }
            }
            if (didMark) {
                reportAchievement(id.rawValue)
                // TODO(v1.1): CloudSyncService.autoSync()
            }
        }
    }

    private fun addToSet(key: Preferences.Key<Set<String>>, value: String) {
        scope.launch {
            ds.edit { prefs ->
                val s = prefs[key] ?: emptySet()
                prefs[key] = s + value
            }
        }
    }

    private fun setCount(key: Preferences.Key<Set<String>>): Int = runBlocking {
        (ds.data.first()[key] ?: emptySet()).size
    }

    private fun intValue(key: Preferences.Key<Int>): Int = runBlocking {
        ds.data.first()[key] ?: 0
    }

    // endregion

    // region PGS stubs — to be filled in when Play Games Services lands in v1.1

    private fun reportAchievement(rawId: String) {
        // TODO(v1.1): Games.Achievements.unlock(googleSignInClient, rawId)
    }

    private fun reportProgress(rawId: String, percentComplete: Double) {
        // TODO(v1.1): Games.Achievements.setSteps or incremental progress
    }

    private fun reportScore(board: String, value: Int) {
        // TODO(v1.1): Games.Leaderboards.submitScore(client, boardId, value)
    }

    // endregion

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // region 🎮 BATTLE COMPLETE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    fun checkBattleAchievements(
        fighter1: Animal,
        fighter2: Animal,
        result: BattleResult,
        environment: BattleEnvironment,
    ) {
        val settings = UserSettings.instance(appContext)
        val battleCount = settings.totalBattleCountNow
        val isDraw = result.winner == "draw"
        val winnerId = result.winner
        val winnerAnimal = if (winnerId == fighter1.id) fighter1 else fighter2
        val loserAnimal  = if (winnerId == fighter1.id) fighter2 else fighter1

        // Track unique animals + categories
        addToSet(Key.UNIQUE_ANIMALS_USED, fighter1.id)
        addToSet(Key.UNIQUE_ANIMALS_USED, fighter2.id)
        addToSet(Key.CATEGORIES_BATTLED, fighter1.category.name)
        addToSet(Key.CATEGORIES_BATTLED, fighter2.category.name)

        // Track session battles (resets on app launch)
        scope.launch {
            ds.edit { prefs ->
                prefs[Key.SESSION_BATTLE_COUNT] = (prefs[Key.SESSION_BATTLE_COUNT] ?: 0) + 1
            }
        }
        val sessionCount = intValue(Key.SESSION_BATTLE_COUNT) + 1

        // Battle milestones
        val milestones: List<Pair<Int, AchievementID>> = listOf(
            1 to AchievementID.firstFight, 10 to AchievementID.tenBattles, 50 to AchievementID.fiftyBattles,
            100 to AchievementID.hundredBattles, 250 to AchievementID.twoFiftyBattles, 500 to AchievementID.fiveHundredBattles,
            1000 to AchievementID.thousandBattles, 5000 to AchievementID.fiveThousandBattles, 10000 to AchievementID.tenThousandBattles,
        )
        for ((threshold, ach) in milestones) {
            if (battleCount >= threshold && !isEarned(ach)) markEarned(ach)
        }
        // Progress on NEXT unearned milestone
        for ((threshold, ach) in milestones) {
            if (!isEarned(ach)) {
                val pct = battleCount.toDouble() / threshold.toDouble() * 100.0
                reportProgress(ach.rawValue, pct)
                break
            }
        }

        // Category Mashups
        val cats = setOf(fighter1.category, fighter2.category)
        if (AnimalCategory.LAND in cats && AnimalCategory.SEA in cats) markEarned(AchievementID.surfAndTurf)
        if (AnimalCategory.LAND in cats && AnimalCategory.AIR in cats) markEarned(AchievementID.whenPigsFly)
        if (AnimalCategory.AIR  in cats && AnimalCategory.INSECT in cats) markEarned(AchievementID.bugZapper)
        if (fighter1.category == AnimalCategory.PREHISTORIC && fighter2.category == AnimalCategory.PREHISTORIC)
            markEarned(AchievementID.prehistoricShowdown)
        if (fighter1.category == AnimalCategory.MYTHIC && fighter2.category == AnimalCategory.MYTHIC)
            markEarned(AchievementID.mythVsMyth)
        if (fighter1.category == AnimalCategory.OLYMPUS && fighter2.category == AnimalCategory.OLYMPUS)
            markEarned(AchievementID.godFight)
        if (fighter1.category == AnimalCategory.FANTASY && fighter2.category == AnimalCategory.FANTASY)
            markEarned(AchievementID.fantasyRumble)

        if (setCount(Key.CATEGORIES_BATTLED) >= 5) markEarned(AchievementID.categoryCollector)

        // Draw
        if (isDraw) {
            markEarned(AchievementID.itsADraw)
            // TODO(v1.1): CloudSyncService.autoSync()
            return
        }

        // Upsets
        if (winnerAnimal.size <= 2 && loserAnimal.size >= 4) markEarned(AchievementID.davidVsGoliath)
        if (winnerAnimal.category != AnimalCategory.OLYMPUS && loserAnimal.category == AnimalCategory.OLYMPUS)
            markEarned(AchievementID.godSlayer)
        if (winnerAnimal.category == AnimalCategory.INSECT && loserAnimal.size >= 4) markEarned(AchievementID.bugSquasher)
        if (winnerId == "dodo") markEarned(AchievementID.dodoRevenge)
        if (winnerId == "mantis_shrimp") markEarned(AchievementID.shrimpKing)

        // Specific animal wins
        if (winnerId == "honey_badger") {
            markEarned(AchievementID.honeyDontCare)
            if (loserAnimal.category == AnimalCategory.OLYMPUS) markEarned(AchievementID.holdMyHoney)
        }
        if (winnerId == "kraken")             markEarned(AchievementID.releaseTheKraken)
        if (winnerId == "zeus")               markEarned(AchievementID.thunderstruck)
        if (winnerId == "lion")               markEarned(AchievementID.kingOfTheJungle)
        if (winnerId == "great_white_shark")  markEarned(AchievementID.jaws)
        if (winnerId == "velociraptor")       markEarned(AchievementID.cleverGirl)
        if (winnerId == "phoenix")            markEarned(AchievementID.phoenixRising)
        if (winnerId == "medusa")             markEarned(AchievementID.stoneCold)
        if (winnerId == "hercules")           markEarned(AchievementID.herculeanEffort)
        if (winnerId == "cerberus")           markEarned(AchievementID.threeHeadedTerror)

        // Dragon Slayer — dragon LOSES
        if (loserAnimal.id == "dragon") markEarned(AchievementID.dragonSlayer)

        // Environments
        addToSet(Key.ENVIRONMENTS_WON, environment.name)
        if (winnerAnimal.category == AnimalCategory.SEA && environment == BattleEnvironment.OCEAN)
            markEarned(AchievementID.homeTurf)
        if (winnerAnimal.category == AnimalCategory.SEA && environment == BattleEnvironment.DESERT)
            markEarned(AchievementID.fishOutOfWater)

        when (environment) {
            BattleEnvironment.VOLCANO -> markEarned(AchievementID.fireWalker)
            BattleEnvironment.STORM   -> markEarned(AchievementID.stormChaser)
            BattleEnvironment.NIGHT   -> markEarned(AchievementID.nightHunter)
            BattleEnvironment.ARCTIC  -> markEarned(AchievementID.frozenFight)
            BattleEnvironment.JUNGLE  -> markEarned(AchievementID.jungleFever)
            else -> Unit
        }

        if (setCount(Key.ENVIRONMENTS_WON) >= 9) markEarned(AchievementID.worldTraveler)

        // Battle outcome
        if (result.winnerHealthPercent < 20)  markEarned(AchievementID.closeCall)
        if (result.winnerHealthPercent >= 85) markEarned(AchievementID.flawlessVictory)
        if (result.isOfflineFallback)         markEarned(AchievementID.offlineWarrior)

        // Custom creatures
        if (fighter1.isCustom || fighter2.isCustom) {
            markEarned(AchievementID.creatureCreator)
            val customName = if (fighter1.isCustom) fighter1.id else fighter2.id
            addToSet(Key.CUSTOM_CREATURES_USED, customName)
            if (setCount(Key.CUSTOM_CREATURES_USED) >= 5)  markEarned(AchievementID.imaginationStation)
            if (setCount(Key.CUSTOM_CREATURES_USED) >= 10) markEarned(AchievementID.madScientist)
        }

        // Time-based
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        if (hour in 0..4) markEarned(AchievementID.nightOwl)
        if (hour in 5..6) markEarned(AchievementID.earlyBird)

        // Session marathon
        if (sessionCount >= 10) markEarned(AchievementID.marathoner)

        // TODO(v1.1): CloudSyncService.autoSync()
    }

    // endregion

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // region 🏆 TOURNAMENT COMPLETE
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    fun checkTournamentAchievements(
        bracketSize: Int,
        championCategory: AnimalCategory?,
        grandChampionWon: Boolean,
        allWagersCorrect: Boolean,
        totalWagered: Int,
        totalWon: Int,
    ) {
        scope.launch {
            ds.edit { prefs ->
                prefs[Key.TOURNAMENTS_COMPLETED] = (prefs[Key.TOURNAMENTS_COMPLETED] ?: 0) + 1
            }
        }
        val count = intValue(Key.TOURNAMENTS_COMPLETED) + 1

        reportScore("tournamentsWon", count)

        markEarned(AchievementID.tournamentRookie)
        if (bracketSize >= 16)    markEarned(AchievementID.bracketBuster)
        if (grandChampionWon)     markEarned(AchievementID.grandChampion)
        if (allWagersCorrect)     markEarned(AchievementID.perfectBracket)
        if (totalWagered >= 500)  markEarned(AchievementID.highRoller)
        if (totalWon >= 1000)     markEarned(AchievementID.kaChing)

        if (championCategory != null) {
            when (championCategory) {
                AnimalCategory.LAND -> markEarned(AchievementID.landLubber)
                AnimalCategory.SEA  -> markEarned(AchievementID.seaSupremacy)
                AnimalCategory.AIR  -> markEarned(AchievementID.airForceOne)
                else -> Unit
            }
        }

        if (count >= 10) markEarned(AchievementID.tournamentVeteran)

        if (!isEarned(AchievementID.tournamentVeteran)) {
            reportProgress(AchievementID.tournamentVeteran.rawValue, count.toDouble() / 10.0 * 100.0)
        }

        // TODO(v1.1): CloudSyncService.autoSync()
    }

    // endregion

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // region 💰 COIN CHANGES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    fun checkCoinAchievements(balance: Int) {
        if (balance >= 1_000)  markEarned(AchievementID.piggyBank)
        if (balance >= 5_000)  markEarned(AchievementID.fatCat)
        if (balance >= 10_000) markEarned(AchievementID.dragonsHoard)

        if (!isEarned(AchievementID.dragonsHoard)) {
            reportProgress(AchievementID.dragonsHoard.rawValue, balance.toDouble() / 10_000.0 * 100.0)
        }
    }

    fun trackCoinsSpent(amount: Int) {
        scope.launch {
            var total = 0
            ds.edit { prefs ->
                total = (prefs[Key.TOTAL_COINS_SPENT] ?: 0) + amount
                prefs[Key.TOTAL_COINS_SPENT] = total
            }
            if (total >= 5_000) markEarned(AchievementID.bigSpender)
            if (!isEarned(AchievementID.bigSpender)) {
                reportProgress(AchievementID.bigSpender.rawValue, total.toDouble() / 5_000.0 * 100.0)
            }
            // TODO(v1.1): CloudSyncService.autoSync()
        }
    }

    // endregion

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // region 🔥 STREAK CHANGES
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    fun checkStreakAchievements(streak: Int) {
        if (streak >= 3)  markEarned(AchievementID.onARoll)
        if (streak >= 7)  markEarned(AchievementID.dedicated)
        if (streak >= 14) markEarned(AchievementID.unstoppable)
        if (streak >= 30) markEarned(AchievementID.obsessed)

        if (!isEarned(AchievementID.obsessed)) {
            reportProgress(AchievementID.obsessed.rawValue, streak.toDouble() / 30.0 * 100.0)
        }
    }

    // endregion

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // region 📦 PACK UNLOCKS
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    fun checkPackAchievements() {
        val s = UserSettings.instance(appContext)
        if (s.isPrehistoricUnlocked) markEarned(AchievementID.jurassicSpark)
        if (s.isFantasyUnlocked)     markEarned(AchievementID.onceUponATime)
        if (s.isMythicUnlocked)      markEarned(AchievementID.mythMaker)
        if (s.isOlympusUnlocked)     markEarned(AchievementID.ascendingOlympus)

        if (s.isPrehistoricUnlocked && s.isFantasyUnlocked &&
            s.isMythicUnlocked && s.isOlympusUnlocked) {
            markEarned(AchievementID.gottaCatchEmAll)
        }
        // TODO(v1.1): CloudSyncService.autoSync()
    }

    // endregion

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // region 🎤 VOICE SEARCH
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    fun trackVoiceSearch() {
        markEarned(AchievementID.voiceCommander)
    }

    // endregion

    /** Call on app launch to reset per-session counters. */
    fun resetSessionCount() {
        scope.launch {
            ds.edit { it[Key.SESSION_BATTLE_COUNT] = 0 }
        }
    }

    companion object {
        @Volatile private var INSTANCE: AchievementTracker? = null
        fun instance(context: Context): AchievementTracker {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: AchievementTracker(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
}
