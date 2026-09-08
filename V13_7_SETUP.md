# CodaVybes V13.7 — Brand Loader + Sticky Profile Threads

## Existing live database

Run this migration after migration 017:

`supabase/migrations/018_profile_rising_threads.sql`

Do not rerun migrations 001–017 on an existing database.

Migration 018 keeps the existing RPC name for compatibility but restricts profile content to the signed-in user's active, public `post` targets. Messages, Room results and game results cannot appear in the Threads tab.

## Included behavior

- App opening, chat opening and every existing `AppLaunchLoader` use the same CodaVybes brand intro.
- The animation reveals the logo mark first and the CodaVybes name second in a 1.45-second sequence.
- The profile identity becomes a compact sticky bar after 86px of page scroll and returns to its full hero at the top.
- The compact bar retains avatar, display name, username, verification/Plus badges and Vibe Score.
- The former Moments tab is now Threads and contains only posts uploaded through Rising Lab.

## Deploy

1. Run migration 018 in the Supabase SQL Editor.
2. Install dependencies from a clean platform-local `node_modules` folder.
3. Run `npm run build` and deploy the web build.
4. Run the Capacitor sync flow before rebuilding Android.
