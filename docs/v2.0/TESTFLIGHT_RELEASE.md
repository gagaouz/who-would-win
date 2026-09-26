# Animal vs Animal 2.0 — TestFlight release gates

**Current build 111:** Animal vs Animal 2.0 (111) is available in internal TestFlight. Apple reports VALID, INTERNAL_ONLY, and IN_BETA_TESTING; the exact candidate is present in the existing self group. See [2.0 (111)](RELEASE_2.0_111.md) for the refreshed motion/UI and exact source/test provenance. New native runs passed 59 + 53 + 5 + 2 executions across the recorded commits, with zero failures/skips. Prior build 110 backend and strict upgrade results are carried only for unchanged source; no actual build 111 upgrade was run. Owner physical/account acceptance remains pending.

**Earlier verified internal beta:** [2.0 (110) release record](RELEASE_2.0_110.md). At **2026-09-26T16:36:11Z**, Apple reported the exact build `VALID`, `INTERNAL_ONLY`, and internally `IN_BETA_TESTING`; the owner's `self` group contains the candidate and has all-build access. The build is available through internal TestFlight. External testing is `NOT_APPLICABLE`; no public release is included.

Build 110 evidence comprises **55 native test executions** (41 unit, 9 iPhone UI, 5 targeted iPad UI), **46 backend tests**, and **two in-place synthetic upgrade cases**, all passed. Archived source is `583b5e5`; app/project/config/test trees are identical to tested native source `ebcc38e`. Owner installation and physical-device/account acceptance remain pending; see the [owner checklist](OWNER_TESTFLIGHT_CHECKS.md). Passing these measured checks does not mark every planned matrix scenario tested.

Original planning audit: September 26, 2026. The observations below describe the read-only source/toolchain audit before implementation; no build, test, signing operation, upload, deployment, or ASC account inspection was performed **by that initial audit**. Subsequent execution is documented in [release readiness evidence](RELEASE_READINESS_2026-09-26.md) and the final release record above. Credential contents were not recorded in these documents.

The owner wants the **entire app to become retro in 2.0**, with existing functionality preserved. There is no classic presentation option. Loading, reduced-motion, missing-art, and offline fallbacks must also remain intentionally retro: a static sprite, restrained effect, or temporary pixel silhouette. A fallback cannot remove custom creatures or prevent a battle from completing.

Related documents: [implementation plan](PLAN.md), [branching and hotfix workflow](BRANCHING.md), [feature parity inventory](FEATURE_PARITY.md), and [retro architecture](RETRO_ARCHITECTURE.md).

## 1. Checked local state versus unknown live state

The audit read the committed iOS/backend baseline in `/Users/home/WWW/who-would-win`. The 2.0 worktree was subsequently created from its maintenance tip; these observations describe the baseline before implementation.

| Item | Evidence observed | Meaning / remaining check |
| --- | --- | --- |
| Current source version | `ios/WhoWouldWin/Info.plist`: **1.1.7 / 109** | Source metadata only; current ASC build availability and highest used build number remain unverified. |
| Generator version | `ios/project.yml`: **1.1.6 / 108** | **Release blocker:** generation can revert the source version and reuse an old build number. Reconcile before running XcodeGen. |
| App identity | `com.whowouldin.WhoWouldWin`; same configured development team in project and export settings | Preserve for canonical upgrade/TestFlight build. Profile capability coverage is unverified. |
| Toolchain | `xcodebuild -version`: **Xcode 27.0 / 27A266a**; `xcrun --sdk iphoneos --show-sdk-version`: **27.0** | Current installed toolchain meets the cited Apple SDK minimum. Actual archive validation is still required. |
| Supported OS/devices | Project target **iOS 16.0**, device families iPhone and iPad | Only iOS 26.5 simulator runtime was available at audit time. Oldest supported OS/device and current OS coverage must be arranged. |
| Local tooling/access | `xcodegen` present; `security find-identity` reported **2 valid signing identities**; configured upload credential file exists | No proof of distribution profile, credential validity/role, active membership, agreements, or tester access. Private material was not inspected. |
| Swift packages | Tracked `Package.resolved` pins Google Mobile Ads **13.9.0** and User Messaging Platform **3.1.0** | Project requirements permit later compatible versions. Release resolution must use the reviewed lockfile; upgrades need their own validation. |
| Schemes/CI | No tracked shared `.xcscheme` or CI workflow found | Add a reproducible shared scheme including both test targets and a documented required-check path. |
| iOS tests | **13 unit-test methods**, **one UI smoke test** in source | Not executed by this audit; not comprehensive parity coverage. The smoke test can contact production and passes on fallback. |
| Backend tests/build | `npm test` compiles TypeScript and runs `node --test test/*.test.js`; lockfile present | Execute in isolated test configuration during implementation. Historical claims of passing tests do not establish this candidate passes. |
| Upload script | `ios/deploy.sh` exists; `ExportOptions.plist` uses `app-store-connect`, destination `upload`, automatic signing, symbol upload | Existing script is not a release gate; see section 3. |
| App capabilities | Release App Attest environment `production`; Game Center and iCloud key-value-store entitlement present | Verify canonical archive/provisioning and physical-device behavior. CarPlay entitlement is intentionally absent and its source excluded. |
| Backend configuration | App hardcodes production API in `AppConfig.swift`; diagnostics disabled in app source | Separate staging configuration is required. Actual deployed environment, service health, and diagnostics settings were not inspected. |
| Live distribution | No authenticated ASC inspection in this audit | Existing builds, review state, owner tester eligibility, group auto-distribution, account agreements, products, and processing errors remain unknown. |

Apple requires iOS/iPadOS SDK 26 or later for uploads from April 28, 2026. Its September 14, 2026 release notes explicitly accept Xcode 27 / iOS 27 SDK builds for App Store and internal/external TestFlight. Recheck these requirements at release time. [Apple SDK minimum](https://developer.apple.com/news/?id=ueeok6yw) · [App Store Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)

## 2. Protect maintenance releases and allocate versions deliberately

Use `release/1.1.7` for maintenance and `develop/2.0` in this worktree for retro development. A future public maintenance patch may have marketing version `1.1.8` or another appropriate value; the branch name does not require reusing 1.1.7. The 2.0 marketing version belongs only on the v2 line.

Before a release on **either** line:

- Inspect actual ASC build history, the local [build/version ledger](BRANCHING.md#buildversion-ledger), pending uploads, and the other line's reserved build number. Do not assume `110` is unused just because the baseline plist says `109`.
- Allocate and record a unique increasing build number across both lines as an operational convention. The ledger records version, build, branch, commit, archive path, upload attempt, and processing outcome. A failed/uncertain upload is reconciled before retry; do not blindly reuse its identifier.
- Verify marketing version/build agree in the maintained source, generated project configuration, application plist, and final archived binary. Prevent XcodeGen from reverting either field.
- Build from a reviewed release commit with no uncommitted product changes. Preserve unrelated user work in other worktrees. Do not use blanket staging, cleanup, or reset to obtain a clean release tree.
- Forward-port relevant maintenance fixes into v2 with their source SHA and regression case, recording any deliberate equivalent implementation. Never merge v2 back into maintenance.
- Use distinct DerivedData, archives, export directories, logs, local ports, and simulators. Worktrees do not isolate fixed output paths or remote services.
- Inspect GitHub/Railway/hosting branch triggers before publishing the new branch. Confirm that pushing v2 cannot trigger production deployment. This live configuration was not checked by this audit.

An archive is a source recovery artifact; it is not proof that downgrading device data or a backend database is safe. Recovery plans must address each separately.

## 3. Replace implicit upload assumptions with explicit release stages

The current `ios/deploy.sh` bumps the local plist before archiving, synchronizes only the build number into `project.yml` after successful upload, uses fixed archive/log locations, and does not enforce a branch, clean source, tests, or archived metadata verification. Its introductory credential comment differs from its actual configured credential. Do not run it unchanged as the v2 release procedure or concurrently in two worktrees.

Implementation must provide these separately reviewable stages:

1. **Preflight:** correct branch/commit; version allocation; reviewed package locks; app identity; supported toolchain; profile/capability availability; account/agreements; intended environment; intended tester group; production-trigger isolation.
2. **Verify:** deterministic suites, feature matrix, upgrade fixtures, asset validator, device capabilities, performance/accessibility evidence, and backend compatibility checks.
3. **Archive:** Release configuration to a unique path named by version/build/commit. Save full logs and archive/dSYMs. Validate command exit status; do not infer success only from filtered output.
4. **Inspect archive:** actual embedded version/build, bundle ID, distribution entitlements, App Attest environment, resources, privacy manifest, signing, symbols, and intended API configuration. Fail on mismatch.
5. **Upload:** one deliberate upload using the checked archive and normal ASC distribution. Preserve exact logs and upload identity. A standard distribution upload can later be assigned to internal testing; do not inadvertently create an internal-only archive if the same artifact is intended for later external testing or App Store consideration.
6. **Verify processing/access:** check Apple's actual build state, resolve processing/compliance failures, assign the intended owner group, and confirm installation availability. Upload exit status alone cannot satisfy this stage.

No public App Store version submission or release is part of the TestFlight completion milestone.

## 4. Identity, upgrade, iCloud, and commerce gates

The canonical 2.0 beta retains the existing app bundle, StoreKit product IDs, Game Center configuration, App Attest identity, and iCloud key-value-store entitlement. Preserve stable animal IDs and current persistence keys unless an explicit, versioned, tested migration is unavoidable.

**Installing the canonical TestFlight app replaces the App Store 1.1.7 app on that device.** Apple also documents that selecting a previous beta build replaces the currently installed build. Separate worktrees provide no device-data isolation. Use a separate baseline device or an explicitly isolated development bundle for parallel development; the latter cannot prove canonical upgrade, purchase, or cloud behavior. [Apple TestFlight installation and previous-build guidance](https://testflight.apple.com/)

Automated synthetic upgrade/model/state checks block the internal beta. Canonical physical upgrade, real receipts, iCloud and device-only capabilities are explicit owner acceptance checks after internal TestFlight installation when no hardware is available here. They are required before broader release; they must remain marked **Not tested** until performed. This avoids making owner installation depend on tests that require that installation.

Required evidence, with those two phases recorded separately:

- [ ] Capture representative 1.1.7 fixtures before conversion: fresh user; free user with progress/coins and recorded custom-creature usage; earned/coin-unlocked content; each purchased entitlement; current and expired subscriber; collections/achievements; interrupted and settled tournaments including custom entrants; parental settings; cloud-backed state. No existing favorites or standalone saved-custom library was found; do not invent an upgrade fixture for an absent feature.
- [ ] Upgrade fixtures in place to the canonical 2.0 bundle and compare actual stored/displayed values. Test fresh installation separately. Never erase the owner's state to simplify a test.
- [ ] Preserve reward and consumable transaction idempotency through backgrounding, retries, interruptions, restore, and repeated result presentation.
- [ ] Test StoreKit purchase success, pending approval, cancellation, failure, restore, subscription expiration/revocation, no-ads, paid packs, bundles, and consumables with the existing product IDs.
- [ ] Verify iCloud reconciliation with stale cloud data, two devices, no iCloud account, offline upgrade, later reconnect, and intentional settings differences.
- [ ] Verify original PIN/parental gates, wagering setting, notifications, speech permissions, audio/haptics settings, and progress remain effective after upgrade.

`CloudSyncService.swift` currently uses maximum values for coins/progress, true-wins for many permanent unlocks, unions for achievement-related arrays, and per-key maxima for win counts. Sticker collection (`collected.animals`), melee ownership, tournament saves, and other persisted keys are not in the tracked lists. These choices require fixtures; they do not establish complete backup, correct spend reconciliation, or safe downgrade. Keep fixes to existing compatibility defects isolated and regression-tested.

TestFlight apps use Apple's purchase sandbox; subscriptions renew on an accelerated schedule. Use separate controlled test accounts/data when exercising commerce and cloud restoration. Current true-wins unlock flags mean a sandbox-earned unlock must not be mistaken for a verified production entitlement or silently contaminate the owner's production-state assessment. [Apple TestFlight In-App Purchase guidance](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight/)

## 5. Local custom artwork and existing backend compatibility

**Updated scope from the owner:** custom sprites are made entirely on-device from an approved bundled sprite kit using a stable name-aware recipe. No paid per-custom image API, provider credential, new hosted sprite endpoint, or sprite-service deployment is part of 2.0. The experimental unreleased backend sprite code must be removed before the candidate is frozen. Existing narration still uses the existing backend, with its established offline fallback.

Required evidence:

- [ ] Every native catalog ID has valid bundled artwork; no known creature is accidentally left on a placeholder. Validate the shipped manifest against the actual iOS roster and inspect atlas crops visually.
- [ ] Custom names deterministically produce appropriate local sprite recipes without changing the original custom Animal identity. Case/whitespace/Unicode normalization is stable; distinct meaningful inputs and style/recipe versions have correct cache behavior.
- [ ] Local custom rendering works offline on first creation, with bounded memory/work, valid dimensions and transparency, and no provider credentials or paid image request. Existing content moderation and custom-creation coin rules remain intact.
- [ ] Battle stage, picker/portraits, tournament/melee, and exported share images use the same custom visual identity. Erase-data clears custom rendering cache/state as specified; rematch/cancellation cannot display stale art.
- [ ] A renderer or asset failure retains an intentional retro fallback and cannot strand a battle, change its accepted winner, or duplicate rewards. Reduced Motion retains a meaningful static retro presentation.
- [ ] Review backend source against the maintenance baseline, preserving `/api/battle`, `/api/battle/quick`, `/api/battle/melee`, `/api/animal`, attestation/reporting and existing fallback contracts. Run existing compatibility tests without production traffic or paid AI calls.
- [ ] Release configuration keeps the existing production narration API; fixture tests block external services. No service deployment or environment mutation is required for local sprites.

Archive QA requires explicit `localCustomArtworkPassed` and `backendCompatibilityPassed` evidence. The former means actual local rendering and related integration checks passed; a placeholder-only implementation cannot satisfy it. The latter establishes that maintenance clients and existing backend behavior remain compatible, not that an unnecessary new service has been deployed.

## 6. Validation matrix and internal-beta boundary

Every item below requires a linked result, artifact, screenshot, trace, or exact test case in the implementation evidence ledger. An unexecuted check remains **Not tested**. Source inspection alone does not satisfy runtime behavior. Automated correctness, available simulator parity/upgrade tests, complete local artwork, unchanged backend compatibility, and archive metadata/signing block owner internal TestFlight. Hardware-only validation is an explicit owner acceptance stage after the beta is available; it blocks broader external/public distribution, not the requested internal beta.

| Area | Required coverage and acceptance |
| --- | --- |
| Entire retro app | All routes and relevant interaction states in `FEATURE_PARITY.md` reachable and usable; no unfinished screens or classic theme switch. Long-form text remains readable. |
| Art coverage | All current catalog IDs and all nine arenas represented; current expected catalog count is 143 and must be reconciled against source. Review silhouettes, alpha edges, frame bounds, facing, scale, wings/tails, and pixel crispness. |
| Custom creatures | Multiple substantially different names/anatomies, long/punctuated names, stable identity, rejected content, deterministic local recipes, offline first creation, cache/erase behavior, restart, valid rendered/exported sprites, and playable retro fallback. Custom creatures are not restricted to demo assets. |
| Battle integrity | Solo/quick, rematch, next challenger, tournament, and melee from 1v1 through 4v4; visuals end at the authoritative winner/team and terminal health. No scripted prototype outcomes in production. |
| Lifecycle/accounting | Cancel/skip/replay, navigation mid-animation, background/foreground, rapid rematches, interrupted tournament resume and settlement, no duplicate coins/records/achievements. |
| Existing services | Facts, sharing, sticker book, achievements/trophies, shops/unlocks, leaderboards/Game Center, settings, permissions, narration/audio/haptics, parent gates and reminders. |
| Network | Distinct explicit online and offline assertions; cached, timeout, authentication, quota, unavailable service, malformed response, and missing/corrupt artwork cases. Passing via fallback does not prove online success. |
| Upgrade/commerce/cloud | Synthetic 1.1.7 state and model compatibility pass before internal beta; physical canonical upgrade/real receipts/iCloud remain explicit owner checks, with sandbox and production evidence distinguished. |
| Layout/accessibility | Supported phones/tablets, iPad orientations, large text, VoiceOver labels/order/result announcements, touch targets, contrast, non-color cues, independent audio/haptics controls. Reduced motion disables shake/flashing and uses static or restrained retro states. |
| Performance | Compare measured baseline on representative and oldest supported hardware; assess cold start, frame rate, 4v4 overlap, memory/cache bounds, package size, battery/thermal load, and at least 20 sequential battles for leaks. Browser demo smoothness is not native evidence. |
| Physical capabilities | Release-signed device behavior for App Attest, StoreKit, ads, iCloud, Game Center, speech/microphone, notifications, audio and haptics. Simulator limitations remain explicit. |
| Release artifact | Deterministic iOS/backend checks passed for the frozen source; reviewed package pins; correct privacy manifest/disclosures for the actual local artwork implementation; archive metadata/signing/capabilities verified. |

No unresolved critical/high-severity regression is acceptable. Low-severity limitations require explicit ownership, impact, and a recorded decision; cosmetic polish cannot excuse lost functionality or untested data preservation.

## 7. TestFlight distribution workflow

1. Verify the existing app record, current uploaded versions/builds, owner tester access, eligible role, agreements, and intended tester group. Check whether group automatic distribution could expose an unfinished candidate beyond the intended audience.
2. Freeze the candidate commit and record its check results. Reserve the build number, archive once into a unique location, inspect the artifact, and retain its dSYMs/logs.
3. Upload the inspected archive. Monitor ASC until processing completes; resolve export-compliance or validation issues instead of treating the upload response as completion.
4. Add clear beta description, feedback contact, and build-specific **What to Test**. Document known low-severity limitations, current feature coverage, upgrade expectations, and specific failure-reporting instructions.
5. Prefer the owner's eligible internal group for this owner-testing milestone. Assign the processed build and verify the owner's account/group can install it. Apple documents build assignment and a 90-day testing window. [Internal tester workflow](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
6. Keep this candidate restricted to the owner internal group. External beta review, public links/additional groups, and App Store submission are outside this milestone and remain unavailable until separately approved and their remaining validation is completed. Apple documents the separate external-review flow. [External tester workflow](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
7. Record the actual processing status, assigned group, owner access, and availability timestamp. A general public invite or unrequested expansion to additional testers is not required for this milestone.
8. Run a final physical-device smoke on the distributed candidate where device access permits. Owner installation/acceptance is separately recorded; if the owner has not installed yet, say **available to install**, not **owner tested**.

Providing beta information and assigning groups have ASC role requirements; inspect current access early, without assuming the presence of an upload key grants all account operations. [Beta test information](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/) · [Assign testers to builds](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-testers-to-builds/)

## 8. Exact completion definition and handoff

The TestFlight milestone is complete only when **all** of the following are evidenced:

- The entire retro app, catalog/custom paths, and every existing feature in the parity matrix are implemented; required automated/internal-beta regression and synthetic upgrade checks pass for the frozen source, with unperformed hardware checks explicitly assigned to owner acceptance.
- No critical/high-severity defects, destructive untested migrations, placeholder screens, or missing feature routes remain. Temporary retro art is a deliberate tested failure state, not a substitute for the working local custom sprite renderer.
- The canonical **2.0 / allocated build** archive is tied to its source commit and retained with logs, symbols, dependency locks, and verification results.
- Apple processing/compliance checks have succeeded and the exact build is assigned to the appropriate owner-accessible group, with internal distribution only; no external/public release is included.
- **The owner can install the processed build in TestFlight.** This does not require pretending the owner has already installed or accepted it. Report owner-install confirmation as a separate status.
- The owner receives the actual app/version/build, TestFlight access route, commit, completed test matrix, known low-severity limitations, and feedback instructions. No public App Store release has been performed as part of this milestone.

Suggested owner test route: verify retained progress/purchases; create an unusual custom creature; run a normal battle and quick/next-challenger flow; exercise a tournament and 4v4 melee; inspect collections/facts/share output; test settings/parent gates/reduced motion; repeat with network unavailable. Record observed results against the supplied build rather than the browser prototype.

The current candidate's exact source, artifacts, distribution state, measured validation, and handoff details are in [RELEASE_2.0_111.md](RELEASE_2.0_111.md). The [build 110 release record](RELEASE_2.0_110.md) preserves its earlier distribution and actual upgrade evidence. Owner installation/acceptance, physical upgrade, StoreKit/account behavior, iCloud, permissions, accessibility, and device performance remain explicitly pending where not exercised; internal availability does not imply owner acceptance.

The objective is measurable readiness and recoverability. A plan cannot guarantee zero defects; a passed and documented set of release gates can make mistakes easier to detect before the owner receives the beta.
