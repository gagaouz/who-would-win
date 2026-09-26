# Owner checks for the internal 2.0 beta

**2.0 (112): Animal vs Animal 2.0 (112) is available in internal TestFlight. At 2026-09-26 20:19:50 UTC, Apple reported VALID, INTERNAL_ONLY and IN_BETA_TESTING; the exact candidate is present in the existing self group and its What to Test notes were read back.** Open TestFlight → Animal vs Animal → **2.0 (112)**. See the [current release record](RELEASE_2.0_112.md); [build 110](RELEASE_2.0_110.md) and [build 111](RELEASE_2.0_111.md) remain documented separately.

Build 112 passed 70 native executions at frozen `9eec02b` and two fresh strict synthetic 1.1.7 → 112 simulator upgrade cases. No physical iPhone/iPad was attached, so the checks below require the owner's device and account. They remain pending until observed; passing simulator fixtures does not stand in for StoreKit, iCloud or a canonical App Store-to-TestFlight upgrade.

## Before installing

- Record the current coin balance, unlocks, stickers, achievements, parental settings, and any active tournament. A device backup is useful because TestFlight uses the same app identity as the App Store version.
- Install the exact 2.0 build identified in the final release record. The separate `release/1.1.7` Git branch protects source maintenance, not a device's saved data.

## First session

1. Confirm the recorded progress and active tournament remain present. Check the parental PIN and restore-purchases flow with the existing account.
2. Play a normal duel, a rematch, a daily challenge, and a team battle. Background the app during a battle, return, and confirm a single result/reward.
3. Try a custom animal such as Blue Lion, a fantasy name such as Ice Dragon, and an unfamiliar name. Each receives a stable local retro avatar. Artwork works offline; existing narration/classification availability still follows the game's established network/fallback behavior.
4. Resume or start a tournament, place a permitted wager, try full and quick matches, and finish a bracket. Confirm settlement and champion rewards happen once. Check that parental wagering restrictions still apply.
5. Share a duel, team result, and tournament. Verify the exported card matches the participants and result.

## Build 112 visual checks

- Compare several land animals, birds, snakes, sea creatures, arthropods, small pets and fantasy fighters. All 143 catalog creatures and 12 custom bases now have individually drawn idle, anticipation, attack and reaction poses. Look for stable scale, clear attacks and readable team rosters. This four-pose action cycle does not claim dedicated walk or flap clips.
- Try Blue Lion, Ice Dragon and an unfamiliar custom name. The selected form's authored poses should survive custom recoloring. Artwork works offline without an image API charge; ordinary gameplay costs and narration network behavior remain unchanged. The optional Body · Colour · Extras editor is only a proposal and is not present in build 112.
- Try Reduce Motion, background/resume, rematch and consecutive 4v4 battles. Confirm the displayed result, rewards and tournament settlement remain correct. Inspect shared duel/team/tournament/custom cards for consistent identity and readable content.
- Continue checking the bright interface, shops, parent controls and bracket history for readable text and comfortable controls on your device.

## Device/account capabilities

- Restore real entitlements and confirm owned packs/no-ads/subscription status. Test new purchase behavior only through the intended sandbox/TestFlight flow; do not use consumable purchases to probe ordinary navigation.
- With the relevant accounts signed in, check Game Center and iCloud synchronization on the devices you normally use.
- Check narration, sound, haptics, notification permission/reminders, and ad consent/reward behavior where eligible.
- Try VoiceOver, larger text, Reduce Motion, and the smallest/largest supported devices available to you. Look for clipped labels, unreadable buttons, or slow play after several battles.
- Record any issue with build number, device/iOS version, route, expected result, and what happened. Screenshots or a recording are useful, but avoid exposing a PIN or account details.

Do not expand to external testers or public release until these capabilities and any reported defects have been reviewed. The beta itself is not a public App Store submission.
