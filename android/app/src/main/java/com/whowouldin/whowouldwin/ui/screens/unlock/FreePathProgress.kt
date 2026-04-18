package com.whowouldin.whowouldwin.ui.screens.unlock

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * "FREE PATH — Play N battles" progress card.
 *
 * Shared across the four unlock sheets; accent color + gradient tail + tip
 * emoji vary per pack.
 */
@Composable
internal fun FreePathProgress(
    title: String,
    currentBattles: Int,
    targetBattles: Int,
    progress: Double,
    accentColor: Color,
    progressGradient: Brush,
    tipEmoji: String,
    batteryRemainingLabel: String? = null,
) {
    val clampedProgress = progress.coerceIn(0.0, 1.0).toFloat()
    val animatedProgress by animateFloatAsState(
        targetValue = clampedProgress,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMedium),
        label = "progress",
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.10f))
            .border(1.5.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(18.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Title + counters row
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.Top,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(
                    text = "FREE PATH",
                    style = bungee(11).copy(letterSpacing = 1.5.sp),
                    color = Color.White.copy(alpha = 0.35f),
                )
                Text(
                    text = title,
                    style = bungee(17),
                    color = Color.White,
                )
            }
            Box(Modifier.weight(1f))
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Text(
                    text = "$currentBattles",
                    style = bungee(22),
                    color = accentColor,
                )
                Text(
                    text = "/ ${formatThousands(targetBattles)}",
                    style = bungee(13),
                    color = Color.White.copy(alpha = 0.35f),
                )
            }
        }

        // Progress bar
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .height(14.dp),
        ) {
            val maxW = maxWidth
            // Track
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color.White.copy(alpha = 0.1f))
            )
            // Fill
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .width(maxW * animatedProgress)
                    .shadow(4.dp, RoundedCornerShape(8.dp), spotColor = accentColor.copy(alpha = 0.5f))
                    .clip(RoundedCornerShape(8.dp))
                    .background(progressGradient)
            )
            // Sparkle at tip
            if (animatedProgress > 0.01f && animatedProgress < 1.0f) {
                Text(
                    text = tipEmoji,
                    fontSize = 10.sp,
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .offset(x = maxW * animatedProgress - 8.dp, y = (-1).dp),
                )
            }
        }

        if (batteryRemainingLabel != null) {
            Text(
                text = batteryRemainingLabel,
                style = bungee(13),
                color = Color.White.copy(alpha = 0.35f),
            )
        }
    }
}

private fun formatThousands(value: Int): String =
    java.text.NumberFormat.getIntegerInstance().format(value)
