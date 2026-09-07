-- VYBE V1: secure authentication/onboarding foundation.
-- Run this in a fresh Supabase project via SQL Editor or Supabase CLI.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.app_config (
  id smallint primary key default 1 check (id = 1),
  min_age smallint not null default 18 check (min_age between 13 and 99),
  generation_start_date date not null default date '1997-01-01',
  generation_end_date date not null default date '2012-12-31',
  username_change_days integer not null default 30 check (username_change_days between 1 and 365),
  old_username_reserve_days integer not null default 90 check (old_username_reserve_days between 0 and 3650),
  min_interests integer not null default 3 check (min_interests between 1 and 20),
  updated_at timestamptz not null default now()
);

insert into public.app_config (id) values (1)
on conflict (id) do nothing;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text,
  username_normalized text,
  username_changed_at timestamptz,
  display_name text,
  bio text not null default '',
  avatar_url text,
  aura_total bigint not null default 1 check (aura_total >= 1),
  onboarding_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_username_format check (
    username is null or username ~ '^[A-Za-z0-9_]{3,20}$'
  ),
  constraint profiles_username_normalized_consistent check (
    (username is null and username_normalized is null)
    or username_normalized = lower(username)
  ),
  constraint profiles_display_name_length check (
    display_name is null or char_length(display_name) between 1 and 40
  ),
  constraint profiles_bio_length check (char_length(bio) <= 300)
);

create unique index if not exists profiles_username_normalized_unique
  on public.profiles (username_normalized)
  where username_normalized is not null;

create table if not exists private.user_private (
  user_id uuid primary key references auth.users(id) on delete cascade,
  birth_date date,
  eligibility_status text not null default 'pending'
    check (eligibility_status in ('pending','eligible','ineligible')),
  eligibility_checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists private.reserved_usernames (
  username_normalized text primary key,
  reason text not null default 'system',
  created_at timestamptz not null default now()
);

insert into private.reserved_usernames (username_normalized, reason) values
  ('admin','system'),
  ('administrator','system'),
  ('support','system'),
  ('help','system'),
  ('security','system'),
  ('system','system'),
  ('vybe','brand'),
  ('vybehq','brand'),
  ('official','system')
on conflict (username_normalized) do nothing;

create table if not exists private.username_reservations (
  username_normalized text primary key,
  reserved_for uuid references auth.users(id) on delete cascade,
  release_at timestamptz not null,
  reason text not null default 'previous_username',
  created_at timestamptz not null default now()
);

create table if not exists private.username_history (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  old_username text,
  new_username text not null,
  changed_by uuid,
  source text not null default 'user' check (source in ('user','admin','system')),
  changed_at timestamptz not null default now()
);

create table if not exists public.interests (
  id bigint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z0-9_]{2,40}$'),
  label text not null check (char_length(label) between 1 and 50),
  icon text not null default '✦',
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

insert into public.interests (slug,label,icon,sort_order) values
  ('gaming','Gaming','🎮',10),
  ('football','Football','⚽',20),
  ('f1','F1','🏎️',30),
  ('music','Music','🎵',40),
  ('movies','Movies','🎬',50),
  ('memes','Memes','😂',60),
  ('deep_talks','Deep Talks','🧠',70),
  ('night_owls','Night Owls','🌙',80),
  ('tech','Tech','💻',90),
  ('startups','Startups','🔥',100),
  ('gym','Gym','🏋️',110),
  ('photography','Photography','📸',120),
  ('art','Art','🎨',130),
  ('books','Books','📚',140),
  ('travel','Travel','✈️',150),
  ('food','Food','🍔',160)
on conflict (slug) do update set
  label = excluded.label,
  icon = excluded.icon,
  sort_order = excluded.sort_order;

create table if not exists public.user_interests (
  user_id uuid not null references auth.users(id) on delete cascade,
  interest_id bigint not null references public.interests(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, interest_id)
);

-- Generic timestamp trigger.
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function public.touch_updated_at() from public, anon, authenticated;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

drop trigger if exists user_private_touch_updated_at on private.user_private;
create trigger user_private_touch_updated_at
before update on private.user_private
for each row execute function public.touch_updated_at();

drop trigger if exists app_config_touch_updated_at on public.app_config;
create trigger app_config_touch_updated_at
before update on public.app_config
for each row execute function public.touch_updated_at();

-- Create base rows whenever Supabase Auth creates a user.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  insert into private.user_private (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Backfill rows if this migration is applied after test users already exist.
insert into public.profiles (user_id)
select id from auth.users
on conflict (user_id) do nothing;

insert into private.user_private (user_id)
select id from auth.users
on conflict (user_id) do nothing;

-- Username availability. Authenticated only so enumeration is not public.
create or replace function public.check_username_available(p_username text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_username text := trim(p_username);
  v_normalized text := lower(trim(p_username));
  v_current text;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  if v_username !~ '^[A-Za-z0-9_]{3,20}$' then
    return jsonb_build_object('available', false, 'reason', 'Use 3–20 letters, numbers or underscores only.');
  end if;

  select username_normalized into v_current
  from public.profiles
  where user_id = v_user;

  if v_current = v_normalized then
    return jsonb_build_object('available', true, 'normalized', v_normalized, 'reason', 'This is already your username.');
  end if;

  if exists (
    select 1 from private.reserved_usernames r
    where r.username_normalized = v_normalized
  ) then
    return jsonb_build_object('available', false, 'reason', 'That username is reserved.');
  end if;

  if exists (
    select 1 from public.profiles p
    where p.username_normalized = v_normalized
      and p.user_id <> v_user
  ) then
    return jsonb_build_object('available', false, 'reason', 'Already taken.');
  end if;

  if exists (
    select 1 from private.username_reservations r
    where r.username_normalized = v_normalized
      and r.release_at > now()
      and r.reserved_for is distinct from v_user
  ) then
    return jsonb_build_object('available', false, 'reason', 'Temporarily unavailable.');
  end if;

  return jsonb_build_object('available', true, 'normalized', v_normalized, 'reason', 'Username is available.');
end;
$$;

revoke execute on function public.check_username_available(text) from public, anon;
grant execute on function public.check_username_available(text) to authenticated;

create or replace function public.claim_username(p_username text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_username text := trim(p_username);
  v_normalized text := lower(trim(p_username));
  v_old_username text;
  v_old_normalized text;
  v_last_change timestamptz;
  v_change_days integer;
  v_reserve_days integer;
  v_available jsonb;
  v_next_change timestamptz;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  insert into public.profiles (user_id) values (v_user)
  on conflict (user_id) do nothing;

  select username, username_normalized, username_changed_at
    into v_old_username, v_old_normalized, v_last_change
  from public.profiles
  where user_id = v_user
  for update;

  if v_old_normalized = v_normalized then
    return jsonb_build_object(
      'ok', true,
      'username', v_old_username,
      'next_change_at', v_last_change + make_interval(days => (select username_change_days from public.app_config where id = 1))
    );
  end if;

  select username_change_days, old_username_reserve_days
    into v_change_days, v_reserve_days
  from public.app_config where id = 1;

  if v_old_username is not null and v_last_change is not null and now() < v_last_change + make_interval(days => v_change_days) then
    v_next_change := v_last_change + make_interval(days => v_change_days);
    raise exception 'Username can be changed again after %', v_next_change;
  end if;

  v_available := public.check_username_available(v_username);
  if coalesce((v_available->>'available')::boolean, false) is false then
    raise exception '%', coalesce(v_available->>'reason', 'Username is unavailable.');
  end if;

  if v_old_normalized is not null then
    insert into private.username_reservations (username_normalized, reserved_for, release_at, reason)
    values (v_old_normalized, v_user, now() + make_interval(days => v_reserve_days), 'previous_username')
    on conflict (username_normalized) do update set
      reserved_for = excluded.reserved_for,
      release_at = excluded.release_at,
      reason = excluded.reason;
  end if;

  update public.profiles
  set username = v_username,
      username_normalized = v_normalized,
      username_changed_at = now()
  where user_id = v_user;

  insert into private.username_history (user_id, old_username, new_username, changed_by, source)
  values (v_user, v_old_username, v_username, v_user, 'user');

  return jsonb_build_object(
    'ok', true,
    'username', v_username,
    'next_change_at', now() + make_interval(days => v_change_days)
  );
exception
  when unique_violation then
    raise exception 'Already taken.';
end;
$$;

revoke execute on function public.claim_username(text) from public, anon;
grant execute on function public.claim_username(text) to authenticated;

-- DOB is write-once for users. Admin correction will be a separate privileged flow.
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
  v_generation_start date;
  v_generation_end date;
  v_age integer;
  v_eligible boolean;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  if p_birth_date is null or p_birth_date > current_date then
    raise exception 'Enter a valid birth date.';
  end if;

  insert into private.user_private (user_id) values (v_user)
  on conflict (user_id) do nothing;

  select birth_date into v_existing
  from private.user_private
  where user_id = v_user
  for update;

  if v_existing is not null then
    raise exception 'Birthday is already locked. Contact support for a correction.';
  end if;

  select min_age, generation_start_date, generation_end_date
    into v_min_age, v_generation_start, v_generation_end
  from public.app_config where id = 1;

  v_age := extract(year from age(current_date, p_birth_date));
  v_eligible :=
    p_birth_date >= v_generation_start
    and p_birth_date <= v_generation_end
    and p_birth_date <= (current_date - make_interval(years => v_min_age));

  update private.user_private
  set birth_date = p_birth_date,
      eligibility_status = case when v_eligible then 'eligible' else 'ineligible' end,
      eligibility_checked_at = now()
  where user_id = v_user;

  if not v_eligible then
    -- Do not let an ineligible auth account hold a public VYBE username.
    update public.profiles
    set username = null,
        username_normalized = null,
        username_changed_at = null,
        onboarding_complete = false
    where user_id = v_user;
  end if;

  return jsonb_build_object(
    'eligible', v_eligible,
    'age', v_age,
    'minimum_age', v_min_age,
    'generation_start_date', v_generation_start,
    'generation_end_date', v_generation_end
  );
end;
$$;

revoke execute on function public.set_birth_date(date) from public, anon;
grant execute on function public.set_birth_date(date) to authenticated;

create or replace function public.set_profile_details(p_display_name text, p_bio text default '')
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_display_name text := trim(p_display_name);
  v_bio text := coalesce(trim(p_bio), '');
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;
  if char_length(v_display_name) < 1 or char_length(v_display_name) > 40 then
    raise exception 'Display name must be 1–40 characters.';
  end if;
  if char_length(v_bio) > 300 then
    raise exception 'Bio must be 300 characters or fewer.';
  end if;

  update public.profiles
  set display_name = v_display_name,
      bio = v_bio
  where user_id = v_user;

  return jsonb_build_object('ok', true);
end;
$$;

revoke execute on function public.set_profile_details(text,text) from public, anon;
grant execute on function public.set_profile_details(text,text) to authenticated;

create or replace function public.set_my_interests(p_slugs text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_min integer;
  v_count integer;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select min_interests into v_min from public.app_config where id = 1;

  if p_slugs is null or cardinality(p_slugs) < v_min then
    raise exception 'Choose at least % interests.', v_min;
  end if;
  if cardinality(p_slugs) > 20 then
    raise exception 'Choose no more than 20 interests.';
  end if;

  select count(*) into v_count
  from public.interests i
  where i.active = true
    and i.slug = any(p_slugs);

  if v_count <> (select count(distinct slug) from unnest(p_slugs) as t(slug)) then
    raise exception 'One or more interests are invalid.';
  end if;

  delete from public.user_interests where user_id = v_user;

  insert into public.user_interests (user_id, interest_id)
  select v_user, i.id
  from public.interests i
  where i.active = true and i.slug = any(p_slugs)
  on conflict do nothing;

  return jsonb_build_object('ok', true, 'count', v_count);
end;
$$;

revoke execute on function public.set_my_interests(text[]) from public, anon;
grant execute on function public.set_my_interests(text[]) to authenticated;

create or replace function public.complete_onboarding()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_profile public.profiles%rowtype;
  v_status text;
  v_interest_count integer;
  v_min_interests integer;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select * into v_profile from public.profiles where user_id = v_user for update;
  select eligibility_status into v_status from private.user_private where user_id = v_user;
  select count(*) into v_interest_count from public.user_interests where user_id = v_user;
  select min_interests into v_min_interests from public.app_config where id = 1;

  if v_profile.username is null then raise exception 'Choose a username first.'; end if;
  if v_status <> 'eligible' then raise exception 'Age eligibility is not complete.'; end if;
  if v_profile.display_name is null or trim(v_profile.display_name) = '' then raise exception 'Add a display name.'; end if;
  if v_interest_count < v_min_interests then raise exception 'Choose at least % interests.', v_min_interests; end if;

  update public.profiles set onboarding_complete = true where user_id = v_user;

  return jsonb_build_object('ok', true, 'aura_total', v_profile.aura_total);
end;
$$;

revoke execute on function public.complete_onboarding() from public, anon;
grant execute on function public.complete_onboarding() to authenticated;

create or replace function public.get_my_onboarding_state()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_result jsonb;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  insert into public.profiles (user_id) values (v_user)
  on conflict (user_id) do nothing;
  insert into private.user_private (user_id) values (v_user)
  on conflict (user_id) do nothing;

  select jsonb_build_object(
    'user_id', p.user_id,
    'username', p.username,
    'username_changed_at', p.username_changed_at,
    'display_name', p.display_name,
    'bio', p.bio,
    'avatar_url', p.avatar_url,
    'aura_total', p.aura_total,
    'onboarding_complete', p.onboarding_complete,
    'birth_date', up.birth_date,
    'birth_date_set', up.birth_date is not null,
    'eligibility_status', up.eligibility_status,
    'interests', coalesce((
      select jsonb_agg(i.slug order by i.sort_order)
      from public.user_interests ui
      join public.interests i on i.id = ui.interest_id
      where ui.user_id = v_user
    ), '[]'::jsonb),
    'username_next_change_at', case
      when p.username_changed_at is null then null
      else p.username_changed_at + make_interval(days => cfg.username_change_days)
    end
  ) into v_result
  from public.profiles p
  join private.user_private up on up.user_id = p.user_id
  cross join public.app_config cfg
  where p.user_id = v_user and cfg.id = 1;

  return v_result;
end;
$$;

revoke execute on function public.get_my_onboarding_state() from public, anon;
grant execute on function public.get_my_onboarding_state() to authenticated;

-- RLS + grants: client can READ safe public data, but writes happen through constrained RPCs.
alter table public.app_config enable row level security;
alter table public.profiles enable row level security;
alter table public.interests enable row level security;
alter table public.user_interests enable row level security;

revoke all on table public.app_config from anon, authenticated;
revoke all on table public.profiles from anon, authenticated;
revoke all on table public.interests from anon, authenticated;
revoke all on table public.user_interests from anon, authenticated;

grant select on table public.app_config to authenticated;
grant select on table public.profiles to authenticated;
grant select on table public.interests to authenticated;

drop policy if exists "authenticated can read app config" on public.app_config;
drop policy if exists "authenticated can read completed profiles or own profile" on public.profiles;
drop policy if exists "authenticated can read active interests" on public.interests;

create policy "authenticated can read app config"
on public.app_config for select
to authenticated
using (true);

create policy "authenticated can read completed profiles or own profile"
on public.profiles for select
to authenticated
using ((select auth.uid()) = user_id or onboarding_complete = true);

create policy "authenticated can read active interests"
on public.interests for select
to authenticated
using (active = true);

-- No direct client policies/grants for user_interests. Mutations and own-state reads go through RPCs.

commit;
