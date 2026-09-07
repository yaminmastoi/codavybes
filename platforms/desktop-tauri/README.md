# VYBE Desktop — Tauri shell

This shell packages the same VYBE React build as a lightweight Windows/macOS desktop application.

## Requirements

- Node/npm
- Rust toolchain
- Tauri OS prerequisites

## First setup

```bash
# root app
cd ../..
npm install

# desktop shell
cd platforms/desktop-tauri
npm install
npm run dev
```

Production bundle:

```bash
npm run build
```

Tauri will run the root `npm run build` first and bundle `dist/`.

## Production checklist

Before public desktop distribution add:

- System-browser OAuth callback/deep-link handling
- Native desktop notifications for background delivery
- Auto-update signing/feed
- Windows code signing / macOS notarization
- Optional system tray behavior

Do not embed Supabase service-role credentials in the desktop bundle.
