-- CodaVybes global leaderboard. DOB / age is intentionally not part of
-- ranking or access. Blocked/inactive accounts are excluded.
begin;

drop function if exists public.get_platform_leaderboard(integer);

create function public.get_platform_leaderboard(p_limit integer default 10)
returns table(
  "position" integer,
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  aura_total bigint,
  is_verified boolean,
  "rank" jsonb
)
language sql
stable
security definer
set search_path = public, private, pg_temp
as $$
  with ranked_users as (
    select
      p.user_id,
      p.username,
      p.display_name,
      p.avatar_url,
      p.aura_total::bigint as aura_total,
      coalesce(p.is_verified,false) as is_verified,
      row_number() over(
        order by p.aura_total desc, p.created_at asc, p.user_id asc
      )::integer as leaderboard_position
    from public.profiles p
    left join private.user_account_controls c on c.user_id = p.user_id
    where p.onboarding_complete = true
      and p.username is not null
      and coalesce(c.status,'active') = 'active'
      and not public.users_are_blocked(auth.uid(),p.user_id)
  )
  select
    r.leaderboard_position as "position",
    r.user_id,
    r.username,
    r.display_name,
    r.avatar_url,
    r.aura_total,
    r.is_verified,
    public.get_aura_rank(r.aura_total) as "rank"
  from ranked_users r
  where r.leaderboard_position <= least(greatest(coalesce(p_limit,10),1),100)
  order by r.leaderboard_position;
$$;

revoke all on function public.get_platform_leaderboard(integer) from public, anon;
grant execute on function public.get_platform_leaderboard(integer) to authenticated;

commit;
