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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Ports iOS `Views/Components/AnimalCard.swift`.
 *
 * 3D embossed card with category-tinted gradient, bottom "edge" offset,
 * dark inset, top shine, selection ring + X-badge, locked state with blur.
 */
@Composable
fun AnimalCard(
    animal: Animal,
    isSelected: Boolean,
    isDisabled: Boolean,
    modifier: Modifier = Modifier,
    isLocked: Boolean = false,
    onTap: () -> Unit,
) {
    val accent = BrandTheme.categoryAccent(animal.category)

    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.06f else 1f,
        animationSpec = spring(dampingRatio = 0.62f, stiffness = Spring.StiffnessMediumLow),
        label = "selScale",
    )

    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (pressed && !isDisabled) 0.96f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "pressScale",
    )

    Box(
        modifier = modifier
            .scale(scale * pressScale)
            .alpha(if (isDisabled) 0.32f else 1f)
            .clickable(
                interactionSource = interaction,
                indication = null,
                enabled = !isDisabled,
                onClick = onTap,
            ),
    ) {
        // Bottom 3D edge — accent-tinted, shifted down 4dp
        Box(
            modifier = Modifier
                .matchParentSize()
                .offset(y = 4.dp)
                .background(accent.copy(alpha = 0.7f), RoundedCornerShape(14.dp)),
        )

        // Main card face
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = if (isSelected) 10.dp else 4.dp,
                    shape = RoundedCornerShape(14.dp),
                    spotColor = if (isSelected) accent.copy(alpha = 0.5f) else Color.Black.copy(alpha = 0.2f),
                )
                .background(BrandTheme.categoryGradient(animal.category), RoundedCornerShape(14.dp))
                .border(
                    width = if (isSelected) 2.5.dp else 1.dp,
                    color = if (isSelected) Color.White else Color.White.copy(alpha = 0.2f),
                    shape = RoundedCornerShape(14.dp),
                )
                .padding(3.dp)
                .background(Color.Black.copy(alpha = 0.65f), RoundedCornerShape(10.dp)),
        ) {
            // Top shine
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(30.dp)
                    .padding(horizontal = 3.dp, vertical = 2.dp)
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(Color.White.copy(alpha = 0.2f), Color.White.copy(alpha = 0f)),
                        ),
                        RoundedCornerShape(12.dp),
                    ),
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 4.dp, vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                // Image / emoji — prefer bundled asset, then custom URL, then emoji
                val ctx = LocalContext.current
                val assetResId = animal.creatureAssetName?.let { name ->
                    remember(name) {
                        ctx.resources.getIdentifier(name, "drawable", ctx.packageName)
                    }
                } ?: 0

                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .shadow(4.dp, RoundedCornerShape(8.dp))
                        .blur(if (isLocked) 3.dp else 0.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    when {
                        assetResId != 0 -> {
                            androidx.compose.foundation.Image(
                                painter = painterResource(id = assetResId),
                                contentDescription = animal.name,
                                contentScale = ContentScale.Fit,
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(RoundedCornerShape(8.dp)),
                            )
                        }
                        animal.isCustom && !animal.imageUrl.isNullOrBlank() -> {
                            AsyncImage(
                                model = animal.imageUrl,
                                contentDescription = animal.name,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(RoundedCornerShape(8.dp)),
                            )
                        }
                        else -> {
                            Text(
                                text = animal.emoji,
                                style = bungee(40).copy(fontSize = 40.sp),
                            )
                        }
                    }
                }

                Text(
                    text = animal.name,
                    style = bungee(11),
                    color = Color.White,
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(28.dp)
                        .blur(if (isLocked) 2.5.dp else 0.dp),
                )
            }
        }

        // Locked overlay
        if (isLocked) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(14.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Lock,
                        contentDescription = "Locked",
                        tint = BrandTheme.fantasyAccent,
                        modifier = Modifier.size(18.dp),
                    )
                    Text(
                        text = "LOCKED",
                        style = bungee(7).copy(
                            color = BrandTheme.fantasyAccent.copy(alpha = 0.9f),
                            fontWeight = FontWeight.Black,
                            letterSpacing = 1.sp,
                        ),
                    )
                }
            }
        }

        // Selected X badge — top-end
        if (isSelected) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .offset(x = 5.dp, y = (-5).dp)
                    .size(20.dp)
                    .shadow(3.dp, CircleShape, spotColor = BrandTheme.red.copy(alpha = 0.5f))
                    .background(BrandTheme.red, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "Remove",
                    tint = Color.White,
                    modifier = Modifier.size(10.dp),
                )
            }
        }
    }
}
