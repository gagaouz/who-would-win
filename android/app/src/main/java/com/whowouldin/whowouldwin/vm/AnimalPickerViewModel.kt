package com.whowouldin.whowouldwin.vm

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.whowouldin.whowouldwin.data.Animals
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalCategory
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.service.AnimalImageService
import com.whowouldin.whowouldwin.service.CheatState
import com.whowouldin.whowouldwin.service.ContentFilter
import com.whowouldin.whowouldwin.service.UserPrefs
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Port of iOS `AnimalPickerViewModel.swift` to Jetpack Compose / Android.
 *
 * Exposes a single [UiState] [StateFlow] consumed by [AnimalPickerScreen]. All
 * derived state (filtered list, canFight, lockedAnimal, customAnimal) lives on
 * the state object so the Compose side can `collectAsStateWithLifecycle()`
 * once and read everything.
 *
 * Design notes:
 *  - Cheat-code tap counter is session-only and lives on [CheatState] (see the
 *    original iOS `CheatState.shared.olympusUnlocked`). The view owns its own
 *    `olympusCheatStep` because it's a transient UI-level tap sequence.
 *  - Dual-path custom-creature flow is modeled as two VM entry points:
 *    [payCoinsForCustom] and [watchAdForCustom] (the caller hands in a
 *    "granted" result for the ad path). Both delegate to [selectAnimal].
 *  - First-free custom battle is a Boolean persisted through [UserPrefs]
 *    under the key `"custom.freeUsed"` — same key as iOS.
 *  - Debounced custom-creature image lookup mirrors the iOS
 *    `searchTextSubject.debounce(0.5s)` Combine pipeline.
 */
class AnimalPickerViewModel(app: Application) : AndroidViewModel(app) {

    private val userPrefs = UserPrefs(app.applicationContext)
    private val cheat = CheatState
    private val imageService = AnimalImageService

    // One hot flow of raw search-text emissions for the debounce pipeline.
    private val searchTextChanges = MutableSharedFlow<String>(extraBufferCapacity = 64)

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var customFetchJob: Job? = null

    init {
        // Hydrate persistent first-run flags.
        viewModelScope.launch {
            val hintCount = userPrefs.getInt(KEY_HINT_SHOWN, 0)
            val freeUsed = userPrefs.getBool(KEY_FREE_USED, false)
            _state.update { it.copy(hintShowCount = hintCount, customFreeUsed = freeUsed) }
        }

        // Debounced custom-creature info fetch — only fires when no built-in matches.
        wireCustomLookupPipeline()
    }

    @OptIn(FlowPreview::class)
    private fun wireCustomLookupPipeline() {
        viewModelScope.launch {
            searchTextChanges
                .debounce(500)
                .onEach { raw ->
                    val trimmed = raw.trim()
                    if (trimmed.isEmpty()) return@onEach
                    val hasMatches = Animals.all.any {
                        it.name.contains(trimmed, ignoreCase = true)
                    }
                    if (!hasMatches) fetchCustomAnimalInfo(trimmed)
                }
                .collect { /* consume */ }
        }
    }

    // ---- Search ---------------------------------------------------------

    fun onSearchTextChanged(text: String) {
        _state.update {
            val reset = text.trim().isEmpty()
            it.copy(
                searchText = text,
                customEmoji = if (reset) DEFAULT_EMOJI else it.customEmoji,
                customCategory = if (reset) AnimalCategory.LAND else it.customCategory,
                customColor = if (reset) DEFAULT_COLOR else it.customColor,
                customImageUrl = if (reset) null else it.customImageUrl,
            )
        }
        searchTextChanges.tryEmit(text)
    }

    fun clearSearch() = onSearchTextChanged("")

    // ---- Category / environment / arena toggle ---------------------------

    fun selectCategory(category: AnimalCategory) {
        _state.update { it.copy(selectedCategory = category) }
    }

    fun selectEnvironment(env: BattleEnvironment) {
        _state.update { it.copy(chosenEnvironment = env) }
    }

    fun setArenaEffectsEnabled(enabled: Boolean) {
        _state.update { it.copy(arenaEffectsEnabled = enabled) }
    }

    // ---- Selection ------------------------------------------------------

    /** Mirrors iOS `select(_:)` — prefers empty slot 1, then slot 2, else
     *  replaces slot 2. Never duplicates the same animal into both slots. */
    fun select(animal: Animal) {
        _state.update { s ->
            when {
                s.fighter1 == null -> s.copy(fighter1 = animal)
                s.fighter2 == null && animal != s.fighter1 -> s.copy(fighter2 = animal)
                animal != s.fighter1 -> s.copy(fighter2 = animal)
                else -> s
            }
        }
    }

    /** Convenience used by the custom-creature buttons — selects & clears the
     *  search box so the grid is immediately usable for the second pick. */
    fun selectAnimal(animal: Animal) {
        select(animal)
        onSearchTextChanged("")
    }

    fun clearSlot(slot: Int) {
        _state.update {
            when (slot) {
                1 -> it.copy(fighter1 = null)
                2 -> it.copy(fighter2 = null)
                else -> it
            }
        }
    }

    fun toggleAnimal(animal: Animal) {
        val s = _state.value
        when {
            s.fighter1?.id == animal.id -> clearSlot(1)
            s.fighter2?.id == animal.id -> clearSlot(2)
            else -> select(animal)
        }
    }

    fun reset() {
        _state.update {
            UiState(
                hintShowCount = it.hintShowCount,
                customFreeUsed = it.customFreeUsed,
            )
        }
    }

    // ---- Hint bookkeeping ----------------------------------------------

    /** Called by the view after the hint has been displayed once. Bumps the
     *  visible-count persisted counter; hint disappears at 3. */
    fun markHintShown() {
        viewModelScope.launch {
            val next = _state.value.hintShowCount + 1
            userPrefs.setInt(KEY_HINT_SHOWN, next)
            _state.update { it.copy(hintShowCount = next) }
        }
    }

    // ---- Dual-path custom creature -------------------------------------

    /** User tapped the BIG free button (first-use path). Marks `custom.freeUsed`
     *  true and selects the creature. Returns the animal that was selected. */
    fun claimFreeCustom(animal: Animal): Animal {
        viewModelScope.launch {
            userPrefs.setBool(KEY_FREE_USED, true)
            _state.update { it.copy(customFreeUsed = true) }
        }
        selectAnimal(animal)
        return animal
    }

    /** Coin path — caller already called CoinStore.spend(cost). We just select. */
    fun onCoinsSpentForCustom(animal: Animal) = selectAnimal(animal)

    /** Ad path — caller shows a rewarded ad via [AdManager] and calls this with
     *  the grant result. */
    fun onAdGrantedForCustom(animal: Animal, granted: Boolean) {
        if (granted) selectAnimal(animal)
    }

    // ---- Image lookup --------------------------------------------------

    private fun fetchCustomAnimalInfo(name: String) {
        // Only one in-flight lookup at a time; latest wins.
        customFetchJob?.cancel()
        if (!ContentFilter.isAppropriate(name)) return

        customFetchJob = viewModelScope.launch {
            coroutineScope {
                val infoDeferred = async { imageService.fetchAnimalInfo(name) }
                val imageDeferred = async { imageService.imageURL(name) }
                val info = infoDeferred.await()
                val imageUrl = imageDeferred.await()

                // Bail if the user has kept typing past this fetch.
                val current = _state.value.searchText.trim()
                if (current != name) return@coroutineScope

                _state.update {
                    it.copy(
                        customEmoji = info.emoji,
                        customCategory = info.category,
                        customColor = info.pixelColor,
                        customImageUrl = imageUrl,
                    )
                }
            }
        }
    }

    // ---- Derived helpers read by the screen -----------------------------

    /** Filters the roster by (category, search, Olympus visibility). */
    fun filteredAnimals(s: UiState = _state.value): List<Animal> {
        val olympusVisible = cheat.olympusUnlocked.value || s.isOlympusUnlockedPersisted
        return Animals.all.filter { animal ->
            if (animal.category == AnimalCategory.OLYMPUS && !olympusVisible) return@filter false
            val categoryMatch =
                s.selectedCategory == AnimalCategory.ALL || animal.category == s.selectedCategory
            val searchMatch =
                s.searchText.isBlank() || animal.name.contains(s.searchText, ignoreCase = true)
            categoryMatch && searchMatch
        }
    }

    /** The iOS `lockedAnimal` computed prop — a known creature the user
     *  hasn't unlocked whose name is an exact (case-insensitive) match. */
    fun lockedAnimal(s: UiState = _state.value): Animal? {
        val trimmed = s.searchText.trim()
        if (trimmed.isEmpty() || filteredAnimals(s).isNotEmpty()) return null
        return Animals.all.firstOrNull { it.name.equals(trimmed, ignoreCase = true) }
    }

    /** The iOS `customAnimal` computed prop. */
    fun customAnimal(s: UiState = _state.value): Animal? {
        val trimmed = s.searchText.trim()
        if (trimmed.isEmpty()) return null
        if (filteredAnimals(s).isNotEmpty()) return null
        if (lockedAnimal(s) != null) return null
        if (!ContentFilter.isAppropriate(trimmed)) return null
        return Animal(
            id = trimmed.lowercase().replace(" ", "_"),
            name = trimmed.replaceFirstChar { it.uppercase() },
            emoji = s.customEmoji,
            category = s.customCategory,
            pixelColor = s.customColor,
            size = 3,
            isCustom = true,
            imageUrl = s.customImageUrl,
        )
    }

    companion object {
        private const val KEY_HINT_SHOWN = "custom.hintShown"
        private const val KEY_FREE_USED = "custom.freeUsed"
        private const val DEFAULT_EMOJI = "🐾"
        private const val DEFAULT_COLOR = "#888888"
    }
}

/** Immutable state rendered by [AnimalPickerScreen]. */
data class UiState(
    val fighter1: Animal? = null,
    val fighter2: Animal? = null,
    val searchText: String = "",
    val selectedCategory: AnimalCategory = AnimalCategory.ALL,
    val chosenEnvironment: BattleEnvironment = BattleEnvironment.GRASSLAND,
    val arenaEffectsEnabled: Boolean = false,

    // Custom creature lookup state
    val customEmoji: String = "🐾",
    val customCategory: AnimalCategory = AnimalCategory.LAND,
    val customColor: String = "#888888",
    val customImageUrl: String? = null,

    // Persistent first-run flags (hydrated from DataStore)
    val hintShowCount: Int = 0,
    val customFreeUsed: Boolean = false,

    // Settings snapshot (hydrated from UserSettings observer)
    val isFantasyUnlockedPersisted: Boolean = false,
    val isPrehistoricUnlockedPersisted: Boolean = false,
    val isMythicUnlockedPersisted: Boolean = false,
    val isOlympusUnlockedPersisted: Boolean = false,
) {
    val canFight: Boolean get() = fighter1 != null && fighter2 != null
}
