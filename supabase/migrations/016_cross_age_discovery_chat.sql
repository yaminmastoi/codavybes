-- CodaVybes V13.4 — cross-age discovery and conversation compatibility.
-- Run once AFTER migration 015 on an existing database.
--
-- Product rule:
--   * The existing minimum account age (10+) remains unchanged.
--   * Every eligible, active account may discover/connect across age groups.
--   * Existing symmetric block checks and account restrictions remain mandatory.
--   * Meet still requires both users to choose Keep before a permanent DM unlocks.

begin;

-- Keep the established helper signature because RLS policies, chat/Meet RPCs,
-- message triggers, profile visibility and social surfaces already call it.
-- Compatibility now means "both accounts are eligible and active", not
-- "both accounts have the same age-band slug".
create or replace function private.age_compatible(p_a uuid,p_b uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select p_a is not null
    and p_b is not null
    and private.account_is_active(p_a)
    and private.account_is_active(p_b)
    and exists(
      select 1
      from private.user_private up
      where up.user_id=p_a and up.eligibility_status='eligible'
    )
    and exists(
      select 1
      from private.user_private up
      where up.user_id=p_b and up.eligibility_status='eligible'
    );
$$;

revoke execute on function private.age_compatible(uuid,uuid) from public,anon,authenticated;

-- The browser-safe wrapper remains boolean-only and automatically adopts the
-- new compatibility rule for profile/Aura RLS policies.
create or replace function public.current_user_age_compatible(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select auth.uid() is not null
    and p_other is not null
    and private.age_compatible(auth.uid(),p_other);
$$;

revoke execute on function public.current_user_age_compatible(uuid) from public,anon;
grant execute on function public.current_user_age_compatible(uuid) to authenticated;

-- Remove the old explicit "viewer must have an active age band" guard from
-- Discover. Age/DOB is still private; minors retain broad display labels.
create or replace function public.get_discover_people(p_limit integer default 24,p_mode text default 'for_you')
returns table(
  user_id uuid,username text,display_name text,avatar_url text,aura_total bigint,rank jsonb,
  age_display text,age_band text,shared_interests jsonb,shared_count integer,match_score integer,is_online_hint boolean
)
language plpgsql
volatile
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_limit integer:=least(greatest(coalesce(p_limit,24),1),50);
  v_my_band text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.account_is_active(v_user) then raise exception 'Account restricted'; end if;
  if not exists(
    select 1 from private.user_private up
    where up.user_id=v_user and up.eligibility_status='eligible'
  ) then raise exception 'Age eligibility is not complete.'; end if;

  v_my_band:=coalesce(private.user_age_band(v_user),'eligible');

  return query
  with mine as (
    select ui.interest_id from public.user_interests ui where ui.user_id=v_user
  ), candidates as (
    select p.user_id,p.username,p.display_name,p.avatar_url,p.aura_total,
      private.user_age(p.user_id) as age,
      coalesce((
        select count(*)
        from public.user_interests x
        join mine m on m.interest_id=x.interest_id
        where x.user_id=p.user_id
      ),0)::integer shared
    from public.profiles p
    where p.onboarding_complete=true
      and p.user_id<>v_user
      and private.age_compatible(v_user,p.user_id)
      and not public.users_are_blocked(v_user,p.user_id)
      and not exists(
        select 1 from public.connections c
        where c.status='active'
          and c.user_low=least(v_user,p.user_id)
          and c.user_high=greatest(v_user,p.user_id)
      )
      and not exists(
        select 1 from public.meet_requests mr
        where mr.status='pending'
          and ((mr.sender_id=v_user and mr.receiver_id=p.user_id)
            or (mr.sender_id=p.user_id and mr.receiver_id=v_user))
      )
  )
  select c.user_id,c.username,c.display_name,c.avatar_url,c.aura_total,
    public.get_aura_rank(c.aura_total),
    case
      when c.age>=18 then c.age::text
      when c.age between 10 and 12 then '10–12'
      else 'Teen'
    end,
    v_my_band,
    coalesce((
      select jsonb_agg(i.slug order by i.sort_order)
      from public.user_interests ui
      join public.interests i on i.id=ui.interest_id
      join mine m on m.interest_id=ui.interest_id
      where ui.user_id=c.user_id
    ),'[]'::jsonb),
    c.shared,
    least(98,greatest(45,50+c.shared*9+case when c.aura_total>=200 then 3 else 0 end))::integer,
    false
  from candidates c
  order by
    case when p_mode='new' then (
      select created_at from public.profiles p2 where p2.user_id=c.user_id
    ) end desc nulls last,
    c.shared desc,
    case when p_mode='rising' then c.aura_total else 0 end desc,
    random()
  limit v_limit;
end;
$$;

revoke execute on function public.get_discover_people(integer,text) from public,anon;
grant execute on function public.get_discover_people(integer,text) to authenticated;

commit;
