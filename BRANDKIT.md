# CodaVybes Brand Kit — V9

## Brand idea

**CodaVybes is a premium social playground.** The interface should feel intentional, modern and social without looking childish, noisy or like a gaming skin.

Core voice:

- Clear, confident, concise.
- Friendly without excessive slang in system UI.
- Social copy can be playful, but controls and safety language stay professional.
- No decorative sticker clutter.
- Emoji are not used as navigation or brand icons. Social reaction payloads may still use emoji internally for compatibility, but the UI renders curated vector icons.

## Logo

The CodaVybes mark is an interlocking ribbon **V** made from two directional forms. It communicates connection, movement and two people meeting in the middle.

Implementation:

- React logo: `src/components/Logo.jsx`
- App / notification mark: `public/vybe-mark.svg`
- Visual reference: `brand-reference.png`

Rules:

- Keep clear space of at least 0.5× the symbol width around the mark.
- Do not add stickers, crowns, flames or emojis to the core logo.
- Use mark-only for loaders, app icon and compact navigation.
- Use mark + CodaVybes wordmark for onboarding and HQ.

## Color system

### Light — default

- Canvas: `#F6F7FA`
- Secondary canvas: `#EEF1F6`
- Surface: `#FFFFFF`
- Secondary surface: `#F8F9FC`
- Primary text: `#151821`
- Muted text: `#6F7888`
- Border: `#E3E6EE`
- CodaVybes Violet: `#7258F5`
- CodaVybes Blue: `#3978F6`

### Dark

- Canvas: `#0B0D12`
- Secondary canvas: `#0F1218`
- Surface: `#14171E`
- Secondary surface: `#191D25`
- Primary text: `#F4F6FA`
- Muted text: `#9199A8`
- Border: `#282D38`
- CodaVybes Violet: `#8A73FF`
- CodaVybes Blue: `#5A8CFF`

Aura and interactive emphasis use the violet → blue family. Aura is never represented by purchasable gold/status styling.

## Typography

Primary UI family:

`Plus Jakarta Sans`

Fallback:

`Avenir Next`, `Segoe UI`, system sans-serif.

Guidelines:

- H1/H2: 700–800, tight tracking.
- UI controls: 650–750.
- Body: 400–550.
- Small labels / eyebrow text: 750–800 with controlled tracking.
- Avoid novelty, brush, handwritten and graffiti fonts in product UI.

## Iconography

Library: `lucide-react`

- Stroke: usually 1.8–2.0.
- Icons live inside 32–40px soft containers for primary actions.
- Use one icon per concept consistently.
- Emoji are reserved only as underlying reaction values where required by the existing database API; users see vector reaction icons.

## Surfaces

- Main card radius: 18px.
- Controls: 12–14px.
- Borders are subtle and visible in both themes.
- Shadows stay soft in light mode and deeper but restrained in dark mode.
- Avoid large neon glows behind normal cards.

## Motion & loading

CodaVybes has three loading levels:

1. **App / protected-route loader** — animated CodaVybes mark and progress line.
2. **Content fetch** — skeleton cards matching the final layout.
3. **Action state** — compact inline spinner inside the affected button.

`prefers-reduced-motion` disables nonessential motion.

## Theme behavior

- Fresh installs start in **Light**.
- Settings offers Light / Dark / System.
- Preference is stored locally for instant startup and in Supabase `user_preferences.theme_preference` for account persistence.
- Both themes share identical information architecture and component spacing.

## Commerce visibility

User-facing monetization surfaces obey HQ configuration in realtime:

- Shop disabled → Shop links and `/shop` disappear / redirect.
- CodaVybes+ disabled → CodaVybes+ links and `/vybe-plus` disappear / redirect.
- Top-ups disabled → wallet remains available, but every top-up action and package surface disappears.

Aura remains completely separate from CodaCoins.
