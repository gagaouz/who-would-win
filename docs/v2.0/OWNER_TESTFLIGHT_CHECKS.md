# Owner checks for the internal 2.0 beta

**2.0 (111): Animal vs Animal 2.0 (111) is available in internal TestFlight. Apple reports VALID, INTERNAL_ONLY, and IN_BETA_TESTING; the exact candidate is present in the existing self group.** Open TestFlight → Animal vs Animal → **2.0 (111)**. See the [current release record](RELEASE_2.0_111.md); [build 110](RELEASE_2.0_110.md) remains documented separately.

Build 111 native checks passed at the documented source states. The two disposable simulator upgrades were performed for build 110 and carried only for unchanged persistence paths; no actual build 111 upgrade was performed locally. No physical iPhone or iPad was attached to the development host, so the checks below require the owner's device and account. They remain pending until observed; passing simulator fixtures does not stand in for StoreKit, iCloud, or a real upgrade.

## Before installing

- Record the current coin balance, unlocks, stickers, achievements, parental settings, and any active tournament. A device backup is useful because TestFlight uses the same app identity as the App Store version.
- Install the exact 2.0 build identified in the final release record. The separate `release/1.1.7` Git branch protects source maintenance, not a device's saved data.

## First session

1. Confirm the recorded progress and active tournament remain present. Check the parental PIN and restore-purchases flow with the existing account.
2. Play a normal duel, a rematch, a daily challenge, and a team battle. Background the app during a battle, return, and confirm a single result/reward.
3. Try a custom animal such as Blue Lion, a fantasy name such as Ice Dragon, and an unfamiliar name. Each receives a stable local retro avatar. Artwork works offline; existing narration/classification availability still follows the game's established network/fallback behavior.
4. Resume or start a tournament, place a permitted wager, try full and quick matches, and finish a bracket. Confirm settlement and champion rewards happen once. Check that parental wagering restrictions still apply.
5. Share a duel, team result, and tournament. Verify the exported card matches the participants and result.

## Build 111 visual checks

- Compare a lion/tiger/shark/eagle battle with creatures such as cheetah, owl, spider, fish, or slime. Eighteen catalog creatures use authored poses; the other 125 use body motion from eight anatomy families. Look for motion appropriate to the anatomy, stable scale, clear attacks, and readable team rosters.
- Try Blue Lion, Ice Dragon, and an unfamiliar custom name. Authored source poses should survive custom recoloring; other forms should animate through their motion family. Avatar creation works offline without an image API charge; ordinary gameplay costs and narration network behavior remain unchanged.
- Inspect home, selected picker/arena tiles, shop, parent controls, tournament history, results, and shared cards for readable text and comfortable rounded buttons. Try Reduce Motion, background/resume, and several consecutive 4v4 battles.

## Device/account capabilities

- Restore real entitlements and confirm owned packs/no-ads/subscription status. Test new purchase behavior only through the intended sandbox/TestFlight flow; do not use consumable purchases to probe ordinary navigation.
- With the relevant accounts signed in, check Game Center and iCloud synchronization on the devices you normally use.
- Check narration, sound, haptics, notification permission/reminders, and ad consent/reward behavior where eligible.
- Try VoiceOver, larger text, Reduce Motion, and the smallest/largest supported devices available to you. Look for clipped labels, unreadable buttons, or slow play after several battles.
- Record any issue with build number, device/iOS version, route, expected result, and what happened. Screenshots or a recording are useful, but avoid exposing a PIN or account details.

Do not expand to external testers or public release until these capabilities and any reported defects have been reviewed. The beta itself is not a public App Store submission.
