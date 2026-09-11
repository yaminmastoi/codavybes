# CodaVybes V13.16 — Supabase signup and analytics hotfix

This migration fixes two production errors:

- Signup failed when `welcome_coins` was `0`, because the wallet bootstrap tried to write a zero-value ledger row while `wallet_ledger_amount_check` correctly rejects zero movements.
- Older analytics deployments used a UUID `session_id`, while the browser sends an opaque text session identifier.

## Apply

Run only this migration on a project that already has migrations `001` through `020`:

```text
supabase/migrations/021_signup_analytics_hotfix.sql
```

Do not rerun the full migration history on the production project. The migration preserves existing wallet and analytics rows; it only converts the existing private analytics event session column to text when needed and updates the wallet bootstrap function.

## Supabase Dashboard steps

1. Open the CodaVybes Supabase project and go to **SQL Editor → New query**.
2. Paste the complete contents of `supabase/migrations/021_signup_analytics_hotfix.sql` and select **Run**.
3. Wait for the query to finish successfully. Do not run it twice unless the first run clearly failed before committing.
4. Retry signup with a fresh test email. If the failed test email already exists in Auth, finish that account or remove only that test account from **Authentication → Users** before retrying.

Optional checks:

```sql
select udt_name
from information_schema.columns
where table_schema = 'private'
  and table_name = 'analytics_events'
  and column_name = 'session_id';

select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.wallet_ledger'::regclass
  and conname = 'wallet_ledger_amount_check';
```

The first query should return `text`; the second should show the existing non-zero ledger check. No frontend secret or `VITE_` environment variable needs to change for this hotfix.

After applying it, retry signup with a fresh test email. Then confirm that a signed-in page view appears in HQ analytics. The `25P02` message should disappear automatically because it was a follow-up error from the failed transaction.
