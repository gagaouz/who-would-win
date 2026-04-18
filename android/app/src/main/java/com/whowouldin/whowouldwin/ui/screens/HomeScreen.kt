package com.whowouldin.whowouldwin.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.ripple
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.service.HapticsService
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.CoinBadge
import com.whowouldin.whowouldwin.ui.components.CoinBadgeSize
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.components.VSShield
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.colorFromHex
import kotlinx.coroutines.delay

/**
 * Ports iOS `Views/HomeView.swift` — keeps all polish:
 *  - pulsing BATTLE button (1.025× breathe)
 *  - yellow title with orange outline + glow pulse
 *  - hero animals bounce (-10dp) + rotating pair every 4s
 *  - VS shield 1.0↔1.2 pulse
 *  - streak badge when ≥2 days
 *  - tournament button unlocks at 30 battles
 *
 * Disclaimer / Help / TournamentResume sheets hoisted to caller via callback
 * slots — this Composable only owns the home surface itself.
 */

private val HeroPairs = listOf(
    "🦁" to "🐯",
    "🦈" to "🐊",
    "🦅" to "🐺",
    "🐘" to "🦏",
    "🦍" to "🐻",
    "🦁" to "🦈",
)

@Composable
fun HomeScreen(
    onBattleClick: () -> Unit,
    onTournamentClick: () -> Unit,
    onSettingsClick: () -> Unit,
    onCoinBadgeClick: () -> Unit,
    onHelpClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val ctx = LocalContext.current
    val settings = remember { UserSettings.instance(ctx) }
    val coinStore = remember { CoinStore.instance(ctx) }
    val haptics = remember { HapticsService.instance(ctx) }

    val currentStreak by settings.currentStreak.collectAsStateWithLifecycle()
    val balance by coinStore.balance.collectAsStateWithLifecycle()

    val isTournamentUnlocked = settings.isTournamentUnlocked

    val transition = rememberInfiniteTransition(label = "home")
    val playPulse by transition.animateFloat(
        1f, 1.025f,
        infiniteRepeatable(tween(1500, easing = LinearEasing), RepeatMode.Reverse),
        label = "playPulse",
    )
    val titleGlow by transition.animateFloat(
        0.3f, 0.8f,
        infiniteRepeatable(tween(1800, easing = LinearEasing), RepeatMode.Reverse),
        label = "titleGlow",
    )
    val animalBounce by transition.animateFloat(
        0f, -10f,
        infiniteRepeatable(tween(2000, easing = LinearEasing), RepeatMode.Reverse),
        label = "bounce",
    )
    val vsScale by transition.animateFloat(
        1f, 1.2f,
        infiniteRepeatable(tween(1300, easing = LinearEasing), RepeatMode.Reverse),
        label = "vs",
    )

    var pairIndex by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(4000)
            pairIndex = (pairIndex + 1) % HeroPairs.size
        }
    }

    ScreenBackground(style = BackgroundStyle.HOME, modifier = modifier.fillMaxSize()) {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val h = maxHeight

            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp, start = 20.dp, end = 20.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FrostedCircleButton(onClick = { haptics.tap(); onSettingsClick() }) {
                    Icon(Icons.Filled.Settings, contentDescription = "Settings", tint = Color.White)
                }
                Spacer(Modifier.weight(1f))
                CoinBadge(
                    balance = balance,
                    formattedBalance = coinStore.formattedBalance,
                    size = CoinBadgeSize.REGULAR,
                    onClick = onCoinBadgeClick,
                )
                Spacer(Modifier.weight(1f))
                FrostedCircleButton(onClick = onHelpClick) {
                    Text("?", style = bungee(20).copy(color = Color.White, fontWeight = FontWeight.Black))
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .widthIn(max = 720.dp)
                    .align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Spacer(Modifier.height(h * 0.22f))

                // Hero animals + VS
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 40.dp)
                        .graphicsLayer { translationY = animalBounce }
                        .padding(bottom = 28.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    AnimatedContent(
                        targetState = pairIndex,
                        transitionSpec = { (scaleIn() + fadeIn()) togetherWith (scaleOut() + fadeOut()) },
                        label = "heroL",
                    ) { idx ->
                        Text(
                            HeroPairs[idx].first,
                            style = bungee(80).copy(
                                fontSize = 80.sp,
                                shadow = Shadow(color = BrandTheme.orange.copy(alpha = 0.6f), blurRadius = 24f),
                            ),
                        )
                    }

                    VSShield(size = 56, fontSize = 18, modifier = Modifier.scale(vsScale))

                    AnimatedContent(
                        targetState = pairIndex,
                        transitionSpec = { (scaleIn() + fadeIn()) togetherWith (scaleOut() + fadeOut()) },
                        label = "heroR",
                    ) { idx ->
                        Text(
                            HeroPairs[idx].second,
                            style = bungee(80).copy(
                                fontSize = 80.sp,
                                shadow = Shadow(color = BrandTheme.cyan.copy(alpha = 0.6f), blurRadius = 24f),
                            ),
                        )
                    }
                }

                // Title
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "ANIMAL",
                        style = bungee(38).copy(
                            color = BrandTheme.yellow,
                            shadow = Shadow(
                                color = BrandTheme.yellow.copy(alpha = titleGlow),
                                blurRadius = 18f * titleGlow,
                            ),
                        ),
                    )
                    Text(
                        "VS ANIMAL",
                        style = bungee(30).copy(
                            color = Color.White,
                            shadow = Shadow(color = colorFromHex("#1565C0"), blurRadius = 6f),
                        ),
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "Who Would Win?",
                        style = bungee(16).copy(
                            color = Color.White.copy(alpha = 0.65f),
                            letterSpacing = 1.sp,
                        ),
                    )
                }

                Spacer(Modifier.height(h * 0.03f))

                // Streak badge
                AnimatedVisibility(
                    visible = currentStreak >= 2,
                    enter = scaleIn() + fadeIn(),
                    exit = scaleOut() + fadeOut(),
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .shadow(4.dp, CircleShape)
                            .background(Color.White.copy(alpha = 0.12f), CircleShape)
                            .border(2.dp, BrandTheme.orange.copy(alpha = 0.5f), CircleShape)
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                    ) {
                        Text("🔥", fontSize = 15.sp)
                        Text(
                            "$currentStreak day streak!",
                            style = bungee(13).copy(color = BrandTheme.orange, fontWeight = FontWeight.Black),
                        )
                    }
                }

                Spacer(Modifier.height(h * 0.025f))

                // BATTLE button
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 28.dp)
                        .scale(playPulse),
                ) {
                    MegaButton(
                        text = "⚔️  LET'S BATTLE!  ⚔️",
                        color = MegaButtonColor.ORANGE,
                        onClick = onBattleClick,
                        height = 78,
                        fontSize = 22,
                    )
                }

                // Tournament button (unlocked at 30 battles)
                if (isTournamentUnlocked) {
                    Spacer(Modifier.height(h * 0.012f))
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 28.dp),
                    ) {
                        MegaButton(
                            text = "🏆  TOURNAMENT  🏆",
                            color = MegaButtonColor.GOLD,
                            onClick = { haptics.tap(); onTournamentClick() },
                            height = 58,
                            fontSize = 16,
                        )
                    }
                }
                // TODO: Port TournamentUnlockNudge / CustomCreatureCTA / PackJourneyNudge

                Spacer(Modifier.weight(1f))

                Text(
                    "Just for fun — no real animals are harmed 🐾",
                    style = bungee(11).copy(color = Color.White.copy(alpha = 0.3f)),
                    modifier = Modifier.padding(horizontal = 32.dp, vertical = 24.dp),
                )
            }
        }
    }
}

@Composable
private fun FrostedCircleButton(onClick: () -> Unit, content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .shadow(4.dp, CircleShape)
            .background(Color.White.copy(alpha = 0.12f), CircleShape)
            .border(2.dp, Color.White.copy(alpha = 0.25f), CircleShape)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = ripple(bounded = false, color = Color.White),
                onClick = onClick,
            ),
        contentAlignment = Alignment.Center,
    ) { content() }
}
