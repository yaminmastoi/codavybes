# CodaVybes V13.8 — Distraction-free Chat

## Included behavior

- Opening an individual chat removes the mobile bottom navigation completely.
- Leaving the conversation restores the normal bottom navigation automatically.
- The mobile chat fills `100dvh`; the 52px composer stays at the bottom and respects the device safe area.
- All scrollable surfaces use a slim themed vertical scrollbar. Horizontal scrollbar rails are hidden.

## Database

No new SQL migration is required for V13.8. Existing migration 018 must already be applied when upgrading from V13.6 or earlier.

## Deploy

1. Install dependencies from a clean platform-local `node_modules` folder.
2. Run `npm run build` and deploy the web build.
3. For Android, run the Capacitor sync flow and rebuild the APK.
4. For Windows, run `npm install` and `npm run build` from `platforms/desktop-tauri`. The shell now resolves the root frontend with the corrected `../..` path.
