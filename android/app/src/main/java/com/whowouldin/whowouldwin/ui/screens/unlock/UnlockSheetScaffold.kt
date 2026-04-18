package com.whowouldin.whowouldwin.ui.screens.unlock

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Shared shell for Fantasy / Prehistoric / Mythic / Olympus unlock sheets.
 *
 * Renders as a full-screen composable laid over a [ScreenBackground] with
 * the unlock gradient, a close X in the top-right, and a vertically scrollable
 * body supplied by the caller.
 */
@Composable
internal fun UnlockSheetScaffold(
    onDismiss: () -> Unit,
    body: @Composable () -> Unit,
) {
    ScreenBackground(style = BackgroundStyle.UNLOCK, modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Close button row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(top = 16.dp),
                horizontalArrangement = Arrangement.End,
            ) {
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(Color.White.copy(alpha = 0.10f))
                        .border(1.dp, Color.White.copy(alpha = 0.2f), CircleShape)
                        .clickable { onDismiss() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = "Close",
                        tint = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.size(13.dp),
                    )
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp)
                    .padding(top = 8.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                body()
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}

/** The 6-circle creature preview row used at the top of each unlock sheet. */
@Composable
internal fun CreaturePreviewRow(
    creatures: List<Pair<String, String>>, // (emoji, name)
    accentColor: Color,
    circleTopHex: String,
    circleBottomHex: String,
    lockIconColor: Color = Color.White.copy(alpha = 0.9f),
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        creatures.forEach { (emoji, name) ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.verticalGradient(
                                listOf(
                                    com.whowouldin.whowouldwin.ui.theme.colorFromHex(circleTopHex).copy(alpha = 0.85f),
                                    com.whowouldin.whowouldwin.ui.theme.colorFromHex(circleBottomHex),
                                )
                            )
                        )
                        .border(1.dp, accentColor.copy(alpha = 0.3f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = emoji,
                        fontSize = 22.sp,
                        modifier = Modifier.blur(2.5.dp),
                    )
                    Icon(
                        imageVector = Icons.Filled.Lock,
                        contentDescription = null,
                        tint = lockIconColor,
                        modifier = Modifier.size(11.dp),
                    )
                }
                Text(
                    text = name,
                    style = bungee(8),
                    color = Color.White.copy(alpha = 0.35f),
                    maxLines = 1,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

/** Thin hairline divider used between sections. */
@Composable
internal fun SheetDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
            .height(1.dp)
            .background(Color.White.copy(alpha = 0.08f))
    )
}

/** OR UNLOCK NOW divider row. */
@Composable
internal fun OrUnlockDivider() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.weight(1f).height(1.dp).background(Color.White.copy(alpha = 0.2f)))
        Text(
            text = "OR UNLOCK NOW",
            style = bungee(11).copy(letterSpacing = 1.5.sp),
            color = Color.White.copy(alpha = 0.35f),
        )
        Box(Modifier.weight(1f).height(1.dp).background(Color.White.copy(alpha = 0.2f)))
    }
}

/** Restore purchases footer link. */
@Composable
internal fun RestorePurchasesLink(onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "RESTORE PURCHASES",
            style = bungee(11).copy(
                letterSpacing = 1.sp,
                textDecoration = TextDecoration.Underline,
            ),
            color = Color.White.copy(alpha = 0.35f),
            modifier = Modifier.clickable { onClick() },
        )
    }
}
