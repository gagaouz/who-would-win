package com.whowouldin.whowouldwin.ui.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.ui.theme.BungeeFamily

/**
 * Port of iOS `Views/Components/PixelText.swift`.
 *
 * iOS uses the PressStart2P bundled font; Android does not ship that .ttf, so we
 * fall back to the chunky Bungee display family (closest visual match already
 * shipping with the app). Bold weight and a hard black drop shadow preserved.
 */
@Composable
fun PixelText(
    text: String,
    modifier: Modifier = Modifier,
    size: Int = 14,
    color: Color = Color.White,
) {
    Text(
        text = text,
        modifier = modifier,
        style = TextStyle(
            fontFamily = BungeeFamily,
            fontSize = size.sp,
            fontWeight = FontWeight.Bold,
            color = color,
            shadow = androidx.compose.ui.graphics.Shadow(
                color = Color.Black.copy(alpha = 0.8f),
                offset = androidx.compose.ui.geometry.Offset(2f, 2f),
                blurRadius = 2f,
            ),
        ),
    )
}
