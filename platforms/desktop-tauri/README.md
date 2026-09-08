# CodaVybes Desktop — Tauri shell

This shell packages the same CodaVybes React build as a lightweight Windows/macOS desktop application.

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

The Tauri commands run from `platforms/desktop-tauri`, so the root frontend is
reached with `../..`. The `frontendDist` path remains `../../../dist` because
that setting is resolved relative to `src-tauri/tauri.conf.json`.

If GitHub Actions reports that it cannot find `D:\\a\\<repo>\\package.json`,
make sure the workflow runs the desktop command from the shell directory:

```yaml
- name: Build Windows app
  working-directory: platforms/desktop-tauri
  run: npm run build
```

## Google OAuth return to Windows

The Windows shell includes Tauri's opener, deep-link and single-instance
plugins. Google opens in the system browser and returns to the installed app at:

- `app.vybe.desktop://auth/callback`
- `app.vybe.desktop://auth/reset-password`

Add both URLs to the Supabase Auth redirect allow list before building the
installer. The protocol is registered by the installed Windows bundle.

## Production checklist

Before public desktop distribution add:

- Native desktop notifications for background delivery
- Auto-update signing/feed
- Windows code signing / macOS notarization
- Optional system tray behavior

Do not embed Supabase service-role credentials in the desktop bundle.
