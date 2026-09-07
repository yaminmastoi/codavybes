# VYBE V11 setup — Verification + Password Recovery + UI cleanup

V11 is an upgrade on top of V10/V9.1. It does **not** replace your Supabase project and it does not require a database reset.

## 1) Database

If your current live database already has migrations `001` through `009`, run only:

```text
supabase/migrations/010_verification_password_ui.sql
```

The migration adds:
- public blue-tick state on profiles
- private verification request/review records
- user verification request RPCs
- VYBE HQ verification review RPCs
- audited admin verification override
- verification approve/reject system notifications

Do not expose the `private` schema or a service-role key to the browser.

## 2) Supabase password recovery URLs

In **Supabase Dashboard → Authentication → URL Configuration** keep your production VYBE URL as the Site URL.

For the current deployment, use an allowed redirect such as:

```text
https://vybe-beryl.vercel.app/**
```

For local development also allow:

```text
http://localhost:5173/**
```

VYBE sends recovery links with:

```text
/reset-password
```

so wildcard redirect rules above cover the recovery page as well as auth/onboarding routes.

## 3) Forgot / reset password test

1. Open login.
2. Press **Forgot password?**
3. Enter the account email.
4. Open the Supabase recovery email.
5. The link should return to `/reset-password`.
6. Enter a password that passes all four strength checks.
7. Continue back into VYBE and verify the new password works after sign-out/sign-in.

The forgot-password confirmation is deliberately generic so the UI does not disclose whether an email is registered.

## 4) Blue-tick verification test

As a normal user:

1. Settings → **Verification / Blue tick**.
2. Press **Apply**.
3. Choose account type, enter a 20+ character explanation, and optionally add an `http(s)` evidence link.
4. Submit. The user should see **Review pending**.

As Admin/Super Admin:

1. Open `/hq`.
2. Open **Verification**.
3. Review the request.
4. Approve or reject it.
5. Approval sets `profiles.is_verified=true` and the blue badge appears across identity surfaces.
6. The user receives an in-app/system notification from VYBE.

Admins can also open a user from HQ and apply/remove the blue tick directly. That action is audited.

Verification is a trust/identity signal. It cannot be purchased with Aura or VYBE Coins.

## 5) UI button cleanup

V11 adds a final layout discipline pass:
- button shadows and button gradients removed
- simple background/border hover only
- action rows wrap instead of overflowing
- long labels/text can shrink or wrap safely
- feed actions use equal-width columns
- mobile HQ controls stack where necessary
- login/reset/verification actions have consistent full-width/form alignment

## 6) Deploy

No new environment variables are required beyond the existing VYBE Supabase variables.

```bash
npm install
npm run build
```

Push this version to the same repository/Vercel project. Your existing `vercel.json` SPA rewrite remains valid.
