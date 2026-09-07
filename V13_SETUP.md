# CodaVybes V13 setup

V13 is an upgrade on top of V12. It does not replace earlier migrations.

## Existing live database
Run only:

`supabase/migrations/014_codavybes_feed_sponsorship_sharing.sql`

Do not rerun migrations 001–013 on an existing database.

## What migration 014 adds
- Every active public post is eligible for For You (ranking still orders the feed).
- Reaction, comment and share notifications for the post author.
- Share-event analytics.
- Sponsored promotion campaigns with brand, copy, image URL, destination URL, CTA, schedule and priority.
- Sponsored placements are 18+ by default and are filtered server-side by user age.
- Promotion impression/click analytics.
- Super-admin official CodaVybes posts with all-user notification delivery.
- Official posts can appear above the organic For You feed.
- Brand-safe context defaults for CodaVybes / CodaCoins.

## Feed pacing
The client intentionally keeps paid placements sparse: roughly one sponsored card after seven organic posts, with no more than two sponsored cards in a 20-post window.

## Deploy
1. Run migration 014 in Supabase SQL Editor.
2. Push the V13 source to the same Vercel project.
3. Keep the existing `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` variables.
4. Redeploy.
5. Smoke-test Home / Rising / Share / Notifications / Chats / HQ > Promotions / HQ > Content.

## Admin surfaces
- **HQ > Promotions**: create/edit sponsored campaigns using remote image and destination URLs.
- **HQ > Content**: super_admin can publish an official CodaVybes post that notifies all eligible active users.

## Privacy / consent
The first-visit consent banner links to Privacy, Cookies, Security and Terms pages. Users can revisit privacy choices from Settings.
