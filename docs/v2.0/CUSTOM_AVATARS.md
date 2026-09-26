# Local custom avatars and private downloaded artwork

Build 112 reflects the owner's earlier choice of custom artwork without recurring image-generation charges. It creates a retro avatar on the device from bundled artwork. It does not call an image provider, send a name to an additional service, or require an image API credential. Existing battle narration and custom classification behavior are unchanged. Build 113 adds the private subscriber-library and generated-pack implementation described in [Subscriber-generated custom fighters](SUBSCRIBER_CUSTOM_FIGHTERS.md). Live provider generation remains unavailable and unverified; this does not change build 112's historical local-only behavior.

## Build 113 private-pack integration

[Build 113](RELEASE_2.0_113.md) is available in internal TestFlight from frozen `3ae7a43f`. A saved fighter can carry an optional immutable appearance reference while keeping its stable identity/name. The shared renderer resolves a verified installed owner pack first and retains bundled local fallback when art is unavailable. Older saved animals/tournaments decode without the optional field. A newly installed pack changes presentation, not battle outcomes or the existing local creation rules.

Generated packs are private account data and have four fixed pose cells. Downloads are bounded, authenticated, hash/manifest validated and atomically installed before the fighter enters the local roster. Cache invalidation follows library revision. Expired creation eligibility does not erase the downloaded pack; explicit sign-out hides the selected owner's library. Local erase and remote account deletion are distinct, and explicit tombstones/library epochs handle server-confirmed removals.

The 113 tests used synthetic packs made from existing bundled poses and simulated subscriber/API answers. They passed the scoped native/backend/upgrade checks and reviewed screenshots in the release ledger. No live image-provider credential, paid quality pilot, real Apple sign-in or subscription-linked generation has been qualified. The separate API creation allowance is 3 successful creations per UTC month during the purchaser-only Sandbox beta; existing typed-name local avatars still need no image API.

## Appearance contract

- Keep the existing custom animal ID and name. Artwork is a presentation detail; it cannot change battle identity, coins, eligibility, wagers, or results.
- Recognizable animal/type words select an appropriate bundled form. Explicit color words may adjust its palette while retaining readable outlines and shading.
- Names without a recognized type receive a stable fantasy avatar. These are playful avatars, not a promise to depict every arbitrary name or fictional character exactly.
- Twelve dedicated forms supplement the complete 143-creature catalog: robot, knight, wizard, superhero, slime, mushroom, tree, alien, winged cat, rock golem, sea serpent, and ghost.
- Normalization and a stable digest make the same name choose the same appearance across relaunches and devices. Existing random custom IDs remain independent of appearance selection.
- Pixel art is bundled. Creation and recreation work offline; memory caches are disposable. No download, server retention, or migration of saved tournaments is needed.
- Portraits, arena actors and shared cards use the same renderer. In build 112, every one of the 143 catalog bodies and 12 custom bases has individually drawn idle, anticipation, attack and reaction poses. A custom avatar keeps its selected body's pose set through recoloring and effects.
- Custom image-cache keys include the requested pose. All poses share a family-wide render scale and baseline, preventing a sprite from changing size as it attacks. The bounded cache remains memory-only and can be rebuilt offline.

## Source and validation

`ios/WhoWouldWin/Retro/RetroSpriteManifest.json` includes `customBases` with source rectangles and archetypes. Build 112 references 40 atlases, including 35 raw PNG resources in `Resources/RetroAtlases/` and five retained asset-catalog pages. All catalog/custom pose families pass native rectangle, distinct-pixel and authored-detection checks; crop/pose contact sheets were visually reviewed. Exact generation prompts and source provenance are under `art-prompts/`.

New raw pages use uncached bundle loading with a 32 MiB retained decoded-atlas LRU and detached crop buffers. The crop cache has its own limit; SpriteKit textures and other process memory are separate. Memory warnings purge without publishing a revision that would eagerly reinstall textures, and parent erase clears both caches. Cache/alpha/orientation/pixel-reload tests passed.

Acceptance checks cover recognized names, unfamiliar names, punctuation, Unicode normalization, long names, distinct identities sharing a name, cache recreation without network, two-custom battles, custom versus catalog, all share renderers, and saved 1.1.7 custom entrants. Native validation evidence is recorded in the implementation and release ledgers; this specification alone does not mark those checks passed.

For historical build 112, the earlier paid-service prototype was removed before live image API calls or deployment, and its backend tree matched 1.1.7. Build 113 intentionally adds a separate custom-only service, private custom tables and tests; do not apply that old unchanged-backend claim to the new subscriber feature. The deployment shares the existing PostgreSQL connection, not a separately verified database.

## Build 112 motion and compatibility evidence

All 155 source families now have four authored poses and use the same action-cycle contract as the original lion. This does not promise separate walking, flapping or multi-frame clips. Defensive procedural fallback remains for missing/invalid art; it is not counted as completed roster animation.

Frozen `9eec02b` passed 56 native unit tests, 9 phone UI cases and 5 repeated tablet UI cases. Tests include custom recipe/identity stability, pose-cache separation, common family scaling, four distinct rendered poses, cache pressure/reload and Reduce Motion. Native custom battles, all four share types and production-scene motion sheets were visually accepted. Two fresh strict synthetic 1.1.7 → 112 simulator upgrades preserved pending/settled tournament state including custom identity; real owner account/device acceptance remains pending.

See the [build 112 release record](RELEASE_2.0_112.md) for actual source/test/artifact evidence. No live image API request or backend deployment is needed for local artwork. The optional **Change look / Body · Colour · Extras** editor is [proposed only](CUSTOM_FIGHTERS_PROPOSAL.md); existing typed custom creation and gameplay rules remain unchanged.
