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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.model.BracketSize
import com.whowouldin.whowouldwin.model.SelectionMode
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.GamePanel
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Port of iOS TournamentSetupView — bracket size + selection mode picker.
 */
@Composable
fun TournamentSetupScreen(
    onContinue: (BracketSize, SelectionMode) -> Unit,
    onClose: () -> Unit,
) {
    var size by remember { mutableStateOf(BracketSize.EIGHT) }
    var mode by remember { mutableStateOf(SelectionMode.RANDOM) }

    ScreenBackground(style = BackgroundStyle.BATTLE) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            // Top bar with close
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(38.dp)
                        .background(Color.White.copy(alpha = 0.10f), CircleShape)
                        .clickable { onClose() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = Color.White, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.weight(1f))
            }

            // Header
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text(
                    "🏆 TOURNAMENT MODE 🏆",
                    style = bungee(22).copy(color = BrandTheme.gold),
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    "Pick your bracket and start the hype!",
                    style = bungee(13).copy(color = Color.White.copy(alpha = 0.75f)),
                )
            }

            // Size
            GamePanel(headerText = "BRACKET SIZE", headerColor = MegaButtonColor.BLUE) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    BracketSize.values().forEach { s ->
                        SizeChip(size = s, isSelected = size == s, onClick = { size = s }, modifier = Modifier.weight(1f))
                    }
                }
            }

            // Mode
            GamePanel(headerText = "FIGHTER SELECTION", headerColor = MegaButtonColor.PURPLE) {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    ModeRow(
                        title = "RANDOM ROLL",
                        subtitle = "Surprise me! Pick my whole bracket.",
                        emoji = "🎲",
                        isSelected = mode == SelectionMode.RANDOM,
                        onTap = { mode = SelectionMode.RANDOM },
                    )
                    ModeRow(
                        title = "HAND-PICK ALL",
                        subtitle = "Choose every fighter yourself.",
                        emoji = "✍️",
                        isSelected = mode == SelectionMode.MANUAL,
                        onTap = { mode = SelectionMode.MANUAL },
                    )
                    ModeRow(
                        title = "MIX IT UP",
                        subtitle = "Pick a few, fill the rest at random.",
                        emoji = "🎯",
                        isSelected = mode == SelectionMode.HYBRID,
                        onTap = { mode = SelectionMode.HYBRID },
                    )
                }
            }

            Spacer(Modifier.height(4.dp))

            MegaButton(
                text = if (mode == SelectionMode.RANDOM) "ROLL BRACKET" else "PICK FIGHTERS",
                onClick = { onContinue(size, mode) },
                color = MegaButtonColor.ORANGE,
                height = 70,
                cornerRadius = 22,
                fontSize = 22,
            )
        }
    }
}

@Composable
private fun SizeChip(size: BracketSize, isSelected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .background(
                if (isSelected) BrandTheme.orange.copy(alpha = 0.35f) else Color.White.copy(alpha = 0.08f),
                RoundedCornerShape(14.dp),
            )
            .border(
                width = if (isSelected) 2.5.dp else 1.2.dp,
                color = if (isSelected) BrandTheme.orange else Color.White.copy(alpha = 0.20f),
                shape = RoundedCornerShape(14.dp),
            )
            .clickable { onClick() }
            .padding(vertical = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text("${size.size}", style = bungee(28).copy(color = Color.White))
        Text("FIGHTERS", style = bungee(10).copy(color = Color.White.copy(alpha = 0.7f), letterSpacing = 1.sp))
    }
}

@Composable
private fun ModeRow(
    title: String,
    subtitle: String,
    emoji: String,
    isSelected: Boolean,
    onTap: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (isSelected) BrandTheme.gold.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.05f),
                RoundedCornerShape(12.dp),
            )
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) BrandTheme.gold.copy(alpha = 0.9f) else Color.White.copy(alpha = 0.15f),
                shape = RoundedCornerShape(12.dp),
            )
            .clickable { onTap() }
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(emoji, fontSize = 28.sp)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = bungee(13).copy(color = Color.White, letterSpacing = 0.5.sp))
            Text(subtitle, style = bungee(12).copy(color = Color.White.copy(alpha = 0.7f)))
        }
        Icon(
            imageVector = if (isSelected) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (isSelected) BrandTheme.gold else Color.White.copy(alpha = 0.4f),
            modifier = Modifier.size(22.dp),
        )
    }
}
