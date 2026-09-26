# Animal vs Animal 2.0 (111) — motion and interface refresh

**Animal vs Animal 2.0 (111) is available in internal TestFlight. Apple reports VALID, INTERNAL_ONLY, and IN_BETA_TESTING; the exact candidate is present in the existing self group.** This iteration gives every catalog creature visible body motion, adds more authored sprite poses, and replaces the muted panels and stepped buttons with a brighter sky/mint/ivory interface and compact rounded controls. The whole app remains retro. The [build 110 release record](RELEASE_2.0_110.md) remains the historical record for the first complete retro beta.

## What changed

- **18 of 143 catalog creatures have authored idle, anticipation, attack, and reaction poses**, up from two in build 110. The other **125 use eight anatomy-based motion families** that move parts of their existing artwork during battle. These are distinct rendering methods; this is not a claim of 143 individually authored animation sheets.
- Custom avatars use the selected bundled form's poses when available, or its anatomy-based motion otherwise. Pose-specific memory caching and a consistent scale keep their identity and size stable. Creation remains on-device, offline-capable, and free of image API charges; existing custom-creation coin rules and narration/classification behavior are unchanged.
- Home, pickers, battle controls/results, collections, settings/shop, parent flows, tournaments, and shared cards use the refreshed palette, backgrounds, borders, and buttons. Final contrast fixes keep shop badges and previous tournament rounds readable.
- Battle outcomes, rewards, custom IDs, saved data schemas, backend contracts, and commerce rules are unchanged. Source/callback review found no removed action or accessibility identifier in the presentation changes.

## Distribution evidence

| Field | Verified result |
| --- | --- |
| App / canonical bundle | Animal vs Animal / `com.whowouldin.WhoWouldWin` |
| Version / build | **2.0 / 111** |
| App Store Connect build | `cf90c71c-871a-42d1-9b47-6c781f8638cf` |
| Processing / audience | `VALID` / `INTERNAL_ONLY` |
| Internal / external testing state | `IN_BETA_TESTING` / `NOT_APPLICABLE` |
| Internal group / exact candidate access | Existing `self` group; all-build access; exact candidate present in its build list |
| Availability verified | September 26, 2026, 17:32:18 UTC |
| What to Test read-back | September 26, 2026, 17:32:18 UTC; English notes published and read back |
| Export compliance | `usesNonExemptEncryption: false`; no blocking compliance state |
| Apple upload time / expiration | September 26, 2026, 17:30:39 UTC / December 25, 2026, 17:30:39 UTC |
| Actual owner installation / acceptance | Pending; not inferred from Apple availability |

Xcode reported upload success at **2026-09-26 17:29:57 UTC**, exporting the same canonical archive with internal-only distribution and automatic build renumbering disabled. The exact build passed Apple processing and is available to the existing internal group. No invitations were sent and no external group was changed. The final sanitized record belongs at [build 111 verification](evidence/testflight-2.0-111.json). No external beta or App Store submission is part of this milestone.

## Source and measured validation

The canonical candidate source is **`5ea7ba1966bcf71e85918a390ad2e234c976f8c4`** on `develop/2.0`. Tests were run in three explicitly identified source states:

| Run | Actual source | Passed / failed / skipped |
| --- | --- | --- |
| Broad iPhone suite: 50 unit + 9 UI | `5205bf50ed3f2bb4f6966ff10dfbea4c27ebaf8c` | **59 / 0 / 0** |
| Motion correction: 50 unit + 3 battle UI | `2a5264d7067d4828ff4a3391c2fe6d852c05dfed` | **53 / 0 / 0** |
| iPad: 3 battle UI, actual tournament dismissal, tournament/share exports | `2a5264d7067d4828ff4a3391c2fe6d852c05dfed` | **5 / 0 / 0** |
| Final shop/parent/settings and tournament/export UI | `5ea7ba1966bcf71e85918a390ad2e234c976f8c4` | **2 / 0 / 0** |

These are **119 native test executions**, including repeated methods across devices and source states. They are not 119 distinct tests, nor a claim that the whole suite reran at final HEAD. The transition from `5205bf5` to `2a5264d` changes one bird-wing motion expression. The final four-file change adjusts shop label contrast/decorative crown, the wager speed icon, bracket history contrast, and tournament export text contrast. The two affected UI cases were rerun at final HEAD. The unit-test sources, motion/battle engine, models/services, artwork, configuration, and both test targets used for the final motion checks are unchanged by those last four UI edits; exact object comparisons are retained.

New motion checks cover every catalog/custom source's anatomy, meaningful pose changes, bounded nonfolded meshes, authored-pose bypass, and clearing procedural deformation under Reduce Motion. Native SpriteKit contact sheets show multiple times across ten matchups. Phone/tablet battle, 4v4, custom, navigation, and export captures were reviewed, including the final UI changes. Static captures do not establish physical-device frame pacing. Bundled artwork validation covers **143 catalog creatures, 12 custom bases, and 23 referenced atlases**.

## Inherited compatibility evidence

**No new build 111 backend test run or actual upgrade installation is claimed.** The previous **46 passing backend tests** remain applicable because the entire tracked backend tree, including tests, package manifest, and lockfile, is byte-for-byte identical (`a7d55743ba7a55e37b1f935a541201706171a3cd`). No backend deployment was required.

The prior build 110 **two strict synthetic 1.1.7 upgrade cases** (pending and settled) are carried only for unchanged persistence paths. Models, services, startup, data IDs, canonical identity/entitlements, release settings, fixtures, and the upgrade harness match the tested release. Those earlier cases verified durable preferences and loaded stores, a cold baseline launch, Documents data, and the synthetic Keychain PIN. No new 1.1.7 → 111 or 110 → 111 installation occurred locally. Actual owner-device upgrade, receipt/account state, and cloud reconciliation remain pending.

The final 17:25 UTC release recheck confirmed the original maintenance checkout's NUL-delimited status still matched its saved snapshot and the remote `release/1.1.7` tip remained `107bf7327f1c82e85282101e2294fb6f9ded3639`. That branch remains the independent maintenance line; see [branching instructions](BRANCHING.md). Build 111 is reserved for this candidate; Build 111 is now uploaded and available internally. Recheck live ASC history before allocating the next build on either line.

## Retained artifacts

Paths are relative to the v2 worktree; binary outputs remain ignored locally.

- Final QA: `ios/build/QA-2.0-111-5ea7ba1.json`; source comparisons: `ios/build/QA-carryforward-111.json`.
- Broad phone results: `ios/build/runs/20260926T170850Z-test-2.0-111-5205bf50-75f6eb/Tests.xcresult`.
- Motion/battle phone results: `ios/build/runs/20260926T171419Z-test-2.0-111-2a5264d7-f31bfc/Tests.xcresult`.
- Tablet results: `ios/build/runs/20260926T171718Z-test-2.0-111-2a5264d7-83c929/Tests.xcresult`.
- Final affected UI results: `ios/build/runs/20260926T172036Z-test-2.0-111-5ea7ba19-b1ba30/Tests.xcresult`.
- Previous backend log: `ios/build/backend-tests-583b5e5.log`; previous upgrade report: `ios/build/runs/20260926T162110Z-upgrade-71d167/upgrade-report.json`.
- Signed archive and inspection: `ios/build/runs/20260926T172651Z-archive-2.0-111-5ea7ba19-8ad296/WhoWouldWin.xcarchive`; `ios/build/runs/20260926T172651Z-archive-2.0-111-5ea7ba19-8ad296/archive-inspection.json`.
- Inspected local IPA: `ios/build/export-2.0-111-5ea7ba1/Export/WhoWouldWin.ipa`; SHA-256: `759139967814caa68f0ed75c996efd74a08b99e250e5d4446d55c2bfb73679c1`; export evidence: `ios/build/export-2.0-111-5ea7ba1/export-evidence.json`.
- Upload evidence: `ios/build/upload-2.0-111-5ea7ba1/`; final Apple read-back: `ios/build/beta-2.0-111-verified.json`.

Signed archive and local internal-only IPA inspection passed: canonical identity/version, production configuration, signing/capabilities, bundled artwork, and absence of DEBUG fixture/diagnostic markers. The application dSYM is retained. The inspected local IPA hash identifies that retained export; it does not assert that a separately exported Apple upload is byte-identical. Archive warnings remain in untouched SpeechService, the unassigned legacy icon, and skipped App Intents metadata extraction because the app has no AppIntents dependency. The upload again reported missing dSYMs for the unchanged GoogleMobileAds and UserMessagingPlatform SDKs; the app's own dSYM is present. Those third-party symbols are not claimed as supplied. Passing checks do not imply warning-free compilation or complete third-party debug symbols.

## Owner acceptance

Open TestFlight → Animal vs Animal → **2.0 (111)**. Use the [owner checklist](OWNER_TESTFLIGHT_CHECKS.md), especially anatomy-specific motion, custom avatar poses, the refreshed controls, background/rematch, 4v4 play, and Reduce Motion. Record progress before updating the canonical app; source worktrees do not isolate device data.

No physical iPhone/iPad was connected. Real upgrade/purchases/restore, App Attest and live narration, Game Center/iCloud, device permissions, audio/haptics/ads, accessibility, older supported OS versions, and sustained hardware performance remain owner checks. The dated [feature inventory](FEATURE_PARITY.md) retains its NOT TESTED qualifications for scenarios that have not been exercised. Internal availability is not owner acceptance or authorization for broader distribution.
