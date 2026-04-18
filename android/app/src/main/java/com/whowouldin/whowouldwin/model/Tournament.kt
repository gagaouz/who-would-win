package com.whowouldin.whowouldwin.model

import com.squareup.moshi.JsonClass
import java.util.UUID

enum class BracketSize(val size: Int) {
    FOUR(4), EIGHT(8), SIXTEEN(16);

    val totalRounds: Int get() = when (this) {
        FOUR -> 2
        EIGHT -> 3
        SIXTEEN -> 4
    }

    fun roundName(roundIndex: Int): String = when (totalRounds - roundIndex) {
        1 -> "Final"
        2 -> "Semifinals"
        3 -> "Quarterfinals"
        4 -> "Round of 16"
        else -> "Round ${roundIndex + 1}"
    }
}

enum class SelectionMode { RANDOM, MANUAL, HYBRID }

/** Sealed hierarchy mirrors iOS TournamentPhase enum-with-associated-values. */
sealed class TournamentPhase {
    object Setup : TournamentPhase()
    object Picking : TournamentPhase()
    object Preview : TournamentPhase()
    object GrandWager : TournamentPhase()
    data class RoundWager(val roundIndex: Int) : TournamentPhase()
    data class RoundBattles(val roundIndex: Int, val matchupIndex: Int) : TournamentPhase()
    data class RoundResults(val roundIndex: Int) : TournamentPhase()
    object Complete : TournamentPhase()
}

@JsonClass(generateAdapter = true)
data class MatchupWager(
    val pickedFighterId: String,
    val amount: Int,
)

@JsonClass(generateAdapter = true)
data class GrandChampionWager(
    var pickedFighterId: String,
    val amount: Int,
    var multiplier: Double,
    var lockedAtRoundIndex: Int,
)

@JsonClass(generateAdapter = true)
data class Matchup(
    val id: String = UUID.randomUUID().toString(),
    val fighter1: Animal,
    val fighter2: Animal,
    val environment: BattleEnvironment,
    var wager: MatchupWager? = null,
    var result: BattleResult? = null,
) {
    val winningFighter: Animal?
        get() = result?.let { r ->
            when (r.winner) {
                fighter1.id -> fighter1
                fighter2.id -> fighter2
                else -> null // draw
            }
        }

    val losingFighter: Animal?
        get() = result?.let { r ->
            when (r.winner) {
                fighter1.id -> fighter2
                fighter2.id -> fighter1
                else -> null
            }
        }

    val isResolved: Boolean get() = result != null
}

@JsonClass(generateAdapter = true)
data class Bracket(
    /** rounds[0] = first round, rounds[last] = final. */
    var rounds: List<List<Matchup>>,
) {
    val allFighters: List<Animal>
        get() {
            val seen = mutableSetOf<String>()
            val out = mutableListOf<Animal>()
            for (round in rounds) for (m in round) {
                if (seen.add(m.fighter1.id)) out.add(m.fighter1)
                if (seen.add(m.fighter2.id)) out.add(m.fighter2)
            }
            return out
        }

    val aliveFighters: List<Animal>
        get() {
            val losers = rounds.flatten().mapNotNull { it.losingFighter?.id }.toSet()
            return allFighters.filter { it.id !in losers }
        }
}

@JsonClass(generateAdapter = true)
data class LedgerEntry(
    val id: String = UUID.randomUUID().toString(),
    val timestampMillis: Long,
    val description: String,
    val delta: Int,
    val runningBalance: Int,
)

@JsonClass(generateAdapter = true)
data class Tournament(
    val id: String = UUID.randomUUID().toString(),
    val createdAtMillis: Long = System.currentTimeMillis(),
    val size: BracketSize,
    val selectionMode: SelectionMode,
    var phase: TournamentPhase,
    var bracket: Bracket,
    var grandChampion: GrandChampionWager? = null,
    var rerollUsed: Boolean = false,
    var ledger: List<LedgerEntry> = emptyList(),
    val schemaVersion: Int = 1,
) {
    val currentRoundIndex: Int?
        get() = when (val p = phase) {
            is TournamentPhase.RoundWager -> p.roundIndex
            is TournamentPhase.RoundBattles -> p.roundIndex
            is TournamentPhase.RoundResults -> p.roundIndex
            else -> null
        }

    val canSwapGrandChampion: Boolean
        get() = currentRoundIndex?.let { it < size.totalRounds - 1 } ?: false

    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
    }
}

/** Wager multiplier table. Mirrors iOS WagerMultipliers. */
object WagerMultipliers {
    fun matchup(roundIndex: Int, size: BracketSize): Double =
        when (size.totalRounds - roundIndex) {
            1 -> 3.0  // final
            2 -> 2.5  // semis
            3 -> 2.0  // quarterfinals
            4 -> 1.5  // round of 16
            else -> 1.5
        }

    fun grandChampion(lockedAtRoundIndex: Int): Double = when (lockedAtRoundIndex) {
        0 -> 5.0
        1 -> 3.5
        2 -> 2.5
        3 -> 1.75
        else -> 1.75
    }
}
