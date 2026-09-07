# CodaVybes V13.4 — Analytics Command Center

V13.4 adds a privacy-aware live command center to CodaVybes HQ for Web, Android and Windows. It creates no mock analytics rows. Historical device/session telemetry begins only after a V13.4 client is deployed; business counts (posts, messages, games, orders, etc.) are read from the existing production database.

## 1) Database migration

If your project already has migrations 001–015, run only:

`supabase/migrations/016_analytics_command_center.sql`

Do not rerun 001–015 on an existing database.

Run it in Supabase Dashboard → SQL Editor, or with your normal Supabase migration workflow.

## 2) Deploy the telemetry Edge Function

The app can fall back to a database RPC for presence, but IP/coarse edge geography is available only when the Edge Function is deployed.

From a Supabase CLI project linked to your production project:

```bash
supabase functions deploy telemetry-ingest
```

The function verifies the signed-in user's JWT before using the server-side service-role client. Never put the service-role key in any `VITE_*` variable or browser bundle.

Supabase normally provides `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` to Edge Functions. If your project uses custom secret management, ensure those server-side values are available to the function.

## 3) Web deployment

Vercel environment variables:

```text
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_BROWSER_KEY
VITE_APP_PLATFORM=web
VITE_APP_VERSION=13.4.0
```

Push the V13.4 code to the production branch and redeploy Vercel. Web users receive the new client on their next load/refresh.

## 4) Android update

The included GitHub workflows already build V13.4 with:

```text
VITE_APP_PLATFORM=android
VITE_APP_VERSION=13.4.0
```

For a test APK: Actions → **Build CodaVybes Android APK**.

For production: Actions → **Build CodaVybes Android Release**. The release workflow uses the existing Android signing secrets and outputs signed APK + AAB. Keep using the same release keystore for future updates.

For Play Store users, upload the new AAB as a new release. For direct-APK users, distribute the newly signed APK. In HQ → Analytics → Release Control, create an Android release row with version `13.4.0`, the build number you are distributing, and the Play Store/download URL. Clients can then show an in-app update banner.

## 5) Windows update

Actions → **Build CodaVybes Windows** to create the V13.4 `.exe` / `.msi` installers.

Upload the installer to a stable HTTPS URL (for example a GitHub Release asset or your download site). Then HQ → Analytics → Release Control → Windows:

- Version: `13.4.0`
- Build number: a monotonically increasing number
- Download URL: HTTPS installer/release page
- Required: only enable when you truly need to block old clients

Existing Windows installations do not self-replace silently; the in-app banner sends the user to the installer URL.

## 6) What is live and what is historical

HQ refreshes the Analytics view about every 5 seconds. Signed-in clients send a presence heartbeat about every 25 seconds. A user is considered active when a heartbeat has been seen within about 75 seconds.

Real database activity (posts, comments, reactions, shares, message metadata, games, Aura and wallet activity) is read directly from production tables. Private message bodies are never returned by the analytics RPCs.

Optional analytics events and client error capture require the user's optional analytics consent. Exact latitude/longitude is a separate opt-in, restricted to eligible 18+ accounts, and shown only to Super Admin. IP metadata is server-observed, role-restricted and short-lived; under-18 accounts do not expose IP/precise coordinates in HQ analytics views.

## 7) HQ sections

HQ → Analytics includes:

- active users and sessions
- Web / Android / Windows splits
- versions in use
- installs/installation IDs seen after analytics consent
- routes/screens in use
- device / OS / browser class
- network quality fields where the client API supplies them
- coarse country/region/city where the hosting edge supplies headers
- real product activity stream
- client error stream
- Plus and paid-order summaries
- per-user analytics drill-down
- release/update registry for all platforms

Blank values mean the signal was not supplied; CodaVybes does not invent or mock missing location/network data.

## 8) Privacy / production note

The included Privacy, Cookies, Security and Terms pages are product templates, not legal advice. Before a public launch—especially because CodaVybes supports younger users—have the final policies, consent design, retention periods and regional requirements reviewed for the countries where you operate.
