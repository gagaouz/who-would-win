# Release readiness evidence — September 26, 2026

**Final outcome: 2.0 (110) is available in internal TestFlight.** Apple reports `VALID`, `INTERNAL_ONLY`, and `IN_BETA_TESTING`; the exact build is present in the existing `self` group and its What to Test notes were published and verified. See the [final release record](RELEASE_2.0_110.md) and [sanitized Apple evidence](evidence/testflight-2.0-110.json).

Final validation passed 41 unit, 9 iPhone UI, 5 targeted iPad UI, 46 backend tests, and both strict in-place synthetic upgrade cases. Archived source is `583b5e5`; native source equivalence to tested `ebcc38e` is recorded. The original maintenance checkout is unchanged. Physical installation/account/capability acceptance remains pending through the [owner checklist](OWNER_TESTFLIGHT_CHECKS.md).

The sections below retain the day's earlier checkpoints as **historical evidence**, superseded by the final record above. Their provisional allocation, earlier test counts, and not-yet-uploaded statements describe those earlier times, not current release status.

## Native baseline and build harness

- The untouched source at `107bf7327f1c82e85282101e2294fb6f9ded3639` was extracted with `git archive` into `/tmp/ava-117-baseline.O78hnl`. Its iOS Debug simulator build passed under Xcode 27.0, signing disabled. Log and built app remain in that directory. The baseline app was not launched, and its production backend was not contacted.
- Version/build now come from `ios/config/Version.xcconfig`: **2.0 / 110, provisional**. Info.plist and XcodeGen reference build settings instead of duplicate literals. Release preserves canonical app identity; Testing has its own `.uitesting` bundle.
- Shared scheme and Debug/Testing/Release configuration generation passed. Swift package requirements are pinned to the reviewed resolved versions. The generated project includes `RetroSpriteManifest.json`.
- Fixture launch skips live startup services and installs a local URLSession request blocker; only the isolated Testing bundle can reset its own test preferences. Success-fixture and offline-fallback UI cases are separate. Domain-level service guards supplement startup isolation.
- `ios/scripts/release.py` provides preflight, build, test, local archive, and archive inspection. Outputs are unique, logs retained, and there is no upload operation. Archive checks refuse provisional allocation, dirty source, or incomplete candidate QA evidence. The legacy `deploy.sh` now forwards to these explicit stages without incrementing or uploading.
- Integrated Testing validation completed at **2026-09-26T10:47Z**: **29 unit tests and 4 UI tests passed**. This includes native battle lifecycle/model tests, asset validation, baseline-encoded upgrade models, success/offline battle paths, all-eight-member 4v4 visibility, background/resume and rematch. Result: `ios/build/runs/20260926T103517Z-test-2.0-110-a137ec3f-7bba26/Tests-expanded.xcresult`; matching `run-expanded.json` records the exact command. Captures are under `captures-expanded/`. This run preceded completion of the full catalog art; the final 143-sprite build needs its own validation record.

## Live App Store Connect — read only

Checked at **2026-09-26T10:32:24Z** with the already configured API credential. No authentication material or tester contact details were saved. Evidence: `ios/build/asc-readiness-2026-09-26.json` (ignored local build evidence); repeatable reader: `ios/scripts/asc_readiness.py`.

- Correct app record: Animal vs Animal, `com.whowouldin.WhoWouldWin`, app ID `6761319389`.
- The complete returned build history had no next page. Highest uploaded build was **109 / 1.1.7**, processing state **VALID**, unexpired at the check, expiring December 22, 2026.
- App Store version **1.1.7** reported **READY_FOR_SALE**.
- Internal group **self** contains one tester and reports `hasAccessToAllBuilds: true`. This automatic access matters when deciding when a candidate is ready to upload.
- One external group contains three testers and has a public invitation link enabled. The v2 milestone does not require adding it to that group.
- Build 110 was not present at this check. It remains provisional until coordination with the maintenance line and a release-time recheck. This read-only query does not reserve a number in ASC.
- Owner's exact tester membership/install access, current membership/agreements, distribution-profile capability coverage, and new candidate processing remain unverified. No builds uploaded, groups changed, review requested, or invitations sent.

## Remote deployment triggers — verified, no push performed

Read-only GitHub API inspection found only dynamic Dependabot Updates and CodeQL workflows; repository webhook listing returned an empty array. GitHub deployment history also shows the Railway app integration, so branch rules were checked directly rather than inferred from webhooks.

At **2026-09-26T10:46:23Z**, an authenticated read-only Railway GraphQL query of the linked project found exactly one backend repository trigger: `gagaouz/who-would-win`, branch `main`, production environment `2ed3111a-8768-440e-8d38-90c008aaf3ea`. Project `prDeploys` and `botPrEnvironments` are both `false`; Postgres has no repository triggers. The inspected configuration therefore has no branch trigger for `develop/2.0`. [Sanitized response](evidence/railway-trigger-audit-2026-09-26.json) contains configuration identifiers only, with no token or environment secrets. The latest production deployment at the check was successful from September 24 (`dfefd10c-edaf-4391-812d-27418c99c182`).

Netlify's live site API, refreshed at **2026-09-26T15:37:51Z**, reports production branch `main`, allowed branches `["main"]`, builds enabled, and the published deployment on `main` for site `9b3c727f-15d5-4424-bc7c-62c07212856b`. [Sanitized Netlify response](evidence/netlify-trigger-audit-2026-09-26.json). These are point-in-time observations; recheck before any subsequent publishing if configuration changes.

**At the inspection checkpoint no branch had been pushed and no remote configuration was changed.** The v2 checkout was not linked to the production Railway service. These observations establish the inspected integrations' main-only branch behavior; they do not authorize deployment or prove that every possible external integration has been discovered.

## Upgrade fixtures and limitations

`ios/scripts/Capture117Fixtures.swift` was compiled against the untouched 1.1.7 `Animal`, `BattleEnvironment`, `BattleResult`, and `Tournament` source to produce synthetic fixtures under `ios/scripts/fixtures/1.1.7/`. They include pending and settled tournaments with a custom entrant and wagers, plus representative preferences for coins, progress, collections, unlocks, consumed transaction IDs, and parental settings. `provenance.json` records source identity and content hashes.

The generated JSON is embedded into `Upgrade117FixtureTests` in `RetroAssetTests.swift` so the current decoder must accept old payloads and preserve the settlement guard and custom identity. This avoids encoding and decoding with the same new implementation, which would miss schema drift.

The disposable-simulator harness initially found that unsigned simulator products lack the entitlement sections needed by Keychain. Rebuilding the archived fixture using Xcode ad-hoc “Sign to Run Locally” allowed the synthetic PIN to be saved and verified. The final candidate must use the same simulator signing path; this requires no distribution key/profile or account call. A manual simulator-signing experiment failed to launch and is not treated as successful upgrade evidence.

These fixtures are **not** a physical App Store-to-TestFlight upgrade, a StoreKit receipt, iCloud-account migration, or keychain/PIN backup. Those release gates remain required. The synthetic preference plist is a controlled test input, not a backup of the owner's device.

## Integrated simulator evidence

The first complete-catalog binary passed **34 unit tests and 7 iPhone UI tests** on September 26; result `ios/build/runs/20260926T103517Z-test-2.0-110-a137ec3f-7bba26/Tests-full-art.xcresult`, `run-full-art.json`. Exact native roster coverage was asserted at 143 IDs. Xcode's verbose post-test simulator diagnostic collector stalled after all cases passed; only that identified `simctl diagnose` subprocess was stopped, after which Xcode finalized **TEST SUCCEEDED / exit0**. Test assertions were not disabled or cancelled.

The same compiled binary then passed **6 iPad Air11 UI tests**, including solo pause/resume/rematch, 4v4 result, 17 broad screen/export fixtures and home battle success. Result `Tests-tablet.xcresult`, `run-tablet.json`. The tablet command disabled only verbose simulator diagnostic collection to avoid repeating the host-tool hang; ordinary XCTest logs, assertions, screenshots and results were retained. Friendly PNGs are under `captures-full-art/by-name/` and `captures-tablet/by-name/`; full-size rendered share cards are preserved in the former.

These runs precede subsequent crop cleanup, small visual fixes, and the owner-selected local custom sprite renderer. They are implementation evidence, not approval of untested later changes. A final integrated run remains required for the frozen candidate.

## Current custom-art scope

The owner selected fully on-device custom artwork using a stable name-aware recipe and bundled sprite kit. No paid per-custom API or new backend deployment is required. Archive attestations now require `localCustomArtworkPassed` plus `backendCompatibilityPassed`; native local rendering, offline creation, identity/caching/erase behavior and unchanged narration contracts must pass before distribution.

## Hardware availability and owner acceptance

Read-only `devicectl` and `xctrace` inspection found **no physical iPhone/iPad available**. Every devicectl iOS record explicitly reports `reality: simulated`; xctrace's physical-device section contains only the host Mac. [Sanitized evidence](evidence/device-availability-2026-09-26.json) omits device names, UDIDs and account identifiers.

The owner-requested deliverable is an internal TestFlight beta they can test. The archive contract therefore requires `distributionScope: internal-testflight`, all automated correctness/parity/synthetic-upgrade/local-art/backend checks passed, and an honest `physicalDeviceStatus`. With no hardware, use `pending-owner-testflight` plus explicit `ownerDeviceChecks` for canonical App Store-to-beta upgrade, real purchase restore/subscription states, iCloud, device permissions/capabilities and performance. These checks are not marked passed. External/public distribution remains outside this candidate scope.

## Candidate build allocation

At **2026-09-26T16:00:47Z**, fresh read-only ASC history remained complete with highest uploaded build 109 and no build 110. Maintenance checkout metadata remains 1.1.7 / 109. **2.0 / 110 is now allocated locally to this internal-beta candidate**, recorded in `ios/config/BuildAllocation.json` and [sanitized ASC evidence](evidence/asc-allocation-2026-09-26.json). This is coordination, not an ASC reservation. The next unallocated global number at that check is 111; maintenance work must choose a different number. Recheck before upload.

## Earlier remaining release gate — subsequently completed

At this checkpoint, the remaining work was the final native/local-art suite, strict synthetic upgrade, backend compatibility, release artifact inspection, upload, and Apple processing/access verification. Those internal-beta gates subsequently completed; see [RELEASE_2.0_110.md](RELEASE_2.0_110.md). Actual owner installation and physical/account acceptance remain unverified.

## Published source checkpoint

After the main-only trigger audit, root pushed only `develop/2.0` at `7b03a2a` on September 26. The maintenance branch remains at `107bf73`; its working-directory status still matches the isolation snapshot. No backend source changes or production deployment were part of this push. Later tested/released commits are recorded separately.
