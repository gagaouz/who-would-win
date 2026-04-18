package com.whowouldin.whowouldwin.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.service.HapticsService
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Port of iOS `Views/Components/RandomPickCard.swift`.
 *
 * "🎲 RANDOM" tile that lives as the first cell in every picker grid.
 * Orange→yellow gradient face, 3D darker-orange bottom edge, white top shine,
 * dice rotates 360° on each tap with a bouncy spring.
 */
@Composable
fun RandomPickCard(
    onTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val ctx = LocalContext.current
    var diceRotation by remember { mutableStateOf(0f) }
    val animatedRotation by animateFloatAsState(
        targetValue = diceRotation,
        animationSpec = spring(
            dampingRatio = 0.5f,
            stiffness = Spring.StiffnessMediumLow,
        ),
        label = "diceRot",
    )

    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (pressed) 0.94f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "pressScale",
    )

    Box(
        modifier = modifier
            .scale(pressScale)
            .clickable(
                interactionSource = interaction,
                indication = null,
            ) {
                HapticsService.instance(ctx).medium()
                diceRotation += 360f
                onTap()
            },
    ) {
        // Bottom 3D edge — darker orange, shifted down 4dp
        Box(
            modifier = Modifier
                .matchParentSize()
                .offset(y = 4.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(BrandTheme.orange.copy(alpha = 0.8f)),
        )

        // Main card face
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = 6.dp,
                    shape = RoundedCornerShape(14.dp),
                    spotColor = BrandTheme.orange.copy(alpha = 0.45f),
                )
                .clip(RoundedCornerShape(14.dp))
                .background(
                    Brush.linearGradient(listOf(BrandTheme.orange, BrandTheme.yellow))
                )
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(14.dp)),
        ) {
            // Top shine overlay
            Column(Modifier.fillMaxSize()) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(30.dp)
                        .padding(horizontal = 3.dp)
                        .padding(top = 2.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(
                            Brush.verticalGradient(
                                listOf(Color.White.copy(alpha = 0.25f), Color.Transparent)
                            )
                        )
                )
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp, vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Text(
                    text = "🎲",
                    fontSize = 40.sp,
                    modifier = Modifier.graphicsLayer { rotationZ = animatedRotation },
                )
                Text(
                    text = "RANDOM",
                    style = bungee(11),
                    color = Color.White,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(28.dp),
                )
            }
        }
    }
}
