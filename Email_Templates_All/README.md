# CodaVybes Auth Email Templates

Logo used everywhere:
https://codavybes.vercel.app/brand/codavybes-logo.png

Brand colors: #F6F7FA, #FFFFFF, #151821, #6F7888, #E3E6EE, #FF7A1C, #0E5060, #07151B, #FFF5DC.

Hosted Supabase: Authentication -> Email Templates.

01 Confirm signup
02 Reset password
03 Magic link / OTP
04 Invite user
05 Change email
06 Reauthentication
07-13 Security notification templates
14 Custom 4-digit Resend OTP used by CodaVybes Edge Function

For the custom OTP Edge Function, use resend-otp-snippet.ts and replace the existing inline Resend html body with otpEmailHtml(code).

Keep the logo URL public over HTTPS. If the production domain changes, replace it in all files.
