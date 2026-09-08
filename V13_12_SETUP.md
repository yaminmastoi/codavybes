# CodaVybes V13.12 — For You and promotions delivery

## Required database update

Run this file once in the Supabase SQL Editor after migration 018:

```text
supabase/migrations/019_fyp_promotions_delivery.sql
```

Migration 019 makes every existing active public Moment eligible for For You, reinstalls the current all-public-post feed RPC, adds a supporting partial index and repairs the global Feed ads switch when a live campaign already exists.

## Promotion behavior

- A feed with zero organic posts can still show one active sponsored card.
- A feed with 1–6 posts shows one sponsored card after the first post.
- Larger feeds return to the low-frequency placement cadence, capped at two sponsored cards per loaded feed window.
- Saving an active promotion in HQ automatically enables the global Feed ads switch.
- HQ shows `LIVE`, `SCHEDULED`, `EXPIRED`, `ADS OFF` or `OFF` instead of labeling every active row as live.
- Campaign minimum-age, start-time and end-time rules still apply.

## Deployment order

1. Run migration 019.
2. Deploy the updated root web build.
3. Rebuild/sync Android and rebuild Windows so all clients receive the same shared frontend.
4. Open HQ → Promotions and confirm the campaign says `LIVE`.
5. Test with an account whose age meets the campaign minimum age.

If For You still contains only one organic card after migration 019, then only one row currently satisfies: `target_type='post'`, `status='active'`, `visibility='public'`, author onboarding complete, author account active, and not blocked by the viewer. The migration does not manufacture or reactivate moderated/private content.
