# CodaVybes V13.4 — Responsive Chat + Cross-Age Social Compatibility

## Existing live database

Run only:

`supabase/migrations/016_cross_age_discovery_chat.sql`

Run it after migration 015. Do not rerun migrations 001–015.

## What changes

- Eligible active users can appear in Discover across age groups.
- Meet, connection creation, direct/group chat, profile visibility and related social checks no longer require matching age-band slugs.
- The 10+ signup gate remains unchanged.
- If either person blocks the other, Discover/Meet/chat access remains unavailable in both directions.
- Permanent direct chat still unlocks through the existing mutual Keep flow.
- Laptop/tablet sidebar is a stable compact icon rail; full sidebar labels return at 1280px and above.
- Chat header, message stream, actions and composer now stay inside the available viewport on mobile, tablet and desktop.

## Deploy

1. Run migration 016 in the Supabase SQL Editor.
2. Install dependencies from a clean platform-local `node_modules` folder.
3. Run `npm run build`.
4. Deploy the new web build.
5. For Android, run the Capacitor sync/build flow so the latest `dist/` is copied into the APK.
