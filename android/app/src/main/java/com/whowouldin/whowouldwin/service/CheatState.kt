package com.whowouldin.whowouldwin.service

import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Android port of iOS CheatState.swift.
 *
 * In-memory cheat unlock state. Intentionally NOT persisted — resets to false
 * every time the process is killed.
 */
object CheatState {
    val olympusUnlocked = MutableStateFlow(false)
}
