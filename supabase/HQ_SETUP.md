# CodaVybes HQ setup

Apply migrations in order:

```text
001_auth_onboarding.sql
002_aura_engine.sql
003_chat_groups_realtime.sql
004_rooms_games.sql
005_social_loop_bonds_age10.sql
006_vybe_hq_admin.sql
...
020_codavybes_analytics_restore.sql
```

## Bootstrap the first Super Admin

CodaVybes deliberately does **not** allow a normal browser session to make itself admin. After you have signed up and completed onboarding, open Supabase SQL Editor and run this once with your real account email:

```sql
insert into private.admin_users (user_id, role, active)
select id, 'super_admin', true
from auth.users
where lower(email) = lower('YOUR_ADMIN_EMAIL@example.com')
on conflict (user_id) do update
set role = 'super_admin', active = true, updated_at = now();
```

Then refresh the app. Your profile will show **Open CodaVybes HQ**, or navigate to `/hq`.

## Admin roles

- `super_admin`: all HQ controls, including other admin roles.
- `admin`: users, Aura corrections, config, ranks, age bands, content and game bank.
- `moderator`: reports and account moderation; cannot change economy/config.
- `analyst`: dashboard, audit and analytics visibility with masked IP addresses; no moderation or product writes.

## Security model

- Every browser-facing admin mutation is a `SECURITY DEFINER` RPC that first checks `private.admin_users`.
- Client-side buttons are convenience only; hiding a button is **not** authorization.
- Privileged mutations append to `private.admin_audit_log`.
- Suspended/banned accounts are removed from age/discovery compatibility and core chat/Room membership helpers.
- No service-role key is used by the React app.
- User Aura adjustments append ledger events instead of silently overwriting totals.
- Exact DOB is only returned by the admin user-detail RPC to `admin`/`super_admin`.
- Analytics IP addresses are stored in the private schema. `super_admin` and `admin` can view full IPs in HQ; `analyst` receives masked IPs.

## Important production note about Auth bans

The app enforces CodaVybes account suspension at the application/database layer. Before a large public launch, also mirror permanent bans / force-logout actions through a trusted Supabase Edge Function or backend using the Supabase Admin API. Never put the service-role key in Vite/browser code.

## Optional: sync CodaVybes bans to Supabase Auth

CodaVybes includes `supabase/functions/hq-auth-action`. Deploy it if you want the **Sync Auth ban / Lift Auth ban** buttons in HQ:

```bash
supabase functions deploy hq-auth-action
```

The function validates the caller through `admin_get_session()` and only then uses the server-side Supabase secret key to call Auth Admin. New publishable/secret key environment variables are supported, with legacy key variables only as a fallback. Never copy the secret/service-role key into `.env.local` used by Vite.

## Optional: deploy HQ analytics IP/location capture

V13.14 includes `supabase/functions/track-analytics`. Deploy it after migration `020`:

```bash
supabase functions deploy track-analytics --no-verify-jwt
```

The function performs its own Supabase user-token check. Gateway JWT verification
is intentionally disabled for this endpoint so browser and native-app `OPTIONS`
preflight requests reach the function and receive CORS headers. Keep the function
protected by the in-function `Authorization` check; never remove that check.

Supabase reserves the `SUPABASE_` prefix for built-in function values, so do not
add a custom secret named `SUPABASE_SERVICE_ROLE_KEY` if the dashboard rejects it.
Use `PRIVATE_SB_SECRET_KEY` for the service-role key instead. The functions also
support built-in `SUPABASE_SECRET_KEYS` when Supabase provides it.

The frontend only uses browser-safe `VITE_SUPABASE_*` values.
