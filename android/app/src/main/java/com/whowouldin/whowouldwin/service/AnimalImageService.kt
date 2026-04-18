package com.whowouldin.whowouldwin.service

import com.whowouldin.whowouldwin.model.AnimalCategory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

/**
 * Android port of iOS `AnimalImageService` — resolves Wikipedia page-image
 * URLs + short article extracts for custom (user-typed) creatures.
 *
 * Uses the public Wikipedia REST summary endpoint:
 *   https://en.wikipedia.org/api/rest_v1/page/summary/{title}
 *
 * Non-blocking — both calls return `null` on any failure; callers fall back
 * to emoji rendering.
 */
object AnimalImageService {
    val shared: AnimalImageService get() = this

    private val client by lazy {
        OkHttpClient.Builder()
            .connectTimeout(6, TimeUnit.SECONDS)
            .readTimeout(6, TimeUnit.SECONDS)
            .build()
    }

    data class AnimalInfo(
        val extract: String = "",
        val imageUrl: String? = null,
        val emoji: String = "🐾",
        val category: AnimalCategory = AnimalCategory.LAND,
        val pixelColor: String = "#888888",
    )

    suspend fun imageURL(name: String): String? = fetchSummary(name)?.imageUrl

    suspend fun fetchAnimalInfo(name: String): AnimalInfo = fetchSummary(name) ?: AnimalInfo()

    private suspend fun fetchSummary(name: String): AnimalInfo? = withContext(Dispatchers.IO) {
        runCatching {
            val title = URLEncoder.encode(name.trim().replace(' ', '_'), "UTF-8")
            val url = "https://en.wikipedia.org/api/rest_v1/page/summary/$title"
            val req = Request.Builder().url(url).header("User-Agent", "WhoWouldWin/1.0 Android").build()
            client.newCall(req).execute().use { resp ->
                if (!resp.isSuccessful) return@use null
                val body = resp.body?.string() ?: return@use null
                val json = JSONObject(body)
                val extract = json.optString("extract", "")
                val imageUrl = json.optJSONObject("thumbnail")?.optString("source")
                AnimalInfo(extract = extract, imageUrl = imageUrl?.takeIf { it.isNotBlank() })
            }
        }.getOrNull()
    }
}
