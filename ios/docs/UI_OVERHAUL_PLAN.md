# Animal vs Animal — UI Overhaul Design Document

## Vision

Transform the app from "vibe-coded prototype" to "looks like Supercell made it." Every screen should feel tactile, bold, and juicy — like Clash Royale or Brawl Stars. The core techniques: **gradient fills, 3D raised buttons, text outlines, layered card borders, warm surfaces, spring animations, and consistent depth via shadows.**

Zero functionality changes. Every button, flow, API call, and navigation path stays identical.

---

## 1. Color Palette

### Primary Brand Colors
| Role | Name | Hex | Usage |
|---|---|---|---|
| Brand Orange | `heroOrange` | #FF6B35 | Primary CTAs, brand accent |
| Brand Yellow | `heroYellow` | #FFD60A | CTA gradients, coin/gold, highlights |
| Battle Red | `battleRed` | #EF4444 | VS badges, damage, alerts |
| Epic Purple | `epicPurple` | #9333EA | Premium/special elements |
| Victory Green | `victoryGreen` | #22C55E | Confirm, success, "GO" actions |

### Background Colors (Dark Mode Primary)
| Role | Name | Hex | Usage |
|---|---|---|---|
| Deep BG | `bgDeepNavy` | #0A0E1A | Deepest background layer |
| Mid BG | `bgMidNavy` | #111B33 | Mid-depth panels |
| Surface | `bgSurface` | #1A2744 | Card and panel backgrounds |
| Warm Card | `bgCard` | #1E2D4F | Elevated card surfaces |

### Background Colors (Light Mode)
| Role | Name | Hex | Usage |
|---|---|---|---|
| Deep BG | `bgDeepCream` | #FFF8ED | Warm cream base |
| Mid BG | `bgMidCream` | #FEF3C7 | Parchment-like panels |
| Surface | `bgSurfaceLight` | #FFFDF5 | Card surfaces |
| Card | `bgCardLight` | #FFFFFF | Elevated cards (with warm border) |

### Text Colors
| Role | Hex (Dark) | Hex (Light) | Notes |
|---|---|---|---|
| Primary | #F8FAFC | #1E293B | Never pure white or pure black |
| Secondary | #94A3B8 | #64748B | Descriptions, subtitles |
| Tertiary | #64748B | #94A3B8 | Captions, metadata |

### Accent/State Colors
| Role | Name | Hex |
|---|---|---|
| Fighter 1 | `fighter1` | #FF6B35 (orange) |
| Fighter 2 | `fighter2` | #00D4D4 (cyan) |
| Gold/Coin | `coinGold` | #FFD700 |
| Locked/Disabled | `locked` | #4A5568 |
| Success | `success` | #22C55E |
| Warning | `warning` | #F59E0B |

### Category Accents (unchanged logic, enriched gradients)
Each category keeps its existing accent but gains a richer 3-stop gradient for card backgrounds:
- **Land**: #D4622A → #C2571F → #8B3A10
- **Sea**: #1B87CC → #1574B0 → #0D4F7A
- **Air**: #5DADE2 → #4A9BD1 → #2D7AB0
- **Insect**: #38A169 → #2D8A56 → #1E6A3E
- **Fantasy**: #C77DFF → #A855F7 → #7C3AED
- **Prehistoric**: #C8820A → #A66D08 → #7A5006
- **Mythic**: #C0A000 → #A68C00 → #7A6700
- **Olympus**: #FFD700 → #F5C400 → #CC9E00

---

## 2. Typography Plan

### Font Hierarchy

**Headlines / Titles**: Keep PressStart2P for the main app title "ANIMAL VS ANIMAL" only — it's the brand identity. For all other headlines, switch to **SF Rounded Black** at large sizes. This gives Supercell's chunky, readable feel without requiring an extra font embed.

**All UI Text**: SF Rounded at varying weights:
| Element | Font | Size | Weight | Extras |
|---|---|---|---|---|
| App Title | PressStart2P | 28-46pt | N/A | Keep existing pixel style |
| Screen Headers | SF Rounded | 28-32pt | .black | ALL CAPS, 2px dark outline |
| Section Titles | SF Rounded | 20-24pt | .bold | ALL CAPS, tracking +1.5 |
| Button Labels | SF Rounded | 18-22pt | .heavy | ALL CAPS, 1px outline |
| Card Titles | SF Rounded | 16-18pt | .bold | Title case |
| Body | SF Rounded | 15-16pt | .medium | Sentence case |
| Caption | SF Rounded | 12-13pt | .medium | Secondary color |

### Text Outline Technique (StrokedText)
All text over colored or gradient backgrounds gets a dark outline. Implementation:
- Layer the same `Text` 8 times at 1px offsets in all cardinal + diagonal directions with dark color
- Top layer: the actual text in its fill color
- Result: crisp, readable text on any background (the Supercell signature)

### Text Shadows
- Headlines: shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: 2)
- Button labels: shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: 1)
- Body text on dark BG: no shadow needed (sufficient contrast)

---

## 3. Button Style Guide

### GameButton (Primary CTA)
The signature Supercell-style button. Every important action uses this.

**Visual stack (top to bottom):**
1. **Inner highlight**: Top-half gradient overlay, white at 15% → transparent
2. **Main fill**: LinearGradient of the button's color (lighter top → darker bottom)
3. **Bottom edge border**: 4px band in a 30% darker shade of the fill color
4. **Drop shadow**: (0, 4px), blur 10px, black at 25%

**Sizing:**
- Large CTA (LET'S BATTLE): 60pt tall, full width minus 40pt padding
- Medium (in-sheet actions): 52pt tall
- Small (secondary): 44pt tall

**Color variants:**
| Variant | Top | Bottom | Edge | Usage |
|---|---|---|---|---|
| Orange (primary) | #FF8C42 | #FF5722 | #CC3D0A | LET'S BATTLE, main CTAs |
| Green (confirm) | #4ADE80 | #22C55E | #15803D | LET'S FIGHT, confirm actions |
| Purple (premium) | #C084FC | #9333EA | #6B21A8 | Unlock pack, subscribe |
| Gold (coin) | #FDE047 | #EAB308 | #A16207 | Spend coins, earn actions |
| Red (destructive) | #FCA5A5 | #EF4444 | #B91C1C | Rare, destructive only |

**Press state:**
- Scale to 0.92x
- Y-offset +2px (button "pushes into" the screen)
- Bottom edge shrinks to 1px
- Spring animation: response 0.2, damping 0.5 (slight overshoot bounce)
- Haptic: `.medium` impact

**Disabled state:**
- Desaturated to grayscale
- Opacity 0.5
- No shadow
- No press animation

### SecondaryButton
For less prominent actions (Back, Close, Cancel).

- Outline-only style: 2px border in accent color, clear fill
- On press: fill fades in at 10% opacity, scale 0.95x
- Text color matches border color
- No bottom edge, no drop shadow

### IconButton
For toolbar actions (Settings gear, Help icon, Close X).

- Circle or rounded-rect background: bgCard color
- 2px border in cardBorder color
- Shadow: (0, 2px), blur 4px, black at 15%
- Icon: SF Symbol, 18-22pt
- Press: scale 0.9x, spring

---

## 4. Card / Panel Style Guide

### GameCard (Animal Selection Cards)
**Visual stack:**
1. **Content**: Emoji/image + name label
2. **Inner padding**: 8pt all sides
3. **Card fill**: Category gradient (3-stop, top-to-bottom)
4. **Inner border**: 1px, lighter shade of category color at 40%
5. **Outer border**: 2.5px, darker shade of category color
6. **Corner radius**: 14px
7. **Drop shadow**: (0, 3px), blur 6px, black at 20%

**States:**
- **Default**: Standard card appearance
- **Selected**: Outer border becomes 3px in the fighter's accent color (orange or cyan), add colored outer glow shadow (category accent at 40%, radius 8px)
- **Locked**: Overlay with dark scrim at 60%, lock icon centered, desaturated card beneath
- **Disabled**: Opacity 0.4, no shadow

### GamePanel (Modals, Result Screens, Info Boxes)
For unlock sheets, battle results, settings sections.

**Visual stack:**
1. **Content** with 16-20pt padding
2. **Panel fill**: bgCard (dark mode) or bgCardLight (light mode)
3. **Inner border**: 1px at white/10% (dark) or black/5% (light)
4. **Outer border**: 2px at accent color or divider color
5. **Corner radius**: 20px
6. **Drop shadow**: (0, 6px), blur 16px, black at 25%

**Optional header bar:**
- Accent-colored gradient strip across the top (within the panel's rounded rect)
- Title text in white with outline, centered in the strip
- Makes each panel feel like a "window" with a title bar

### InsetTray (Recessed Areas)
For progress bars, stat displays, and input fields.

- Background: 20% darker than parent card
- Inner shadow: inset, (0, 2px), blur 4px, black at 25%
- Border: 1px darker shade
- Corner radius: 8-10px
- Content sits inside this "carved in" area

---

## 5. Background Treatment

### Primary Screen Background (HomeView, PickerView)
**Layered composition:**
1. **Base gradient**: bgDeepNavy → bgMidNavy (top-left to bottom-right)
2. **Radial accent**: Subtle radial gradient at center, hero color at 8% opacity, fading to transparent. This creates a warm focal glow.
3. **Star field** (existing): Keep the SpreadStarField, but increase star count to 40-50 and add size variation (1-3pt). Add subtle twinkle animation (opacity pulse).
4. **Subtle pattern overlay**: Faint diagonal line pattern or hex grid at 3-5% opacity. Creates richness without distraction.

### Battle Screen Background
- Keep the existing environment-specific gradient system (it's already good)
- Enhance: add a vignette effect (darker edges) via radial gradient overlay
- Add subtle floating particles for each environment (dust, bubbles, snow — already partially done)

### Sheet/Modal Background
- Sheets get bgDeepNavy base with the same radial accent glow
- Dimmed background behind sheet: black at 60%
- Sheet itself has the GamePanel treatment

### Share Card Background
- Keep existing dark aesthetic (it's designed for sharing)
- No changes needed — already polished

---

## 6. Screen-by-Screen Redesign Notes

### HomeView
**Current**: Purple-ish gradient, pixel title, emoji animals, orange gradient battle button, pack journey strip at bottom.

**Changes:**
- **Background**: Switch to deeper navy gradient with center radial glow (warm amber at 5%). Keep star field.
- **Title "ANIMAL VS ANIMAL"**: Keep PressStart2P but add a subtle glow effect behind it (gold shadow at radius 20, 30% opacity). The title is the brand — preserve it.
- **Animal emojis**: Add a circular "frame" behind each — a gradient ring (category accent color) with inner shadow, making the emoji look like it's inside a medallion/badge.
- **VS badge**: Make it a 3D raised badge — gold gradient fill, dark outline, drop shadow. Current pulsing glow is good, keep it.
- **"LET'S BATTLE!" button**: Convert to GameButton (orange variant). Full width, 60pt tall, 3D raised with bottom edge. Add crossed-swords icon on each side.
- **CoinBadge**: Add a subtle 3D pill shape — bgCard fill with 2px border and inner shadow on the coin icon area. Keep gold coin visual.
- **PackJourneyNudge**: Restyle progress bars as InsetTray style (recessed, inner shadow). Category icons get small circular frames. The bar fills should be animated gradient (shimmer effect).
- **Settings/Help buttons**: Convert to IconButton style with circular bgCard background and border.
- **Streak badge**: Add a flame icon, use GamePanel style mini-badge with gradient border.

### AnimalPickerView
**Current**: Same purple gradient BG, search bar, category pills, fighter slots, animal grid.

**Changes:**
- **Background**: Match HomeView's navy + radial glow.
- **"PICK YOUR FIGHTERS" header**: SF Rounded Black, 26pt, ALL CAPS, white with 2px dark outline. Replace pixel font here.
- **Fighter slots**: Make them GamePanel-style recessed trays with inner shadow. When empty, show a pulsing dashed border. When filled, the animal sits in a glowing circle frame (fighter1 orange or fighter2 cyan accent).
- **VS badge between slots**: 3D raised gold badge (same as HomeView).
- **Search bar**: InsetTray style — recessed background, inner shadow, rounded. Mic button becomes an IconButton.
- **Category pills**: Convert to mini GameButtons — each pill gets a gradient fill (category color), 2px darker bottom edge, subtle shadow. Active pill: brighter, slight scale-up. Locked pill: grayscale with small lock icon overlay.
- **Animal cards**: Full GameCard treatment — category gradient background, layered borders, shadow. Selected state: glowing accent border + slight scale-up (1.04x). Locked: dark scrim + lock icon.
- **"Pick 2 animals to fight" CTA**: Convert to GameButton (green variant, disabled until 2 selected).
- **CoinBadge (top-right)**: Same treatment as HomeView.

### PreBattleSheet
**Current**: Modal sheet showing matchup, arena grid, arena effects toggle, fight button.

**Changes:**
- **Sheet container**: GamePanel treatment with rounded corners, border, shadow.
- **Fighter matchup display**: Each fighter in a circular frame (accent-colored gradient ring). VS badge between them (3D gold).
- **Arena grid**: Each arena cell becomes a mini GameCard — gradient fill matching environment colors, 2px border, shadow. Selected arena: bright accent border + glow.
- **Arena Effects toggle**: Custom styled — replace iOS default toggle with a game-style toggle (green ON / gray OFF, with a sliding knob that has a shadow and inner highlight).
- **"LET'S FIGHT!" button**: GameButton green variant, full width, 56pt tall.

### BattleView
**Current**: SpriteKit battle, health bars, result narration, action buttons.

**Changes:**
- **Health bars**: Convert to InsetTray style. The tray is recessed with inner shadow. The fill bar has a gradient (green→yellow→red as HP decreases). Add a bright "sheen" animation that sweeps across the bar when damage is dealt.
- **VS badge**: 3D raised gold badge (consistent with other screens).
- **Result panel**: Full GamePanel treatment — slides up from bottom with spring animation. Header strip in winner's accent color. Narration text in a recessed inner tray.
- **"Rematch" and "New Battle" buttons**: GameButton style. Rematch = orange variant. New Battle = green variant.
- **Share button**: IconButton style (circle, share icon).
- **Coin earn overlay**: Add a "burst" animation — coins fly up from center and settle into the CoinBadge position.
- **Arena badge**: If showing, use a small GamePanel mini-badge with the environment accent gradient.

### SettingsView
**Current**: Scrollable list with card-style sections, toggles, purchase buttons.

**Changes:**
- **Background**: Navy gradient, consistent with other screens.
- **Section cards**: Full GamePanel treatment — each section (Sound, Appearance, Packs, etc.) is a panel with optional accent header strip.
- **Section titles**: SF Rounded Bold, 18pt, ALL CAPS, tracking +1.5. Placed inside the colored header strip of the panel.
- **Toggle rows**: Keep layout, but style the toggle track as a mini InsetTray. Toggle knob gets shadow and highlight.
- **Purchase buttons**: Convert to GameButton — purple variant for pack unlocks, gold variant for premium. Add price badge as a small pill overlay.
- **"BEST VALUE" badge on annual plan**: Gold gradient pill with dark outline, positioned overlapping the button's top-right corner. Slight rotation (-5 degrees) for playfulness.
- **Restore Purchases**: Text button, secondary style.
- **About section**: Same panel treatment, version number in a recessed tray.

### Unlock Sheets (Fantasy, Prehistoric, Mythic, Olympus)
**Current**: Modal sheets with creature previews, progress bar, coin unlock, paid CTA.

**Changes (applied to all four):**
- **Sheet container**: Full GamePanel with accent-colored header strip (category color).
- **Pack title**: SF Rounded Black, 28pt, ALL CAPS, white with 2px outline in category dark color. Emoji icon gets a circular glowing frame.
- **Creature preview grid**: Each preview creature in a small GameCard with category gradient. Add a subtle shimmer animation sweeping across the locked creatures.
- **Progress bar section**: "FREE PATH" label in category accent. Progress bar uses InsetTray style with animated gradient fill. Battle count in bold.
- **CoinUnlockSection**: Styled as a sub-panel within the sheet. Coin cost displayed in gold GameButton. "Watch Ad" button in a distinct green GameButton.
- **"OR" divider**: Stylized — a horizontal line with "OR" in a small circular badge overlapping center.
- **Purchase CTA**: GameButton in category accent color. Price shown clearly.
- **Restore link**: Small text button at bottom.

### BattleShareCard
**Current**: Already polished dark-themed card for sharing.

**Changes:** Minimal — it's already well-designed for its purpose.
- Add the layered card border treatment (outer dark border + inner lighter border) to the overall card frame.
- Ensure fighter names use the outline text treatment.
- Keep everything else as-is.

---

## 7. Animation Enhancements

### Global Interaction Animations
- **Every button tap**: Scale 0.92x → 1.0x with spring(response: 0.2, dampingFraction: 0.5). This gives the signature Supercell "bounce-back."
- **Every button tap**: UIImpactFeedbackGenerator(.medium) fires simultaneously.
- **GameButton press**: Additionally shifts Y +2px and bottom edge shrinks (physical push feel).

### Screen Transitions
- **Screen entrance**: Content fades in + slides up 20pt with staggered delays (0.05s per element). Spring(response: 0.4, dampingFraction: 0.7).
- **Sheet presentation**: Slides up from bottom with spring(response: 0.35, dampingFraction: 0.75). Background dims to black at 60%.
- **Sheet dismissal**: Slides down with easeIn(0.25). Background fades back.

### Micro-Interactions
- **Coin earn**: Gold coin emoji scales from 0 → 1.2 → 1.0 at the earn location, then flies (arc path) to the CoinBadge position and disappears. CoinBadge number bumps with spring scale.
- **Pack progress bar fill**: Animated with spring(response: 0.5, dampingFraction: 0.8). A bright "sheen" highlight sweeps left-to-right after the fill completes.
- **Category pill selection**: Selected pill scales to 1.05x, others scale to 0.95x, all with spring(0.3, 0.7).
- **Animal card selection**: Selected card scales to 1.04x with a colored glow shadow that fades in. Deselection: scale back to 1.0x, glow fades out.

### Idle Animations
- **"LET'S BATTLE!" button**: Gentle scale pulse 1.0 → 1.02 → 1.0, 2s period, repeating. Shadow glow radius oscillates 10 → 16 → 10.
- **VS badge**: Slow rotation wobble ±3 degrees, 2s period. Scale pulse 1.0 → 1.08 → 1.0.
- **Star field**: Individual stars twinkle (opacity 0.3 → 0.8, randomized 1-3s period per star).
- **Gold coin in CoinBadge**: Subtle shine effect — a white highlight sweeps across every 4 seconds.

### Victory / Defeat
- **Winner announcement**: Text scales from 0 → 1.15 → 1.0 with spring. Stars burst outward from behind the text (particle effect). Screen edges flash the winner's accent color briefly.
- **Confetti**: Keep existing, but add variety — stars, circles, and small rectangles in category colors.
- **Defeat side**: Animal sprite tips over (existing), add a brief screen-shake (±3pt X offset for 0.3s).

---

## 8. Icon and Asset Guidance

### Emoji Treatment
Emojis are the app's character art — they need to feel like they belong in a premium game UI. Don't replace them (they're charming and recognizable), but **frame them**:

- **Animal cards**: Emoji sits inside a circular gradient frame (category accent color fading to darker shade). The circle has a 2px border (darker accent) and drop shadow. This makes each emoji feel like a collectible card portrait.
- **Fighter slots**: Selected animal emoji gets a larger frame with glowing ring (fighter accent color at 40% opacity, radius 8px blur). The glow pulses subtly.
- **Home screen hero emojis**: Large size (80pt), each in a circular frame that matches their category. A subtle floating animation (existing bob is good).

### Creature Asset Images (Paid Packs)
- These already have custom artwork. Frame them the same way as emojis for visual consistency.
- Add a faint "glow" behind creature assets using the category accent color at 20% opacity, blur 12px.

### Icons (SF Symbols)
- All SF Symbols used as buttons get the IconButton treatment (circle background, border, shadow).
- Navigation icons (back arrow, close X): 20pt, regular weight, white.
- Feature icons (gear, mic, lock): 18pt, semibold weight, white or accent color.
- Status icons (checkmark, star, fire): Use filled variants, in accent color.

### Special Badges
- **"NEW"**: Small pill badge, green gradient, white text with outline, rotated -5 degrees.
- **"BEST VALUE"**: Gold gradient pill, dark outline text, rotated -5 degrees, positioned overlapping parent element.
- **"LOCKED"**: Dark badge with lock icon, semi-transparent background.
- **Rarity-style indicators**: If we ever add rarity, use colored glow rings: gray (common), green (rare), blue (epic), purple (legendary), gold (mythic).

---

## 9. Implementation Plan (Components to Build)

### New shared files:
1. **`GameTheme.swift`** — Extends existing Theme.swift with new colors, gradients, and design tokens
2. **`GameButtonStyle.swift`** — The 3D raised button style with variants
3. **`GameCard.swift`** — Reusable card container with layered borders
4. **`GamePanel.swift`** — Modal/section panel with optional header strip
5. **`InsetTray.swift`** — Recessed area style for progress bars and inputs
6. **`StrokedText.swift`** — Text with dark outline for readability on any background
7. **`ScreenBackground.swift`** — Layered background (gradient + radial glow + stars + pattern)

### Modification order:
1. Build all shared components first (Theme, Button, Card, Panel, etc.)
2. Apply to HomeView (most visible screen)
3. Apply to AnimalPickerView
4. Apply to BattleView (careful — SpriteKit area untouched, only SwiftUI chrome)
5. Apply to PreBattleSheet
6. Apply to Unlock Sheets (all four)
7. Apply to SettingsView
8. Apply to BattleShareCard (minimal changes)
9. Final audit pass

---

## 10. What NOT to Change

- **PressStart2P on the main title** — It's the brand identity
- **Existing emoji usage** — Charming, recognizable, zero download cost
- **SpriteKit BattleScene internals** — The battle animation logic stays identical
- **Navigation structure** — All sheets, links, and flows stay the same
- **State management** — No ViewModels, ObservableObjects, or bindings touched
- **API calls** — BattleService, ClaudeService, AdManager untouched
- **Sound/haptics triggers** — AudioManager and HapticsService calls stay where they are
- **CarPlay** — Completely untouched
- **Data models** — Animal, BattleResult, BattleEnvironment unchanged
