package com.whowouldin.whowouldwin.ui.screens.tournament

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.BracketSize
import com.whowouldin.whowouldwin.model.SelectionMode
import com.whowouldin.whowouldwin.model.TournamentPhase
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.service.TournamentManager
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.screens.BattleScreen
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import kotlinx.coroutines.launch

/**
 * Root of the tournament flow. Observes [TournamentManager.activeTournament]
 * and dispatches to the appropriate phase screen. When no tournament is
 * active, shows the pre-tournament setup/picker.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TournamentRootScreen(
    onExit: () -> Unit,
) {
    val ctx = LocalContext.current
    val manager: TournamentManager = viewModel(factory = TournamentManager.factory(ctx))
    val active by manager.activeTournament.collectAsState()
    val coinStore = remember { CoinStore.instance(ctx) }
    val balance by coinStore.balance.collectAsState()

    // Pre-tournament local state (before a Tournament is created)
    var preStage by remember { mutableStateOf(PreStage.SETUP) }
    var chosenSize by remember { mutableStateOf(BracketSize.EIGHT) }
    var chosenMode by remember { mutableStateOf(SelectionMode.RANDOM) }
    var showCostSheet by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    fun attemptStart(picks: List<Animal>) {
        val result = manager.startNew(
            size = chosenSize,
            selectionMode = chosenMode,
            manualPicks = picks,
            payWithCoinsIfOverLimit = false,
        )
        if (result == null && manager.nextTournamentRequiresCoins) {
            showCostSheet = true
        }
    }

    fun confirmPaidStart(picks: List<Animal>) {
        manager.startNew(
            size = chosenSize,
            selectionMode = chosenMode,
            manualPicks = picks,
            payWithCoinsIfOverLimit = true,
        )
        showCostSheet = false
    }

    val activeTournament = active
    if (activeTournament == null) {
        // Pre-tournament
        when (preStage) {
            PreStage.SETUP -> TournamentSetupScreen(
                onContinue = { size, mode ->
                    chosenSize = size
                    chosenMode = mode
                    if (mode == SelectionMode.RANDOM) {
                        attemptStart(emptyList())
                    } else {
                        preStage = PreStage.PICKER
                    }
                },
                onClose = onExit,
            )
            PreStage.PICKER -> TournamentCreaturePickerScreen(
                targetCount = chosenSize.size,
                mode = chosenMode,
                onContinue = { picks -> attemptStart(picks) },
                onBack = { preStage = PreStage.SETUP },
            )
        }
    } else {
        when (val phase = activeTournament.phase) {
            TournamentPhase.Setup, TournamentPhase.Picking, TournamentPhase.Preview -> {
                BracketPreviewScreen(
                    tournament = activeTournament,
                    onConfirm = { manager.setPhase(TournamentPhase.GrandWager) },
                    onReroll = { manager.rerollBracket() },
                    onForfeit = {
                        manager.forfeit()
                        preStage = PreStage.SETUP
                    },
                )
            }
            TournamentPhase.GrandWager -> {
                GrandChampionWagerScreen(
                    tournament = activeTournament,
                    manager = manager,
                    onConfirm = { id, amount ->
                        manager.placeGrandChampion(id, amount)
                        manager.setPhase(TournamentPhase.RoundWager(0))
                    },
                    onSkip = { manager.setPhase(TournamentPhase.RoundWager(0)) },
                )
            }
            is TournamentPhase.RoundWager -> {
                RoundWagerScreen(
                    tournament = activeTournament,
                    roundIndex = phase.roundIndex,
                    manager = manager,
                    onDone = {
                        manager.setPhase(TournamentPhase.RoundBattles(phase.roundIndex, 0))
                    },
                )
            }
            is TournamentPhase.RoundBattles -> {
                val round = activeTournament.bracket.rounds.getOrNull(phase.roundIndex) ?: emptyList()
                val matchup = round.getOrNull(phase.matchupIndex)
                if (matchup == null) {
                    // Should not happen — advance to results.
                    LaunchedEffect(phase) {
                        manager.setPhase(TournamentPhase.RoundResults(phase.roundIndex))
                    }
                } else {
                    BattleScreen(
                        fighter1 = matchup.fighter1,
                        fighter2 = matchup.fighter2,
                        environment = matchup.environment,
                        tournamentContext = "Round ${phase.roundIndex + 1} — Match ${phase.matchupIndex + 1}/${round.size}",
                        onBack = onExit,
                        onTournamentComplete = { result ->
                            manager.recordMatchupResult(matchup.id, result)
                            val nextIdx = phase.matchupIndex + 1
                            if (nextIdx < round.size) {
                                manager.setPhase(TournamentPhase.RoundBattles(phase.roundIndex, nextIdx))
                            } else {
                                manager.setPhase(TournamentPhase.RoundResults(phase.roundIndex))
                            }
                        },
                    )
                }
            }
            is TournamentPhase.RoundResults -> {
                RoundResultsScreen(
                    tournament = activeTournament,
                    roundIndex = phase.roundIndex,
                    manager = manager,
                    onContinue = {
                        val isFinal = phase.roundIndex == activeTournament.size.totalRounds - 1
                        if (isFinal) {
                            manager.setPhase(TournamentPhase.Complete)
                        } else {
                            manager.setPhase(TournamentPhase.RoundWager(phase.roundIndex + 1))
                        }
                    },
                )
            }
            TournamentPhase.Complete -> {
                TournamentCompleteScreen(
                    tournament = activeTournament,
                    manager = manager,
                    onPlayAgain = {
                        manager.clear()
                        preStage = PreStage.SETUP
                    },
                    onExit = {
                        manager.clear()
                        onExit()
                    },
                )
            }
        }
    }

    if (showCostSheet) {
        val cost = coinStore.tournamentExtraEntryCost
        val canPay = balance >= cost
        ModalBottomSheet(
            onDismissRequest = { showCostSheet = false },
            sheetState = sheetState,
            containerColor = Color(0xFF1A1A2E),
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    "DAILY LIMIT REACHED",
                    style = bungee(18).copy(color = BrandTheme.gold),
                )
                Text(
                    "You've used your ${coinStore.tournamentDailyFreeLimit} free tournaments today. Spend $cost coins to play another?",
                    style = bungee(12).copy(color = Color.White.copy(alpha = 0.8f)),
                    textAlign = TextAlign.Center,
                )
                Text(
                    "Balance: $balance",
                    style = bungee(11).copy(color = Color.White.copy(alpha = 0.6f)),
                )
                MegaButton(
                    text = if (canPay) "SPEND $cost COINS" else "NOT ENOUGH COINS",
                    onClick = {
                        if (canPay) {
                            scope.launch { sheetState.hide() }
                            confirmPaidStart(emptyList())
                        }
                    },
                    color = if (canPay) MegaButtonColor.GOLD else MegaButtonColor.BLUE,
                    height = 56,
                    cornerRadius = 16,
                    fontSize = 15,
                    enabled = canPay,
                )
                MegaButton(
                    text = "MAYBE LATER",
                    onClick = {
                        scope.launch { sheetState.hide() }
                        showCostSheet = false
                    },
                    color = MegaButtonColor.BLUE,
                    height = 48,
                    cornerRadius = 14,
                    fontSize = 13,
                )
            }
        }
    }
}

private enum class PreStage { SETUP, PICKER }
