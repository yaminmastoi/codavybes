# CodaVybes V13.2 UI Fix

This pass is UI-only. No Supabase migration is required.

## Fixed
- Desktop left navigation and right quick rail are pinned to the viewport.
- The center workspace is now the independent scroll surface.
- Chat pages no longer create full-page scrolling; the message stream scrolls instead.
- Chat composer is hard-capped to a compact 52–54px bar so it cannot stretch into a large panel.
- Horizontal overflow guardrails were added to desktop workspace and chat.
- Profile now opens on an identity-first hero: avatar, name, username and Vibe Score.
- Aura rank, wallet, stats, tabs and other details start after the first viewport and appear on scroll.
- Mobile keeps the bottom navigation and uses a compact composer/profile hero.

## Database
No SQL is needed. Keep migrations 001–014 as-is.
