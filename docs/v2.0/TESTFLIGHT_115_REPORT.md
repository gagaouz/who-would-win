**Animal vs Animal 2.0 (115) — available in internal TestFlight**

Candidate: `72d542c7b973072b55f273ec76c4b4519c7738ae` on `develop/2.0`. Apple verified the exact build as VALID, INTERNAL_ONLY and IN_BETA_TESTING at 2026-09-27T10:21:45.749939+00:00. The existing self tester group contains the build, and the published en-US testing notes were read back successfully. Physical installation by the owner and public release readiness are not claimed.

This build brings the Miami arcade palette, shared pixel lettering, angular controls, cream panels and playful animated home logo across the game. The home carousel offers five random matchups: swipe or use the arrows, then tap to battle with the displayed fighters. The regular picker and Surprise Me remain available. Longer collection/shop labels, champion brackets and exported result layouts were adjusted to retain their content.

Verified evidence:

- **108 native test executions passed:** 76 unit tests plus 16 UI tests on iPhone 17, and the same 16 UI tests on iPad Air 11-inch (M4). These represent 92 distinct methods, with no failures or skips. Both final r3 runs have identical clean source fingerprints before and after execution.
- **110 final UI captures reviewed:** 55 per device, covering home navigation, picker, collection/facts, settings, commerce, parental controls, tournaments, sharing, battles and the custom library. Four complete share PNGs per device were also inspected: **8 exports**, representing duel, team, tournament and custom results. These counts include repeated views; they do not imply 118 distinct screens. No blocking visual defect was recorded in this tested scope.
- **Fresh strict 1.1.7 fixture upgrade passed:** the actual final Testing app preserved loaded state, preferences, Keychain PIN and documents for both settled and pending scenarios, including cold-launch checks and container relocation. The post-upgrade home was inspected. This used an isolated simulator fixture with original persistence code, not the owner's canonical App Store installation.
- **Artwork retained and revalidated:** all 143 catalog fighters and 12 local custom bases have authored pose sets. The manifest, renderer/resources, 35 raw atlases and five asset-catalog atlas sets match build 114 exactly. Changed views received fresh review; their appearance was not inherited from 114.
- **Backend checks carried forward through exact source identity:** all 90 tracked backend files match tested runtime `72aeef18`; its retained log records 145 passing tests. These were not rerun for build 115. Read-only endpoint probes confirmed configured subscriber creation, allowance 3, served privacy, private-library authentication and isolation from legacy battle routes. No paid generation or new Apple login was performed by this QA.
- **1.1.7 remains protected:** post-push checks confirm the original checkout, working-state hash and remote `release/1.1.7` remain at baseline `107bf7327f1c82e85282101e2294fb6f9ded3639`. Legacy Railway deployment `dfefd10c-edaf-4391-812d-27418c99c182` and the separate artwork deployment remained unchanged and successful. Existing native services, models, view models, animal data, entitlements and Release configuration match build 114.

The accepted record is `ios/build/QA-2.0-115-72d542c7-final.json`. Final native/visual records are under `ios/build/visual-pivot/final-phone-r3` and `final-tablet-r3`; upgrade evidence is under `ios/build/runs/20260927T100238Z-upgrade-52862c`. Superseded successful runs, interrupted r2 attempts and the first blocked QA assembly are retained and excluded from final acceptance.

**Distribution verified**

- Signed archive and canonical bundle/version inspection passed from the frozen source above.
- The internal IPA export passed inspection, including complete source-matched artwork. SHA-256: `0f2a2ca41de705c4c7716bc8a87a70ca32cbe3160dd15f65cbc6a8d5dc050f66`.
- Upload completed successfully once, after confirming build 115 was unused across marketing versions.
- Apple processing, internal tester access and final testing-note readback passed. ASC build: `32381f30-cf55-49f8-aed1-bfd8c06bc96e`.
- No external tester group, invitation or public App Store submission was changed. The same missing GoogleMobileAds/UserMessagingPlatform framework dSYM warnings seen in 114 were non-blocking; the app dSYM is present. These limit symbolication within those third-party SDKs.

The [compact release evidence](evidence/miami-arcade-115-release.json) binds the QA, export, upload and Apple availability records by SHA-256. [Post-upgrade home preview](evidence/miami-home-115.png) is an isolated simulator capture with synthetic saved data.

Physical owner checks remain: install over the existing app without erasing data; verify progress, PIN and interrupted tournaments; exercise real Sandbox purchase/restore, Premium and saved fighters; check iCloud/Game Center, permissions and narration; and inspect VoiceOver, larger text, Reduce Motion, background/resume and sustained battle performance on hardware. Fixture storefront values and synthetic custom packs do not verify live purchases, account authorization or provider output. The uncertain-request screenshot shows the state after a fresh, explicitly approved request; the preceding returned-credit state is established by test assertions.
