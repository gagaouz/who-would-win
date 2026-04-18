package com.whowouldin.whowouldwin.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ripple
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.colorFromHex

/**
 * Ports iOS `Views/Components/CoinBadge.swift`.
 *
 * - [GoldCoin]  — drawn gold coin icon with "C" glyph
 * - [CoinBadge] — tappable capsule showing balance
 *
 * The coins-hub sheet (earn rates, buy IAP, watch-ad reward) lives in
 * `CoinsHubSheet.kt` — kept separate because it depends on Billing + AdManager.
 */

private val GoldLight = colorFromHex("#FFE566")
private val GoldMid   = colorFromHex("#FFD700")
private val GoldDark  = colorFromHex("#B8860B")

@Composable
fun GoldCoin(size: Dp = 20.dp) {
    Box(
        modifier = Modifier.size(size),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(size)) {
            val s = this.size.minDimension
            // Outer rim — top-leading → bottom-trailing gradient
            drawCircle(
                brush = Brush.linearGradient(
                    colors = listOf(GoldLight, GoldDark),
                    start = Offset(0f, 0f),
                    end = Offset(s, s),
                ),
                radius = s / 2f,
            )
            // Inner face
            drawCircle(
                brush = Brush.verticalGradient(
                    colors = listOf(GoldMid, GoldDark.copy(alpha = 0.8f)),
                ),
                radius = s * 0.38f,
            )
        }
        // Center "C" glyph — font scales with coin size
        Text(
            text = "C",
            style = bungee((size.value * 0.5f).toInt().coerceAtLeast(8)),
            color = GoldLight.copy(alpha = 0.9f),
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center,
        )
    }
}

enum class CoinBadgeSize { COMPACT, REGULAR, LARGE }

/**
 * Capsule coin-balance badge used in top bars across the app.
 *
 * Pass [balance] as the live value from `CoinStore.balance` (collected via
 * `collectAsStateWithLifecycle()` in the caller).  When tapped, invokes
 * [onClick] — callers route this to open the CoinsHubSheet.
 *
 * [adDotVisible] — show the green "ad ready" dot in the top-right corner.
 */
@Composable
fun CoinBadge(
    balance: Int,
    formattedBalance: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    size: CoinBadgeSize = CoinBadgeSize.REGULAR,
    adDotVisible: Boolean = false,
) {
    val emojiSize = when (size) {
        CoinBadgeSize.COMPACT -> 12.dp
        CoinBadgeSize.REGULAR -> 14.dp
        CoinBadgeSize.LARGE   -> 20.dp
    }
    val textSize = when (size) {
        CoinBadgeSize.COMPACT -> 12
        CoinBadgeSize.REGULAR -> 14
        CoinBadgeSize.LARGE   -> 18
    }
    val hPad = when (size) {
        CoinBadgeSize.COMPACT -> 8.dp
        CoinBadgeSize.REGULAR -> 10.dp
        CoinBadgeSize.LARGE   -> 14.dp
    }
    val vPad = when (size) {
        CoinBadgeSize.COMPACT -> 4.dp
        CoinBadgeSize.REGULAR -> 5.dp
        CoinBadgeSize.LARGE   -> 8.dp
    }
    val dotSize = when (size) {
        CoinBadgeSize.COMPACT -> 7.dp
        CoinBadgeSize.REGULAR -> 8.dp
        CoinBadgeSize.LARGE   -> 10.dp
    }
    val spacing = if (size == CoinBadgeSize.COMPACT) 3.dp else 5.dp

    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.94f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessMedium),
        label = "coinBadgeScale",
    )

    // Animate balance pop on change (mirrors iOS spring numericText)
    val balanceScale by animateFloatAsState(
        targetValue = 1f,
        animationSpec = spring(stiffness = Spring.StiffnessMediumLow),
        label = "balancePop",
    )

    Box(modifier = modifier.scale(scale)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(spacing),
            modifier = Modifier
                .clickable(
                    interactionSource = interaction,
                    indication = ripple(bounded = false, color = GoldMid),
                    onClick = onClick,
                )
                .background(GoldMid.copy(alpha = 0.15f), RoundedCornerShape(50))
                .border(1.dp, GoldMid.copy(alpha = 0.4f), RoundedCornerShape(50))
                .padding(horizontal = hPad, vertical = vPad),
        ) {
            GoldCoin(size = emojiSize)
            Text(
                text = formattedBalance,
                style = bungee(textSize).copy(color = GoldMid),
                modifier = Modifier.scale(balanceScale),
            )
        }

        // Green "ad ready" dot — top-trailing corner
        if (adDotVisible) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .size(dotSize)
                    .background(Color(0xFF2ECC40), CircleShape)
                    .border(1.dp, Color.Black.copy(alpha = 0.3f), CircleShape),
            )
        }
    }
}
