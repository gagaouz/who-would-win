# Artwork availability follow-up — September 27, 2026

The 9:28 PM screenshot exposed two separate outcomes: Moon Knight was refused by the image provider's output moderation, and the following Devil request could not enter the queue because conservative global reservations had reached the beta limit. The customer's two remaining credits were intact. This follow-up keeps TestFlight 2.0 (114) and its saved fighters compatible.

## Cause and server change

The $5 lifetime application budget contained $1 of conservative holds for metered work and four $1 holds for image-provider refusals with no usage returned. These were reservations, not four confirmed $1 charges. The status endpoint previously advertised `enabled: true` without checking whether another request could reserve its budget, leaving Create active despite the service rejecting it.

The server now uses the same global headroom calculation for status and queue admission. Build 114 already uses `enabled` to disable Create; additional optional fields report creation availability and a reason for newer clients. Authenticated status continues returning the real customer allowance. Responses are not cached, and admission remains atomic under the shared ledger lock.

Fully metered terminal failures now settle excess reservations using complete usage for every paid stage that could have run. An image-only failure cannot settle after review started unless review usage is also present. Missing, duplicated, invalid, or uncertain usage retains its hold. Settlement is atomic and idempotent, never reduces historical cost, and can increase exposure when known charges exceed the original reservation.

Private failure diagnostics now distinguish a completed provider refusal from HTTP errors, timeout, transport failure, and malformed responses. They retain bounded operation/status/request-ID/moderation-stage facts, never raw provider prose or credentials, and are omitted from customer responses. Paid failures remain marked as billing unknown. Account erasure and 90-day diagnostic expiry clear them.

## Provisional cost reconciliation

An authenticated OpenAI Cost data export filtered to the dedicated beta key reported **$0.221872** across eight metered image generations and five semantic reviews. Its token totals matched the durable usage records. The CSV covers September 26–28 and was captured at 01:36:58 UTC; SHA-256 is `11449565cafe7bfe0bd594674d922fb7f8d04b5fa7ab26c58b7de904d7905ce7`. The private export stays in ignored local incident evidence.

The audited reconciliation retains all $1 of known conservative holds, which exceeds the $0.46 doubled-and-rounded reported-cost allowance, and retains a separate **$1 pooled reserve for the four unresolved refusals**. Each audited refusal carries one quarter of that pooled reserve. New uncovered requests retain their usual reservations. The reconciliation applied at 01:44:46 UTC reduced retained exposure from $5 to $2; the $5 application limit and the customer's credits are unchanged. Historical accumulated estimates remain $0.225639, slightly higher than the provider's current reported total.

This is provisional engineering accounting, not a determination that refusals are free or a guaranteed provider billing ceiling. The export has no final-billing marker. Later provider costs must be reconciled upward if they exceed retained exposure. The old per-request $1 hold was also an application estimate. Official documentation publishes [model token rates](https://developers.openai.com/api/docs/models/gpt-image-2.5-flare) and [refusal stages](https://developers.openai.com/api/docs/guides/image-generation#handling-blocked-requests-and-other-errors), but does not establish zero billing for these errors.

The adjustment is restricted to four exact terminal records, checks the complete request set and expected ledger totals under the shared lock, preserves every other hold, and records immutable before/after evidence under audit `3db35488-1e79-4367-97c8-ebc17d4b80fc`. It does not retry failed requests, create an account, alter a subscription, publish artwork, or consume a customer credit.

## Verification

The combined backend suite passed **145 tests, zero failures and zero skips**. Coverage includes paused status with two real remaining credits, restoration after available headroom, concurrent admission, complete versus unknown failure costs, idempotent settlement, private diagnostic validation/omission/erasure, and all existing backend regressions.

Runtime source is `72aeef1`. Deployment `6c2e308f-7ae7-4033-b786-db33741bfab4` succeeded. The live endpoint first returned `enabled: false` / `budget_exhausted`, then returned `enabled: true` / `creationAvailable: true` after reconciliation at 01:44:55 UTC. Repeating the audit ID returned `alreadyApplied: true` without another adjustment. The original `release/1.1.7` worktree and original Railway backend remain protected.

Moon Knight's name passed input screening, but the provider refused its generated output. There is no approved Moon Knight asset, and this patch does not claim that name now succeeds. The earlier successful customer Trump remains saved.

One bounded operator Devil trial completed at **01:45:50 UTC** using the exact deployed artwork adapters. Its four distinct right-facing poses passed original/pose moderation, normalizer checks, semantic review, and visual inspection. The trial created no customer account, used no customer credit, and did not publish to the private library. It is pipeline evidence, not a physical-device playback check. Its $0.10 conservative hold brings retained exposure to **$2.10**, with **$0.255288** in accumulated usage estimates. A post-pilot dashboard refresh had not yet reflected the additional requests; the new hold remains independently accounted for. Final live status at **01:46:34 UTC** reports creation available, customer allowance remains **2 of 3**, health/privacy return 200 and unauthenticated library access returns 401. See [sanitized evidence](evidence/custom-artwork-availability-fix.json).
