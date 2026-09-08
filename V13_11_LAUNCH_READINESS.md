# CodaVybes V13.11 — responsive Moment thread and platform parity

## What V13.11 fixes

- The Moment thread author row now uses the same responsive identity structure as feed cards.
- Long names, handles, context labels, Moment copy and reply text can shrink or wrap without horizontal overflow.
- Moment actions remain four compact actions on normal phones and become a readable 2×2 grid on very narrow devices.
- Reply identity metadata no longer collides with the avatar or card boundary.
- The reply composer fills the content width, respects the mobile safe area and stays above the floating navigation.
- Buttons include accessible labels and form controls keep a mobile-safe 16px input size.

No database migration is required for V13.11.

## Feature parity model

The root React/Vite application is the only product frontend. Web/PWA deploys its `dist/` output, Capacitor copies that same `dist/` into Android, and Tauri embeds that same `dist/` into Windows. Routes, Supabase services, permissions, feature flags and UI are therefore shared rather than separately reimplemented.

| Product area | Web/PWA | Android | Windows |
| --- | --- | --- | --- |
| Signup, login, persistent session and Google OAuth | Shared | Shared + native deep link | Shared + native deep link |
| Home, Rising Lab, Moments, reactions, Aura and replies | Shared | Shared | Shared |
| Discover, connections and cross-age eligibility | Shared | Shared | Shared |
| Direct/group chat, typing, receipts, clear and delete | Shared | Shared | Shared |
| Rooms, games and Meet | Shared | Shared | Shared |
| Profile, Threads, settings, themes and verification | Shared | Shared | Shared |
| Notifications UI/preferences | Shared | Shared + native local alerts | Shared + OS web notifications |
| Wallet, Shop, CodaVybes+ and HQ feature flags | Shared | Shared | Shared |

Platform adapters intentionally differ only where the operating system requires it: OAuth browser/deep-link handling, installation, safe areas and notification presentation.

## Automated verification

Run from the repository root:

```bash
npm run verify:launch
npm run build
```

Before a production release, configure `.env.local` and run:

```bash
npm run verify:launch:production
```

The current parity verifier checks shared build output paths, all public/product routes, branding, SPA rewrites, native OAuth dependencies, notification support and migrations 001–019.

## Release gates that still require the deployment owner

Code alone cannot complete these account- and device-bound checks:

1. Apply Supabase migrations 001–019 in order and configure the web, Android and Windows OAuth callback URLs from `V13_9_SETUP.md`.
2. Confirm Realtime is enabled for the chat, typing, notification and Room tables used by the migrations.
3. Build and test Web/PWA in Chrome, Safari and Edge at 280, 320, 360, 390, 768 and desktop widths.
4. Build a signed Android release, reinstall it on Android 13+, approve notification permission and test login/deep-link return, keyboard/safe-area behavior and background/resume.
5. Configure FCM/APNs if notifications must arrive while the native app is fully terminated. Local notification support alone cannot provide server-originated killed-app delivery.
6. Build and sign the Windows installer, install it on a clean machine and test the registered OAuth deep link and notification permission.
7. Configure production environment values, domains, store listing assets, privacy/legal text, support contact, crash reporting and release signing secrets.

A release is ready to publish only after the automated verifier, production build and every applicable external gate pass.
