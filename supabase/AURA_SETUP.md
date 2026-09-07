# VYBE Phase 2 — Aura Engine Setup

Run:

1. `supabase/migrations/001_auth_onboarding.sql`
2. `supabase/migrations/002_aura_engine.sql`

## What Phase 2 creates

- `aura_config` — future VYBE HQ-controlled thresholds/weights
- `aura_ranks` — database-driven Aura rank ladder
- `aura_targets` — generalized Aura-able objects (currently public test moments; later messages/Room/game results)
- `aura_events` — immutable Aura ledger
- `give_aura()` — secure +1 peer Aura with anti-farming checks
- `get_rising_feed()` — fresh public targets that can collect initial Aura
- `get_for_you_feed()` — only content that earned FYP eligibility
- `get_my_aura_dashboard()` — rank/progress/today/week/giving limits
- `get_my_aura_ledger()` — current user's recent Aura history
- `get_aura_board()` — Today / Week / Lifetime board
- `award_verified_aura()` — service-role-only game/MVP rewards
- `admin_adjust_aura()` — service-role-only future HQ correction tool

## Default economy

- New user starts at Aura `+1`.
- Peer Aura is always `+1`.
- One user can Aura a specific target only once.
- Default daily giver limit: `50`.
- New account first `72h`: default daily giver limit `10`.
- Default same giver → receiver daily limit: `10`.
- Default combined two-way pair limit: `15`.
- Public test-moment creation: `10/hour`; new accounts default `3/hour`.
- Aura Moment threshold: `+5`.
- For You eligibility: `+5 Aura` from at least `3` unique people.
- For You max age: `168h` (7 days).

These values live in `public.aura_config`. Authenticated users may read safe config but cannot modify it.

## Test the real loop

Use at least four fully onboarded accounts:

1. Account A opens Home and drops a test moment in **Rising Lab**.
2. Accounts B/C/D open **Rising**.
3. Each gives the moment `Aura +` once.
4. Watch unique giver + Aura counters increase.
5. At the configured threshold, the target becomes an Aura Moment / For You eligible.
6. Open **For You** and verify it appears based on its FYP score.
7. Open Account A → Profile and verify lifetime Aura, rank progress, recent Aura ledger and Aura Board.

A user cannot Aura their own target and cannot repeatedly Aura the same target.

## Verified game Aura (trusted server only)

Do **not** call this from React. From your trusted backend/service-role environment after server-side game scoring:

```sql
select public.award_verified_aura(
  '<winner-user-uuid>',
  'game',
  '<game-result-uuid>',
  3,
  'Puzzle Battle winner'
);
```

For MVP:

```sql
select public.award_verified_aura(
  '<mvp-user-uuid>',
  'room_mvp',
  '<room-result-uuid>',
  5,
  'Room MVP'
);
```

Retries with the same receiver/source/source-id do not double-award Aura.

## Important

Never add direct browser INSERT/UPDATE grants for `aura_events`, `aura_targets` counters, or `profiles.aura_total`.
