# VYBE V8 — Settings, Notifications & Commerce

Run migrations in this order:

1. `001_auth_onboarding.sql`
2. `002_aura_engine.sql`
3. `003_chat_groups_realtime.sql`
4. `004_rooms_games.sql`
5. `005_social_loop_bonds_age10.sql`
6. `006_vybe_hq_admin.sql`
7. `007_user_experience_commerce.sql`

## What V8 adds

- DB-backed Settings / notification preferences
- Real Settings username editor using the existing globally-unique 30-day cooldown RPC
- In-app notification inbox and unread counter
- Notifications for Aura, chat messages, Meet requests and Room invites
- Working public Moment React / Reply / Share flow
- VYBE Coins wallet + immutable wallet ledger
- 100 default welcome coins (admin configurable for new wallets)
- Top-up package catalog
- Server-side top-up checkout intent gate
- VYBE Shop purchases with coin balance locking
- Owned/equipped cosmetics
- VYBE+ 30-day subscription bought with VYBE Coins
- VYBE HQ coin adjustment, top-up package management and coin-priced Shop items

## Important payment note

V8 intentionally does **not** fake a successful real-money payment. `create_topup_checkout()` returns `checkout_ready=false` while `monetization_config.payment_provider='unconfigured'`.

This means the Top Up screen is real and the server validates packages, but no coins are issued until a real payment provider is integrated server-side and a verified webhook/settlement flow marks a checkout paid.

Never make the browser send `paid=true`, `coins=...`, or directly update `vybe_wallets`.

## User routes

- `/notifications`
- `/settings`
- `/wallet`
- `/shop`
- `/vybe-plus`
- `/moments/:targetId`

## Economy rule

**Aura is earned. VYBE Coins are spendable.**

There is no RPC that converts VYBE Coins into Aura or rank.

## Button/navigation cleanup

V8 also wires previously decorative or incomplete surfaces:

- Home notification bell → notification inbox
- Profile Settings gear → Settings
- Profile tabs → real local panels
- Home movement cards / feed tabs → actual routes
- Feed React / Reply / Share → working interactions
- Discover search → working filter surface
- Home/Profile Wallet cards → Wallet / Shop / VYBE+

A static JSX button audit reports zero bare/dead buttons in `src/`.
