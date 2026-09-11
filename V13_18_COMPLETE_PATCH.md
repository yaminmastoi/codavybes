# CodaVybes V13.18 Complete Patch

This source patch keeps the uploaded web app as the single source of truth and preserves the existing embedded brand assets/theme.

## Included fixes

- Auth entry now offers Email, Google and X.
- Email/password signup and sign-in require a custom 4-digit email verification challenge before a Supabase session is created.
- Google/X OAuth is treated as factor one; the local OAuth session is converted into the same 4-digit registered-email verification flow before app access.
- New-user onboarding is username -> DOB + gender -> existing profile/interests/reveal flow.
- DOB/gender are stored in Supabase; DOB is not used to gate discovery, posts, friendship, Meet, chat or Moment interaction.
- Historical age-compatibility helper is retained for backward compatibility but now means active-account compatibility only.
- Native auth persistence is added for Capacitor Preferences (Android) and Tauri Store (Windows/Linux), with session recovery/refresh on resume/focus/online.
- Android FCM token registration is added; tokens are stored privately through an authenticated RPC.
- `push-dispatch` Edge Function sends inserted `user_notifications` to Android FCM tokens, allowing terminated-app delivery once Firebase and the database webhook are configured.
- Windows/Linux Tauri native notification plugin is wired in; closing the desktop window keeps the process in the tray so realtime/native notifications can continue. Tray has Open and explicit Quit actions.
- Windows release binary uses the GUI subsystem to prevent the console/CMD window.
- CodaVybes Leaderboard page shows the top 10 active onboarded users by Aura.
- Existing browser confirm dialogs in chat/rooms were replaced by CodaVybes confirmation UI.
- Startup reveal timing is ~2.45 seconds and retains current fox-logo branding.
- Powered by CodaBite placement is restored in restrained product surfaces.
- Chat viewport uses Visual Viewport height support for mobile/native keyboards.
- Existing Android/Windows/Linux GitHub build workflows are preserved; Android release CI now requires Firebase configuration for production push.

## Required deployment order

1. Apply Supabase migrations in order through `025_remove_remaining_age_delivery_gates.sql`.
2. Deploy Edge Functions `email-auth-otp` and `push-dispatch`.
3. Set server-only Supabase Edge Function secrets listed in `LAUNCH_CHECKLIST_V13_18.md`.
4. Configure Google and X providers in Supabase Auth. X must request the user's email.
5. Create a Supabase Database Webhook on `public.user_notifications` INSERT pointing to `push-dispatch`, with the configured `x-codavybes-push-secret` header.
6. Add the Firebase Android JSON as the GitHub secret documented in the launch checklist.
7. Run the GitHub Android/Windows/Linux workflows or local platform builds.

## Verification status

- `git diff --check`: passed.
- All 91 JS/JSX source files were parsed with the TypeScript JSX parser: 0 syntax errors.
- Modified non-JSX service files passed `node --check`.
- A full Vite build could not be completed in this execution environment because root dependency installation timed out and the uploaded ZIP did not include root `node_modules`. Build CI uses `npm install` and must be run before production release.

Do not deploy the pre-existing `dist/` as proof of this patch; rebuild it from source.
