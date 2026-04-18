package com.whowouldin.whowouldwin.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.whowouldin.whowouldwin.data.Animals
import com.whowouldin.whowouldwin.model.Animal
import com.whowouldin.whowouldwin.model.AnimalCategory
import com.whowouldin.whowouldwin.ui.components.AnimalCard
import com.whowouldin.whowouldwin.ui.components.BackgroundStyle
import com.whowouldin.whowouldwin.ui.components.MegaButton
import com.whowouldin.whowouldwin.ui.components.MegaButtonColor
import com.whowouldin.whowouldwin.ui.components.PillButton
import com.whowouldin.whowouldwin.ui.components.ScreenBackground
import com.whowouldin.whowouldwin.ui.components.SectionHeader
import com.whowouldin.whowouldwin.ui.theme.BrandTheme
import com.whowouldin.whowouldwin.ui.theme.bungee
import com.whowouldin.whowouldwin.vm.AnimalPickerViewModel

/**
 * Ports iOS `Views/AnimalPickerView.swift`.
 *
 * Minimum-viable port: search, category pills, grid of animals, two fighter
 * slots, FIGHT button.  Custom-creature fetch + locked-character unlock flow
 * are plumbed via the VM; the unlock-sheet presentation is a TODO.
 */
@Composable
fun AnimalPickerScreen(
    onBack: () -> Unit,
    onFight: (Animal, Animal) -> Unit,
    modifier: Modifier = Modifier,
    vm: AnimalPickerViewModel = viewModel(),
) {
    val state by vm.state.collectAsStateWithLifecycle()

    val filtered = remember(state) { vm.filteredAnimals(state) }

    ScreenBackground(style = BackgroundStyle.HOME, modifier = modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
            // Header
            Row(
                Modifier.fillMaxWidth().padding(top = 8.dp, bottom = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                }
                Text(
                    "PICK YOUR FIGHTERS",
                    style = bungee(20).copy(color = BrandTheme.yellow),
                    modifier = Modifier.weight(1f),
                )
            }

            // Search field
            BasicTextField(
                value = state.searchText,
                onValueChange = vm::onSearchTextChanged,
                textStyle = bungee(16).copy(color = Color.White),
                cursorBrush = SolidColor(BrandTheme.yellow),
                singleLine = true,
                keyboardOptions = KeyboardOptions.Default,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
                    .border(1.dp, Color.White.copy(alpha = 0.2f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                decorationBox = { inner ->
                    Box {
                        if (state.searchText.isEmpty()) {
                            Text(
                                "Search or create ANY creature...",
                                style = bungee(14).copy(color = Color.White.copy(alpha = 0.4f)),
                            )
                        }
                        inner()
                    }
                },
            )

            Spacer(Modifier.height(12.dp))

            // Category pills
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(horizontal = 4.dp),
            ) {
                items(AnimalCategory.entries.toList()) { cat ->
                    PillButton(
                        text = cat.name,
                        selected = state.selectedCategory == cat,
                        accent = BrandTheme.categoryAccent(cat),
                        onClick = { vm.selectCategory(cat) },
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            // Fighter slot strip
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                FighterSlot(state.fighter1, onClear = { vm.clearSlot(1) }, modifier = Modifier.weight(1f))
                Text("VS", style = bungee(24).copy(color = BrandTheme.yellow), modifier = Modifier.align(Alignment.CenterVertically))
                FighterSlot(state.fighter2, onClear = { vm.clearSlot(2) }, modifier = Modifier.weight(1f))
            }

            Spacer(Modifier.height(12.dp))

            SectionHeader(text = "CHOOSE")

            // Grid
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.weight(1f).fillMaxWidth().padding(vertical = 8.dp),
            ) {
                items(filtered, key = { it.id }) { animal ->
                    val isSel = state.fighter1?.id == animal.id || state.fighter2?.id == animal.id
                    AnimalCard(
                        animal = animal,
                        isSelected = isSel,
                        isDisabled = false,
                        onTap = { vm.toggleAnimal(animal) },
                    )
                }
            }

            // FIGHT button
            if (state.canFight) {
                MegaButton(
                    text = "⚔  FIGHT!  ⚔",
                    color = MegaButtonColor.ORANGE,
                    onClick = { onFight(state.fighter1!!, state.fighter2!!) },
                    height = 68,
                    fontSize = 22,
                    modifier = Modifier.padding(bottom = 20.dp),
                )
            } else {
                Spacer(Modifier.height(88.dp))
            }
        }
    }
}

@Composable
private fun FighterSlot(
    animal: Animal?,
    onClear: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .height(100.dp)
            .background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(14.dp))
            .border(
                width = 2.dp,
                color = if (animal != null) BrandTheme.yellow.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.2f),
                shape = RoundedCornerShape(14.dp),
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (animal == null) {
            Text("?", style = bungee(40).copy(color = Color.White.copy(alpha = 0.25f)))
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(animal.emoji, style = bungee(36))
                Text(animal.name, style = bungee(11).copy(color = Color.White), maxLines = 1)
            }
        }
    }
}
