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
import com.whowouldin.whowouldwin.model.Matchup
import com.whowouldin.whowouldwin.model.Tournament

private val bg        = Color(0xFF07051A)
private val orange    = Color(0xFFFF5722)
private val cyan      = Color(0xFF00CFCF)
private val gold      = Color(0xFFFFD700)
private val goldLight = Color(0xFFFFF0A0)

/**
 * Tournament summary share card. Renders champion hero + compact bracket.
 */
@Composable
fun TournamentShareCard(
    tournament: Tournament,
    grandChampionPayout: Int,
    netCoinDelta: Int,
) {
    val champion = tournament.bracket.rounds.lastOrNull()?.firstOrNull()?.winningFighter

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(bg),
        contentAlignment = Alignment.TopCenter,
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(listOf(gold.copy(alpha = 0.35f), Color.Transparent, orange.copy(alpha = 0.15f)))
                )
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("⚡ TOURNAMENT RESULT ⚡", color = orange, fontSize = 11.sp, fontWeight = FontWeight.Black)
            Spacer(Modifier.height(4.dp))
            Text("Who Would Win?", color = Color.White.copy(alpha = 0.32f), fontSize = 9.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(18.dp))

            // Champion hero
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(22.dp))
                    .background(gold.copy(alpha = 0.08f))
                    .border(1.5.dp, gold.copy(alpha = 0.35f), RoundedCornerShape(22.dp))
                    .padding(vertical = 18.dp),
            ) {
                Text("🏆 CHAMPION 🏆", color = gold, fontSize = 11.sp, fontWeight = FontWeight.Black)
                Spacer(Modifier.height(10.dp))
                Text(champion?.emoji ?: "❓", fontSize = 120.sp)
                Spacer(Modifier.height(8.dp))
                Text(
                    text = (champion?.name ?: "???").uppercase(),
                    color = goldLight,
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Black,
                    textAlign = TextAlign.Center,
                )
                if (tournament.grandChampion != null && grandChampionPayout > 0) {
                    Spacer(Modifier.height(8.dp))
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(gold.copy(alpha = 0.14f))
                            .border(1.dp, gold.copy(alpha = 0.35f), RoundedCornerShape(50))
                            .padding(horizontal = 10.dp, vertical = 5.dp),
                    ) {
                        Text(
                            "GRAND CHAMPION HIT  +$grandChampionPayout coins",
                            color = Color(0xFF69F0AE),
                            fontSize = 9.sp,
                            fontWeight = FontWeight.Black,
                        )
                    }
                }
            }

            Spacer(Modifier.height(14.dp))
            GradientRuleTour()
            Spacer(Modifier.height(14.dp))

            // Bracket summary — rounds as columns.
            Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp)) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text("BRACKET", color = Color.White.copy(alpha = 0.55f), fontSize = 10.sp, fontWeight = FontWeight.Black)
                    Spacer(Modifier.weight(1f))
                    Text("${tournament.size.size} FIGHTERS", color = Color.White.copy(alpha = 0.45f), fontSize = 9.sp, fontWeight = FontWeight.Black)
                }
                Spacer(Modifier.height(6.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    tournament.bracket.rounds.forEachIndexed { idx, round ->
                        Column(
                            modifier = Modifier.weight(1f),
                            horizontalAlignment = Alignment.CenterHorizontally,
                        ) {
                            Text(
                                tournament.size.roundName(idx).uppercase(),
                                color = gold.copy(alpha = 0.65f),
                                fontSize = 7.sp,
                                fontWeight = FontWeight.Black,
                            )
                            Spacer(Modifier.height(4.dp))
                            round.forEach { matchup ->
                                MatchupMini(matchup)
                                Spacer(Modifier.height(4.dp))
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(14.dp))
            GradientRuleTour()
            Spacer(Modifier.height(12.dp))

            // Stats row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                StatBox("FIGHTERS", tournament.bracket.allFighters.size.toString(), gold, Modifier.weight(1f))
                StatBox("ROUNDS", tournament.size.totalRounds.toString(), gold, Modifier.weight(1f))
                StatBox(
                    "NET",
                    if (netCoinDelta >= 0) "+$netCoinDelta coins" else "$netCoinDelta coins",
                    if (netCoinDelta >= 0) Color(0xFF69F0AE) else Color(0xFFFF8A80),
                    Modifier.weight(1f),
                )
            }

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
private fun MatchupMini(m: Matchup) {
    val winnerId = m.winningFighter?.id
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .border(0.8.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(6.dp))
            .padding(horizontal = 4.dp, vertical = 4.dp),
    ) {
        FighterMiniRow(m.fighter1.name, m.fighter1.emoji, winnerId == m.fighter1.id)
        Box(Modifier.fillMaxWidth().height(0.5.dp).background(Color.White.copy(alpha = 0.2f)))
        FighterMiniRow(m.fighter2.name, m.fighter2.emoji, winnerId == m.fighter2.id)
    }
}

@Composable
private fun FighterMiniRow(name: String, emoji: String, isWinner: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(emoji, fontSize = 10.sp)
        Spacer(Modifier.width(3.dp))
        Text(
            name,
            color = if (isWinner) gold else Color.White.copy(alpha = 0.6f),
            fontSize = 7.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
        if (isWinner) {
            Spacer(Modifier.width(2.dp))
            Text("👑", fontSize = 6.sp)
        }
    }
}

@Composable
private fun StatBox(label: String, value: String, tint: Color, modifier: Modifier) {
    Column(
        modifier = modifier
            .wrapContentHeight()
            .clip(RoundedCornerShape(10.dp))
            .background(Color.White.copy(alpha = 0.05f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(10.dp))
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label, color = Color.White.copy(alpha = 0.45f), fontSize = 8.sp, fontWeight = FontWeight.Black)
        Spacer(Modifier.height(2.dp))
        Text(value, color = tint, fontSize = 14.sp, fontWeight = FontWeight.Black, maxLines = 1)
    }
}

@Composable
private fun GradientRuleTour() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .height(1.dp)
            .background(
                Brush.horizontalGradient(
                    listOf(Color.Transparent, gold.copy(alpha = 0.4f), orange.copy(alpha = 0.4f), Color.Transparent)
                )
            )
    )
}

/** Renders the tournament card and launches the system share sheet. */
suspend fun shareTournament(
    context: Context,
    tournament: Tournament,
    grandChampionPayout: Int,
    netCoinDelta: Int,
    caption: String = "I just won a tournament in Animal vs Animal! 🏆",
) {
    val bitmap = renderComposableToBitmap(
        context = context,
        widthDp = 390,
        heightDp = 620,
    ) {
        TournamentShareCard(tournament, grandChampionPayout, netCoinDelta)
    }
    val uri = saveBitmapForSharing(
        context,
        bitmap,
        fileName = "tournament_${tournament.id}_${System.currentTimeMillis()}.png",
    )
    launchShareIntent(context, uri, caption)
}
