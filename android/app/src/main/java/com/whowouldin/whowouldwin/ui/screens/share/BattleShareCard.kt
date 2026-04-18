package com.whowouldin.whowouldwin.ui.screens.share

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.BattleResult

private val bg        = Color(0xFF07051A)
private val orange    = Color(0xFFFF5722)
private val cyan      = Color(0xFF00CFCF)
private val gold      = Color(0xFFFFD700)
private val goldLight = Color(0xFFFFF0A0)

/**
 * Android port of iOS BattleShareCard. Rendered off-screen via
 * [renderComposableToBitmap] and shared via [shareBattle].
 *
 * Dimensions follow the iOS layout (390 x 560 dp) so social-media crops match.
 */
@Composable
fun BattleShareCard(
    fighter1: Animal,
    fighter2: Animal,
    result: BattleResult,
) {
    val isDraw = result.winner == "draw"
    val winnerIsF1 = result.winner == fighter1.id
    val winner = if (winnerIsF1) fighter1 else fighter2
    val loser = if (winnerIsF1) fighter2 else fighter1
    val winnerAccent = if (winnerIsF1) orange else cyan
    val loserAccent = if (winnerIsF1) cyan else orange

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(bg),
        contentAlignment = Alignment.TopCenter,
    ) {
        // Diagonal radial glow approximated with a linear gradient for simplicity.
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(
                        colors = listOf(orange.copy(alpha = 0.35f), Color.Transparent, cyan.copy(alpha = 0.30f)),
                    )
                )
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Branding bar
            Text(
                text = "⚡ ANIMAL VS ANIMAL ⚡",
                color = orange,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = "Who Would Win?",
                color = Color.White.copy(alpha = 0.32f),
                fontSize = 9.sp,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(18.dp))

            // Fighter panels
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                FighterPanel(
                    animal = fighter1,
                    accent = orange,
                    isWinner = !isDraw && winner.id == fighter1.id,
                    isLoser = !isDraw && winner.id != fighter1.id,
                    modifier = Modifier.weight(1f),
                )
                Box(
                    modifier = Modifier
                        .size(46.dp)
                        .clip(CircleShape)
                        .background(bg)
                        .border(1.5.dp, Brush.linearGradient(listOf(orange, cyan)), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("VS", color = Color.White.copy(alpha = 0.9f), fontSize = 10.sp, fontWeight = FontWeight.Black)
                }
                FighterPanel(
                    animal = fighter2,
                    accent = cyan,
                    isWinner = !isDraw && winner.id == fighter2.id,
                    isLoser = !isDraw && winner.id != fighter2.id,
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(Modifier.height(14.dp))
            GradientRule()
            Spacer(Modifier.height(14.dp))

            // Result
            if (isDraw) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("⚔️", fontSize = 40.sp)
                    Text(
                        "IT'S A DRAW!",
                        fontSize = 26.sp,
                        fontWeight = FontWeight.Black,
                        color = gold,
                    )
                }
            } else {
                Text("🏆  WINNER", color = gold.copy(alpha = 0.75f), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                Text(
                    text = winner.name.uppercase(),
                    color = goldLight,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Black,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
                Spacer(Modifier.height(10.dp))
                HealthBar(winner.name, result.winnerHealthPercent, winnerAccent)
                Spacer(Modifier.height(4.dp))
                HealthBar(loser.name, result.loserHealthPercent, loserAccent.copy(alpha = 0.65f))
            }

            Spacer(Modifier.height(14.dp))
            // Narration
            val quote = result.narration.trim().let { if (it.endsWith(".")) it else "$it." }
            Text(
                text = "\u201C$quote\u201D",
                color = Color.White.copy(alpha = 0.55f),
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp),
            )
            Spacer(Modifier.height(14.dp))

            // Fun fact
            Row(
                verticalAlignment = Alignment.Top,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.White.copy(alpha = 0.04f))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                Text("✨", fontSize = 11.sp)
                Spacer(Modifier.width(6.dp))
                Text(
                    text = result.funFact,
                    color = Color.White.copy(alpha = 0.5f),
                    fontSize = 11.sp,
                )
            }

            Spacer(Modifier.height(12.dp))
            GradientRule()
            Spacer(Modifier.weight(1f, fill = true))

            // Footer
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(orange.copy(alpha = 0.08f))
                    .border(1.dp, orange.copy(alpha = 0.22f), RoundedCornerShape(10.dp))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                Column {
                    Text("🐾 Animal vs Animal", color = Color.White.copy(alpha = 0.85f), fontSize = 11.sp, fontWeight = FontWeight.Black)
                    Text("Download free on Google Play →", color = orange.copy(alpha = 0.85f), fontSize = 9.sp, fontWeight = FontWeight.Black)
                }
            }
        }
    }
}

@Composable
private fun FighterPanel(
    animal: Animal,
    accent: Color,
    isWinner: Boolean,
    isLoser: Boolean,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .wrapContentHeight()
            .padding(horizontal = 8.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(accent.copy(alpha = if (isWinner) 0.10f else 0.04f))
            .border(
                if (isWinner) 1.5.dp else 1.dp,
                accent.copy(alpha = if (isWinner) 0.35f else 0.12f),
                RoundedCornerShape(18.dp),
            )
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        when {
            isWinner -> Text("👑 WINNER", color = gold, fontSize = 8.sp, fontWeight = FontWeight.Black)
            isLoser -> Text("DEFEATED", color = Color.White.copy(alpha = 0.35f), fontSize = 8.sp, fontWeight = FontWeight.Black)
            else -> Spacer(Modifier.height(12.dp))
        }
        Spacer(Modifier.height(6.dp))
        Text(
            animal.emoji,
            fontSize = 78.sp,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = animal.name.uppercase(),
            color = if (isLoser) accent.copy(alpha = 0.5f) else accent,
            fontSize = 13.sp,
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun HealthBar(name: String, pct: Int, accent: Color) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 22.dp),
    ) {
        Text(
            text = name.uppercase(),
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 8.sp,
            fontWeight = FontWeight.Black,
            modifier = Modifier.width(68.dp),
            textAlign = TextAlign.End,
        )
        Spacer(Modifier.width(8.dp))
        Box(
            modifier = Modifier
                .weight(1f)
                .height(7.dp)
                .clip(RoundedCornerShape(50))
                .background(Color.White.copy(alpha = 0.08f)),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth(pct.coerceIn(0, 100) / 100f)
                    .fillMaxSize()
                    .background(Brush.horizontalGradient(listOf(accent.copy(alpha = 0.7f), accent))),
            )
        }
        Spacer(Modifier.width(8.dp))
        Text("$pct%", color = accent, fontSize = 8.sp, fontWeight = FontWeight.Black, modifier = Modifier.width(28.dp))
    }
}

@Composable
private fun GradientRule() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .height(1.dp)
            .background(
                Brush.horizontalGradient(
                    listOf(Color.Transparent, orange.copy(alpha = 0.4f), cyan.copy(alpha = 0.4f), Color.Transparent)
                )
            )
    )
}

// ---------------------------------------------------------------------------
// Public helper — renders to Bitmap + fires the share intent
// ---------------------------------------------------------------------------

/**
 * Renders a battle card to a Bitmap and launches a SEND intent via FileProvider.
 * Call from a coroutine / ViewModel; UI threading is handled internally.
 */
suspend fun shareBattle(
    context: Context,
    fighter1: Animal,
    fighter2: Animal,
    result: BattleResult,
    caption: String = "Who would win? 🔥 Find out in Animal vs Animal!",
) {
    val bitmap = renderComposableToBitmap(
        context = context,
        widthDp = 390,
        heightDp = 560,
    ) {
        BattleShareCard(fighter1, fighter2, result)
    }
    val uri = saveBitmapForSharing(
        context,
        bitmap,
        fileName = "battle_${fighter1.id}_vs_${fighter2.id}_${System.currentTimeMillis()}.png",
    )
    launchShareIntent(context, uri, caption)
}
