package com.whowouldin.whowouldwin.ui.screens.unlock

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.ui.components.CoinUnlockSection
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.colorFromHex

/** Port of iOS `Views/OlympusUnlockSheet.swift`. 10,000 battles free or $19.99 pack. */
@Composable
fun OlympusUnlockSheet(
    onDismiss: () -> Unit,
) {
    val ctx = LocalContext.current
    val settings = remember { UserSettings.instance(ctx) }
    val coinStore = remember { CoinStore.instance(ctx) }
    val totalBattles by settings.totalBattleCount.collectAsState()

    val threshold = UserSettings.olympusBattleThreshold
    val battlesRemaining = (threshold - totalBattles).coerceAtLeast(0)
    val progress = settings.olympusUnlockProgress

    val gold = colorFromHex("#FFD700")
    val goldLight = colorFromHex("#FFF8DC")
    val purple = colorFromHex("#4A0E8F")

    UnlockSheetScaffold(onDismiss = onDismiss) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "🏛️⚡️🏛️",
                fontSize = 52.sp,
                style = TextStyle(shadow = Shadow(gold.copy(alpha = 0.9f), blurRadius = 30f)),
            )
            Text(
                text = "MOUNT OLYMPUS",
                style = bungee(28).copy(
                    brush = Brush.horizontalGradient(listOf(gold, goldLight, gold)),
                    shadow = Shadow(gold.copy(alpha = 0.8f), blurRadius = 12f),
                ),
                textAlign = TextAlign.Center,
            )
            Text(
                text = "The ultimate pack — 12 Greek gods and legends",
                style = TextStyle(fontSize = 14.sp, color = Color.White.copy(alpha = 0.7f)),
                textAlign = TextAlign.Center,
            )
            // Unlocked-all-packs capsule badge
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(gold.copy(alpha = 0.15f))
                    .border(1.dp, gold.copy(alpha = 0.4f), RoundedCornerShape(50))
                    .padding(horizontal = 14.dp, vertical = 6.dp),
            ) {
                Text(
                    text = "YOU UNLOCKED ALL PACKS!",
                    style = bungee(11).copy(letterSpacing = 1.5.sp),
                    color = gold,
                )
            }
        }

        CreaturePreviewRow(
            creatures = listOf(
                "⚡️" to "Zeus", "🔱" to "Poseidon", "💀" to "Hades",
                "🪖" to "Ares", "🦉" to "Athena", "☀️" to "Apollo",
            ),
            accentColor = gold,
            circleTopHex = "#2A1A00",
            circleBottomHex = "#0D0800",
            lockIconColor = gold.copy(alpha = 0.9f),
        )

        SheetDivider()

        FreePathProgress(
            title = "Play 10,000 Battles",
            currentBattles = totalBattles,
            targetBattles = threshold,
            progress = progress,
            accentColor = gold,
            progressGradient = Brush.horizontalGradient(listOf(purple, gold)),
            tipEmoji = "⚡️",
            batteryRemainingLabel = if (battlesRemaining > 0)
                "${formatCount(battlesRemaining)} more battle${if (battlesRemaining == 1) "" else "s"} to go!"
            else null,
        )

        CoinUnlockSection(
            cost = coinStore.olympusCost,
            accentColor = gold,
            onUnlock = {
                settings.setOlympusUnlocked(true)
                onDismiss()
            },
        )

        OrUnlockDivider()

        PaidUnlockButton(
            emoji = "⚡️",
            title = "Unlock Mount Olympus Pack",
            priceText = "$19.99",
            color = MegaButtonColor.GOLD,
            onClick = {
                settings.setOlympusUnlocked(true)
                onDismiss()
            },
        )

        RestorePurchasesLink(onClick = {})
    }
}

private fun formatCount(value: Int): String =
    java.text.NumberFormat.getIntegerInstance().format(value)
