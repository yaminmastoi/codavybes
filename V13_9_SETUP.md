# CodaVybes V13.9 — Persistent Auth + Native Google Return

## Fixed

- A valid Supabase refresh token is persisted and restored after the web tab,
  Android app or Windows app is closed and reopened.
- Token refresh restarts when the Android app returns to the foreground.
- Google OAuth uses PKCE and a system browser on Android and Windows.
- After Google completes, the callback returns to the same app instead of
  leaving the user on the normal website.
- Web Google OAuth finishes through `/auth/callback`.

## Required Supabase configuration

Open Supabase Dashboard → Authentication → URL Configuration. Keep the live web
domain as the Site URL and add these Redirect URLs:

```text
https://YOUR-WEB-DOMAIN/auth/callback
https://YOUR-WEB-DOMAIN/auth/reset-password
app.vybe.social://auth/callback
app.vybe.social://auth/reset-password
app.vybe.desktop://auth/callback
app.vybe.desktop://auth/reset-password
```

Replace `YOUR-WEB-DOMAIN` with the real production domain. Add the exact Vercel
preview URL separately only when preview OAuth is required.

Do not put the custom app schemes in Google Cloud Console. Google's authorized
redirect URI remains the Supabase provider callback:

```text
https://YOUR-PROJECT-REF.supabase.co/auth/v1/callback
```

## Web deployment

1. From the repository root run `npm install` and `npm run build`.
2. Deploy the generated `dist/` directory.
3. Confirm the host rewrites `/auth/callback` to the SPA `index.html`. The
   included Vercel configuration already provides SPA routing.

## Android deployment

1. From `platforms/mobile-capacitor`, run `npm install` and `npm run sync`.
2. Confirm `android/app/src/main/res/values/strings.xml` contains
   `<string name="custom_url_scheme">app.vybe.social</string>`.
3. Rebuild and reinstall the APK. An older installed APK does not contain this
   auth bridge.

## Windows deployment

1. From `platforms/desktop-tauri`, run `npm install` and `npm run build`.
2. Install the newly generated Windows installer. The installed bundle registers
   `app.vybe.desktop://` with Windows.
3. Test Google sign-in from the installed app, not an unpacked executable.

## Database

No SQL migration is required for V13.9.
