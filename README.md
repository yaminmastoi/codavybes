# CodaVybes V13

# CodaVybes V12 — Games Expansion + Feed Layout Fix

V12 expands Rooms to **8 server-authoritative games**, seeds an asserted **10,000+ private question/prompt bank**, updates HQ game-question controls, and fixes the cramped mobile feed identity header shown in V11.2. Existing auth, Aura, Certified verification, responsive shells, commerce feature gates and realtime protections remain intact.

For an existing V11.2 database, run only `supabase/migrations/013_games_expansion_10k.sql`. See `V12_SETUP.md`.

# CodaVybes V11 — Verification, Recovery & UI Discipline

V11 adds admin-reviewed blue-tick verification, secure Supabase password recovery/reset, verification notifications, and a no-shadow/no-overflow button alignment pass on top of V10 adaptive web. See `V11_SETUP.md` before deploying.

# CodaVybes V10 — Adaptive Web / PWA

V10 keeps the V9.1 realtime/security base and rebuilds the frontend shell so CodaVybes feels native to each screen size instead of showing a centered phone layout on desktop.

## V10 highlights

- Mobile: full-width touch UI + bottom navigation.
- Tablet: compact navigation rail + wider two-column surfaces.
- Desktop: persistent sidebar + full content canvas + contextual right rail.
- Focus mode for chats, Rooms, Meet and Moment threads.
- Desktop split-screen onboarding.
- Global PWA service-worker registration + install surface.
- Existing light/dark themes, feature flags, Realtime hotfix and Supabase security preserved.
- **No new database migration is required for V10.**

Read `RESPONSIVE_ARCHITECTURE.md` and `V10_SETUP.md` first.

---

# CodaVybes V9 — Premium Brand System

V9 is the visual/product-polish release of the existing V8.1 working platform.

## What changed

- Light theme is now the default.
- Full premium dark theme.
- Light / Dark / System selector in Settings.
- New CodaVybes interlocking-ribbon logo and app mark.
- Plus Jakarta Sans formal UI typography.
- Unified Lucide vector icon system; decorative emoji UI removed.
- App-launch loader, route loaders, content skeletons and action loaders.
- Browser/PWA system-notification bridge using Supabase Realtime + Service Worker.
- Shop, CodaVybes+ and Top Up user surfaces now obey HQ controls in realtime.
- HQ Monetization save wiring repaired and top-up packages are passed to the panel correctly.
- Fake Home "Active Vibes" demo people removed; Home now uses the user's real connections.
- V8.1 `user_age_band` permission hotfix remains included.

Read `BRANDKIT.md` for the complete visual system.

## Run

```bash
npm install
cp .env.example .env.local
npm run dev
```

`.env.local`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Never expose a Supabase secret/service-role key through a `VITE_*` variable.

## Existing V8.1 database

Run only:

```text
supabase/migrations/009_brand_theme_notifications_feature_gates.sql
```

For a fresh database, run `001` → `009` in order. Full details: `supabase/V9_SETUP.md`.

## Important files

- `BRANDKIT.md`
- `src/context/ThemeContext.jsx`
- `src/components/Logo.jsx`
- `src/components/Loaders.jsx`
- `src/context/CommerceContext.jsx`
- `src/components/NotificationBridge.jsx`
- `public/vybe-sw.js`
- `supabase/migrations/009_brand_theme_notifications_feature_gates.sql`
- `supabase/V9_SETUP.md`
- `SECURITY.md`

## V11.2 Certified verification

V11.2 changes blue-tick verification to a Certified-rank waitlist. Run `supabase/migrations/012_certified_verification_waitlist.sql` after 001–011. See `V11_2_SETUP.md` and `UI_AUDIT_V11_2.md`.


## V13.2 UI shell fix

- Desktop left navigation and right rail stay pinned while center content scrolls.
- Chat composer is compact and message stream owns chat scrolling.
- Profile opens with identity, username and Vibe Score first; details begin after the first viewport.
- No database migration is required for V13.2.

See `V13_2_UI_FIX.md`.

## V13.4 Analytics Command Center

V13.4 adds live Web/Android/Windows presence, real product activity, version/device health, privacy-aware telemetry and HQ release control. See `V13_4_ANALYTICS_SETUP.md` and run only migration `016_analytics_command_center.sql` after an existing 001–015 database.
