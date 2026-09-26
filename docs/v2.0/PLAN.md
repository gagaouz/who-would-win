# Animal vs Animal 2.0 — implementation and TestFlight plan

Status: **implementation in progress.** Native retro UI/battles and all 143 catalog sprites are implemented; final visual validation, the on-device custom avatar kit, and release work remain. Hosted custom image generation is no longer a delivery requirement: the owner explicitly declined recurring image-service charges. See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for measured evidence and open gates.

Owner direction, September 26, 2026: the approved pixel-art prototype becomes the visual direction for the entire game. **2.0 is retro only. There is no classic-theme switch.** Existing functionality, progress, and purchases must carry forward. The final deliverable is a complete, processed 2.0 build available to the owner in TestFlight, ready for testing.

## 1. Release strategy and current evidence

Use two branches and separate Git worktrees in the same repository, rather than a second repository that would drift from maintenance fixes.

| Line | Location | Purpose |
| --- | --- | --- |
| `release/1.1.7` | `/Users/home/WWW/who-would-win` | Existing release line and all existing uncommitted work |
| `develop/2.0` | `/Users/home/WWW/who-would-win-v2.0` | Isolated retro development, prototype, plan, and tests |

The new worktree was created at `107bf7327f1c82e85282101e2294fb6f9ded3639`, the verified local and remote `release/1.1.7` tip. The last iOS release change is `4ef855e`; the later commits update the backend/admin dashboard. `main` is older, at `4a640e4`, so it is not the correct 2.0 starting point.

The original checkout has extensive unfinished Android changes and some marketing/web/tool changes. They remain in place. The 2.0 worktree includes committed baseline source, not an unreviewed copy of every dirty file. The approved prototype was copied explicitly. Compare-and-verify of the original Git status before and after worktree creation passed.

This creates local separation, not GitHub branch protection or a remote backup. Remote branch publication and deployment-trigger verification are an early implementation task. See [BRANCHING.md](BRANCHING.md).

**Baseline release findings at `107bf73`:** the iOS plist was 1.1.7/build 109 while `ios/project.yml` said 1.1.6/build 108; deployment tooling did not enforce tests, clean source, or both version fields, and the UI smoke test could contact production. P1 addresses these prerequisites. Current corrections and remaining verification belong in [TESTFLIGHT_RELEASE.md](TESTFLIGHT_RELEASE.md) and the release evidence ledger, rather than treating these historical findings as current build status.

## 2. What “complete 2.0” means

- Every currently reachable iOS feature remains reachable and works in the new presentation. A visually finished one-on-one battle alone is not a complete release.
- The home screen, creature picker, search/custom creation, arena picker, all battle modes, result screens, collections, achievements, shops, unlocks, settings, parent controls, leaderboards, and share cards use one coherent retro design.
- All **143 currently catalogued creatures** have approved retro artwork, tracked by stable animal ID. The **nine existing arenas** have compatible retro presentation. Automated manifest checks reconcile these counts to source so additions cannot silently be omitted.
- All supported custom-creature flows use a deterministic avatar assembled on the device from a bundled retro sprite kit. Recognizable animal/type words select appropriate recipes; unknown names receive a stable fantasy avatar. Artwork needs no API, paid runtime service, or persistent disk cache, and first-use artwork works offline. Exact semantic likeness is not guaranteed. Custom creatures remain available beyond the demo characters.
- One-on-one, quick match, rematch, next challenger, tournament rounds, and melee use actual existing results and rules. Current melee supports one to four animals per team.
- Progress, unlocked content, coins, collections, achievements, tournament state (including embedded custom-animal records), and purchase entitlements survive an upgrade from 1.1.7. Preserve custom creation and selection; do not claim an existing favorites or standalone saved-custom library, which the source audit did not find.
- The app works online and through its existing offline paths; unavailable artwork or narration cannot permanently strand a battle.
- iPhone and iPad layouts, orientation rules, accessibility, reduced motion, audio controls, and parent gates pass their acceptance cases.
- A signed archive from a known commit is uploaded, processed by Apple, assigned to an appropriate TestFlight group, and available to the owner to install. The build number, commit, verification evidence, and test instructions are delivered together.

“Uploaded,” “archive succeeded,” and “the prototype looks good” do not satisfy this definition. App Store public release is outside this milestone.

## 3. Product and visual decisions

**Use the prototype as an art-direction reference.** Keep the warm landscapes, bold readable creature silhouettes, restrained pixel effects, brief dramatic pauses, and clear victory payoff. Port the idea into native iOS; do not embed the browser demo as the finished game.

Create a native retro design system before converting screens: semantic colors, spacing, pixel borders, panels, buttons, selection states, focus/pressed/disabled/loading states, icon family, badges, motion, and sound. Include the app icon and launch/loading presentation in the art review; native system purchase/share/permission sheets retain their system behavior. Pixel lettering belongs in short display labels; long stories, facts, accessibility sizes, and parent information need a readable body face. Keep touch targets at least 44pt and test text scaling rather than shrinking labels to fit.

The presentation should feel playful and suitable for the existing audience. Defeat is tiredness or retreat, with no gore, graphic injuries, or intense flashing. Preserve useful real-animal reference photos in facts where they are current functionality; their surrounding interface becomes retro. Real-world reference content is not replaced with fictional facts.

Port all interaction states, including sold out, owned, locked, insufficient coins, unavailable ads, restore failure, microphone denial, empty collections, long custom names, and slow networks. The new look must not make an existing control disappear. New favorites, a persistent battle-history library, multiplayer, new roster categories, expanded team sizes, and economy/balance redesign are not added to this release plan. If presentation replay is exposed, it reuses the accepted result and grants no rewards; it is distinct from the existing rematch action.

## 4. Native technical approach

Proposed architecture: SwiftUI owns navigation, forms, settings, commerce, accessibility, and results; a SpriteKit scene owns the arena and sprite effects. A battle presentation coordinator connects the existing view models to that scene through a small explicit contract. Confirm the renderer choice with the first native vertical slice before broad conversion.

The existing battle resolver and result models remain authoritative. Current responses provide results and terminal health, not a verified per-hit combat log. Use illustrative exchanges, preserve the existing crowd-cheer interaction, and display supplied terminal health where the current product uses it. Do not show invented live numerical damage or ship the prototype's hardcoded winners, damage, or forced zero-health loser. The scene, result, share card, and bracket must agree on the final accepted outcome, including draws and fallback/tiebreak handling. A true animated HP simulation would require a separate validated event contract and is outside this visual release.

The coordinator must handle preparation, waiting for a result, playback, final reveal, interruption, cancellation, and failure. Neutral preparation may play while the result is pending. The decisive beat waits for the result. Presentation completion signals the existing model once. Backgrounding pauses presentation while preserving the session and any accepted result, with explicit recovery on return. Dismissal, rematch, navigation away, and committing a new arena invalidate/cancel the previous session. Neither path may deliver old results or duplicate coins, records, achievements, or wagers.

Use a shared sprite manifest with stable ID, version, source rectangles, logical size, facing, floor/contact anchor, movement archetype, frame timing, and fallback. Keep rendering isolated from persistence and reward logic. See [RETRO_ARCHITECTURE.md](RETRO_ARCHITECTURE.md) for detailed contracts and proposed components.

## 5. Art and custom-creature delivery

The sample atlas proves visual potential but requires measured crops and has some changing anatomy across poses. Production assets need actual grid discipline and visual QA; a generated sheet is not accepted solely because a file exists.

Start with a representative art/animation batch: a large quadruped, primate, small mammal, bird, fish/shark, snake/eel, arthropod, dinosaur, humanoid mythic creature, and unusual custom hybrid. Resolve outlines, palette, alpha fringes, anchors, scaling, flying/swimming movement, and crowded melee readability before producing the full roster.

Every catalog animal gets an approved ready sprite and a movement archetype. Use shared native motion for idle, approach, recoil, and celebration where appropriate. Add authored anticipation/attack/reaction frames by archetype or creature where a static-pose motion would look weak. Completion requires visibly appropriate motion for all archetypes, not a promise of unlimited bespoke animation for every possible input.

**Custom artwork policy — owner decision, September 26, 2026:** use an entirely on-device curated sprite kit. There is no recurring paid image service, image-provider integration, or new sprite backend dependency in the shipped custom flow. This replaces the earlier hosted-generation proposal.

1. Preserve validated custom names, existing content checks, random custom animal UUIDs, selection/unlock routes, coin/ad rules, battles, Next Challenger, tournament records, and sharing. Rendering does not introduce another charge or change the battle resolver.
2. Interpret recognizable animal/type words through explicit local recipes using bundled base sprites, palettes, and safe accessories. Select a stable fantasy recipe for unknown names. This is a retro avatar system, not an arbitrary text-to-image model; a literal or exact likeness is not guaranteed.
3. Derive appearance deterministically from normalized name and a versioned recipe policy, independently of random participant UUIDs. Equivalent names produce a stable appearance across selection, battle, result, sharing, and relaunch. Keep gameplay IDs and stored `Animal` fields compatible with 1.1.7; no custom-library or save-schema redesign is implied.
4. Render with bounded in-memory caching. Bundle the kit and recreate derived images when needed; no network request, persisted image, disk index, or background retry is required for correctness. First-time offline names work using the same recipe policy as online names.
5. Keep the intentional pencil preview while the name is uncommitted. After selection, use the composed avatar consistently everywhere. If an asset is unexpectedly missing, use the local fallback without blocking the fight. Avoid promising a unique image for every possible name or silently using old photo URLs.
6. Use the recipe's anatomy profile for restrained shared motion. Validate recognizable quadruped, bird, sea, serpent, arthropod and humanoid/fantasy cases; unknown inputs retain a suitable fantasy profile. Artwork never changes combat strength, results or rewards.
7. Test equivalent normalized names with different UUIDs, distinct unknown names, punctuation and length limits, blocked input, two-custom battles, custom versus catalog, share rendering, relaunch and active-bracket resume, cache eviction, and first-use offline creation. Assert no image-service calls and no duplicate custom-selection spend.

Build-time authoring of bundled sprites is separate from runtime artwork. The shipped app uses its included kit without provider credentials or per-image costs. See [CUSTOM_ART_SERVICE.md](CUSTOM_ART_SERVICE.md) for the current implementation/status record.

## 6. Work packages and completion gates

| Package | Depends on | Deliverable | Exit evidence |
| --- | --- | --- | --- |
| P0 — isolate and specify | — | 1.1.7 stays intact; 2.0 worktree, preserved prototype, source audit, plan | Separate branches/paths, original state comparison, scoped planning commit |
| P1 — reproducible baseline | P0 | Shared build/test schemes, version source of truth, independent build outputs, fixture-driven tests, API environment separation | Baseline builds; existing tests run; production calls excluded from routine tests; upgrade fixtures captured |
| P2 — design system and native slice | P1 | Retro components and a real native lion/gorilla/custom battle from existing result models | Runs on iPhone/iPad; art review; real result synchronization; cancellation/replay/reward tests; representative performance measurement |
| P3 — production art and custom avatar kit | P2 | Catalog manifest, nine arena assets, approved movement archetypes, bundled deterministic custom recipes | No missing catalog IDs; sample archetypes approved; recognized-name and unknown-name avatars stable across views/relaunch; cold offline creation and missing-asset tests pass |
| P4 — full UI conversion | P2 | All primary and secondary screens/states retro | Every row of feature inventory mapped to new screen and test; no unreachable feature; accessibility review |
| P5 — all game modes | P2, initial P3 | Quick/normal battles, next challenger, tournament progression, melee, results, sharing integrated with renderer | Deterministic outcome/reward tests, persisted interrupted tournament fixtures, 1v1 through 4v4 melee checks |
| P6 — compatibility and hardening | P3–P5 | Upgrade/data/commerce/network/accessibility/performance regression pass | Full parity matrix green; no critical/high-severity open defects; asset and build validators pass |
| P7 — release candidate and TestFlight | P6 | Signed 2.0 release candidate, beta notes, processed and installable owner build | Exact source/archive identity, Apple processing success, owner group access, physical-device smoke evidence, final handoff |

P3 and P4 can run in parallel after the style/native spike is accepted. P5 can proceed against a small approved asset subset while the rest of the roster is produced. P6 and P7 cannot be bypassed to make an earlier demo appear complete. Keep commits small enough that regressions can be bisected and individual changes can be reverted.

## 7. Functionality preservation and data protection

[FEATURE_PARITY.md](FEATURE_PARITY.md) is the source-audited checklist. Each feature gets a source reference, new screen/component mapping, test case, and pass evidence. “Not tested” must remain explicit until executed. A rewritten appearance is never evidence that underlying behavior was preserved.

Keep stable animal IDs, existing persistence keys and product identifiers unless a separately tested migration is unavoidable. Preserve current earned/coin/purchased permanent unlock semantics and revocable subscription semantics. Do not reset progress to simplify a fresh-looking home screen. Record representative before/after values for upgrades, not just successful launch.

Required upgrade fixtures include: brand-new user; free user with coins and recorded custom-creature usage; earned and coin-unlocked content; each purchased entitlement and restored entitlement; expired/current subscriber; collected stickers/trophies; a tournament with custom entrants mid-round, awaiting settlement, and after reward settlement; cloud-synced state; and offline launch after upgrade. Never erase the owner's device or simulator data as a test shortcut.

Audit existing cloud merge behavior rather than assuming it is complete. Current concerns include maximum-based coin merging, omitted keys, and permanent-unlock flags shared with purchase restoration. Test separate fresh/returning/cloud accounts and sandbox purchase state. Any necessary compatibility fix gets an isolated migration/logic change and regression tests, not an incidental UI refactor.

**A canonical TestFlight build with the same app ID replaces the installed 1.1.7 app on that device.** Worktrees protect source code, not device save data. Use a separate simulator/device and, if needed, a distinct development bundle with separate cloud/commerce configuration during development. Final upgrade testing uses the canonical bundle and preserved representative state. Do not assume downgrading is a safe recovery strategy.

## 8. Validation strategy

Use cheap deterministic tests throughout, then broaden at defined integration points.

- **Model/unit:** unchanged resolver outcomes and health, stable IDs, no duplicate rewards/records, tournament decoding and settlement, cloud merge fixtures, entitlement restoration, cache keys/validation, display preferences unrelated to removed theme choice, input moderation, reduced-motion behavior.
- **Contract/backend:** 1.1.7 battle requests and responses remain compatible; current authentication, quotas, idempotency, story safety, rankings, custom tracking, and fallback semantics remain intact. Custom artwork performs no backend/image-provider request. Use isolated battle-service fixtures and verify the local avatar path independently of backend availability.
- **UI:** every routed flow in the feature matrix, including lock/unlock, purchase cancel/fail/restore, denied permissions, nil/empty/error states, long labels, navigation during playback, rematch spamming, background/foreground, and returning from system settings.
- **Visual:** review every catalog sprite and arena; review meaningful screen states at supported phone/tablet sizes; contact sheets and missing-asset checks supplement but do not replace visual inspection. Check alpha edges, crisp scale, cut-off feet/wings/tails, overlap, simultaneous effects, and narration consistency.
- **Accessibility:** VoiceOver names/order and result announcements, touch targets, text scaling, contrast, independent sound/haptics settings, reduced motion with no shake/strobe, information not conveyed by color alone.
- **Performance:** establish the 1.1.7 baseline; target smooth 60fps on the agreed representative device, verify the oldest supported device behavior, and measure 4v4 load, resident texture memory, cold start, archive size, battery/thermal behavior, and at least 20 sequential battles for growing caches or leaked scenes. Report measured numbers; do not claim device performance from browser animation.
- **Upgrade:** install 1.1.7 with fixtures, upgrade in place, compare state, exercise purchases/cloud/tournament resume, and relaunch offline. Keep upgrade and fresh-install tests separate.
- **Release:** Release configuration and archive checks, entitlements/App Attest, pinned dependencies, real-device StoreKit/ads/Game Center/iCloud/speech/notification behavior as available, privacy manifest and metadata review, exact TestFlight build access.

The audited 1.1.7 baseline contained 13 unit test methods and one UI smoke test; that inventory was not proof of broad coverage. Use the current evidence ledger for executed 2.0 test counts and results. Add tests for high-risk behavior and failure paths; avoid testing trivial view styling mechanically.

## 9. Risk register and decisions that cannot be hand-waved

| Risk | Control / release decision |
| --- | --- |
| Generator reverts version/build | One maintained version source; checked generation diff; archive metadata validation |
| 1.1.7 fix omitted from 2.0 | Cherry-pick relevant fixes with origin SHA and regression case; maintain a forward-port ledger |
| Retro accidentally loses a screen/control | Complete feature inventory and route-by-route parity signoff |
| Animation winner disagrees with result | Result-driven timeline; terminal-state assertions; no prototype winner script |
| Closing/rematch causes duplicate rewards or stale callbacks | Cancellable coordinator, battle identity, exactly-once model settlement tests |
| Custom avatar fails to resemble an unusual name | Recognizable keyword/type recipes and a deterministic fantasy fallback; accurate avatar wording, curated silhouette review, local memory bounds, no recurring image-service charge |
| Melee becomes unreadable | Early 4v4 prototype, stable formations, restrained per-actor effects, phone test |
| Upgrade loses purchases or save data | Stable keys/IDs, in-place upgrade fixtures, sandbox/cloud isolation, explicit migrations only |
| Beta harms production backend | Separate staging; additive contracts; production branch/deploy controls verified before publishing |
| Fake confidence from simulator tests | Physical-device capabilities called out; unknown results stay unknown; evidence ledger |
| Apple processing/review/login delay | Check readiness early; internal owner testing where eligible; report actual processing/access state |

Do not promise a release date until P1 and the P2/P3 anatomy/custom-avatar validation establish actual effort. The project is more than a skin swap; asset coverage, every mode, and upgrade safety are real workstreams.

## 10. Release and handoff

Follow [TESTFLIGHT_RELEASE.md](TESTFLIGHT_RELEASE.md). Marketing version becomes `2.0` only on the new line; choose a build number after inspecting App Store Connect, and keep a monotonic ledger across maintenance and 2.0 builds as an operational convention. Existing signing identity, bundle ID, products, and services remain attached to the original app for the final beta.

Freeze a release candidate commit, run required checks against that source, archive to a unique path, verify embedded version/build/entitlements, retain the archive and symbols, upload once, and monitor processing. Assign the processed build to the owner's eligible internal group or follow the external-beta review path if required. No public App Store submission is implied.

Final delivery must state: app/version/build, source commit, TestFlight group/access, verified availability, completed test matrix, any low-severity limitations, and where to send feedback. Include a short owner test route covering custom creation, a normal fight, quick/next challenger, tournament, melee, collections, settings, and upgrade state. No placeholder screens or known critical/high-severity regressions are acceptable.

This plan provides controls to catch errors; it is not a guarantee of zero defects. The completion claim will be based on the delivered build and test evidence.
