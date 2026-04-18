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

/** Port of iOS `Views/PrehistoricUnlockSheet.swift`. 100 battles free or $1.99 pack. */
@Composable
fun PrehistoricUnlockSheet(
    onDismiss: () -> Unit,
) {
    val ctx = LocalContext.current
    val settings = remember { UserSettings.instance(ctx) }
    val coinStore = remember { CoinStore.instance(ctx) }
    val totalBattles by settings.totalBattleCount.collectAsState()

    val threshold = UserSettings.prehistoricBattleThreshold
    val battlesRemaining = (threshold - totalBattles).coerceAtLeast(0)
    val progress = settings.prehistoricUnlockProgress

    val accent = colorFromHex("#C8820A")
    val yellow = BrandTheme.yellow

    UnlockSheetScaffold(onDismiss = onDismiss) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "🦖",
                fontSize = 64.sp,
                style = TextStyle(shadow = Shadow(accent.copy(alpha = 0.7f), blurRadius = 20f)),
            )
            Text(
                text = "PREHISTORIC PACK",
                style = bungee(22).copy(
                    brush = Brush.horizontalGradient(listOf(accent, yellow)),
                    shadow = Shadow(accent.copy(alpha = 0.5f), blurRadius = 8f),
                ),
                textAlign = TextAlign.Center,
            )
            Text(
                text = "12 ancient titans of the prehistoric world",
                style = bungee(14),
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
            )
        }

        CreaturePreviewRow(
            creatures = listOf(
                "🦖" to "T-Rex", "🦕" to "Tricera", "🦈" to "Megalodon",
                "🦣" to "Mammoth", "🐅" to "Saber-Tooth", "🦖" to "Spino",
            ),
            accentColor = accent,
            circleTopHex = "#4E3108",
            circleBottomHex = "#2D1A04",
        )

        SheetDivider()

        FreePathProgress(
            title = "Play 100 Battles",
            currentBattles = totalBattles,
            targetBattles = threshold,
            progress = progress,
            accentColor = accent,
            progressGradient = Brush.horizontalGradient(listOf(accent, yellow)),
            tipEmoji = "🦴",
            batteryRemainingLabel = if (battlesRemaining > 0)
                "$battlesRemaining more battle${if (battlesRemaining == 1) "" else "s"} to go!"
            else null,
        )

        CoinUnlockSection(
            cost = coinStore.prehistoricCost,
            accentColor = accent,
            onUnlock = {
                settings.setPrehistoricUnlocked(true)
                onDismiss()
            },
        )

        OrUnlockDivider()

        PaidUnlockButton(
            emoji = "🦖",
            title = "Unlock Prehistoric Pack",
            priceText = "$1.99",
            color = MegaButtonColor.ORANGE,
            onClick = {
                settings.setPrehistoricUnlocked(true)
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
