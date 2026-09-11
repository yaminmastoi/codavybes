# CodaVybes V13.18 Launch Checklist

## Supabase

- [ ] Backup production database.
- [ ] Apply migrations 022, 023, 024 and 025 in order.
- [ ] Deploy `email-auth-otp` Edge Function.
- [ ] Deploy `push-dispatch` Edge Function.
- [ ] Set `RESEND_API_KEY`.
- [ ] Set `AUTH_OTP_FROM` to a sender on a verified email domain.
- [ ] Set a long random `AUTH_OTP_PEPPER`.
- [ ] Set `FIREBASE_SERVICE_ACCOUNT_JSON`.
- [ ] Set a long random `PUSH_WEBHOOK_SECRET`.
- [ ] Ensure `SUPABASE_SERVICE_ROLE_KEY` is available to the Edge Functions using your Supabase environment convention.
- [ ] Configure a Database Webhook for INSERT on `public.user_notifications` -> `/functions/v1/push-dispatch`.
- [ ] Send the header `x-codavybes-push-secret: <PUSH_WEBHOOK_SECRET>` from that webhook.

## Auth providers

- [ ] Google OAuth enabled and callback/redirect allowlist includes web + native callback routes already used by the app.
- [ ] X / Twitter OAuth 2.0 enabled in Supabase.
- [ ] X application has `Request email from users` enabled; second factor requires a registered email.
- [ ] Test email signup -> 4-digit code -> username -> DOB/gender -> profile/interests.
- [ ] Test returning email/password sign-in -> 4-digit code -> existing account.
- [ ] Test Google sign-in -> 4-digit registered-email code.
- [ ] Test X sign-in -> 4-digit registered-email code.
- [ ] Test wrong OTP, expiry, max attempts and 60-second resend cooldown.

## Android push/build

- [ ] Firebase Android app package is exactly `app.codavybes.social`.
- [ ] Add GitHub secret `ANDROID_GOOGLE_SERVICES_JSON_BASE64` containing Base64 of `google-services.json`.
- [ ] Existing Android signing secrets remain configured.
- [ ] Run `Build CodaVybes Android Release` workflow.
- [ ] Install release APK on a real Android device.
- [ ] Allow notification permission.
- [ ] Confirm `private.push_device_tokens` receives the device token.
- [ ] Send message, Meet event, Moment event and system notification while app is foregrounded.
- [ ] Repeat while app is backgrounded.
- [ ] Fully terminate Android app and repeat; FCM notification must arrive.
- [ ] Tap notification and verify deep link opens expected route.

## Windows/Linux

- [ ] Run desktop workflows from this patched source.
- [ ] Windows installed release starts without CMD/console window.
- [ ] Close main window; verify app moves to tray instead of terminating.
- [ ] Test native notification while window is hidden.
- [ ] Verify tray `Open CodaVybes` and `Quit CodaVybes` actions.
- [ ] Explicit Quit intentionally stops desktop realtime notifications; true push after process termination would require an OS background service/provider beyond the tray design.

## Session regression

- [ ] Login on Android, leave app idle/backgrounded for >15 minutes, return; account remains signed in.
- [ ] Force-close/reopen Android; persisted Supabase refresh session restores.
- [ ] Repeat on Windows and Linux after >15 minutes.
- [ ] Confirm web auth remains unchanged and stable.

## Product parity

- [ ] No age-based discover/chat/post/Meet/Moment restriction remains after migration 025.
- [ ] Blocked/banned/suspended account restrictions still work.
- [ ] Leaderboard route works and shows at most 10 active onboarded users.
- [ ] Chat composer remains visible above mobile/native keyboard.
- [ ] Loader/branding matches embedded final fox assets.
- [ ] No default application `alert/confirm/prompt` remains; the PWA install object's `prompt()` method is not a browser dialog and is intentionally retained.
