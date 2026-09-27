# Custom artwork rejection incident — September 27, 2026

> Later follow-up: the Moon Knight refusal exhausted conservative budget holds; creation was restored by an audited provisional reconciliation. See the [availability fix](CUSTOM_ARTWORK_AVAILABILITY_FIX.md) for the current deployment and remaining provider limitations.

This server patch addresses the rejected requests reported from TestFlight 2.0 (114). The installed native app and its public API contract are unchanged. The server fix is live, and the owner’s actual Trump request reached `ready` with a privately saved original and runtime sheet at **01:07:22 UTC**. Final deployment `eb4a0a53-8645-46cf-ab35-062c277c1496` from `00f3f1eb2237457d60e4dc1eba61fd79603a77a0` was verified successful at **01:23:45 UTC**. Health/privacy/status and Apple challenge checks passed; unauthenticated library access remains 401. See [the incident evidence](evidence/custom-artwork-rejection-fix.json).

## What the live records establish

At 00:26:31 UTC, Tree, Sonic and Trump each had one completed image-generation usage entry and a terminal `quality_rejected` result, before semantic review. Pikachu had a durable image dispatch followed by `content_rejected`, with no image usage returned: the image provider refused that request. All four customer credit reservations had been released, and no library assets had been published. The three earlier generated images were not retained, so their exact mechanical failure cannot be retrospectively established.

The fresh Tree pilot reproduced a real false rejection: its action pose ended at x=509 inside its source cell. The old 12px margin rule rejected it even though the entire drawing was present; the normalizer can safely supply the missing display padding. A fresh Trump image revealed a second layout issue: its complete action hand crossed the internal x=512 grid boundary. Cutting fixed quadrants truncated that hand and copied part of it into the reaction cell.

## Changes

- Normalize complete source drawings before applying the unchanged native-compatible runtime bounds and density checks. Small pixel sprites can enlarge with one shared nearest-neighbor scale; dense drawings within the requested bounds are accepted.
- Extract four distinct, complete characters without cutting them at internal grid boundaries. Reject actual outer-canvas clipping, missing/merged characters, ambiguous detached content and duplicate poses. Preserve source PNG bytes separately from normalized runtime output.
- Use subject-appropriate pose instructions for trees, objects and amorphous mascots. Keep input/output moderation and all semantic approval fields.
- Validate the complete semantic-review schema before interpreting safety results. Missing or malformed fields cannot become an accusation that the subject was inappropriate.
- Record bounded internal failure stage/reason labels. A refusal after subject screening uses build 114's existing artwork-failure message, with the credit returned; provider prose and diagnostics are not exposed through the public job DTO.
- Add an operator pilot that uses the production adapters and the shared budget ledger without creating accounts, receipts, customer jobs or library assets. Unique run IDs cannot replay paid requests. Existing originals can be revalidated without another image-generation call.

## Verification and remaining limitation

Real operator requests generated accepted Tree and Sonic packs, with original/pose moderation and semantic review passed. Their exact originals also pass the final whole-character normalizer offline; their first live reviews used the preceding normalizer. The existing Trump original passed the final normalizer, all moderation and a fresh semantic review after clarifying that human caricatures are judged as cartoon concepts, not by real-person facial identification. Every review flag remains enforced. All three approved sheets were visually inspected. The owner then generated and saved a fresh Trump pack through the deployed app service, providing a real authenticated, subscription-linked publication result.

Pikachu was refused by the external generator under both standard and a bounded trial of the documented low moderation preset. The latter reported `moderation_stage: output`; no image or usage was returned. The final service retains standard `moderation: auto`. This patch does not claim Pikachu now succeeds, bypass the refusal or substitute another character. The historical Pikachu error was corrected to the downstream-artwork message; its name had passed input screening. See [the official image moderation documentation](https://developers.openai.com/api/docs/guides/image-generation#content-moderation).

The final geometry/provider/worker changes passed 120 automated tests before the successful-publication budget settlement follow-up. The final combined suite, including successful-publication settlement, passed **126 tests, zero failures and zero skips**. A test teardown race was reproduced and fixed by awaiting actual PostgreSQL client close events; no assertions were removed. The first settlement-suite attempt exposed dependent disposable database fixtures after the service-isolation test; cleanup now truncates those related fixtures together, and the complete 126-test rerun passed.

The accepted pilot images are operator QA artifacts, not entries in the user's private fighter library and not proof of physical-device installation or battle playback. Failed historical requests do not automatically rerun. Creating a fresh request in the existing build uses the updated server after deployment.

## Budget and privacy

The application budget remains $5 for the lifetime beta, and customer allowance remains three successful creations per UTC month. An audited adjustment replaced three $1 holds for fully known completed image-only failures with conservative $0.10 holds each; it did not erase usage history or customer credits. All three Pikachu refusals retain their full unknown-charge holds. The initial audit is `455a804f-1f2e-4772-945e-21ac06714924` in `custom_fighter_budget_adjustments`. A further Trump attempt reached the old server at 00:42 UTC and was similarly reconciled under `35996580-756b-4b9d-a470-6f00fecc48c6`; its customer credit was returned. No budget limit was increased. The existing successful Trump hold was conservatively settled using the tested new helper under audit `b4aa5695-a1ec-4a1e-9a2d-ef483929c156`. Final retained exposure was $4.00 with $0.225639 accumulated usage estimates, one successful customer credit used and none reserved.

Pilot reservations share the customer ledger and preserve headroom for an owner request. Each completed known run retains at least $0.10, or twice its conservatively rounded token estimate when larger; incomplete or uncertain paid usage retains at least $1. Successful customer publication now applies the same conservative settlement only when both image and review usage are complete and valid; unknown or incomplete usage retains the full hold. Actual usage history is never reduced. These are application estimates, not invoice-confirmed charges or a provider-enforced billing cap. Rates were checked against [the official Flare model documentation](https://developers.openai.com/api/docs/models/gpt-image-2.5-flare).

Operator PNGs live only in ignored local QA directories after moderation; explicitly unsafe review output is not saved. Operator runs are separate durable diagnostic records. These local artifacts require manual deletion after inspection and are not covered by customer-library retention. No provider key, database URL, bearer token, owner ID or receipt is included in the checked-in evidence.

The original `release/1.1.7` worktree and original Railway backend must remain unchanged. Only `backend-v2` is eligible for this deployment.
