-- CodaVybes V13.16 — signup wallet + analytics session compatibility hotfix.
-- Apply once after 020_codavybes_analytics_restore.sql.
-- This migration is forward-only: it preserves existing users and analytics rows.

begin;

-- Older analytics deployments used uuid for session_id, while the browser session
-- identifier is an opaque text value. Convert only the existing analytics event
-- column when it is present and still has a non-text type.
do $$
declare
  v_udt text;
begin
  if to_regclass('private.analytics_events') is not null then
    select c.udt_name
      into v_udt
      from information_schema.columns c
     where c.table_schema = 'private'
       and c.table_name = 'analytics_events'
       and c.column_name = 'session_id';

    if v_udt is not null and v_udt <> 'text' then
      execute 'alter table private.analytics_events alter column session_id type text using session_id::text';
    end if;
  end if;
end;
$$;

do $$
begin
  if to_regclass('private.analytics_events') is not null then
    execute 'create index if not exists analytics_events_session_created_idx on private.analytics_events(session_id, created_at desc)';
  end if;
end;
$$;

-- A zero welcome balance is valid, but a zero ledger movement is not. Do not
-- create a ledger row when monetization_config.welcome_coins is set to zero.
create or replace function private.ensure_vybe_wallet(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_welcome integer := 100;
  v_rows integer := 0;
begin
  select coalesce((select m.welcome_coins from public.monetization_config m where m.id = 1), 100)
    into v_welcome;

  insert into public.vybe_wallets(user_id, coin_balance)
  values (p_user, greatest(v_welcome, 0))
  on conflict (user_id) do nothing;

  get diagnostics v_rows = row_count;

  if v_rows > 0 and v_welcome <> 0 then
    insert into public.wallet_ledger(user_id, amount, entry_type, note)
    values (p_user, v_welcome, 'welcome', 'Welcome to CodaVybes');
  end if;

  insert into public.user_preferences(user_id)
  values (p_user)
  on conflict (user_id) do nothing;
end;
$$;

commit;
