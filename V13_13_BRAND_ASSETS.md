# CodaVybes V13.13 / V13.15 Brand Assets

V13.15 replaces the earlier ribbon mark with the final rounded fox logo and keeps it consistent across the web app, PWA metadata, social previews, notifications, Android source assets, Windows desktop packaging and Linux desktop packaging.

## Included Assets

- `public/brand/codavybes-logo-reference.png` - edited final fox logo reference.
- `public/brand/codavybes-fox-clean.png` - cleaned square source with the ear symbols removed.
- `public/brand/codavybes-mark.png` - rounded app mark used by the React UI.
- `public/brand/codavybes-mark.svg` - compatibility wrapper for legacy SVG references.
- `public/brand/codavybes-logo.svg` - scalable fallback lockup.
- `public/brand/codavybes-og.png` and `public/og-image.png` - 1200x630 social preview.
- `public/icons/favicon.ico` - browser favicon with 16, 24, 32, 48, 64, and 256 layers.
- `public/icons/icon-192.png`, `public/icons/icon-512.png`, `public/icons/maskable-icon-512.png` - PWA install icons.
- `platforms/mobile-capacitor/assets/icon.png` and `splash.png` - Android/iOS asset source.
- `platforms/desktop-tauri/src-tauri/icons/icon.ico`, `icon.png` and `512x512.png` - Windows and Linux desktop bundle icons.

## Launch Notes

- The app brand lockup now uses the fox icon with `CodaVybes` and `Connect. Discover. Chat.` as the UI subline.
- The splash loader uses the fox mark only and completes in under two seconds.
- Chat detail no longer uses the branded splash loader or artificial delay.
- Windows Tauri bundling now has a valid `.ico` path in `tauri.conf.json`.
- Supabase redirect allow-list should include:
  - `https://codavybes.vercel.app/auth/callback`
  - `https://codavybes.vercel.app/auth/reset-password`
  - `app.codavybes.social://auth/callback`
  - `app.codavybes.social://auth/reset-password`
  - `app.codavybes.desktop://auth/callback`
  - `app.codavybes.desktop://auth/reset-password`
