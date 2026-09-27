# Private custom artwork service

This implementation is disabled by default. Mock-provider and disposable local PostgreSQL tests do not demonstrate live provider access, accepted production artwork, App Review approval, or real paid-subscription restoration.

## Isolation and activation

Use a separate deployment with `SPRITE_ONLY_SERVICE=true`. In that mode the process exposes health, the private custom-fighter routes, and Apple account/subscription endpoints. It does not import the old battle/animal/App Attest modules or start their database cleanup timers. Existing clients continue to use the original service.

Generation requires all of:

- `SPRITE_GENERATION_ENABLED=true`, a PostgreSQL connection, and the server-only `SPRITE_OPENAI_API_KEY`.
- An authenticated owner and current verified Premium Apple transaction belonging to that owner.
- `SPRITE_ALLOW_SANDBOX=true` for the private TestFlight beta. Production additionally requires `SPRITE_ALLOW_PRODUCTION=true` and Apple's private key/key ID/issuer ID, as enforced by the auth service.
- Explicit parent-disclosure `consentVersion: "custom-art-v1"` in a new creation request.
- Capacity in both the owner's monthly allowance and the independent application budget.

`GET /api/custom-fighters/status` reports booleans only, never secret values. Disabling creation never removes authenticated library reads, downloads, reports, or deletion. `POST /status` accepts an optional signed transaction; no proof reports no active creation entitlement. Supplied invalid/unavailable proof returns the actual error instead of inventing an inactive result.

## Contract

All private endpoints require `Authorization: Bearer <sessionToken>` from the Apple account endpoints. Names are at most24 Unicode code points. IDs and idempotency keys are UUIDs. Accepted original and delivered PNGs are at most8MiB each.

- `POST /` accepts `{name,idempotencyKey,signedTransaction,consentVersion}` and returns202 `{job,allowance}`. An owner-scoped identical retry returns the same job before new entitlement/quota/feature gates. Reusing the key for a different name returns409. There is no retry that creates a new job silently.
- `GET /` returns `{fighters,jobs,removedAssetIDs,libraryEpoch}` in one transaction: up to100 private active fighters, the latest30 jobs created within90days, explicit owner-scoped deletion/quarantine tombstones, and a positive numeric account-library epoch. Clients apply tombstones and clear old-epoch local art; an absent list entry alone is never an implicit deletion. Account deletion increments the epoch before purging data, preventing another device from resurrecting its stale local copy after reauthentication.
- `GET /jobs/:id` returns `{job,fighter?}`. Job states are queued, generating, validating, ready, rejected, failed, reconciling, cancelled.
- `GET /:id` returns `{fighter}`; `GET /:id/sheet` returns the authenticated PNG, never a public URL.
- `DELETE /:id` erases the private asset and leaves an idempotency/deletion tombstone. Repeated deletion is safe. Deletion never refunds a successful creation allowance.
- `POST /:id/report` accepts a fixed reason: unsafe, wrong_subject, poor_quality, other. Unsafe reports quarantine the remote copy immediately. The client also removes its cached copy; reporting is not a promise of a staffed review queue.

Fighter fields are `id,name,createdAt,appearance,manifest,sheetPath`. `appearance` is `{schemaVersion:1,assetID,version:1,sha256}`. The manifest repeats these fields and adds `styleVersion:"retro-v1",width:1024,height:1024,archetype,frames`. The four512×512 cells are ordered idle, anticipation, attack, reaction in a2×2grid. `job.assetId`, `fighter.id`, and both `assetID` values are the same immutable UUID. Hashes refer to the delivered runtime PNG, not the retained original sheet.

## Provider and quality gates

The provider is fixed to OpenAI's image edit endpoint with one bundled, previously authored game-style reference, `gpt-image-2.5-flare-2026-09-08`, medium quality, 1024×1024, PNG, transparent background, n=1, and standard `moderation: auto`. The independent game input, whole-sheet, individual-pose and semantic safety checks remain mandatory. A bounded diagnostic trial of the documented low preset did not resolve a Pikachu output refusal, so the standard preset is retained. Clients cannot select models, endpoints, output sizes, references, arbitrary prompts, moderation or retry settings. The style reference is the unmodified shipped `retro_motion_wild` atlas; the build copies it into dist. Image API response streams are byte-limited and paid requests have a180second timeout; SDK retries are not used.

The workflow performs input moderation, bounded PNG decoding/pose checks, whole-sheet and individual-pose moderation, then a strict structured semantic review with `gpt-4.1-mini-2025-04-14`. Four different hashes alone do not establish four meaningful poses. Only a complete set passing every gate is published. The runtime PNG uses one family-wide scale and common baseline and passes the same alpha-density/bounds/distinct-trimmed-pixel criteria as the native installer. Archetypes match the native renderer exactly.

The source normalizer identifies four complete connected drawings and orders their centers into the requested 2×2 layout. Internal grid crossings do not cut anatomy. Bounded nearby detached details remain with their drawing; merged/missing characters, ambiguous or excessive detached content and actual outer-canvas clipping fail. Alpha ≤16 matte pixels are removed only in normalized output; accepted original PNG bytes are retained unchanged. Internal `failure_stage` / `failure_reason` labels distinguish generation, geometry, moderation and review failures without retaining provider prose or exposing diagnostics to clients.

No automatic repair is enabled in this beta: the permitted maximum of one repair is an upper bound, not a requirement to spend twice. Rejections and failures release the customer's reservation. A requested redesign is a separate explicit creation.

Official image-generation moderation settings and refusal-stage diagnostics rechecked September27,2026: [image generation](https://developers.openai.com/api/docs/guides/image-generation). Other schemas checked September26: [image edits](https://developers.openai.com/api/reference/resources/images/methods/edit), [moderation](https://developers.openai.com/api/docs/guides/moderation), [structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs).

## Accounting and recovery

`SPRITE_MONTHLY_ALLOWANCE` defaults to3 successful sets (operator range1–10). Every term uses a fixed UTC calendar month; accelerated sandbox renewals, monthly/annual product switches, and reinstalls do not reset it. One job may be active per owner and one provider workflow globally during the beta. At most10 creation attempts per owner per rolling day prevent repeated rejected requests from being free unlimited traffic.

`SPRITE_BETA_BUDGET_USD` defaults to a **lifetime $5 application reservation ledger**, not a monthly reset or a provider-enforced cap. Each new job reserves a conservative$1 for its image and semantic review. The reservation is released only when no paid dispatch was recorded. After dispatch it remains even when the provider fails or bills less, so the default permits at most five paid attempts. Returned token usage is stored separately as an estimate; absent usage must not be interpreted as zero actual cost. Increasing the cap is an operator action and requires a measured budget decision.

Any operator reconciliation must retain aggregate usage history, a conservative hold for completed known usage and the full hold for uncertain charges. The September27 incident adjustment is documented in `docs/v2.0/CUSTOM_ARTWORK_REJECTION_FIX.md` and the durable `custom_fighter_budget_adjustments` audit. It does not raise the $5 limit. `scripts/sprite-pilot.cjs` supports explicit, separately recorded operator diagnostics inside the same ledger, preserving $1 headroom for an owner request and never creating customer accounts/jobs/assets. A repeated run ID cannot replay. `--original` revalidates an existing ignored local PNG with only a review charge; source/image SHA values identify the exact inputs. These operator artifacts require manual cleanup after inspection.

The dispatch mark is committed before the provider call. If the process dies before dispatch, a lease expiry safely requeues the job. If it dies after dispatch, the job becomes reconciling, the customer allowance is released, and possible provider spend stays reserved. Such jobs never automatically call the provider again; an operator must inspect provider billing if reconciliation is needed. Worker claims, budget/quota reservations, publication and deletion use PostgreSQL transactions/advisory locks. Account row locks precede creation/publication, so a stale authorized request cannot publish into an erased account.

## Private storage and retention

This small beta stores bounded binary data in PostgreSQL bytea behind `FighterStore`: accepted original PNG, normalized runtime PNG, immutable manifest, and generation/model/consent provenance. No additional object-storage account is needed to test it. Each asset is bounded to16MiB across its two blobs, each owner to100 saved assets, and the initial global beta budget further bounds growth. Before expanding the beta, migrate the storage implementation to private object storage or qualify database backup/size/egress costs. Images are not placed in iCloud key-value storage or public caches.

Approved private assets remain until their owner deletes them. No public catalog promotion or cross-owner name deduplication is implemented. Parent account deletion cancels jobs, strips their names/usage, removes original/runtime blobs and metadata, and preserves narrowly necessary quota and duplicate-charge tombstones. The existing game coin ledger is never touched.

Hourly maintenance continues when generation is disabled. Failed/rejected/cancelled/reconciling job names and their name digests are scrubbed after7days (plus at most one maintenance interval); terminal operational usage and names are scrubbed after90days. Reports expire after90days. Quota rows older than the month containing90days ago are removed. Minimal owner/request IDs, terminal status, dates and billing/idempotency tombstones remain to prevent duplicate charges and creation-allowance resets; they contain no retained failed prompt or image. Backup expiry is an infrastructure setting and must be disclosed and configured separately. Never claim immediate deletion from historical backups.

Run `npm test`. Custom-fighter tests start and remove disposable localhost-only PostgreSQL clusters. They use synthetic art and mocked provider HTTP; no test needs or spends an OpenAI credential.
