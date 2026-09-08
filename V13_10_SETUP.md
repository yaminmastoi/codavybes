# CodaVybes V13.10 — Chat Recency + Profile Motion

## Chat fixes

- The newest 80 messages are sorted deterministically from oldest to newest.
- After the opening loader, chat waits for two render frames and immediately
  anchors to the newest message.
- A second settle runs after fonts/layout finish, preventing the composer or
  late layout changes from covering the latest message.
- Message groups use natural compact spacing and cannot stretch vertically.
- Realtime incoming and newly sent messages continue to move the view to the
  latest item.

## Profile motion

- Desktop pointer movement adds a restrained 3D tilt to the identity scene.
- Scroll position drives avatar depth, orbit movement and floating Aura,
  Rising and Bonds elements.
- Supported browsers reveal profile sections progressively as they enter view.
- Coarse-pointer devices avoid pointer tilt, and reduced-motion preferences
  disable the motion layer.

## CodaVybes naming

- Android `appName`, Windows `productName`, window title and platform shell
  metadata now show CodaVybes.
- Existing internal application identifiers and database names remain stable so
  installed-app upgrades, OAuth callbacks, routes and migrations do not break.

## Deploy

1. Web: run a clean root `npm install` and `npm run build`, then deploy `dist/`.
2. Android: run `npm install` and `npm run sync` from
   `platforms/mobile-capacitor`, then rebuild the APK.
3. Windows: run `npm install` and `npm run build` from
   `platforms/desktop-tauri`, then install the new build.

## Database

No SQL migration is required for V13.10.
