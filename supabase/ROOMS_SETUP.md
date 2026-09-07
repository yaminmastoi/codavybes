# VYBE Rooms + Games Setup

Run migrations in this exact order:

1. `001_auth_onboarding.sql`
2. `002_aura_engine.sql`
3. `003_chat_groups_realtime.sql`
4. `004_rooms_games.sql`

## What Phase 4 adds

- Room creation from an existing DM/group conversation.
- Every active conversation member is invited; the creator becomes host.
- Realtime lobby membership and game-state refreshes.
- Puzzle Battle, Rapid Trivia, and Most Likely To.
- Server/database-authoritative answer validation and scoring.
- 3 rounds per game by default.
- Winner XP, Room Win count, verified game Aura and verified Room MVP Aura.
- Private answer keys: authenticated clients cannot read correct answers or other players' live submissions.

## Security model

The browser never sends `score`, `winner`, `mvp`, `vibe_xp`, or `aura_reward`. It only sends a selected answer. PostgreSQL calculates the score and final placement and calls the trusted verified-Aura function internally.

Do **not** expose the Supabase service-role/secret key to the browser. `award_verified_aura()` remains non-executable by authenticated users.

## Admin-ready config

`public.room_config` contains the values VYBE HQ can later manage through a privileged admin backend: player limits, rounds, timers, XP and Aura rewards.
