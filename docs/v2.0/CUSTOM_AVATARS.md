# Local custom avatars

The owner chose custom artwork without recurring image-generation charges. Version 2.0 therefore creates a retro avatar on the device from bundled artwork. It does not call an image provider, send a name to an additional service, or require an image API credential. Existing battle narration and custom classification behavior are unchanged.

## Appearance contract

- Keep the existing custom animal ID and name. Artwork is a presentation detail; it cannot change battle identity, coins, eligibility, wagers, or results.
- Recognizable animal/type words select an appropriate bundled form. Explicit color words may adjust its palette while retaining readable outlines and shading.
- Names without a recognized type receive a stable fantasy avatar. These are playful avatars, not a promise to depict every arbitrary name or fictional character exactly.
- Twelve dedicated forms supplement the complete 143-creature catalog: robot, knight, wizard, superhero, slime, mushroom, tree, alien, winged cat, rock golem, sea serpent, and ghost.
- Normalization and a stable digest make the same name choose the same appearance across relaunches and devices. Existing random custom IDs remain independent of appearance selection.
- Pixel art is bundled. Creation and recreation work offline; memory caches are disposable. No download, server retention, or migration of saved tournaments is needed.
- Portraits, arena actors, and shared cards use the same renderer. In build 111, a custom avatar keeps its source form's authored pose set when one is available. Other forms use the appropriate anatomy-based motion family.
- Custom image-cache keys include the requested pose. All poses share a family-wide render scale and baseline, preventing a sprite from changing size as it attacks. The bounded cache remains memory-only and can be rebuilt offline.

## Source and validation

`ios/WhoWouldWin/Retro/RetroSpriteManifest.json` includes `customBases` with source rectangles and archetypes. Three generated atlas originals were visually inspected and copied unchanged into the asset catalog. Measured crops contain no pixels from neighboring characters. Exact generation prompts and source provenance are under `art-prompts/`.

Acceptance checks cover recognized names, unfamiliar names, punctuation, Unicode normalization, long names, distinct identities sharing a name, cache recreation without network, two-custom battles, custom versus catalog, all share renderers, and saved 1.1.7 custom entrants. Native validation evidence is recorded in the implementation and release ledgers; this specification alone does not mark those checks passed.

The abandoned paid-service prototype was removed from the release branch before any live image API calls or deployment. Backend source and dependencies remain unchanged from the 1.1.7 baseline.

## Build 111 motion evidence

The catalog now has 18 authored four-pose sets and 125 creatures using eight procedural anatomy families. Custom recipes reuse those forms or one of the twelve custom bases; recoloring does not collapse an authored set into one static image. Tests exercise pose-cache separation, consistent rendering, anatomy assignment, bounded meshes, and Reduce Motion bypass. Native custom battle and share captures were reviewed alongside production-scene motion contact sheets.

See the [build 111 release record](RELEASE_2.0_111.md) for actual source states and test results. Saved custom entrants remain compatible through unchanged model/service paths and the prior build 110 upgrade evidence; this iteration did not repeat an actual upgrade installation. No live image API request or backend deployment is needed for local artwork.
