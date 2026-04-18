# WhoWouldWin — Android

Kotlin + Jetpack Compose port of the iOS app, shipping to Google Play and Amazon Appstore.

## First-time setup

1. **Install Android Studio** (Giraffe or later — Jellyfish recommended)
   https://developer.android.com/studio
   The installer brings the JDK, Android SDK, and Gradle with it.

2. **Open this folder** in Android Studio: `File → Open → /Users/home/WWW/who-would-win/android`
   Wait for Gradle sync — first run downloads ~500 MB of dependencies.

3. **Build it.** `Build → Make Project` or `Cmd+F9`.

4. **Run it.** Pick any emulator (AVD Manager creates one in 2 minutes) and press ▶.
   You should see the "ANIMAL VS ANIMAL" scaffold screen on a dark background.

## Project layout

```
android/
├── app/
│   ├── build.gradle.kts           app config, deps
│   ├── proguard-rules.pro         R8/ProGuard keep rules
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/whowouldin/whowouldwin/
│       │   ├── MainActivity.kt         entry point
│       │   ├── WhoWouldWinApp.kt       Application class
│       │   ├── data/UserSettings.kt    DataStore (UserDefaults replacement)
│       │   ├── network/BattleApi.kt    Retrofit interface to Railway backend
│       │   ├── network/NetworkModule.kt OkHttp + Retrofit singleton
│       │   ├── ui/theme/               Compose theme (mirrors iOS Theme.swift)
│       │   └── ui/screens/             screens — HomeScreen.kt is a stub for now
│       └── res/                        XML resources, icons, strings
├── gradle/libs.versions.toml      version catalog (all lib versions)
├── build.gradle.kts               root
├── settings.gradle.kts
└── gradle.properties
```

## Mapping from iOS

| iOS (Swift)                           | Android (Kotlin)                       |
|---------------------------------------|----------------------------------------|
| `UserDefaults`                        | `DataStore` (`UserSettings.kt`)        |
| `URLSession` + `Codable`              | Retrofit + Moshi                       |
| `NSUbiquitousKeyValueStore` (iCloud)  | Google Drive App Folder (v1.1)         |
| `StoreKit` (IAP)                      | Google Play Billing v7                 |
| `GameKit` (Game Center)               | Play Games Services (v1.1 — cut from v1) |
| `HapticsService`                      | `Vibrator` / `HapticFeedback`          |
| SwiftUI `View`                        | Compose `@Composable`                  |
| `ObservableObject`                    | `ViewModel` + `StateFlow`              |
| Custom fonts in `Info.plist`          | `res/font/*.ttf` + `FontFamily`        |

## Build variants

- **debug** — `.debug` appId suffix, `-debug` version suffix, unsigned, no R8
- **release** — R8 minify + resource shrink, signed with your keystore (see SECURITY.md)

## Store submission

See `SUBMISSION_GUIDE.md` for the Play Console and Amazon Appstore step-by-step.

## Current status

Scaffold only. Screens still to port:
- [ ] HomeView → HomeScreen
- [ ] AnimalPickerView → AnimalPickerScreen
- [ ] BattleView → BattleScreen
- [ ] SettingsView → SettingsScreen
- [ ] Tournament flow
- [ ] IAP sheets (Fantasy/Prehistoric/Mythic/Olympus/Environments)
- [ ] Fonts bundled (Bungee, LilitaOne)
- [ ] Animal images bundled (copy from iOS Assets.xcassets)
- [ ] Sound assets
