package com.whowouldin.whowouldwin.model

import androidx.compose.ui.graphics.Color
import com.whowouldin.whowouldwin.ui.theme.colorFromHex

/** Direct port of iOS BattleEnvironment.swift — nine environments with category-specific
 *  stat multipliers, tiered by free/earned/premium, with gradient + accent theme colors. */
enum class BattleEnvironment(
    val displayName: String,
    val emoji: String,
    val tagline: String,
    val tier: EnvTier,
    val battleThreshold: Int?,
    private val bgTopHex: String,
    private val bgBottomHex: String,
    private val accentHex: String,
) {
    GRASSLAND("Grassland", "🌿", "Open plains — no advantage",       EnvTier.FREE,    null, "#0E0B22", "#1C1640", "#6ECC6E"),
    OCEAN    ("Ocean",     "🌊", "Sea creatures dominate",            EnvTier.FREE,    null, "#050f1f", "#082040", "#2196F3"),
    SKY      ("Sky",       "☁️", "Aerial animals take flight",        EnvTier.FREE,    null, "#0a1a3a", "#1a3060", "#64B5F6"),
    ARCTIC   ("Arctic",    "❄️", "Cold-adapted fighters shine",        EnvTier.EARNED,  75,   "#0a1928", "#12283a", "#90CAF9"),
    DESERT   ("Desert",    "🏜️", "Speed & stamina rule",              EnvTier.EARNED,  150,  "#1e0e04", "#3a1e08", "#FFB347"),
    JUNGLE   ("Jungle",    "🌴", "Agility wins close quarters",       EnvTier.PREMIUM, null, "#051408", "#0d2b12", "#4CAF50"),
    VOLCANO  ("Volcano",   "🌋", "Raw power in the heat",             EnvTier.PREMIUM, null, "#1a0404", "#3a0808", "#FF5722"),
    NIGHT    ("Night",     "🌙", "Mythic hunters emerge",             EnvTier.PREMIUM, null, "#020208", "#0a0a20", "#9C27B0"),
    STORM    ("Storm",     "⚡", "Fast & fierce survive",             EnvTier.PREMIUM, null, "#060d18", "#0d1e30", "#FDD835");

    val bgTop: Color get() = colorFromHex(bgTopHex)
    val bgBottom: Color get() = colorFromHex(bgBottomHex)
    val accentColor: Color get() = colorFromHex(accentHex)

    /** Per-category multiplier table. Mirrors iOS multiplier(for:) exactly. */
    fun multiplier(category: AnimalCategory): EnvironmentMultiplier = when (this) {
        GRASSLAND -> EnvironmentMultiplier.NEUTRAL
        OCEAN -> when (category) {
            AnimalCategory.SEA         -> EnvironmentMultiplier(1.30, 1.15, 1.20, 1.10)
            AnimalCategory.LAND        -> EnvironmentMultiplier(0.60, 0.80, 0.55, 0.85)
            AnimalCategory.AIR         -> EnvironmentMultiplier(0.50, 0.55, 0.40, 0.75)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(0.70, 0.80, 0.60, 0.80)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(0.85, 1.05, 0.80, 1.00)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(0.90, 0.90, 0.90, 0.90)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(0.95, 0.95, 0.95, 0.95)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier(0.90, 1.05, 0.90, 1.00)
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
        SKY -> when (category) {
            AnimalCategory.AIR         -> EnvironmentMultiplier(1.40, 1.10, 1.35, 0.90)
            AnimalCategory.LAND        -> EnvironmentMultiplier(0.70, 0.85, 0.50, 0.85)
            AnimalCategory.SEA         -> EnvironmentMultiplier(0.30, 0.50, 0.25, 0.65)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(1.10, 0.90, 1.20, 0.85)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(0.80, 1.00, 0.75, 0.90)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(1.10, 1.10, 1.10, 1.00)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(1.05, 1.05, 1.05, 1.00)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier(1.15, 1.10, 1.15, 1.00)
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
        ARCTIC -> when (category) {
            AnimalCategory.SEA         -> EnvironmentMultiplier(1.10, 1.05, 1.10, 1.20)
            AnimalCategory.LAND        -> EnvironmentMultiplier(0.85, 0.95, 0.85, 1.10)
            AnimalCategory.AIR         -> EnvironmentMultiplier(0.75, 0.80, 0.70, 0.80)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(0.40, 0.50, 0.40, 0.50)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(0.90, 1.10, 0.85, 1.20)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(0.90, 0.95, 0.90, 1.00)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(0.95, 1.00, 0.95, 1.05)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier.NEUTRAL
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
        DESERT -> when (category) {
            AnimalCategory.LAND        -> EnvironmentMultiplier(1.15, 1.00, 1.10, 0.90)
            AnimalCategory.SEA         -> EnvironmentMultiplier(0.25, 0.50, 0.20, 0.65)
            AnimalCategory.AIR         -> EnvironmentMultiplier(1.10, 0.95, 1.10, 0.85)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(1.20, 1.10, 1.20, 1.00)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(0.90, 1.05, 0.85, 1.00)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(0.95, 0.95, 0.95, 0.95)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(1.00, 1.05, 1.00, 1.00)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier(1.05, 1.05, 1.05, 1.00)
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
        JUNGLE -> when (category) {
            AnimalCategory.LAND        -> EnvironmentMultiplier(0.90, 1.05, 1.20, 0.90)
            AnimalCategory.SEA         -> EnvironmentMultiplier(0.70, 0.75, 0.65, 0.80)
            AnimalCategory.AIR         -> EnvironmentMultiplier(0.80, 0.90, 0.85, 0.90)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(1.00, 1.15, 1.10, 1.00)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(0.85, 1.10, 0.90, 1.00)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(1.10, 1.10, 1.10, 1.00)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(1.05, 1.10, 1.10, 1.00)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier(1.00, 1.05, 1.00, 1.00)
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
        VOLCANO -> when (category) {
            AnimalCategory.LAND        -> EnvironmentMultiplier(0.80, 1.20, 0.75, 0.90)
            AnimalCategory.SEA         -> EnvironmentMultiplier(0.40, 0.50, 0.35, 0.60)
            AnimalCategory.AIR         -> EnvironmentMultiplier(0.75, 0.85, 0.70, 0.80)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(0.50, 0.60, 0.50, 0.55)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(1.00, 1.30, 0.90, 1.20)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(1.10, 1.25, 1.00, 1.10)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(1.05, 1.20, 1.00, 1.10)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier(1.00, 1.15, 1.00, 1.00)
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
        NIGHT -> when (category) {
            AnimalCategory.LAND        -> EnvironmentMultiplier(0.90, 0.95, 1.00, 0.90)
            AnimalCategory.SEA         -> EnvironmentMultiplier(0.90, 0.95, 0.90, 0.90)
            AnimalCategory.AIR         -> EnvironmentMultiplier(1.00, 1.05, 1.10, 0.95)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(1.20, 1.10, 1.20, 1.00)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(0.90, 1.00, 0.90, 0.95)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(1.15, 1.20, 1.15, 1.10)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(1.20, 1.25, 1.20, 1.10)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier(1.10, 1.10, 1.10, 1.00)
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
        STORM -> when (category) {
            AnimalCategory.LAND        -> EnvironmentMultiplier(0.75, 0.90, 0.70, 0.85)
            AnimalCategory.SEA         -> EnvironmentMultiplier(1.20, 1.15, 1.10, 0.90)
            AnimalCategory.AIR         -> EnvironmentMultiplier(1.25, 1.05, 1.20, 0.80)
            AnimalCategory.INSECT      -> EnvironmentMultiplier(0.40, 0.50, 0.40, 0.50)
            AnimalCategory.PREHISTORIC -> EnvironmentMultiplier(0.80, 1.05, 0.75, 0.95)
            AnimalCategory.FANTASY     -> EnvironmentMultiplier(1.10, 1.15, 1.05, 1.00)
            AnimalCategory.MYTHIC      -> EnvironmentMultiplier(1.10, 1.15, 1.10, 1.05)
            AnimalCategory.OLYMPUS     -> EnvironmentMultiplier(1.15, 1.20, 1.15, 1.05)
            AnimalCategory.ALL         -> EnvironmentMultiplier.NEUTRAL
        }
    }
}

enum class EnvTier { FREE, EARNED, PREMIUM }

data class EnvironmentMultiplier(
    val speed: Double,
    val power: Double,
    val agility: Double,
    val defense: Double,
) {
    fun apply(stats: AnimalStats): AnimalStats {
        fun clamp(v: Int) = minOf(99, maxOf(1, v))
        return AnimalStats(
            speed = clamp((stats.speed * speed).toInt()),
            power = clamp((stats.power * power).toInt()),
            agility = clamp((stats.agility * agility).toInt()),
            defense = clamp((stats.defense * defense).toInt()),
        )
    }

    companion object {
        val NEUTRAL = EnvironmentMultiplier(1.0, 1.0, 1.0, 1.0)
    }
}
