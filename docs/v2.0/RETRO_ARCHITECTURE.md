# Retro 2.0 architecture

Audit date: 2026-09-26. This document records verified source findings and proposed implementation decisions. It does not report an implemented native renderer, completed asset library, passed device tests, or an uploaded TestFlight build.

## Product requirement

**Version 2.0 is retro throughout the game. There is no classic-theme option.** The current UI stays on the maintenance branch. This supersedes the initial idea of an optional retro mode.

Every existing feature, entitlement, saved value, and supported device flow remains available. Retro changes how the app looks and how battles are presented; it must not introduce a second set of battle rules or silently drop difficult creatures, custom fighters, team battles, or tournament flows. The final delivery is a complete iOS 2.0 build available through TestFlight, not the browser prototype or a native battle-only demo.

## Verified source findings

| Area | What is present now | Implication for 2.0 |
| --- | --- | --- |
| Catalog | `Animals.swift` declares **143 unique animals** in 10 categories; backend `creatures.json` also has 143 records. There are **118** bundled `creature_*.imageset` directories. | Audit all 143 IDs, including 25 core animals currently rendered as emoji. Existing illustration coverage is not a complete sprite inventory. |
| Arenas | `BattleEnvironment` defines **9**: grassland, ocean, sky, arctic, desert, jungle, volcano, night, storm. Arena effects can be disabled independently of the stored environment. | All nine need art and choreography support. A decorative background must never enable environmental modifiers. |
| Live battle view | Current production battle screens are SwiftUI cheer/build-up screens. The normal battle view schedules a **6-second animation gate**. There is no live `SKScene` implementation in the audited Swift sources; several SpriteKit comments are historical. | Introduce a real native renderer and replace the artificial timer with a presentation completion event. Do not assume an existing SpriteKit scene can simply be reskinned. |
| One-versus-one result | `BattleResult` contains winner ID or `draw`, narration, fun fact, terminal winner/loser health, optional `why`, and a client fallback flag. It has no attack log. | The final accepted result is the authority. Current data cannot justify invented damage numbers or a specific blow-by-blow simulation. |
| Result orchestration | Normal battles fetch concurrently with animation; quick battles omit the animation wait. Local fallback, custom-result sanity checks, and tournament draw breaking can modify the fetched answer before display. | Bind animation only to the **final accepted result**, after these transformations. Preserve quick mode. |
| Teams | iOS setup allows **1–4 fighters per team**, including asymmetric teams. The backend accepts up to six. `MeleeResult` has winning team, MVP and **team-level** terminal health, not individual health or elimination order. | Ship all currently offered 1–4 combinations. Do not expand the product cap just because the server accepts six, or manufacture individual eliminations. |
| Tournament | Brackets contain 4, 8 or 16 fighters. `TournamentManager` owns saved results, next-round construction, wagers, ledger and guarded payouts. The host advances after `onComplete(result)`. | Battle presentation must not directly mutate the bracket or award payouts. Resume and replay cannot trigger a second advancement. |
| Custom art | `AnimalImageService` resolves Wikipedia imagery, then a Pollinations URL. Its UIImage and URL caches are bounded in-memory dictionaries. `/api/animal` returns emoji/category/color, **not sprites**. | Runtime custom sprite generation is a new backend and persistence capability; the prototype's Mossback does not demonstrate it. |
| Identity | Custom IDs are random UUID-based strings; comments explicitly avoid turning child-entered names into durable identifiers. Current assets use `creature_<id>`. | Keep animal identity independent of sprite identity and appearance version. Do not replace custom UUIDs with name hashes. |
| Progress and rewards | Result presentation triggers battle/streak counts, coins, predictions, stickers, wins, achievements, sound, haptics and review prompts. Team coins/counts are currently awarded in result `onAppear`. | Retain every side effect but give completion an explicit idempotency boundary so a renderer replay or view reconstruction cannot award again. |
| Platform | `ios/project.yml` currently targets iOS 16.0, iPhone and iPad. Existing sound uses `SoundService`, user preferences and an ambient audio session. | Preserve the deployment target and device support unless separately changed; reuse audio/accessibility policy. |

Source references: [catalog](../../ios/WhoWouldWin/Data/Animals.swift), [backend catalog](../../backend/src/data/creatures.json), [environment model](../../ios/WhoWouldWin/Models/BattleEnvironment.swift#L5), [battle timer](../../ios/WhoWouldWin/Views/KidsBattleView.swift#L208), [battle flow](../../ios/WhoWouldWin/ViewModels/BattleViewModel.swift#L58), [result contract](../../ios/WhoWouldWin/Models/BattleResult.swift#L3), [team contract](../../ios/WhoWouldWin/Models/Melee.swift#L3), [team sizes](../../ios/WhoWouldWin/Views/Melee/MeleeSetupView.swift#L134), [tournament host](../../ios/WhoWouldWin/Views/Tournament/TournamentRootView.swift#L203), [payout guard](../../ios/WhoWouldWin/Services/TournamentManager.swift#L430), [custom service](../../ios/WhoWouldWin/Services/AnimalImageService.swift#L16), [animal endpoint](../../backend/src/routes/animal.ts#L19), [custom identity](../../ios/WhoWouldWin/ViewModels/AnimalPickerViewModel.swift#L7), [result side effects](../../ios/WhoWouldWin/Views/KidsBattleView.swift#L997), [team result side effects](../../ios/WhoWouldWin/Views/Melee/MeleeBattleView.swift#L31), [platform configuration](../../ios/project.yml), [sound service](../../ios/WhoWouldWin/Services/SoundService.swift#L24).

The 25 catalog IDs without a current bundled illustration are: `lion`, `tiger`, `grizzly_bear`, `wolf`, `elephant`, `rhinoceros`, `hippopotamus`, `gorilla`, `cheetah`, `crocodile`, `wolverine`, `honey_badger`, `giraffe`, `zebra`, `moose`, `boar`, `tarantula`, `scorpion`, `cobra`, `giant_squid`, `mantis_shrimp`, `barn_owl`, `crow`, `centipede`, `stag_beetle`. This was counted from the catalog and asset directories, not inferred from comments.

## Proposed native structure

Keep SwiftUI for navigation, text, accessible controls, sheets, purchase flows, facts, share cards, brackets and results. Introduce a focused **SpriteKit battle stage embedded in SwiftUI**. The browser canvas is visual reference material, not a WKWebView-based production game.

| Proposed component | Responsibility | Must not own |
| --- | --- | --- |
| `RetroDesign` | App-wide color, border, spacing, typography, panel and interaction tokens. Pixel display type for short headings; readable scalable body text. | Game rules, store entitlements. |
| `CreatureArtwork` | One SwiftUI entry point for catalog/custom portraits, icons, stickers and share-card imagery. Uses the idle frame and the same creature appearance as battle. | Network work during synchronous share rendering. |
| `SpriteAssetStore` actor | Manifest lookup, bundled/downloaded artifact loading, deduplicated requests, validation, disk storage and memory budgets. | Winners, HP, coin charging. |
| `CreatureRenderProfile` | Anatomy, locomotion, semantic poses, scale, anchors, contact points and supported effect origins. | Combat strength; rendering traits do not change resolver tiers. |
| `BattlePresentationSession` | Immutable match input and accepted outcome, session ID, animation seed/version, pinned asset versions and presentation status. | Re-resolving an accepted result. |
| `BattlePresentationCoordinator` | Cancellable lifecycle, asset readiness, waiting/playing/reveal/skip, one completion event, and pause/resume. | StoreKit, bracket mutation, reward math. |
| `BattleStoryboardBuilder` | Converts accepted result plus anatomy profiles into a bounded illustrative sequence. Supports solo, teams, draws and fast presentation. | Choosing a winner or inventing authoritative damage. |
| `RetroBattleScene` | Sprite/frame playback, anatomy-safe procedural motion, arena layers, shadows, gentle effects. | Backend calls or persistent rewards. |

Use a low logical resolution with integer-aligned positions and nearest-neighbor texture filtering. Fit the battle stage to the available iPhone/iPad area while leaving UI text native; do not pixelate an entire screenshot of the UI. Profile the simplest SpriteKit implementation before introducing custom Metal rendering.

The shared art entry point should replace the current separate ladders in `AnimalBubble`, `CreatureIcon`, `CreatureGlyph`, picker cards, result portraits and share cards. Otherwise a creature can look different in six screens. Current consolidation points are [KidsDesign.swift](../../ios/WhoWouldWin/Views/Components/KidsDesign.swift#L427) and [Animal.creatureAssetName](../../ios/WhoWouldWin/Models/Animal.swift#L24).

## Result synchronization and truthful presentation

1. **Create a new session for a new battle.** Capture ordered fighters, match type, environment, whether effects are enabled, and any tournament matchup ID. Scene recreation must retain that session.
2. **Prepare art and resolve the battle concurrently.** While waiting, show entrance/idle/cheering and non-decisive movement. Never celebrate, eliminate a fighter, or move numerical HP based on a guessed result.
3. **Accept exactly one final result.** Apply existing validation, local fallback and tournament tiebreaking first. Freeze the result snapshot. A late cloud response must not replace an accepted fallback after playback, rewards or bracket advancement.
4. **Build and play a result-bound story.** The final winner, drawing outcome, MVP, result text and any displayed terminal health all come from that snapshot. Use an animation seed for visual variation; it has no influence on the outcome.
5. **Finish once.** Skip, reduced motion, normal completion, background recovery and timeout recovery all converge on one presentation-completed event. Existing result/reward/tournament logic consumes the same snapshot.
6. **Distinguish replay from rematch.** Replay reuses the accepted result and awards nothing. Rematch creates a new battle session, preserving the selected arena rules. Next Challenger and a new tournament matchup also create new sessions.

### Health and narration

The existing health fields describe terminal dominance and are used in share cards and achievements. There is no per-hit simulation to replay. **For the initial production implementation, keep live numerical damage/HP out of illustrative choreography.** Preserve crowd cheering and show supplied terminal values wherever the existing product uses them. Do not drain the loser to zero: real results can leave positive health, and a draw needs its own ending.

If numerical HP changes during each hit are required, add a versioned, validated combat-event contract produced alongside the authoritative result, with the same contract implemented for offline resolution. Events must reference valid participant IDs and conserve the supplied terminal totals. This is a separate rules/data task, not something the renderer may infer or randomize. Additive fields must remain compatible with maintenance clients.

Use generic close/fast/powerful visual exchanges until the backend supplies structured supported actions; do not parse free-form narration into unvalidated attacks. The final flourish must agree with the accepted winner, while the text remains the service's accepted narration/`why`/fact.

For teams, keep every selected creature represented through visible roster slots and coordinated/tag-team beats. Highlight the supplied winning team and MVP. Do not invent individual KO order or individual HP from team health. Support 1v1, 1v4, 4v1 and 4v4 explicitly, rather than duplicating the two-fighter scene and shrinking everyone until unreadable.

Quick tournament mode must remain quick: use a short reveal or immediate result, not an unavoidable ten-second fight for each of fifteen matches. Tournament result recording and payout guards stay under `TournamentManager`.

### Existing integration risks to resolve at this boundary

- [BattleViewModel](../../ios/WhoWouldWin/ViewModels/BattleViewModel.swift#L120) currently gates on concurrent fetch and animation. Replace the six-second view timer with coordinator completion; do not add a second competing gate.
- [Tournament timeout rescue](../../ios/WhoWouldWin/Views/Tournament/KidsTournamentBattleView.swift#L130) currently fabricates a stat-based result directly in the view after 25 seconds and marks it offline. Route this through the existing result service/fallback policy and freeze acceptance; otherwise the rescue and late fetch can disagree.
- [Tournament draw breaking](../../ios/WhoWouldWin/ViewModels/BattleViewModel.swift#L390) and custom-result sanity checks can modify winner/health. Storyboards must use the post-validation result.
- [Melee result appearance](../../ios/WhoWouldWin/Views/Melee/MeleeBattleView.swift#L31) awards counts/coins from `onAppear`; the new presentation must not amplify that lifecycle weakness. Use a battle-session completion ledger/guard for side effects.
- Preserve the arena-effects-off invariant. A stored random tournament arena can be inert in quick mode; rendering it must not reactivate its combat modifiers. See [MeleeViewModel.statEnvironment](../../ios/WhoWouldWin/ViewModels/MeleeViewModel.swift#L28) and [OnDeviceResolver.envMod](../../ios/WhoWouldWin/Services/OnDeviceResolver.swift#L26).

## Art and animation coverage

Create a checked-in manifest covering **every one of the 143 catalog IDs**. The build-time coverage check compares against the real catalog rather than a second manually maintained count. At minimum each profile supports idle, anticipation, attack, reaction, recovery, victory and tired/draw behavior; authored frames and controlled procedural transforms may share poses where an artist has approved the result.

Use authored silhouettes and action poses for identity. Use procedural motion for foot planting, approach/retreat, gentle breathing, tail/wing secondary motion, anticipation, settle and effect timing. Do not stretch a static portrait into a universal attack. A four-pose prototype is a useful minimum experiment, not proof that all anatomy works.

Anatomy profiles need to cover quadrupeds, bipeds/humanoids, birds and other winged creatures, fish/marine mammals, serpents, arthropods, tentacled creatures, shell-bearing creatures, and fantasy hybrids. Custom inputs may also describe plant-like, object-like or amorphous creatures. Biological category alone is insufficient: prehistoric and pet categories both contain swimmers and fliers.

Each asset manifest records canvas size, frame rectangles, pivot/foot anchor, contact/effect anchors, facing direction, safe mirroring rules, per-pose timing, collision-free display bounds, profile ID, palette/style version and content checksum. These are visual bounds, not new combat hitboxes. Use a consistent logical pixel size and outline weight across assets. Normalize anchors during processing so poses do not jump or change scale when a new frame appears.

Author all nine arenas with readable ground/air/water staging, contrast behind fighters, restrained foreground layers and corresponding dust/splash/snow/leaf effects. Sky and ocean need different movement support from grassland. Arena art must not imply that an incompatible creature acquired a new power; an intentionally disadvantaged pairing still uses the accepted game result. Keep fights playful: reactions and yielding, no gore or death animation.

Every screen is part of the retro pass: home and onboarding, picker/search/voice/custom creation, arena and prebattle selection, solo and team setup/play/results, quick and full tournaments, brackets/wagers/champion, facts, stickers/trophies/hall of fame, coin shop/paywalls/unlocks, settings/grown-up controls, empty/loading/error states and share output. Native system sheets may keep their system appearance. No screen loses its content or action to make room for decoration.

## Custom creature pipeline

The custom example in the browser is an authored asset. Production needs a separately implemented pipeline:

1. On **committed custom selection**, preserve the existing content checks and access/unlock behavior. Do not generate on every search keystroke, charge coins twice, or make custom selection unavailable while art is pending.
2. Submit sanitized input through the app backend using the existing authenticated/request-identity approach. Keep image-provider credentials server-side. The backend allocates an opaque sprite artifact ID and deduplicates in-flight work.
3. Create an approved unique appearance and an anatomy profile. The release minimum is one validated custom sprite with anatomy-appropriate procedural motion; additional authored pose frames may be generated from the same appearance only when consistency and latency meet the acceptance gate. Process transparency, scale, padding, frame rectangles and pivots into a validated artifact. A single unverified generator sheet is not a production atlas.
4. Validate image dimensions/byte limits, decodeability, the poses required by the selected motion profile, bounds, ground registration and visible content. Reject/retry malformed artifacts and apply content checks to generated output. Built-in assets additionally receive human visual review; custom automation uses the same standards where machine-checkable. A profile using one source frame must still demonstrate appropriate ready, anticipation, attack, reaction and ending behavior through its approved motion.
5. Return an artifact manifest and immutable versioned asset URL. Cache on the server and device; all appearances of that saved custom fighter reuse the same artifact. Keep sprite identity separate from random battle participant ID.
6. Render a consistent anatomy-based **retro placeholder** while first generation is unavailable, with the real custom name and loading/retry state. A placeholder must not be presented as a completed unique likeness. Once ready, use the generated identity everywhere; pin it for a playing scene and apply updates at a safe boundary, avoiding mid-swing appearance changes.

The final 2.0 acceptance gate includes successful novel custom generations, reuse of cached customs, two-custom battles, custom versus catalog, server failure, cancellation, relaunch and offline behavior. A generic sprite forever assigned to all custom inputs does not satisfy the requirement.

Offline truth: all bundled catalog creatures and arenas can work without network access. Already generated/saved custom appearances should be available from pinned local artifacts. A never-generated custom cannot obtain a brand-new AI likeness offline; retain custom battle functionality with the clearly pending retro placeholder and queue/retry generation when connected. Do not claim arbitrary offline image generation unless an actual on-device generator is implemented and tested.

Preserve the existing privacy-oriented identity separation. Raw custom names must not become file paths, analytics keys, public artifact URLs or permanent cache identifiers. Use opaque IDs; any server deduplication of custom input needs an explicit bounded retention policy and must remain compatible with data erasure. These requirements follow the current [random custom-ID design](../../ios/WhoWouldWin/ViewModels/AnimalPickerViewModel.swift#L35) and [POST classification endpoint](../../backend/src/routes/animal.ts#L12).

## Cache, versioning, memory and lifecycle

- **Versions:** separate manifest schema, art style, individual artifact content, motion profile and storyboard versions. Pin versions in active sessions and saved replay metadata. A cosmetic art update must not change a creature ID, unlock state, stats or accepted result.
- **Storage:** bundle complete catalog/arena essentials. Store downloaded immutable files by artifact ID plus checksum. Keep a small durable index for saved custom identities. Pin saved/custom tournament dependencies where offline availability is promised; purge only unpinned derivative cache files. Never silently erase active custom art to satisfy an LRU limit.
- **Validation:** atomically install a fully verified artifact and manifest; discard partial downloads. Bound compressed bytes and decoded dimensions. Verify checksums before decoding and coalesce simultaneous requests for the same asset.
- **Memory:** preload only current fighters, required effects and the current arena; opportunistically prepare the next tournament match. Use measured decoded-byte costs, not an image-count limit. A 2048² RGBA page is about 16 MiB before other overhead, so loading all 143 atlases is unacceptable. Share texture resources between portrait and stage where practical; unload unused scene resources on departure/memory pressure.
- **Scene lifecycle:** own one elapsed-time clock per session. Pause/resume explicitly on app inactivity; cancel tasks/actions when dismissed. Invalidate old callback generations on rematch. An OS interruption may shorten presentation but cannot cause a second fetch, conflicting winner, duplicate reward or tournament advance.
- **Accessibility:** honor system Reduce Motion dynamically: no camera shake, parallax, repeated bobbing, flashing impacts or mandatory victory hopping. Use static pose transitions and/or immediate reveal with the same content. VoiceOver reads native participant names, progress/status and accepted result; expose cheering, skip and result actions as real controls. Retain Dynamic Type, contrast, sound, haptic and narration preferences. Do not shrink prose into a tiny pixel font.
- **Audio:** extend the existing sound service with a modest retro sound bank; respect the silent switch, sound toggle and narration. Avoid a separate scene audio session or concurrent victory fanfares from both scene and result view.

## Prototype shortcuts that must not ship

The prototype intentionally contains three fighters, manually specified crop boxes, a fixed savanna, fixed 9.7-second choreography, a `power` ordering that picks a winner, and fixed damage ending at zero. [battle.js](../../prototypes/retro-mode/battle.js#L9) is the evidence. Its Mossback is pre-generated and its HP is cosmetic. Those shortcuts prove visual direction only.

Replace every hardcoded outcome/HP/roster/arena restriction, manual atlas layout assumption and browser-only lifecycle with the native/result-bound design above. Do not reuse the canvas as a second rules engine. A generated sheet also needs registration, anatomy, palette and mobile-size review even when its single screenshot looks good.

## Acceptance gates and end state

| Gate | Required evidence before moving on |
| --- | --- |
| 1. Feature and data baseline | A route/action inventory for the current app; migration fixtures preserving coins, purchases, unlocks, streaks, predictions, stickers, achievements, preferences and an in-progress tournament. Capture existing online/offline resolver behavior. Retro-only requirement and all screen scope are explicit. |
| 2. Native visual slice | Real iPhone/iPad native scene with an actual accepted result, shared retro UI tokens, and several deliberately different anatomies. Review idle, anticipation, contact, reaction, recovery and ending at device size. No hardcoded winner/damage. |
| 3. Full art coverage | Catalog-driven check passes for 143 IDs; every ID has approved portrait and battle states. Nine arenas complete. Human contact-sheet and animated QA catch clipping, extra/missing limbs, pose drift, inconsistent scale/pixel size, mirroring mistakes and unreadable silhouettes. |
| 4. Custom production path | Unique novel customs generate, validate, cache and retain identity across views/relaunch. Existing saved customs work offline; first-time unavailable generation has truthful pending presentation. Verify no double charge, repeated generation per keystroke, permanent generic substitution or leaked raw-name identifiers. |
| 5. Functional parity | Solo, draws, rematch/new arena/Next Challenger, cheers/predictions, 1–4 team combinations, 4/8/16 tournaments, quick mode, wagers on/off, payouts, sharing, speech, rewards, achievements, unlocks, shops, parental settings and restoration all retain their behavior. Compare accepted result, animation winner, result screen, share card and bracket for exact agreement. |
| 6. Fault and lifecycle correctness | Slow response, offline, 5xx/rate limit, corrupted/missing atlas, late cloud answer after fallback, midbattle dismissal, background/foreground, memory warning, replay, rematch and repeated view appearance have tests. No hang, stale result, duplicate completion, coin reward or bracket advance. |
| 7. Performance and accessibility | Profile worst-case 4v4 and long tournament sessions on the oldest supported physical device available plus a current iPhone and iPad. Establish and record frame-time, peak decoded texture memory, steady-state memory and thermal/battery budgets from the native slice; reject unbounded growth or repeatable frame stalls. Target smooth 60 fps, with a measured stable 30 fps mode if required. VoiceOver, large text, Reduce Motion, sound-off and narration-on pass. Simulator screenshots alone do not satisfy this gate. |
| 8. TestFlight delivery | Complete native release build with version 2.0 and a valid new build number; archive/sign/validate; upload and wait for App Store Connect processing; confirm the intended TestFlight group can install it. Record build identity and install/test evidence. An archive, successful upload command or simulator build alone is not the end state. |

Implementation should progress through these gates on `develop/2.0` while the maintenance branch retains the prior UI. A partial catalog, battle-only reskin, disabled team/tournament/custom flow, or uploaded build that testers cannot install is not a completed 2.0 release.
