# CodaVybes V13.15 — Fox Brand + Linux Desktop

## What Changed

- The final fox logo is now the official CodaVybes mark.
- The ear `< >` symbols were removed from the source image.
- The in-app logo uses a rounded dark teal/navy background that matches the fox palette.
- The launch intro is mark-only: no wordmark, no tagline, just the fox icon with a short pop/pulse/fade-style transition.
- Web/PWA, Android source assets, Windows icons and Linux desktop icons use the same fox mark.
- Linux desktop packaging is ready through Tauri scripts and GitHub Actions.

## Brand Assets

- `public/brand/codavybes-mark.png`
- `public/brand/codavybes-fox-clean.png`
- `public/brand/codavybes-logo.png`
- `public/brand/codavybes-og.png`
- `public/og-image.png`
- `public/icons/favicon.ico`
- `public/icons/icon-192.png`
- `public/icons/icon-512.png`
- `public/icons/maskable-icon-512.png`
- `platforms/mobile-capacitor/assets/icon.png`
- `platforms/mobile-capacitor/assets/splash.png`
- `platforms/desktop-tauri/src-tauri/icons/icon.ico`
- `platforms/desktop-tauri/src-tauri/icons/icon.png`
- `platforms/desktop-tauri/src-tauri/icons/512x512.png`

## Web / Vercel

```bash
npm install
npm run build
```

Deploy the root `dist/` folder to Vercel.

## Android APK

```bash
cd platforms/mobile-capacitor
npm install
npm run sync:android
```

Then open/build the Android project. The `assets/icon.png` and `assets/splash.png`
files are the source for the native launcher icon and splash assets.

## Windows

```bash
cd platforms/desktop-tauri
npm install
npm run build:windows
```

This builds MSI/NSIS on a Windows runner or Windows machine.

## Linux

```bash
cd platforms/desktop-tauri
npm install
npm run build:linux
```

This builds `deb`, `rpm` and `AppImage` on a Linux runner or Linux machine with
Tauri prerequisites installed. A GitHub Actions workflow is included for Ubuntu.

## Verify

```bash
npm run verify:launch
```
