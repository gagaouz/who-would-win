# Animal vs Animal 2.0 (110) — internal TestFlight release

**Ready for the owner to install through TestFlight.** Apple processing and access were verified on September 26, 2026, at 16:36 UTC. The game is retro throughout, with animated battles, all 143 catalog sprites, and custom avatars rendered locally without image-service charges.

## Distribution evidence

| Field | Verified result |
| --- | --- |
| App / canonical bundle | Animal vs Animal / `com.whowouldin.WhoWouldWin` |
| Version / build | **2.0 / 110** |
| App Store Connect build | `45e26632-f537-4f2b-bf55-897742c476c1` |
| Processing / audience | `VALID` / `INTERNAL_ONLY` |
| Internal testing state | `IN_BETA_TESTING` |
| Existing internal group | `self`, all-build access, exact candidate present in its build list |
| What to Test | English notes published and read back successfully |
| Export compliance | `usesNonExemptEncryption: false`; no blocking compliance state reported |
| Expiration | December 25, 2026, 16:33:09 UTC |
| Actual owner installation | Pending; no physical device was connected |

Xcode reported upload success at 16:32:14 UTC. Apple recorded the upload at 16:33:09 UTC and subsequently completed processing. [Sanitized verification](evidence/testflight-2.0-110.json) records the exact candidate and notes. Existing external groups were not changed, invitations were not sent, and no App Store submission was made.

## Source and maintenance

The archive was built from clean, published `develop/2.0` commit **`583b5e54a3f6fb6279705dacb50465197318ce67`**. The tested native commit is `ebcc38ed81b7745434bbd1760efe4780ae94e3ee`; the only subsequent change before archiving was the synthetic upgrade harness. Shipping app, artwork, generated project, configuration, and both test-target trees have matching Git object IDs, retained in the QA record. Later documentation commits do not change the uploaded binary.

The maintenance branch `release/1.1.7` remains at `107bf7327f1c82e85282101e2294fb6f9ded3639`. The original checkout's pre-existing dirty status matches its saved NUL-delimited snapshot. No original files were stashed, reset, cleaned, or included in v2 commits. [Branching and hotfix instructions](BRANCHING.md) describe independent maintenance and forward-porting fixes. Build 110 is now used; check App Store Connect again before choosing the next build number on either line.

Backend source and dependencies exactly match that maintenance baseline. Railway and Netlify production triggers were inspected as main-only before publishing the v2 branch. This release required no backend deployment.

## Validation completed

| Check | Final result |
| --- | --- |
| iPhone 17 / iOS 26.5 simulator | 41 unit + 9 UI tests passed |
| iPad Air 11 / iOS 26.5 simulator | 5 targeted UI tests passed |
| Unchanged shipping backend | 46 tests passed |
| Synthetic in-place 1.1.7 upgrade | Pending and settled cases passed |
| Bundled artwork | 143/143 catalog creatures, 12 custom bases, 20 atlases, no missing entries |
| Signed archive and local IPA | Identity, production configuration, capabilities, privacy manifest, strict signing, artwork, and absence of DEBUG fixture markers checked |

There were **55 native test executions**, with zero failures or skips; this is not 55 distinct test methods, since iPad repeats selected scenarios. The final tests cover accepted-result animation, once-only settlement, cancellation, stale rematch responses, reduced motion, all-eight-member teams, local custom recipes/identity/cache rebuilding, success fixtures and offline fallback, broad screen rendering, actual tournament dismissal, and share exports. Source/callback preservation was reviewed separately. The original [feature inventory](FEATURE_PARITY.md) is not a claim that every live feature combination was exercised.

The upgrade harness extracted actual 1.1.7 source and replaced only startup with an isolated synthetic fixture host; original persistence models and services remained in use. It verified durable disk state and a cold baseline relaunch before installing 2.0. Both final cases retained every captured preference, loaded store state, custom entrant, wager/result settlement guard, Documents sentinel, and synthetic Keychain PIN. Installation legitimately relocated the data-container UUID; assertions followed the returned container. No state was copied back into or reseeded in the candidate. These are simulator checks, not actual App Store receipt, iCloud, or owner-device upgrade checks.

## Retained artifacts

Paths below are relative to the v2 worktree. Build outputs are ignored locally; the sanitized final evidence is committed.

- QA record: `ios/build/QA-2.0-110-583b5e5.json`.
- Signed archive and inspection: `ios/build/runs/20260926T162807Z-archive-2.0-110-583b5e54-f591ca/WhoWouldWin.xcarchive` and adjacent `archive-inspection.json`.
- Phone tests: `ios/build/runs/20260926T161058Z-test-2.0-110-ebcc38ed-0b10c7/Tests.xcresult`. The same directory contains `tablet-final/Tests.xcresult`, `tablet-final-exports/Tests.xcresult`, and reviewed capture folders.
- Upgrade report: `ios/build/runs/20260926T162110Z-upgrade-71d167/upgrade-report.json`.
- Shipping backend tests: `ios/build/backend-tests-583b5e5.log` and `ios/build/backend-compatibility-final.json`.
- Inspected local IPA: `ios/build/export-2.0-110-583b5e5-r2/Export/WhoWouldWin.ipa`. SHA-256: `78d8478d0a5742f7769b7d905364d0fa9362abaa31bbfe68ec1d377de1671622`.
- Upload evidence/log: `ios/build/upload-2.0-110-583b5e5/`. Xcode exported the same canonical archive for upload with internal-only distribution and automatic build renumbering disabled. The inspected local IPA hash is not a claim that Apple's uploaded export is byte-identical.
- Final Apple read-back: `ios/build/beta-2.0-110-verified.json`.

The app's own dSYM is present. Xcode requested symbol upload and completed successfully, but emitted missing-dSYM warnings for the unchanged GoogleMobileAds and UserMessagingPlatform SDKs. Those SDK symbols are not claimed as supplied; Apple nevertheless validated and enabled the candidate for internal testing. Compiler diagnostics also remain in untouched SpeechService, test SDK compatibility, and an unassigned legacy icon asset. Successful checks do not imply warning-free compilation.

## Owner acceptance

Open TestFlight → Animal vs Animal → **2.0 (110)** and use the [owner testing checklist](OWNER_TESTFLIGHT_CHECKS.md). Record current progress before installing over 1.1.7: the separate source branch does not create a separate app/data installation.

Actual upgrade, purchases/restore, App Attest and live narration, Game Center/iCloud, microphone/notification permissions, sound/haptics, eligible ad lifecycle, accessibility, older supported iOS versions, and sustained physical-device performance remain pending. No physical iPhone/iPad was attached. Broader distribution should follow those checks and any resulting fixes.
