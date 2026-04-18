package com.whowouldin.whowouldwin.vm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalStats
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.model.BattleResult
import com.whowouldin.whowouldwin.network.BattleRequest
import com.whowouldin.whowouldwin.network.NetworkModule
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.IOException
import kotlin.random.Random

/**
 * Port of iOS `ViewModels/BattleViewModel.swift`.
 *
 * Phase machine: INTRO → ANIMATING → REVEALING → COMPLETE.
 * Orchestrates: intro delay → parallel fetch + animation → typewriter narration.
 *
 * NOTE: the iOS project wraps network calls in a `BattleService` singleton. That service
 * hasn't been ported to Android yet, so we call [NetworkModule.battleApi] directly and
 * inline the fallback-result generator here. When `BattleService.kt` lands we can
 * delegate to it without changing this file's public surface.
 */
class BattleViewModel(
    val fighter1: Animal,
    val fighter2: Animal,
    var environment: BattleEnvironment = BattleEnvironment.GRASSLAND,
    var arenaEffectsEnabled: Boolean = false,
    val isQuickMode: Boolean = false,
    val tournamentContext: String? = null,
) : ViewModel() {

    enum class Phase { INTRO, ANIMATING, FETCHING_RESULT, REVEALING, COMPLETE }

    // MARK: - State

    private val _phase = MutableStateFlow(Phase.INTRO)
    val phase: StateFlow<Phase> = _phase.asStateFlow()

    private val _battleResult = MutableStateFlow<BattleResult?>(null)
    val battleResult: StateFlow<BattleResult?> = _battleResult.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private val _narrationDisplayed = MutableStateFlow("")
    val narrationDisplayed: StateFlow<String> = _narrationDisplayed.asStateFlow()

    private val _animationComplete = MutableStateFlow(false)
    val animationComplete: StateFlow<Boolean> = _animationComplete.asStateFlow()

    /** When set, the next [startBattle] run uses this result instead of fetching. */
    var forcedResult: BattleResult? = null

    private var lastFetchErrorWasNetworkUnavailable = false
    private var animationSignal: CompletableDeferred<Unit>? = null

    // MARK: - Entry point

    fun startBattle() {
        viewModelScope.launch {
            runBattle()
        }
    }

    private suspend fun runBattle() {
        _phase.value = Phase.INTRO
        _animationComplete.value = false

        // Quick mode: resolve instantly from the lightweight endpoint or local fallback.
        if (isQuickMode) {
            val result = runCatching {
                val req = BattleRequest(
                    fighter1 = fighter1.id,
                    fighter2 = fighter2.id,
                    fighter1Name = fighter1.name,
                    fighter2Name = fighter2.name,
                    environmentName = environment.displayName,
                    tournamentContext = tournamentContext,
                )
                val quick = NetworkModule.battleApi.quickBattle(req)
                // Quick endpoint returns winner only; synthesize a minimal BattleResult.
                BattleResult(
                    winner = quick.winner,
                    narration = "",
                    funFact = "",
                    winnerHealthPercent = Random.nextInt(45, 80),
                    loserHealthPercent = Random.nextInt(5, 25),
                )
            }.getOrElse {
                val isTrueOffline = it is IOException
                generateFallbackResult(markAsOffline = isTrueOffline)
            }
            val final = if (tournamentContext != null) breakDrawIfNeeded(result) else result
            _battleResult.value = final
            _narrationDisplayed.value = final.narration
            _phase.value = Phase.COMPLETE
            return
        }

        // Intro pause
        delay(2_000)
        if (!currentCoroutineIsActive()) return

        _phase.value = Phase.ANIMATING

        // Fire API + animation concurrently.
        val fetchTask = viewModelScope.async { fetchResultIgnoringErrors() }
        val animTask = viewModelScope.async { waitForAnimation() }

        val fetched = fetchTask.await()
        if (!currentCoroutineIsActive()) return

        val result: BattleResult = when {
            forcedResult != null -> {
                val r = forcedResult!!
                forcedResult = null
                r
            }
            fetched != null -> fetched
            else -> generateFallbackResult(markAsOffline = lastFetchErrorWasNetworkUnavailable)
        }

        val finalResult = if (tournamentContext != null) breakDrawIfNeeded(result) else result
        _battleResult.value = finalResult

        // Start typewriter while animation finishes
        val typewriterJob = viewModelScope.launch { runTypewriter() }

        animTask.await()
        if (!currentCoroutineIsActive()) {
            typewriterJob.cancel()
            return
        }

        _phase.value = Phase.REVEALING
        typewriterJob.join()
        _phase.value = Phase.COMPLETE
    }

    private fun currentCoroutineIsActive() = viewModelScope.isActive

    // MARK: - Animation signal (called by BattleArena when its animation finishes)

    fun animationDidComplete() {
        _animationComplete.value = true
        animationSignal?.complete(Unit)
        animationSignal = null
    }

    private suspend fun waitForAnimation() {
        if (_animationComplete.value) return
        val signal = CompletableDeferred<Unit>()
        animationSignal = signal
        signal.await()
    }

    // MARK: - Typewriter

    private suspend fun runTypewriter() {
        val result = _battleResult.value ?: return
        _narrationDisplayed.value = ""
        val narration = result.narration
        for (i in narration.indices) {
            _narrationDisplayed.value = narration.substring(0, i + 1)
            delay(30)
        }
    }

    // MARK: - Rematch

    fun rematch() {
        animationSignal?.complete(Unit)
        animationSignal = null
        _phase.value = Phase.INTRO
        _battleResult.value = null
        _narrationDisplayed.value = ""
        _animationComplete.value = false
        _errorMessage.value = null
    }

    // MARK: - Fetch

    private suspend fun fetchResultIgnoringErrors(): BattleResult? {
        lastFetchErrorWasNetworkUnavailable = false
        return try {
            val req = BattleRequest(
                fighter1 = fighter1.id,
                fighter2 = fighter2.id,
                fighter1Name = fighter1.name,
                fighter2Name = fighter2.name,
                environmentName = if (arenaEffectsEnabled) environment.displayName else null,
                tournamentContext = tournamentContext,
            )
            val net = NetworkModule.battleApi.battle(req)
            BattleResult(
                winner = net.winner,
                narration = net.narration,
                funFact = net.funFact ?: "",
                winnerHealthPercent = Random.nextInt(60, 92),
                loserHealthPercent = Random.nextInt(2, 25),
            )
        } catch (ce: CancellationException) {
            throw ce
        } catch (io: IOException) {
            lastFetchErrorWasNetworkUnavailable = true
            _errorMessage.value = "No internet — using offline result"
            null
        } catch (t: Throwable) {
            _errorMessage.value = "Couldn't reach the battle server"
            null
        }
    }

    // MARK: - Fallback generation (mirrors BattleService.generateFallbackResult)

    private fun generateFallbackResult(markAsOffline: Boolean): BattleResult {
        val stats1 = AnimalStats.generate(fighter1, environment)
        val stats2 = AnimalStats.generate(fighter2, environment)
        val score1 = stats1.speed + stats1.power + stats1.agility + stats1.defense + Random.nextInt(-20, 21)
        val score2 = stats2.speed + stats2.power + stats2.agility + stats2.defense + Random.nextInt(-20, 21)

        val winner = when {
            kotlin.math.abs(score1 - score2) < 8 -> null // draw
            score1 > score2 -> fighter1
            else -> fighter2
        }
        val loser = if (winner == fighter1) fighter2 else fighter1
        val winnerId = winner?.id ?: "draw"

        val narration = if (winner != null) {
            "${winner.name} and ${loser.name} clashed in an intense showdown! In the end, ${winner.name} outmuscled the ${loser.name} and claimed victory."
        } else {
            "${fighter1.name} and ${fighter2.name} fought to a standstill — neither could land the decisive blow. An epic stalemate!"
        }
        val funFact = winner?.let { "The ${it.name} is famous for its fierce determination in battle." }
            ?: "Matchups this close are legendary — even the experts can't pick a winner."

        return BattleResult(
            winner = winnerId,
            narration = narration,
            funFact = funFact,
            winnerHealthPercent = if (winner != null) Random.nextInt(60, 92) else 50,
            loserHealthPercent = if (winner != null) Random.nextInt(2, 25) else 50,
            isOfflineFallback = markAsOffline,
        )
    }

    // MARK: - Tournament draw-breaking (mirrors iOS breakDrawIfNeeded)

    private fun breakDrawIfNeeded(result: BattleResult): BattleResult {
        if (result.winner != "draw") return result
        val winnerFirst = Random.nextBoolean()
        val winner = if (winnerFirst) fighter1 else fighter2
        val loser = if (winnerFirst) fighter2 else fighter1

        val narrationPool = listOf(
            "The ${winner.name} edged out the ${loser.name} in a brutal, back-and-forth clash! Both fought with everything they had, but the ${winner.name} landed the final decisive blow.",
            "After a hard-fought struggle, the ${winner.name} outlasted the ${loser.name} by sheer grit. It was close — but in the end, only one could stand tall.",
            "The ${winner.name} barely pulled ahead of the ${loser.name} in a neck-and-neck battle! Stamina won the day as the ${loser.name} finally yielded.",
        )
        val funFactPool = listOf(
            "The ${winner.name} is famous for its incredible combat instincts — every move counts.",
            "In the wild (or in legend), the ${winner.name} is known for refusing to give up against tougher opponents.",
            "The ${winner.name} earned this win with a perfect mix of strength and timing.",
        )
        return BattleResult(
            winner = winner.id,
            narration = narrationPool.random(),
            funFact = funFactPool.random(),
            winnerHealthPercent = Random.nextInt(45, 66),
            loserHealthPercent = Random.nextInt(5, 21),
            isOfflineFallback = result.isOfflineFallback,
        )
    }
}
