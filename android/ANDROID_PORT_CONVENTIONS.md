# Android Port Conventions (for parallel agents)

All agents porting Swift → Kotlin must follow these conventions.

## Paths

- **iOS source**: `/Users/home/WWW/who-would-win/ios/WhoWouldWin/`
- **Android target**: `/Users/home/WWW/who-would-win/android/app/src/main/java/com/whowouldin/whowouldwin/`
- **Resources**: `/Users/home/WWW/who-would-win/android/app/src/main/res/`

## Package structure (already established)

```
com.whowouldin.whowouldwin
├── MainActivity.kt
├── WhoWouldWinApp.kt       — Application class
├── model/                  — data classes (Animal, BattleEnvironment, BattleResult, Tournament)
├── data/                   — UserSettings (DataStore), Animals.kt (roster)
├── network/                — BattleApi (Retrofit), NetworkModule (OkHttp)
├── service/                — CoinStore, HapticsService, ContentFilter, CheatState, AchievementTracker, AnimalImageService
├── ui/theme/               — BrandTheme, Type, Theme
├── ui/components/          — RetroButton, GamePanel, VSShield, CoinBadge, AnimalCard
├── ui/screens/             — HomeScreen, AnimalPickerScreen, BattleScreen, SettingsScreen
├── ui/screens/tournament/  — tournament flow views
├── ui/screens/unlock/      — Fantasy/Prehistoric/Mythic/Olympus unlock sheets
├── vm/                     — BattleViewModel, AnimalPickerViewModel, TournamentViewModel
```

## Types already defined (do not redefine)

`model/Animal.kt`:
- `data class Animal(id, name, emoji, category, pixelColor, size, isCustom, imageUrl)`
- `enum class AnimalCategory { ALL, LAND, SEA, AIR, INSECT, PREHISTORIC, FANTASY, MYTHIC, OLYMPUS }`
- `data class AnimalStats(speed, power, agility, defense)` with `companion.generate(animal[, env])`

`model/BattleEnvironment.kt`:
- `enum class BattleEnvironment { GRASSLAND, OCEAN, SKY, ARCTIC, DESERT, JUNGLE, VOLCANO, NIGHT, STORM }`
- Each env has: `displayName`, `emoji`, `tagline`, `tier: EnvTier`, `battleThreshold: Int?`, `bgTop: Color`, `bgBottom: Color`, `accentColor: Color`, `multiplier(category)`
- `enum class EnvTier { FREE, EARNED, PREMIUM }`

`model/BattleResult.kt`: `data class BattleResult(winner, narration, funFact, winnerHealthPercent, loserHealthPercent, isOfflineFallback)`

`model/Tournament.kt`: `BracketSize`, `SelectionMode`, `sealed class TournamentPhase`, `Matchup`, `Bracket`, `GrandChampionWager`, `MatchupWager`, `LedgerEntry`, `Tournament`, `object WagerMultipliers`

`ui/theme/`:
- `object BrandTheme` — colors, gradients, category helpers (see file)
- `bungee(size)`, `lilita(size)`, `display(size)`, `headline(size)`, `bodyFont(size)`, `labelFont(size)` — TextStyles
- `WhoWouldWinTheme { content }`
- `colorFromHex("#RRGGBB")` helper
- `BrandColors` (back-compat aliases)

`network/BattleApi.kt`: Retrofit interface for `/api/battle` and `/api/animal`. Base URL `https://api.animal-vs-animal.com/` via `NetworkModule.baseUrl`. There's also a `/api/battle/quick` endpoint used by tournament quick mode (add to the interface).

## Conventions

1. **iOS `UserDefaults` keys preserved verbatim** — e.g. `"pref.sound"`, `"iap.fantasy"`, `"stat.battles"`. Easier for future cloud-sync reconciliation.
2. **Coin / battle / streak constants** — must match iOS values exactly (see `Services/CoinStore.swift`, `Services/UserSettings.swift`).
3. **No Hilt / no DI framework** — app is small. Use a simple `ServiceLocator` or singleton pattern — mirror iOS `XxxService.shared`.
4. **ViewModels** use Jetpack `ViewModel` + `StateFlow` for observable state (maps to iOS `@Published`). Collect with `collectAsStateWithLifecycle()`.
5. **Navigation** uses Jetpack Navigation Compose (`NavHost`). Routes: `home`, `picker`, `battle`, `settings`, `tournament`, etc.
6. **Animations** — use Compose `animate*AsState`, `AnimatedVisibility`, `rememberInfiniteTransition` to match iOS spring/easeInOut/repeat animations. Do not skip animations — we want full fidelity.
7. **Fonts** — use `bungee(size)` for display titles (ANIMAL VS ANIMAL, VS, WINNER!) and `lilita(size)` for buttons, animal names, section headers. Body text uses `bodyFont(size)`.
8. **Haptics** — call `HapticsService.tap/medium/heavy/success/warning()` at the same moments iOS does.
9. **Sounds** — placeholder service `SoundService.play("name")` — sound assets will be copied in a separate pass.
10. **Copy strings verbatim** — fun fact strings, error messages, button labels must match iOS 1:1.
11. **Supercell-style 3D buttons**: top/mid/bot gradient + drop-shadow + press-down animation. See iOS `RetroButton.swift` MegaButtonStyle.

## What NOT to do

- Don't invent new features. 1:1 port only.
- Don't redefine types listed above.
- Don't skip polish animations — we want full fidelity.
- Don't add third-party UI libraries beyond `gradle/libs.versions.toml`.
- Don't create accounts, submit to stores, or modify signing — that's user work.

## Build versions already on the project

See `android/gradle/libs.versions.toml`. Compose BOM 2024.09.03, Material3 1.3.0,
Retrofit 2.11.0, Moshi 1.15.1, Billing 7.0.0, DataStore 1.1.1, Kotlin 2.0.20, AGP 8.6.1.
Add Navigation-Compose 2.8.x if not present when you need it.
