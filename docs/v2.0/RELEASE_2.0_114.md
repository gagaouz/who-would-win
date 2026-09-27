# Animal vs Animal 2.0 (114) — Fighter account sign-in fix

**September 27 artwork follow-up:** The owner’s real sign-in/subscription-linked Trump request succeeded and was privately saved at 01:07:22 UTC after the server fix. Build 114 remains current. See the [artwork rejection fix and its measured limits](CUSTOM_ARTWORK_REJECTION_FIX.md); earlier activation and inherited backend evidence below are historical.

**Animal vs Animal 2.0 (114) is available in internal TestFlight.** At **2026-09-27 00:15:50 UTC**, Apple reported the exact candidate `VALID`, `INTERNAL_ONLY` and `IN_BETA_TESTING`, present in the existing `self` group; its English testing notes matched on read-back. Update to **114** to retry fighter-account sign-in. Owner installation and live account acceptance remain unverified.

Build 113 sent fighter-account authentication requests to the legacy battle backend, where those routes return 404. That response appeared as “Your fighter library is temporarily unavailable.” Build 114 sends challenge, Apple token exchange, sign-out and account-deletion requests to the dedicated private artwork service. Saved account credentials now use the same service origin and app-bundle namespace in Keychain. The game, artwork, private-library interface and backend implementation are otherwise unchanged.

Three new regression methods exercise the production URL builder, reject unsafe origins/unknown paths, and verify service/bundle separation for saved credentials. The existing three account-state tests remain. These checks address the routing mistake that the configured-URL and synthetic UI checks in build 113 did not detect; they do not prove successful real Apple authorization.

## Candidate and validation

| Field | Evidence / pending result |
| --- | --- |
| Version / build | **2.0 / 114** |
| Frozen candidate | `4eb736ee41fca8d6e678e629a515bb3f92b3e81b` on `develop/2.0` |
| Canonical app | `com.whowouldin.WhoWouldWin`; same installed app |
| Full phone suite | **90 passed, 0 failed, 0 skipped**: **76 unit + 14 UI** |
| Focused tablet suite | **11 passed, 0 failed, 0 skipped**: **6 account unit + 5 custom-library UI** |
| Fresh 1.1.7 → 114 synthetic upgrades | **Both fresh cases passed**, using the tested 114 phone app; loaded progress, preferences, Documents, cold baseline and Keychain PIN preserved. Rendered home accepted after cold relaunch with 1,234 coins and the six-day streak. |
| Backend carry-forward | Build 113's **80 passed tests**, not rerun for 114; backend tree remains exactly `27906a67a70fe3934f7e6d119bf9e15931776579`, with file fingerprints checked |
| Artwork/layout carry-forward | Build 113's **45 accepted still captures**, not new 114 screenshots; view/model/render/resource tree objects and all 35 raw atlas hashes remain identical |
| Fresh 114 visual review | **Six tablet custom-library stills accepted**; synthetic fixtures only. No new battle/share review or live Apple/provider claim. |
| Live service probes | September 26, 2026, **23:57:12 UTC**: enabled/configured, allowance 3, subscription required; health/privacy 200, private library 401 without auth, legacy battle 404; challenge response shape checked |
| Signed archive / IPA | **Passed** canonical identity, dedicated artwork configuration, entitlement/profile, DEBUG exclusion and artwork checks; retained IPA SHA-256 `77911a71f1966b2e70c60fd74210be47458d660b76b5279de96b97281f68e7e0` |
| Upload / Apple availability | Upload succeeded **2026-09-27 00:12:02 UTC**; Apple upload date **00:13:14 UTC**. Build `e8661d5a-ac0c-4cd7-9109-8d82473414de`; `VALID` / `INTERNAL_ONLY` / `IN_BETA_TESTING`, existing self-group access and notes verified **00:15:50 UTC**. External state `NOT_APPLICABLE`. |
| Maintenance isolation | **2026-09-27 00:10:45 UTC:** original checkout HEAD/status unchanged; remote `release/1.1.7` remains `107bf7327f1c82e85282101e2294fb6f9ded3639`. |

Inherited evidence is limited to the unchanged backend and presentation/assets. It does not carry forward working authentication from build 113. Its reviewed custom packs are synthetic, and still captures do not prove playback or sustained physical-device performance. The two fresh upgrade cases were isolated simulator installations, not the owner's physical TestFlight upgrade or receipt/iCloud state. The accepted native runs total **101 test executions**; repeated tablet methods are not additional distinct coverage.

The first 114 phone/tablet runs (`20260926T235517Z`, suffixes `369726` / `be24c3`) and the initial upgrade attempt ending `5d6af4` were interrupted by host disk exhaustion. They are retained and excluded from acceptance. Replacement runs used the same frozen source and passed all 90 phone and 11 tablet cases. Upgrade attempt `639de6` failed before validation because the selected reuse run did not contain its own baseline app; it is retained and excluded. Replacement `9618f5` used the verified original baseline app and passed both cases. None of these failed attempts is counted as an accepted run.

## Owner test

Update the existing app to **2.0 (114)** through TestFlight. **Do not erase game data or reinstall.** Confirm progress, parental settings and the current tournament remain, then open **My Fighters → Fighter account → Sign in with Apple**.

After sign-in, activate or restore Premium through TestFlight's Sandbox flow and explicitly create **one friendly fighter such as Robot** through the grown-up gate and OpenAI consent. This pilot is already authorized. Check idle, windup, attack and reaction poses, one-credit accounting, the saved library entry and reuse in battles. If it fails, retain the message instead of repeatedly retrying.

The service is configured for the purchaser-only Sandbox beta with three successful creations per UTC month and the existing $5 lifetime application ledger / $1 paid-attempt reservation. Production creation remains off. **Real device Apple sign-in, subscription association, and a live generated four-pose sheet remain unverified.** Existing typed custom fighters remain available. Physical-device account deletion/restore, receipts, cloud services, accessibility and sustained performance remain owner/public-release checks.

## Evidence paths

- Final QA: `ios/build/QA-2.0-114-4eb736ee.json` (all required internal-beta checks passed).
- Fresh tablet visuals: `ios/build/release-tools/visual-114-tablet/visual-review.json` (six captures, scoped acceptance).
- QA assembler and inputs: `ios/build/release-tools/readiness114/assemble_qa_114.py`, `inputs114.json`.
- Replacement phone: `ios/build/runs/20260927T000047Z-test-2.0-114-4eb736ee-edde63/`.
- Replacement tablet: `ios/build/runs/20260927T000047Z-test-2.0-114-4eb736ee-b7beeb/`.
- Fresh upgrade: `ios/build/runs/20260927T000403Z-upgrade-9618f5/`.
- Live service: `ios/build/release-tools/backend-v2-live-114.json`.
- Testing notes: `ios/build/release-tools/what-to-test-114.txt`.
- Signed archive: `ios/build/runs/20260927T000843Z-archive-2.0-114-4eb736ee-87ca10/WhoWouldWin.xcarchive`.
- Export: `ios/build/release-tools/export-114-4eb736ee/export-evidence.json`.
- Upload: `ios/build/release-tools/upload-114-4eb736ee/upload-evidence.json`.
- Apple and notes: `ios/build/release-tools/testflight-2.0-114-final.json`.
- Maintenance: `ios/build/release-tools/maintenance-final-114.json`.

The [sanitized build 114 evidence](evidence/testflight-2.0-114.json) records these scopes and artifacts. The retained IPA identifies the inspected local export; upload used the same archive with internal-only distribution and fixed build numbering. No invitations, external-group changes or App Store submission were made. Upload retained the GoogleMobileAds and UserMessagingPlatform vendor dSYM warnings; this release is not claimed warning-free.

Earlier [build 113 history](RELEASE_2.0_113.md) and its [provider activation evidence](evidence/custom-fighter-activation-113.json) remain unchanged.
