-- VYBE V8.1 hotfix
-- Fixes: permission denied for function user_age_band / age_compatible /
-- account_is_active when RLS policies were evaluated by authenticated users.
--
-- Private helper functions stay private. RLS uses narrowly-scoped public
-- SECURITY DEFINER wrappers instead of granting browser roles access to the
-- private schema.

begin;

create or replace function public.current_account_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and private.account_is_active(auth.uid());
$$;
revoke execute on function public.current_account_is_active() from public,anon;
grant execute on function public.current_account_is_active() to authenticated;

create or replace function public.current_user_age_band()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when auth.uid() is null then null else private.user_age_band(auth.uid()) end;
$$;
revoke execute on function public.current_user_age_band() from public,anon;
grant execute on function public.current_user_age_band() to authenticated;

create or replace function public.current_user_age_compatible(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
     and p_other is not null
     and private.age_compatible(auth.uid(),p_other);
$$;
revoke execute on function public.current_user_age_compatible(uuid) from public,anon;
grant execute on function public.current_user_age_compatible(uuid) to authenticated;

-- Repair age-safe profile/Aura RLS.
drop policy if exists "authenticated can read completed profiles or own profile" on public.profiles;
create policy "authenticated can read completed profiles or own profile"
on public.profiles for select to authenticated
using (
  auth.uid() = user_id
  or (onboarding_complete = true and public.current_user_age_compatible(user_id))
);

drop policy if exists "authenticated can read public aura targets or own targets" on public.aura_targets;
create policy "authenticated can read public aura targets or own targets"
on public.aura_targets for select to authenticated
using (
  owner_id = auth.uid()
  or (status='active' and visibility='public' and public.current_user_age_compatible(owner_id))
);

-- Repair HQ's restrictive account-state policies without exposing the private helper.
do $$
declare r record;
begin
  for r in select * from (values
    ('profiles'),('user_interests'),('aura_targets'),('conversations'),('conversation_members'),('messages'),('message_reactions'),
    ('user_blocks'),('rooms'),('room_members'),('game_sessions'),('game_rounds'),('game_results'),('room_events'),
    ('connections'),('bonds'),('meet_requests'),('meet_sessions'),('meet_messages'),('meet_decisions')
  ) v(tbl)
  loop
    if to_regclass(format('public.%I',r.tbl)) is not null then
      execute format('drop policy if exists "active account required" on public.%I',r.tbl);
      execute format('create policy "active account required" on public.%I as restrictive for all to authenticated using(public.current_account_is_active()) with check(public.current_account_is_active())',r.tbl);
    end if;
  end loop;
end $$;

-- Repair V8 moment visibility policies.
do $$ begin
  if to_regclass('public.moment_reactions') is not null then
    drop policy if exists "read reactions on visible moments" on public.moment_reactions;
    create policy "read reactions on visible moments" on public.moment_reactions
    for select to authenticated using(
      exists(
        select 1 from public.aura_targets t
        where t.id=target_id
          and t.status='active'
          and t.visibility='public'
          and public.current_user_age_compatible(t.owner_id)
          and not public.users_are_blocked(auth.uid(),t.owner_id)
      )
    );
  end if;

  if to_regclass('public.moment_comments') is not null then
    drop policy if exists "read comments on visible moments" on public.moment_comments;
    create policy "read comments on visible moments" on public.moment_comments
    for select to authenticated using(
      exists(
        select 1 from public.aura_targets t
        where t.id=target_id
          and t.status='active'
          and t.visibility='public'
          and public.current_user_age_compatible(t.owner_id)
          and not public.users_are_blocked(auth.uid(),t.owner_id)
      )
    );
  end if;
end $$;

-- Repair announcement audience policy (the reported user_age_band failure).
do $$ begin
  if to_regclass('public.announcements') is not null then
    drop policy if exists "read live announcements" on public.announcements;
    create policy "read live announcements" on public.announcements
    for select to authenticated using(
      active=true
      and starts_at<=now()
      and (ends_at is null or ends_at>now())
      and (audience='all' or audience=public.current_user_age_band())
    );
  end if;
end $$;

commit;
