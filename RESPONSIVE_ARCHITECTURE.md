# CodaVybes V10 — Adaptive Interface Architecture

CodaVybes now uses one React/Supabase product surface that adapts to the device instead of rendering a phone-sized app on every screen.

## Breakpoints

- **Mobile: 0–767px** — full-width app, bottom navigation, touch-first controls.
- **Tablet: 768–1179px** — compact icon rail, wider content, two-column discovery/rooms where useful.
- **Desktop: 1180px+** — persistent navigation sidebar, wide content canvas and contextual right rail.
- **Large desktop: 1500px+** — expanded focus routes and comfortable reading/game widths.

## Desktop shell

Desktop uses:

1. Persistent left navigation.
2. Main content column.
3. Context/quick-access rail on ordinary pages.
4. Focus mode for chats, Rooms, Meet sessions and Moment threads so these workflows use the full center canvas.

No backend or route behavior changes between devices. The same Supabase account, Aura, Bonds, Rooms, messages, Wallet and feature flags are used everywhere.

## Onboarding

Desktop onboarding is intentionally different from mobile:

- Desktop: brand/story panel + dedicated account workflow panel.
- Tablet: larger centered workflow.
- Mobile: native-feeling full-screen onboarding.

## PWA

The root app remains installable as a PWA. V10 registers the existing service worker globally and exposes an Install CodaVybes action when the browser provides an install prompt.

The manifest includes Home, Chats, Rooms and Discover shortcuts.

## Native packaging path

The responsive web/PWA is the shared product foundation. Native wrappers should consume the same production build:

- **Android/iOS:** Capacitor shell around the Vite build, then replace capabilities with native plugins only where needed (push, camera, haptics, deep links).
- **Windows/macOS:** Tauri shell around the Vite build for a lightweight dedicated desktop client.

Do not fork Aura, auth, chat or Room logic into separate backends. All clients share the same Supabase services and RLS policies.
