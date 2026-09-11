# CodaVybes V13

## V13.16 — Supabase signup + analytics hotfix

V13.16 fixes production signup failures caused by a zero-value welcome wallet ledger entry and upgrades older analytics deployments whose `session_id` column is still UUID-typed. Apply `supabase/migrations/021_signup_analytics_hotfix.sql` once after migration 020; do not rerun the full migration history.

## V13.15 — fox brand + Linux desktop build

V13.15 integrates the final rounded fox logo across the React brand component, app intro loader, PWA metadata, favicons, OG preview, Android asset source, Windows icons and Linux desktop bundle icons. The ear `< >` symbols were removed from the source logo. Desktop now includes separate Windows and Linux Tauri build scripts; Linux builds produce `deb`, `rpm` and `AppImage` artifacts on an Ubuntu runner.

Run `npm run verify:launch` before release. See `V13_15_FOX_BRAND_LINUX.md`.

## V13.14 — HQ analytics restore

V13.14 adds a first-party analytics system back into CodaVybes HQ: active users, active sessions, platform/device mix, location/IP metadata, top pages, recent sessions and privacy-safe retention cleanup. It also wires optional Google Analytics 4 through `VITE_GA_MEASUREMENT_ID`.

Run `supabase/migrations/020_codavybes_analytics_restore.sql` after migration 019 and deploy `supabase/functions/track-analytics` if you want IP/location capture. Service-role access can use `PRIVATE_SB_SECRET_KEY` in Supabase Function Secrets. See `V13_14_ANALYTICS_SETUP.md`.

## V13.12 — For You inventory + promotions delivery

V13.12 fixes promotions disappearing when the organic feed has fewer than six posts, automatically enables Feed ads when an active campaign is saved, exposes accurate campaign state in HQ, and reinstalls the all-public-post For You RPC. Run `supabase/migrations/019_fyp_promotions_delivery.sql` after migration 018. See `V13_12_SETUP.md`.

## V13.11 — Moment thread alignment + platform parity guard

V13.11 repairs Moment/reply layout from 280px mobile widths through desktop and adds an automated check proving that Web/PWA, Android Capacitor and Windows Tauri package the same shared routes and frontend output. No database migration is required.

Run `npm run verify:launch` and read `V13_11_LAUNCH_READINESS.md` before release packaging.

## V13.4 — Responsive chat + cross-age discovery

V13.4 fixes compact/expanded desktop sidebar behavior and makes the chat viewport, messages and composer responsive across mobile, tablet and desktop. It also allows every eligible active 10+ account to discover/connect across age groups while preserving symmetric block enforcement, account restrictions and the existing mutual-Keep chat flow.

For an existing V13.3 database, run only `supabase/migrations/016_cross_age_discovery_chat.sql`. See `V13_4_SETUP.md`.

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
- Earlier CodaVybes ribbon branding is superseded by the V13.15 fox app mark.
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

## V13.5 chat controls and live status

- Three-dot menu now includes per-user **Clear chat**.
- Senders can delete their own messages for everyone.
- Live `is typing…` status uses Supabase Realtime Broadcast.
- Message receipts show one grey tick for pending/offline, two grey ticks for delivered, and two red ticks for viewed.
- Run `supabase/migrations/017_chat_controls_receipts.sql` after migration 016.

See `V13_5_SETUP.md` for deployment details.

## V13.6 mobile navigation and Android alerts

- Existing Home, Discover, Rooms, Chats and You links now use a floating mobile navigation surface.
- Down-scroll hides the bar and up-scroll restores it.
- Capacitor Android builds use native Local Notifications with Android 13+ permission handling and a dedicated alert channel.
- No database migration is required.

See `V13_6_SETUP.md` before rebuilding the APK.

## V13.7 brand loader and profile Threads

- App and chat opening use a shared 1.45-second CodaVybes logo-to-name animation.
- Profile identity compacts into a persistent sticky bar during scroll and expands again at the top.
- The profile Moments tab is replaced by Threads containing only the user's public Rising Lab posts.
- Run `supabase/migrations/018_profile_rising_threads.sql` after migration 017.

See `V13_7_SETUP.md` for deployment order.

## V13.8 distraction-free mobile chat

- The primary bottom navigation is not rendered inside an open conversation and returns after leaving the chat.
- Mobile chat now owns the full dynamic viewport, with its compact composer locked to the bottom safe area.
- Site-wide vertical scrollbars use a small themed thumb and horizontal scrollbar rails are hidden.
- Windows Tauri builds use the corrected `../..` root command path from `platforms/desktop-tauri`.
- No database migration is required.

See `V13_8_SETUP.md` for deployment notes.

## V13.9 persistent cross-platform authentication

- Supabase sessions now use explicit persistent storage, PKCE and automatic token refresh across web, Capacitor and Tauri.
- Google OAuth opens in the system browser on Android and Windows and returns to the same client through registered deep links.
- Web OAuth finishes on `/auth/callback`; password reset uses the matching callback flow.
- The Windows shell includes deep-link, opener and single-instance support.
- No database migration is required; Supabase redirect allow-list configuration is required.

See `V13_9_SETUP.md` before deploying or rebuilding native clients.

## V13.10 chat recency, profile motion and product naming

- Chat messages use deterministic chronological ordering and reliably settle on the newest message after the opening loader.
- Message rows keep compact natural spacing instead of stretching across the conversation viewport.
- Profile identity includes subtle pointer tilt, scroll depth, orbit elements, floating social chips and scroll-reveal cards.
- Android and Windows display names, window titles and shell metadata now use CodaVybes rather than VYBE.
- No database migration is required.

See `V13_10_SETUP.md` for rebuild notes.

## V13.13 production brand assets

- The approved CodaVybes logo is integrated across the React logo component, splash loader, PWA manifest, favicon, Apple icon, notifications, OG/Twitter preview and Windows bundle assets.
- Windows Tauri now has a valid `src-tauri/icons/icon.ico` plus explicit MSI/NSIS icon config, fixing the `Couldn't find a .ico icon` workflow failure.
- Chat detail no longer shows the branded opening splash or waits on the old artificial loader delay.
- Public launch basics are included: `robots.txt`, `sitemap.xml`, and a 1200x630 `og-image.png`.
- No database migration is required.

See `V13_13_BRAND_ASSETS.md` for asset paths and Supabase redirect allow-list notes.
