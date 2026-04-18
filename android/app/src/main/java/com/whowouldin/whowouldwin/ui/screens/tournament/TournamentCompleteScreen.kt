package com.whowouldin.whowouldwin.ui.screens.tournament

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.model.Tournament
import com.whowouldin.whowouldwin.service.TournamentManager
import com.whowouldin.whowouldwin.ui.components.AnimalAvatar
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.GamePanel
import com.whowouldin.whowouldwin.ui.components.GoldCoin
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

@Composable
fun TournamentCompleteScreen(
    tournament: Tournament,
    manager: TournamentManager,
    onPlayAgain: () -> Unit,
    onExit: () -> Unit,
) {
    var gcPayout by remember { mutableStateOf<Int?>(null) }
    var didResolve by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (!didResolve) {
            didResolve = true
            gcPayout = manager.resolveGrandChampionPayout()
        }
    }

    val champion = tournament.bracket.rounds.lastOrNull()?.firstOrNull()?.winningFighter
    val gc = tournament.grandChampion
    val totalWagersPlaced = tournament.bracket.rounds.sumOf { r -> r.count { it.wager != null } }
    val netDelta = manager.netCoinDelta

    ScreenBackground(style = BackgroundStyle.BATTLE) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("🏆", fontSize = 64.sp)
            Text(
                "CHAMPION",
                style = bungee(22).copy(color = BrandTheme.gold, letterSpacing = 3.sp),
            )

            // Champion card
            if (champion != null) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(18.dp))
                        .border(2.dp, BrandTheme.gold, RoundedCornerShape(18.dp))
                        .padding(vertical = 16.dp, horizontal = 14.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    AnimalAvatar(animal = champion, size = 88.dp, cornerRadius = 16.dp)
                    Text(champion.name.uppercase(), style = bungee(20).copy(color = Color.White))
                    Text(
                        "${tournament.size.size}-fighter bracket winner",
                        style = bungee(11).copy(color = Color.White.copy(alpha = 0.65f)),
                    )
                }
            }

            // Summary
            GamePanel(headerText = "TOURNAMENT SUMMARY", headerColor = MegaButtonColor.GOLD) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    SummaryRow("Rounds", "${tournament.size.totalRounds}")
                    SummaryRow("Fighters", "${tournament.size.size}")
                    SummaryRow("Wagers placed", "$totalWagersPlaced")
                    if (gc != null) {
                        val pickName = tournament.bracket.allFighters.firstOrNull { it.id == gc.pickedFighterId }?.name ?: "?"
                        val correct = champion?.id == gc.pickedFighterId
                        SummaryRow(
                            label = "Grand Champion",
                            value = if (correct) "$pickName ✅" else "$pickName ❌",
                        )
                        if (gcPayout != null && gcPayout!! > 0) {
                            SummaryRow(
                                label = "GC payout",
                                value = "+${gcPayout}",
                                valueColor = BrandTheme.neonGrn,
                                coin = true,
                            )
                        }
                    } else {
                        SummaryRow("Grand Champion", "Skipped")
                    }
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(1.dp)
                            .background(Color.White.copy(alpha = 0.2f)),
                    )
                    SummaryRow(
                        label = "NET",
                        value = if (netDelta >= 0) "+$netDelta" else "$netDelta",
                        valueColor = if (netDelta >= 0) BrandTheme.neonGrn else BrandTheme.red.copy(alpha = 0.9f),
                        coin = true,
                        large = true,
                    )
                }
            }

            // Bracket
            GamePanel(headerText = "BRACKET", headerColor = MegaButtonColor.PURPLE) {
                TournamentBracketDiagram(
                    bracket = tournament.bracket,
                    highlightedRoundIndex = tournament.size.totalRounds - 1,
                )
            }

            // Actions
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                MegaButton(
                    text = "PLAY AGAIN",
                    onClick = onPlayAgain,
                    color = MegaButtonColor.ORANGE,
                    height = 60,
                    cornerRadius = 18,
                    fontSize = 18,
                )
                MegaButton(
                    text = "BACK TO HOME",
                    onClick = onExit,
                    color = MegaButtonColor.BLUE,
                    height = 52,
                    cornerRadius = 16,
                    fontSize = 14,
                )
            }
        }
    }
}

@Composable
private fun SummaryRow(
    label: String,
    value: String,
    valueColor: Color = Color.White,
    coin: Boolean = false,
    large: Boolean = false,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label.uppercase(),
            style = bungee(if (large) 14 else 12).copy(
                color = Color.White.copy(alpha = 0.7f),
                letterSpacing = 1.sp,
            ),
        )
        Spacer(Modifier.weight(1f))
        Text(
            value,
            style = bungee(if (large) 18 else 13).copy(color = valueColor),
            textAlign = TextAlign.End,
        )
        if (coin) {
            Spacer(Modifier.width(4.dp))
            GoldCoin(size = if (large) 16.dp else 12.dp)
        }
    }
}
