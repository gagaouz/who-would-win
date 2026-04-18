package com.whowouldin.whowouldwin.ui.screens.unlock

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.colorFromHex

/** Port of iOS `Views/MythicUnlockSheet.swift`. 500 battles free or $2.99 pack. */
@Composable
fun MythicUnlockSheet(
    onDismiss: () -> Unit,
) {
    val ctx = LocalContext.current
    val settings = remember { UserSettings.instance(ctx) }
    val coinStore = remember { CoinStore.instance(ctx) }
    val totalBattles by settings.totalBattleCount.collectAsState()

    val threshold = UserSettings.mythicBattleThreshold
    val battlesRemaining = (threshold - totalBattles).coerceAtLeast(0)
    val progress = settings.mythicUnlockProgress

    val accent = colorFromHex("#C0A000")
    val orange = BrandTheme.orange

    UnlockSheetScaffold(onDismiss = onDismiss) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "⚡",
                fontSize = 64.sp,
                style = TextStyle(shadow = Shadow(accent.copy(alpha = 0.7f), blurRadius = 20f)),
            )
            Text(
                text = "MYTHIC BEASTS",
                style = bungee(24).copy(
                    brush = Brush.horizontalGradient(listOf(accent, orange)),
                    shadow = Shadow(accent.copy(alpha = 0.5f), blurRadius = 8f),
                ),
                textAlign = TextAlign.Center,
            )
            Text(
                text = "12 legendary beasts from ancient mythology",
                style = bungee(14),
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
            )
        }

        CreaturePreviewRow(
            creatures = listOf(
                "🦅" to "Thunder", "🦁" to "Manticore", "🐉" to "Wyvern",
                "🦄" to "Kirin", "🦅" to "Roc", "🐇" to "Jackalope",
            ),
            accentColor = accent,
            circleTopHex = "#332D08",
            circleBottomHex = "#1A1604",
        )

        SheetDivider()

        FreePathProgress(
            title = "Play 500 Battles",
            currentBattles = totalBattles,
            targetBattles = threshold,
            progress = progress,
            accentColor = accent,
            progressGradient = Brush.horizontalGradient(listOf(accent, orange)),
            tipEmoji = "⚡",
            batteryRemainingLabel = if (battlesRemaining > 0)
                "$battlesRemaining more battle${if (battlesRemaining == 1) "" else "s"} to go!"
            else null,
        )

        CoinUnlockSection(
            cost = coinStore.mythicCost,
            accentColor = accent,
            onUnlock = {
                settings.setMythicUnlocked(true)
                onDismiss()
            },
        )

        OrUnlockDivider()

        PaidUnlockButton(
            emoji = "⚡",
            title = "Unlock Mythic Beasts Pack",
            priceText = "$2.99",
            color = MegaButtonColor.ORANGE,
            onClick = {
                settings.setMythicUnlocked(true)
                onDismiss()
            },
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Text(text = "👑", fontSize = 12.sp, color = BrandTheme.gold)
            Spacer(Modifier.size(6.dp))
            Text(
                text = "Also included in Premium subscription",
                style = TextStyle(fontSize = 12.sp, color = Color.White.copy(alpha = 0.35f)),
            )
        }

        RestorePurchasesLink(onClick = {})
    }
}
