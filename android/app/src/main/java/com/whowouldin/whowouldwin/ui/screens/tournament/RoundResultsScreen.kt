package com.whowouldin.whowouldwin.ui.screens.tournament

import androidx.compose.foundation.background
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.model.Tournament
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.service.TournamentManager
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.CoinBadge
import com.whowouldin.whowouldwin.ui.components.CoinBadgeSize
import com.whowouldin.whowouldwin.ui.components.GamePanel
import com.whowouldin.whowouldwin.ui.components.GoldCoin
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

@Composable
fun RoundResultsScreen(
    tournament: Tournament,
    roundIndex: Int,
    manager: TournamentManager,
    onContinue: () -> Unit,
) {
    val ctx = LocalContext.current
    val coinStore = remember { CoinStore.instance(ctx) }
    val balance by coinStore.balance.collectAsState()
    var lines by remember { mutableStateOf<List<TournamentManager.RoundPayoutLine>>(emptyList()) }
    var didResolve by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (!didResolve) {
            didResolve = true
            lines = manager.resolveRoundPayouts()
        }
    }

    val isFinalRound = roundIndex == tournament.size.totalRounds - 1
    val roundNet = lines.sumOf { it.delta }

    ScreenBackground(style = BackgroundStyle.BATTLE) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "${tournament.size.roundName(roundIndex).uppercase()} RESULTS",
                        style = bungee(18).copy(color = Color.White),
                    )
                    Text(
                        "Round ${roundIndex + 1} of ${tournament.size.totalRounds}",
                        style = bungee(11).copy(color = Color.White.copy(alpha = 0.7f)),
                    )
                }
                Spacer(Modifier.weight(1f))
                CoinBadge(balance = balance, formattedBalance = coinStore.formattedBalance, onClick = {}, size = CoinBadgeSize.COMPACT)
            }

            GamePanel(headerText = "PAYOUTS", headerColor = MegaButtonColor.GOLD) {
                if (lines.isEmpty()) {
                    Text(
                        "No wagers this round.",
                        style = bungee(12).copy(color = Color.White.copy(alpha = 0.6f)),
                        modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
                    )
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        lines.forEach { PayoutRow(it) }
                        Box(modifier = Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.2f)))
                        Row(modifier = Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                "ROUND NET",
                                style = bungee(13).copy(color = Color.White.copy(alpha = 0.7f), letterSpacing = 1.sp),
                            )
                            Spacer(Modifier.weight(1f))
                            Text(
                                if (roundNet >= 0) "+$roundNet" else "$roundNet",
                                style = bungee(16).copy(color = if (roundNet >= 0) BrandTheme.neonGrn else BrandTheme.red.copy(alpha = 0.9f)),
                            )
                            Spacer(Modifier.width(4.dp))
                            GoldCoin(size = 14.dp)
                        }
                    }
                }
            }

            MegaButton(
                text = if (isFinalRound) "SEE CHAMPION" else "NEXT ROUND",
                onClick = onContinue,
                color = MegaButtonColor.ORANGE,
                height = 60,
                cornerRadius = 18,
                fontSize = 18,
            )
        }
    }
}

@Composable
private fun PayoutRow(line: TournamentManager.RoundPayoutLine) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.05f), RoundedCornerShape(10.dp))
            .padding(vertical = 8.dp, horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            imageVector = if (line.won) Icons.Filled.CheckCircle else Icons.Filled.Cancel,
            contentDescription = null,
            tint = if (line.won) BrandTheme.neonGrn else BrandTheme.red.copy(alpha = 0.85f),
            modifier = Modifier.size(20.dp),
        )
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("WINNER: ${line.winnerName}", style = bungee(12).copy(color = Color.White))
            if (line.wagered > 0) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("Wagered ${line.wagered}", fontSize = 11.sp, color = Color.White.copy(alpha = 0.55f))
                    GoldCoin(size = 11.dp)
                }
            } else {
                Text("No wager", fontSize = 11.sp, color = Color.White.copy(alpha = 0.45f))
            }
        }
        if (line.wagered > 0) {
            Text(
                if (line.delta >= 0) "+${line.delta}" else "${line.delta}",
                style = bungee(14).copy(color = if (line.won) BrandTheme.neonGrn else BrandTheme.red.copy(alpha = 0.9f)),
            )
            Spacer(Modifier.width(4.dp))
            GoldCoin(size = 14.dp)
        }
    }
}
