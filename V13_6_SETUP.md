# CodaVybes V13.6 — Floating Mobile Navigation + Android Alerts

## Included behavior

- Mobile navigation keeps the existing CodaVybes destinations: Home, Discover, Rooms, Chats and You.
- The bar is now a compact floating surface with an original CodaVybes active state.
- Scrolling down hides the bar after a small movement; scrolling up restores it quickly. Route changes and returning near the top also restore it.
- Scroll direction works for both document pages and internal scrolling surfaces such as chat.
- Android uses Capacitor Local Notifications instead of failing the browser Notification API check inside the WebView.
- Android 13+ permission, a high-importance notification channel, test notifications and notification-tap navigation are included.

## Web deployment

No database migration is required. Install from a clean local dependency folder, run `npm run build`, and deploy the resulting web build.

## Android update

From `platforms/mobile-capacitor`:

```bash
npm install
npm run sync
```

Rebuild and reinstall the APK. In the installed app, open Settings → System notifications → Enable. Accept the Android prompt, then use **Send test notification**.

The included native channel handles notifications produced while the app process is available. True delivery after the app is fully terminated requires a separate FCM server-sender setup and `google-services.json`.
