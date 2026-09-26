# Animal vs Animal 2.0 (112) — authored animation for every fighter

**Build 2.0 (112) is available in internal TestFlight.** Apple reports `VALID`, `INTERNAL_ONLY` and `IN_BETA_TESTING`; the exact build is present in the existing `self` group. Availability and English testing notes were verified on September 26, 2026 at **20:19:50 UTC**. Owner installation and physical-device acceptance remain pending.

All **143 catalog creatures and 12 custom bases** now have four distinct drawn poses: idle, anticipation, attack and reaction. They use the native approach/strike/recoil/recovery sequence established for the original lion. This is four-pose battle animation, not a claim of separate walking, flapping or multi-frame attack clips. The brighter sky/mint/ivory interface and rounded controls from build 111 remain in place.

Custom names still resolve to stable local avatars using recognized bodies, colour cues and effects. Every available body now has authored action poses. Unknown names receive a fantasy avatar; arbitrary exact likenesses are not promised. No image provider, API key or per-character image charge is introduced. The optional **Change look → Body · Colour · Extras** editor is [documented as a proposal](CUSTOM_FIGHTERS_PROPOSAL.md), and is not shipped in this build. Existing custom IDs, creation eligibility, coin/ad rules, narration and battle outcomes are unchanged.

## Delivery evidence

| Field | Verified result |
| --- | --- |
| Canonical bundle | `com.whowouldin.WhoWouldWin` |
| Version / build | **2.0 / 112** |
| Frozen tested and archived source | `9eec02be943501312c233738b5d53dd284b4d726` on `develop/2.0` |
| Apple build ID | `525fad06-a69d-45a2-a9d1-daab53807677` |
| Processing / audience | `VALID` / `INTERNAL_ONLY` |
| Internal / external state | `IN_BETA_TESTING` / `NOT_APPLICABLE` |
| Internal access | Existing `self` group; exact candidate present in its build list |
| Upload command success | September 26, 2026, **20:15:48 UTC** |
| Apple upload date / expiration | September 26 / December 25, 2026, **20:16:55 UTC** |
| Availability and What to Test read-back | September 26, 2026, **20:19:50 UTC** |
| Export compliance | `usesNonExemptEncryption: false` |
| Retained local IPA SHA-256 | `0bc18c01737362a9b72ec69b02985ce94dbf05225c80846c4ebb920c35e229ed` |

The [sanitized release record](evidence/testflight-2.0-112.json) links the measured evidence. Upload used the same canonical archive, internal-only distribution and disabled automatic build renumbering. A fresh pre-upload lookup confirmed 112 was absent across marketing versions. No invitations, external group changes or App Store submission were made. The IPA hash identifies the retained local export, not a claim that Apple's separately exported upload is byte-identical.

## Measured validation

| Check | Result |
| --- | --- |
| Full iPhone suite | **56 native unit + 9 UI tests passed** |
| iPad affected cases, same built product | **5 UI tests passed** |
| Total XCTest executions | **70 passed, 0 failed, 0 skipped**; tablet methods repeat phone coverage |
| Fresh synthetic 1.1.7 → 112 upgrades | **Pending and settled tournament cases passed** |
| Complete authored coverage | **143 catalog + 12 custom bases**, four distinct valid/renderable poses each |
| New artwork review | **35 sheets, 137 subjects, 548 pose cells** accepted after corrections; the previous 18 authored catalog families are retained |
| Native visual review | **39 unique phone/tablet artifacts** accepted, including ten matchups at six fixed times, custom variants, stages/results, brackets and share previews |
| Source stability | **454 source/config/resource/test files** unchanged before and after both native runs |
| Packaged artwork | **35 raw PNG atlases** match source byte for byte in archive and IPA; **40 referenced atlases** total |
| Backend compatibility | Prior **46 passing tests** carried by exact complete backend-tree identity; no new backend run or deployment |

Both native runs used the isolated `.uitesting` bundle with external services blocked. Evidence includes actual app version, executable/debug-library hashes, compiled assets, manifest and all raw atlas hashes. Tests cover battle lifecycle/results, offline fixtures, cancellation/reentry, Reduce Motion, cache eviction and clearing, custom identities and authored rendering. These are the measured scenarios, not universal device/account acceptance. Visual captures establish pose and layout appearance; fixed-time stills do not establish frame pacing. Share review covers native scroll previews, without claiming a separate visual inspection of saved full-size export files.

The fresh upgrade runs installed an instrumented 1.1.7 baseline from `107bf7327f1c82e85282101e2294fb6f9ded3639`, then upgraded in place to the exact tested 112 product. Both cases preserved loaded stores, preferences, Documents data and the synthetic Keychain PIN, including a cold baseline launch. The baseline fixture entry point was replaced; persistence services/models were unchanged. Root separately reviewed the pending case's home after a cold relaunch: the expected 1,234 coins and six-day streak rendered. These checks do not represent an upgrade of the owner's canonical app, receipts or cloud account.

The complete backend tree remains `a7d55743ba7a55e37b1f935a541201706171a3cd`, identical to the prior 46-test run. Gameplay views, models, services, IDs, backend contracts, battle scene/lifecycle and commerce rules are unchanged from build 111; rendering resources and their loader changed. At **20:20:21 UTC**, the original maintenance checkout's NUL-delimited status still matched its saved baseline and remote `release/1.1.7` remained `107bf7327f1c82e85282101e2294fb6f9ded3639`. See [branching instructions](BRANCHING.md); build 112 is now used, so recheck live ASC history before the next allocation on either line.

## Artwork memory and package checks

New sheets live in `RetroAtlases/` as raw PNG resources. The decoded atlas LRU retains at most **32 MiB** and uses detached crop buffers, so a small displayed portrait does not retain its entire source sheet. Crop caching has a separate cost/count limit. Memory warnings clear both caches without forcing immediate texture recreation; parent erase clears both and refreshes artwork. The five retained asset-catalog atlases keep the compatibility path. This is a decoded-atlas budget, not a whole-app memory limit; SpriteKit textures, cropped images, frameworks and legacy pages are separate.

Archive and IPA inspection passed canonical identity/version, production configuration, signing/capabilities, current manifest, all 35 raw atlas hashes and absence of DEBUG fixture markers. The raw resources' four pose crops were checked against their pixels. The five retained compiled asset-catalog atlases have native rendering evidence plus source-pixel validation; the release inspector does not claim extracted compiled-catalog pixel comparisons.

The application's dSYM is present. Upload reported missing vendor dSYMs for the unchanged GoogleMobileAds and UserMessagingPlatform frameworks. Existing warnings remain for SpeechService's weak capture, an unassigned legacy icon and skipped App Intents metadata extraction. These are retained in the logs; this release is not described as warning-free.

## Retained artifacts

Paths are relative to the v2 worktree; generated binary outputs remain ignored locally.

- QA: `ios/build/QA-2.0-112-9eec02b.json`.
- Phone results and captures: `ios/build/runs/20260926T193859Z-test-2.0-112-9eec02be-62e1a8/`.
- Tablet results and captures: `ios/build/runs/20260926T194425Z-test-2.0-112-9eec02be-2a40de/`.
- Fresh upgrade and delayed home review: `ios/build/runs/20260926T194048Z-upgrade-d14569/`.
- Static art acceptance: `ios/build/release-tools/motion-all/visual-acceptance-index.json`; native acceptance: `ios/build/release-tools/native-visual-review-112-9eec02b.json`.
- Signed archive and inspection: `ios/build/runs/20260926T200418Z-archive-2.0-112-9eec02be-261807/`.
- Local IPA and export evidence: `ios/build/export-2.0-112-9eec02b/`.
- Upload evidence and warnings: `ios/build/upload-2.0-112-9eec02b/`.
- Apple read-back: `ios/build/beta-2.0-112-verified.json`; maintenance: `ios/build/release-tools/maintenance-final-112-verified.json`.

## Owner testing

Open TestFlight → Animal vs Animal → **2.0 (112)** and use the [owner checklist](OWNER_TESTFLIGHT_CHECKS.md). Compare different species and custom names, then try rematch, 4v4, background/resume, Reduce Motion and shared cards. Check retained progress and the active tournament before further play.

Actual installation, purchases/restore, subscription and receipt state, App Attest/live narration, Game Center/iCloud, permissions, audio/haptics/ads, accessibility, older supported systems and sustained physical-device performance remain owner checks. Separate source worktrees do not isolate data on a device using the same canonical app identity. Build 112 availability is verified; owner acceptance and broader distribution are not implied.
