package com.whowouldin.whowouldwin

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.ui.Modifier
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.whowouldin.whowouldwin.ui.screens.AnimalPickerScreen
import com.whowouldin.whowouldwin.ui.screens.BattleScreen
import com.whowouldin.whowouldwin.ui.screens.HomeScreen
import com.whowouldin.whowouldwin.ui.theme.WhoWouldWinTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            WhoWouldWinTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { inner ->
                    AppNav(modifier = Modifier.padding(inner))
                }
            }
        }
    }
}

@androidx.compose.runtime.Composable
private fun AppNav(modifier: Modifier = Modifier) {
    val nav = rememberNavController()
    NavHost(navController = nav, startDestination = "home", modifier = modifier) {
        composable("home") {
            HomeScreen(
                onBattleClick = { nav.navigate("picker") },
                onTournamentClick = { nav.navigate("tournament") },
                onSettingsClick = { nav.navigate("settings") },
                onCoinBadgeClick = { /* TODO: coins hub sheet */ },
                onHelpClick = { /* TODO: help sheet */ },
            )
        }
        composable("picker") {
            AnimalPickerScreen(
                onBack = { nav.popBackStack() },
                onFight = { a, b ->
                    nav.navigate("battle/${Uri.encode(a.id)}/${Uri.encode(b.id)}")
                },
            )
        }
        composable(
            route = "battle/{id1}/{id2}",
            arguments = listOf(
                navArgument("id1") { type = NavType.StringType },
                navArgument("id2") { type = NavType.StringType },
            ),
        ) { entry ->
            val id1 = entry.arguments?.getString("id1").orEmpty()
            val id2 = entry.arguments?.getString("id2").orEmpty()
            val f1 = com.whowouldin.whowouldwin.data.Animals.all.firstOrNull { it.id == id1 }
            val f2 = com.whowouldin.whowouldwin.data.Animals.all.firstOrNull { it.id == id2 }
            if (f1 != null && f2 != null) {
                BattleScreen(
                    fighter1 = f1,
                    fighter2 = f2,
                    onBack = { nav.popBackStack("home", inclusive = false) },
                    onNewFighters = { nav.popBackStack("picker", inclusive = false) },
                )
            }
        }
        composable("tournament") {
            com.whowouldin.whowouldwin.ui.screens.tournament.TournamentRootScreen(
                onExit = { nav.popBackStack("home", inclusive = false) },
            )
        }
        composable("settings") {
            com.whowouldin.whowouldwin.ui.screens.SettingsScreen(
                onBack = { nav.popBackStack() },
            )
        }
    }
}
