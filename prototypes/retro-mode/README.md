# Retro mode: playable concept

A standalone, dependency-free animation study for Animal vs Animal. Production iOS, Android, and backend code are untouched.

## Open

From this directory, run `python3 -m http.server 8769 --bind 127.0.0.1`, then visit <http://127.0.0.1:8769>.

Choose **Lion vs Gorilla** or **Mossback vs Lion**, then play the short battle. Sound is opt-in. Slow motion helps inspect the transitions, and the sprite drawer displays the four generated poses. Reduce motion follows the system preference and can also be enabled manually.

## What this demonstrates

- Three recognizable creatures in a shared retro art direction, including an invented turtle-dragon.
- Four authored poses per creature: ready, anticipation, attack, recoil.
- A low-resolution canvas with nearest-neighbor rendering, short lunges, contact effects, hit pauses, dust, and a celebratory finish.
- Shared animation timing applied to two different matchups.

The battles, energy bars, and winners are scripted illustration data. This does not call the app's battle resolver, generate new custom animals, or spend credits. It is a browser prototype, not an integrated native feature.

## Assessment

Worth pursuing as an optional mode. The sample art is readable and the scene supports much more specific movement than the current bobbing portraits. The animation implementation is straightforward; a dependable art pipeline is the larger task.

The generated atlas has real transparency and recognizable identity across poses, but is not a perfect production sprite sheet. It misses the requested grid boundaries, varies character anatomy and scale slightly between frames, and contains fine texture beyond a strict historical pixel palette. `RETRO_FRAMES` records measured crops, and rendering uses one consistent scale and ground baseline. A production pass would standardize silhouettes, palette, anchors, and grid alignment.

For an initial native release, start with a small curated roster and a common ready/lunge/recoil vocabulary. Custom animals can initially use one generated and cached side-view sprite with shared motion. Full bespoke multi-pose custom sheets need further testing across flying, swimming, many-legged, and unusually shaped creatures.

## Integration path

1. Introduce an optional persisted display preference while preserving the existing app appearance.
2. Replace the battle presentation in `ios/WhoWouldWin/Views/KidsBattleView.swift` with the retro scene. Signal `BattleViewModel.animationDidComplete()` at actual animation completion rather than the existing fixed six-second timer.
3. Use the actual battle result to select the final beat and winner. Continue neutral exchanges or idle while narration/result is loading; do not reveal a scripted winner.
4. Keep a shared sprite manifest with crop rectangles, facing direction, pixel dimensions, and ground anchors for iOS and Android.
5. Add a separate custom-sprite generation/cache path, keyed by normalized creature description and art-style version. Existing custom art resolves photos or cartoon URLs and cannot provide consistent pixel animation automatically.
6. Validate native performance, reduced motion, memory use, and result timing before replacing the prototype with a product feature.

## Files

- `index.html`, `style.css`, `ui.js`: prototype controls and presentation.
- `battle.js`: deterministic canvas scene, timing, particles, and optional synthesized sound.
- `assets/sprites.png`: unchanged generated source atlas.
- `assets/GENERATION.md`: full prompt and generation provenance (built-in image generation tool).
- Fonts are copied from the app's existing bundled assets.

The generated artwork and engine are reusable starting points. No new service or dependency is required to run this local preview.

## Verification

JavaScript syntax checks and an engine state smoke check passed. Browser checks covered both matchup results, replay/reset, switching matchup, slow motion, reduced motion, sound toggle, the pose inspector, and a 390px phone viewport without horizontal overflow. A terrain repaint issue found during animation review was fixed. `preview-desktop.jpg` and `preview-mobile.jpg` preserve the final ready state.
