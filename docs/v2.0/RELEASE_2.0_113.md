# Animal vs Animal 2.0 (113) — My Fighters and private subscriber artwork

**Authentication fix supersedes this build:** use [2.0 (114)](RELEASE_2.0_114.md) to retry Sign in with Apple. Build 113 sends fighter-account requests to the legacy battle origin and receives 404. The historical delivery/activation evidence below is preserved.

**Animal vs Animal 2.0 (113) is available in internal TestFlight. At 2026-09-26 22:05:23 UTC, Apple reported VALID, INTERNAL_ONLY and IN_BETA_TESTING; the exact candidate is present in the existing self group and its English testing notes were read back.** Owner installation and physical-device acceptance remain pending.

My Fighters adds a private account library with four-pose previews, saved-fighter selection and restoration. It is accessible from home, settings, solo, team and tournament selection. Existing typed-name local avatars remain available. Selecting downloaded artwork does not spend another custom-creation charge, and downloaded fighters remain usable after Premium expires or a network session needs sign-in again. An explicit sign-out hides that owner's local library.

**Upload-time state (22:05 UTC):** The service had no image-provider credential and live new-artwork generation was unavailable. The later activation below supersedes that configuration status; the original upload evidence remains unchanged. This beta contains the account/library and generation workflow implementation; it is not a claim that real Sign in with Apple, a real subscription-to-owner association, or a paid generated sheet has succeeded. The new UI tests use explicitly isolated synthetic account/API responses and fixture artwork made from bundled sprites.

## Backend activation — September 26, 2026

At **23:23:48 UTC**, deployment `138ef722-baf2-4ef7-89c9-81b1f97ef7da` succeeded and the private artwork service reported `enabled: true` and `configured: true`. The approved pilot is **Sandbox-only**, purchaser-only, with **three successful creations per UTC month** and the existing **$5 lifetime application budget / $1 paid-attempt reservation**. Production creation remains off. Private-library access still requires authentication (401 without it), and the old battle route remains absent from this service (404).

The key expires **2026-12-25**. Its preflight listed all three required models, and a benign moderation request returned 200. These checks made **zero image-generation or semantic-review requests**; no live generated sheet has been accepted. The independent database check at 23:26:07 UTC found zero actual accounts, sessions, jobs or budget entries. Model visibility and moderation success do not establish the complete generation, quality or subscription flow.

The next owner check is in **TestFlight 2.0 (113) → My Fighters**: complete real Sign in with Apple, establish the intended Sandbox Premium entitlement, then create **one benign fighter such as Robot** through the grown-up gate and explicit OpenAI consent. The activation and one-request pilot are already authorized. Check its four poses, one-credit accounting, saved-library entry and reuse. Account authentication, receipt association and live output quality remain unverified until observed.

The same TestFlight build remained `VALID` / `INTERNAL_ONLY` / `IN_BETA_TESTING` with existing `self` access when its updated English notes were read back at **23:24:28 UTC**. See the [separate activation evidence](evidence/custom-fighter-activation-113.json). This backend configuration change does not replace frozen app source `3ae7a43f` or alter the [historical upload record](evidence/testflight-2.0-113.json).

## Delivery evidence

| Field | Result |
| --- | --- |
| Canonical bundle | `com.whowouldin.WhoWouldWin` |
| Version / build | **2.0 / 113** |
| Frozen candidate source | `3ae7a43f0e48097707d5cb32fc783b2d645944b8` on `develop/2.0` |
| Apple build ID | `e396210b-2dbb-4012-981b-519432c5c62a` |
| Processing / audience | `VALID` / `INTERNAL_ONLY` |
| Internal / external state | `IN_BETA_TESTING` / `NOT_APPLICABLE` |
| Internal access | Existing `self` group; exact candidate present |
| Upload success | September 26, 2026, **22:02:17 UTC** |
| Apple upload date / expiration | September 26 / December 25, 2026, **22:03:09 UTC** |
| Availability / What to Test read-back | September 26, 2026, **22:05:23 UTC** |
| Export compliance | `usesNonExemptEncryption: false` |
| Retained local IPA SHA-256 | `ab81292d35f39b63c57573635a38fd6a67e0e35d3790387e1f39b3bca38d10e4` |

The [sanitized build 113 record](evidence/testflight-2.0-113.json) links actual QA, archive/export/upload and Apple availability evidence. Upload used the same canonical archive, internal-only distribution and fixed build numbering. The retained local IPA hash identifies that export, not Apple's separately exported upload. No invitations, external group changes or App Store submission were made.

## Measured validation

| Check | Current evidence |
| --- | --- |
| Full iPhone suite at frozen source | **73 native unit + 14 UI tests passed** (87 executions) |
| iPad affected cases at frozen source | **10 repeated UI cases passed** in the complete replacement run |
| Total final XCTest executions | **97 passed, 0 failed, 0 skipped** in the two accepted final runs; repeated tablet cases are executions, not distinct coverage |
| Fresh synthetic 1.1.7 → 113 upgrades | **Both fresh cases passed**: pending and settled tournaments, using the actual tested 113 app |
| Fresh backend suite at frozen source | **80 passed, 0 failed, 0 skipped**, completed 21:42:35 UTC on September 26, 2026 |
| Source/bundle stability | **581 fingerprints unchanged** before/after both accepted native runs; 498 required native-scope files; actual isolated 2.0/113 bundle and 35 raw-atlas hashes verified |
| Final native visual review | **45 inspected still captures accepted** (16 phone + 29 tablet); synthetic pack integration, with scoped observations/limitations |
| Live isolated service | Health/status/privacy/challenge checked; library unauthenticated 401; old battle route 404; no paid calls |
| Sign in with Apple capability | Enabled for canonical bundle at 21:20:10 UTC; existing capabilities preserved |
| Signed archive and local IPA | **Passed** canonical identity/configuration, signed Apple entitlement and embedded profile, existing capabilities, DEBUG-marker exclusion, artwork hashes and own app dSYM |
| Maintenance isolation | Original checkout unchanged at 22:03:01 UTC; fresh read-only remote check retained `release/1.1.7` at `107bf73` |

The final native suite measures downloaded-pack validation/owner isolation, legacy model decoding and renderer behavior, pending-request persistence, terminal uncertain jobs, battle lifecycle, existing screens and the five custom-library scenarios. These scenarios cover: typing and cancelled consent create nothing; an explicit confirmed request creates once; unavailable service disables creation; downloaded selection still works without creation entitlement; an older persisted job absent from the recent list is recovered directly without another creation; and an uncertain terminal job returns the customer credit and permits only a newly confirmed replacement request. Some scenarios share one UI method. They are mock-network tests, not real Premium, sign-in, provider or cloud-library acceptance.

An earlier same-source tablet run (`20260926T214228Z-test-2.0-113-3ae7a43f-aa1dcd`) passed 9 of 10 cases and failed a legacy cheer accessibility lookup after the fixture battle had already transitioned to its result. The failure and triage are retained in `ios/build/release-tools/tablet-113-race-triage.json`. The entire unchanged ten-case tablet scope then passed in `214929-aec4d3`; no source/assertion changes were made. The earlier failure is not silently counted as a pass or added to the 97 accepted executions.

The 80-test backend run includes disposable local PostgreSQL transactions/concurrency, mocked provider/signed-proof responses, accounting, moderation/image checks and deletion/isolation checks. It made zero paid provider calls. This is new build 113 backend evidence; the old 46-test identical-tree carry-forward used for earlier visual releases is not applicable to this feature. Frozen backend tree is `27906a67a70fe3934f7e6d119bf9e15931776579`.

Both upgrade cases used the actual phone app from frozen `3ae7a43f` and preserved loaded state, preferences, Documents and the synthetic Keychain PIN, including cold baseline launches. The post-upgrade home was also reviewed. This is an isolated instrumented simulator upgrade, not the owner's App Store-to-TestFlight installation, receipt restore or iCloud state. Final tests and fresh upgrades supersede earlier 113 candidate runs; earlier passing runs remain diagnostic history only.

## Artwork, account and quota behavior

Typing a name never requests artwork. The explicit Create action requires a fresh grown-up gate followed by disclosure that the name is sent through the private service to OpenAI. Creation uses the existing Premium monthly/annual products, with **three successful creations per UTC calendar month** during the purchaser-only Sandbox beta. Production creation stays off. Existing local custom benefits, permanent purchases, coin rules and earned unlocks are separate.

A request UUID is written atomically before POST. Resume uses that same key; a known job missing from the last 30 jobs is retrieved by ID. Server deduplication prevents an ambiguous retry from becoming another paid generation. `reconciling` is terminal for the customer/workflow: the customer credit is returned, the request never retries automatically, and a new creation needs fresh confirmation. The application retains its cost reservation for possibly billed work. The beta ledger is **$5 lifetime**, with **$1 reserved per paid attempt**; these are application controls, not measured provider prices or an external billing cap. No automatic repair calls are implemented.

Accepted original and runtime PNGs are stored privately in PostgreSQL. Device downloads are authenticated, reject redirects, are limited to 8 MiB and validate hashes/frames before an atomic owner-separated install. Explicit tombstones and library epochs prevent deleted/quarantined accounts or assets reappearing from a stale library. A missing list entry alone is not deletion. Unsafe reports remove the local copy after server success.

The grown-up **Erase game data** control removes game progress, local fighter credentials, downloaded packs and pending request data. Deleting the private online library remains a separate **My Fighters → Account** action. Local deletion errors are reported. Apple authorization-grant revocation, finite backup expiry and full real-device account-deletion behavior remain public-release gates.

All 143 bundled catalog creatures and 12 local custom bases retain their existing four authored poses and bounded atlas loader. Private generated packs also contain four poses. This does not add separate walk/fly clips or a visual body/colour editor. See [subscriber artwork design/status](SUBSCRIBER_CUSTOM_FIGHTERS.md) and the [local avatar contract](CUSTOM_AVATARS.md).

## Service and capability checks

At **2026-09-26 21:45:41 UTC**, the isolated v2 service reported `enabled: true`, `configured: false`, monthly allowance 3 and subscription required. Health and privacy returned 200, unauthenticated library returned 401, and the legacy battle route returned 404. At 21:45:42 UTC its database-backed challenge endpoint returned the expected non-secret response shape. These read-only probes did not authenticate an Apple user or call the image provider.

The isolated service uses a separate artwork API base URL and custom routes/tables, but shares the existing Railway PostgreSQL connection. A separate database is not claimed. Ordinary battle/narration traffic continues to its existing service; the new deployment does not expose legacy battle routes. The 22:03:01 UTC isolation record confirms the original checkout HEAD/status remain unchanged and 65 deployed backend fingerprints match. A final read-only remote check confirms `release/1.1.7` still points to `107bf7327f1c82e85282101e2294fb6f9ded3639`; the sanitized release evidence retains both check times.

Apple's capability record confirms Sign in with Apple is enabled for the canonical bundle. The actual archive/export also passed the corresponding signed entitlement and embedded-profile checks, together with the existing capabilities. A capability setting does not prove the actual device account flow.

## Retained artifacts

Paths are relative to the v2 worktree; generated binaries and detailed logs remain ignored locally.

- Final QA: `ios/build/QA-2.0-113-3ae7a43f.json`.
- Phone: `ios/build/runs/20260926T214227Z-test-2.0-113-3ae7a43f-ed7360/`.
- Tablet: `ios/build/runs/20260926T214929Z-test-2.0-113-3ae7a43f-aec4d3/`.
- Fresh upgrades: `ios/build/runs/20260926T214403Z-upgrade-8e5fda/`.
- Backend: `ios/build/release-tools/backend-113-frozen/` (run, source-before/after and test log).
- Service: `ios/build/release-tools/backend-v2-live-113.json`; deployed source fingerprints: `ios/build/release-tools/backend-source-113.json`.
- Apple capability: `ios/build/release-tools/apple-signin-capability-113-enabled.json`.
- Final native review: `ios/build/release-tools/native-visual-review-113-3ae7a43f.json`.
- Signed archive / inspection: `ios/build/runs/20260926T215842Z-archive-2.0-113-3ae7a43f-24c13f`.
- Local IPA / export evidence: `ios/build/release-tools/export-113-3ae7a43f`.
- Upload / warning evidence: `ios/build/release-tools/upload-113-3ae7a43f`.
- Apple read-back / maintenance: `ios/build/release-tools/testflight-2.0-113-final.json`; `ios/build/release-tools/isolation-113.json`; `ios/build/release-tools/docs-113/maintenance-final-113-verified.json`.

The app's own dSYM is present. Upload reported missing vendor dSYMs for GoogleMobileAds and UserMessagingPlatform. The archive retained warnings for the unassigned legacy AppIcon child, SpeechService capture semantics and skipped App Intents metadata extraction. These are recorded; the release is not described as warning-free.

## Owner testing

Open TestFlight → Animal vs Animal → **2.0 (113)** and use [the owner checklist](OWNER_TESTFLIGHT_CHECKS.md). First verify retained progress/PIN/tournament state, then real Sign in with Apple and existing subscription purchase/restore/account linkage. The Sandbox service is now configured for the authorized one-request pilot: sign in with Apple, establish Sandbox Premium, and explicitly confirm one benign request such as Robot. Its real account, receipt and generated-output checks remain pending. Do not treat fixture screenshots as accepted live-generated artwork.

Physical installation, sustained motion/memory, accessibility, real receipts, App Attest/narration, iCloud/Game Center, permissions, audio/haptics and eligible ads remain owner checks. Broader external testing and App Store submission are outside this internal-beta delivery.
