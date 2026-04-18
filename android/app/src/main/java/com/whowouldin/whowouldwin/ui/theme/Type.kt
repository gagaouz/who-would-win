package com.whowouldin.whowouldwin.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.R

/**
 * Typography — mirrors iOS Theme.bungee() / Theme.lilita() / Theme.display() / etc.
 *
 * Font files live in `res/font/`:
 *   - bungee_regular.ttf    (Bungee, chunky display — titles, VS badge, WINNER!)
 *   - lilita_one_regular.ttf (Lilita One, kid-friendly bold — buttons, card names)
 *
 * If the .ttf files are missing at build time the build fails at R.font lookup —
 * that's intentional so you can't accidentally ship with the wrong fonts.
 */

val BungeeFamily = FontFamily(Font(R.font.bungee_regular, FontWeight.Normal))
val LilitaFamily = FontFamily(Font(R.font.lilita_one_regular, FontWeight.Normal))

fun bungee(size: Int): TextStyle = TextStyle(fontFamily = BungeeFamily, fontSize = size.sp)
fun lilita(size: Int): TextStyle = TextStyle(fontFamily = LilitaFamily, fontSize = size.sp)

// System fallbacks for body/label (Android has no `.rounded` SF variant)
fun display(size: Int): TextStyle = TextStyle(fontWeight = FontWeight.Black, fontSize = size.sp)
fun headline(size: Int): TextStyle = TextStyle(fontWeight = FontWeight.Bold, fontSize = size.sp)
fun bodyFont(size: Int): TextStyle = TextStyle(fontWeight = FontWeight.Medium, fontSize = size.sp)
fun labelFont(size: Int): TextStyle = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = size.sp)

val AppTypography = Typography(
    displayLarge = bungee(48),
    displayMedium = bungee(36),
    displaySmall = bungee(28),
    headlineLarge = lilita(28),
    headlineMedium = lilita(22),
    headlineSmall = lilita(18),
    titleLarge = lilita(20),
    titleMedium = lilita(16),
    titleSmall = lilita(14),
    bodyLarge = bodyFont(16),
    bodyMedium = bodyFont(14),
    bodySmall = bodyFont(12),
    labelLarge = labelFont(14),
    labelMedium = labelFont(12),
    labelSmall = labelFont(10),
)
