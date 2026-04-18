package com.whowouldin.whowouldwin.service

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.Locale

/**
 * Android equivalent of iOS `Services/SpeechService.swift`.
 *
 * Uses Android [TextToSpeech] for narration playback. Singleton so the TTS engine
 * is initialized once and reused across battles. Mirrors iOS API:
 *   - [speak] with toggle-off if currently speaking
 *   - [stop]
 *   - [hasHighQualityVoice] (Network-tier voice)
 *   - [hasSeenVoiceQualityPrompt] flag (persisted in SharedPreferences to match
 *     iOS `UserSettings.hasSeenVoiceQualityPrompt`)
 */
object SpeechService {

    private var tts: TextToSpeech? = null
    private var initialized = false
    private var pendingText: String? = null
    private var appContext: Context? = null

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking

    /** Called once from Application.onCreate or lazily on first use. */
    fun init(context: Context) {
        if (tts != null) return
        appContext = context.applicationContext
        tts = TextToSpeech(context.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.US
                tts?.setPitch(1.0f)
                tts?.setSpeechRate(0.95f)
                selectBestVoice()
                initialized = true
                pendingText?.let { speakNow(it) }
                pendingText = null
            }
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) { _isSpeaking.value = true }
            override fun onDone(utteranceId: String?) { _isSpeaking.value = false }
            @Deprecated("Deprecated in API 21")
            override fun onError(utteranceId: String?) { _isSpeaking.value = false }
            override fun onError(utteranceId: String?, errorCode: Int) { _isSpeaking.value = false }
        })
    }

    /**
     * Speak the given text. If currently speaking, toggles off (iOS parity).
     * Safe to call before [init] — will auto-init using the provided context.
     */
    fun speak(context: Context, text: String) {
        if (tts == null) init(context)
        if (_isSpeaking.value) {
            stop()
            return
        }
        if (!initialized) {
            pendingText = text
            return
        }
        speakNow(text)
    }

    private fun speakNow(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "narration-${System.currentTimeMillis()}")
        _isSpeaking.value = true
    }

    fun stop() {
        tts?.stop()
        _isSpeaking.value = false
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        initialized = false
    }

    /**
     * True when the device has at least one "Network"-quality or Enhanced English voice
     * available — the Android equivalent of iOS's premium/enhanced voice check.
     * Android marks Network voices with [Voice.QUALITY_VERY_HIGH] or [Voice.QUALITY_HIGH]
     * and features `FEATURE_NOT_INSTALLED == false`.
     */
    val hasHighQualityVoice: Boolean
        get() {
            val voices = runCatching { tts?.voices ?: emptySet() }.getOrElse { emptySet() }
            return voices.any { v ->
                v.locale.language == "en" &&
                    (v.quality >= Voice.QUALITY_HIGH) &&
                    !v.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)
            }
        }

    private fun selectBestVoice() {
        val voices = runCatching { tts?.voices ?: emptySet() }.getOrElse { emptySet() }
        val englishVoices = voices.filter { it.locale.language == "en" }
        val best = englishVoices
            .filter { !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) }
            .maxByOrNull { it.quality }
            ?: englishVoices.firstOrNull()
        best?.let { tts?.voice = it }
    }

    // MARK: - Voice-quality prompt flag (mirrors iOS hasSeenVoiceQualityPrompt)

    private const val PREFS = "speech_service_prefs"
    private const val KEY_SEEN_PROMPT = "hasSeenVoiceQualityPrompt"

    fun hasSeenVoiceQualityPrompt(context: Context): Boolean {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_SEEN_PROMPT, false)
    }

    fun markVoiceQualityPromptSeen(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_SEEN_PROMPT, true).apply()
    }
}
