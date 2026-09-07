-- VYBE V6: all-generation 10+ eligibility + age-safe discovery + Meet sessions + Bonds.
-- Prerequisites: 001_auth_onboarding.sql .. 004_rooms_games.sql
--
-- Product rule:
--   * Anyone age 10+ may create/use an account.
--   * Stranger discovery remains separated into safety pools: 10-12, 13-17, 18+.
--   * Exact DOB stays private. Exact age is only returned for adults; minors expose a broad age group.
--   * Meet sessions are temporary (default 10 minutes). Both users must choose KEEP to become connections.
--   * Bonds are earned from real interactions and are ledger-backed.

begin;

-- ---------------------------------------------------------------------------
-- AGE GATE: remove Gen-Z window, allow 10+.
-- ---------------------------------------------------------------------------
alter table public.app_config drop constraint if exists app_config_min_age_check;
alter table public.app_config add constraint app_config_min_age_check check (min_age between 10 and 99);
update public.app_config
set min_age = 10,
    generation_start_date = date '1900-01-01',
    generation_end_date = date '2100-12-31',
    updated_at = now()
where id = 1;

-- Re-evaluate existing accounts when upgrading from the former Gen-Z/18+ gate.
update private.user_private
set eligibility_status = case
      when birth_date is null then 'pending'
      when extract(year from age(current_date,birth_date))::integer >= 10 then 'eligible'
      else 'ineligible'
    end,
    eligibility_checked_at = case when birth_date is null then eligibility_checked_at else now() end,
    updated_at = now();

create or replace function public.set_birth_date(p_birth_date date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_existing date;
  v_min_age integer;
  v_age integer;
  v_eligible boolean;
  v_band text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_birth_date is null or p_birth_date > current_date then raise exception 'Enter a valid birth date.'; end if;
  if p_birth_date < current_date - interval '120 years' then raise exception 'Enter a valid birth date.'; end if;

  insert into private.user_private (user_id) values (v_user)
  on conflict (user_id) do nothing;

  select birth_date into v_existing
  from private.user_private
  where user_id = v_user
  for update;

  if v_existing is not null then
    raise exception 'Birthday is already locked. Contact support for a correction.';
  end if;

  select min_age into v_min_age from public.app_config where id = 1;
  v_age := extract(year from age(current_date, p_birth_date));
  v_eligible := v_age >= v_min_age;
  v_band := case
    when v_age between 10 and 12 then '10_12'
    when v_age between 13 and 17 then '13_17'
    when v_age >= 18 then '18_plus'
    else 'under_minimum'
  end;

  update private.user_private
  set birth_date = p_birth_date,
      eligibility_status = case when v_eligible then 'eligible' else 'ineligible' end,
      eligibility_checked_at = now(),
      updated_at = now()
  where user_id = v_user;

  if not v_eligible then
    update public.profiles
    set username = null,
        username_normalized = null,
        username_changed_at = null,
        onboarding_complete = false,
        updated_at = now()
    where user_id = v_user;
  end if;

  return jsonb_build_object(
    'eligible', v_eligible,
    'age', v_age,
    'minimum_age', v_min_age,
    'age_band', v_band
  );
end;
$$;
revoke execute on function public.set_birth_date(date) from public, anon;
grant execute on function public.set_birth_date(date) to authenticated;

-- Private helpers never reveal DOB.
create or replace function private.user_age(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when up.birth_date is null then null
    else extract(year from age(current_date, up.birth_date))::integer end
  from private.user_private up
  where up.user_id = p_user and up.eligibility_status = 'eligible';
$$;
revoke execute on function private.user_age(uuid) from public, anon, authenticated;

create or replace function private.user_age_band(p_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_age integer;
begin
  v_age := private.user_age(p_user);
  return case
    when v_age between 10 and 12 then '10_12'
    when v_age between 13 and 17 then '13_17'
    when v_age >= 18 then '18_plus'
    else null
  end;
end;
$$;
revoke execute on function private.user_age_band(uuid) from public, anon, authenticated;

create or replace function private.age_compatible(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.user_age_band(p_a) is not null
     and private.user_age_band(p_a) = private.user_age_band(p_b);
$$;
revoke execute on function private.age_compatible(uuid,uuid) from public, anon, authenticated;


-- Safe RLS wrappers. Keep private helpers inaccessible to browser roles while
-- allowing policies to evaluate age safety through SECURITY DEFINER functions.
create or replace function public.current_user_age_band()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when auth.uid() is null then null else private.user_age_band(auth.uid()) end;
$$;
revoke execute on function public.current_user_age_band() from public, anon;
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
     and private.age_compatible(auth.uid(), p_other);
$$;
revoke execute on function public.current_user_age_compatible(uuid) from public, anon;
grant execute on function public.current_user_age_compatible(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- SOCIAL CONFIG / CONNECTIONS / BONDS / MEET
-- ---------------------------------------------------------------------------
create table if not exists public.social_config (
  id smallint primary key default 1 check (id = 1),
  meet_session_minutes integer not null default 10 check (meet_session_minutes between 3 and 120),
  meet_request_day_limit integer not null default 30 check (meet_request_day_limit between 1 and 500),
  meet_message_per_minute_limit integer not null default 20 check (meet_message_per_minute_limit between 1 and 120),
  meet_max_messages_per_session integer not null default 100 check (meet_max_messages_per_session between 10 and 1000),
  bond_message_points integer not null default 1 check (bond_message_points between 0 and 20),
  bond_message_daily_cap integer not null default 8 check (bond_message_daily_cap between 0 and 100),
  bond_aura_points integer not null default 2 check (bond_aura_points between 0 and 50),
  bond_aura_daily_cap integer not null default 6 check (bond_aura_daily_cap between 0 and 100),
  bond_shared_game_points integer not null default 3 check (bond_shared_game_points between 0 and 50),
  updated_at timestamptz not null default now()
);
insert into public.social_config(id) values(1) on conflict(id) do nothing;

drop trigger if exists social_config_touch_updated_at on public.social_config;
create trigger social_config_touch_updated_at
before update on public.social_config
for each row execute function public.touch_updated_at();

create table if not exists public.connections (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references auth.users(id) on delete cascade,
  user_high uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','ended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user_low::text < user_high::text),
  unique(user_low,user_high)
);
create index if not exists connections_low_idx on public.connections(user_low,status);
create index if not exists connections_high_idx on public.connections(user_high,status);

drop trigger if exists connections_touch_updated_at on public.connections;
create trigger connections_touch_updated_at
before update on public.connections
for each row execute function public.touch_updated_at();

create table if not exists public.bonds (
  connection_id uuid primary key references public.connections(id) on delete cascade,
  points integer not null default 0 check (points >= 0),
  last_interaction_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists private.bond_events (
  id bigint generated always as identity primary key,
  connection_id uuid not null references public.connections(id) on delete cascade,
  event_type text not null check (event_type in ('message','aura','shared_game','connection','admin')),
  points integer not null check (points between -1000 and 1000),
  source_id uuid,
  actor_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(connection_id,event_type,source_id)
);
create index if not exists bond_events_conn_created_idx on private.bond_events(connection_id,created_at desc);

create table if not exists public.meet_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled','expired')),
  match_score integer not null default 50 check (match_score between 0 and 100),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (sender_id <> receiver_id)
);
create index if not exists meet_requests_receiver_idx on public.meet_requests(receiver_id,status,created_at desc);
create index if not exists meet_requests_sender_idx on public.meet_requests(sender_id,status,created_at desc);
create unique index if not exists meet_requests_pending_pair_unique
on public.meet_requests(least(sender_id::text,receiver_id::text),greatest(sender_id::text,receiver_id::text))
where status='pending';

create table if not exists public.meet_sessions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.meet_requests(id) on delete cascade,
  user_low uuid not null references auth.users(id) on delete cascade,
  user_high uuid not null references auth.users(id) on delete cascade,
  status text not null default 'active' check (status in ('active','connected','closed','expired')),
  icebreaker text not null,
  expires_at timestamptz not null,
  conversation_id uuid references public.conversations(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user_low::text < user_high::text)
);
create index if not exists meet_sessions_users_idx on public.meet_sessions(user_low,user_high,status,expires_at desc);

drop trigger if exists meet_sessions_touch_updated_at on public.meet_sessions;
create trigger meet_sessions_touch_updated_at
before update on public.meet_sessions
for each row execute function public.touch_updated_at();

create table if not exists public.meet_messages (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.meet_sessions(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1200),
  created_at timestamptz not null default now()
);
create index if not exists meet_messages_session_idx on public.meet_messages(session_id,created_at);

create table if not exists public.meet_decisions (
  session_id uuid not null references public.meet_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  decision text not null check (decision in ('keep','move_on')),
  decided_at timestamptz not null default now(),
  primary key(session_id,user_id)
);

create or replace function private.connection_id_for(p_a uuid,p_b uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.id from public.connections c
  where c.user_low = least(p_a,p_b) and c.user_high = greatest(p_a,p_b) and c.status='active'
  limit 1;
$$;
revoke execute on function private.connection_id_for(uuid,uuid) from public,anon,authenticated;

create or replace function private.bond_percent(p_points integer)
returns integer
language sql
immutable
as $$
  select least(100,greatest(1,round(100 * (1 - exp(-greatest(coalesce(p_points,0),0)::numeric / 120.0)))::integer));
$$;
revoke execute on function private.bond_percent(integer) from public,anon,authenticated;

create or replace function private.bond_label(p_percent integer)
returns text
language sql
immutable
as $$
  select case
    when p_percent >= 100 then 'Legendary Bond'
    when p_percent >= 91 then 'Ride or Die'
    when p_percent >= 71 then 'Inner Circle'
    when p_percent >= 51 then 'Close Friend'
    when p_percent >= 31 then 'Homie'
    when p_percent >= 11 then 'Vibing'
    else 'New Connection'
  end;
$$;
revoke execute on function private.bond_label(integer) from public,anon,authenticated;

create or replace function private.add_bond_points(
  p_a uuid,p_b uuid,p_event_type text,p_points integer,p_source uuid,p_actor uuid default null,p_daily_cap integer default null
)
returns void
language plpgsql
security definer
set search_path=''
as $$
declare v_conn uuid; v_today_points integer; v_add integer := greatest(coalesce(p_points,0),0);
begin
  if p_a is null or p_b is null or p_a=p_b or v_add=0 then return; end if;
  v_conn := private.connection_id_for(p_a,p_b);
  if v_conn is null then return; end if;

  if p_daily_cap is not null then
    select coalesce(sum(be.points),0)::integer into v_today_points
    from private.bond_events be
    where be.connection_id=v_conn and be.event_type=p_event_type and be.created_at>=date_trunc('day',now());
    v_add := least(v_add,greatest(p_daily_cap-v_today_points,0));
  end if;
  if v_add<=0 then return; end if;

  begin
    insert into private.bond_events(connection_id,event_type,points,source_id,actor_id)
    values(v_conn,p_event_type,v_add,p_source,p_actor);
  exception when unique_violation then
    return;
  end;

  insert into public.bonds(connection_id,points,last_interaction_at)
  values(v_conn,v_add,now())
  on conflict(connection_id) do update
  set points=public.bonds.points+excluded.points,last_interaction_at=now(),updated_at=now();
end;
$$;
revoke execute on function private.add_bond_points(uuid,uuid,text,integer,uuid,uuid,integer) from public,anon,authenticated;

-- ---------------------------------------------------------------------------
-- Age-safe discovery / chat enforcement.
-- ---------------------------------------------------------------------------
create or replace function public.search_chat_people(p_query text, p_limit integer default 20)
returns table (user_id uuid, username text, display_name text, avatar_url text, aura_total bigint, rank jsonb)
language plpgsql stable security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_query text:=lower(trim(coalesce(p_query,''))); v_limit integer:=least(greatest(coalesce(p_limit,20),1),30);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if char_length(v_query)<2 then return; end if;
  return query
  select p.user_id,p.username,p.display_name,p.avatar_url,p.aura_total,public.get_aura_rank(p.aura_total)
  from public.profiles p
  where p.onboarding_complete=true and p.user_id<>v_user
    and private.age_compatible(v_user,p.user_id)
    and private.connection_id_for(v_user,p.user_id) is not null
    and not public.users_are_blocked(v_user,p.user_id)
    and (lower(coalesce(p.username,'')) like '%'||v_query||'%' or lower(coalesce(p.display_name,'')) like '%'||v_query||'%')
  order by case when lower(coalesce(p.username,''))=v_query then 0 else 1 end,p.aura_total desc
  limit v_limit;
end;
$$;
revoke execute on function public.search_chat_people(text,integer) from public,anon;
grant execute on function public.search_chat_people(text,integer) to authenticated;

create or replace function public.create_direct_chat(p_target_user uuid)
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_key text; v_conversation uuid; v_count integer; v_limit integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_target_user is null or p_target_user=v_user then raise exception 'Choose another user.'; end if;
  if not exists(select 1 from public.profiles where user_id=v_user and onboarding_complete=true) then raise exception 'Finish onboarding first.'; end if;
  if not exists(select 1 from public.profiles where user_id=p_target_user and onboarding_complete=true) then raise exception 'User unavailable.'; end if;
  if not private.age_compatible(v_user,p_target_user) then raise exception 'This connection is unavailable for your age-safety pool.'; end if;
  if private.connection_id_for(v_user,p_target_user) is null then raise exception 'Connect through Meet before starting a direct chat.'; end if;
  if public.users_are_blocked(v_user,p_target_user) then raise exception 'This conversation is unavailable.'; end if;

  v_key:=least(v_user::text,p_target_user::text)||':'||greatest(v_user::text,p_target_user::text);
  select id into v_conversation from public.conversations where direct_key=v_key and type='direct' limit 1;
  if v_conversation is not null then
    insert into public.conversation_members(conversation_id,user_id,role,status) values(v_conversation,v_user,'member','active')
      on conflict(conversation_id,user_id) do update set status='active';
    insert into public.conversation_members(conversation_id,user_id,role,status) values(v_conversation,p_target_user,'member','active')
      on conflict(conversation_id,user_id) do update set status='active';
    update public.conversations set status='active' where id=v_conversation;
    return v_conversation;
  end if;

  select direct_chat_create_hour_limit into v_limit from public.chat_config where id=1;
  select count(*) into v_count from public.conversations where created_by=v_user and type='direct' and created_at>=now()-interval '1 hour';
  if v_count>=v_limit then raise exception 'You are starting chats too quickly. Try again later.'; end if;

  begin
    insert into public.conversations(type,direct_key,created_by) values('direct',v_key,v_user) returning id into v_conversation;
  exception when unique_violation then
    select id into v_conversation from public.conversations where direct_key=v_key;
  end;
  insert into public.conversation_members(conversation_id,user_id,role)
  values(v_conversation,v_user,'member'),(v_conversation,p_target_user,'member')
  on conflict(conversation_id,user_id) do update set status='active';
  return v_conversation;
end;
$$;
revoke execute on function public.create_direct_chat(uuid) from public,anon;
grant execute on function public.create_direct_chat(uuid) to authenticated;

create or replace function public.create_group_chat(p_title text,p_member_ids uuid[])
returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_title text:=trim(coalesce(p_title,'')); v_conversation uuid; v_members uuid[]; v_member uuid; v_max integer; v_created integer; v_group_daily_limit integer; v_requested integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if char_length(v_title)<1 or char_length(v_title)>50 then raise exception 'Group name must be 1–50 characters.'; end if;
  if not exists(select 1 from public.profiles where user_id=v_user and onboarding_complete=true) then raise exception 'Finish onboarding first.'; end if;

  select max_group_members,group_create_day_limit into v_max,v_group_daily_limit from public.chat_config where id=1;
  select count(*) into v_created from public.conversations where created_by=v_user and type='group' and created_at>=date_trunc('day',now());
  if v_created>=v_group_daily_limit then raise exception 'You reached today''s group creation limit.'; end if;

  select coalesce(array_agg(x order by x::text),'{}'::uuid[]) into v_members
  from (select distinct unnest(coalesce(p_member_ids,'{}'::uuid[])) x) s where x<>v_user;
  v_requested:=coalesce(array_length(v_members,1),0);
  if v_requested<1 then raise exception 'Add at least one other person.'; end if;
  if v_requested+1>v_max then raise exception 'This group is too large.'; end if;

  foreach v_member in array v_members loop
    if not exists(select 1 from public.profiles where user_id=v_member and onboarding_complete=true) then raise exception 'One selected user is unavailable.'; end if;
    if not private.age_compatible(v_user,v_member) then raise exception 'All group members must be in the same age-safety pool.'; end if;
    if private.connection_id_for(v_user,v_member) is null then raise exception 'You can only add your connections to a group.'; end if;
    if public.users_are_blocked(v_user,v_member) then raise exception 'One selected user cannot be added.'; end if;
  end loop;

  insert into public.conversations(type,title,created_by) values('group',v_title,v_user) returning id into v_conversation;
  insert into public.conversation_members(conversation_id,user_id,role) values(v_conversation,v_user,'owner');
  insert into public.conversation_members(conversation_id,user_id,role) select v_conversation,x,'member' from unnest(v_members)x;
  return v_conversation;
end;
$$;
revoke execute on function public.create_group_chat(text,uuid[]) from public,anon;
grant execute on function public.create_group_chat(text,uuid[]) to authenticated;

-- ---------------------------------------------------------------------------
-- Discovery and Meet RPCs.
-- ---------------------------------------------------------------------------
create or replace function public.get_discover_people(p_limit integer default 24,p_mode text default 'for_you')
returns table(
  user_id uuid,username text,display_name text,avatar_url text,aura_total bigint,rank jsonb,
  age_display text,age_band text,shared_interests jsonb,shared_count integer,match_score integer,is_online_hint boolean
)
language plpgsql volatile security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_limit integer:=least(greatest(coalesce(p_limit,24),1),50); v_my_band text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  v_my_band:=private.user_age_band(v_user);
  if v_my_band is null then raise exception 'Age eligibility is not complete.'; end if;

  return query
  with mine as (
    select ui.interest_id from public.user_interests ui where ui.user_id=v_user
  ), candidates as (
    select p.user_id,p.username,p.display_name,p.avatar_url,p.aura_total,
      private.user_age(p.user_id) as age,
      coalesce((select count(*) from public.user_interests x join mine m on m.interest_id=x.interest_id where x.user_id=p.user_id),0)::integer shared
    from public.profiles p
    where p.onboarding_complete=true and p.user_id<>v_user
      and private.age_compatible(v_user,p.user_id)
      and not public.users_are_blocked(v_user,p.user_id)
      and not exists(select 1 from public.connections c where c.status='active' and c.user_low=least(v_user,p.user_id) and c.user_high=greatest(v_user,p.user_id))
      and not exists(select 1 from public.meet_requests mr where mr.status='pending' and ((mr.sender_id=v_user and mr.receiver_id=p.user_id) or (mr.sender_id=p.user_id and mr.receiver_id=v_user)))
  )
  select c.user_id,c.username,c.display_name,c.avatar_url,c.aura_total,public.get_aura_rank(c.aura_total),
    case when c.age>=18 then c.age::text else case when c.age between 10 and 12 then '10–12' else 'Teen' end end,
    v_my_band,
    coalesce((select jsonb_agg(i.slug order by i.sort_order) from public.user_interests ui join public.interests i on i.id=ui.interest_id join mine m on m.interest_id=ui.interest_id where ui.user_id=c.user_id),'[]'::jsonb),
    c.shared,
    least(98,greatest(45,50 + c.shared*9 + case when c.aura_total>=200 then 3 else 0 end))::integer,
    false
  from candidates c
  order by
    case when p_mode='new' then (select created_at from public.profiles p2 where p2.user_id=c.user_id) end desc nulls last,
    c.shared desc,
    case when p_mode='rising' then c.aura_total else 0 end desc,
    random()
  limit v_limit;
end;
$$;
revoke execute on function public.get_discover_people(integer,text) from public,anon;
grant execute on function public.get_discover_people(integer,text) to authenticated;

create or replace function public.send_meet_request(p_target uuid)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_limit integer; v_count integer; v_request uuid; v_shared integer; v_score integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_target is null or p_target=v_user then raise exception 'User unavailable.'; end if;
  if not exists(select 1 from public.profiles where user_id=p_target and onboarding_complete=true) then raise exception 'User unavailable.'; end if;
  if not private.age_compatible(v_user,p_target) then raise exception 'This Meet is unavailable for your age-safety pool.'; end if;
  if public.users_are_blocked(v_user,p_target) then raise exception 'User unavailable.'; end if;
  if private.connection_id_for(v_user,p_target) is not null then raise exception 'You are already connected.'; end if;

  select meet_request_day_limit into v_limit from public.social_config where id=1;
  select count(*) into v_count from public.meet_requests where sender_id=v_user and created_at>=date_trunc('day',now());
  if v_count>=v_limit then raise exception 'You reached today''s Meet request limit.'; end if;

  update public.meet_requests set status='expired',responded_at=now()
  where status='pending' and created_at<now()-interval '48 hours';

  if exists(select 1 from public.meet_requests mr where mr.status='pending' and ((mr.sender_id=v_user and mr.receiver_id=p_target) or (mr.sender_id=p_target and mr.receiver_id=v_user))) then
    raise exception 'A Meet request is already pending.';
  end if;

  select count(*)::integer into v_shared
  from public.user_interests a join public.user_interests b on b.interest_id=a.interest_id
  where a.user_id=v_user and b.user_id=p_target;
  v_score:=least(98,greatest(45,50+v_shared*9));

  insert into public.meet_requests(sender_id,receiver_id,match_score)
  values(v_user,p_target,v_score) returning id into v_request;
  return jsonb_build_object('ok',true,'request_id',v_request,'match_score',v_score);
end;
$$;
revoke execute on function public.send_meet_request(uuid) from public,anon;
grant execute on function public.send_meet_request(uuid) to authenticated;

create or replace function public.get_meet_requests(p_limit integer default 30)
returns table(request_id uuid,direction text,status text,other_user_id uuid,username text,display_name text,avatar_url text,aura_total bigint,match_score integer,created_at timestamptz)
language sql stable security definer set search_path=''
as $$
  select mr.id,
    case when mr.receiver_id=auth.uid() then 'incoming' else 'outgoing' end,
    mr.status,p.user_id,p.username,p.display_name,p.avatar_url,p.aura_total,mr.match_score,mr.created_at
  from public.meet_requests mr
  join public.profiles p on p.user_id=case when mr.receiver_id=auth.uid() then mr.sender_id else mr.receiver_id end
  where auth.uid() is not null and (mr.sender_id=auth.uid() or mr.receiver_id=auth.uid())
    and mr.status in('pending','accepted')
  order by case when mr.receiver_id=auth.uid() and mr.status='pending' then 0 else 1 end,mr.created_at desc
  limit least(greatest(coalesce(p_limit,30),1),100);
$$;
revoke execute on function public.get_meet_requests(integer) from public,anon;
grant execute on function public.get_meet_requests(integer) to authenticated;

create or replace function public.respond_meet_request(p_request uuid,p_accept boolean)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_req public.meet_requests%rowtype; v_session uuid; v_minutes integer; v_ice text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_req from public.meet_requests where id=p_request for update;
  if not found or v_req.receiver_id<>v_user or v_req.status<>'pending' then raise exception 'Meet request unavailable.'; end if;
  if not private.age_compatible(v_req.sender_id,v_req.receiver_id) then raise exception 'Meet request unavailable.'; end if;
  if public.users_are_blocked(v_req.sender_id,v_req.receiver_id) then raise exception 'Meet request unavailable.'; end if;

  if not coalesce(p_accept,false) then
    update public.meet_requests set status='declined',responded_at=now() where id=p_request;
    return jsonb_build_object('ok',true,'accepted',false);
  end if;

  select meet_session_minutes into v_minutes from public.social_config where id=1;
  v_ice := (array[
    'You both get one superpower for 24 hours. What are you picking?',
    'Delete one forever: music or movies. Defend your choice.',
    'What opinion would get you cooked in your group chat?',
    'You have a free flight tonight. Where are you going?',
    'What is the funniest useless skill you have?'
  ])[1+floor(random()*5)::integer];

  update public.meet_requests set status='accepted',responded_at=now() where id=p_request;
  insert into public.meet_sessions(request_id,user_low,user_high,icebreaker,expires_at)
  values(p_request,least(v_req.sender_id,v_req.receiver_id),greatest(v_req.sender_id,v_req.receiver_id),v_ice,now()+make_interval(mins=>v_minutes))
  returning id into v_session;
  return jsonb_build_object('ok',true,'accepted',true,'session_id',v_session,'expires_in_minutes',v_minutes);
end;
$$;
revoke execute on function public.respond_meet_request(uuid,boolean) from public,anon;
grant execute on function public.respond_meet_request(uuid,boolean) to authenticated;



create or replace function public.get_my_meet_sessions(p_limit integer default 20)
returns table(session_id uuid,status text,other_user_id uuid,username text,display_name text,avatar_url text,aura_total bigint,match_score integer,expires_at timestamptz,conversation_id uuid,created_at timestamptz)
language sql stable security definer set search_path=''
as $$
  select s.id,s.status,p.user_id,p.username,p.display_name,p.avatar_url,p.aura_total,mr.match_score,s.expires_at,s.conversation_id,s.created_at
  from public.meet_sessions s
  join public.meet_requests mr on mr.id=s.request_id
  join public.profiles p on p.user_id=case when s.user_low=auth.uid() then s.user_high else s.user_low end
  where auth.uid() is not null and auth.uid() in(s.user_low,s.user_high)
    and (s.status='connected' or (s.status='active' and s.expires_at>now()))
  order by case when s.status='active' then 0 else 1 end,s.created_at desc
  limit least(greatest(coalesce(p_limit,20),1),100);
$$;
revoke execute on function public.get_my_meet_sessions(integer) from public,anon;
grant execute on function public.get_my_meet_sessions(integer) to authenticated;

create or replace function public.get_meet_session(p_session uuid)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_s public.meet_sessions%rowtype; v_other uuid; v_profile public.profiles%rowtype; v_mine text; v_theirs text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_s from public.meet_sessions where id=p_session;
  if not found or v_user not in (v_s.user_low,v_s.user_high) then raise exception 'Meet unavailable.'; end if;
  if v_s.status='active' and v_s.expires_at<=now() then
    update public.meet_sessions set status='expired',updated_at=now() where id=p_session;
    v_s.status:='expired';
  end if;
  v_other:=case when v_user=v_s.user_low then v_s.user_high else v_s.user_low end;
  select * into v_profile from public.profiles where user_id=v_other;
  select decision into v_mine from public.meet_decisions where session_id=p_session and user_id=v_user;
  select decision into v_theirs from public.meet_decisions where session_id=p_session and user_id=v_other;
  return jsonb_build_object(
    'session_id',v_s.id,'status',v_s.status,'expires_at',v_s.expires_at,'icebreaker',v_s.icebreaker,'conversation_id',v_s.conversation_id,
    'my_decision',v_mine,'their_decision',v_theirs,
    'other',jsonb_build_object('user_id',v_profile.user_id,'username',v_profile.username,'display_name',v_profile.display_name,'avatar_url',v_profile.avatar_url,'aura_total',v_profile.aura_total,'rank',public.get_aura_rank(v_profile.aura_total))
  );
end;
$$;
revoke execute on function public.get_meet_session(uuid) from public,anon;
grant execute on function public.get_meet_session(uuid) to authenticated;

create or replace function public.get_meet_messages(p_session uuid,p_limit integer default 100)
returns table(id uuid,sender_id uuid,body text,created_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.meet_sessions s where s.id=p_session and v_user in(s.user_low,s.user_high)) then raise exception 'Meet unavailable.'; end if;
  return query select m.id,m.sender_id,m.body,m.created_at from public.meet_messages m where m.session_id=p_session order by m.created_at asc limit least(greatest(coalesce(p_limit,100),1),300);
end;
$$;
revoke execute on function public.get_meet_messages(uuid,integer) from public,anon;
grant execute on function public.get_meet_messages(uuid,integer) to authenticated;

create or replace function public.send_meet_message(p_session uuid,p_body text)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_s public.meet_sessions%rowtype; v_body text:=trim(coalesce(p_body,'')); v_cfg public.social_config%rowtype; v_recent integer; v_total integer; v_id uuid; v_created timestamptz;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_s from public.meet_sessions where id=p_session for update;
  if not found or v_user not in(v_s.user_low,v_s.user_high) then raise exception 'Meet unavailable.'; end if;
  if v_s.status<>'active' or v_s.expires_at<=now() then
    if v_s.status='active' then update public.meet_sessions set status='expired' where id=p_session; end if;
    raise exception 'This Meet has ended.';
  end if;
  if char_length(v_body)<1 or char_length(v_body)>1200 then raise exception 'Message must be 1–1200 characters.'; end if;
  if public.users_are_blocked(v_s.user_low,v_s.user_high) then raise exception 'This Meet is unavailable.'; end if;
  select * into v_cfg from public.social_config where id=1;
  select count(*) into v_recent from public.meet_messages where sender_id=v_user and created_at>=now()-interval '1 minute';
  if v_recent>=v_cfg.meet_message_per_minute_limit then raise exception 'You are sending messages too quickly.'; end if;
  select count(*) into v_total from public.meet_messages where session_id=p_session;
  if v_total>=v_cfg.meet_max_messages_per_session then raise exception 'This Meet reached its message limit.'; end if;
  insert into public.meet_messages(session_id,sender_id,body) values(p_session,v_user,v_body) returning id,created_at into v_id,v_created;
  return jsonb_build_object('id',v_id,'sender_id',v_user,'body',v_body,'created_at',v_created);
end;
$$;
revoke execute on function public.send_meet_message(uuid,text) from public,anon;
grant execute on function public.send_meet_message(uuid,text) to authenticated;

create or replace function public.decide_meet(p_session uuid,p_decision text)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_s public.meet_sessions%rowtype; v_other uuid; v_other_decision text; v_conn uuid; v_chat uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_decision not in('keep','move_on') then raise exception 'Decision unavailable.'; end if;
  select * into v_s from public.meet_sessions where id=p_session for update;
  if not found or v_user not in(v_s.user_low,v_s.user_high) then raise exception 'Meet unavailable.'; end if;
  if v_s.status not in('active','expired') then
    return jsonb_build_object('ok',true,'status',v_s.status,'conversation_id',v_s.conversation_id);
  end if;
  v_other:=case when v_user=v_s.user_low then v_s.user_high else v_s.user_low end;
  insert into public.meet_decisions(session_id,user_id,decision) values(p_session,v_user,p_decision)
  on conflict(session_id,user_id) do update set decision=excluded.decision,decided_at=now();

  if p_decision='move_on' then
    update public.meet_sessions set status='closed',updated_at=now() where id=p_session;
    return jsonb_build_object('ok',true,'connected',false,'status','closed');
  end if;

  select decision into v_other_decision from public.meet_decisions where session_id=p_session and user_id=v_other;
  if v_other_decision='move_on' then
    update public.meet_sessions set status='closed',updated_at=now() where id=p_session;
    return jsonb_build_object('ok',true,'connected',false,'status','closed');
  end if;
  if v_other_decision<>'keep' then
    return jsonb_build_object('ok',true,'connected',false,'status',v_s.status,'waiting_for_other',true);
  end if;

  if not private.age_compatible(v_user,v_other) or public.users_are_blocked(v_user,v_other) then raise exception 'Connection unavailable.'; end if;
  insert into public.connections(user_low,user_high,status)
  values(least(v_user,v_other),greatest(v_user,v_other),'active')
  on conflict(user_low,user_high) do update set status='active',updated_at=now()
  returning id into v_conn;
  insert into public.bonds(connection_id,points,last_interaction_at) values(v_conn,1,now())
  on conflict(connection_id) do nothing;
  begin
    insert into private.bond_events(connection_id,event_type,points,source_id,actor_id)
    values(v_conn,'connection',1,p_session,v_user);
  exception when unique_violation then null; end;

  v_chat:=public.create_direct_chat(v_other);
  update public.meet_sessions set status='connected',conversation_id=v_chat,updated_at=now() where id=p_session;
  return jsonb_build_object('ok',true,'connected',true,'status','connected','conversation_id',v_chat,'connection_id',v_conn,'bond_percent',private.bond_percent(1),'bond_label',private.bond_label(private.bond_percent(1)));
end;
$$;
revoke execute on function public.decide_meet(uuid,text) from public,anon;
grant execute on function public.decide_meet(uuid,text) to authenticated;

create or replace function public.get_my_connections(p_limit integer default 50)
returns table(connection_id uuid,user_id uuid,username text,display_name text,avatar_url text,aura_total bigint,bond_percent integer,bond_label text,bond_points integer,last_interaction_at timestamptz,connected_at timestamptz)
language sql stable security definer set search_path=''
as $$
  select c.id,p.user_id,p.username,p.display_name,p.avatar_url,p.aura_total,
    private.bond_percent(coalesce(b.points,0)),private.bond_label(private.bond_percent(coalesce(b.points,0))),coalesce(b.points,0),b.last_interaction_at,c.created_at
  from public.connections c
  join public.profiles p on p.user_id=case when c.user_low=auth.uid() then c.user_high else c.user_low end
  left join public.bonds b on b.connection_id=c.id
  where auth.uid() is not null and c.status='active' and auth.uid() in(c.user_low,c.user_high)
  order by coalesce(b.last_interaction_at,c.created_at) desc
  limit least(greatest(coalesce(p_limit,50),1),200);
$$;
revoke execute on function public.get_my_connections(integer) from public,anon;
grant execute on function public.get_my_connections(integer) to authenticated;

create or replace function public.get_bond_with_user(p_user uuid)
returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare v_me uuid:=auth.uid(); v_conn uuid; v_points integer; v_since timestamptz; v_last timestamptz; v_percent integer;
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  v_conn:=private.connection_id_for(v_me,p_user);
  if v_conn is null then return null; end if;
  select coalesce(b.points,0),c.created_at,b.last_interaction_at into v_points,v_since,v_last
  from public.connections c left join public.bonds b on b.connection_id=c.id where c.id=v_conn;
  v_percent:=private.bond_percent(v_points);
  return jsonb_build_object('connection_id',v_conn,'bond_points',v_points,'bond_percent',v_percent,'bond_label',private.bond_label(v_percent),'connected_at',v_since,'last_interaction_at',v_last);
end;
$$;
revoke execute on function public.get_bond_with_user(uuid) from public,anon;
grant execute on function public.get_bond_with_user(uuid) to authenticated;

-- Extra defense for any pre-existing conversation created before this migration.
create or replace function private.guard_chat_age_pool()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_member uuid;
begin
  for v_member in select cm.user_id from public.conversation_members cm where cm.conversation_id=new.conversation_id and cm.status='active' and cm.user_id<>new.sender_id loop
    if not private.age_compatible(new.sender_id,v_member) then
      raise exception 'This conversation is unavailable for your age-safety pool.';
    end if;
  end loop;
  return new;
end;
$$;
revoke execute on function private.guard_chat_age_pool() from public,anon,authenticated;
drop trigger if exists messages_age_pool_before_insert on public.messages;
create trigger messages_age_pool_before_insert before insert on public.messages for each row execute function private.guard_chat_age_pool();

-- ---------------------------------------------------------------------------
-- Bond triggers: messages, Aura, shared games.
-- ---------------------------------------------------------------------------
create or replace function private.on_message_bond()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_other uuid; v_type text; v_cfg public.social_config%rowtype;
begin
  select c.type into v_type from public.conversations c where c.id=new.conversation_id;
  if v_type<>'direct' or new.kind<>'text' or new.status<>'active' then return new; end if;
  select cm.user_id into v_other from public.conversation_members cm where cm.conversation_id=new.conversation_id and cm.user_id<>new.sender_id and cm.status='active' limit 1;
  if v_other is null then return new; end if;
  select * into v_cfg from public.social_config where id=1;
  perform private.add_bond_points(new.sender_id,v_other,'message',v_cfg.bond_message_points,new.id,new.sender_id,v_cfg.bond_message_daily_cap);
  return new;
end;
$$;
revoke execute on function private.on_message_bond() from public,anon,authenticated;
drop trigger if exists messages_bond_after_insert on public.messages;
create trigger messages_bond_after_insert after insert on public.messages for each row execute function private.on_message_bond();

create or replace function private.on_aura_bond()
returns trigger language plpgsql security definer set search_path=''
as $$
declare v_cfg public.social_config%rowtype;
begin
  if new.status<>'counted' or new.giver_id is null or new.source<>'peer' then return new; end if;
  select * into v_cfg from public.social_config where id=1;
  perform private.add_bond_points(new.giver_id,new.receiver_id,'aura',v_cfg.bond_aura_points,new.id::text::uuid,new.giver_id,v_cfg.bond_aura_daily_cap);
  return new;
end;
$$;
revoke execute on function private.on_aura_bond() from public,anon,authenticated;
drop trigger if exists aura_events_bond_after_insert on public.aura_events;
create trigger aura_events_bond_after_insert after insert on public.aura_events for each row execute function private.on_aura_bond();

create or replace function private.on_game_result_bond()
returns trigger language plpgsql security definer set search_path=''
as $$
declare r record; v_cfg public.social_config%rowtype;
begin
  select * into v_cfg from public.social_config where id=1;
  for r in select gr.user_id from public.game_results gr where gr.session_id=new.session_id and gr.user_id<>new.user_id loop
    perform private.add_bond_points(new.user_id,r.user_id,'shared_game',v_cfg.bond_shared_game_points,new.session_id,new.user_id,null);
  end loop;
  return new;
end;
$$;
revoke execute on function private.on_game_result_bond() from public,anon,authenticated;
drop trigger if exists game_results_bond_after_insert on public.game_results;
create trigger game_results_bond_after_insert after insert on public.game_results for each row execute function private.on_game_result_bond();

-- ---------------------------------------------------------------------------
-- RLS / grants. Everything writes through RPC.
-- ---------------------------------------------------------------------------
alter table public.connections enable row level security;
alter table public.bonds enable row level security;
alter table public.meet_requests enable row level security;
alter table public.meet_sessions enable row level security;
alter table public.meet_messages enable row level security;
alter table public.meet_decisions enable row level security;

revoke all on table public.social_config,public.connections,public.bonds,public.meet_requests,public.meet_sessions,public.meet_messages,public.meet_decisions from anon,authenticated;
grant select on table public.social_config to authenticated;
grant select on table public.connections,public.bonds,public.meet_requests,public.meet_sessions,public.meet_messages,public.meet_decisions to authenticated;

create policy "connection members read" on public.connections for select to authenticated using(auth.uid() in(user_low,user_high));
create policy "bond connection members read" on public.bonds for select to authenticated using(exists(select 1 from public.connections c where c.id=connection_id and auth.uid() in(c.user_low,c.user_high)));
create policy "meet request parties read" on public.meet_requests for select to authenticated using(auth.uid() in(sender_id,receiver_id));
create policy "meet session parties read" on public.meet_sessions for select to authenticated using(auth.uid() in(user_low,user_high));
create policy "meet message parties read" on public.meet_messages for select to authenticated using(exists(select 1 from public.meet_sessions s where s.id=session_id and auth.uid() in(s.user_low,s.user_high)));
create policy "meet decision parties read" on public.meet_decisions for select to authenticated using(exists(select 1 from public.meet_sessions s where s.id=session_id and auth.uid() in(s.user_low,s.user_high)));

-- Realtime is safe because RLS restricts Meet rows to session participants.
do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='meet_messages') then
    execute 'alter publication supabase_realtime add table public.meet_messages';
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='meet_sessions') then
    execute 'alter publication supabase_realtime add table public.meet_sessions';
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='meet_decisions') then
    execute 'alter publication supabase_realtime add table public.meet_decisions';
  end if;
exception when undefined_object then null; end $$;


-- ---------------------------------------------------------------------------
-- Cross-age privacy guard: public profiles/Aura feeds are only visible inside
-- the viewer's safety pool. Own profile remains readable.
-- ---------------------------------------------------------------------------
drop policy if exists "authenticated can read completed profiles or own profile" on public.profiles;
create policy "authenticated can read completed profiles or own profile"
on public.profiles for select to authenticated
using (
  (select auth.uid()) = user_id
  or (onboarding_complete = true and public.current_user_age_compatible(user_id))
);

drop policy if exists "authenticated can read public aura targets or own targets" on public.aura_targets;
create policy "authenticated can read public aura targets or own targets"
on public.aura_targets for select to authenticated
using (
  owner_id = (select auth.uid())
  or (status='active' and visibility='public' and public.current_user_age_compatible(owner_id))
);

create or replace function private.guard_peer_aura_age_pool()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.source='peer' and new.giver_id is not null and not private.age_compatible(new.giver_id,new.receiver_id) then
    raise exception 'Aura is unavailable across age-safety pools.';
  end if;
  return new;
end;
$$;
revoke execute on function private.guard_peer_aura_age_pool() from public,anon,authenticated;
drop trigger if exists aura_events_age_pool_before_insert on public.aura_events;
create trigger aura_events_age_pool_before_insert before insert on public.aura_events for each row execute function private.guard_peer_aura_age_pool();

-- Age-safe versions of existing Aura surfaces.
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
      and private.age_compatible(v_user,p.user_id)
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
    and private.age_compatible(v_user,p.user_id)
  order by score desc, t.created_at desc
  limit v_limit offset v_offset;
end;
$$;

revoke execute on function public.get_rising_feed(integer,integer) from public, anon;
grant execute on function public.get_rising_feed(integer,integer) to authenticated;

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
    and private.age_compatible(v_user,p.user_id)
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


commit;
