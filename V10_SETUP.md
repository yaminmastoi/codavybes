# VYBE V10 setup

V10 is a frontend/layout release. It does **not** require a new Supabase migration after V9.1.

## Existing production database

Keep migrations 001–009 exactly as they are. No migration 010 is required for this responsive release.

## Run locally

```bash
npm install
npm run dev
```

Test at least these widths in browser DevTools:

- 390px — phone
- 768px — tablet
- 1024px — laptop/tablet landscape
- 1366px — desktop
- 1600px — large desktop

## Production deployment

The existing `vercel.json` SPA rewrite is preserved. Deploy the project as a normal Vite app with:

- Build command: `npm run build`
- Output: `dist`
- Existing `VITE_SUPABASE_URL`
- Existing `VITE_SUPABASE_PUBLISHABLE_KEY`

No Supabase secret/service-role key belongs in the browser.

## PWA install

The PWA install button only appears when the browser fires `beforeinstallprompt`. On iOS Safari, install continues to use the platform's Add to Home Screen UI.
