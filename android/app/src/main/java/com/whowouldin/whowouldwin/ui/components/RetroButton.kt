package com.whowouldin.whowouldwin.ui.components

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.service.HapticsService
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.colorFromHex
import com.whowouldin.whowouldwin.ui.theme.lilita

/** Color sets for the MegaButton — mirrors iOS MegaButtonColor. */
enum class MegaButtonColor {
    ORANGE, GREEN, PURPLE, GOLD, BLUE, RED;

    val topColor: Color get() = when (this) {
        ORANGE -> BrandTheme.btnOrangeTop
        GREEN -> BrandTheme.btnGreenTop
        PURPLE -> BrandTheme.btnPurpleTop
        GOLD -> BrandTheme.btnGoldTop
        BLUE -> BrandTheme.btnBlueTop
        RED -> BrandTheme.btnRedTop
    }
    val midColor: Color get() = when (this) {
        ORANGE -> BrandTheme.btnOrangeMid
        GREEN -> BrandTheme.btnGreenMid
        PURPLE -> BrandTheme.btnPurpleMid
        GOLD -> BrandTheme.btnGoldMid
        BLUE -> BrandTheme.btnBlueMid
        RED -> BrandTheme.btnRedMid
    }
    val botColor: Color get() = when (this) {
        ORANGE -> BrandTheme.btnOrangeBot
        GREEN -> BrandTheme.btnGreenBot
        PURPLE -> BrandTheme.btnPurpleBot
        GOLD -> BrandTheme.btnGoldBot
        BLUE -> BrandTheme.btnBlueBot
        RED -> BrandTheme.btnRedBot
    }
    val shadowColor: Color get() = when (this) {
        ORANGE -> BrandTheme.btnOrangeShadow
        GREEN -> BrandTheme.btnGreenShadow
        PURPLE -> BrandTheme.btnPurpleShadow
        GOLD -> BrandTheme.btnGoldShadow
        BLUE -> BrandTheme.btnBlueShadow
        RED -> BrandTheme.btnRedShadow
    }
    val textColor: Color get() = when (this) {
        GOLD -> colorFromHex("#1A237E")
        else -> Color.White
    }
    val glowColor: Color get() = midColor
}

/**
 * Supercell-style 3D "mega" button with:
 * - top→mid→bot vertical gradient body
 * - drop shadow that lifts the button off the background
 * - pressed state: translates down 3dp, shrinks to 0.97, shadow softens (0.4→0.2 opacity)
 * - top-half shine highlight for the plastic-sheen look
 * - Bungee font for text, haptic tap on press
 *
 * Mirrors iOS MegaButtonStyle. Spacing, corners, shine rectangle size, and animation
 * timing (0.08s ease-in-out) all ported verbatim.
 */
@Composable
fun MegaButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: MegaButtonColor = MegaButtonColor.ORANGE,
    height: Int = 68,
    cornerRadius: Int = 18,
    fontSize: Int = 24,
    enabled: Boolean = true,
    leadingIcon: (@Composable () -> Unit)? = null,
) {
    val interaction = remember { MutableInteractionSource() }
    val isPressed by interaction.collectIsPressedAsState()
    val context = LocalContext.current

    val pressedTranslationY by animateFloatAsState(
        targetValue = if (isPressed) 3f else 0f,
        animationSpec = tween(80),
        label = "translationY",
    )
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.97f else 1.0f,
        animationSpec = tween(80),
        label = "scale",
    )
    val shadowOpacity by animateFloatAsState(
        targetValue = if (isPressed) 0.2f else 0.4f,
        animationSpec = tween(80),
        label = "shadowOpacity",
    )
    val shadowOffsetY by animateFloatAsState(
        targetValue = if (isPressed) 2f else 6f,
        animationSpec = tween(80),
        label = "shadowOffsetY",
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height.dp)
            .graphicsLayer {
                this.translationY = pressedTranslationY * density
                this.scaleX = scale
                this.scaleY = scale
            }
            .shadow(
                elevation = (if (isPressed) 6 else 14).dp,
                shape = RoundedCornerShape(cornerRadius.dp),
                ambientColor = color.glowColor.copy(alpha = shadowOpacity),
                spotColor = color.glowColor.copy(alpha = shadowOpacity),
            ),
        contentAlignment = Alignment.Center,
    ) {
        // Bottom shadow edge (3D depth) — offset down so body sits on top
        Box(
            Modifier
                .fillMaxSize()
                .graphicsLayer { this.translationY = shadowOffsetY * density }
                .clip(RoundedCornerShape(cornerRadius.dp))
                .background(color.shadowColor)
        )

        // Main button body — top/mid/bot vertical gradient, clickable
        Box(
            Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(cornerRadius.dp))
                .background(
                    Brush.verticalGradient(listOf(color.topColor, color.midColor, color.botColor))
                )
                .clickable(
                    interactionSource = interaction,
                    indication = ripple(bounded = true, color = Color.White.copy(alpha = 0.2f)),
                    enabled = enabled,
                ) {
                    HapticsService.instance(context).tap()
                    onClick()
                },
            contentAlignment = Alignment.Center,
        ) {
            // Top shine highlight — upper 40% of button, white→transparent
            Column(Modifier.fillMaxSize()) {
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height((height * 0.4f).dp)
                        .padding(horizontal = 6.dp, vertical = 3.dp)
                        .clip(RoundedCornerShape((cornerRadius - 2).dp))
                        .background(
                            Brush.verticalGradient(
                                listOf(Color.White.copy(alpha = 0.35f), Color.Transparent)
                            )
                        )
                )
                Spacer(Modifier.weight(1f))
            }

            // Button label (optional leading icon + text)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                if (leadingIcon != null) {
                    leadingIcon()
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    text = text,
                    style = bungee(fontSize),
                    color = color.textColor,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/**
 * Smaller variant — used for secondary CTAs (SmallButton on iOS).
 * Same 3D look, ~56dp tall, lilita font for slightly lower visual weight.
 */
@Composable
fun SmallMegaButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: MegaButtonColor = MegaButtonColor.ORANGE,
    enabled: Boolean = true,
) {
    MegaButton(
        text = text,
        onClick = onClick,
        modifier = modifier,
        color = color,
        height = 56,
        cornerRadius = 16,
        fontSize = 18,
        enabled = enabled,
    )
}

/** Tiny scale-down press effect for plain clickable elements (icons, cards). */
@Composable
fun Modifier.pressable(): Modifier {
    val interaction = remember { MutableInteractionSource() }
    val isPressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.93f else 1f,
        animationSpec = tween(100),
        label = "pressable-scale",
    )
    return this.graphicsLayer { this.scaleX = scale; this.scaleY = scale }
}

/**
 * GamePanel — frosted-glass card with optional colored header bar.
 * Mirrors iOS GamePanel: 18dp corner radius, 3dp border, dark shadow,
 * header uses same MegaButtonColor family for coherent theming.
 */
@Composable
fun GamePanel(
    modifier: Modifier = Modifier,
    headerText: String? = null,
    headerColor: MegaButtonColor = MegaButtonColor.ORANGE,
    borderColor: Color = Color.White.copy(alpha = 0.25f),
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(10.dp, RoundedCornerShape(18.dp))
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.10f))
            .border(3.dp, borderColor, RoundedCornerShape(18.dp)),
    ) {
        if (headerText != null) {
            Box(
                Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(listOf(headerColor.topColor, headerColor.midColor))
                    )
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = headerText.uppercase(),
                    style = bungee(18).copy(letterSpacing = 2.sp),
                    color = headerColor.textColor,
                )
            }
        }
        Box(Modifier.padding(14.dp)) { content() }
    }
}

/**
 * BattlePanel — special glowing version used on the battle screen.
 * Orange/red header, deep navy body, cyan border glow. Port of iOS BattlePanel.
 */
@Composable
fun BattlePanel(
    headerText: String,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .shadow(14.dp, RoundedCornerShape(18.dp), spotColor = colorFromHex("#2196F3"))
            .clip(RoundedCornerShape(18.dp))
            .background(
                Brush.verticalGradient(
                    listOf(
                        colorFromHex("#0D47A1").copy(alpha = 0.7f),
                        colorFromHex("#1A237E").copy(alpha = 0.8f),
                    )
                )
            )
            .border(2.dp, colorFromHex("#64B5F6").copy(alpha = 0.4f), RoundedCornerShape(18.dp)),
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(
                        listOf(colorFromHex("#FF6D00"), colorFromHex("#D50000"))
                    )
                )
                .padding(vertical = 10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = headerText.uppercase(),
                style = bungee(18).copy(letterSpacing = 2.sp),
                color = Color.White,
            )
        }
        Box(Modifier.padding(14.dp)) { content() }
    }
}

/**
 * VSShield — the golden "VS" badge shown between fighters on home + battle screens.
 * Golden gradient circle, thick orange stroke, drop shadow + soft yellow glow.
 * Ports iOS VSShield 1:1.
 */
@Composable
fun VSShield(
    modifier: Modifier = Modifier,
    size: Int = 56,
    fontSize: Int = 18,
) {
    Box(
        modifier = modifier
            .size(size.dp)
            .shadow(8.dp, CircleShape, spotColor = colorFromHex("#FFEB3B").copy(alpha = 0.18f))
            .clip(CircleShape)
            .background(
                Brush.verticalGradient(
                    listOf(
                        colorFromHex("#FFF176"),
                        colorFromHex("#FFEB3B"),
                        colorFromHex("#FDD835"),
                    )
                )
            )
            .border(4.dp, colorFromHex("#FF8F00"), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "VS",
            style = bungee(fontSize),
            color = colorFromHex("#E65100"),
            fontWeight = FontWeight.Black,
        )
    }
}

/** Section header row — icon + uppercase title, used inside settings and panels. */
@Composable
fun SectionHeader(
    text: String,
    modifier: Modifier = Modifier,
    icon: String? = null,
) {
    Row(
        modifier = modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Text(text = icon, fontSize = 20.sp)
            Spacer(Modifier.width(8.dp))
        }
        Text(
            text = text.uppercase(),
            style = bungee(14).copy(letterSpacing = 1.5.sp),
            color = BrandTheme.textPrimary(),
        )
    }
}

/** Pill-shaped badge — colored background, lilita text. Used for env tags, category tags. */
@Composable
fun Badge(
    text: String,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.9f))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(
            text = text,
            style = lilita(12),
            color = Color.White,
        )
    }
}

/** Category pill — toggles between selected (filled gradient) and unselected (outlined). */
@Composable
fun PillButton(
    text: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    accent: Color = BrandTheme.orange,
    leadingEmoji: String? = null,
    locked: Boolean = false,
) {
    val context = LocalContext.current
    val scale by animateFloatAsState(
        targetValue = if (selected) 1.05f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "pill-scale",
    )
    Box(
        modifier = modifier
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(RoundedCornerShape(20.dp))
            .then(
                if (selected) Modifier.background(
                    Brush.horizontalGradient(listOf(accent, accent.copy(alpha = 0.7f)))
                )
                else Modifier.background(Color.White.copy(alpha = 0.10f))
            )
            .border(
                2.dp,
                if (selected) accent else Color.White.copy(alpha = 0.25f),
                RoundedCornerShape(20.dp),
            )
            .clickable {
                HapticsService.instance(context).tap(); onClick()
            }
            .padding(horizontal = 14.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (leadingEmoji != null) {
                Text(text = leadingEmoji, fontSize = 14.sp)
                Spacer(Modifier.width(4.dp))
            }
            Text(
                text = text.uppercase(),
                style = lilita(14).copy(letterSpacing = 0.5.sp),
                color = if (selected) Color.White else BrandTheme.textPrimary().copy(alpha = 0.8f),
            )
            if (locked) {
                Spacer(Modifier.width(4.dp))
                Text(text = "🔒", fontSize = 12.sp)
            }
        }
    }
}

/** Circle icon button — for back/close/settings icons. */
@Composable
fun CircleIconButton(
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    size: Int = 44,
    tint: Color = Color.White,
    background: Color = Color.Black.copy(alpha = 0.25f),
) {
    val context = LocalContext.current
    Box(
        modifier = modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(background)
            .border(1.dp, Color.White.copy(alpha = 0.2f), CircleShape)
            .clickable {
                HapticsService.instance(context).tap(); onClick()
            },
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.material3.Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = tint,
            modifier = Modifier.size((size * 0.5f).dp),
        )
    }
}

/** Screen background — radial glow overlays on top of the base gradient.
 *  `style` picks which glow cluster to render (home/settings/battle/unlock). */
enum class BackgroundStyle { HOME, BATTLE, UNLOCK, SETTINGS }

@Composable
fun ScreenBackground(
    style: BackgroundStyle = BackgroundStyle.HOME,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    Box(
        modifier
            .fillMaxSize()
            .background(
                when (style) {
                    BackgroundStyle.HOME, BackgroundStyle.SETTINGS -> BrandTheme.homeGradient()
                    BackgroundStyle.BATTLE -> BrandTheme.battleGradient()
                    BackgroundStyle.UNLOCK -> BrandTheme.unlockGradient()
                }
            )
    ) {
        // Radial glow overlays — paint with Canvas so they layer nicely
        Box(Modifier.fillMaxSize().drawBehind {
            when (style) {
                BackgroundStyle.HOME, BackgroundStyle.SETTINGS -> {
                    drawRadial(Color(0xFFFFEB3B), 0.08f, Offset(size.width * 0.5f, size.height * 0.05f), 600f)
                    drawRadial(Color(0xFF4CAF50), 0.05f, Offset(size.width * 0.2f, size.height * 0.85f), 400f)
                    drawRadial(Color(0xFFBA68C8), 0.08f, Offset(size.width * 0.7f, size.height * 0.3f), 500f)
                }
                BackgroundStyle.BATTLE -> {
                    drawRadial(Color(0xFFFFEB3B), 0.06f, Offset(size.width * 0.5f, size.height * 0.3f), 400f)
                    drawRadial(Color(0xFFF44336), 0.05f, Offset(size.width * 0.2f, size.height * 0.2f), 400f)
                    drawRadial(Color(0xFF00E5FF), 0.05f, Offset(size.width * 0.8f, size.height * 0.2f), 400f)
                }
                BackgroundStyle.UNLOCK -> {
                    drawRadial(Color(0xFFE1BEE7), 0.08f, Offset(size.width * 0.5f, size.height * 0.15f), 500f)
                    drawRadial(Color(0xFF64B5F6), 0.04f, Offset(size.width * 0.3f, size.height * 0.8f), 400f)
                }
            }
        })
        content()
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawRadial(
    color: Color, alpha: Float, center: Offset, radius: Float,
) {
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(color.copy(alpha = alpha), Color.Transparent),
            center = center,
            radius = radius,
        ),
        radius = radius,
        center = center,
    )
}
