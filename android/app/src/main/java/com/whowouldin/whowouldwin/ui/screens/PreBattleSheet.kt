package com.whowouldin.whowouldwin.ui.screens

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.BattleEnvironment
import com.whowouldin.whowouldwin.service.HapticsService
import com.whowouldin.whowouldwin.ui.components.AnimalAvatar
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.PixelText
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.components.VSShield
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Port of iOS `Views/PreBattleSheet.swift`.
 *
 * Shown after both fighters are picked — previews the matchup and lets the user
 * pick an arena (3-column grid, locked tiles show 🔒), toggle arena effects, and
 * launch the battle via a giant orange "LET'S FIGHT!" CTA.
 */
@Composable
fun PreBattleSheet(
    fighter1: Animal,
    fighter2: Animal,
    selectedEnvironment: BattleEnvironment,
    arenaEffectsEnabled: Boolean,
    onSelectedEnvironmentChange: (BattleEnvironment) -> Unit,
    onArenaEffectsEnabledChange: (Boolean) -> Unit,
    onFight: () -> Unit,
    onDismiss: () -> Unit,
) {
    val ctx = LocalContext.current
    val settings = remember { UserSettings.instance(ctx) }
    val totalBattles by settings.totalBattleCount.collectAsState()
    val environmentsUnlocked by settings.environmentsUnlocked.collectAsState()
    val isSubscribed by settings.isSubscribed.collectAsState()

    ScreenBackground(style = BackgroundStyle.HOME, modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Drag handle
            Box(
                modifier = Modifier
                    .padding(top = 12.dp, bottom = 10.dp)
                    .size(width = 40.dp, height = 4.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(Color.White.copy(alpha = 0.2f))
            )

            // Title + back row
            Box(
                modifier = Modifier.fillMaxWidth().padding(bottom = 20.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "CHOOSE YOUR ARENA",
                    style = bungee(11).copy(letterSpacing = 2.sp),
                    color = Color.White.copy(alpha = 0.35f),
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clickable { onDismiss() },
                    ) {
                        Icon(
                            imageVector = Icons.Filled.KeyboardArrowLeft,
                            contentDescription = null,
                            tint = Color.White.copy(alpha = 0.6f),
                            modifier = Modifier.size(16.dp),
                        )
                        Spacer(Modifier.width(2.dp))
                        Text(
                            text = "Change",
                            style = TextStyle(
                                fontSize = 13.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White.copy(alpha = 0.6f),
                            ),
                        )
                    }
                }
            }

            // Fighter matchup row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp, vertical = 0.dp)
                    .padding(bottom = 24.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                FighterBadge(animal = fighter1, accent = BrandTheme.orange)
                // VS circle — a small VSShield-like badge with orange→yellow gradient
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .shadow(8.dp, CircleShape, spotColor = BrandTheme.orange.copy(alpha = 0.5f))
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(listOf(BrandTheme.orange, BrandTheme.yellow))
                        ),
                    contentAlignment = Alignment.Center,
                ) {
                    PixelText(text = "VS", size = 10, color = Color.White)
                }
                FighterBadge(animal = fighter2, accent = BrandTheme.cyan)
            }

            // Arena grid (fills remaining space)
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(BattleEnvironment.values()) { env ->
                    ArenaCell(
                        env = env,
                        isSelected = env == selectedEnvironment,
                        isLocked = !settings.isEnvironmentUnlocked(env),
                        onTap = {
                            HapticsService.instance(ctx).tap()
                            if (!settings.isEnvironmentUnlocked(env)) {
                                // No AdManager wired yet — silently no-op.
                                return@ArenaCell
                            }
                            onSelectedEnvironmentChange(env)
                            onArenaEffectsEnabledChange(true)
                        },
                    )
                }
            }

            Spacer(Modifier.height(16.dp))

            // Arena effects toggle
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.12f))
                    .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(16.dp))
                    .padding(horizontal = 24.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = "Arena Effects",
                        style = bungee(13),
                        color = Color.White,
                    )
                    Text(
                        text = if (arenaEffectsEnabled)
                            "Arena shapes the outcome"
                        else "Pure animal vs animal",
                        style = bungee(12),
                        color = Color.White.copy(alpha = 0.35f),
                    )
                }
                Switch(
                    checked = arenaEffectsEnabled,
                    onCheckedChange = onArenaEffectsEnabledChange,
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = BrandTheme.orange,
                        uncheckedThumbColor = Color.White,
                        uncheckedTrackColor = Color.White.copy(alpha = 0.24f),
                    ),
                )
            }

            Spacer(Modifier.height(16.dp))

            // Fight button
            FightButton(
                onClick = {
                    HapticsService.instance(ctx).medium()
                    onFight()
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .padding(bottom = 36.dp),
            )
        }
    }
}

@Composable
private fun FighterBadge(animal: Animal, accent: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.15f))
                .border(1.5.dp, accent.copy(alpha = 0.4f), CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            AnimalAvatar(animal = animal, size = 48.dp)
        }
        Text(
            text = animal.name,
            style = bungee(11),
            color = Color.White,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
    }
}

@Composable
private fun ArenaCell(
    env: BattleEnvironment,
    isSelected: Boolean,
    isLocked: Boolean,
    onTap: () -> Unit,
) {
    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.04f else 1f,
        animationSpec = spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessMedium),
        label = "arenaSel",
    )

    Column(
        modifier = Modifier
            .scale(scale)
            .fillMaxWidth()
            .height(80.dp)
            .clip(RoundedCornerShape(14.dp))
            .then(
                if (isSelected) Modifier.background(
                    Brush.linearGradient(
                        listOf(
                            env.accentColor.copy(alpha = 0.35f),
                            env.accentColor.copy(alpha = 0.15f),
                        )
                    )
                )
                else Modifier.background(Color.White.copy(alpha = 0.12f))
            )
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) env.accentColor.copy(alpha = 0.8f) else Color.White.copy(alpha = 0.2f),
                shape = RoundedCornerShape(14.dp),
            )
            .clickable(onClick = onTap)
            .alpha(if (isLocked) 0.55f else 1f)
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Text(text = env.emoji, fontSize = 28.sp)
        Text(
            text = env.displayName,
            style = bungee(10),
            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.6f),
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
        if (isLocked) {
            Text(text = "🔒", fontSize = 10.sp)
        }
    }
}

@Composable
private fun FightButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val pressScale by animateFloatAsState(
        targetValue = if (pressed) 0.97f else 1f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "fightPress",
    )

    Box(
        modifier = modifier
            .scale(pressScale)
            .fillMaxWidth()
            .height(64.dp)
            .shadow(12.dp, RoundedCornerShape(22.dp), spotColor = BrandTheme.orange.copy(alpha = 0.6f))
            .clip(RoundedCornerShape(22.dp))
            .background(Brush.horizontalGradient(listOf(BrandTheme.orange, BrandTheme.yellow)))
            .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(22.dp))
            .clickable(interactionSource = interaction, indication = null, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = "⚔️", fontSize = 22.sp)
            Spacer(Modifier.width(12.dp))
            Text(
                text = "LET'S FIGHT!",
                style = bungee(20),
                color = Color.White,
            )
            Spacer(Modifier.width(12.dp))
            Text(text = "⚔️", fontSize = 22.sp)
        }
    }
}
