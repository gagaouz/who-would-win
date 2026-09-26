# Maintaining 1.1.7 while developing 2.0

## Isolated source lines

- Original checkout: `/Users/home/WWW/who-would-win`, branch `release/1.1.7`.
- New checkout: `/Users/home/WWW/who-would-win-v2.0`, branch `develop/2.0`.
- Exact common base: `107bf7327f1c82e85282101e2294fb6f9ded3639`.
- `git ls-remote` confirmed this was also the remote release branch tip on September 26, 2026.
- The original working-directory status was unchanged by the isolation work.
- The approved retro prototype was copied into `prototypes/retro-mode/` in the new checkout.
- Local planning commit includes only that prototype and `docs/v2.0/`.

No original files were stashed, reset, cleaned, moved, or included in the planning commit. In particular, unfinished Android work stays in the original checkout. Subsequent native implementation commits belong only to `develop/2.0`. The original prototype copy also remains available.

## Why a worktree

A worktree provides a second folder with its own branch and index while sharing repository history. It allows parallel builds and edits without repeatedly switching the user's dirty checkout between releases. A GitHub fork or a copied repository is unnecessary for this project.

Worktrees do not isolate remote backend services, device installs, signing identities, cloud data, production deployment triggers, or shared build paths. Those need separate configuration.

## Rules

1. All 2.0 implementation happens under the new path on `develop/2.0` or short-lived feature branches rooted there. The application is retro only in this line.
2. Keep `release/1.1.7` as the maintenance line. A new public maintenance release may have a newer marketing patch version; the branch name does not force reuse of 1.1.7.
3. Keep the same stable app identity for the final 2.0 TestFlight release. Use dedicated development identities only for deliberately isolated test builds.
4. Never merge `develop/2.0` back into the maintenance branch. Forward-port relevant maintenance fixes into 2.0.
5. Never `git add .` in the original checkout to capture a maintenance fix. Stage reviewed files/hunks only. Do not auto-commit pre-existing Android/web/marketing work.
6. Use separate DerivedData, archive, export, simulator, test-log, and local-server locations. Do not run the existing upload script concurrently across the two folders.
7. Before pushing a new branch, inspect GitHub/Railway/Netlify triggers. The September 26 read-only audit found Railway and Netlify production triggers restricted to `main`, with no Railway PR environments. See [release evidence](RELEASE_READINESS_2026-09-26.md). Push only the selected branch, never all branches/tags; recheck if integration configuration changes.
8. Once safely published, configure suitable required checks/protection on maintenance and 2.0 integration branches. A local branch is not a configured GitHub protection rule; none was claimed in this planning pass.
9. Keep backend changes additive and test both client generations. Deploy incompatible experiments only to a separate staging environment.

## Hotfix workflow

Start from the current maintenance tip, not from a v2 commit. When the original checkout is busy or dirty, make a third temporary worktree instead of switching it.

```sh
git -C /Users/home/WWW/who-would-win fetch origin
git -C /Users/home/WWW/who-would-win worktree add \
  -b fix/1.1.x-ISSUE \
  /Users/home/WWW/who-would-win-hotfix-ISSUE \
  origin/release/1.1.7
```

`ISSUE` is a deliberate placeholder for the actual fix. Make the smallest fix, add the relevant regression case, run that release's checks, and review the diff. Publish/release through the maintenance workflow. Record the actual source commit and chosen marketing version/build; do not assume that local branch state proves an App Store release.

Then forward-port the reviewed fix into 2.0:

```sh
git -C /Users/home/WWW/who-would-win-v2.0 cherry-pick -x HOTFIX_COMMIT
```

Resolve conflicts in favor of the intended behavior in the new architecture, not by blindly taking an entire old screen. Run the regression case plus affected v2 tests. Record the source and destination commit in the ledger below. A UI-specific maintenance patch may require an equivalent implementation rather than a literal cherry-pick; document why.

Do not use a mass merge simply to eliminate divergence, and do not silently drop hotfixes because a cherry-pick conflicts.

## Forward-port ledger

| Maintenance commit | Issue/regression case | 2.0 commit or equivalent | Verification | Status |
| --- | --- | --- | --- | --- |
| — | No post-split maintenance fix yet | — | — | None pending at creation |

## Build/version ledger

| Source | Version/build | Evidence | Status |
| --- | --- | --- | --- |
| Common base / iOS release commit `4ef855e` | 1.1.7 / 109 | ASC read-only audit September 26 | Valid build; App Store version ready for sale |
| Released internal candidate `583b5e5` | 2.0 / 110 | [Final release record](RELEASE_2.0_110.md) | Apple VALID; available to internal `self` group on September 26 |

The old XcodeGen version drift has been removed. Both generated project and Info.plist now read `Version.xcconfig`. The maintenance branch keeps its existing source/configuration; do not copy v2 version settings into a hotfix. Build 110 is now uploaded; recheck ASC history and allocate a new unused number for the next build on either source line.

## Recovery

The original maintenance worktree remains the source-code recovery path. Revert specific v2 commits or return to a known v2 checkpoint when needed; do not reset the shared repository or erase user changes. Preserve the native build/archive and test data at each accepted milestone. A source rollback does not guarantee safe rollback of device data or a backend migration, which must each be designed and tested separately.
