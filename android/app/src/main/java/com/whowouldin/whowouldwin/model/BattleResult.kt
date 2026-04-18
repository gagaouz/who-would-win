package com.whowouldin.whowouldwin.model

import com.squareup.moshi.JsonClass

@JsonClass(generateAdapter = true)
data class BattleResult(
    val winner: String,               // Animal id, or "draw"
    val narration: String,            // 2-sentence battle narration
    val funFact: String,              // one fun fact about the winner
    val winnerHealthPercent: Int,     // 10–90 — how dominant the win was
    val loserHealthPercent: Int,      // 0–25 — how much fight the loser put up
    @Transient val isOfflineFallback: Boolean = false,
)
