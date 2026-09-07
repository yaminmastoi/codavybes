# VYBE Mobile — Capacitor shell

This package turns the root responsive VYBE build into Android/iOS native shells.

## Requirements

- Node/npm
- Android Studio for Android
- macOS + Xcode for iOS

## First setup

From repository root:

```bash
npm install
npm run build
cd platforms/mobile-capacitor
npm install
```

Android:

```bash
npm run add:android
npm run android
```

iOS (macOS only):

```bash
npm run add:ios
npm run ios
```

After changing the React app:

```bash
npm run sync
```

## Production checklist

Before store submission add native implementations for:

- System-browser Google OAuth + app deep links
- Native push notifications (APNs/FCM)
- Camera/gallery permissions for profile/media uploads
- Haptics for Aura and game feedback
- Universal/App Links for VYBE URLs

Never place the Supabase service-role/secret key in Capacitor config or bundled JavaScript.
