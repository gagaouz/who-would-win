package com.whowouldin.whowouldwin.ui.screens.unlock

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.ui.components.CoinUnlockSection
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.colorFromHex
import com.whowouldin.whowouldwin.service.CoinStore

/**
 * Port of iOS `Views/FantasyUnlockSheet.swift`.
 *
 * Shown when the user taps a locked fantasy creature or the Fantasy category pill.
 * Two paths: 250 battles (free) OR spend coins / buy Fantasy Pack.
 */
@Composable
fun FantasyUnlockSheet(
    onDismiss: () -> Unit,
) {
    val ctx = LocalContext.current
    val settings = remember { UserSettings.instance(ctx) }
    val coinStore = remember { CoinStore.instance(ctx) }
    val totalBattles by settings.totalBattleCount.collectAsState()

    val threshold = UserSettings.fantasyBattleThreshold
    val battlesRemaining = (threshold - totalBattles).coerceAtLeast(0)
    val progress = settings.fantasyUnlockProgress

    val fantasyAccent = BrandTheme.fantasyAccent
    val magenta = colorFromHex("#E040FB")
    val lilac = colorFromHex("#C77DFF")

    UnlockSheetScaffold(onDismiss = onDismiss) {
        // Header
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "✨",
                fontSize = 64.sp,
                style = TextStyle(
                    shadow = Shadow(
                        color = fantasyAccent.copy(alpha = 0.7f),
                        blurRadius = 20f,
                    ),
                ),
            )
            Text(
                text = "FANTASY REALM",
                style = bungee(24).copy(
                    brush = Brush.horizontalGradient(listOf(fantasyAccent, magenta, lilac)),
                    shadow = Shadow(color = fantasyAccent.copy(alpha = 0.5f), blurRadius = 8f),
                ),
                textAlign = TextAlign.Center,
            )
            Text(
                text = "12 legendary creatures await",
                style = bungee(14),
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center,
            )
        }

        // Creature preview row
        CreaturePreviewRow(
            creatures = listOf(
                "🐉" to "Dragon", "🦄" to "Unicorn", "🐙" to "Kraken",
                "🐂" to "Minotaur", "🔥" to "Phoenix", "🐲" to "Hydra",
            ),
            accentColor = fantasyAccent,
            circleTopHex = "#3B1067",
            circleBottomHex = "#1A0535",
        )

        SheetDivider()

        FreePathProgress(
            title = "Play 250 Battles",
            currentBattles = totalBattles,
            targetBattles = threshold,
            progress = progress,
            accentColor = fantasyAccent,
            progressGradient = Brush.horizontalGradient(listOf(fantasyAccent, magenta)),
            tipEmoji = "✨",
            batteryRemainingLabel = if (battlesRemaining > 0)
                "$battlesRemaining more battle${if (battlesRemaining == 1) "" else "s"} to go!"
            else null,
        )

        CoinUnlockSection(
            cost = coinStore.fantasyCost,
            accentColor = fantasyAccent,
            onUnlock = {
                settings.setFantasyUnlocked(true)
                onDismiss()
            },
        )

        OrUnlockDivider()

        PaidUnlockButton(
            emoji = "✨",
            title = "Unlock Fantasy Pack",
            priceText = "$1.99",
            color = MegaButtonColor.PURPLE,
            onClick = {
                // StoreKit isn't wired on Android yet; in DEBUG just unlock.
                settings.setFantasyUnlocked(true)
                onDismiss()
            },
        )

        // Premium note
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            Text(text = "👑", fontSize = 12.sp, color = BrandTheme.gold)
            Spacer(Modifier.size(6.dp))
            Text(
                text = "Also included in Premium subscription",
                style = TextStyle(
                    fontSize = 12.sp,
                    color = Color.White.copy(alpha = 0.35f),
                ),
            )
        }

        RestorePurchasesLink(onClick = {
            // Restore no-op (not wired on Android).
        })
    }
}
