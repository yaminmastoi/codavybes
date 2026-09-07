-- VYBE V2: secure Aura economy + ranks + Aura Moments + For You eligibility.
-- Prerequisite: 001_auth_onboarding.sql
--
-- Design rules:
--   * Client NEVER writes profiles.aura_total, aura counters, ranks, or FYP flags directly.
--   * Peer Aura is always +1 and is awarded through give_aura().
--   * One giver can Aura a target once.
--   * Pair/day and giver/day limits reduce basic farming.
--   * New accounts have tighter daily limits.
--   * FYP is earned by the CONTENT (Aura + unique givers), not by lifetime user Aura.
--   * Rank thresholds/settings are database-driven for future VYBE HQ control.

begin;

create extension if not exists pgcrypto;

create table if not exists public.aura_config (
  id smallint primary key default 1 check (id = 1),
  peer_aura_amount smallint not null default 1 check (peer_aura_amount = 1),
  daily_giver_limit integer not null default 50 check (daily_giver_limit between 1 and 1000),
  daily_pair_limit integer not null default 10 check (daily_pair_limit between 1 and 100),
  daily_pair_combined_limit integer not null default 15 check (daily_pair_combined_limit between 1 and 200),
  moment_create_hour_limit integer not null default 10 check (moment_create_hour_limit between 1 and 200),
  new_account_moment_hour_limit integer not null default 3 check (new_account_moment_hour_limit between 1 and 100),
  new_account_hours integer not null default 72 check (new_account_hours between 0 and 720),
  new_account_daily_limit integer not null default 10 check (new_account_daily_limit between 1 and 200),
  aura_moment_threshold integer not null default 5 check (aura_moment_threshold between 1 and 10000),
  fyp_min_aura integer not null default 5 check (fyp_min_aura between 1 and 10000),
  fyp_min_unique_givers integer not null default 3 check (fyp_min_unique_givers between 1 and 10000),
  fyp_max_age_hours integer not null default 168 check (fyp_max_age_hours between 1 and 8760),
  weight_velocity numeric(6,3) not null default 0.45 check (weight_velocity >= 0),
  weight_unique_givers numeric(6,3) not null default 0.25 check (weight_unique_givers >= 0),
  weight_total_aura numeric(6,3) not null default 0.15 check (weight_total_aura >= 0),
  weight_freshness numeric(6,3) not null default 0.15 check (weight_freshness >= 0),
  updated_at timestamptz not null default now()
);

insert into public.aura_config (id) values (1)
on conflict (id) do nothing;

drop trigger if exists aura_config_touch_updated_at on public.aura_config;
create trigger aura_config_touch_updated_at
before update on public.aura_config
for each row execute function public.touch_updated_at();

create table if not exists public.aura_ranks (
  id bigint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z0-9_]{2,40}$'),
  name text not null check (char_length(name) between 1 and 40),
  min_aura bigint not null unique check (min_aura >= 1),
  badge text not null default '⚡',
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists aura_ranks_touch_updated_at on public.aura_ranks;
create trigger aura_ranks_touch_updated_at
before update on public.aura_ranks
for each row execute function public.touch_updated_at();

insert into public.aura_ranks (slug, name, min_aura, badge, sort_order) values
  ('new_vibe', 'NEW VIBE', 1, '⚡', 10),
  ('lowkey', 'LOWKEY', 200, '◈', 20),
  ('valid', 'VALID', 500, '✦', 30),
  ('certified', 'CERTIFIED', 1000, '◆', 40),
  ('main_character', 'MAIN CHARACTER', 2500, '♛', 50),
  ('aura_magnet', 'AURA MAGNET', 5000, '✧', 60),
  ('aura_demon', 'AURA DEMON', 10000, '⚡', 70),
  ('untouchable', 'UNTOUCHABLE', 25000, '♜', 80),
  ('lore', 'LORE', 50000, '♛', 90)
on conflict (slug) do update set
  name = excluded.name,
  min_aura = excluded.min_aura,
  badge = excluded.badge,
  sort_order = excluded.sort_order,
  active = true;

-- A generalized Aura-able object. Today this powers public moments/jokes;
-- later message/room/game services can create targets with target_type accordingly.
create table if not exists public.aura_targets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  target_type text not null default 'post'
    check (target_type in ('post','message','room_result','game_result')),
  source_id uuid,
  content_text text not null check (char_length(content_text) between 1 and 1200),
  context_label text not null default 'VYBE' check (char_length(context_label) between 1 and 60),
  aura_count integer not null default 0 check (aura_count >= 0),
  unique_givers integer not null default 0 check (unique_givers >= 0),
  is_aura_moment boolean not null default false,
  fyp_eligible boolean not null default false,
  visibility text not null default 'public' check (visibility in ('public','private')),
  status text not null default 'active' check (status in ('active','hidden','removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists aura_targets_owner_created_idx
  on public.aura_targets (owner_id, created_at desc);
create index if not exists aura_targets_fyp_idx
  on public.aura_targets (fyp_eligible, created_at desc)
  where status = 'active' and visibility = 'public';

drop trigger if exists aura_targets_touch_updated_at on public.aura_targets;
create trigger aura_targets_touch_updated_at
before update on public.aura_targets
for each row execute function public.touch_updated_at();

-- Immutable peer Aura ledger. Admin/system reversals should ADD compensating/reversal
-- records in a future privileged flow rather than deleting history.
create table if not exists public.aura_events (
  id uuid primary key default gen_random_uuid(),
  giver_id uuid references auth.users(id) on delete set null,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid references public.aura_targets(id) on delete set null,
  amount smallint not null check (amount between -100 and 100),
  source text not null default 'peer'
    check (source in ('peer','game','room_mvp','admin_adjustment','reversal')),
  status text not null default 'counted' check (status in ('counted','reversed')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index if not exists aura_events_one_peer_per_target
  on public.aura_events (giver_id, target_id)
  where source = 'peer' and status = 'counted' and giver_id is not null and target_id is not null;

create index if not exists aura_events_giver_created_idx
  on public.aura_events (giver_id, created_at desc)
  where source = 'peer' and status = 'counted';
create index if not exists aura_events_pair_created_idx
  on public.aura_events (giver_id, receiver_id, created_at desc)
  where source = 'peer' and status = 'counted';
create index if not exists aura_events_receiver_created_idx
  on public.aura_events (receiver_id, created_at desc)
  where status = 'counted';

-- Return the active rank containing the supplied Aura amount.
create or replace function public.get_aura_rank(p_aura bigint)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with current_rank as (
    select r.*
    from public.aura_ranks r
    where r.active = true and r.min_aura <= greatest(coalesce(p_aura, 1), 1)
    order by r.min_aura desc
    limit 1
  ), next_rank as (
    select r.*
    from public.aura_ranks r
    where r.active = true
      and r.min_aura > greatest(coalesce(p_aura, 1), 1)
    order by r.min_aura asc
    limit 1
  )
  select jsonb_build_object(
    'slug', c.slug,
    'name', c.name,
    'badge', c.badge,
    'min_aura', c.min_aura,
    'next_slug', n.slug,
    'next_name', n.name,
    'next_badge', n.badge,
    'next_min_aura', n.min_aura,
    'aura_to_next', case when n.min_aura is null then 0 else greatest(n.min_aura - greatest(coalesce(p_aura,1),1), 0) end,
    'progress', case
      when n.min_aura is null then 1
      when n.min_aura = c.min_aura then 1
      else least(1, greatest(0,
        (greatest(coalesce(p_aura,1),1) - c.min_aura)::numeric /
        (n.min_aura - c.min_aura)::numeric
      ))
    end
  )
  from current_rank c
  left join next_rank n on true;
$$;

revoke execute on function public.get_aura_rank(bigint) from public, anon;
grant execute on function public.get_aura_rank(bigint) to authenticated;

-- Optional public moment composer used in this phase to exercise the Aura economy.
-- Chat/Room phases will create target_type message/game_result through server-controlled flows.
create or replace function public.create_vybe_moment(p_text text, p_context_label text default 'VYBE')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_text text := trim(coalesce(p_text, ''));
  v_context text := trim(coalesce(p_context_label, 'VYBE'));
  v_target public.aura_targets%rowtype;
  v_complete boolean;
  v_created_at timestamptz;
  v_cfg public.aura_config%rowtype;
  v_recent_posts integer;
  v_post_limit integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select onboarding_complete, created_at into v_complete, v_created_at
  from public.profiles where user_id = v_user;
  select * into v_cfg from public.aura_config where id = 1;

  if coalesce(v_complete, false) is false then
    raise exception 'Finish onboarding first.';
  end if;
  if char_length(v_text) < 1 or char_length(v_text) > 1200 then
    raise exception 'Moment must be 1–1200 characters.';
  end if;
  if char_length(v_context) < 1 or char_length(v_context) > 60 then
    raise exception 'Context must be 1–60 characters.';
  end if;

  select count(*) into v_recent_posts
  from public.aura_targets t
  where t.owner_id = v_user
    and t.target_type = 'post'
    and t.created_at >= now() - interval '1 hour';

  v_post_limit := case
    when v_created_at > now() - make_interval(hours => v_cfg.new_account_hours)
      then least(v_cfg.moment_create_hour_limit, v_cfg.new_account_moment_hour_limit)
    else v_cfg.moment_create_hour_limit
  end;

  if v_recent_posts >= v_post_limit then
    raise exception 'You are posting too fast. Try again later.';
  end if;

  insert into public.aura_targets (owner_id, target_type, content_text, context_label)
  values (v_user, 'post', v_text, v_context)
  returning * into v_target;

  return jsonb_build_object(
    'id', v_target.id,
    'text', v_target.content_text,
    'context_label', v_target.context_label,
    'aura_count', 0,
    'unique_givers', 0,
    'is_aura_moment', false,
    'fyp_eligible', false,
    'created_at', v_target.created_at
  );
end;
$$;

revoke execute on function public.create_vybe_moment(text,text) from public, anon;
grant execute on function public.create_vybe_moment(text,text) to authenticated;

-- Secure peer Aura award. This is the ONLY authenticated path that increases peer Aura.
create or replace function public.give_aura(p_target_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_giver uuid := auth.uid();
  v_target public.aura_targets%rowtype;
  v_receiver_total bigint;
  v_receiver_before bigint;
  v_giver_created_at timestamptz;
  v_giver_complete boolean;
  v_receiver_complete boolean;
  v_cfg public.aura_config%rowtype;
  v_today timestamptz := date_trunc('day', now());
  v_giver_today integer;
  v_pair_today integer;
  v_pair_combined_today integer;
  v_limit integer;
  v_rank jsonb;
  v_became_moment boolean := false;
  v_became_fyp boolean := false;
begin
  if v_giver is null then raise exception 'Authentication required'; end if;

  select * into v_cfg from public.aura_config where id = 1;

  select p.created_at, p.onboarding_complete
    into v_giver_created_at, v_giver_complete
  from public.profiles p
  where p.user_id = v_giver;

  if coalesce(v_giver_complete, false) is false then
    raise exception 'Finish onboarding first.';
  end if;

  select * into v_target
  from public.aura_targets
  where id = p_target_id
  for update;

  if not found or v_target.status <> 'active' or v_target.visibility <> 'public' then
    raise exception 'This Aura target is unavailable.';
  end if;

  if v_target.owner_id = v_giver then
    raise exception 'You cannot give Aura to yourself.';
  end if;

  select onboarding_complete, aura_total into v_receiver_complete, v_receiver_before
  from public.profiles
  where user_id = v_target.owner_id
  for update;

  if coalesce(v_receiver_complete, false) is false then
    raise exception 'This user is unavailable.';
  end if;

  if exists (
    select 1 from public.aura_events e
    where e.giver_id = v_giver
      and e.target_id = p_target_id
      and e.source = 'peer'
      and e.status = 'counted'
  ) then
    select aura_total into v_receiver_total
    from public.profiles where user_id = v_target.owner_id;

    return jsonb_build_object(
      'ok', true,
      'already_given', true,
      'target_id', p_target_id,
      'target_aura', v_target.aura_count,
      'receiver_aura', v_receiver_total,
      'rank', public.get_aura_rank(v_receiver_total),
      'fyp_eligible', v_target.fyp_eligible,
      'is_aura_moment', v_target.is_aura_moment
    );
  end if;

  select count(*) into v_giver_today
  from public.aura_events e
  where e.giver_id = v_giver
    and e.source = 'peer'
    and e.status = 'counted'
    and e.created_at >= v_today;

  v_limit := case
    when v_giver_created_at > now() - make_interval(hours => v_cfg.new_account_hours)
      then least(v_cfg.daily_giver_limit, v_cfg.new_account_daily_limit)
    else v_cfg.daily_giver_limit
  end;

  if v_giver_today >= v_limit then
    raise exception 'You reached today''s Aura-giving limit. Come back tomorrow.';
  end if;

  select count(*) into v_pair_today
  from public.aura_events e
  where e.giver_id = v_giver
    and e.receiver_id = v_target.owner_id
    and e.source = 'peer'
    and e.status = 'counted'
    and e.created_at >= v_today;

  if v_pair_today >= v_cfg.daily_pair_limit then
    raise exception 'You have given this person enough Aura for today.';
  end if;

  select count(*) into v_pair_combined_today
  from public.aura_events e
  where e.source = 'peer'
    and e.status = 'counted'
    and e.created_at >= v_today
    and (
      (e.giver_id = v_giver and e.receiver_id = v_target.owner_id)
      or (e.giver_id = v_target.owner_id and e.receiver_id = v_giver)
    );

  if v_pair_combined_today >= v_cfg.daily_pair_combined_limit then
    raise exception 'This Aura pair has reached today''s safety limit.';
  end if;

  -- Insert first; the partial unique index closes concurrent double-tap races.
  begin
    insert into public.aura_events (giver_id, receiver_id, target_id, amount, source)
    values (v_giver, v_target.owner_id, p_target_id, v_cfg.peer_aura_amount, 'peer');
  exception
    when unique_violation then
      select aura_total into v_receiver_total
      from public.profiles where user_id = v_target.owner_id;
      return jsonb_build_object(
        'ok', true,
        'already_given', true,
        'target_id', p_target_id,
        'target_aura', v_target.aura_count,
        'receiver_aura', v_receiver_total,
        'rank', public.get_aura_rank(v_receiver_total),
        'fyp_eligible', v_target.fyp_eligible,
        'is_aura_moment', v_target.is_aura_moment
      );
  end;

  v_became_moment := (not v_target.is_aura_moment)
    and (v_target.aura_count + v_cfg.peer_aura_amount >= v_cfg.aura_moment_threshold);

  v_became_fyp := (not v_target.fyp_eligible)
    and (v_target.aura_count + v_cfg.peer_aura_amount >= v_cfg.fyp_min_aura)
    and (v_target.unique_givers + 1 >= v_cfg.fyp_min_unique_givers);

  update public.aura_targets
  set aura_count = aura_count + v_cfg.peer_aura_amount,
      unique_givers = unique_givers + 1,
      is_aura_moment = is_aura_moment or v_became_moment,
      fyp_eligible = fyp_eligible or v_became_fyp
  where id = p_target_id
  returning * into v_target;

  update public.profiles
  set aura_total = aura_total + v_cfg.peer_aura_amount
  where user_id = v_target.owner_id
  returning aura_total into v_receiver_total;

  v_rank := public.get_aura_rank(v_receiver_total);

  return jsonb_build_object(
    'ok', true,
    'already_given', false,
    'amount', v_cfg.peer_aura_amount,
    'target_id', p_target_id,
    'target_aura', v_target.aura_count,
    'unique_givers', v_target.unique_givers,
    'receiver_aura', v_receiver_total,
    'old_rank', public.get_aura_rank(v_receiver_before),
    'rank', v_rank,
    'rank_up', coalesce(public.get_aura_rank(v_receiver_before)->>'slug','') <> coalesce(v_rank->>'slug',''),
    'became_aura_moment', v_became_moment,
    'became_fyp', v_became_fyp,
    'fyp_eligible', v_target.fyp_eligible,
    'is_aura_moment', v_target.is_aura_moment
  );
end;
$$;

revoke execute on function public.give_aura(uuid) from public, anon;
grant execute on function public.give_aura(uuid) to authenticated;

-- The actual For You feed: only content that earned the configured threshold is returned.
create or replace function public.get_for_you_feed(p_limit integer default 20, p_offset integer default 0)
returns table (
  target_id uuid,
  author_id uuid,
  display_name text,
  username text,
  author_aura bigint,
  author_rank jsonb,
  content_text text,
  context_label text,
  aura_count integer,
  unique_givers integer,
  is_aura_moment boolean,
  created_at timestamptz,
  viewer_has_aura boolean,
  fyp_score numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_cfg public.aura_config%rowtype;
  v_limit integer := least(greatest(coalesce(p_limit,20),1),50);
  v_offset integer := greatest(coalesce(p_offset,0),0);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_cfg from public.aura_config where id = 1;

  return query
  with scored as (
    select
      t.id,
      t.owner_id,
      p.display_name,
      p.username,
      p.aura_total,
      public.get_aura_rank(p.aura_total) as rank_json,
      t.content_text,
      t.context_label,
      t.aura_count,
      t.unique_givers,
      t.is_aura_moment,
      t.created_at,
      exists (
        select 1 from public.aura_events e
        where e.giver_id = v_user
          and e.target_id = t.id
          and e.source = 'peer'
          and e.status = 'counted'
      ) as has_aura,
      (
        (t.aura_count::numeric / greatest(extract(epoch from (now() - t.created_at))/3600.0, 0.25)) * v_cfg.weight_velocity
        + t.unique_givers::numeric * v_cfg.weight_unique_givers
        + t.aura_count::numeric * v_cfg.weight_total_aura
        + greatest(0::numeric, 1 - (extract(epoch from (now() - t.created_at))/3600.0) / v_cfg.fyp_max_age_hours::numeric) * 10 * v_cfg.weight_freshness
      ) as score
    from public.aura_targets t
    join public.profiles p on p.user_id = t.owner_id
    where t.status = 'active'
      and t.visibility = 'public'
      and t.fyp_eligible = true
      and t.created_at >= now() - make_interval(hours => v_cfg.fyp_max_age_hours)
      and p.onboarding_complete = true
  )
  select
    s.id, s.owner_id, s.display_name, s.username, s.aura_total, s.rank_json,
    s.content_text, s.context_label, s.aura_count, s.unique_givers,
    s.is_aura_moment, s.created_at, s.has_aura, s.score
  from scored s
  order by s.score desc, s.created_at desc
  limit v_limit offset v_offset;
end;
$$;

revoke execute on function public.get_for_you_feed(integer,integer) from public, anon;
grant execute on function public.get_for_you_feed(integer,integer) to authenticated;

create or replace function public.get_rising_feed(p_limit integer default 20, p_offset integer default 0)
returns table (
  target_id uuid,
  author_id uuid,
  display_name text,
  username text,
  author_aura bigint,
  author_rank jsonb,
  content_text text,
  context_label text,
  aura_count integer,
  unique_givers integer,
  is_aura_moment boolean,
  created_at timestamptz,
  viewer_has_aura boolean,
  rising_score numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit,20),1),50);
  v_offset integer := greatest(coalesce(p_offset,0),0);
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  return query
  select
    t.id, t.owner_id, p.display_name, p.username, p.aura_total, public.get_aura_rank(p.aura_total),
    t.content_text, t.context_label, t.aura_count, t.unique_givers, t.is_aura_moment, t.created_at,
    exists (
      select 1 from public.aura_events e
      where e.giver_id = v_user and e.target_id = t.id and e.source = 'peer' and e.status = 'counted'
    ),
    (
      t.aura_count::numeric * 2
      + t.unique_givers::numeric * 3
      + greatest(0::numeric, 24 - extract(epoch from (now() - t.created_at))/3600.0) / 24
    ) as score
  from public.aura_targets t
  join public.profiles p on p.user_id = t.owner_id
  where t.status = 'active'
    and t.visibility = 'public'
    and t.created_at >= now() - interval '24 hours'
    and p.onboarding_complete = true
  order by score desc, t.created_at desc
  limit v_limit offset v_offset;
end;
$$;

revoke execute on function public.get_rising_feed(integer,integer) from public, anon;
grant execute on function public.get_rising_feed(integer,integer) to authenticated;

create or replace function public.get_my_aura_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_total bigint;
  v_rank jsonb;
  v_today_received bigint;
  v_week_received bigint;
  v_today_given integer;
  v_cfg public.aura_config%rowtype;
  v_created_at timestamptz;
  v_limit integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select aura_total, created_at into v_total, v_created_at
  from public.profiles where user_id = v_user;
  if v_total is null then raise exception 'Profile unavailable.'; end if;

  select * into v_cfg from public.aura_config where id = 1;
  v_rank := public.get_aura_rank(v_total);

  select coalesce(sum(e.amount),0) into v_today_received
  from public.aura_events e
  where e.receiver_id = v_user and e.status = 'counted'
    and e.created_at >= date_trunc('day', now());

  select coalesce(sum(e.amount),0) into v_week_received
  from public.aura_events e
  where e.receiver_id = v_user and e.status = 'counted'
    and e.created_at >= now() - interval '7 days';

  select count(*) into v_today_given
  from public.aura_events e
  where e.giver_id = v_user and e.source = 'peer' and e.status = 'counted'
    and e.created_at >= date_trunc('day', now());

  v_limit := case
    when v_created_at > now() - make_interval(hours => v_cfg.new_account_hours)
      then least(v_cfg.daily_giver_limit, v_cfg.new_account_daily_limit)
    else v_cfg.daily_giver_limit
  end;

  return jsonb_build_object(
    'aura_total', v_total,
    'rank', v_rank,
    'received_today', v_today_received,
    'received_7d', v_week_received,
    'given_today', v_today_given,
    'giving_limit_today', v_limit,
    'giving_remaining_today', greatest(v_limit - v_today_given, 0),
    'moment_threshold', v_cfg.aura_moment_threshold,
    'fyp_min_aura', v_cfg.fyp_min_aura,
    'fyp_min_unique_givers', v_cfg.fyp_min_unique_givers
  );
end;
$$;

revoke execute on function public.get_my_aura_dashboard() from public, anon;
grant execute on function public.get_my_aura_dashboard() to authenticated;

create or replace function public.get_my_aura_ledger(p_limit integer default 30)
returns table (
  event_id uuid,
  amount smallint,
  source text,
  created_at timestamptz,
  giver_username text,
  giver_display_name text,
  target_text text,
  metadata jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.amount, e.source, e.created_at,
         giver.username, giver.display_name,
         t.content_text,
         e.metadata
  from public.aura_events e
  left join public.profiles giver on giver.user_id=e.giver_id
  left join public.aura_targets t on t.id=e.target_id
  where e.receiver_id=auth.uid() and e.status='counted'
  order by e.created_at desc
  limit least(greatest(coalesce(p_limit,30),1),100);
$$;

revoke execute on function public.get_my_aura_ledger(integer) from public, anon;
grant execute on function public.get_my_aura_ledger(integer) to authenticated;

create or replace function public.get_my_moments(p_limit integer default 20)
returns table (
  target_id uuid,
  content_text text,
  context_label text,
  aura_count integer,
  unique_givers integer,
  is_aura_moment boolean,
  fyp_eligible boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.content_text, t.context_label, t.aura_count, t.unique_givers,
         t.is_aura_moment, t.fyp_eligible, t.created_at
  from public.aura_targets t
  where t.owner_id = auth.uid() and t.status = 'active'
  order by t.created_at desc
  limit least(greatest(coalesce(p_limit,20),1),50);
$$;

revoke execute on function public.get_my_moments(integer) from public, anon;
grant execute on function public.get_my_moments(integer) to authenticated;

-- Aura Board: lifetime shows lifetime reputation; day/week show earned Aura within that window.
create or replace function public.get_aura_board(p_window text default 'week', p_limit integer default 20)
returns table (
  user_id uuid,
  display_name text,
  username text,
  lifetime_aura bigint,
  window_aura bigint,
  rank jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_window text := lower(coalesce(p_window,'week'));
  v_since timestamptz;
  v_limit integer := least(greatest(coalesce(p_limit,20),1),50);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if v_window not in ('day','week','lifetime') then raise exception 'Use day, week, or lifetime.'; end if;

  v_since := case
    when v_window = 'day' then date_trunc('day', now())
    when v_window = 'week' then now() - interval '7 days'
    else null
  end;

  return query
  select
    p.user_id,
    p.display_name,
    p.username,
    p.aura_total,
    case
      when v_window = 'lifetime' then greatest(p.aura_total - 1, 0)
      else coalesce(sum(e.amount) filter (where e.created_at >= v_since and e.status = 'counted'), 0)
    end::bigint as period_aura,
    public.get_aura_rank(p.aura_total)
  from public.profiles p
  left join public.aura_events e on e.receiver_id = p.user_id
  where p.onboarding_complete = true
  group by p.user_id, p.display_name, p.username, p.aura_total
  order by period_aura desc, p.aura_total desc
  limit v_limit;
end;
$$;

revoke execute on function public.get_aura_board(text,integer) from public, anon;
grant execute on function public.get_aura_board(text,integer) to authenticated;

-- A stable server reference makes verified game/MVP rewards idempotent.
create unique index if not exists aura_events_verified_source_unique
  on public.aura_events (receiver_id, source, ((metadata->>'source_id')))
  where source in ('game','room_mvp')
    and status = 'counted'
    and metadata ? 'source_id';

-- TRUSTED SERVER ONLY: award Aura after a server-authoritative game result.
-- Never expose the service-role key in the browser.
create or replace function public.award_verified_aura(
  p_receiver uuid,
  p_source text,
  p_source_id uuid,
  p_amount smallint,
  p_label text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before bigint;
  v_after bigint;
  v_old_rank jsonb;
  v_new_rank jsonb;
begin
  if p_source not in ('game','room_mvp') then
    raise exception 'Verified Aura source must be game or room_mvp.';
  end if;
  if p_source_id is null then raise exception 'Verified source id is required.'; end if;
  if p_amount < 1 or p_amount > 100 then raise exception 'Verified Aura must be 1–100.'; end if;

  select aura_total into v_before
  from public.profiles
  where user_id = p_receiver and onboarding_complete = true
  for update;

  if v_before is null then raise exception 'Receiver profile unavailable.'; end if;
  v_old_rank := public.get_aura_rank(v_before);

  begin
    insert into public.aura_events (giver_id,receiver_id,target_id,amount,source,status,metadata)
    values (
      null,p_receiver,null,p_amount,p_source,'counted',
      jsonb_build_object('source_id',p_source_id::text,'verified',true,'label',left(coalesce(p_label,''),120))
    );
  exception when unique_violation then
    return jsonb_build_object(
      'ok',true,'already_awarded',true,'receiver_aura',v_before,
      'rank',v_old_rank
    );
  end;

  update public.profiles
  set aura_total = aura_total + p_amount
  where user_id = p_receiver
  returning aura_total into v_after;

  v_new_rank := public.get_aura_rank(v_after);

  return jsonb_build_object(
    'ok',true,
    'already_awarded',false,
    'verified',true,
    'amount',p_amount,
    'receiver_aura',v_after,
    'old_rank',v_old_rank,
    'rank',v_new_rank,
    'rank_up',coalesce(v_old_rank->>'slug','') <> coalesce(v_new_rank->>'slug','')
  );
end;
$$;

revoke execute on function public.award_verified_aura(uuid,text,uuid,smallint,text) from public, anon, authenticated;
grant execute on function public.award_verified_aura(uuid,text,uuid,smallint,text) to service_role;

-- TRUSTED SERVER ONLY: future VYBE HQ moderation/admin correction.
-- This appends an audit event instead of secretly editing history.
create or replace function public.admin_adjust_aura(
  p_receiver uuid,
  p_amount smallint,
  p_reason text,
  p_reference uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before bigint;
  v_after bigint;
  v_effective smallint := p_amount;
begin
  if p_amount = 0 or p_amount < -100 or p_amount > 100 then
    raise exception 'Adjustment must be between -100 and 100, excluding zero.';
  end if;
  if char_length(trim(coalesce(p_reason,''))) < 3 then raise exception 'Admin reason required.'; end if;

  select aura_total into v_before from public.profiles where user_id=p_receiver for update;
  if v_before is null then raise exception 'Profile unavailable.'; end if;

  if v_before + v_effective < 1 then
    v_effective := (1-v_before)::smallint;
  end if;
  if v_effective = 0 then
    return jsonb_build_object('ok',true,'amount',0,'receiver_aura',v_before);
  end if;

  insert into public.aura_events(giver_id,receiver_id,target_id,amount,source,status,metadata)
  values(null,p_receiver,null,v_effective,case when v_effective < 0 then 'reversal' else 'admin_adjustment' end,'counted',
    jsonb_build_object('reference',p_reference::text,'reason',left(trim(p_reason),240),'admin_audit',true));

  update public.profiles set aura_total=greatest(1,aura_total+v_effective)
  where user_id=p_receiver returning aura_total into v_after;

  return jsonb_build_object('ok',true,'amount',v_effective,'receiver_aura',v_after,'rank',public.get_aura_rank(v_after));
end;
$$;

revoke execute on function public.admin_adjust_aura(uuid,smallint,text,uuid) from public, anon, authenticated;
grant execute on function public.admin_adjust_aura(uuid,smallint,text,uuid) to service_role;

-- RLS + direct grants. Read surfaces are constrained; all mutations are RPC-only.
alter table public.aura_config enable row level security;
alter table public.aura_ranks enable row level security;
alter table public.aura_targets enable row level security;
alter table public.aura_events enable row level security;

revoke all on table public.aura_config from anon, authenticated;
revoke all on table public.aura_ranks from anon, authenticated;
revoke all on table public.aura_targets from anon, authenticated;
revoke all on table public.aura_events from anon, authenticated;

grant select on table public.aura_config to authenticated;
grant select on table public.aura_ranks to authenticated;
grant select on table public.aura_targets to authenticated;

drop policy if exists "authenticated can read aura config" on public.aura_config;
drop policy if exists "authenticated can read aura ranks" on public.aura_ranks;
drop policy if exists "authenticated can read public aura targets or own targets" on public.aura_targets;

create policy "authenticated can read aura config"
on public.aura_config for select to authenticated using (true);

create policy "authenticated can read aura ranks"
on public.aura_ranks for select to authenticated using (active = true);

create policy "authenticated can read public aura targets or own targets"
on public.aura_targets for select to authenticated
using (
  (status = 'active' and visibility = 'public')
  or owner_id = (select auth.uid())
);

-- No direct authenticated SELECT on aura_events: personal/event aggregates are exposed by RPCs.
-- No INSERT/UPDATE/DELETE grants on Aura economy tables.

commit;
