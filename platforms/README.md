# CodaVybes platform shells

The root Vite application is the shared product. Do not fork backend logic between clients.

## Web / PWA

Build from the repository root:

```bash
npm install
npm run build
```

Deploy `dist/` to Vercel. The PWA manifest and service worker are already in `public/`.

## Android / iOS

See `mobile-capacitor/README.md`.

Capacitor copies the same root `dist/` into native projects. Keep Supabase/RLS as the source of truth.

## Windows / macOS

See `desktop-tauri/README.md`.

Tauri embeds the same root `dist/` in a lightweight desktop application.

## Important auth note

Authentication sessions use persistent PKCE storage in every client. Google OAuth opens the system browser on Android and Windows, then returns to the originating client through its registered deep link. See `../V13_9_SETUP.md` for the required Supabase redirect allow list.
