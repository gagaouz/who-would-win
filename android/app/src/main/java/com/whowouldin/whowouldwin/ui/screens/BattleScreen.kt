package com.whowouldin.whowouldwin.ui.screens

import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.ui.screens.battle.BattleArena
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.lilita
import com.whowouldin.whowouldwin.service.SpeechService
import com.whowouldin.whowouldwin.vm.BattleViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Port of iOS `Views/BattleView.swift`.
 *
 * Phases (driven by [BattleViewModel.phase]):
 *   - INTRO     — fighters slide in from the sides, "VS" springs up, then quick health bars
 *   - ANIMATING — full BattleArena (Canvas) with particles + lunges + hits
 *   - REVEALING / COMPLETE — results card slides up from bottom with winner, narration, fun fact, actions
 *
 * Ad interstitials, achievement tracking, Wikipedia photos and share-card rendering will be
 * wired in once their respective services are ported. Hooks are left as TODO blocks below.
 */
@Composable
fun BattleScreen(
    fighter1: Animal,
    fighter2: Animal,
    environment: BattleEnvironment = BattleEnvironment.GRASSLAND,
    arenaEffectsEnabled: Boolean = false,
    quickMode: Boolean = false,
    tournamentContext: String? = null,
    onBack: () -> Unit,
    onTournamentComplete: ((com.whowouldin.whowouldwin.model.BattleResult) -> Unit)? = null,
    onNewFighters: () -> Unit = onBack,
) {
    val vm: BattleViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                BattleViewModel(
                    fighter1 = fighter1,
                    fighter2 = fighter2,
                    environment = environment,
                    arenaEffectsEnabled = arenaEffectsEnabled,
                    isQuickMode = quickMode,
                    tournamentContext = tournamentContext,
                )
            }
        },
    )
    val phase by vm.phase.collectAsState()
    val result by vm.battleResult.collectAsState()
    val narration by vm.narrationDisplayed.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var displayEnv by remember { mutableStateOf(environment) }

    // Kick off the battle once
    LaunchedEffect(Unit) {
        vm.startBattle()
    }

    // Stop narration on back
    LaunchedEffect(Unit) {
        SpeechService.init(context)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(listOf(displayEnv.bgTop, displayEnv.bgBottom)),
            ),
    ) {
        // ── Top bar ─────────────────────────────────────────────
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BackPill(onClick = {
                SpeechService.stop()
                onBack()
            })
            Spacer(Modifier.weight(1f))
            EnvironmentPill(displayEnv)
            Spacer(Modifier.weight(1f))
            CoinBadgeStub()
        }

        // ── Phase content ──────────────────────────────────────
        when (phase) {
            BattleViewModel.Phase.INTRO -> IntroPhase(
                fighter1 = fighter1,
                fighter2 = fighter2,
            )
            BattleViewModel.Phase.ANIMATING,
            BattleViewModel.Phase.FETCHING_RESULT -> {
                BattleArena(
                    fighter1 = fighter1,
                    fighter2 = fighter2,
                    environment = displayEnv,
                    result = null,
                    onAnimationComplete = { vm.animationDidComplete() },
                    onHit = { isCritical ->
                        // Hook for HapticsService.heavy() / .tap() — no-op for now.
                    },
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 72.dp),
                )
            }
            BattleViewModel.Phase.REVEALING,
            BattleViewModel.Phase.COMPLETE -> {
                Box(Modifier.fillMaxSize()) {
                    BattleArena(
                        fighter1 = fighter1,
                        fighter2 = fighter2,
                        environment = displayEnv,
                        result = result,
                        onAnimationComplete = {},
                        modifier = Modifier.fillMaxSize().padding(top = 72.dp),
                    )
                    ResultsPanel(
                        fighter1 = fighter1,
                        fighter2 = fighter2,
                        result = result,
                        narrationDisplayed = narration,
                        environment = displayEnv,
                        arenaEffectsEnabled = arenaEffectsEnabled,
                        canShowButtons = phase == BattleViewModel.Phase.COMPLETE,
                        tournamentMode = onTournamentComplete != null,
                        onReadAloud = {
                            val r = result ?: return@ResultsPanel
                            val full = r.narration +
                                if (r.funFact.isNotEmpty()) ". Fun fact: ${r.funFact}" else ""
                            SpeechService.speak(context, full)
                        },
                        onBattleAgain = {
                            scope.launch {
                                vm.rematch()
                                delay(50)
                                vm.startBattle()
                            }
                        },
                        onNewFighters = {
                            SpeechService.stop()
                            onNewFighters()
                        },
                        onShare = {
                            val r = result ?: return@ResultsPanel
                            val winnerName = when (r.winner) {
                                fighter1.id -> fighter1.name
                                fighter2.id -> fighter2.name
                                else -> null
                            }
                            val caption = if (winnerName != null) {
                                val loser = if (r.winner == fighter1.id) fighter2.name else fighter1.name
                                "$winnerName beats $loser! 🏆🔥 #WhoWouldWin"
                            } else {
                                "${fighter1.name} vs ${fighter2.name} — it's a DRAW! 🤯 #WhoWouldWin"
                            }
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_TEXT, caption)
                            }
                            context.startActivity(Intent.createChooser(intent, "Share battle"))
                        },
                        onTournamentContinue = {
                            val r = result ?: return@ResultsPanel
                            SpeechService.stop()
                            onTournamentComplete?.invoke(r)
                        },
                    )
                }
            }
        }

        // ── Coin-earned popup ──────────────────────────────────
        // NOTE: CoinStore isn't ported yet — when it is, subscribe to its
        // `showEarnAnimation` flag and render a +coins chip here.
        // See iOS `BattleView.swift` lines 180–205 for the target design.
    }
}

// ─────────────────────────────────────────────────────────────
// Intro phase — fighters slide in + VS springs
// ─────────────────────────────────────────────────────────────
@Composable
private fun IntroPhase(fighter1: Animal, fighter2: Animal) {
    var reveal by remember { mutableStateOf(false) }
    var showVs by remember { mutableStateOf(false) }
    var showHealth by remember { mutableStateOf(false) }

    val offset1 by animateFloatAsState(
        targetValue = if (reveal) 0f else -500f,
        animationSpec = spring(dampingRatio = 0.72f, stiffness = Spring.StiffnessMediumLow),
        label = "f1-offset",
    )
    val offset2 by animateFloatAsState(
        targetValue = if (reveal) 0f else 500f,
        animationSpec = spring(dampingRatio = 0.72f, stiffness = Spring.StiffnessMediumLow),
        label = "f2-offset",
    )
    val vsScale by animateFloatAsState(
        targetValue = if (showVs) 1f else 0.1f,
        animationSpec = spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMedium),
        label = "vs-scale",
    )
    val vsAlpha by animateFloatAsState(
        targetValue = if (showVs) 1f else 0f,
        animationSpec = tween(300),
        label = "vs-alpha",
    )

    LaunchedEffect(Unit) {
        reveal = true
        delay(180)
        // Second fighter reveals slightly after
        delay(320)
        showVs = true
        delay(150)
        showHealth = true
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(top = 90.dp, bottom = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            FighterIntroCard(
                animal = fighter1,
                accent = BrandTheme.orange,
                modifier = Modifier.graphicsLayer { translationX = offset1 }.weight(1f),
            )
            Text(
                text = "VS",
                style = bungee(32),
                color = BrandTheme.orange,
                modifier = Modifier
                    .graphicsLayer {
                        scaleX = vsScale
                        scaleY = vsScale
                        alpha = vsAlpha
                    }
                    .padding(horizontal = 8.dp),
            )
            FighterIntroCard(
                animal = fighter2,
                accent = BrandTheme.cyan,
                modifier = Modifier.graphicsLayer { translationX = offset2 }.weight(1f),
            )
        }

        if (showHealth) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 36.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                SimpleHealthBar(color = BrandTheme.orange, modifier = Modifier.weight(1f))
                SimpleHealthBar(color = BrandTheme.cyan, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun FighterIntroCard(animal: Animal, accent: Color, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .padding(6.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(Color.White.copy(alpha = 0.07f))
            .padding(vertical = 22.dp, horizontal = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(text = animal.emoji, fontSize = 80.sp)
        Text(
            text = animal.name.uppercase(),
            style = lilita(14).copy(color = accent),
            textAlign = TextAlign.Center,
            maxLines = 2,
        )
    }
}

@Composable
private fun SimpleHealthBar(color: Color, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .height(10.dp)
            .clip(RoundedCornerShape(6.dp))
            .background(Color.White.copy(alpha = 0.1f)),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Brush.horizontalGradient(listOf(color, color.copy(alpha = 0.7f)))),
        )
    }
}

// ─────────────────────────────────────────────────────────────
// Results panel (REVEALING + COMPLETE)
// ─────────────────────────────────────────────────────────────
@Composable
private fun BoxScope.ResultsPanel(
    fighter1: Animal,
    fighter2: Animal,
    result: com.whowouldin.whowouldwin.model.BattleResult?,
    narrationDisplayed: String,
    environment: BattleEnvironment,
    arenaEffectsEnabled: Boolean,
    canShowButtons: Boolean,
    tournamentMode: Boolean,
    onReadAloud: () -> Unit,
    onBattleAgain: () -> Unit,
    onNewFighters: () -> Unit,
    onShare: () -> Unit,
    onTournamentContinue: () -> Unit,
) {
    result ?: return
    val isDraw = result.winner == "draw"
    val winner = when (result.winner) {
        fighter1.id -> fighter1
        fighter2.id -> fighter2
        else -> null
    }
    val winnerAccent = if (result.winner == fighter1.id) BrandTheme.orange else BrandTheme.cyan

    // Animate slide-up from below
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }
    val panelOffset by animateFloatAsState(
        targetValue = if (visible) 0f else 1000f,
        animationSpec = spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow),
        label = "results-offset",
    )

    // Animate health bars over 3s from 100% to target
    val winnerPct = remember(result) { Animatable(1f) }
    val loserPct = remember(result) { Animatable(1f) }
    LaunchedEffect(result) {
        winnerPct.animateTo(
            targetValue = if (isDraw) 0.55f else result.winnerHealthPercent / 100f,
            animationSpec = tween(durationMillis = 3000, easing = FastOutSlowInEasing),
        )
    }
    LaunchedEffect(result) {
        loserPct.animateTo(
            targetValue = if (isDraw) 0.45f else result.loserHealthPercent / 100f,
            animationSpec = tween(durationMillis = 3000, easing = FastOutSlowInEasing),
        )
    }

    Column(
        modifier = Modifier
            .align(Alignment.BottomCenter)
            .fillMaxWidth()
            .fillMaxHeight(0.7f)
            .graphicsLayer { translationY = panelOffset }
            .clip(RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp))
            .background(Color(0xFF0E0B22).copy(alpha = 0.95f))
            .padding(horizontal = 24.dp, vertical = 18.dp),
    ) {
        // Drag pill
        Box(
            modifier = Modifier
                .align(Alignment.CenterHorizontally)
                .size(width = 40.dp, height = 5.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(Color.White.copy(alpha = 0.15f)),
        )
        Spacer(Modifier.height(16.dp))

        // Health bars
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            HealthBar(
                name = fighter1.name,
                pct = if (result.winner == fighter1.id || isDraw) winnerPct.value else loserPct.value,
                color = BrandTheme.orange,
                modifier = Modifier.weight(1f),
            )
            HealthBar(
                name = fighter2.name,
                pct = if (result.winner == fighter2.id || isDraw) winnerPct.value else loserPct.value,
                color = BrandTheme.cyan,
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(Modifier.height(18.dp))

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .weight(1f),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // Winner heading
            if (isDraw) {
                Text("⚔️", fontSize = 54.sp)
                Text("IT'S A DRAW!", style = bungee(26).copy(color = BrandTheme.gold))
                Text(
                    "Neither fighter could claim victory — their strengths were too evenly matched.",
                    style = bungee(12).copy(color = Color.White.copy(alpha = 0.65f)),
                    textAlign = TextAlign.Center,
                )
            } else if (winner != null) {
                Text("🏆", fontSize = 54.sp)
                Text("WINNER!", style = bungee(12).copy(color = Color.White.copy(alpha = 0.6f)))
                Text(
                    text = winner.name.uppercase(),
                    style = bungee(26).copy(color = winnerAccent),
                    textAlign = TextAlign.Center,
                )
            }

            if (arenaEffectsEnabled) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(environment.accentColor.copy(alpha = 0.12f))
                        .padding(horizontal = 12.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(environment.emoji, fontSize = 12.sp)
                    Spacer(Modifier.width(4.dp))
                    Text(
                        "${environment.displayName.uppercase()} ARENA",
                        fontSize = 9.sp,
                        color = environment.accentColor,
                        fontWeight = FontWeight.Black,
                    )
                }
            }

            if (result.isOfflineFallback) {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(20.dp))
                        .background(Color(0xFFFFB347).copy(alpha = 0.15f))
                        .padding(horizontal = 14.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("⚡", fontSize = 12.sp)
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "Offline result",
                        color = Color(0xFFFFB347),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }

            // Narration (typewriter from VM)
            if (narrationDisplayed.isNotEmpty()) {
                Text(
                    text = narrationDisplayed,
                    color = Color.White,
                    textAlign = TextAlign.Center,
                    fontSize = 15.sp,
                )
            }

            // Read aloud
            if (canShowButtons && result.narration.isNotEmpty()) {
                val isSpeaking by SpeechService.isSpeaking.collectAsState()
                TextButton(onClick = onReadAloud) {
                    Text(
                        text = if (isSpeaking) "🔊 Stop" else "🔈 Read Aloud",
                        color = if (isSpeaking) BrandTheme.orange else Color.White.copy(alpha = 0.7f),
                    )
                }
            }

            // Fun fact
            if (result.funFact.isNotEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(BrandTheme.teal.copy(alpha = 0.07f))
                        .padding(14.dp),
                ) {
                    Text(
                        "✨ FUN FACT",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Black,
                        color = BrandTheme.teal,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        result.funFact,
                        color = Color.White,
                        fontSize = 14.sp,
                    )
                }
            }

            // Action buttons
            if (canShowButtons) {
                if (tournamentMode) {
                    BattleActionButton(
                        text = "🏆 CONTINUE TOURNAMENT",
                        color = BrandTheme.gold,
                        onClick = onTournamentContinue,
                    )
                } else {
                    BattleActionButton(
                        text = "🔄 BATTLE AGAIN",
                        color = BrandTheme.orange,
                        onClick = onBattleAgain,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        BattleActionButton(
                            text = "🐾 NEW FIGHTERS",
                            color = BrandTheme.cyan,
                            onClick = onNewFighters,
                            modifier = Modifier.weight(1f),
                        )
                        BattleActionButton(
                            text = "📤 SHARE",
                            color = BrandTheme.teal,
                            onClick = onShare,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun HealthBar(
    name: String,
    pct: Float,
    color: Color,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(
            text = name.uppercase(),
            color = color,
            fontSize = 10.sp,
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(4.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(14.dp)
                .clip(RoundedCornerShape(7.dp))
                .background(Color.White.copy(alpha = 0.1f)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(pct.coerceIn(0f, 1f))
                    .fillMaxHeight()
                    .background(
                        Brush.horizontalGradient(listOf(color, color.copy(alpha = 0.7f))),
                    ),
            )
        }
        Text(
            text = "${(pct * 100).toInt()}%",
            color = Color.White.copy(alpha = 0.65f),
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth().padding(top = 2.dp),
        )
    }
}

@Composable
private fun BattleActionButton(
    text: String,
    color: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp),
        shape = RoundedCornerShape(16.dp),
        colors = ButtonDefaults.buttonColors(containerColor = color),
    ) {
        Text(
            text = text,
            style = bungee(15).copy(color = Color.White),
        )
    }
}

// ─────────────────────────────────────────────────────────────
// Top-bar bits
// ─────────────────────────────────────────────────────────────
@Composable
private fun BackPill(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.08f))
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        Text("← Back", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun EnvironmentPill(env: BattleEnvironment) {
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(env.accentColor.copy(alpha = 0.15f))
            .padding(horizontal = 14.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(env.emoji, fontSize = 13.sp)
        Spacer(Modifier.width(6.dp))
        Text(
            env.displayName.uppercase(),
            color = env.accentColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.Black,
        )
    }
}

@Composable
private fun CoinBadgeStub() {
    // Real CoinStore-backed pill will replace this once CoinStore is ported.
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(Color(0xFFFFD700).copy(alpha = 0.18f))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("🪙", fontSize = 14.sp)
        Spacer(Modifier.width(4.dp))
        Text(
            "0",
            color = Color(0xFFFFD700),
            fontWeight = FontWeight.Black,
            fontSize = 13.sp,
        )
    }
}
