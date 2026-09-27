**Animal vs Animal 2.0 (119) — available in internal TestFlight**

The Fact of the Day card had 8–8.6pt pixel headings separated by only one point, a small portrait, and readable 16pt prose squeezed into a narrow column. Build 119 gives the portrait a 56pt tile, separates the headings, increases the animal name to 12pt pixel type, and places the fact beneath the header across the card’s full width. Both name and fact can wrap with larger text. Redundant portrait accessibility is hidden and the informational text is grouped together.

Only `KidsHomeView.factOfTheDayCard` changed in app code. Shared reading typography, date-based fact selection, carousel/navigation logic, artwork, rewards, Leo’s tribute, persistence and backend source remain identical to 118. The iOS version/allocation changes are release metadata. Runtime source is `0c00051403b15540546a2da5dcfaac9174480fea` on `develop/2.0`.

Fresh checks:

- Eight passing executions of three existing UI methods: carousel/selection, exact displayed battle selection and tournament return on phone and tablet, plus tournament return at native accessibility-extra-large on each device. No failures or skips; no new test method was added. Source, app and test-product provenance were checked, and original simulator text sizes were restored.
- All 20 actual screenshots were independently reviewed. The complete changed card passes at default and larger text sizes on both devices: its fact uses two lines on the default phone, one on the default tablet, four on AX3 phone and three on AX3 tablet. Headings, portrait, full ending text and card padding remain separate.
- Final QA `ios/build/QA-2.0-119-0c000514-final.json` has SHA-256 `feb2d6cd4d7653492512b5978253190b751938278fb464def4fea94c0e8d032c`. The scoped source proof allows no other app change. Historical 118 whole-app/tribute evidence, 117 paragraph AX3 evidence, 116 persistence-upgrade evidence and 145 backend tests are retained at their original source, not described as fresh 119 runs. The one uncommitted 118 preview is excluded from the eight final executions.

This is acceptance of the changed card. Existing unrelated AX3 phone progress labels and tournament-setup headings still truncate or wrap, and scrolled content can underlap the status area. Those unchanged regions are recorded as limitations, not newly approved by this card fix. Captures use today’s Tabby Cat fact; other device widths, orientations, names, VoiceOver order and physical-device behavior remain owner checks.

Original 1.1.7 local status and local/remote maintenance head remain unchanged at `107bf7327f1c82e85282101e2294fb6f9ded3639`. Read-only checks confirm unchanged successful Railway deployments and expected public API boundaries. No paid generation or user-account mutation was performed for QA.

The signed archive is `/Users/home/WWW/who-would-win-v2.0/ios/build/runs/20260927T200713Z-archive-2.0-119-0c000514-24cf9c/WhoWouldWin.xcarchive`. Production inspection confirms correct identity/version, no DEBUG fixture markers or test bundles, and a matching app dSYM. The inspected internal-only IPA has SHA-256 `abc13373148255824937338ec517b505d2a2218d752934c88c0a4f0a4bd20ea5`. A fresh all-versions check confirmed 119 unused before the one successful upload.

Apple verified build `82cdc9df-b78e-4600-9f5b-fcb2e4db4e75` at `2026-09-27T20:14:00.851089+00:00` as VALID, INTERNAL_ONLY and IN_BETA_TESTING, present in the existing `self` group. Testing notes were read back exactly. No external group or tester invitation changed; an owner-device installation is not claimed.

Xcode reported nonblocking missing-symbol warnings for `GoogleMobileAds.framework`, `UserMessagingPlatform.framework`. The app’s own dSYM matches the archived executable; upload succeeded and Apple accepted the build. These warnings limit third-party framework symbolication.

Install 2.0 (119) over the existing app without deleting data. Check Fact of the Day at your normal text size and a larger setting. The detailed artifact hashes are in [daily-fact-119-release.json](evidence/daily-fact-119-release.json).
