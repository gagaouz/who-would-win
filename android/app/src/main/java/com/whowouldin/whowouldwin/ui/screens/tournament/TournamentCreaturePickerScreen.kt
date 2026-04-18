package com.whowouldin.whowouldwin.ui.screens.tournament

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.whowouldin.whowouldwin.data.Animals
import com.whowouldin.whowouldwin.data.UserSettings
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalCategory
import com.whowouldin.whowouldwin.model.SelectionMode
import com.whowouldin.whowouldwin.ui.components.AnimalAvatar
import com.whowouldin.whowouldwin.ui.components.AnimalCard
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee

/**
 * Port of iOS TournamentCreaturePickerView. Simpler than iOS: no custom-creature
 * fetch integration yet — that flow lives in a separate spawned port task.
 */
@Composable
fun TournamentCreaturePickerScreen(
    targetCount: Int,
    mode: SelectionMode,
    onContinue: (List<Animal>) -> Unit,
    onBack: () -> Unit,
) {
    val ctx = LocalContext.current
    val settings = remember { UserSettings.instance(ctx) }
    var search by remember { mutableStateOf("") }
    var selectedCategory by remember { mutableStateOf(AnimalCategory.ALL) }
    val selected = remember { mutableStateListOf<Animal>() }

    val availableCategories: List<AnimalCategory> = buildList {
        addAll(listOf(AnimalCategory.ALL, AnimalCategory.LAND, AnimalCategory.SEA, AnimalCategory.AIR, AnimalCategory.INSECT))
        if (settings.isPrehistoricUnlocked) add(AnimalCategory.PREHISTORIC)
        if (settings.isFantasyUnlocked) add(AnimalCategory.FANTASY)
        if (settings.isMythicUnlocked) add(AnimalCategory.MYTHIC)
        if (settings.isOlympusUnlocked) add(AnimalCategory.OLYMPUS)
    }

    val unlocked = Animals.all.filter { a ->
        when (a.category) {
            AnimalCategory.ALL, AnimalCategory.LAND, AnimalCategory.SEA,
            AnimalCategory.AIR, AnimalCategory.INSECT -> true
            AnimalCategory.PREHISTORIC -> settings.isPrehistoricUnlocked
            AnimalCategory.FANTASY -> settings.isFantasyUnlocked
            AnimalCategory.MYTHIC -> settings.isMythicUnlocked
            AnimalCategory.OLYMPUS -> settings.isOlympusUnlocked
        }
    }

    val filtered = unlocked.filter { a ->
        (selectedCategory == AnimalCategory.ALL || a.category == selectedCategory) &&
            (search.isBlank() || a.name.lowercase().contains(search.trim().lowercase()))
    }

    val continueEnabled = when (mode) {
        SelectionMode.MANUAL -> selected.size == targetCount
        SelectionMode.HYBRID -> selected.size in 1 until targetCount
        SelectionMode.RANDOM -> false
    }

    fun toggle(a: Animal) {
        val idx = selected.indexOfFirst { it.id == a.id }
        if (idx >= 0) selected.removeAt(idx)
        else if (selected.size < targetCount) selected.add(a)
    }

    ScreenBackground(style = BackgroundStyle.BATTLE) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .background(Color.White.copy(alpha = 0.1f), CircleShape)
                        .clickable { onBack() },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White, modifier = Modifier.size(16.dp))
                }
                Spacer(Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        if (mode == SelectionMode.MANUAL) "PICK ALL $targetCount" else "PICK SOME",
                        style = bungee(18).copy(color = Color.White),
                    )
                    Text(
                        when (mode) {
                            SelectionMode.MANUAL -> "${selected.size} / $targetCount"
                            SelectionMode.HYBRID -> "${selected.size} picked — rest random"
                            SelectionMode.RANDOM -> ""
                        },
                        style = bungee(11).copy(color = Color.White.copy(alpha = 0.75f)),
                    )
                }
                Spacer(Modifier.weight(1f))
                Spacer(Modifier.size(36.dp))
            }

            // Search
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(14.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(14.dp))
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.Search, contentDescription = null, tint = Color.White.copy(alpha = 0.6f))
                Spacer(Modifier.width(8.dp))
                Box(Modifier.weight(1f)) {
                    if (search.isEmpty()) {
                        Text("Search or add any fighter…", style = bungee(14).copy(color = Color.White.copy(alpha = 0.45f)))
                    }
                    BasicTextField(
                        value = search,
                        onValueChange = { search = it },
                        singleLine = true,
                        textStyle = bungee(14).copy(color = Color.White),
                        cursorBrush = SolidColor(BrandTheme.gold),
                    )
                }
                if (search.isNotEmpty()) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "Clear",
                        tint = Color.White.copy(alpha = 0.5f),
                        modifier = Modifier.clickable { search = "" },
                    )
                }
            }

            // Category pills
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                availableCategories.forEach { cat ->
                    CategoryPill(cat = cat, isSelected = selectedCategory == cat) { selectedCategory = cat }
                }
            }

            // Selection strip
            if (selected.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    selected.forEach { a ->
                        Row(
                            modifier = Modifier
                                .background(BrandTheme.gold.copy(alpha = 0.35f), CircleShape)
                                .border(1.2.dp, BrandTheme.gold, CircleShape)
                                .clickable { toggle(a) }
                                .padding(vertical = 6.dp, horizontal = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            AnimalAvatar(animal = a, size = 20.dp, cornerRadius = 5.dp)
                            Text(a.name, style = bungee(12).copy(color = Color.White))
                            Icon(Icons.Filled.Close, contentDescription = "Remove", tint = Color.White.copy(alpha = 0.7f), modifier = Modifier.size(13.dp))
                        }
                    }
                }
            }

            // Grid
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 4.dp),
            ) {
                items(filtered, key = { it.id }) { animal ->
                    val isSel = selected.any { it.id == animal.id }
                    AnimalCard(
                        animal = animal,
                        isSelected = isSel,
                        isDisabled = !isSel && selected.size >= targetCount,
                        onTap = { toggle(animal) },
                    )
                }
            }

            // Continue
            MegaButton(
                text = if (mode == SelectionMode.MANUAL) "ROLL BRACKET (${selected.size}/$targetCount)" else "ROLL BRACKET",
                onClick = { if (continueEnabled) onContinue(selected.toList()) },
                color = if (continueEnabled) MegaButtonColor.ORANGE else MegaButtonColor.BLUE,
                height = 62,
                cornerRadius = 20,
                fontSize = 18,
                enabled = continueEnabled,
                modifier = Modifier.padding(bottom = 8.dp),
            )
        }
    }
}

@Composable
private fun CategoryPill(cat: AnimalCategory, isSelected: Boolean, onClick: () -> Unit) {
    val accent = BrandTheme.categoryAccent(cat)
    Row(
        modifier = Modifier
            .background(
                if (isSelected) accent.copy(alpha = 0.45f) else Color.White.copy(alpha = 0.08f),
                CircleShape,
            )
            .border(
                width = if (isSelected) 1.8.dp else 1.dp,
                color = if (isSelected) accent else Color.White.copy(alpha = 0.15f),
                shape = CircleShape,
            )
            .clickable { onClick() }
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Text(BrandTheme.categoryEmoji(cat), fontSize = 12.sp)
        Text(
            BrandTheme.categoryLabel(cat).uppercase(),
            style = bungee(11).copy(
                color = if (isSelected) Color.White else Color.White.copy(alpha = 0.6f),
                letterSpacing = 1.sp,
            ),
        )
    }
}
