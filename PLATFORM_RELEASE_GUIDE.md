# CodaVybes Platform Release Guide

This package keeps one CodaVybes product/backend and produces platform-specific clients.

## Outputs

### Web / PWA
The existing Vercel build remains the canonical web client. Users can install it from supported browsers as a PWA.

### Windows portable
`release/windows-portable/CodaVybes-Portable.exe` is a zero-install Windows launcher. It opens the live CodaVybes site in Edge/Chrome standalone app mode. It is useful immediately for beta testers. It is not the final Tauri installer.

### Windows native desktop installer
GitHub Action: `.github/workflows/build-windows.yml`

It builds Tauri installers on `windows-latest` and uploads `.exe` (NSIS) and `.msi` artifacts.

### Android APK
GitHub Action: `.github/workflows/build-android-debug.yml`

It builds an installable debug APK and uploads it as `CodaVybes-Android-APK`.

### Android Play Store release
GitHub Action: `.github/workflows/build-android-release.yml`

Required GitHub Secrets:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow outputs a signed release APK and AAB.

## Required GitHub secrets for every build

Set repository → Settings → Secrets and variables → Actions:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Do **not** add a Supabase service-role/secret key to a client build.

## Android beta build

1. Push this repository to GitHub.
2. Open Actions.
3. Run `Build CodaVybes Android APK`.
4. Download `CodaVybes-Android-APK` from the completed run.
5. Install the APK on Android after allowing installs from that source.

## Windows native build

1. Open GitHub Actions.
2. Run `Build CodaVybes Windows`.
3. Download `CodaVybes-Windows`.
4. Use the `.exe` installer for normal users or `.msi` for managed Windows installs.

## Auth before public app-store launch

Email/password works with the shared Supabase backend. Before public Play Store/App Store distribution, wire Google/social OAuth through the system browser and app deep links rather than relying on embedded WebView OAuth. Also wire native push notifications for background delivery.

## Identifiers

- App name: `CodaVybes`
- Publisher/brand: `CodaBite`
- Android/Desktop identifier: `com.codabite.codavybes`

## Current backend

All platform clients use the same Supabase project and therefore share accounts, Aura, Bonds, Chats, Rooms, Wallet, CodaVybes+, verification, and moderation.
