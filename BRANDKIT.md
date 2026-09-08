# CodaVybes Brand Kit — V13.15

## Brand idea

**CodaVybes is a premium social playground.** The interface should feel intentional, modern and social without looking childish, noisy or like a gaming skin.

Core voice:

- Clear, confident, concise.
- Friendly without excessive slang in system UI.
- Social copy can be playful, but controls and safety language stay professional.
- No decorative sticker clutter.
- Emoji are not used as navigation or brand icons. Social reaction payloads may still use emoji internally for compatibility, but the UI renders curated vector icons.

## Logo

The CodaVybes mark is a rounded fox app icon with a play-button eye. It communicates social energy, creator culture, chat, discovery and a premium app identity.

Implementation:

- React logo: `src/components/Logo.jsx`
- In-app rounded mark: `public/brand/codavybes-mark.png`
- Clean edited source: `public/brand/codavybes-fox-clean.png`
- SVG compatibility wrappers: `public/brand/codavybes-mark.svg`, `public/brand/codavybes-app-icon.svg`, `public/vybe-mark.svg`
- PWA / browser icons: `public/icons/`
- Desktop bundle icons: `platforms/desktop-tauri/src-tauri/icons/`
- Android icon/splash source: `platforms/mobile-capacitor/assets/`
- Visual reference: `public/brand/codavybes-logo-reference.png`

Rules:

- Keep clear space of at least 0.5× the symbol width around the mark.
- Do not add stickers, crowns, flames or emojis to the core logo.
- Use mark-only for loaders, app icon and compact navigation.
- Use mark + CodaVybes wordmark for onboarding and HQ.
- Do not place angle-bracket symbols, code marks or extra decorative glyphs inside the fox ears.

## Color system

### Light — default

- Canvas: `#F6F7FA`
- Secondary canvas: `#EEF1F6`
- Surface: `#FFFFFF`
- Secondary surface: `#F8F9FC`
- Primary text: `#151821`
- Muted text: `#6F7888`
- Border: `#E3E6EE`
- Fox Orange: `#FF7A1C`
- Deep Teal: `#0E5060`
- Midnight Navy: `#07151B`
- Warm Cream: `#FFF5DC`

### Dark

- Canvas: `#0B0D12`
- Secondary canvas: `#0F1218`
- Surface: `#14171E`
- Secondary surface: `#191D25`
- Primary text: `#F4F6FA`
- Muted text: `#9199A8`
- Border: `#282D38`
- Fox Orange: `#FF8A2A`
- Deep Teal: `#0E5060`
- Midnight Navy: `#07151B`
- Warm Cream: `#FFF5DC`

Brand emphasis uses the fox orange → deep teal family. Aura remains separate from purchasable/status styling.

## Typography

Heading family:

`Sora`

Primary UI family:

`Inter`

Fallback:

`Segoe UI`, system sans-serif.

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

1. **App / protected-route loader** — mark-only fox intro with a short pop/pulse and fade-style transition.
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
