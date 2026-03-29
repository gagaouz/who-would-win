# Who Would Win? — iOS App

A retro pixel-art iOS app where kids pick two animals and watch them battle it out. The app calls a backend API to generate AI-powered battle narration and fun facts, with an offline fallback so it always works.

---

## What You Need

- A Mac running macOS 13 (Ventura) or later
- **Xcode** — download free from the [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835)
- An **Apple ID** (free — you do not need a paid developer account to run on the simulator)
- A paid **Apple Developer account** ($99/year) only if you want to install on a real device

---

## Step-by-Step Setup

### 1. Open Xcode and Create the Project

1. Launch Xcode
2. On the welcome screen, choose **"Create a new Xcode project"**
3. Select the **iOS** tab at the top, then choose **App**, and click **Next**
4. Fill in the project options:
   - **Product Name:** `WhoWouldWin`
   - **Team:** Select your Apple ID (sign in via Xcode > Settings > Accounts if needed)
   - **Organization Identifier:** e.g. `com.yourname` (any reverse-domain string)
   - **Bundle Identifier:** will auto-fill as `com.yourname.WhoWouldWin`
   - **Interface:** `SwiftUI`
   - **Language:** `Swift`
   - Uncheck **"Include Tests"** for now (you'll add the test file manually)
5. Click **Next**, choose a save location, and click **Create**

### 2. Set the Minimum iOS Deployment Target

1. Click your project name at the top of the **Project Navigator** (left sidebar)
2. Select the **WhoWouldWin** target (not the project)
3. Under the **General** tab, find **"Minimum Deployments"**
4. Set iOS to **16.0**

### 3. Add the Swift Source Files

The source files are organized in subfolders. Add them to Xcode by:

1. In the **Project Navigator**, right-click the **WhoWouldWin** group folder
2. Choose **"Add Files to 'WhoWouldWin'..."**
3. Navigate to the `ios/WhoWouldWin/` directory and select all the Swift files, keeping **"Create groups"** selected
4. Make sure **"Add to targets: WhoWouldWin"** is checked, then click **Add**

The folder structure to replicate:

```
WhoWouldWin/
  Views/
    Components/
      PixelText.swift
      RetroButton.swift
      AnimalCard.swift
    HomeView.swift
    AnimalPickerView.swift
    BattleView.swift
  ViewModels/
    AnimalPickerViewModel.swift
    BattleViewModel.swift
  Models/
    Animal.swift
    BattleResult.swift
  SpriteKit/
    BattleScene.swift
    AnimalSprite.swift
    PixelExplosion.swift
  Audio/
    AudioManager.swift
  AppConfig.swift
  WhoWouldWinApp.swift
```

### 4. Add the Press Start 2P Font

This app uses the **Press Start 2P** retro pixel font from Google Fonts.

1. Download the font from [fonts.google.com](https://fonts.google.com/specimen/Press+Start+2P) — click **"Download family"**
2. Unzip and locate `PressStart2P-Regular.ttf`
3. Drag the `.ttf` file into your Xcode project (into the **WhoWouldWin** group)
4. Make sure **"Add to targets: WhoWouldWin"** is checked when prompted
5. Open **Info.plist** and add a new key:
   - Key: `Fonts provided by application`  (raw key: `UIAppFonts`)
   - Type: `Array`
   - Add one item (String): `PressStart2P-Regular.ttf`

### 5. Update the Backend URL

Open `AppConfig.swift` and replace the placeholder URL with your deployed backend address:

```swift
static let backendURL = "https://your-backend-url.com"
```

### 6. Add the Asset Colors

In **Assets.xcassets**, add the following named colors so the app's color references resolve:

| Name            | Hex Value   |
|-----------------|-------------|
| RetroBlack      | `#0D0D0D`   |
| RetroDeepBlue   | `#1a1a2e`   |
| RetroYellow     | `#FFD700`   |
| RetroRed        | `#FF3333`   |
| RetroGreen      | `#39FF14`   |
| RetroGray       | `#333333`   |
| RetroBorder     | `#555555`   |
| RetroText       | `#FFFFFF`   |
| RetroMuted      | `#AAAAAA`   |

To add a color: click the **+** button in Assets.xcassets, choose **"New Color Set"**, name it, then set the hex value in the Attributes Inspector.

### 7. Add the Test File (Optional)

1. In Xcode, go to **File > New > Target** and choose **Unit Testing Bundle**
2. Name it `WhoWouldWinTests`
3. Add `BattleServiceTests.swift` to that target

### 8. Build and Run

- Press **Cmd+R** (or the Play button) to build and run on the iOS Simulator
- The first build may take a minute while Xcode indexes files

---

## Running on a Real Device

To run on a physical iPhone or iPad:

1. Connect your device via USB
2. Select your device from the run destination dropdown (top center of Xcode)
3. You must have a valid **Team** selected under **Signing & Capabilities**
4. With a free Apple ID, you can sideload for 7 days before needing to re-sign

---

## Simulator vs Real Device

| Feature              | Simulator        | Real Device      |
|----------------------|------------------|------------------|
| SpriteKit animation  | Works            | Works (smoother) |
| Audio (8-bit sounds) | May be silent    | Works fully      |
| Haptic feedback      | Silent           | Works fully      |
| Performance          | Slightly slower  | Full speed       |
| Camera/Mic           | Not available    | Available        |

The app is fully usable on the simulator for development. Audio and haptics are best tested on a real device.

---

## Troubleshooting

- **Font not showing:** Double-check the exact filename in Info.plist matches the `.ttf` filename exactly (including case)
- **Build errors about missing types:** Make sure all Swift files are added to the `WhoWouldWin` target
- **SpriteKit blank screen:** Verify the `SpriteView` frame has non-zero dimensions; the scene size is set to match the view
- **API not responding:** Check `AppConfig.swift` has the correct backend URL and the server is running
