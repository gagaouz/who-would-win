# Animal vs Animal 2.0 — implementation and TestFlight plan

Status: **planning and isolation complete; product implementation has not started.**

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

**Known defects in release preparation:** the actual iOS plist is 1.1.7/build 109, but `ios/project.yml` still says 1.1.6/build 108. The generator must not be run before this is reconciled. Existing deployment tooling does not enforce tests, clean source, or both version fields. The current UI smoke test can contact production. These are prerequisites, not details to defer until upload.

## 2. What “complete 2.0” means

- Every currently reachable iOS feature remains reachable and works in the new presentation. A visually finished one-on-one battle alone is not a complete release.
- The home screen, creature picker, search/custom creation, arena picker, all battle modes, result screens, collections, achievements, shops, unlocks, settings, parent controls, leaderboards, and share cards use one coherent retro design.
- All **143 currently catalogued creatures** have approved retro artwork, tracked by stable animal ID. The **nine existing arenas** have compatible retro presentation. Automated manifest checks reconcile these counts to source so additions cannot silently be omitted.
- All supported custom-creature flows have a working pixel-art path, with caching, loading, retry, and offline behavior. Custom creatures are not removed or restricted to the three demo characters.
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

Custom generation is a separate workstream with its own acceptance gate:

1. Reuse the current validated custom-creature identity/description and child-safety checks.
2. Generate a consistent side-facing sprite in the approved style through a server-owned provider integration. No provider secret ships in the app.
3. Keep the existing custom animal UUIDs. Separately deduplicate artwork by normalized identity/description plus style/model version behind an opaque artifact ID; do not key reusable art solely by a new local UUID. Raw child-entered names must not become public filenames, artifact URLs, or indefinite analytics history. Define bounded retention and deletion behavior before service deployment.
4. Fetch asynchronously and deduplicate concurrent requests. Bound dimensions, file size, timeout, retries, storage, and provider usage. Use existing request authentication and rate limits appropriately; do not weaken production protections to make generation work.
5. Provide an immediate intentional retro placeholder while art loads. Existing custom creatures remain selectable and playable. Previously generated sprites remain available offline. Newly entered offline creatures use a clearly temporary silhouette with later retry; this is a failure state, not a shipped replacement for online generation.
6. Reuse shared motion for arbitrary anatomy. More elaborate custom pose generation can only enter this release after consistency and latency are proven; it must not become an endless prerequisite that prevents custom play.
7. Test several substantially different custom prompts, duplicate names/descriptions, denied/invalid input, punctuation, very long names, two simultaneous requests, timeout, restart, and cache invalidation.

Batch generation and any new hosted generation service need a concrete provider, usage estimate, and budget before paid production calls. There is no claim that the built-in prototype image tool is a production app API or that large-scale generation is free. Confirm relevant image-provider policies, retention, and app privacy disclosures before enabling the service.

## 6. Work packages and completion gates

| Package | Depends on | Deliverable | Exit evidence |
| --- | --- | --- | --- |
| P0 — isolate and specify | — | 1.1.7 stays intact; 2.0 worktree, preserved prototype, source audit, plan | Separate branches/paths, original state comparison, scoped planning commit |
| P1 — reproducible baseline | P0 | Shared build/test schemes, version source of truth, independent build outputs, fixture-driven tests, API environment separation | Baseline builds; existing tests run; production calls excluded from routine tests; upgrade fixtures captured |
| P2 — design system and native slice | P1 | Retro components and a real native lion/gorilla/custom battle from existing result models | Runs on iPhone/iPad; art review; real result synchronization; cancellation/replay/reward tests; representative performance measurement |
| P3 — production art and custom service | P2 | Catalog manifest, nine arena assets, approved movement archetypes, cached custom generation | No missing catalog IDs; sample archetypes approved before bulk production; online/offline/custom failure tests pass |
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
- **Contract/backend:** 1.1.7 requests and responses remain compatible after any new sprite endpoint is added; current authentication, quotas, idempotency, story safety, rankings, custom tracking, and fallback semantics remain intact. Use isolated data and provider fixtures, not paid/live calls for every test.
- **UI:** every routed flow in the feature matrix, including lock/unlock, purchase cancel/fail/restore, denied permissions, nil/empty/error states, long labels, navigation during playback, rematch spamming, background/foreground, and returning from system settings.
- **Visual:** review every catalog sprite and arena; review meaningful screen states at supported phone/tablet sizes; contact sheets and missing-asset checks supplement but do not replace visual inspection. Check alpha edges, crisp scale, cut-off feet/wings/tails, overlap, simultaneous effects, and narration consistency.
- **Accessibility:** VoiceOver names/order and result announcements, touch targets, text scaling, contrast, independent sound/haptics settings, reduced motion with no shake/strobe, information not conveyed by color alone.
- **Performance:** establish the 1.1.7 baseline; target smooth 60fps on the agreed representative device, verify the oldest supported device behavior, and measure 4v4 load, resident texture memory, cold start, archive size, battery/thermal behavior, and at least 20 sequential battles for growing caches or leaked scenes. Report measured numbers; do not claim device performance from browser animation.
- **Upgrade:** install 1.1.7 with fixtures, upgrade in place, compare state, exercise purchases/cloud/tournament resume, and relaunch offline. Keep upgrade and fresh-install tests separate.
- **Release:** Release configuration and archive checks, entitlements/App Attest, pinned dependencies, real-device StoreKit/ads/Game Center/iCloud/speech/notification behavior as available, privacy manifest and metadata review, exact TestFlight build access.

Current test inventory is small (13 unit test methods and one UI smoke test found in source), not proof of broad coverage. Existing checks must first be run and evaluated for meaningful assertions. Add tests for high-risk behavior and failure paths; avoid testing trivial view styling mechanically.

## 9. Risk register and decisions that cannot be hand-waved

| Risk | Control / release decision |
| --- | --- |
| Generator reverts version/build | One maintained version source; checked generation diff; archive metadata validation |
| 1.1.7 fix omitted from 2.0 | Cherry-pick relevant fixes with origin SHA and regression case; maintain a forward-port ledger |
| Retro accidentally loses a screen/control | Complete feature inventory and route-by-route parity signoff |
| Animation winner disagrees with result | Result-driven timeline; terminal-state assertions; no prototype winner script |
| Closing/rematch causes duplicate rewards or stale callbacks | Cancellable coordinator, battle identity, exactly-once model settlement tests |
| Custom artwork is slow/inconsistent/expensive | Small anatomy spike, persistent cache, bounded jobs, genuine fallback, measured cost before bulk generation |
| Melee becomes unreadable | Early 4v4 prototype, stable formations, restrained per-actor effects, phone test |
| Upgrade loses purchases or save data | Stable keys/IDs, in-place upgrade fixtures, sandbox/cloud isolation, explicit migrations only |
| Beta harms production backend | Separate staging; additive contracts; production branch/deploy controls verified before publishing |
| Fake confidence from simulator tests | Physical-device capabilities called out; unknown results stay unknown; evidence ledger |
| Apple processing/review/login delay | Check readiness early; internal owner testing where eligible; report actual processing/access state |

Do not promise a release date until P1 and the P2/P3 anatomy/custom-generation spike establish actual effort. The project is more than a skin swap; asset coverage, every mode, and upgrade safety are real workstreams.

## 10. Release and handoff

Follow [TESTFLIGHT_RELEASE.md](TESTFLIGHT_RELEASE.md). Marketing version becomes `2.0` only on the new line; choose a build number after inspecting App Store Connect, and keep a monotonic ledger across maintenance and 2.0 builds as an operational convention. Existing signing identity, bundle ID, products, and services remain attached to the original app for the final beta.

Freeze a release candidate commit, run required checks against that source, archive to a unique path, verify embedded version/build/entitlements, retain the archive and symbols, upload once, and monitor processing. Assign the processed build to the owner's eligible internal group or follow the external-beta review path if required. No public App Store submission is implied.

Final delivery must state: app/version/build, source commit, TestFlight group/access, verified availability, completed test matrix, any low-severity limitations, and where to send feedback. Include a short owner test route covering custom creation, a normal fight, quick/next challenger, tournament, melee, collections, settings, and upgrade state. No placeholder screens or known critical/high-severity regressions are acceptable.

This plan provides controls to catch errors; it is not a guarantee of zero defects. The completion claim will be based on the delivered build and test evidence.
