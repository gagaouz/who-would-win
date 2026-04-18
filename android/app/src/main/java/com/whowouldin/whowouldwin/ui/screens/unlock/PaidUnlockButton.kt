package com.whowouldin.whowouldwin.ui.screens.unlock

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Paid IAP call-to-action button for unlock sheets.
 *
 * 3D top/mid/bot gradient (matches `MegaButton`) but taller-labeled:
 * shows a leading emoji, a two-line label ("Unlock X" + price), and a chevron.
 * Visual identical to iOS `MegaButtonStyle(color: ..., height: 58, cornerRadius: 18)`.
 */
@Composable
internal fun PaidUnlockButton(
    emoji: String,
    title: String,
    priceText: String,
    color: MegaButtonColor,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interaction = remember { MutableInteractionSource() }
    val isPressed by interaction.collectIsPressedAsState()

    val pressedTranslationY by animateFloatAsState(
        targetValue = if (isPressed) 3f else 0f,
        animationSpec = tween(80),
        label = "tY",
    )
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1f,
        animationSpec = tween(80),
        label = "scale",
    )
    val shadowOpacity by animateFloatAsState(
        targetValue = if (isPressed) 0.2f else 0.4f,
        animationSpec = tween(80),
        label = "shadowOp",
    )

    val cornerRadius = 18.dp
    val height = 58.dp

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .graphicsLayer {
                this.translationY = pressedTranslationY * density
                this.scaleX = scale
                this.scaleY = scale
            }
            .shadow(
                elevation = (if (isPressed) 6 else 14).dp,
                shape = RoundedCornerShape(cornerRadius),
                ambientColor = color.glowColor.copy(alpha = shadowOpacity),
                spotColor = color.glowColor.copy(alpha = shadowOpacity),
            ),
        contentAlignment = Alignment.Center,
    ) {
        // 3D shadow edge
        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer { translationY = 6f * density }
                .clip(RoundedCornerShape(cornerRadius))
                .background(color.shadowColor)
        )

        // Body
        Box(
            Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(cornerRadius))
                .background(Brush.verticalGradient(listOf(color.topColor, color.midColor, color.botColor)))
                .clickable(
                    interactionSource = interaction,
                    indication = null,
                    onClick = onClick,
                ),
            contentAlignment = Alignment.CenterStart,
        ) {
            // Top shine
            Column(Modifier.fillMaxSize()) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(height * 0.4f)
                        .padding(horizontal = 6.dp, vertical = 3.dp)
                        .clip(RoundedCornerShape(cornerRadius - 2.dp))
                        .background(
                            Brush.verticalGradient(
                                listOf(Color.White.copy(alpha = 0.35f), Color.Transparent)
                            )
                        )
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text = emoji, fontSize = 20.sp)
                Spacer(Modifier.width(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(text = title, style = bungee(14), color = color.textColor)
                    Text(text = priceText, style = bungee(12), color = color.textColor.copy(alpha = 0.85f))
                }
                Spacer(Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = color.textColor,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}
