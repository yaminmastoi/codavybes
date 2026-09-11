# CodaVybes Supabase Setup

## 1. Create a Supabase project

Copy only browser-safe values into `.env.local`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
VITE_GA_MEASUREMENT_ID=
```

Never put a secret/service-role key in a `VITE_*` variable.

## 2. Run migrations in order

In **Supabase Dashboard → SQL Editor** run:

1. `supabase/migrations/001_auth_onboarding.sql`
2. `supabase/migrations/002_aura_engine.sql`
...
20. `supabase/migrations/020_codavybes_analytics_restore.sql`

Run every migration in order for a fresh production database. Phase 20 restores first-party HQ analytics and can be added to an existing V13.13 database after migration 019.

## 3. Authentication settings

In **Authentication → Providers**:

- Enable Email/Password.
- Keep email confirmation enabled.
- Enable Google for `Continue with Google`.

In **Authentication → URL Configuration** set:

- Local Site URL: `http://localhost:5173`
- Redirect URL: `http://localhost:5173/onboarding`
- Add the matching production URL + `/onboarding` before deployment.

For Google OAuth, configure the Supabase callback URL shown by Supabase in Google Cloud Console.

## 4. Eligibility defaults

`app_config` defaults:

- minimum age: 10
- generation window fields remain for backward compatibility but are no longer used by V6 eligibility
- username cooldown: 30 days
- old username protection: 90 days

V6 eligibility is minimum-age based. `005_social_loop_bonds_age10.sql` sets the minimum to 10 and adds age-safety pools for social discovery.

## 5. Browser-facing onboarding RPCs

- `check_username_available`
- `claim_username`
- `set_birth_date`
- `set_profile_details`
- `set_my_interests`
- `complete_onboarding`
- `get_my_onboarding_state`

## 6. Browser-facing Aura RPCs

- `give_aura`
- `create_vybe_moment` (temporary Rising Lab/test surface)
- `get_rising_feed`
- `get_for_you_feed`
- `get_my_aura_dashboard`
- `get_my_aura_ledger`
- `get_my_moments`
- `get_aura_board`

`award_verified_aura` and `admin_adjust_aura` are **service-role-only** and must never be invoked from browser code.

## 7. HQ analytics

Run `020_codavybes_analytics_restore.sql`, then deploy the optional Edge Function if you want IP/location capture:

```bash
supabase functions deploy track-analytics --no-verify-jwt
supabase secrets set PRIVATE_SB_SECRET_KEY=YOUR_SERVICE_ROLE_KEY
```

`track-analytics` validates the caller's Supabase access token inside the
function. The `--no-verify-jwt` flag only lets CORS preflight requests reach the
function; it does not make event writes public.

Use `PRIVATE_SB_SECRET_KEY` when adding the service-role key through Supabase
Function Secrets. The dashboard may reject new custom names that start with
`SUPABASE_`; the functions still read Supabase's built-in values automatically
when they exist.

Without the Edge Function, the app still records consented page/event counts through a browser-safe RPC, but server-derived IP/location fields remain empty.
