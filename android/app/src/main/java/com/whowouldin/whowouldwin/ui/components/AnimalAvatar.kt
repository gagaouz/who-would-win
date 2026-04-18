package com.whowouldin.whowouldwin.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.whowouldin.whowouldwin.model.Animal

/**
 * Port of iOS `Views/Components/AnimalAvatar.swift`.
 *
 * Pack creatures (fantasy/mythic/olympus/prehistoric) have bespoke generated
 * artwork at `res/drawable/creature_<id>.png` — looked up at runtime via the
 * resource name, since we don't have a hand-maintained enum of every id.
 * Falls back to the custom-creature remote image (Coil), then to the emoji.
 */
@Composable
fun AnimalAvatar(
    animal: Animal,
    size: Dp,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = 8.dp,
) {
    val ctx = LocalContext.current
    val assetResId = animal.creatureAssetName?.let { name ->
        remember(name) {
            ctx.resources.getIdentifier(name, "drawable", ctx.packageName)
        }
    } ?: 0

    Box(
        modifier = modifier.size(size),
        contentAlignment = Alignment.Center,
    ) {
        when {
            assetResId != 0 -> {
                Image(
                    painter = painterResource(id = assetResId),
                    contentDescription = animal.name,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .size(size)
                        .clip(RoundedCornerShape(cornerRadius)),
                )
            }
            animal.isCustom && !animal.imageUrl.isNullOrBlank() -> {
                AsyncImage(
                    model = animal.imageUrl,
                    contentDescription = animal.name,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier
                        .size(size)
                        .clip(RoundedCornerShape(cornerRadius)),
                )
            }
            else -> {
                Text(
                    text = animal.emoji,
                    fontSize = (size.value * 0.85f).sp,
                )
            }
        }
    }
}
