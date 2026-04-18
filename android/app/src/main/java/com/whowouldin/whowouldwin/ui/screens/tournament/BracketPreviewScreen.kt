package com.whowouldin.whowouldwin.ui.screens.tournament

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.model.Matchup
import com.whowouldin.whowouldwin.model.Tournament
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.ui.components.AnimalAvatar
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.GoldCoin
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

@Composable
fun BracketPreviewScreen(
    tournament: Tournament,
    onConfirm: () -> Unit,
    onReroll: () -> Unit,
    onForfeit: () -> Unit,
) {
    val ctx = LocalContext.current
    val coinStore = remember { CoinStore.instance(ctx) }
    val rerollCost = coinStore.tournamentBracketRerollCost
    var showForfeit by remember { mutableStateOf(false) }
    val balance by coinStore.balance.collectAsState()

    ScreenBackground(style = BackgroundStyle.BATTLE) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color.White.copy(alpha = 0.1f), CircleShape)
                        .clickable { showForfeit = true },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Close, contentDescription = "Forfeit", tint = Color.White, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${tournament.size.size}-FIGHTER BRACKET", style = bungee(18).copy(color = Color.White))
                    Text("Preview & confirm", style = bungee(11).copy(color = Color.White.copy(alpha = 0.7f)))
                }
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.size(36.dp))
            }

            // Scrollable matchup list
            LazyColumn(
                modifier = Modifier.weight(1f).padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                item {
                    Text(
                        "ROUND 1 MATCHUPS",
                        style = bungee(10).copy(color = Color.White.copy(alpha = 0.45f), letterSpacing = 1.5.sp),
                        modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp),
                    )
                }
                items(tournament.bracket.rounds.firstOrNull() ?: emptyList(), key = { it.id }) { m ->
                    MatchupRow(m)
                }
            }

            // Action buttons
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 14.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                MegaButton(
                    text = "LOOKS GOOD — CONTINUE",
                    onClick = onConfirm,
                    color = MegaButtonColor.ORANGE,
                    height = 60,
                    cornerRadius = 18,
                    fontSize = 18,
                )
                if (!tournament.rerollUsed) {
                    MegaButton(
                        text = "RE-ROLL BRACKET — $rerollCost",
                        onClick = {
                            if (balance >= rerollCost) onReroll()
                        },
                        color = MegaButtonColor.PURPLE,
                        height = 48,
                        cornerRadius = 16,
                        fontSize = 14,
                        enabled = balance >= rerollCost,
                    )
                } else {
                    Text(
                        "Re-roll already used",
                        style = bungee(11).copy(color = Color.White.copy(alpha = 0.4f)),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }

    if (showForfeit) {
        AlertDialog(
            onDismissRequest = { showForfeit = false },
            title = { Text("Forfeit tournament?") },
            text = { Text("Your bracket will be cleared. Already-spent coins are not refunded.") },
            confirmButton = {
                TextButton(onClick = { showForfeit = false; onForfeit() }) { Text("Forfeit") }
            },
            dismissButton = {
                TextButton(onClick = { showForfeit = false }) { Text("Keep playing") }
            },
        )
    }
}

@Composable
private fun MatchupRow(m: Matchup) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.07f), RoundedCornerShape(8.dp))
            .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(8.dp))
            .padding(vertical = 6.dp, horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        AnimalAvatar(animal = m.fighter1, size = 22.dp)
        Text(m.fighter1.name, style = bungee(9).copy(color = Color.White), maxLines = 1, modifier = Modifier.weight(1f))
        Text("VS", style = bungee(8).copy(color = BrandTheme.gold))
        Text(
            m.fighter2.name,
            style = bungee(9).copy(color = Color.White),
            maxLines = 1,
            modifier = Modifier.weight(1f),
            textAlign = TextAlign.End,
        )
        AnimalAvatar(animal = m.fighter2, size = 22.dp)
    }
}

