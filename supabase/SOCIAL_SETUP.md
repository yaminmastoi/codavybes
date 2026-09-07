# VYBE V6 — Social Loop Setup

Run `005_social_loop_bonds_age10.sql` **after migrations 001–004**.

## What changes

The old Gen-Z/18+ gate is replaced with a simple **10+ minimum age**. Existing DOB records are re-evaluated automatically.

VYBE then creates three discovery safety pools:

```text
10–12
13–17
18+
```

A user can only discover/connect with users in the same pool. This rule is enforced in PostgreSQL, not only in React.

## Meet flow

```text
Discover
  ↓
Meet request
  ↓
Receiver accepts
  ↓
Temporary Meet session
  ↓
10-minute chat
  ↓
Both choose KEEP
  ↓
Connection + Bond + permanent DM
```

One `move_on` decision closes the temporary session.

## Bonds

A connection owns one `bonds` row and a private event ledger.

Bond points are added by database triggers when connected users:

- send direct messages
- give peer Aura to one another
- play a Room game together

The displayed Bond percentage is derived from points instead of being directly writable by the browser.

Config lives in `public.social_config`, including Meet duration, rate limits, and Bond point/cap values. This is ready for a future VYBE HQ admin editor.

## Child-safety note

The 10–12 pool is deliberately isolated from teens and adults in stranger-discovery/social creation paths. Exact DOB stays under `private.user_private`.

This architecture is a product/security baseline only. Before a real public launch that includes children, review the privacy, parental-consent, moderation, reporting, data-retention and age-assurance obligations for every target jurisdiction.

## Suggested QA

- age 9 → rejected
- age 10 → accepted, 10–12 pool
- age 12 → accepted, 10–12 pool
- age 13 → accepted, 13–17 pool
- age 17 → accepted, 13–17 pool
- age 18 → accepted, 18+ pool
- adult cannot Discover a teen
- teen cannot search/create DM with adult
- child cannot create group with teen/adult
- same-pool users can Meet
- duplicate pending Meet request fails
- temporary Meet stops accepting messages after expiration
- one Move On closes it
- one Keep waits
- two Keeps create one connection and one DM
- duplicate mutual Keep remains idempotent
- messages/Aura/games grow Bond within caps
- browser cannot directly update Bond points/percent
