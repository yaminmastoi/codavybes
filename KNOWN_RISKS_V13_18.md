# Known Remaining Risks — V13.18

1. **Build verification:** dependency installation timed out in the current execution environment, so the patched source must pass a clean `npm install && npm run build` in CI/local development before production release.
2. **Package lock:** new native frontend dependencies are declared in `package.json`; regenerate/update `package-lock.json` during the clean npm install before using `npm ci` elsewhere.
3. **Firebase config:** no real Firebase service account or `google-services.json` is embedded. Production closed-app Android push will not work until those secrets are configured.
4. **Email provider:** 4-digit verification depends on Resend and a verified sender domain. Keep Edge Function secrets server-only.
5. **4-digit OTP strength:** challenge lifetime is 5 minutes, resend cooldown is 60 seconds and max attempts is 5. Do not weaken these protections.
6. **Desktop after explicit quit:** Windows/Linux notifications continue while the app is hidden in tray, not after the user explicitly quits the process. A true process-terminated desktop push channel would need a separate OS-level background push service.
7. **Historical data:** migration 022 restores accounts previously labeled ineligible. If older code had already released/deleted a historical username, that exact username cannot be reconstructed automatically.
8. **Pre-existing binaries:** any APK/MSI/Linux package/RPM already present in the uploaded project predates this source patch and must be rebuilt/replaced before launch.
