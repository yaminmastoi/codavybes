# VYBE platform shells

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

Email/password works naturally inside all clients. Google/social OAuth should use system-browser + deep-link/callback handling before App Store / Play Store / desktop production distribution. Do not ship embedded-webview OAuth as the final auth implementation.
