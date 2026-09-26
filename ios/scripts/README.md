# Local build and release tools

Run from this worktree. Nothing in these commands uploads, changes App Store Connect, or increments a version.

```sh
python3 ios/scripts/release.py preflight
python3 ios/scripts/release.py build
python3 ios/scripts/release.py test --only-testing WhoWouldWinTests
python3 ios/scripts/release.py test --only-testing WhoWouldWinUITests
```

Each operation writes full logs and `run.json` into a unique ignored `ios/build/runs/` directory. Tests create a dedicated simulator by default and retain it, shut down, for diagnosis. Reuse an explicitly chosen QA device with `--device UUID`; do not point test tooling at the owner's simulator. Simulator builds use Xcode “Sign to Run Locally” (`CODE_SIGN_IDENTITY=-`) so the simulator entitlement sections required by Keychain are present; this uses no private signing key or provisioning request. Testing uses its own `com.whowouldin.WhoWouldWin.uitesting` bundle, blocks external services, and never resets the canonical app's preferences. Fixture launches use `--uitesting --reset-test-data` and `AVA_FIXTURE_SCENARIO` (`battle-success` or `offline`). Unit tests block startup services without implicitly enabling UI fixture responses.

`config/Version.xcconfig` is the only version/build source. **2.0 / 110 is locally allocated**, backed by the read-only 16:00Z ASC check and `config/BuildAllocation.json`. Before upload, recheck current ASC history and maintenance allocations; new candidates must set the chosen version/build and save the allocation record with `version`, `build`, `ascVerifiedAt` and `evidence`. The evidence must refer to the actual check, not an assumed free number. Commit reviewed release changes before archiving.

Debug uses `http://localhost:3000`; Testing forces locally blocked HTTP and fixture service responses. Release uses the production API. For a staging development build, provide a reviewed `AVA_API_BASE_URL` build override; arbitrary runtime endpoint overrides are not accepted in distribution builds. Do not weaken Release App Attest or rename its canonical bundle.

After all automated/internal-beta [release gates](../../docs/v2.0/TESTFLIGHT_RELEASE.md) pass, create a QA JSON record outside the source tree with the exact `sourceCommit`, booleans `requiredChecksPassed`, `featureParityPassed`, `upgradePassed`, `localCustomArtworkPassed`, and `backendCompatibilityPassed` all `true`, `blockingDefects: 0`, and `evidence` references. Set `distributionScope: "internal-testflight"` and `physicalDeviceStatus` to the observed `"passed"` or `"pending-owner-testflight"`. The pending status requires a nonempty `ownerDeviceChecks` array that explicitly lists physical upgrade, real entitlement restore, iCloud, permissions and performance checks still to run after the owner installs the internal beta. No physical result may be invented. The archive command checks the record matches current clean source. These fields are attestations of completed work, not shortcuts to skip it. Custom artwork must render locally using the approved bundled sprite kit, preserve stable custom identities, support offline creation, and pass cache/recipe/erase checks. The existing narration backend stays unchanged; no new sprite service deployment is required.

```sh
python3 ios/scripts/release.py preflight --distribution
python3 ios/scripts/release.py archive --qa-record /absolute/path/to/completed-qa.json
python3 ios/scripts/release.py inspect-archive --archive-path /absolute/path/to/WhoWouldWin.xcarchive
```

Archive provisioning updates are disabled unless `--allow-provisioning-updates` is explicitly provided. The tools retain symbols and verify version/build, canonical identity, API environment, privacy manifest, signature, Game Center, iCloud, and production App Attest. Any later upload must use the reviewed archive, and completion still requires Apple processing plus owner installation availability.

Run `xcodegen generate --spec ios/project.yml --project ios` once after coordinating new source files with the implementation owners; review the generated project and shared scheme. Do not regenerate while another agent builds. All three configurations inherit version settings through their xcconfig files.

`asc_readiness.py` can inspect existing builds and beta groups through the configured account using read-only API calls. It requires Python's `cryptography` package, already available on the audited host. Pass a trusted existing credential configuration and an output path; no token, private key, or tester contact data is written to the report. Never use its findings as proof of owner installation without checking the exact membership/build assignment.

`Capture117Fixtures.swift` produces synthetic upgrade inputs when compiled with the 1.1.7 model sources. Checked-in fixture provenance names the original commit and file hashes. This proves old encoded models can be decoded by current tests; it does not replace the physical in-place upgrade, keychain, StoreKit, or iCloud checks.

`upgrade_simulator.py --candidate-app /absolute/path/to/Testing-iphonesimulator/WhoWouldWin.app` builds an archived 1.1.7 fixture host and installs the candidate over it on a newly created disposable simulator. It uses only a synthetic save, the isolated `.uitesting` identity, blocked network, and a known QA PIN; neither the owner's app nor original checkout is changed. Pass `--source-packages /path/to/DerivedData/SourcePackages` to reuse the existing package cache. The test compares both stored preferences and actual service-loaded state for pending and settled tournaments, including the custom entrant, rewards, collections, entitlements flags, and simulator keychain PIN. Optional snapshots require three guards: explicit capture environment flag, isolated app identity, and synthetic fixture marker. Physical canonical upgrades, real receipts, and iCloud are separate required checks.
