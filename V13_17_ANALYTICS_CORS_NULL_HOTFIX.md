# CodaVybes V13.17 — Analytics CORS + Null Safety Hotfix

This hotfix addresses two production console failures:

- `track-analytics` now answers browser and native-app `OPTIONS` preflight requests with CORS headers.
- User display names are normalized before initials are generated, so a missing profile name cannot throw `null.trim()` during rendering.

## Deploy the Edge Function

Run these commands from the repository root after linking the correct Supabase project:

```bash
supabase link --project-ref yxajjngwjpjmqialpijp
supabase functions deploy track-analytics --no-verify-jwt
supabase secrets set PRIVATE_SB_SECRET_KEY=YOUR_SERVICE_ROLE_KEY
```

`--no-verify-jwt` is intentional for this endpoint. The function validates the
Supabase access token itself, while the gateway must let `OPTIONS` preflight
requests reach the function. Never put `PRIVATE_SB_SECRET_KEY` or any service
role key in Vite environment variables or browser code.

The default CORS allow-list includes:

- `https://app-codavybes.vercel.app`
- `https://codavybes.vercel.app`
- local Vite/Capacitor/Tauri origins

Additional origins can be supplied as a comma-separated `CORS_ALLOWED_ORIGINS`
function secret if required.

## Verify

1. Sign in at `https://app-codavybes.vercel.app` and accept optional analytics consent.
2. Open DevTools and reload `/home` or `/discover`.
3. The `track-analytics` request should no longer show a CORS preflight error.
4. Open CodaVybes HQ analytics and confirm the new session appears after the heartbeat.

If the Edge Function is temporarily unavailable, the browser-safe analytics RPC
fallback remains available, but server-derived IP and location fields will be
empty until the function is deployed.
