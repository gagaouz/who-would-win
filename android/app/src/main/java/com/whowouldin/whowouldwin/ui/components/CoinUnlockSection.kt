package com.whowouldin.whowouldwin.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.service.CoinStore
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.ui.theme.colorFromHex

/**
 * Port of iOS `Views/Components/CoinUnlockSection.swift`.
 *
 * Yellow-bordered card with:
 *  - Header row ("UNLOCK WITH COINS" + balance readout)
 *  - Spend button — gold gradient when affordable, locked look when not
 *  - Upsell row when you can't afford AND no ads left today (stubbed — no AdManager on Android yet)
 */
@Composable
fun CoinUnlockSection(
    cost: Int,
    accentColor: Color,
    onUnlock: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val ctx = LocalContext.current
    val coinStore = remember { CoinStore.instance(ctx) }
    val settings = remember { UserSettings.instance(ctx) }
    val balance by coinStore.balance.collectAsState()
    val isSubscribed by settings.isSubscribed.collectAsState()

    val canAfford = balance >= cost
    val needed = (cost - balance).coerceAtLeast(0)
    var showInsufficientAlert by remember { mutableStateOf(false) }

    val gold = colorFromHex("#FFD700")
    val goldOrange = colorFromHex("#F59E0B")

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(gold.copy(alpha = 0.05f))
            .border(1.dp, gold.copy(alpha = 0.2f), RoundedCornerShape(16.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Header row
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            GoldCoin(size = 12.dp)
            Spacer(Modifier.width(5.dp))
            Text(
                text = "UNLOCK WITH COINS",
                style = bungee(11).copy(letterSpacing = 1.5.sp),
                color = gold,
            )
            Spacer(Modifier.weight(1f))
            Text(
                text = "Balance:",
                style = TextStyle(
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.35f),
                ),
            )
            Spacer(Modifier.width(4.dp))
            GoldCoin(size = 12.dp)
            Spacer(Modifier.width(4.dp))
            Text(
                text = coinStore.formattedBalance,
                style = bungee(12),
                color = gold,
            )
        }

        // Spend button
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .shadow(
                    elevation = if (canAfford) 10.dp else 0.dp,
                    shape = RoundedCornerShape(16.dp),
                    spotColor = if (canAfford) gold.copy(alpha = 0.45f) else Color.Transparent,
                )
                .clip(RoundedCornerShape(16.dp))
                .then(
                    if (canAfford) Modifier.background(
                        Brush.horizontalGradient(listOf(gold, goldOrange))
                    )
                    else Modifier.background(Color.White.copy(alpha = 0.12f))
                )
                .border(
                    1.dp,
                    if (canAfford) gold.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.2f),
                    RoundedCornerShape(16.dp),
                )
                .clickable {
                    if (canAfford) {
                        if (coinStore.spend(cost)) onUnlock()
                    } else {
                        showInsufficientAlert = true
                    }
                }
                .padding(horizontal = 16.dp, vertical = 14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                GoldCoin(size = 22.dp)
                Spacer(Modifier.width(10.dp))
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "Spend ${formatInt(cost)} coins",
                        style = bungee(16),
                        color = if (canAfford) Color.White else Color.White.copy(alpha = 0.6f),
                    )
                    if (!canAfford) {
                        Text(
                            text = "Need ${formatInt(needed)} more",
                            style = TextStyle(
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium,
                                color = Color.White.copy(alpha = 0.35f),
                            ),
                        )
                    }
                }
                Spacer(Modifier.weight(1f))
                if (canAfford) {
                    Icon(
                        imageVector = Icons.Filled.CheckCircle,
                        contentDescription = null,
                        tint = Color.White.copy(alpha = 0.85f),
                        modifier = Modifier.padding(start = 4.dp),
                    )
                }
            }
        }

        // Upsell — can't afford and not subscribed
        AnimatedVisibility(visible = !canAfford && !isSubscribed) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(BrandTheme.gold.copy(alpha = 0.08f))
                    .border(1.dp, BrandTheme.gold.copy(alpha = 0.2f), RoundedCornerShape(12.dp))
                    .padding(vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(
                    text = "Keep battling to earn more!",
                    style = bungee(12),
                    color = Color.White.copy(alpha = 0.5f),
                )
                Text(
                    text = "Go Premium for 2× coin earn rate!",
                    style = bungee(13),
                    color = BrandTheme.gold,
                )
            }
        }
    }

    if (showInsufficientAlert) {
        AlertDialog(
            onDismissRequest = { showInsufficientAlert = false },
            title = { Text("Not Enough Coins") },
            text = {
                Text("You need ${formatInt(needed)} more coins. Keep battling to earn more!")
            },
            confirmButton = {
                TextButton(onClick = { showInsufficientAlert = false }) { Text("OK") }
            },
        )
    }
}

private fun formatInt(value: Int): String =
    java.text.NumberFormat.getIntegerInstance().format(value)
