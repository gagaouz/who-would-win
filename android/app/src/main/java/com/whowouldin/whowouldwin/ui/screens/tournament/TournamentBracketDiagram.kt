package com.whowouldin.whowouldwin.ui.screens.tournament

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.Bracket
import com.whowouldin.whowouldwin.model.BracketSize
import com.whowouldin.whowouldwin.model.Matchup
import com.whowouldin.whowouldwin.ui.components.AnimalAvatar
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Port of iOS TournamentBracketDiagram.
 *
 * Horizontal list of round columns, each with compact matchup cards.
 * Shows winners highlighted with a crown + loser name strikethrough.
 */
@Composable
fun TournamentBracketDiagram(
    bracket: Bracket,
    modifier: Modifier = Modifier,
    highlightedRoundIndex: Int? = null,
    scrollable: Boolean = true,
) {
    val content: @Composable () -> Unit = {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            bracket.rounds.forEachIndexed { roundIdx, round ->
                val alpha = if (highlightedRoundIndex == null || highlightedRoundIndex == roundIdx) 1f else 0.55f
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier
                        .padding(bottom = 2.dp),
                ) {
                    Text(
                        text = roundLabel(bracket, roundIdx),
                        style = bungee(11).copy(
                            color = Color.White.copy(alpha = 0.75f * alpha),
                            letterSpacing = 1.sp,
                        ),
                        modifier = Modifier.padding(bottom = 2.dp),
                    )
                    if (round.isEmpty()) {
                        repeat(placeholderCount(bracket, roundIdx).coerceAtLeast(1)) {
                            PlaceholderCard(alpha)
                        }
                    } else {
                        round.forEach { m -> MatchupCard(m, alpha) }
                    }
                }
            }
        }
    }

    if (scrollable) {
        Box(modifier.horizontalScroll(rememberScrollState())) { content() }
    } else {
        Box(modifier) { content() }
    }
}

private fun roundLabel(b: Bracket, idx: Int): String {
    val size = when (b.rounds.size) {
        2 -> BracketSize.FOUR
        3 -> BracketSize.EIGHT
        4 -> BracketSize.SIXTEEN
        else -> BracketSize.FOUR
    }
    return size.roundName(idx).uppercase()
}

private fun placeholderCount(b: Bracket, idx: Int): Int {
    val remaining = b.rounds.size - idx
    return when (remaining) {
        1 -> 1; 2 -> 2; 3 -> 4; 4 -> 8; else -> 1
    }
}

@Composable
private fun MatchupCard(m: Matchup, alpha: Float) {
    Column(
        modifier = Modifier
            .width(120.dp)
            .background(Color.White.copy(alpha = 0.08f * alpha), RoundedCornerShape(10.dp))
            .border(1.dp, Color.White.copy(alpha = 0.25f * alpha), RoundedCornerShape(10.dp))
            .padding(vertical = 6.dp, horizontal = 8.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        FighterRow(
            animal = m.fighter1,
            isWinner = m.winningFighter?.id == m.fighter1.id,
            isLoser = m.losingFighter?.id == m.fighter1.id,
            alpha = alpha,
        )
        Box(Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.25f * alpha)))
        FighterRow(
            animal = m.fighter2,
            isWinner = m.winningFighter?.id == m.fighter2.id,
            isLoser = m.losingFighter?.id == m.fighter2.id,
            alpha = alpha,
        )
    }
}

@Composable
private fun FighterRow(animal: Animal, isWinner: Boolean, isLoser: Boolean, alpha: Float) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        AnimalAvatar(animal = animal, size = 20.dp, cornerRadius = 5.dp)
        Text(
            text = animal.name,
            style = bungee(11).copy(
                color = (if (isLoser) Color.White.copy(alpha = 0.35f) else Color.White).copy(alpha = alpha),
                textDecoration = if (isLoser) TextDecoration.LineThrough else TextDecoration.None,
            ),
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        if (isWinner) {
            Icon(
                imageVector = Icons.Filled.Star,
                contentDescription = null,
                tint = BrandTheme.gold.copy(alpha = alpha),
                modifier = Modifier.size(10.dp),
            )
        }
    }
}

@Composable
private fun PlaceholderCard(alpha: Float) {
    Column(
        modifier = Modifier
            .width(120.dp)
            .background(Color.White.copy(alpha = 0.04f * alpha), RoundedCornerShape(10.dp))
            .border(1.dp, Color.White.copy(alpha = 0.12f * alpha), RoundedCornerShape(10.dp))
            .padding(vertical = 6.dp, horizontal = 8.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text("? ? ?", style = bungee(11).copy(color = Color.White.copy(alpha = 0.35f * alpha)))
        Spacer(Modifier.height(2.dp))
        Text("? ? ?", style = bungee(11).copy(color = Color.White.copy(alpha = 0.35f * alpha)))
    }
}
