# CodaVybes GitHub Actions hotfix

Fixes:
- `Dependencies lock file is not found ...` from setup-node npm caching.
- Node 20 action-runtime deprecation warning from checkout/setup-node v4.

Changes applied to all three workflows:
- `actions/checkout@v7`
- `actions/setup-node@v7`
- Node.js `24`
- `package-manager-cache: false`
- Keep `npm install` because this repository currently has no committed `package-lock.json`.

No Supabase/database changes are required.

Replace `.github/workflows/` in your GitHub repo, commit, push, then rerun **Build CodaVybes Android APK**.
