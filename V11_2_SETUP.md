# VYBE V11.2 — Certified Blue Tick + UI Polish

## Existing V11.1 database
Run only:

`supabase/migrations/012_certified_verification_waitlist.sql`

Do not rerun 001–011.

## Blue tick flow
1. Account is below Certified: no verification CTA is shown.
2. Aura crosses the active `certified` rank threshold: database trigger unlocks verification and creates a system notification.
3. User opens Settings and chooses **Join waitlist**.
4. HQ → Blue tick waitlist shows the Certified account.
5. Admin/Super Admin may grant or decline.
6. Granting writes the verified state, audit log and notification. The blue seal/check appears across VYBE.

The Certified threshold is read from `public.aura_ranks`; it is not hard-coded in React.

## Important
- Only Certified-or-higher users can join the waitlist.
- Only Certified-or-higher users can be newly verified, including admin overrides.
- Existing verified accounts are not silently removed if Aura later changes; HQ can remove verification explicitly.
- The old V11 request RPC remains as a compatibility alias during rolling deployments, but it now enforces the Certified waitlist rule.

## UI polish
`src/styles/polish.css` is loaded after `global.css` and contains final layout guardrails for button sizing, wrapping, overflow, action groups, mobile breakpoints, HQ controls and the new verification badge.
