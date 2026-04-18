package com.whowouldin.whowouldwin.network

import com.squareup.moshi.JsonClass
import com.whowouldin.whowouldwin.model.BattleResult
import retrofit2.http.Body
import retrofit2.http.POST

/**
 * Matches backend/src/routes/battle.ts.
 * Endpoints:
 *   POST /api/battle       — full Claude narration (~400 tokens)
 *   POST /api/battle/quick — lightweight winner-only (~100 tokens)
 *
 * Base URL lives in NetworkModule.
 */

@JsonClass(generateAdapter = true)
data class BattleRequest(
    val fighter1: String,
    val fighter2: String,
    val fighter1Name: String? = null,
    val fighter2Name: String? = null,
    /** iOS raw value of the environment enum — e.g. "ocean", "volcano". */
    val environment: String? = null,
    val environmentName: String? = null,
    val tournamentContext: String? = null,
)

/** Quick-mode responses only include the winner. */
@JsonClass(generateAdapter = true)
data class QuickBattleResult(
    val winner: String,
)

interface BattleApi {
    @POST("api/battle")
    suspend fun battle(@Body req: BattleRequest): BattleResult

    @POST("api/battle/quick")
    suspend fun quickBattle(@Body req: BattleRequest): QuickBattleResult
}
