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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.Matchup
import com.whowouldin.whowouldwin.model.Tournament
import com.whowouldin.whowouldwin.model.WagerMultipliers
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.service.TournamentManager
import com.whowouldin.whowouldwin.ui.components.AnimalAvatar
import com.whowouldin.whowouldwin.ui.components.AnimalCard
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.CoinBadge
import com.whowouldin.whowouldwin.ui.components.CoinBadgeSize
import com.whowouldin.whowouldwin.ui.components.GamePanel
import com.whowouldin.whowouldwin.ui.components.GoldCoin
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.components.VSShield
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun RoundWagerScreen(
    tournament: Tournament,
    roundIndex: Int,
    manager: TournamentManager,
    onDone: () -> Unit,
) {
    val ctx = LocalContext.current
    val coinStore = remember { CoinStore.instance(ctx) }
    val balance by coinStore.balance.collectAsState()
    val round = tournament.bracket.rounds.getOrNull(roundIndex) ?: emptyList()
    val multiplier = WagerMultipliers.matchup(roundIndex, tournament.size)

    var activeMatchupId by remember { mutableStateOf<String?>(null) }
    var showGcSwap by remember { mutableStateOf(false) }
    val matchupSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val gcSheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ScreenBackground(style = BackgroundStyle.BATTLE) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("PLACE YOUR BETS", style = bungee(18).copy(color = Color.White))
                    Text(
                        "Matchup payout: ${"%.1f".format(multiplier)}×",
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

            GamePanel(
                headerText = tournament.size.roundName(roundIndex).uppercase(),
                headerColor = MegaButtonColor.ORANGE,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    round.forEach { m ->
                        MatchupWagerRow(m, multiplier) { if (m.wager == null) activeMatchupId = m.id }
                    }
                }
            }

            // Grand champion card
            val gc = tournament.grandChampion
            if (gc != null) {
                val pick = tournament.bracket.allFighters.firstOrNull { it.id == gc.pickedFighterId }
                val alive = tournament.bracket.aliveFighters.any { it.id == gc.pickedFighterId }
                if (pick != null) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(14.dp))
                            .border(1.2.dp, BrandTheme.gold.copy(alpha = 0.45f), RoundedCornerShape(14.dp))
                            .padding(12.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            AnimalAvatar(animal = pick, size = 44.dp)
                            Column(modifier = Modifier.weight(1f)) {
                                Text("GRAND CHAMPION PICK", style = bungee(11).copy(color = BrandTheme.gold, letterSpacing = 1.5.sp))
                                Text(pick.name, style = bungee(16).copy(color = Color.White))
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text("${gc.amount}", style = bungee(11).copy(color = Color.White.copy(alpha = 0.7f)))
                                    GoldCoin(size = 11.dp)
                                    Text("· ${"%.2f".format(gc.multiplier)}×", style = bungee(11).copy(color = Color.White.copy(alpha = 0.7f)))
                                }
                            }
                            if (!alive) {
                                Text(
                                    "ELIMINATED",
                                    style = bungee(10).copy(color = BrandTheme.red),
                                    modifier = Modifier
                                        .background(BrandTheme.red.copy(alpha = 0.2f), CircleShape)
                                        .padding(horizontal = 8.dp, vertical = 4.dp),
                                )
                            }
                        }
                        if (tournament.canSwapGrandChampion) {
                            MegaButton(
                                text = if (alive) "BUY OUT — SWAP PICK" else "RESCUE — PICK A SURVIVOR",
                                onClick = { showGcSwap = true },
                                color = MegaButtonColor.PURPLE,
                                height = 42,
                                cornerRadius = 14,
                                fontSize = 12,
                            )
                        } else {
                            Text("Locked for the final", style = bungee(10).copy(color = Color.White.copy(alpha = 0.45f)))
                        }
                    }
                }
            }

            MegaButton(
                text = "START THE ROUND",
                onClick = onDone,
                color = MegaButtonColor.ORANGE,
                height = 60,
                cornerRadius = 18,
                fontSize = 18,
            )
        }
    }

    // Matchup wager sheet
    val activeMatchup = round.firstOrNull { it.id == activeMatchupId }
    if (activeMatchup != null) {
        ModalBottomSheet(
            onDismissRequest = { activeMatchupId = null },
            sheetState = matchupSheetState,
            containerColor = Color(0xFF0E0B22),
        ) {
            MatchupWagerSheetContent(
                matchup = activeMatchup,
                multiplier = multiplier,
                maxWager = manager.maxMatchupWager,
                minWager = coinStore.tournamentMatchupWagerFloor,
                onPlace = { pickedId, amount ->
                    manager.placeMatchupWager(activeMatchup.id, pickedId, amount)
                    activeMatchupId = null
                },
                onCancel = { activeMatchupId = null },
            )
        }
    }

    if (showGcSwap) {
        ModalBottomSheet(
            onDismissRequest = { showGcSwap = false },
            sheetState = gcSheetState,
            containerColor = Color(0xFF0E0B22),
        ) {
            GrandChampionSwapSheetContent(
                tournament = tournament,
                onSwap = { id ->
                    manager.swapGrandChampion(id)
                    showGcSwap = false
                },
                onCancel = { showGcSwap = false },
            )
        }
    }
}

@Composable
private fun MatchupWagerRow(m: Matchup, multiplier: Double, onClick: () -> Unit) {
    val hasWager = m.wager != null
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(12.dp))
            .border(
                width = if (hasWager) 1.6.dp else 1.dp,
                color = if (hasWager) BrandTheme.gold.copy(alpha = 0.7f) else Color.White.copy(alpha = 0.18f),
                shape = RoundedCornerShape(12.dp),
            )
            .clickable(enabled = !hasWager) { onClick() }
            .padding(horizontal = 8.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FighterChip(m.fighter1, m.wager?.pickedFighterId == m.fighter1.id, Modifier.weight(1f))
            VSShield(size = 30, fontSize = 10)
            FighterChip(m.fighter2, m.wager?.pickedFighterId == m.fighter2.id, Modifier.weight(1f))
            Text(m.environment.emoji, fontSize = 16.sp, modifier = Modifier.width(28.dp), textAlign = TextAlign.Center)
        }
        if (hasWager) {
            val w = m.wager!!
            val name = if (w.pickedFighterId == m.fighter1.id) m.fighter1.name else m.fighter2.name
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = BrandTheme.gold, modifier = Modifier.size(14.dp))
                Text("${w.amount}", style = bungee(12).copy(color = BrandTheme.gold))
                GoldCoin(size = 12.dp)
                Text("on $name", style = bungee(12).copy(color = BrandTheme.gold))
            }
        } else {
            Text(
                "Tap to place wager (${"%.1f".format(multiplier)}×)",
                style = bungee(11).copy(color = Color.White.copy(alpha = 0.6f)),
            )
        }
    }
}

@Composable
private fun FighterChip(a: Animal, isPicked: Boolean, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        AnimalAvatar(animal = a, size = 30.dp)
        Text(
            a.name,
            style = bungee(11).copy(color = if (isPicked) BrandTheme.gold else Color.White),
            maxLines = 1,
        )
    }
}

@Composable
private fun MatchupWagerSheetContent(
    matchup: Matchup,
    multiplier: Double,
    maxWager: Int,
    minWager: Int,
    onPlace: (String, Int) -> Unit,
    onCancel: () -> Unit,
) {
    var picked by remember { mutableStateOf<String?>(null) }
    var amount by remember { mutableStateOf(minWager.toFloat()) }
    val amountInt = amount.toInt()

    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("PLACE WAGER", style = bungee(18).copy(color = Color.White), modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            PickTile(matchup.fighter1, picked == matchup.fighter1.id, Modifier.weight(1f)) { picked = matchup.fighter1.id }
            VSShield(size = 34, fontSize = 12)
            PickTile(matchup.fighter2, picked == matchup.fighter2.id, Modifier.weight(1f)) { picked = matchup.fighter2.id }
        }

        if (maxWager > minWager) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    Text("WAGER", style = bungee(11).copy(color = Color.White.copy(alpha = 0.6f), letterSpacing = 1.sp))
                    Spacer(Modifier.weight(1f))
                    Text("$amountInt", style = bungee(18).copy(color = BrandTheme.gold))
                    Spacer(Modifier.width(4.dp))
                    GoldCoin(size = 16.dp)
                }
                Slider(
                    value = amount,
                    onValueChange = { amount = it },
                    valueRange = minWager.toFloat()..maxWager.toFloat(),
                    colors = SliderDefaults.colors(thumbColor = BrandTheme.gold, activeTrackColor = BrandTheme.gold),
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    Text("MIN $minWager", style = bungee(10).copy(color = Color.White.copy(alpha = 0.5f)))
                    Spacer(Modifier.weight(1f))
                    Text("MAX $maxWager (10%)", style = bungee(10).copy(color = Color.White.copy(alpha = 0.5f)))
                }
                Text(
                    "Payout if correct: ${(amountInt * multiplier).toInt()}",
                    style = bungee(12).copy(color = Color.White.copy(alpha = 0.75f)),
                )
            }
        } else if (maxWager == minWager && minWager > 0) {
            Text(
                "Fixed wager: $minWager — earn more coins to bet higher.",
                style = bungee(11).copy(color = Color.White.copy(alpha = 0.5f)),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            Text(
                "Not enough coins to wager. Minimum is $minWager.",
                style = bungee(12).copy(color = Color.White.copy(alpha = 0.6f)),
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            MegaButton(
                text = "CANCEL",
                onClick = onCancel,
                color = MegaButtonColor.BLUE,
                height = 50,
                cornerRadius = 16,
                fontSize = 13,
                modifier = Modifier.weight(1f),
            )
            val canPlace = picked != null && amountInt in minWager..maxWager
            MegaButton(
                text = "PLACE BET",
                onClick = { if (canPlace) onPlace(picked!!, amountInt) },
                color = MegaButtonColor.ORANGE,
                height = 50,
                cornerRadius = 16,
                fontSize = 13,
                enabled = canPlace,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun PickTile(a: Animal, isPicked: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(
        modifier = modifier
            .background(
                if (isPicked) BrandTheme.gold.copy(alpha = 0.35f) else Color.White.copy(alpha = 0.08f),
                RoundedCornerShape(14.dp),
            )
            .border(
                width = if (isPicked) 2.dp else 1.dp,
                color = if (isPicked) BrandTheme.gold else Color.White.copy(alpha = 0.2f),
                shape = RoundedCornerShape(14.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        AnimalAvatar(animal = a, size = 48.dp)
        Text(a.name, style = bungee(12).copy(color = Color.White), maxLines = 1)
    }
}

@Composable
private fun GrandChampionSwapSheetContent(
    tournament: Tournament,
    onSwap: (String) -> Unit,
    onCancel: () -> Unit,
) {
    var picked by remember { mutableStateOf<String?>(null) }
    val r = tournament.currentRoundIndex ?: 0
    val newMult = WagerMultipliers.grandChampion(r)

    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("SWAP GRAND CHAMPION", style = bungee(16).copy(color = Color.White), modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
        Text(
            "New multiplier: ${"%.2f".format(newMult)}× · wager stays the same",
            style = bungee(12).copy(color = Color.White.copy(alpha = 0.7f)),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        LazyVerticalGrid(
            columns = GridCells.Fixed(3),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier.height(240.dp),
        ) {
            items(tournament.bracket.aliveFighters, key = { it.id }) { animal ->
                AnimalCard(
                    animal = animal,
                    isSelected = picked == animal.id,
                    isDisabled = false,
                    onTap = { picked = animal.id },
                )
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            MegaButton(
                text = "CANCEL",
                onClick = onCancel,
                color = MegaButtonColor.BLUE,
                height = 48,
                cornerRadius = 14,
                fontSize = 13,
                modifier = Modifier.weight(1f),
            )
            MegaButton(
                text = "SWAP",
                onClick = { picked?.let(onSwap) },
                color = MegaButtonColor.PURPLE,
                height = 48,
                cornerRadius = 14,
                fontSize = 13,
                enabled = picked != null,
                modifier = Modifier.weight(1f),
            )
        }
    }
}
