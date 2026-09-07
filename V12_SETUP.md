# VYBE V12 — 8 Room Games + 10K+ Prompt Bank

## Existing V11.2 database
Run only:

`supabase/migrations/013_games_expansion_10k.sql`

Do **not** rerun 001–012.

## Games now available
1. Rapid Trivia — server-scored factual multiple choice.
2. Puzzle Battle — arithmetic/logic speed rounds.
3. Most Likely To — room-member voting.
4. Would You Rather — choose a side; majority picks score higher when the round closes.
5. Emoji Decode — decode visual phrases.
6. Riddle Rush — quick number/logic riddles.
7. Word Scramble — timed word unscrambling.
8. Spot the Lie — identify the one false statement.

## Question/prompt bank
Migration 013 seeds more than 10,000 active server-side prompts. The migration contains an assertion and rolls back if the active bank is below 10,000.

Approximate seed mix before any existing/custom questions:
- Would You Rather: 3,570
- Most Likely To: 2,000
- Puzzle Battle: 2,500
- Spot the Lie: 2,000
- Riddle Rush: 500
- Word Scramble: 600
- Rapid Trivia: 600+
- Emoji Decode: 80

Total: 11,800+ seeded prompts/questions.

Correct answers remain in the private schema. The client never decides score, winner, XP, or verified Aura.

## UI fixes
The Rising/For You feed identity header was reorganized for narrow phones. Display name, verified badge, handle/context, Aura, and rank no longer fight for one horizontal line. Long names and handles truncate predictably instead of breaking card width.

## Admin HQ
HQ → Content → Game Engine can create questions for all eight game types after migration 013.
