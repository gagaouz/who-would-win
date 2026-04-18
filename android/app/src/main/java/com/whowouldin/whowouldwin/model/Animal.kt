package com.whowouldin.whowouldwin.model

import com.squareup.moshi.JsonClass

/** Port of iOS Animal.swift. Snake_case id, display name, single emoji, category,
 *  brand pixel color, size 1–5 for sprite scaling. Custom = user-typed free-text. */
@JsonClass(generateAdapter = true)
data class Animal(
    val id: String,
    val name: String,
    val emoji: String,
    val category: AnimalCategory,
    val pixelColor: String,
    val size: Int,
    val isCustom: Boolean = false,
    val imageUrl: String? = null,
) {
    /** Drawable resource name for built-in creatures; null for custom. */
    val creatureAssetName: String?
        get() = if (isCustom) null else "creature_$id"
}

enum class AnimalCategory(val displayLabel: String) {
    ALL("ALL"),
    LAND("LAND"),
    SEA("SEA"),
    AIR("AIR"),
    INSECT("BUGS"),
    PREHISTORIC("DINOS"),  // unlocks at 100 battles
    FANTASY("FANTASY"),    // unlocks at 250 battles
    MYTHIC("MYTHIC"),      // unlocks at 500 battles
    OLYMPUS("OLYMPUS"),    // cheat-code only
}

data class AnimalStats(
    val speed: Int,
    val power: Int,
    val agility: Int,
    val defense: Int,
) {
    companion object {
        /** Generates deterministic stats from id + size + category, with environment multipliers. */
        fun generate(animal: Animal, environment: BattleEnvironment): AnimalStats {
            val base = generate(animal)
            return environment.multiplier(animal.category).apply(base)
        }

        /** Deterministic base stat generation — mirrors AnimalStats.generate(for:) in iOS. */
        fun generate(animal: Animal): AnimalStats {
            // Deterministic hash from id so same animal always gets same stats.
            // Swift uses Int overflow; Kotlin we use Int with explicit wrapping.
            var h = 0
            for (c in animal.id) {
                h = (h * 31) + c.code
            }
            fun component(seed: Int): Int = kotlin.math.abs((h + seed * 7919) % 41) // 0–40

            val sizeBonus = (animal.size - 1) * 9 // 0, 9, 18, 27, 36

            // Gods bypass normal stat generation — all stats land 80–97
            if (animal.category == AnimalCategory.OLYMPUS) {
                fun godComp(seed: Int): Int = kotlin.math.abs((h + seed * 7919) % 18) // 0–17
                return AnimalStats(
                    speed = minOf(97, godComp(1) + 80),
                    power = minOf(97, godComp(2) + 83),
                    agility = minOf(97, godComp(3) + 79),
                    defense = minOf(97, godComp(4) + 81),
                )
            }

            var spd = 0; var pwr = 0; var agi = 0; var def = 0
            when (animal.category) {
                AnimalCategory.AIR         -> { spd = 28; agi = 22; pwr = -12; def = -18 }
                AnimalCategory.SEA         -> { spd = 10; agi =  5; pwr =  10; def =   5 }
                AnimalCategory.INSECT      -> { spd = 12; agi = 18; pwr = -22; def = -12 }
                AnimalCategory.PREHISTORIC -> { spd = -8; pwr =  26; def = 18; agi = -12 }
                AnimalCategory.FANTASY     -> { spd = 10; pwr = 18; agi = 10; def = 10 }
                AnimalCategory.MYTHIC      -> { spd = 14; pwr = 24; agi = 14; def = 14 }
                else -> { /* LAND, ALL: no modifiers */ }
            }

            fun clamp(v: Int): Int = minOf(97, maxOf(12, v))
            return AnimalStats(
                speed   = clamp(component(1) + sizeBonus / 2 + spd + 30),
                power   = clamp(component(2) + sizeBonus     + pwr + 20),
                agility = clamp(component(3) + sizeBonus / 2 + agi + 30),
                defense = clamp(component(4) + sizeBonus     + def + 20),
            )
        }
    }
}
