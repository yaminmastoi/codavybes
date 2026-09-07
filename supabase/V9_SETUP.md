# VYBE V9 setup

## Existing V8.1 project

If migrations `001` through `008` are already applied, run only:

```text
009_brand_theme_notifications_feature_gates.sql
```

Then reload the app and sign in again if Supabase has an old cached session.

## Fresh database

Run migrations in this exact order:

```text
001_auth_onboarding.sql
002_aura_engine.sql
003_chat_groups_realtime.sql
004_rooms_games.sql
005_social_loop_bonds_age10.sql
006_vybe_hq_admin.sql
007_user_experience_commerce.sql
008_fix_private_helper_rls_permissions.sql
009_brand_theme_notifications_feature_gates.sql
```

## What 009 adds

- `theme_preference` on `user_preferences`.
- `system_notifications` preference.
- Updated safe preferences RPC.
- Explicit commerce capability summary.
- Realtime publication for notifications, announcements, feature flags and monetization config when the standard Supabase Realtime publication exists.

## System notifications

The frontend registers `/vybe-sw.js` and asks the user for browser notification permission from Settings.

Requirements:

- HTTPS in production (`localhost` is allowed for local development).
- Browser notification permission must be granted.
- `System notifications` must be enabled in VYBE Settings.

Current implementation produces OS/browser notifications for realtime VYBE notifications while the web app/PWA has an active session. True push delivery when every VYBE tab is fully closed requires a Web Push/VAPID delivery service and is intentionally not faked in the browser.

## Commerce feature gates

HQ changes are reflected through realtime capability refresh:

- `feature_flags.shop = false` → no user Shop surface.
- `feature_flags.vybe_plus = false` OR `monetization_config.vybe_plus_enabled = false` → no VYBE+ surface.
- `monetization_config.topups_enabled = false` → Top Up UI is completely removed while Wallet ledger/balance stays available.

The secure purchase RPCs remain authoritative even if a user manually tries to navigate to a hidden route.
