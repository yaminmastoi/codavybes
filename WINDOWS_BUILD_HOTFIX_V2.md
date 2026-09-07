# CodaVybes Windows Build Hotfix V2

The Windows Tauri workflow was failing because `beforeBuildCommand` used `cd ../../..`, which was evaluated from `platforms/desktop-tauri` and overshot the repository root on GitHub Actions.

Fixed in `platforms/desktop-tauri/src-tauri/tauri.conf.json`:

- `beforeBuildCommand`: `npm --prefix ../.. run build`
- `beforeDevCommand`: `npm --prefix ../.. run dev -- --host 127.0.0.1`

No database migration is required.
