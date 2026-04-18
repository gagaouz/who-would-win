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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
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
import com.whowouldin.whowouldwin.model.Tournament
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.service.TournamentManager
import com.whowouldin.whowouldwin.ui.components.AnimalCard
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.CoinBadge
import com.whowouldin.whowouldwin.ui.components.CoinBadgeSize
import com.whowouldin.whowouldwin.ui.components.GoldCoin
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

@Composable
fun GrandChampionWagerScreen(
    tournament: Tournament,
    manager: TournamentManager,
    onConfirm: (fighterId: String, amount: Int) -> Unit,
    onSkip: () -> Unit,
) {
    val ctx = LocalContext.current
    val coinStore = remember { CoinStore.instance(ctx) }
    val balance by coinStore.balance.collectAsState()
    val maxWager = manager.maxGrandChampionWager
    val minWager = coinStore.tournamentGrandChampionFloor

    var pickedId by remember { mutableStateOf<String?>(null) }
    var amount by remember { mutableStateOf(minWager.toFloat()) }
    val amountInt = amount.toInt()

    ScreenBackground(style = BackgroundStyle.BATTLE) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("GRAND CHAMPION", style = bungee(18).copy(color = BrandTheme.gold))
                    Text(
                        "Pick the whole-tournament winner — 5.0× payout",
                        style = bungee(11).copy(color = Color.White.copy(alpha = 0.75f)),
                    )
                }
                Spacer(Modifier.weight(1f))
                CoinBadge(
                    balance = balance,
                    formattedBalance = coinStore.formattedBalance,
                    onClick = {},
                    size = CoinBadgeSize.COMPACT,
                )
            }

            // Explainer
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
                    .border(1.dp, BrandTheme.gold.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    .padding(vertical = 8.dp, horizontal = 14.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text("🏆 High-risk, high-reward", style = bungee(13).copy(color = BrandTheme.gold))
                Text(
                    "Pick your bet once. You can buy-out later for a smaller multiplier.",
                    style = bungee(11).copy(color = Color.White.copy(alpha = 0.65f)),
                    textAlign = TextAlign.Center,
                )
            }

            // Grid
            val allFighters = tournament.bracket.allFighters
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.height(((allFighters.size / 3 + 1) * 120).dp),
            ) {
                items(allFighters, key = { it.id }) { animal ->
                    AnimalCard(
                        animal = animal,
                        isSelected = pickedId == animal.id,
                        isDisabled = false,
                        onTap = {
                            pickedId = animal.id
                            if (amountInt < minWager) amount = minWager.toFloat()
                        },
                    )
                }
            }

            // Slider
            if (pickedId != null) {
                if (maxWager > minWager) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
                            .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(12.dp))
                            .padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                            Text("WAGER", style = bungee(12).copy(color = Color.White.copy(alpha = 0.7f), letterSpacing = 1.5.sp))
                            Spacer(Modifier.weight(1f))
                            Text("$amountInt", style = bungee(20).copy(color = BrandTheme.gold))
                            Spacer(Modifier.width(4.dp))
                            GoldCoin(size = 18.dp)
                        }
                        Slider(
                            value = amount,
                            onValueChange = { amount = it },
                            valueRange = minWager.toFloat()..maxWager.toFloat(),
                            steps = ((maxWager - minWager) / 5 - 1).coerceAtLeast(0),
                            colors = SliderDefaults.colors(thumbColor = BrandTheme.gold, activeTrackColor = BrandTheme.gold),
                        )
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Text("MIN $minWager", style = bungee(10).copy(color = Color.White.copy(alpha = 0.55f)))
                            Spacer(Modifier.weight(1f))
                            Text("MAX $maxWager (50%)", style = bungee(10).copy(color = Color.White.copy(alpha = 0.55f)))
                        }
                    }
                } else if (maxWager == minWager && minWager > 0) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
                            .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(12.dp))
                            .padding(12.dp),
                    ) {
                        Text(
                            "FIXED WAGER: $minWager",
                            style = bungee(12).copy(color = Color.White.copy(alpha = 0.7f), letterSpacing = 1.5.sp),
                        )
                        Text(
                            "Earn more coins to unlock variable wagers",
                            style = bungee(10).copy(color = Color.White.copy(alpha = 0.55f)),
                        )
                    }
                } else {
                    Text(
                        "You need at least $minWager coins to place a Grand Champion wager.",
                        style = bungee(12).copy(color = Color.White.copy(alpha = 0.65f)),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            // Confirm / skip
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val canConfirm = pickedId != null && amountInt in minWager..maxWager
                MegaButton(
                    text = "LOCK IN (5.0× PAYOUT)",
                    onClick = {
                        if (canConfirm) onConfirm(pickedId!!, amountInt)
                    },
                    color = MegaButtonColor.GOLD,
                    height = 60,
                    cornerRadius = 18,
                    fontSize = 16,
                    enabled = canConfirm,
                )
                TextButton(onClick = onSkip, modifier = Modifier.fillMaxWidth()) {
                    Text(
                        "SKIP — NO GRAND CHAMPION BET",
                        style = bungee(13).copy(color = Color.White.copy(alpha = 0.65f)),
                    )
                }
            }
        }
    }
}
