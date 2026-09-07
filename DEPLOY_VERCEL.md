# VYBE V9.1 — Vercel Deployment

## 1. Supabase database
If V8.1 migrations 001-008 are already applied, run only:
- `supabase/migrations/009_brand_theme_notifications_feature_gates.sql`

If 009 is already applied, do not run it again unless the migration is explicitly idempotent in your environment.

## 2. Local environment
Create `.env.local`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never put a service-role/secret key in a `VITE_` variable.

## 3. Local production build
```bash
npm install
npm run build
npm run preview
```

Confirm `/home`, `/settings`, `/notifications`, `/shop`, `/vybe-plus`, and `/hq` can be opened/refreshed as appropriate for the signed-in account and feature flags.

## 4. GitHub
Push the *contents of this folder* to a GitHub repository. `package.json` must be at the repository/project root selected in Vercel.

## 5. Vercel
Import the GitHub repository.

Recommended settings:
- Framework Preset: Vite
- Build Command: `npm run build`
- Output Directory: `dist`
- Install Command: `npm install`

Add these Environment Variables for Production (and Preview if desired):
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Deploy.

## 6. Supabase Auth URL Configuration
After Vercel gives the production URL, set in Supabase Auth -> URL Configuration:
- Site URL: `https://YOUR-PRODUCTION-DOMAIN`
- Redirect URL: `https://YOUR-PRODUCTION-DOMAIN/**`
- Keep local development redirect too if needed: `http://localhost:5173/**`

For preview deployments, add only the preview wildcard pattern you intentionally want to trust.

## 7. Google OAuth (if enabled)
In Google Auth Platform:
- Authorized JavaScript origin: your production origin, e.g. `https://vybe.example.com`
- Authorized redirect URI: use the Supabase callback URL shown in Supabase's Google provider settings (typically `https://YOUR_PROJECT.supabase.co/auth/v1/callback`).

In Supabase Auth Providers -> Google, ensure the provider is enabled and Client ID/Secret are configured.

## 8. Super Admin
If not already bootstrapped, use Supabase SQL Editor (replace the email):

```sql
insert into private.admin_users (user_id, role, active)
select id, 'super_admin', true
from auth.users
where lower(email)=lower('YOUR_EMAIL@gmail.com')
on conflict (user_id) do update
set role='super_admin', active=true, updated_at=now();
```

## 9. Smoke test after deploy
1. Sign up with email.
2. Confirm verification redirects back to `/onboarding`.
3. Google sign-in works (if enabled).
4. Complete onboarding.
5. Refresh `/home` directly — no Vercel 404.
6. Open Notifications and enable system notifications.
7. Test Discover -> Meet -> Chat.
8. Give Aura and verify profile/rank update.
9. Start a Room/game.
10. Test Settings light/dark/system theme.
11. Disable Shop/VYBE+/Top-ups in HQ and verify entries disappear on a normal user session.
12. Open `/hq` as Super Admin.

## Important
Real-money top-up settlement is still intentionally not implemented unless you separately connected a payment provider/server webhook. Do not manually mark browser-side payment intents as paid.
