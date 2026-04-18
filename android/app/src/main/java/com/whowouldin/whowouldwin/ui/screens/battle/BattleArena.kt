package com.whowouldin.whowouldwin.ui.screens.battle

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.BattleEnvironment
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random
import kotlinx.coroutines.delay
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.material3.Text
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.platform.LocalContext

/**
 * Canvas replacement for the iOS SpriteKit `BattleScene`. Renders:
 *  - Gradient background (environment colors)
 *  - Per-environment particle system (snow, rain, embers, clouds, leaves, fireflies, sand, …)
 *  - Dual fighters at left/right edges
 *  - Clash choreography: alternating lunges, impact flash, screen shake, damage floats
 *  - Winner reveal: glow, scale-up, crown; loser fades/shrinks
 *
 * The animation fires [onAnimationComplete] after 6 alternating hits, matching iOS timing.
 *
 * @param result null while the battle is still animating; set to the final [com.whowouldin.whowouldwin.model.BattleResult]
 *               to trigger the winner/loser reveal pose.
 */
@Composable
fun BattleArena(
    fighter1: Animal,
    fighter2: Animal,
    environment: BattleEnvironment,
    result: com.whowouldin.whowouldwin.model.BattleResult?,
    onAnimationComplete: () -> Unit,
    onHit: (isCritical: Boolean) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val density = LocalDensity.current
        val arenaWidth = maxWidth
        val arenaHeight = maxHeight
        val widthPx = with(density) { arenaWidth.toPx() }
        val heightPx = with(density) { arenaHeight.toPx() }

        // ── Per-fighter animatables ────────────────────────────────
        val lunge1 = remember { Animatable(0f) }  // -1..+1 lunge offset as fraction of arena width
        val lunge2 = remember { Animatable(0f) }
        val shake = remember { Animatable(0f) }
        val flashAlpha = remember { Animatable(0f) }
        var damageFloats by remember { mutableStateOf(listOf<DamageFloat>()) }

        // Winner reveal scales
        val winnerScale = remember { Animatable(1f) }
        val loserScale = remember { Animatable(1f) }
        val loserAlpha = remember { Animatable(1f) }

        val fighter1Wins = result?.winner == fighter1.id
        val fighter2Wins = result?.winner == fighter2.id
        val isDraw = result?.winner == "draw"

        // ── Drive the alternating-hit choreography ────────────────
        LaunchedEffect(Unit) {
            delay(500)
            val rounds = 6
            for (round in 1..rounds) {
                val attackerIsFighter1 = (round % 2 == 1)
                val lunger = if (attackerIsFighter1) lunge1 else lunge2
                val dir = if (attackerIsFighter1) 1f else -1f

                // Lunge in
                lunger.animateTo(dir * 0.18f, tween(durationMillis = 200, easing = FastOutSlowInEasing))

                // Impact — flash + shake + damage float + haptic
                val isCrit = Random.nextInt(7) == 0
                onHit(isCrit)
                flashAlpha.snapTo(1f)
                flashAlpha.animateTo(0f, tween(durationMillis = 220, easing = LinearEasing))

                val dmg = if (isCrit) Random.nextInt(18, 29) else Random.nextInt(8, 21)
                val targetX = if (attackerIsFighter1) widthPx * 0.78f else widthPx * 0.22f
                val fx = DamageFloat(
                    id = damageFloatIdGen++,
                    damage = dmg,
                    isCritical = isCrit,
                    xPx = targetX + Random.nextInt(-30, 31),
                    yPx = heightPx * 0.45f,
                    bornAtMs = System.currentTimeMillis(),
                )
                damageFloats = damageFloats + fx
                // Shake
                shake.snapTo(0f)
                shake.animateTo(
                    1f,
                    tween(durationMillis = 180, easing = LinearEasing),
                )
                shake.snapTo(0f)

                // Pull back
                lunger.animateTo(0f, tween(durationMillis = 220, easing = FastOutSlowInEasing))

                // Cull old damage floats (> 1.2s)
                val now = System.currentTimeMillis()
                damageFloats = damageFloats.filter { now - it.bornAtMs < 1200 }

                delay(180)
            }
            onAnimationComplete()
        }

        // ── Winner/loser reveal ─────────────────────────────────────
        LaunchedEffect(result) {
            if (result == null) return@LaunchedEffect
            delay(300)
            when {
                isDraw -> {
                    winnerScale.animateTo(1.08f, tween(400))
                }
                fighter1Wins -> {
                    winnerScale.animateTo(1.18f, tween(450, easing = FastOutSlowInEasing))
                    loserScale.animateTo(0.82f, tween(450, easing = FastOutSlowInEasing))
                    loserAlpha.animateTo(0.55f, tween(450))
                }
                fighter2Wins -> {
                    winnerScale.animateTo(1.18f, tween(450, easing = FastOutSlowInEasing))
                    loserScale.animateTo(0.82f, tween(450, easing = FastOutSlowInEasing))
                    loserAlpha.animateTo(0.55f, tween(450))
                }
            }
        }

        // ── Background gradient + particles (continuous) ───────────
        val infinite = rememberInfiniteTransition(label = "arena-particles")
        val particleT by infinite.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 6000, easing = LinearEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "particle-t",
        )
        val pulseT by infinite.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(durationMillis = 1800, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse,
            ),
            label = "pulse-t",
        )

        // Pre-seed static particle field (so particles are stable per mount)
        val particles = remember(environment, widthPx, heightPx) {
            createParticleField(environment, widthPx, heightPx)
        }

        val shakeOffset = sin(shake.value * PI.toFloat() * 4f) * 10f

        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer { translationX = shakeOffset },
        ) {
            // Canvas background + particles + fighter-glow blooms
            Canvas(modifier = Modifier.fillMaxSize()) {
                // Gradient backdrop
                drawRect(
                    brush = Brush.verticalGradient(
                        listOf(environment.bgTop, environment.bgBottom),
                    ),
                    size = size,
                )

                // Ground line
                val groundY = size.height * 0.75f
                drawLine(
                    color = environment.accentColor.copy(alpha = 0.3f),
                    start = Offset(0f, groundY),
                    end = Offset(size.width, groundY),
                    strokeWidth = 8f,
                )
                drawLine(
                    color = environment.accentColor.copy(alpha = 0.9f),
                    start = Offset(0f, groundY),
                    end = Offset(size.width, groundY),
                    strokeWidth = 2f,
                )

                // Fighter glow blooms
                drawRadialGlow(
                    center = Offset(size.width * 0.22f, size.height * 0.55f),
                    radius = size.width * 0.32f,
                    color = Color(1f, 0.34f, 0.13f, 0.22f * (0.7f + 0.3f * pulseT)),
                )
                drawRadialGlow(
                    center = Offset(size.width * 0.78f, size.height * 0.55f),
                    radius = size.width * 0.32f,
                    color = Color(0f, 0.81f, 0.81f, 0.18f * (0.7f + 0.3f * (1f - pulseT))),
                )

                // Environment particles
                drawParticles(environment, particles, particleT, size)

                // Impact flash
                if (flashAlpha.value > 0f) {
                    drawRect(
                        color = Color.White.copy(alpha = flashAlpha.value * 0.45f),
                        size = size,
                    )
                }
            }

            // Fighter 1 (left)
            FighterSprite(
                animal = fighter1,
                modifier = Modifier
                    .size(120.dp)
                    .offset(
                        x = (arenaWidth * (0.12f + lunge1.value)),
                        y = arenaHeight * 0.35f,
                    )
                    .graphicsLayer {
                        val s = if (fighter1Wins || isDraw) winnerScale.value else if (fighter2Wins) loserScale.value else 1f
                        scaleX = s
                        scaleY = s
                        alpha = if (fighter2Wins) loserAlpha.value else 1f
                    },
            )

            // Fighter 2 (right) — mirrored
            FighterSprite(
                animal = fighter2,
                modifier = Modifier
                    .size(120.dp)
                    .offset(
                        x = (arenaWidth * (0.72f + lunge2.value)),
                        y = arenaHeight * 0.35f,
                    )
                    .graphicsLayer {
                        scaleX = -1f * (if (fighter2Wins || isDraw) winnerScale.value else if (fighter1Wins) loserScale.value else 1f)
                        scaleY = if (fighter2Wins || isDraw) winnerScale.value else if (fighter1Wins) loserScale.value else 1f
                        alpha = if (fighter1Wins) loserAlpha.value else 1f
                    },
            )

            // Winner crown
            if (fighter1Wins || fighter2Wins) {
                val crownX = if (fighter1Wins) 0.22f else 0.82f
                Text(
                    text = "👑",
                    fontSize = 48.sp,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .offset(x = arenaWidth * crownX - 24.dp, y = arenaHeight * 0.22f),
                )
                Text(
                    text = "WINNER!",
                    style = com.whowouldin.whowouldwin.ui.theme.bungee(20),
                    color = com.whowouldin.whowouldwin.ui.theme.BrandTheme.gold,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .offset(x = arenaWidth * crownX - 48.dp, y = arenaHeight * 0.28f),
                )
            }

            // Damage-float labels (Compose Text over Canvas so emojis render correctly)
            damageFloats.forEach { df ->
                androidx.compose.runtime.key(df.id) {
                    val age = (System.currentTimeMillis() - df.bornAtMs).coerceAtMost(1200)
                    val t = age / 1200f
                    val offsetY = -30f * t
                    val alpha = 1f - t
                    Text(
                        text = if (df.isCritical) "\uD83D\uDCA5 ${df.damage}!" else "-${df.damage}",
                        color = if (df.isCritical) Color(0xFFFFD23F) else Color(0xFFFF4747),
                        fontSize = if (df.isCritical) 22.sp else 17.sp,
                        style = TextStyle(
                            textAlign = TextAlign.Center,
                            fontSize = if (df.isCritical) 22.sp else 17.sp,
                        ),
                        modifier = Modifier
                            .align(Alignment.TopStart)
                            .offset(
                                x = with(density) { df.xPx.toDp() } - 20.dp,
                                y = with(density) { (df.yPx + offsetY).toDp() },
                            )
                            .graphicsLayer { this.alpha = alpha },
                    )
                }
            }
        }
    }
}

// ────────────────────────────────────────────────────────────
// Fighter sprite — emoji or (for custom creatures) Coil image
// ────────────────────────────────────────────────────────────
@Composable
private fun FighterSprite(animal: Animal, modifier: Modifier = Modifier) {
    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        val ctx = LocalContext.current
        val assetName = animal.creatureAssetName
        val drawableId = remember(assetName) {
            if (assetName == null) 0
            else ctx.resources.getIdentifier(assetName, "drawable", ctx.packageName)
        }
        when {
            animal.isCustom && !animal.imageUrl.isNullOrBlank() -> {
                AsyncImage(
                    model = animal.imageUrl,
                    contentDescription = animal.name,
                    modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)),
                    contentScale = ContentScale.Fit,
                )
            }
            drawableId != 0 -> {
                androidx.compose.foundation.Image(
                    painter = painterResource(id = drawableId),
                    contentDescription = animal.name,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit,
                )
            }
            else -> {
                Text(text = animal.emoji, fontSize = 90.sp)
            }
        }
    }
}

// ────────────────────────────────────────────────────────────
// Particle system
// ────────────────────────────────────────────────────────────
private data class Particle(
    val xFrac: Float,
    val yFrac: Float,
    val speed: Float,       // fraction of height per loop
    val driftFrac: Float,   // horizontal drift per loop
    val radiusPx: Float,
    val phase: Float,        // 0..1 phase offset
    val alpha: Float,
)

private fun createParticleField(env: BattleEnvironment, w: Float, h: Float): List<Particle> {
    val rnd = Random(env.ordinal * 9127 + 17)
    val count = when (env) {
        BattleEnvironment.ARCTIC -> 60
        BattleEnvironment.STORM -> 55
        BattleEnvironment.VOLCANO -> 30
        BattleEnvironment.DESERT -> 45
        BattleEnvironment.JUNGLE -> 22
        BattleEnvironment.SKY -> 10
        BattleEnvironment.NIGHT -> 40
        BattleEnvironment.OCEAN -> 18
        BattleEnvironment.GRASSLAND -> 14
    }
    return List(count) {
        Particle(
            xFrac = rnd.nextFloat(),
            yFrac = rnd.nextFloat(),
            speed = 0.5f + rnd.nextFloat() * 1.5f,
            driftFrac = (rnd.nextFloat() - 0.5f) * 0.12f,
            radiusPx = when (env) {
                BattleEnvironment.ARCTIC -> 1.5f + rnd.nextFloat() * 2.0f
                BattleEnvironment.STORM -> 1.0f
                BattleEnvironment.VOLCANO -> 1.5f + rnd.nextFloat() * 1.8f
                BattleEnvironment.DESERT -> 0.8f + rnd.nextFloat() * 1.5f
                BattleEnvironment.JUNGLE -> 3.0f + rnd.nextFloat() * 3.0f
                BattleEnvironment.NIGHT -> 1.5f + rnd.nextFloat() * 2.0f
                BattleEnvironment.SKY -> 22f + rnd.nextFloat() * 14f
                BattleEnvironment.OCEAN -> 2f + rnd.nextFloat() * 2f
                BattleEnvironment.GRASSLAND -> 1.2f + rnd.nextFloat() * 1.2f
            },
            phase = rnd.nextFloat(),
            alpha = 0.35f + rnd.nextFloat() * 0.55f,
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawParticles(
    env: BattleEnvironment,
    particles: List<Particle>,
    t: Float,
    size: Size,
) {
    when (env) {
        BattleEnvironment.ARCTIC -> drawFalling(
            particles, t, size, color = Color.White, fall = true, shape = ParticleShape.Circle,
        )
        BattleEnvironment.STORM -> drawRain(particles, t, size)
        BattleEnvironment.VOLCANO -> drawEmbers(particles, t, size)
        BattleEnvironment.DESERT -> drawSand(particles, t, size)
        BattleEnvironment.JUNGLE -> drawLeaves(particles, t, size)
        BattleEnvironment.NIGHT -> drawFireflies(particles, t, size)
        BattleEnvironment.SKY -> drawClouds(particles, t, size)
        BattleEnvironment.OCEAN -> drawWaveDots(particles, t, size)
        BattleEnvironment.GRASSLAND -> drawFalling(
            particles, t, size, color = Color(0xFFAED581).copy(alpha = 0.4f),
            fall = false, shape = ParticleShape.Circle,
        )
    }
}

private enum class ParticleShape { Circle, Streak }

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawFalling(
    particles: List<Particle>,
    t: Float,
    size: Size,
    color: Color,
    fall: Boolean,
    shape: ParticleShape,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * p.speed) % 1f
        val y = if (fall) size.height * phase else size.height * (1f - phase)
        val x = (size.width * p.xFrac + size.width * p.driftFrac * sin(phase * 2 * PI.toFloat())).let {
            ((it % size.width) + size.width) % size.width
        }
        drawCircle(
            color = color.copy(alpha = p.alpha),
            radius = p.radiusPx,
            center = Offset(x, y),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawRain(
    particles: List<Particle>, t: Float, size: Size,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * (p.speed + 1.5f)) % 1f
        val y = size.height * phase
        val x = size.width * p.xFrac
        val len = 14f + p.radiusPx * 4f
        drawLine(
            color = Color(0xFFBBDEFB).copy(alpha = p.alpha * 0.8f),
            start = Offset(x, y),
            end = Offset(x - len * 0.3f, y + len),
            strokeWidth = 1.4f,
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawEmbers(
    particles: List<Particle>, t: Float, size: Size,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * p.speed) % 1f
        val y = size.height * (0.85f - 0.55f * phase)
        val x = size.width * (0.3f + 0.4f * p.xFrac) +
            30f * sin((phase + p.phase) * 2 * PI.toFloat())
        val alpha = (1f - phase) * p.alpha
        drawCircle(
            color = Color(1f, 0.3f + 0.4f * p.xFrac, 0f, alpha),
            radius = p.radiusPx,
            center = Offset(x, y),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawSand(
    particles: List<Particle>, t: Float, size: Size,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * (p.speed + 0.8f)) % 1f
        val x = (size.width * (p.xFrac + phase * 0.4f)) % size.width
        val y = size.height * (0.55f + 0.4f * p.yFrac) + 6f * sin(phase * 2 * PI.toFloat())
        drawCircle(
            color = Color(0xFFFFB347).copy(alpha = p.alpha * 0.65f),
            radius = p.radiusPx,
            center = Offset(x, y),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawLeaves(
    particles: List<Particle>, t: Float, size: Size,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * p.speed * 0.6f) % 1f
        val y = size.height * phase
        val x = size.width * p.xFrac + 40f * sin(phase * 4 * PI.toFloat())
        drawCircle(
            color = Color(0xFF4CAF50).copy(alpha = p.alpha * 0.6f),
            radius = p.radiusPx,
            center = Offset(x, y),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawFireflies(
    particles: List<Particle>, t: Float, size: Size,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * p.speed * 0.3f) % 1f
        val x = size.width * (p.xFrac + 0.08f * sin(phase * 2 * PI.toFloat()))
        val y = size.height * (0.3f + 0.6f * p.yFrac + 0.05f * cos(phase * 2 * PI.toFloat()))
        val pulse = 0.5f + 0.5f * sin((phase + p.phase) * 2 * PI.toFloat())
        drawCircle(
            color = Color(0xFFFFF59D).copy(alpha = p.alpha * pulse),
            radius = p.radiusPx * (0.7f + 0.5f * pulse),
            center = Offset(x, y),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawClouds(
    particles: List<Particle>, t: Float, size: Size,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * p.speed * 0.2f) % 1f
        val x = (size.width * (p.xFrac + phase * 0.3f)) % (size.width + 100f) - 50f
        val y = size.height * (0.1f + 0.35f * p.yFrac)
        drawCircle(
            color = Color.White.copy(alpha = p.alpha * 0.18f),
            radius = p.radiusPx,
            center = Offset(x, y),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawWaveDots(
    particles: List<Particle>, t: Float, size: Size,
) {
    particles.forEach { p ->
        val phase = (p.phase + t * p.speed * 0.5f) % 1f
        val x = size.width * p.xFrac
        val waveY = size.height * (0.72f + 0.05f * sin((phase + p.xFrac) * 2 * PI.toFloat() * 3))
        drawCircle(
            color = Color(0xFF64B5F6).copy(alpha = p.alpha * 0.4f),
            radius = p.radiusPx,
            center = Offset(x, waveY),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawRadialGlow(
    center: Offset, radius: Float, color: Color,
) {
    drawCircle(
        brush = Brush.radialGradient(
            colors = listOf(color, color.copy(alpha = 0f)),
            center = center,
            radius = radius,
        ),
        radius = radius,
        center = center,
    )
}

// ────────────────────────────────────────────────────────────
// Damage float
// ────────────────────────────────────────────────────────────
private data class DamageFloat(
    val id: Int,
    val damage: Int,
    val isCritical: Boolean,
    val xPx: Float,
    val yPx: Float,
    val bornAtMs: Long,
)

private var damageFloatIdGen = 0
