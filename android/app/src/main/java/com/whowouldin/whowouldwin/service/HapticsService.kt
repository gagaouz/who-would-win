package com.whowouldin.whowouldwin.service

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.whowouldin.whowouldwin.data.UserSettings

/**
 * Android port of iOS HapticsService.swift.
 *
 * Thin wrapper around the system Vibrator. All calls are no-ops when the user
 * has disabled haptics in Settings (mirrors iOS behavior exactly).
 *
 * Prefers `VibrationEffect.createPredefined` on API 29+, falls back to
 * `createOneShot` for older devices.
 */
class HapticsService private constructor(private val appContext: Context) {

    private val vibrator: Vibrator? = run {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = appContext.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            appContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private val hapticsEnabled: Boolean
        get() = UserSettings.instance(appContext).hapticsEnabledNow

    /** Light tap — button presses, card selections. */
    fun tap() {
        if (!hapticsEnabled) return
        oneShot(10, 50)
    }

    /** Medium impact — FIGHT! button, confirming selections. */
    fun medium() {
        if (!hapticsEnabled) return
        oneShot(20, 120)
    }

    /** Heavy impact — battle clash moment. */
    fun heavy() {
        if (!hapticsEnabled) return
        oneShot(30, 200)
    }

    /** Success notification — winner reveal (three-pulse). */
    fun success() {
        if (!hapticsEnabled) return
        pattern(longArrayOf(0, 25, 50, 25, 50, 25), intArrayOf(0, 180, 0, 180, 0, 180))
    }

    /** Error notification — draw or defeat (two-pulse). */
    fun warning() {
        if (!hapticsEnabled) return
        pattern(longArrayOf(0, 40, 80, 40), intArrayOf(0, 200, 0, 200))
    }

    private fun oneShot(durationMs: Long, amplitude: Int) {
        val v = vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createOneShot(durationMs, amplitude))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(durationMs)
        }
    }

    private fun pattern(timings: LongArray, amplitudes: IntArray) {
        val v = vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
        } else {
            @Suppress("DEPRECATION")
            v.vibrate(timings, -1)
        }
    }

    companion object {
        @Volatile private var INSTANCE: HapticsService? = null
        fun instance(context: Context): HapticsService {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: HapticsService(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
}
