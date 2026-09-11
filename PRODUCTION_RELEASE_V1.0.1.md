# CodaVybes V1.0.1 Production Release

This source is the shared Web/Android/Windows/Linux codebase. The GitHub Actions workflows rebuild the same root Vite app for every native shell.

## Fixed in this production pass

- Android CI no longer references the missing `release/assets/codavybes-icon-512.png` file. It uses the source-controlled 1024x1024 Capacitor icon with validated fallbacks.
- Android native OAuth deep-link ownership is injected for `app.codavybes.social://auth/...`.
- Android FCM default icon and `codavybes-alerts` high-importance notification channel are configured.
- Android release workflow validates Firebase, Supabase and signing secrets before building.
- Windows workflow uses the GUI Tauri release target and builds MSI + NSIS from the shared frontend.
- Linux workflow now receives the real Supabase production environment and identifies itself as Linux instead of Windows/web.
- All GitHub workflows use stable v4 GitHub actions and Node 22.
- Version is consistent at `1.0.1` across the root app, Capacitor shell and Tauri package/config.
- Microsoft Store onboarding blocker is hardened: DOB + gender now renders explicit gender buttons instead of relying on a native select dropdown.
- Leaderboard migration 024 is corrected (`"position"` is quoted and the existing `users_are_blocked(uuid,uuid)` helper is used).
- OTP Edge Function errors now show their safe backend message instead of only `non-2xx status code`.
- Generated installers are excluded from source control; publish them as GitHub Actions artifacts/Releases.

## GitHub repository secrets

Required for all production native builds:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Additional Android release secrets:

- `ANDROID_GOOGLE_SERVICES_JSON_BASE64`
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

## Supabase Edge Function secrets

- `RESEND_API_KEY`
- `AUTH_OTP_FROM`
- `AUTH_OTP_PEPPER`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `PUSH_WEBHOOK_SECRET`

Deploy/enable the `email-auth-otp` and `push-dispatch` Edge Functions. Configure a Database Webhook on `public.user_notifications` INSERT to `push-dispatch` with header `x-codavybes-push-secret` matching `PUSH_WEBHOOK_SECRET`.

## Database

Run migrations through `025` in order. If migration 024 previously failed, rerun the corrected `024_platform_leaderboard.sql` from this package, then run 025.

## GitHub build order

1. **Build CodaVybes Android APK** — install/test the debug APK on a real Android device.
2. **Build CodaVybes Windows** — install the new MSI/EXE; do not reuse the old Store package.
3. **Build CodaVybes Linux Desktop** — test AppImage and one package format (`.deb` or `.rpm`).
4. **Build CodaVybes Android Release** — produces signed APK/AAB and requires Firebase + keystore secrets.
5. After all smoke tests pass, create/push tag `v1.0.1` for release workflows.

## Mandatory smoke tests before publishing

- Email/password signup -> 4-digit email code -> username -> DOB -> visible gender buttons -> profile -> interests -> Enter CodaVybes.
- Google and X OAuth return into Web, Android and Desktop correctly.
- Leave Android app for >15 minutes and reopen: session remains signed in.
- Close Android app completely, send a message from another account, and confirm FCM notification arrives.
- Windows/Linux close button moves the app to tray; explicit tray Quit exits it.
- No CMD/console window appears with the Windows release build.
- `/privacy`, `/terms`, `/security`, `/cookies` open without authentication.
- Microsoft Store retest: complete onboarding from a fresh Google account and verify the gender options + Enter CodaVybes action.

## Verification

Run:

```bash
npm run verify:launch
```

For a production environment check, expose only the public Vite Supabase variables and run:

```bash
npm run verify:launch:production
```
