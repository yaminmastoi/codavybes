# VYBE V12 Game Bank

V12 ships eight Room games and seeds 11,800+ active server-side prompts/questions.

| Game | Approx. seeded bank | Scoring |
|---|---:|---|
| Rapid Trivia | 600+ | correct + speed |
| Puzzle Battle | 2,500 | correct + speed |
| Most Likely To | 2,000 | room votes |
| Would You Rather | 3,570 | majority choice |
| Emoji Decode | 80 | correct + speed |
| Riddle Rush | 500 | correct + speed |
| Word Scramble | 600 | correct + speed |
| Spot the Lie | 2,000 | correct + speed |

Migration `013_games_expansion_10k.sql` performs a final database assertion: if fewer than 10,000 active prompts exist after seeding, the migration raises an error and rolls back.

The question bank and answer keys stay in the private schema. Authenticated clients only see the active round prompt/options; correct answers are never granted as a direct table read.
