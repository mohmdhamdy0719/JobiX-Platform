# Credits, monetization and ads

## Implemented Credit model

- Migration 004 creates finalized/reserved Credit balances and append-only transaction records. New account provisioning grants 5 signup Credits once; historical users are not retroactively granted Credits.
- Migration 010 adds export reservations: exactly 2 units for `RESUME_EXPORT`; service-only reserve/finalize functions bind a reservation to operation and fencing token. Only successful finalization inserts the -2 transaction and consumes the reservation; known failures release it; stale/replayed calls cannot double-debit.
- `CoreApi` reads authoritative balance/bootstrap and paginated transaction history. The client does not write balances or transactions.
- Current UI communicates 2 Credits for a new successful PDF export and free valid downloads for 7 days. Downloading an existing object invokes only `download`, not `create`.
- Schema includes categories such as daily reward and other future operations, but no active top-up, purchase, reward-ad or subscription writer was found in the source search.

## Export estimate/admission policy

`mobile/jobix/backend/pdf/ESTIMATED_DEVELOPMENT_COSTS.md` records owner-approved Development estimates: shared reserve 3,000,000 micro-USD; runtime 100 micro-USD/second; seven-day output 12,000 micro-USD/GiB; storage operation 7 micro-USD; per-export overhead 25,000 micro-USD. The document calls these estimates, not measured costs or a guaranteed invoice ceiling. The $10 rolling-seven-day admission budget is not a guarantee that the provider invoice stays below $10. Verify current stored Development values before relying on them; no database query was made here.

## Ads and payments

A targeted dependency/source search found no Google Mobile Ads/AdMob SDK, in-app purchase, Stripe, subscription or checkout integration in the current app. No ad placements, consent controls, test ad IDs, Play billing setup, or payment webhook path were identified. `Top up`/purchase artwork in old screenshots or documents is not proof that payment works.

## Before enabling monetization for real users

Specify package prices/benefits and refund/chargeback policy; integrate platform billing under separate approval; server-verify purchases; make transaction records idempotent; test interrupted purchase, restore, refund and account transfer; implement ad consent/privacy declarations only if an ad SDK is added; verify app-store declarations and country requirements in the current owner console. None is claimed ready.
