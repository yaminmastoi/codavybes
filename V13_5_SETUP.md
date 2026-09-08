# CodaVybes V13.5 — Chat Controls, Typing and Receipts

## Existing live database

Run this migration after migration 016:

`supabase/migrations/017_chat_controls_receipts.sql`

Do not rerun migrations 001–016 on an existing database.

## Included behavior

- **Clear chat:** the three-dot menu clears the current history only for the member who chose it. The other participants keep their history, and new messages appear normally.
- **Delete message:** a sender can delete only their own active text message. Everyone sees a deleted-message placeholder after the realtime update.
- **Typing:** ephemeral Supabase Realtime broadcast shows `is typing…` in the chat header. It is not stored in the database.
- **Receipts:** one grey tick means accepted by the server while no recipient has acknowledged delivery, two grey ticks mean delivered to an active recipient, and two red ticks mean viewed.
- **Background delivery:** opening or returning to the app acknowledges pending incoming messages without marking them viewed. Opening the conversation marks them viewed.

## Deploy

1. Run migration 017 in the Supabase SQL Editor.
2. Install dependencies from a clean platform-local `node_modules` folder.
3. Run `npm run build`.
4. Deploy the new web build.
5. Re-sync the Capacitor web bundle before making a new Android build.

Supabase Realtime must remain enabled for `messages`, `conversation_members`, and `message_reactions`. Typing uses Realtime Broadcast and does not require an additional table.
