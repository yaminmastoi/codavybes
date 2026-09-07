-- CodaVybes V13.3 — safe public CodaVybes+ presence for visible social identities.
-- Returns only a boolean badge state and never exposes subscription dates, source or payment details.
begin;

create or replace function public.get_plus_statuses(p_user_ids uuid[])
returns table(user_id uuid,is_plus boolean)
language sql
stable
security definer
set search_path=''
as $$
  with requested as (
    select distinct x as user_id
    from unnest(coalesce(p_user_ids,'{}'::uuid[])) x
    where x is not null
    limit 100
  )
  select p.user_id,
    exists(
      select 1
      from public.user_subscriptions s
      where s.user_id=p.user_id
        and s.plan='vybe_plus'
        and s.status='active'
        and s.ends_at>now()
    ) as is_plus
  from requested r
  join public.profiles p on p.user_id=r.user_id
  where auth.uid() is not null
    and private.account_is_active(auth.uid())
    and private.account_is_active(p.user_id)
    and p.onboarding_complete=true
    and (
      p.user_id=auth.uid()
      or private.age_compatible(auth.uid(),p.user_id)
      or private.connection_id_for(auth.uid(),p.user_id) is not null
    );
$$;

revoke execute on function public.get_plus_statuses(uuid[]) from public,anon;
grant execute on function public.get_plus_statuses(uuid[]) to authenticated;

commit;
