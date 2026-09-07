# VYBE V11.1 — Admin Verification Queue Hotfix

## Existing database
If migration `010_verification_password_ui.sql` has already been applied, run only:

`supabase/migrations/011_fix_admin_verification_result_types.sql`

Then refresh `/hq` and reopen Verification.

## Why this was needed
`admin_list_verification_requests()` declares `email text`, while `auth.users.email` is a varchar-backed field. PL/pgSQL `RETURN QUERY` requires the returned row structure to exactly match the declared function result types. V11.1 explicitly casts all returned columns.

No database reset is required. No frontend changes are required for this fix.
