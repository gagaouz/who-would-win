# Owner checks for the internal 2.0 beta

**2.0 (113):** Animal vs Animal 2.0 (113) is available in internal TestFlight. At 2026-09-26 22:05:23 UTC, Apple reported VALID, INTERNAL_ONLY and IN_BETA_TESTING; the exact candidate is present in the existing self group and its English testing notes were read back. Open TestFlight → Animal vs Animal → **2.0 (113)**. See the [build 113 release record](RELEASE_2.0_113.md) and [sanitized evidence](evidence/testflight-2.0-113.json). [Build 112](RELEASE_2.0_112.md) and earlier releases retain their historical evidence.

Frozen `3ae7a43f` passed **97 accepted native executions** (73 unit + 14 phone UI + 10 repeated tablet UI), **80 fresh backend tests**, and **two fresh strict synthetic 1.1.7 → 113 upgrade cases**. Forty-five selected phone/tablet still captures were accepted. The earlier tablet timing failure and unchanged full rerun are retained in the release record. No physical iPhone/iPad was attached. These measured simulator checks do not establish canonical App Store-to-TestFlight upgrade, receipts, iCloud or live account behavior.

## Before installing

- Record the current coin balance, unlocks, stickers, achievements, parental settings, and any active tournament. A device backup is useful because TestFlight uses the same app identity as the App Store version.
- Install the exact 2.0 build identified in the final release record. The separate `release/1.1.7` Git branch protects source maintenance, not a device's saved data.

## First session

1. Confirm the recorded progress and active tournament remain present. Check the parental PIN and restore-purchases flow with the existing account.
2. Play a normal duel, a rematch, a daily challenge, and a team battle. Background the app during a battle, return, and confirm a single result/reward.
3. Try a custom animal such as Blue Lion, a fantasy name such as Ice Dragon, and an unfamiliar name. Each receives a stable local retro avatar. Artwork works offline; existing narration/classification availability still follows the game's established network/fallback behavior.
4. Resume or start a tournament, place a permitted wager, try full and quick matches, and finish a bracket. Confirm settlement and champion rewards happen once. Check that parental wagering restrictions still apply.
5. Share a duel, team result, and tournament. Verify the exported card matches the participants and result.

## Bundled animation checks retained from build 112

- Compare several land animals, birds, snakes, sea creatures, arthropods, small pets and fantasy fighters. All 143 catalog creatures and 12 custom bases now have individually drawn idle, anticipation, attack and reaction poses. Look for stable scale, clear attacks and readable team rosters. This four-pose action cycle does not claim dedicated walk or flap clips.
- Try Blue Lion, Ice Dragon and an unfamiliar custom name. The selected form's authored poses should survive custom recoloring. Artwork works offline without an image API charge; ordinary gameplay costs and narration network behavior remain unchanged. The optional Body · Colour · Extras editor is only a proposal and is not present in build 112.
- Try Reduce Motion, background/resume, rematch and consecutive 4v4 battles. Confirm the displayed result, rewards and tournament settlement remain correct. Inspect shared duel/team/tournament/custom cards for consistent identity and readable content.
- Continue checking the bright interface, shops, parent controls and bracket history for readable text and comfortable controls on your device.

## My Fighters and account checks

1. Open My Fighters from home and a fighter picker. New artwork should honestly report unavailable while the provider key is absent; existing typed-name local fighters remain available.
2. With a grown-up, test real Sign in with Apple, cancellation, sign-out, reauthentication and account recovery. The capability is enabled, but device authentication and private-library restoration are still unverified.
3. Test existing Premium purchase/restore and subscriber association through the intended Sandbox flow. The beta gives 3 successful creations per UTC calendar month, purchaser-only; local custom benefits are separate. Do not infer eligibility from a fixture screenshot.
4. Only after an approved live provider pilot is configured, verify typing/cancelled consent creates nothing; explicit parent+OpenAI confirmation creates once; closing/relaunching resumes the same request. An uncertain terminal result returns the customer credit and never automatically retries; a replacement needs fresh confirmation.
5. With authorized actual downloaded art, inspect all four poses and reuse in solo/team/tournament/share paths, offline and after creation eligibility expires. Verify another signed-in device restores the same private fighter without regeneration.
6. On dedicated test data, verify unsafe reporting, per-fighter deletion and account deletion across devices. **Erase game data** clears local/downloaded state and game progress; **My Fighters → Account** separately deletes the private online library. Apple grant revocation and managed-backup expiry remain public-release gates.

No paid provider result, real receipt-to-account association or live cross-device restoration has been established by the automated fixture tests.

## Device/account capabilities

- Restore real entitlements and confirm owned packs/no-ads/subscription status. Test new purchase behavior only through the intended sandbox/TestFlight flow; do not use consumable purchases to probe ordinary navigation.
- With the relevant accounts signed in, check Game Center and iCloud synchronization on the devices you normally use.
- Check narration, sound, haptics, notification permission/reminders, and ad consent/reward behavior where eligible.
- Try VoiceOver, larger text, Reduce Motion, and the smallest/largest supported devices available to you. Look for clipped labels, unreadable buttons, or slow play after several battles.
- Record any issue with build number, device/iOS version, route, expected result, and what happened. Screenshots or a recording are useful, but avoid exposing a PIN or account details.

Do not expand to external testers or public release until these capabilities and any reported defects have been reviewed. The beta itself is not a public App Store submission.
