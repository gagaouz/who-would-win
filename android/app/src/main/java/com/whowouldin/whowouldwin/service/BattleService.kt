package com.whowouldin.whowouldwin.service

import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalStats
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.model.BattleResult
import com.whowouldin.whowouldwin.network.BattleApi
import com.whowouldin.whowouldwin.network.BattleRequest
import com.whowouldin.whowouldwin.network.NetworkModule
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.HttpException
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import com.squareup.moshi.Moshi
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit
import kotlin.random.Random

/**
 * Android port of iOS BattleService.swift.
 *
 * Thin wrapper around the existing Retrofit [BattleApi]. Handles timeouts,
 * translates network/HTTP errors into the iOS-equivalent [BattleError] sealed
 * class, and provides the same deterministic offline fallback.
 *
 * Singleton — access via `BattleService.shared`.
 */
class BattleService private constructor() {

    // Two dedicated OkHttp clients let us match the iOS per-request timeouts:
    // 25s for full-narration calls, 20s for quick-mode.
    private val fullApi: BattleApi = buildApi(fullTimeoutSeconds)
    private val quickApi: BattleApi = buildApi(quickTimeoutSeconds)

    // region Network Battle (full narration)

    /**
     * Posts to `/api/battle`. Uses a 25 s timeout — enough headroom for a Railway
     * backend cold-start (~5–15 s) plus LLM round-trip without prematurely
     * tripping the offline fallback.
     */
    suspend fun fetchBattleResult(
        fighter1: Animal,
        fighter2: Animal,
        environment: BattleEnvironment = BattleEnvironment.GRASSLAND,
        arenaEffectsEnabled: Boolean = true,
        tournamentContext: String? = null,
    ): BattleResult {
        val req = BattleRequest(
            fighter1 = fighter1.id,
            fighter2 = fighter2.id,
            fighter1Name = fighter1.name,
            fighter2Name = fighter2.name,
            // Only send environment fields when arena effects are explicitly enabled.
            // Omitting them tells the backend to use neutral logic.
            environment = if (arenaEffectsEnabled) environment.name.lowercase() else null,
            environmentName = if (arenaEffectsEnabled) environment.displayName else null,
            // Tournament context: when present the backend skips its result cache
            // so each round gets fresh narration.
            tournamentContext = tournamentContext?.takeIf { it.isNotEmpty() },
        )
        return runWithErrorTranslation { fullApi.battle(req) }
    }

    // endregion

    // region Quick Battle (lightweight AI)

    /**
     * Calls `/api/battle/quick` — same AI logic but shorter prompt (~4× fewer
     * tokens). Used by tournament Quick Mode. Never returns a draw.
     * 20 s timeout absorbs Railway cold-start without making the user wait
     * through every wait-and-fail cycle.
     */
    suspend fun fetchQuickBattleResult(
        fighter1: Animal,
        fighter2: Animal,
        environment: BattleEnvironment = BattleEnvironment.GRASSLAND,
        arenaEffectsEnabled: Boolean = false,
    ): BattleResult {
        val req = BattleRequest(
            fighter1 = fighter1.id,
            fighter2 = fighter2.id,
            fighter1Name = fighter1.name,
            fighter2Name = fighter2.name,
            environment = if (arenaEffectsEnabled) environment.name.lowercase() else null,
            environmentName = if (arenaEffectsEnabled) environment.displayName else null,
        )
        val quick = runWithErrorTranslation { quickApi.quickBattle(req) }
        // Quick mode only returns a winner; synthesize the rest for UI parity
        // with full-mode BattleResult.
        val winnerAnimal = if (quick.winner == fighter1.id) fighter1 else fighter2
        val loserAnimal  = if (quick.winner == fighter1.id) fighter2 else fighter1
        return BattleResult(
            winner = quick.winner,
            narration = "${winnerAnimal.name} defeats ${loserAnimal.name}!",
            funFact = "",
            winnerHealthPercent = Random.nextInt(55, 91),
            loserHealthPercent  = Random.nextInt(5, 26),
            isOfflineFallback = false,
        )
    }

    // endregion

    // region Offline / Local Fallback

    /**
     * Determines winner based on environment-adjusted stat totals with some
     * randomness. Higher score wins ~70% of matchups, 10% draw chance.
     *
     * `markAsOffline` controls whether the result is flagged with
     * `isOfflineFallback = true`. Pass `true` only when the device is genuinely
     * offline; pass `false` when this is a local fallback for a server slowdown
     * / 5xx / rate-limit so the user does NOT see a misleading "⚡ Offline
     * result" badge while they're online.
     */
    fun generateFallbackResult(
        fighter1: Animal,
        fighter2: Animal,
        environment: BattleEnvironment = BattleEnvironment.GRASSLAND,
        markAsOffline: Boolean = true,
    ): BattleResult {
        val roll = Random.nextDouble(0.0, 1.0)

        // Environment-adjusted totals.
        val stats1 = AnimalStats.generate(fighter1, environment)
        val stats2 = AnimalStats.generate(fighter2, environment)
        val score1 = (stats1.speed + stats1.power + stats1.agility + stats1.defense).toDouble()
        val score2 = (stats2.speed + stats2.power + stats2.agility + stats2.defense).toDouble()

        val winner: String
        val winnerAnimal: Animal
        val loserAnimal: Animal

        if (roll < 0.10) {
            // 10% draw
            winner = "draw"
            winnerAnimal = fighter1
            loserAnimal  = fighter2
        } else {
            val totalScore = score1 + score2
            val p1WinChance = if (totalScore > 0.0) (score1 / totalScore * 0.6 + 0.2) else 0.5 // 0.2–0.8
            if (roll - 0.10 < (p1WinChance * 0.90)) {
                winner = fighter1.id
                winnerAnimal = fighter1
                loserAnimal  = fighter2
            } else {
                winner = fighter2.id
                winnerAnimal = fighter2
                loserAnimal  = fighter1
            }
        }

        val isDraw = winner == "draw"

        val narration = if (isDraw) {
            "Both the ${fighter1.name} and the ${fighter2.name} fought valiantly in an epic clash! " +
                "Neither could claim victory — the arena falls silent as both warriors stand their ground."
        } else {
            "The ${winnerAnimal.name} dominated the battle with sheer force and determination! " +
                "The ${loserAnimal.name} put up a fight, but ultimately had to concede defeat."
        }

        val funFact = if (isDraw) {
            "Both the ${fighter1.name} and the ${fighter2.name} are remarkable creatures in their own right — " +
                "nature truly has no equal here."
        } else {
            "The ${winnerAnimal.name} is a formidable creature with a size rating of " +
                "${winnerAnimal.size} out of 5 — making it a top-tier predator in its environment."
        }

        val winnerHealthPercent = if (isDraw) 50 else Random.nextInt(55, 91)
        val loserHealthPercent  = if (isDraw) 50 else Random.nextInt(5, 26)

        return BattleResult(
            winner = winner,
            narration = narration,
            funFact = funFact,
            winnerHealthPercent = winnerHealthPercent,
            loserHealthPercent = loserHealthPercent,
            isOfflineFallback = markAsOffline,
        )
    }

    // endregion

    // region Error translation

    private suspend inline fun <T> runWithErrorTranslation(block: () -> T): T {
        return try {
            block()
        } catch (e: HttpException) {
            when (e.code()) {
                429 -> throw BattleError.RateLimited
                else -> throw BattleError.ServerError
            }
        } catch (e: UnknownHostException) {
            throw BattleError.NetworkUnavailable
        } catch (e: SocketTimeoutException) {
            throw BattleError.NetworkUnavailable
        } catch (e: ConnectException) {
            throw BattleError.NetworkUnavailable
        } catch (e: IOException) {
            throw BattleError.NetworkUnavailable
        } catch (e: BattleError) {
            throw e
        } catch (e: Throwable) {
            throw BattleError.ServerError
        }
    }

    // endregion

    companion object {
        private const val fullTimeoutSeconds  = 25L
        private const val quickTimeoutSeconds = 20L

        val shared: BattleService by lazy { BattleService() }

        private fun buildApi(timeoutSeconds: Long): BattleApi {
            val moshi: Moshi = Moshi.Builder()
                .add(KotlinJsonAdapterFactory())
                .build()
            val okHttp = OkHttpClient.Builder()
                .connectTimeout(15, TimeUnit.SECONDS)
                .readTimeout(timeoutSeconds, TimeUnit.SECONDS)
                .writeTimeout(15, TimeUnit.SECONDS)
                .callTimeout(timeoutSeconds, TimeUnit.SECONDS)
                .addInterceptor(HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.NONE
                })
                .build()
            return Retrofit.Builder()
                .baseUrl(NetworkModule.baseUrl)
                .client(okHttp)
                .addConverterFactory(MoshiConverterFactory.create(moshi))
                .build()
                .create(BattleApi::class.java)
        }
    }
}

// MARK: - BattleError

/**
 * Error hierarchy mirroring iOS `enum BattleError`. UI code shows
 * `errorDescription` directly to the user (kids-app friendly copy).
 */
sealed class BattleError(val errorDescription: String) : Throwable(errorDescription) {
    data object ServerError       : BattleError("The battle server is resting. Try again!")
    data object NetworkUnavailable : BattleError("No internet! The animals need WiFi to fight.")
    data object RateLimited       : BattleError("Wow, you've been battling a lot! The arena needs a 15-minute break. Come back soon!")
}
