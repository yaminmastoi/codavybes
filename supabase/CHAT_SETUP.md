# VYBE Chat Setup

## 1. Apply migrations in order

Run:

1. `001_auth_onboarding.sql`
2. `002_aura_engine.sql`
3. `003_chat_groups_realtime.sql`

The third migration creates chats/groups/messages/reactions/blocks, the private report queue, secure RPCs, RLS, and adds messages/reactions/conversation membership to the standard `supabase_realtime` publication when it exists.

## 2. Create two test users
Both users must complete email/Google auth, username, DOB eligibility and onboarding.

## 3. Test

- Login as account A.
- Open **Chats** → new-chat icon.
- Search account B by username/display name.
- Start a 1:1 chat.
- Send a message.
- Login as B in another browser/incognito session.
- Open the chat; messages should refresh through Realtime.
- React with 😂/💀/🔥.
- Press **Aura +1** on A's message.
- A's message Aura and lifetime profile Aura should rise.
- A cannot Aura their own message.
- Repeated Aura on the same message is idempotent.

## 4. Privacy rule
Chat Aura targets are stored as `visibility='private'`; receiving enough Aura can mark an in-chat Aura Moment but never sets public FYP eligibility.

## 5. Admin-controlled knobs later
`chat_config` is already database-driven for VYBE HQ: message length, group size, message velocity, direct-chat creation and group creation limits. Do not give normal clients write access to this table.
