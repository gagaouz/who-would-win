package com.whowouldin.whowouldwin.service

import android.content.Context
import android.content.SharedPreferences

/**
 * Thin synchronous wrapper around [SharedPreferences] — used for small flags
 * that don't warrant DataStore's async API (e.g. one-shot UI hints).
 *
 * Primary store [UserSettings] handles the structured app state.
 */
class UserPrefs(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("user_prefs", Context.MODE_PRIVATE)

    fun getInt(key: String, default: Int = 0): Int = prefs.getInt(key, default)
    fun setInt(key: String, value: Int) { prefs.edit().putInt(key, value).apply() }

    fun getBool(key: String, default: Boolean = false): Boolean = prefs.getBoolean(key, default)
    fun setBool(key: String, value: Boolean) { prefs.edit().putBoolean(key, value).apply() }

    fun getString(key: String, default: String? = null): String? = prefs.getString(key, default)
    fun setString(key: String, value: String?) { prefs.edit().putString(key, value).apply() }
}
