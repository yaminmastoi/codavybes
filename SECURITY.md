# CodaVybes Security Notes

## Browser-safe credentials only
The frontend may contain the Supabase URL and publishable/anon key. Never expose a service-role/secret key.

## Identity / DOB / username
Protected identity changes are constrained RPCs. DOB stays in `private.user_private`. Username final ownership is enforced by the database unique index, not the frontend availability check.

## Aura authority
`aura_events` is the immutable reputation ledger. Authenticated clients cannot directly write Aura totals/events/targets. Peer Aura amount, giver and receiver are server/database chosen. Daily, pair, reciprocal-pair and duplicate-target limits apply.

## Public FYP vs private chat
Public Rising/FYP targets and private chat targets use the same Aura economy but different visibility rules. Message Aura can increase a sender's lifetime Aura/rank and can create an in-chat Aura Moment, but `give_message_aura()` always leaves `fyp_eligible=false`. A private message must never leak into public discovery automatically.

## Chat authorization
All chat mutations are RPC-only. RLS allows direct SELECT only when `chat_is_member(conversation_id)` is true for the current authenticated user. The client never supplies a sender id or membership role.

## Realtime
Realtime is enabled for `messages`, `message_reactions`, and `conversation_members`; their SELECT RLS still scopes rows to active conversation members. Do not replace these policies with `using(true)`.

## DMs and blocking
Direct-chat creation and sending reject users when either side has blocked the other. Blocking also removes the blocker's active membership from shared direct conversations so the conversation disappears from their list. Shared-group handling can be expanded later with per-user hidden-message semantics.

## Reports
Reports are inserted into `private.safety_reports` via a constrained RPC. Authenticated clients receive no direct SELECT grant on that table. Future CodaVybes HQ moderation should access it only through authorized admin backend actions and audit every moderation decision.

## Rate limits
DB limits cover message velocity, direct-chat creation, group creation and Aura economics. Before public beta, add edge/API/device/IP risk rate limiting too; DB limits alone are not sufficient against distributed abuse.

## Rooms / games
Never let the browser declare game score, winner, XP or verified Aura. Room/game results must be calculated by a trusted server and then call service-role-only `award_verified_aura()` idempotently.

## Still required before public beta
- secure avatar/media Storage policies and content scanning
- full moderation HQ + immutable admin audit logs
- stronger spam/device/session risk controls
- notification service
- group owner/admin membership controls
- delete/edit-message policy and retention rules
- explicit public-share consent flow for private Aura Moments
- age-segmented discovery if minors are ever supported

## Phase 4 — Room/game security

- Rooms inherit membership from an existing authorized conversation.
- Non-members cannot read or join arbitrary Rooms.
- Correct game answers are stored in `private.game_answer_keys` / the private question bank.
- Authenticated clients have **no SELECT grant** on `game_submissions`, preventing players from reading other users' live answers.
- Client sends only its answer choice. The database computes correctness, speed score, final placement, XP and Room wins.
- `award_verified_aura()` remains unavailable to `authenticated`; the server-authoritative game finalizer invokes it internally.
- Verified game/MVP Aura uses source IDs for idempotency, preventing duplicate reward farming.
- Realtime publication includes only safe room/game state tables, not private answers or live submissions.


## V6 age-safe social loop

- Minimum signup age is 10.
- Stranger discovery, Meet, peer Aura, direct-chat creation and new groups are separated into 10–12 / 13–17 / 18+ pools.
- Exact DOB stays in `private.user_private`; minor Discover cards expose only a broad age label.
- Direct chats require a mutual CodaVybes connection created through Meet.
- Both users must choose Keep before a Meet becomes a permanent connection.
- Bond points are database-triggered and ledger-backed; the client cannot submit a Bond score.
- Public FYP/Rising/Aura Board/profile read surfaces are restricted to the viewer's age-safety pool.
- A message insert trigger blocks cross-pool writes even for conversations created before the V6 migration.
- 10–12 access is a technical baseline, not a declaration of legal compliance for child-directed services in every jurisdiction.

## V7 — CodaVybes HQ

- HQ access is authorized in PostgreSQL through `private.admin_users`; React route guards are not trusted for authorization.
- Roles are split into Super Admin, Admin, Moderator and Analyst.
- Every privileged config/user/content mutation writes to `private.admin_audit_log`.
- User account restrictions are enforced by database account-state helpers, age/discovery compatibility, restrictive RLS policies and core chat/Room membership helpers.
- Admin Aura corrections create ledger events; the app never silently overwrites reputation history.
- Exact DOB remains private and is only returned through a role-checked admin detail RPC.
- Supabase Auth Admin operations live in the optional `hq-auth-action` Edge Function. Secret/service-role credentials stay server-side only.
- Shop catalog and monetization config do not grant entitlements by themselves. Future payment fulfillment must be server-authoritative and idempotent.
