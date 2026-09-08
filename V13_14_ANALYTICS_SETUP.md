# CodaVybes V13.14 — Analytics Restore

This release restores first-party product analytics inside CodaVybes HQ.

## What You Get In HQ

- Active users and active sessions in the last 15 minutes.
- Unique users, page views, total events, messages, posts and promotions activity for the last 24 hours.
- Platform split: Web, PWA, Android and Windows.
- Device split: mobile, tablet and desktop.
- Approximate country/region/city when the Edge Function receives host geo headers.
- Recent active sessions with username, platform, location, IP address and last page.
- Role-aware IP display: `super_admin` and `admin` see full IP; `analyst` sees masked IP.

Private chat bodies, message text, emails, tokens and passwords are not logged as analytics metadata.

## Database

Run after migration `019`:

```text
supabase/migrations/020_codavybes_analytics_restore.sql
```

Fresh production order is now `001` -> `020`.

If Supabase says `column "country" does not exist`, your project already had an older/partial `private.analytics_events` table. Use the latest version of migration `020`; it now adds missing columns with `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` before creating indexes/views.

## Edge Function For IP + Location

Deploy this function:

```bash
supabase functions deploy track-analytics
```

Set server-side function secrets in Supabase, not in Vite. Supabase reserves the
`SUPABASE_` prefix in the dashboard, so use the custom service-role name below:

```bash
supabase secrets set PRIVATE_SB_SECRET_KEY=YOUR_SERVICE_ROLE_KEY
```

The function also reads Supabase's built-in `SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEYS` / `SUPABASE_ANON_KEY` and `SUPABASE_SECRET_KEYS`
when your project provides them. If your dashboard asks for custom names, use
`PRIVATE_SB_URL`, `PRIVATE_SB_ANON_KEY` and `PRIVATE_SB_SECRET_KEY`.

The React app never receives the service-role key. If the Edge Function is not deployed yet, analytics still records route/event counts through the browser-safe RPC, but IP/location fields will be empty.

## Google Analytics 4

After creating a GA4 web stream, add the measurement id to Vercel and local env:

```env
VITE_GA_MEASUREMENT_ID=G-XXXXXXXXXX
```

Redeploy the web app and rebuild Android/Windows if you want the same compiled config inside native builds.

## Google Search Console

Use URL-prefix property for:

```text
https://codavybes.vercel.app
```

Verify with an HTML tag or Google Analytics, then submit:

```text
https://codavybes.vercel.app/sitemap.xml
```

`robots.txt` already points crawlers to the sitemap and blocks private app/admin surfaces.
