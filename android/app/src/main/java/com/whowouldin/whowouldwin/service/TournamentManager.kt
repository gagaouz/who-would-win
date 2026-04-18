package com.whowouldin.whowouldwin.service

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.squareup.moshi.Moshi
import com.squareup.moshi.adapter
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import com.whowouldin.whowouldwin.data.Animals
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalCategory
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.model.BattleResult
import com.whowouldin.whowouldwin.model.Bracket
import com.whowouldin.whowouldwin.model.BracketSize
import com.whowouldin.whowouldwin.model.GrandChampionWager
import com.whowouldin.whowouldwin.model.LedgerEntry
import com.whowouldin.whowouldwin.model.Matchup
import com.whowouldin.whowouldwin.model.MatchupWager
import com.whowouldin.whowouldwin.model.SelectionMode
import com.whowouldin.whowouldwin.model.Tournament
import com.whowouldin.whowouldwin.model.TournamentPhase
import com.whowouldin.whowouldwin.model.WagerMultipliers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Calendar
import java.util.UUID

/**
 * Android port of iOS TournamentManager.swift.
 *
 * ViewModel-scoped state holder; persists the active tournament to shared
 * prefs (via UserPrefs) using the same storage key as iOS UserDefaults.
 *
 * Because [TournamentPhase] is a sealed class with data/object subtypes, we
 * snapshot it to a simple discriminator + ints instead of relying on Moshi
 * polymorphism — keeps serialization stable without extra gradle deps.
 */
class TournamentManager(private val appContext: Context) : ViewModel() {

    private val prefs = UserPrefs(appContext)

    private val moshi: Moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()

    private val tournamentAdapter = moshi.adapter(SavedTournament::class.java)

    private val _activeTournament = MutableStateFlow<Tournament?>(null)
    val activeTournament: StateFlow<Tournament?> = _activeTournament.asStateFlow()

    // Cached for UI — updated whenever daily count mutates.
    private val _lastStartBlockedReason = MutableStateFlow<StartBlockedReason?>(null)
    val lastStartBlockedReason: StateFlow<StartBlockedReason?> = _lastStartBlockedReason.asStateFlow()

    private val coinStore = CoinStore.instance(appContext)
    private val settings = UserSettings.instance(appContext)

    init { load() }

    // ───────────────────── Persistence ─────────────────────

    private fun load() {
        val blob = prefs.getString(STORAGE_KEY) ?: return
        try {
            val saved = tournamentAdapter.fromJson(blob) ?: return
            if (saved.schemaVersion == Tournament.CURRENT_SCHEMA_VERSION) {
                _activeTournament.value = saved.toTournament()
            } else {
                prefs.setString(STORAGE_KEY, null)
            }
        } catch (e: Throwable) {
            prefs.setString(STORAGE_KEY, null)
        }
    }

    private fun save() {
        val t = _activeTournament.value
        if (t == null) {
            prefs.setString(STORAGE_KEY, null)
            return
        }
        try {
            prefs.setString(STORAGE_KEY, tournamentAdapter.toJson(SavedTournament.from(t)))
        } catch (_: Throwable) { /* swallow */ }
    }

    private fun mutate(block: (Tournament) -> Tournament) {
        val t = _activeTournament.value ?: return
        _activeTournament.value = block(t)
        save()
    }

    // ───────────────────── Daily cap ─────────────────────

    val tournamentsStartedToday: Int
        get() {
            val last = prefs.getInt(DAILY_COUNT_DATE_KEY, 0)
            if (last == 0 || !isDateInToday(prefs.getLong(DAILY_COUNT_DATE_MILLIS_KEY))) return 0
            return prefs.getInt(DAILY_COUNT_KEY, 0)
        }

    val freeTournamentsRemainingToday: Int
        get() = maxOf(0, coinStore.tournamentDailyFreeLimit - tournamentsStartedToday)

    val nextTournamentRequiresCoins: Boolean
        get() = tournamentsStartedToday >= coinStore.tournamentDailyFreeLimit

    private fun incrementDailyCount() {
        val count = tournamentsStartedToday + 1
        prefs.setInt(DAILY_COUNT_KEY, count)
        prefs.setInt(DAILY_COUNT_DATE_KEY, 1)
        prefs.setLong(DAILY_COUNT_DATE_MILLIS_KEY, System.currentTimeMillis())
    }

    fun resetDailyTournamentCountForTesting() {
        prefs.setInt(DAILY_COUNT_KEY, 0)
        prefs.setInt(DAILY_COUNT_DATE_KEY, 0)
        prefs.setLong(DAILY_COUNT_DATE_MILLIS_KEY, 0L)
    }

    // ───────────────────── Lifecycle ─────────────────────

    sealed class StartBlockedReason {
        data class DailyLimitReachedNeedCoins(val cost: Int) : StartBlockedReason()
        data class InsufficientCoinsForExtra(val cost: Int, val balance: Int) : StartBlockedReason()
    }

    fun startNew(
        size: BracketSize,
        selectionMode: SelectionMode,
        manualPicks: List<Animal> = emptyList(),
        payWithCoinsIfOverLimit: Boolean = false,
    ): Tournament? {
        val cost = coinStore.tournamentExtraEntryCost
        if (nextTournamentRequiresCoins) {
            if (!payWithCoinsIfOverLimit) {
                _lastStartBlockedReason.value = StartBlockedReason.DailyLimitReachedNeedCoins(cost)
                return null
            }
            val balance = coinStore.balance.value
            if (balance < cost) {
                _lastStartBlockedReason.value = StartBlockedReason.InsufficientCoinsForExtra(cost, balance)
                return null
            }
            if (!coinStore.spend(cost)) {
                _lastStartBlockedReason.value = StartBlockedReason.InsufficientCoinsForExtra(cost, balance)
                return null
            }
        }

        _lastStartBlockedReason.value = null
        incrementDailyCount()

        val bracket = generateBracket(size = size, selectionMode = selectionMode, manualPicks = manualPicks)
        val t = Tournament(
            size = size,
            selectionMode = selectionMode,
            phase = TournamentPhase.Preview,
            bracket = bracket,
        )
        _activeTournament.value = t
        save()
        return t
    }

    fun clear() {
        _activeTournament.value = null
        prefs.setString(STORAGE_KEY, null)
    }

    fun forfeit() = clear()

    val hasResumableTournament: Boolean
        get() {
            val t = _activeTournament.value ?: return false
            return t.phase !is TournamentPhase.Complete
        }

    // ───────────────────── Phase transitions ─────────────────────

    fun setPhase(phase: TournamentPhase) = mutate { it.copy(phase = phase) }

    // ───────────────────── Re-roll ─────────────────────

    fun rerollBracket(): Boolean {
        val t = _activeTournament.value ?: return false
        if (t.rerollUsed) return false
        val cost = coinStore.tournamentBracketRerollCost
        if (!coinStore.spend(cost)) return false
        val pool = t.bracket.allFighters
        val newBracket = generateBracket(
            size = t.size,
            selectionMode = t.selectionMode,
            manualPicks = pool,
            forcePoolReuse = true,
        )
        mutate { cur ->
            cur.copy(
                bracket = newBracket,
                rerollUsed = true,
                ledger = cur.ledger + LedgerEntry(
                    timestampMillis = System.currentTimeMillis(),
                    description = "Bracket re-roll",
                    delta = -cost,
                    runningBalance = coinStore.balance.value,
                ),
            )
        }
        return true
    }

    // ───────────────────── Bracket generation ─────────────────────

    fun generateBracket(
        size: BracketSize,
        selectionMode: SelectionMode,
        manualPicks: List<Animal>,
        forcePoolReuse: Boolean = false,
    ): Bracket {
        val pool: List<Animal> = if (forcePoolReuse) {
            manualPicks.shuffled()
        } else {
            resolveCreaturePool(size, selectionMode, manualPicks)
        }

        val unlockedEnvs = unlockedEnvironments()
        var envPool = unlockedEnvs.shuffled().toMutableList()
        val round0 = mutableListOf<Matchup>()
        var i = 0
        while (i < pool.size - 1) {
            val env = nextEnv(envPool, unlockedEnvs)
            round0.add(
                Matchup(
                    fighter1 = pool[i],
                    fighter2 = pool[i + 1],
                    environment = env,
                )
            )
            i += 2
        }

        val rounds = mutableListOf<List<Matchup>>()
        rounds.add(round0.toList())
        for (r in 1 until size.totalRounds) rounds.add(emptyList())
        return Bracket(rounds)
    }

    private fun nextEnv(pool: MutableList<BattleEnvironment>, refill: List<BattleEnvironment>): BattleEnvironment {
        if (pool.isEmpty()) pool.addAll(refill.shuffled())
        return pool.removeAt(pool.size - 1)
    }

    private fun resolveCreaturePool(
        size: BracketSize,
        selectionMode: SelectionMode,
        manualPicks: List<Animal>,
    ): List<Animal> {
        val target = size.size
        val roster = unlockedRoster()
        return when (selectionMode) {
            SelectionMode.RANDOM -> roster.shuffled().take(target)
            SelectionMode.MANUAL -> {
                val picks = manualPicks.take(target)
                if (picks.size == target) picks.shuffled()
                else fillHybrid(manualPicks, roster, target)
            }
            SelectionMode.HYBRID -> fillHybrid(manualPicks, roster, target)
        }
    }

    private fun fillHybrid(manualPicks: List<Animal>, roster: List<Animal>, target: Int): List<Animal> {
        val combined = manualPicks.toMutableList()
        val picked = combined.map { it.id }.toMutableSet()
        for (f in roster.shuffled()) {
            if (combined.size >= target) break
            if (f.id !in picked) { combined.add(f); picked.add(f.id) }
        }
        return combined.take(target).shuffled()
    }

    private fun unlockedRoster(): List<Animal> = Animals.all.filter { animal ->
        when (animal.category) {
            AnimalCategory.ALL, AnimalCategory.LAND, AnimalCategory.SEA,
            AnimalCategory.AIR, AnimalCategory.INSECT -> true
            AnimalCategory.PREHISTORIC -> settings.isPrehistoricUnlocked
            AnimalCategory.FANTASY -> settings.isFantasyUnlocked
            AnimalCategory.MYTHIC -> settings.isMythicUnlocked
            AnimalCategory.OLYMPUS -> settings.isOlympusUnlocked
        }
    }

    private fun unlockedEnvironments(): List<BattleEnvironment> {
        val envs = BattleEnvironment.values().filter { settings.isEnvironmentUnlocked(it) }
        return if (envs.isEmpty()) listOf(
            BattleEnvironment.GRASSLAND, BattleEnvironment.OCEAN, BattleEnvironment.SKY,
        ) else envs
    }

    // ───────────────────── Wagering ─────────────────────

    val maxMatchupWager: Int
        get() {
            val bal = coinStore.balance.value
            val pct = (bal * coinStore.tournamentMatchupWagerMaxPct).toInt()
            val floor = if (bal >= coinStore.tournamentMatchupWagerFloor) coinStore.tournamentMatchupWagerFloor else 0
            return maxOf(0, maxOf(pct, floor))
        }

    val maxGrandChampionWager: Int
        get() {
            val bal = coinStore.balance.value
            val pct = (bal * coinStore.tournamentGrandChampionMaxPct).toInt()
            val floor = if (bal >= coinStore.tournamentGrandChampionFloor) coinStore.tournamentGrandChampionFloor else 0
            return maxOf(0, maxOf(pct, floor))
        }

    fun placeMatchupWager(matchupId: String, pickedFighterId: String, amount: Int): Boolean {
        val t = _activeTournament.value ?: return false
        val r = t.currentRoundIndex ?: return false
        val mIdx = t.bracket.rounds[r].indexOfFirst { it.id == matchupId }
        if (mIdx < 0) return false
        val matchup = t.bracket.rounds[r][mIdx]
        if (matchup.wager != null) return false
        if (amount < coinStore.tournamentMatchupWagerFloor) return false
        if (amount > maxMatchupWager) return false
        if (!coinStore.spend(amount)) return false

        mutate { cur ->
            val newRound = cur.bracket.rounds[r].toMutableList()
            newRound[mIdx] = newRound[mIdx].copy(wager = MatchupWager(pickedFighterId, amount))
            val newRounds = cur.bracket.rounds.toMutableList().also { it[r] = newRound.toList() }
            cur.copy(
                bracket = Bracket(newRounds.toList()),
                ledger = cur.ledger + LedgerEntry(
                    timestampMillis = System.currentTimeMillis(),
                    description = "Wager: ${matchup.fighter1.name} vs ${matchup.fighter2.name}",
                    delta = -amount,
                    runningBalance = coinStore.balance.value,
                ),
            )
        }
        return true
    }

    fun placeGrandChampion(pickedFighterId: String, amount: Int): Boolean {
        val t = _activeTournament.value ?: return false
        if (t.grandChampion != null) return false
        if (amount < coinStore.tournamentGrandChampionFloor) return false
        if (amount > maxGrandChampionWager) return false
        if (!coinStore.spend(amount)) return false

        val pickName = t.bracket.allFighters.firstOrNull { it.id == pickedFighterId }?.name ?: "?"
        mutate { cur ->
            cur.copy(
                grandChampion = GrandChampionWager(
                    pickedFighterId = pickedFighterId,
                    amount = amount,
                    multiplier = WagerMultipliers.grandChampion(lockedAtRoundIndex = 0),
                    lockedAtRoundIndex = 0,
                ),
                ledger = cur.ledger + LedgerEntry(
                    timestampMillis = System.currentTimeMillis(),
                    description = "Grand Champion: $pickName (5.0×)",
                    delta = -amount,
                    runningBalance = coinStore.balance.value,
                ),
            )
        }
        return true
    }

    fun swapGrandChampion(newPickedFighterId: String): Boolean {
        val t = _activeTournament.value ?: return false
        if (!t.canSwapGrandChampion) return false
        val r = t.currentRoundIndex ?: return false
        if (t.grandChampion == null) return false
        if (t.bracket.aliveFighters.none { it.id == newPickedFighterId }) return false

        val newMult = WagerMultipliers.grandChampion(r)
        val pickName = t.bracket.allFighters.firstOrNull { it.id == newPickedFighterId }?.name ?: "?"
        mutate { cur ->
            val gc = cur.grandChampion ?: return@mutate cur
            cur.copy(
                grandChampion = gc.copy(
                    pickedFighterId = newPickedFighterId,
                    multiplier = newMult,
                    lockedAtRoundIndex = r,
                ),
                ledger = cur.ledger + LedgerEntry(
                    timestampMillis = System.currentTimeMillis(),
                    description = "GC swap → $pickName (${"%.2f".format(newMult)}×)",
                    delta = 0,
                    runningBalance = coinStore.balance.value,
                ),
            )
        }
        return true
    }

    // ───────────────────── Battle resolution ─────────────────────

    fun recordMatchupResult(matchupId: String, result: BattleResult) {
        val t = _activeTournament.value ?: return
        val r = t.currentRoundIndex ?: return
        val mIdx = t.bracket.rounds[r].indexOfFirst { it.id == matchupId }
        if (mIdx < 0) return
        mutate { cur ->
            val newRound = cur.bracket.rounds[r].toMutableList()
            newRound[mIdx] = newRound[mIdx].copy(result = result)
            val newRounds = cur.bracket.rounds.toMutableList().also { it[r] = newRound.toList() }
            cur.copy(bracket = Bracket(newRounds.toList()))
        }
    }

    data class RoundPayoutLine(
        val matchupId: String,
        val winnerName: String,
        val wagered: Int,
        val delta: Int,
        val won: Boolean,
    )

    fun resolveRoundPayouts(): List<RoundPayoutLine> {
        val t = _activeTournament.value ?: return emptyList()
        val r = t.currentRoundIndex ?: return emptyList()
        val round = t.bracket.rounds[r]
        val lines = mutableListOf<RoundPayoutLine>()

        for (matchup in round) {
            val result = matchup.result ?: continue
            val winnerId = result.winner
            val winnerName = matchup.winningFighter?.name ?: "Draw"
            val w = matchup.wager
            if (w != null) {
                val won = w.pickedFighterId == winnerId
                if (won) {
                    val mult = WagerMultipliers.matchup(r, t.size)
                    val payout = (w.amount * mult).toInt()
                    coinStore.earn(payout)
                    mutate { cur ->
                        cur.copy(
                            ledger = cur.ledger + LedgerEntry(
                                timestampMillis = System.currentTimeMillis(),
                                description = "Win: $winnerName (${"%.1f".format(mult)}×)",
                                delta = payout,
                                runningBalance = coinStore.balance.value,
                            ),
                        )
                    }
                    lines.add(RoundPayoutLine(matchup.id, winnerName, w.amount, payout, true))
                } else {
                    lines.add(RoundPayoutLine(matchup.id, winnerName, w.amount, -w.amount, false))
                }
            } else {
                lines.add(RoundPayoutLine(matchup.id, winnerName, 0, 0, false))
            }
        }

        // Build next round
        val nextRoundIdx = r + 1
        if (nextRoundIdx < t.size.totalRounds) {
            val winners = round.mapNotNull { it.winningFighter }
            val unlockedEnvs = unlockedEnvironments()
            val envPool = unlockedEnvs.shuffled().toMutableList()
            val nextMatchups = mutableListOf<Matchup>()
            var i = 0
            while (i < winners.size - 1) {
                nextMatchups.add(
                    Matchup(
                        fighter1 = winners[i],
                        fighter2 = winners[i + 1],
                        environment = nextEnv(envPool, unlockedEnvs),
                    )
                )
                i += 2
            }
            mutate { cur ->
                val newRounds = cur.bracket.rounds.toMutableList()
                newRounds[nextRoundIdx] = nextMatchups.toList()
                cur.copy(bracket = Bracket(newRounds.toList()))
            }
        }

        return lines
    }

    fun resolveGrandChampionPayout(): Int {
        val t = _activeTournament.value ?: return 0
        val gc = t.grandChampion ?: return 0
        val champion = t.bracket.rounds.lastOrNull()?.firstOrNull()?.winningFighter ?: return 0
        return if (champion.id == gc.pickedFighterId) {
            val payout = (gc.amount * gc.multiplier).toInt()
            coinStore.earn(payout)
            mutate { cur ->
                cur.copy(
                    ledger = cur.ledger + LedgerEntry(
                        timestampMillis = System.currentTimeMillis(),
                        description = "Grand Champion correct! (${"%.2f".format(gc.multiplier)}×)",
                        delta = payout,
                        runningBalance = coinStore.balance.value,
                    ),
                )
            }
            payout
        } else {
            mutate { cur ->
                cur.copy(
                    ledger = cur.ledger + LedgerEntry(
                        timestampMillis = System.currentTimeMillis(),
                        description = "Grand Champion miss",
                        delta = 0,
                        runningBalance = coinStore.balance.value,
                    ),
                )
            }
            0
        }
    }

    val netCoinDelta: Int
        get() = _activeTournament.value?.ledger?.sumOf { it.delta } ?: 0

    // ───────────────────── Internals ─────────────────────

    private fun isDateInToday(millis: Long): Boolean {
        if (millis <= 0L) return false
        val a = Calendar.getInstance().apply { timeInMillis = millis }
        val b = Calendar.getInstance()
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
                a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    }

    // ───────────────────── Serialization helpers ─────────────────────

    /**
     * Snapshot a Tournament into a Moshi-friendly shape. [TournamentPhase] is
     * a sealed class with data/object subtypes, so we flatten it here rather
     * than add the moshi-adapters dependency.
     */
    @com.squareup.moshi.JsonClass(generateAdapter = true)
    data class SavedTournament(
        val id: String,
        val createdAtMillis: Long,
        val sizeName: String,
        val selectionModeName: String,
        val phaseName: String,
        val phaseRoundIndex: Int?,
        val phaseMatchupIndex: Int?,
        val bracket: Bracket,
        val grandChampion: GrandChampionWager?,
        val rerollUsed: Boolean,
        val ledger: List<LedgerEntry>,
        val schemaVersion: Int,
    ) {
        fun toTournament(): Tournament = Tournament(
            id = id,
            createdAtMillis = createdAtMillis,
            size = BracketSize.valueOf(sizeName),
            selectionMode = SelectionMode.valueOf(selectionModeName),
            phase = phaseFrom(phaseName, phaseRoundIndex, phaseMatchupIndex),
            bracket = bracket,
            grandChampion = grandChampion,
            rerollUsed = rerollUsed,
            ledger = ledger,
            schemaVersion = schemaVersion,
        )

        companion object {
            fun from(t: Tournament): SavedTournament {
                val (name, r, m) = phaseTriple(t.phase)
                return SavedTournament(
                    id = t.id,
                    createdAtMillis = t.createdAtMillis,
                    sizeName = t.size.name,
                    selectionModeName = t.selectionMode.name,
                    phaseName = name,
                    phaseRoundIndex = r,
                    phaseMatchupIndex = m,
                    bracket = t.bracket,
                    grandChampion = t.grandChampion,
                    rerollUsed = t.rerollUsed,
                    ledger = t.ledger,
                    schemaVersion = t.schemaVersion,
                )
            }

            private fun phaseTriple(p: TournamentPhase): Triple<String, Int?, Int?> = when (p) {
                is TournamentPhase.Setup -> Triple("setup", null, null)
                is TournamentPhase.Picking -> Triple("picking", null, null)
                is TournamentPhase.Preview -> Triple("preview", null, null)
                is TournamentPhase.GrandWager -> Triple("grandWager", null, null)
                is TournamentPhase.RoundWager -> Triple("roundWager", p.roundIndex, null)
                is TournamentPhase.RoundBattles -> Triple("roundBattles", p.roundIndex, p.matchupIndex)
                is TournamentPhase.RoundResults -> Triple("roundResults", p.roundIndex, null)
                is TournamentPhase.Complete -> Triple("complete", null, null)
            }

            private fun phaseFrom(name: String, r: Int?, m: Int?): TournamentPhase = when (name) {
                "setup" -> TournamentPhase.Setup
                "picking" -> TournamentPhase.Picking
                "preview" -> TournamentPhase.Preview
                "grandWager" -> TournamentPhase.GrandWager
                "roundWager" -> TournamentPhase.RoundWager(r ?: 0)
                "roundBattles" -> TournamentPhase.RoundBattles(r ?: 0, m ?: 0)
                "roundResults" -> TournamentPhase.RoundResults(r ?: 0)
                "complete" -> TournamentPhase.Complete
                else -> TournamentPhase.Preview
            }
        }
    }

    companion object {
        private const val STORAGE_KEY = "tournament.active"
        private const val DAILY_COUNT_KEY = "tournament.dailyCount"
        private const val DAILY_COUNT_DATE_KEY = "tournament.dailyCountDateFlag"
        private const val DAILY_COUNT_DATE_MILLIS_KEY = "tournament.dailyCountDateMillis"

        /** Build a ViewModelProvider.Factory bound to an application context. */
        fun factory(context: Context): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                return TournamentManager(context.applicationContext) as T
            }
        }
    }
}

/** UserPrefs doesn't expose getLong — stopgap extension to keep this file self-contained. */
private fun UserPrefs.getLong(key: String, default: Long = 0L): Long {
    val s = getString(key) ?: return default
    return s.toLongOrNull() ?: default
}

private fun UserPrefs.setLong(key: String, value: Long) {
    setString(key, value.toString())
}
