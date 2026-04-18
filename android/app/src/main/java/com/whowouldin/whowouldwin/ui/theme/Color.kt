package com.whowouldin.whowouldwin.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.whowouldin.whowouldwin.model.AnimalCategory

/** Parses `#RRGGBB` or `#AARRGGBB` to Compose Color. */
fun colorFromHex(hex: String): Color {
    val clean = hex.removePrefix("#")
    return when (clean.length) {
        6 -> Color(
            red = clean.substring(0, 2).toInt(16) / 255f,
            green = clean.substring(2, 4).toInt(16) / 255f,
            blue = clean.substring(4, 6).toInt(16) / 255f,
        )
        8 -> Color(
            alpha = clean.substring(0, 2).toInt(16) / 255f,
            red = clean.substring(2, 4).toInt(16) / 255f,
            green = clean.substring(4, 6).toInt(16) / 255f,
            blue = clean.substring(6, 8).toInt(16) / 255f,
        )
        else -> Color.Magenta
    }
}

/**
 * Full port of iOS `Views/Components/Theme.swift`. Brand-neutral colors as
 * constants; adaptive surfaces as @Composable functions that read isSystemInDarkTheme.
 */
object BrandTheme {
    // Brand — universal, work on any background
    val orange   = colorFromHex("#FF9800")
    val yellow   = colorFromHex("#FFEB3B")
    val gold     = colorFromHex("#FDD835")
    val purple   = colorFromHex("#BA68C8")
    val cyan     = colorFromHex("#00E5FF")
    val teal     = colorFromHex("#26A69A")
    val red      = colorFromHex("#F44336")
    val neonGrn  = colorFromHex("#69F0AE")
    val blue     = colorFromHex("#42A5F5")

    // Supercell-style 3D button colors
    val btnOrangeTop    = colorFromHex("#FFB74D")
    val btnOrangeMid    = colorFromHex("#FF9800")
    val btnOrangeBot    = colorFromHex("#F57C00")
    val btnOrangeShadow = colorFromHex("#E65100")

    val btnGreenTop     = colorFromHex("#69F0AE")
    val btnGreenMid     = colorFromHex("#4CAF50")
    val btnGreenBot     = colorFromHex("#388E3C")
    val btnGreenShadow  = colorFromHex("#1B5E20")

    val btnPurpleTop    = colorFromHex("#E1BEE7")
    val btnPurpleMid    = colorFromHex("#BA68C8")
    val btnPurpleBot    = colorFromHex("#9C27B0")
    val btnPurpleShadow = colorFromHex("#6A1B9A")

    val btnGoldTop      = colorFromHex("#FFF176")
    val btnGoldMid      = colorFromHex("#FFEB3B")
    val btnGoldBot      = colorFromHex("#FDD835")
    val btnGoldShadow   = colorFromHex("#F9A825")

    val btnBlueTop      = colorFromHex("#64B5F6")
    val btnBlueMid      = colorFromHex("#2196F3")
    val btnBlueBot      = colorFromHex("#1976D2")
    val btnBlueShadow   = colorFromHex("#0D47A1")

    val btnRedTop       = colorFromHex("#EF9A9A")
    val btnRedMid       = colorFromHex("#F44336")
    val btnRedBot       = colorFromHex("#D32F2F")
    val btnRedShadow    = colorFromHex("#B71C1C")

    // Category accents
    val landAccent        = colorFromHex("#FF8F00")
    val seaAccent         = colorFromHex("#1E88E5")
    val airAccent         = colorFromHex("#29B6F6")
    val insectAccent      = colorFromHex("#43A047")
    val fantasyAccent     = colorFromHex("#AB47BC")
    val prehistoricAccent = colorFromHex("#FF8F00")
    val mythicAccent      = colorFromHex("#FDD835")
    val olympusAccent     = colorFromHex("#42A5F5")

    @Composable fun bgDeep(): Color =
        if (isSystemInDarkTheme()) colorFromHex("#1A237E") else colorFromHex("#EAF3FF")
    @Composable fun bgMid(): Color =
        if (isSystemInDarkTheme()) colorFromHex("#0D47A1") else colorFromHex("#DEF1FF")
    @Composable fun bgCard(): Color =
        if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.10f) else Color.White
    @Composable fun bgSurface(): Color =
        if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.08f) else colorFromHex("#F0F7FF")
    @Composable fun textPrimary(): Color =
        if (isSystemInDarkTheme()) Color.White else colorFromHex("#1A237E")
    @Composable fun textSecondary(): Color =
        if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.60f)
        else Color(0.259f, 0.310f, 0.569f, 0.85f)
    @Composable fun textTertiary(): Color =
        if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.35f)
        else Color(0.36f, 0.40f, 0.60f, 0.60f)
    @Composable fun cardFill(): Color =
        if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.88f)
    @Composable fun cardBorder(): Color =
        if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.20f) else Color(0.60f, 0.70f, 0.90f, 0.40f)
    @Composable fun divider(): Color =
        if (isSystemInDarkTheme()) Color.White.copy(alpha = 0.10f) else Color(0.60f, 0.70f, 0.90f, 0.25f)

    @Composable fun homeGradient(): Brush =
        if (isSystemInDarkTheme()) Brush.linearGradient(
            0.0f to colorFromHex("#0A0A1A"),
            0.5f to colorFromHex("#12082A"),
            1.0f to colorFromHex("#0A1628"),
        ) else Brush.verticalGradient(
            0.00f to colorFromHex("#42A5F5"),
            0.25f to colorFromHex("#1E88E5"),
            0.50f to colorFromHex("#43A047"),
            0.75f to colorFromHex("#2E7D32"),
            1.00f to colorFromHex("#1B5E20"),
        )

    @Composable fun battleGradient(): Brush =
        if (isSystemInDarkTheme()) Brush.verticalGradient(
            0.0f to colorFromHex("#06060F"),
            0.5f to colorFromHex("#0D0820"),
            1.0f to colorFromHex("#0A1228"),
        ) else Brush.verticalGradient(
            0.00f to colorFromHex("#1A237E"),
            0.25f to colorFromHex("#0D47A1"),
            0.50f to colorFromHex("#1565C0"),
            0.75f to colorFromHex("#0D47A1"),
            1.00f to colorFromHex("#1A237E"),
        )

    @Composable fun unlockGradient(): Brush =
        if (isSystemInDarkTheme()) Brush.verticalGradient(
            0.0f to colorFromHex("#1A0A2E"),
            0.5f to colorFromHex("#12082A"),
            1.0f to colorFromHex("#0A0A1A"),
        ) else Brush.verticalGradient(
            0.00f to colorFromHex("#9C27B0"),
            0.33f to colorFromHex("#7B1FA2"),
            0.66f to colorFromHex("#6A1B9A"),
            1.00f to colorFromHex("#4A148C"),
        )

    val ctaGradient: Brush = Brush.verticalGradient(listOf(btnOrangeTop, btnOrangeMid, btnOrangeBot))
    val purpleGradient: Brush = Brush.verticalGradient(listOf(btnPurpleTop, btnPurpleMid, btnPurpleBot))
    val greenGradient: Brush = Brush.verticalGradient(listOf(btnGreenTop, btnGreenMid, btnGreenBot))
    val goldGradient: Brush = Brush.verticalGradient(listOf(btnGoldTop, btnGoldMid, btnGoldBot))
    val blueGradient: Brush = Brush.verticalGradient(listOf(btnBlueTop, btnBlueMid, btnBlueBot))
    val redGradient: Brush = Brush.verticalGradient(listOf(btnRedTop, btnRedMid, btnRedBot))

    fun categoryGradient(cat: AnimalCategory): Brush = when (cat) {
        AnimalCategory.LAND, AnimalCategory.PREHISTORIC ->
            Brush.linearGradient(listOf(colorFromHex("#FFB74D"), colorFromHex("#FF8F00")))
        AnimalCategory.SEA ->
            Brush.linearGradient(listOf(colorFromHex("#64B5F6"), colorFromHex("#1E88E5")))
        AnimalCategory.AIR ->
            Brush.linearGradient(listOf(colorFromHex("#81D4FA"), colorFromHex("#29B6F6")))
        AnimalCategory.INSECT ->
            Brush.linearGradient(listOf(colorFromHex("#81C784"), colorFromHex("#43A047")))
        AnimalCategory.FANTASY ->
            Brush.linearGradient(listOf(colorFromHex("#CE93D8"), colorFromHex("#AB47BC")))
        AnimalCategory.MYTHIC ->
            Brush.linearGradient(listOf(colorFromHex("#FFF176"), colorFromHex("#FDD835")))
        AnimalCategory.OLYMPUS ->
            Brush.linearGradient(listOf(colorFromHex("#90CAF9"), colorFromHex("#42A5F5")))
        AnimalCategory.ALL ->
            Brush.linearGradient(listOf(colorFromHex("#64B5F6"), colorFromHex("#42A5F5")))
    }

    fun categoryAccent(cat: AnimalCategory): Color = when (cat) {
        AnimalCategory.LAND, AnimalCategory.PREHISTORIC -> landAccent
        AnimalCategory.SEA -> seaAccent
        AnimalCategory.AIR -> airAccent
        AnimalCategory.INSECT -> insectAccent
        AnimalCategory.FANTASY -> fantasyAccent
        AnimalCategory.MYTHIC -> mythicAccent
        AnimalCategory.OLYMPUS -> olympusAccent
        AnimalCategory.ALL -> blue
    }

    fun categoryEmoji(cat: AnimalCategory): String = when (cat) {
        AnimalCategory.ALL -> "🌍"
        AnimalCategory.LAND -> "🌿"
        AnimalCategory.SEA -> "🌊"
        AnimalCategory.AIR -> "☁️"
        AnimalCategory.INSECT -> "🐛"
        AnimalCategory.FANTASY -> "✨"
        AnimalCategory.PREHISTORIC -> "🦖"
        AnimalCategory.MYTHIC -> "⚡"
        AnimalCategory.OLYMPUS -> "🏛️"
    }

    fun categoryLabel(cat: AnimalCategory): String = when (cat) {
        AnimalCategory.ALL -> "All"
        AnimalCategory.LAND -> "Land"
        AnimalCategory.SEA -> "Sea"
        AnimalCategory.AIR -> "Air"
        AnimalCategory.INSECT -> "Bugs"
        AnimalCategory.FANTASY -> "Fantasy"
        AnimalCategory.PREHISTORIC -> "Dinos"
        AnimalCategory.MYTHIC -> "Mythic"
        AnimalCategory.OLYMPUS -> "Olympus"
    }
}

/** Kept for back-compat with the existing scaffold — aliases into BrandTheme. */
object BrandColors {
    val Orange = BrandTheme.orange
    val Yellow = BrandTheme.yellow
    val Gold   = BrandTheme.gold
    val Cyan   = BrandTheme.cyan
    val Red    = BrandTheme.red
    val BattleBg     = colorFromHex("#0A0A1A")
    val BattleBgDeep = colorFromHex("#06060F")
    val PanelBg      = colorFromHex("#14102A")
    val TextPrimary   = Color.White
    val TextSecondary = Color.White.copy(alpha = 0.70f)
    val TextTertiary  = Color.White.copy(alpha = 0.50f)
}

internal val DarkColors = darkColorScheme(
    primary = BrandTheme.orange,
    onPrimary = Color.White,
    secondary = BrandTheme.yellow,
    onSecondary = Color.Black,
    tertiary = BrandTheme.cyan,
    background = colorFromHex("#0A0A1A"),
    onBackground = Color.White,
    surface = Color.White.copy(alpha = 0.08f),
    onSurface = Color.White,
)

internal val LightColors = lightColorScheme(
    primary = BrandTheme.orange,
    onPrimary = Color.White,
    secondary = BrandTheme.gold,
    onSecondary = Color.Black,
    tertiary = BrandTheme.blue,
    background = colorFromHex("#EAF3FF"),
    onBackground = colorFromHex("#1A237E"),
    surface = Color.White,
    onSurface = colorFromHex("#1A237E"),
)
