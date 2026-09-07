-- VYBE V7 — VYBE HQ / Admin control plane
-- Apply after 001..005.
-- Privileged writes are audited and exposed only through role-checked SECURITY DEFINER RPCs.

begin;

-- ---------------------------------------------------------------------------
-- ADMIN IDENTITY + AUDIT
-- ---------------------------------------------------------------------------
create table if not exists private.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'moderator' check (role in ('super_admin','admin','moderator','analyst')),
  active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists private.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text,
  target_id text,
  before_data jsonb,
  after_data jsonb,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists admin_audit_created_idx on private.admin_audit_log(created_at desc);
create index if not exists admin_audit_admin_idx on private.admin_audit_log(admin_id,created_at desc);

create or replace function private.admin_role(p_user uuid default auth.uid())
returns text language sql stable security definer set search_path='' as $$
  select au.role from private.admin_users au where au.user_id=p_user and au.active=true;
$$;
revoke execute on function private.admin_role(uuid) from public,anon,authenticated;

create or replace function private.require_admin(p_roles text[] default array['super_admin','admin','moderator','analyst'])
returns text language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_role text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select au.role into v_role from private.admin_users au where au.user_id=v_user and au.active=true;
  if v_role is null or not (v_role=any(p_roles)) then raise exception 'Admin permission required'; end if;
  return v_role;
end; $$;
revoke execute on function private.require_admin(text[]) from public,anon,authenticated;

create or replace function private.audit_admin(
  p_action text,p_target_type text default null,p_target_id text default null,
  p_before jsonb default null,p_after jsonb default null,p_reason text default null,p_metadata jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path='' as $$
begin
  insert into private.admin_audit_log(admin_id,action,target_type,target_id,before_data,after_data,reason,metadata)
  values(auth.uid(),left(p_action,120),left(p_target_type,80),left(p_target_id,160),p_before,p_after,left(p_reason,500),coalesce(p_metadata,'{}'::jsonb));
end; $$;
revoke execute on function private.audit_admin(text,text,text,jsonb,jsonb,text,jsonb) from public,anon,authenticated;

create or replace function public.is_vybe_admin()
returns boolean language sql stable security definer set search_path='' as $$
  select private.admin_role(auth.uid()) is not null;
$$;
revoke execute on function public.is_vybe_admin() from public,anon;
grant execute on function public.is_vybe_admin() to authenticated;

create or replace function public.admin_get_session()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text;
begin
  v_role:=private.require_admin();
  return jsonb_build_object(
    'is_admin',true,'role',v_role,
    'can_manage_users',v_role in ('super_admin','admin','moderator'),
    'can_manage_config',v_role in ('super_admin','admin'),
    'can_manage_admins',v_role='super_admin',
    'can_view_analytics',true,
    'can_moderate',v_role in ('super_admin','admin','moderator')
  );
end; $$;
revoke execute on function public.admin_get_session() from public,anon;
grant execute on function public.admin_get_session() to authenticated;

-- ---------------------------------------------------------------------------
-- ACCOUNT CONTROL. Suspensions are checked by core membership/age helpers.
-- ---------------------------------------------------------------------------
create table if not exists private.user_account_controls (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'active' check(status in ('active','suspended','banned')),
  reason text,
  suspended_until timestamptz,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into private.user_account_controls(user_id)
select p.user_id from public.profiles p
on conflict(user_id) do nothing;

create or replace function private.account_is_active(p_user uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce((
    select case
      when c.status='active' then true
      when c.status='suspended' and c.suspended_until is not null and c.suspended_until<=now() then true
      else false end
    from private.user_account_controls c where c.user_id=p_user
  ),true);
$$;
revoke execute on function private.account_is_active(uuid) from public,anon,authenticated;


-- Safe current-user wrapper for RLS. Browser roles never receive EXECUTE on
-- private.account_is_active(uuid).
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

-- Automatically provision account-control state for future auth users.
create or replace function private.ensure_account_control()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  insert into private.user_account_controls(user_id) values(new.id) on conflict do nothing;
  return new;
end; $$;
drop trigger if exists vybe_account_control_on_auth_user on auth.users;
create trigger vybe_account_control_on_auth_user after insert on auth.users
for each row execute function private.ensure_account_control();

-- ---------------------------------------------------------------------------
-- AGE SAFETY BANDS ARE NOW DB-DRIVEN / HQ-EDITABLE.
-- ---------------------------------------------------------------------------
create table if not exists public.age_safety_bands (
  id bigint generated always as identity primary key,
  slug text not null unique check(slug ~ '^[a-z0-9_]{2,40}$'),
  label text not null check(char_length(label) between 1 and 50),
  min_age integer not null check(min_age between 0 and 120),
  max_age integer not null check(max_age between 0 and 120 and max_age>=min_age),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into public.age_safety_bands(slug,label,min_age,max_age,sort_order) values
 ('age_10_12','10–12',10,12,10),('age_13_17','13–17',13,17,20),('age_18_plus','18+',18,120,30)
on conflict(slug) do update set label=excluded.label,min_age=excluded.min_age,max_age=excluded.max_age,sort_order=excluded.sort_order,active=true;

alter table public.age_safety_bands enable row level security;
revoke all on public.age_safety_bands from anon,authenticated;
grant select on public.age_safety_bands to authenticated;
drop policy if exists "authenticated read age bands" on public.age_safety_bands;
create policy "authenticated read age bands" on public.age_safety_bands for select to authenticated using(active=true);

create or replace function private.user_age(p_user uuid)
returns integer language sql stable security definer set search_path='' as $$
  select case when up.birth_date is null or not private.account_is_active(p_user) then null
    else extract(year from age(current_date,up.birth_date))::integer end
  from private.user_private up where up.user_id=p_user and up.eligibility_status='eligible';
$$;
revoke execute on function private.user_age(uuid) from public,anon,authenticated;

create or replace function private.user_age_band(p_user uuid)
returns text language plpgsql stable security definer set search_path='' as $$
declare v_age integer; v_slug text;
begin
  if not private.account_is_active(p_user) then return null; end if;
  v_age:=private.user_age(p_user);
  if v_age is null then return null; end if;
  select b.slug into v_slug from public.age_safety_bands b
  where b.active=true and v_age between b.min_age and b.max_age
  order by b.sort_order,b.min_age limit 1;
  return v_slug;
end; $$;
revoke execute on function private.user_age_band(uuid) from public,anon,authenticated;

create or replace function private.age_compatible(p_a uuid,p_b uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select private.account_is_active(p_a) and private.account_is_active(p_b)
    and private.user_age_band(p_a) is not null
    and private.user_age_band(p_a)=private.user_age_band(p_b);
$$;
revoke execute on function private.age_compatible(uuid,uuid) from public,anon,authenticated;


-- Recreate safe public wrappers after HQ replaces the private age helpers.
create or replace function public.current_user_age_band()
returns text language sql stable security definer set search_path='' as $$
  select case when auth.uid() is null then null else private.user_age_band(auth.uid()) end;
$$;
revoke execute on function public.current_user_age_band() from public,anon;
grant execute on function public.current_user_age_band() to authenticated;

create or replace function public.current_user_age_compatible(p_other uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select auth.uid() is not null and p_other is not null and private.age_compatible(auth.uid(),p_other);
$$;
revoke execute on function public.current_user_age_compatible(uuid) from public,anon;
grant execute on function public.current_user_age_compatible(uuid) to authenticated;

create or replace function public.chat_is_member(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select private.account_is_active(auth.uid()) and exists(
    select 1 from public.conversation_members cm
    where cm.conversation_id=p_conversation_id and cm.user_id=auth.uid() and cm.status='active'
  );
$$;
revoke execute on function public.chat_is_member(uuid) from public,anon;
grant execute on function public.chat_is_member(uuid) to authenticated;

create or replace function public.room_is_member(p_room uuid,p_include_invited boolean default true)
returns boolean language sql stable security definer set search_path='' as $$
  select private.account_is_active(auth.uid()) and exists(
    select 1 from public.room_members rm
    where rm.room_id=p_room and rm.user_id=auth.uid()
      and (rm.status='active' or (p_include_invited and rm.status='invited'))
  );
$$;
revoke execute on function public.room_is_member(uuid,boolean) from public,anon;
grant execute on function public.room_is_member(uuid,boolean) to authenticated;

-- Restrictive account-state policy for direct table access. SECURITY DEFINER RPCs use helpers above.
do $$
declare r record;
begin
  for r in select * from (values
    ('profiles'),('user_interests'),('aura_targets'),('conversations'),('conversation_members'),('messages'),('message_reactions'),
    ('user_blocks'),('rooms'),('room_members'),('game_sessions'),('game_rounds'),('game_results'),('room_events'),
    ('connections'),('bonds'),('meet_requests'),('meet_sessions'),('meet_messages'),('meet_decisions')
  ) v(tbl)
  loop
    execute format('drop policy if exists "active account required" on public.%I',r.tbl);
    execute format('create policy "active account required" on public.%I as restrictive for all to authenticated using(public.current_account_is_active()) with check(public.current_account_is_active())',r.tbl);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- FEATURE FLAGS / ANNOUNCEMENTS / SHOP SCAFFOLD
-- ---------------------------------------------------------------------------
create table if not exists public.feature_flags (
  key text primary key check(key ~ '^[a-z0-9_]{2,80}$'),
  label text not null,
  description text not null default '',
  enabled boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into public.feature_flags(key,label,description,enabled) values
 ('public_rooms','Public Rooms','Allow public Room discovery',false),
 ('voice_rooms','Voice Rooms','Enable live voice in Rooms',false),
 ('aura_board','Aura Board','Show Aura leaderboards',true),
 ('rising_feed','Rising Feed','Show new moments before FYP promotion',true),
 ('meet','Meet','Enable stranger Meet discovery',true),
 ('shop','VYBE Shop','Show cosmetics shop',false),
 ('vybe_plus','VYBE+','Show premium subscription surfaces',false)
on conflict(key) do nothing;

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check(char_length(title) between 1 and 100),
  body text not null check(char_length(body) between 1 and 500),
  cta_label text,
  cta_url text,
  audience text not null default 'all' check(audience in ('all','10_12','13_17','18_plus')),
  active boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.monetization_config (
  id smallint primary key default 1 check(id=1),
  vybe_plus_enabled boolean not null default false,
  vybe_plus_price_cents integer not null default 399 check(vybe_plus_price_cents between 0 and 100000),
  currency text not null default 'USD' check(char_length(currency)=3),
  ads_enabled boolean not null default false,
  feed_ad_interval integer not null default 12 check(feed_ad_interval between 3 and 100),
  gifting_enabled boolean not null default false,
  creator_marketplace_enabled boolean not null default false,
  sponsored_rooms_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
insert into public.monetization_config(id) values(1) on conflict(id) do nothing;

create table if not exists public.shop_items (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check(slug ~ '^[a-z0-9_]{2,80}$'),
  name text not null check(char_length(name) between 1 and 80),
  category text not null default 'profile' check(category in ('profile','aura_effect','room_theme','avatar_frame','game_pack')),
  description text not null default '',
  price_cents integer not null default 0 check(price_cents>=0),
  currency text not null default 'USD' check(char_length(currency)=3),
  asset_url text,
  metadata jsonb not null default '{}'::jsonb,
  active boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.feature_flags enable row level security;
alter table public.announcements enable row level security;
alter table public.shop_items enable row level security;
alter table public.monetization_config enable row level security;
revoke all on public.feature_flags,public.announcements,public.shop_items,public.monetization_config from anon,authenticated;
grant select on public.feature_flags,public.announcements,public.shop_items,public.monetization_config to authenticated;

drop policy if exists "read feature flags" on public.feature_flags;
create policy "read feature flags" on public.feature_flags for select to authenticated using(true);
drop policy if exists "read live announcements" on public.announcements;
create policy "read live announcements" on public.announcements for select to authenticated using(active=true and starts_at<=now() and (ends_at is null or ends_at>now()));
drop policy if exists "read active shop items" on public.shop_items;
create policy "read active shop items" on public.shop_items for select to authenticated using(active=true);
drop policy if exists "read monetization config" on public.monetization_config;
create policy "read monetization config" on public.monetization_config for select to authenticated using(true);

-- ---------------------------------------------------------------------------
-- ADMIN DASHBOARD / USERS
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_dashboard()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_out jsonb;
begin
  v_role:=private.require_admin();
  select jsonb_build_object(
    'role',v_role,
    'users_total',(select count(*) from public.profiles),
    'users_24h',(select count(*) from public.profiles where created_at>=now()-interval '24 hours'),
    'onboarded',(select count(*) from public.profiles where onboarding_complete=true),
    'suspended',(select count(*) from private.user_account_controls where status='suspended' and (suspended_until is null or suspended_until>now())),
    'banned',(select count(*) from private.user_account_controls where status='banned'),
    'messages_24h',(select count(*) from public.messages where created_at>=now()-interval '24 hours'),
    'aura_24h',(select coalesce(sum(amount),0) from public.aura_events where created_at>=now()-interval '24 hours' and status='counted'),
    'rooms_24h',(select count(*) from public.rooms where created_at>=now()-interval '24 hours'),
    'games_24h',(select count(*) from public.game_sessions where started_at>=now()-interval '24 hours'),
    'meet_requests_24h',(select count(*) from public.meet_requests where created_at>=now()-interval '24 hours'),
    'connections_total',(select count(*) from public.connections where status='active'),
    'pending_reports',(select count(*) from private.safety_reports where status in ('pending','reviewing')),
    'active_flags',(select count(*) from public.feature_flags where enabled=true),
    'generated_at',now()
  ) into v_out;
  return v_out;
end; $$;
revoke execute on function public.admin_get_dashboard() from public,anon;
grant execute on function public.admin_get_dashboard() to authenticated;

create or replace function public.admin_list_users(
  p_query text default '',p_status text default 'all',p_limit integer default 50,p_offset integer default 0
) returns table(
  user_id uuid,username text,display_name text,email text,aura_total bigint,rank jsonb,
  onboarding_complete boolean,age integer,age_band text,eligibility_status text,account_status text,
  suspended_until timestamptz,created_at timestamptz,last_sign_in_at timestamptz,report_count bigint
) language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_limit integer:=least(greatest(coalesce(p_limit,50),1),100); v_q text:='%'||lower(trim(coalesce(p_query,'')))||'%';
begin
  v_role:=private.require_admin(array['super_admin','admin','moderator','analyst']);
  return query
  select p.user_id,p.username,p.display_name,
    case when v_role in ('super_admin','admin','moderator') then u.email else case when u.email is null then '' else left(u.email,1)||'***@'||split_part(u.email,'@',2) end end,
    p.aura_total,public.get_aura_rank(p.aura_total),p.onboarding_complete,private.user_age(p.user_id),private.user_age_band(p.user_id),
    up.eligibility_status,coalesce(c.status,'active'),c.suspended_until,p.created_at,u.last_sign_in_at,
    (select count(*) from private.safety_reports sr where sr.reported_user_id=p.user_id)
  from public.profiles p
  join auth.users u on u.id=p.user_id
  left join private.user_private up on up.user_id=p.user_id
  left join private.user_account_controls c on c.user_id=p.user_id
  where (trim(coalesce(p_query,''))='' or lower(coalesce(p.username,'')) like v_q or lower(coalesce(p.display_name,'')) like v_q or lower(coalesce(u.email,'')) like v_q)
    and (p_status='all' or coalesce(c.status,'active')=p_status)
  order by p.created_at desc limit v_limit offset greatest(coalesce(p_offset,0),0);
end; $$;
revoke execute on function public.admin_list_users(text,text,integer,integer) from public,anon;
grant execute on function public.admin_list_users(text,text,integer,integer) to authenticated;

create or replace function public.admin_get_user(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_out jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin','moderator']);
  select jsonb_build_object(
    'user_id',p.user_id,'username',p.username,'display_name',p.display_name,'bio',p.bio,'avatar_url',p.avatar_url,
    'email',u.email,'email_confirmed_at',u.email_confirmed_at,'last_sign_in_at',u.last_sign_in_at,'created_at',p.created_at,
    'aura_total',p.aura_total,'rank',public.get_aura_rank(p.aura_total),'onboarding_complete',p.onboarding_complete,
    'birth_date',case when v_role in ('super_admin','admin') then up.birth_date else null end,
    'age',private.user_age(p.user_id),'age_band',private.user_age_band(p.user_id),'eligibility_status',up.eligibility_status,
    'account_status',coalesce(c.status,'active'),'status_reason',c.reason,'suspended_until',c.suspended_until,
    'reports',(select count(*) from private.safety_reports sr where sr.reported_user_id=p.user_id),
    'messages',(select count(*) from public.messages m where m.sender_id=p.user_id),
    'room_wins',(select count(*) from public.game_results gr where gr.user_id=p.user_id and gr.is_winner=true),
    'connections',(select count(*) from public.connections cn where cn.status='active' and p.user_id in(cn.user_low,cn.user_high))
  ) into v_out
  from public.profiles p join auth.users u on u.id=p.user_id
  left join private.user_private up on up.user_id=p.user_id
  left join private.user_account_controls c on c.user_id=p.user_id
  where p.user_id=p_user;
  if v_out is null then raise exception 'User unavailable'; end if;
  return v_out;
end; $$;
revoke execute on function public.admin_get_user(uuid) from public,anon;
grant execute on function public.admin_get_user(uuid) to authenticated;

create or replace function public.admin_set_user_status(p_user uuid,p_status text,p_reason text,p_until timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin','moderator']);
  if p_status not in ('active','suspended','banned') then raise exception 'Invalid status'; end if;
  if p_status<>'active' and char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason required'; end if;
  if p_user=auth.uid() and p_status<>'active' then raise exception 'You cannot restrict your own admin account'; end if;
  if v_role='moderator' and p_status='banned' then raise exception 'Moderators can suspend users but cannot permanently ban them'; end if;
  if exists(select 1 from private.admin_users where user_id=p_user and active=true) and v_role<>'super_admin' then raise exception 'Only super admin can restrict another admin'; end if;
  select to_jsonb(c) into v_before from private.user_account_controls c where c.user_id=p_user;
  insert into private.user_account_controls(user_id,status,reason,suspended_until,updated_by,updated_at)
  values(p_user,p_status,nullif(trim(p_reason),''),case when p_status='suspended' then p_until else null end,auth.uid(),now())
  on conflict(user_id) do update set status=excluded.status,reason=excluded.reason,suspended_until=excluded.suspended_until,updated_by=auth.uid(),updated_at=now();
  select to_jsonb(c) into v_after from private.user_account_controls c where c.user_id=p_user;
  perform private.audit_admin('user_status', 'user',p_user::text,v_before,v_after,p_reason);
  return jsonb_build_object('ok',true,'status',p_status,'suspended_until',p_until);
end; $$;
revoke execute on function public.admin_set_user_status(uuid,text,text,timestamptz) from public,anon;
grant execute on function public.admin_set_user_status(uuid,text,text,timestamptz) to authenticated;

create or replace function public.admin_change_username(p_user uuid,p_username text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_norm text:=lower(trim(coalesce(p_username,''))); v_old text; v_old_norm text; v_reserve integer; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if v_norm !~ '^[a-z0-9_]{3,20}$' then raise exception 'Username must be 3-20 letters, numbers, or underscores'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason required'; end if;
  if exists(select 1 from private.reserved_usernames r where r.username_normalized=v_norm) then raise exception 'Username is reserved'; end if;
  if exists(select 1 from public.profiles p where p.username_normalized=v_norm and p.user_id<>p_user) then raise exception 'Username already taken'; end if;
  if exists(select 1 from private.username_reservations ur where ur.username_normalized=v_norm and ur.release_at>now() and ur.reserved_for<>p_user) then raise exception 'Username is temporarily protected'; end if;
  select username,username_normalized into v_old,v_old_norm from public.profiles where user_id=p_user for update;
  if v_old_norm is null then raise exception 'Profile unavailable'; end if;
  v_before:=jsonb_build_object('username',v_old);
  select old_username_reserve_days into v_reserve from public.app_config where id=1;
  if v_old_norm<>v_norm then
    insert into private.username_history(user_id,old_username,new_username,changed_by,source)
      values(p_user,v_old,v_norm,auth.uid(),'admin');
    if v_reserve>0 then
      insert into private.username_reservations(username_normalized,reserved_for,release_at,reason)
      values(v_old_norm,p_user,now()+make_interval(days=>v_reserve),'previous_username')
      on conflict(username_normalized) do update set reserved_for=excluded.reserved_for,release_at=excluded.release_at,reason=excluded.reason;
    end if;
  end if;
  update public.profiles set username=v_norm,username_normalized=v_norm,username_changed_at=now(),updated_at=now() where user_id=p_user;
  v_after:=jsonb_build_object('username',v_norm);
  perform private.audit_admin('username_change','user',p_user::text,v_before,v_after,p_reason);
  return jsonb_build_object('ok',true,'username',v_norm);
end; $$;
revoke execute on function public.admin_change_username(uuid,text,text) from public,anon;
grant execute on function public.admin_change_username(uuid,text,text) to authenticated;

create or replace function public.admin_correct_birth_date(p_user uuid,p_birth_date date,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_before jsonb; v_after jsonb; v_age integer; v_min integer; v_eligible boolean;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if p_birth_date is null or p_birth_date>current_date or p_birth_date<current_date-interval '120 years' then raise exception 'Invalid birth date'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason required'; end if;
  select to_jsonb(up) into v_before from private.user_private up where up.user_id=p_user;
  select min_age into v_min from public.app_config where id=1;
  v_age:=extract(year from age(current_date,p_birth_date)); v_eligible:=v_age>=v_min;
  insert into private.user_private(user_id,birth_date,eligibility_status,eligibility_checked_at,updated_at)
  values(p_user,p_birth_date,case when v_eligible then 'eligible' else 'ineligible' end,now(),now())
  on conflict(user_id) do update set birth_date=excluded.birth_date,eligibility_status=excluded.eligibility_status,eligibility_checked_at=now(),updated_at=now();
  if not v_eligible then update public.profiles set onboarding_complete=false,updated_at=now() where user_id=p_user; end if;
  select to_jsonb(up) into v_after from private.user_private up where up.user_id=p_user;
  perform private.audit_admin('birth_date_correction','user',p_user::text,v_before,v_after,p_reason);
  return jsonb_build_object('ok',true,'age',v_age,'eligible',v_eligible,'age_band',private.user_age_band(p_user));
end; $$;
revoke execute on function public.admin_correct_birth_date(uuid,date,text) from public,anon;
grant execute on function public.admin_correct_birth_date(uuid,date,text) to authenticated;

create or replace function public.admin_adjust_user_aura(p_user uuid,p_amount integer,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_before bigint; v_after bigint; v_effective integer;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if p_amount=0 or p_amount not between -10000 and 10000 then raise exception 'Adjustment must be between -10000 and 10000'; end if;
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Reason required'; end if;
  select aura_total into v_before from public.profiles where user_id=p_user for update;
  if v_before is null then raise exception 'Profile unavailable'; end if;
  v_effective:=greatest((1-v_before)::integer,p_amount);
  insert into public.aura_events(giver_id,receiver_id,target_id,amount,source,status,metadata)
  values(null,p_user,null,v_effective,case when v_effective<0 then 'reversal' else 'admin_adjustment' end,'counted',jsonb_build_object('reason',left(trim(p_reason),240),'admin_id',auth.uid(),'hq',true));
  update public.profiles set aura_total=greatest(1,aura_total+v_effective),updated_at=now() where user_id=p_user returning aura_total into v_after;
  perform private.audit_admin('aura_adjustment','user',p_user::text,jsonb_build_object('aura',v_before),jsonb_build_object('aura',v_after),p_reason,jsonb_build_object('amount',v_effective));
  return jsonb_build_object('ok',true,'amount',v_effective,'aura_total',v_after,'rank',public.get_aura_rank(v_after));
end; $$;
revoke execute on function public.admin_adjust_user_aura(uuid,integer,text) from public,anon;
grant execute on function public.admin_adjust_user_aura(uuid,integer,text) to authenticated;

-- ---------------------------------------------------------------------------
-- CONFIG CONTROL
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_control_center()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text;
begin
  v_role:=private.require_admin();
  return jsonb_build_object(
    'app',(select to_jsonb(c) from public.app_config c where id=1),
    'aura',(select to_jsonb(c) from public.aura_config c where id=1),
    'chat',(select to_jsonb(c) from public.chat_config c where id=1),
    'rooms',(select to_jsonb(c) from public.room_config c where id=1),
    'social',(select to_jsonb(c) from public.social_config c where id=1),
    'ranks',(select coalesce(jsonb_agg(to_jsonb(r) order by r.min_aura),'[]'::jsonb) from public.aura_ranks r),
    'age_bands',(select coalesce(jsonb_agg(to_jsonb(b) order by b.sort_order),'[]'::jsonb) from public.age_safety_bands b),
    'interests',(select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order),'[]'::jsonb) from public.interests i),
    'flags',(select coalesce(jsonb_agg(to_jsonb(f) order by f.key),'[]'::jsonb) from public.feature_flags f),
    'monetization',(select to_jsonb(m) from public.monetization_config m where id=1)
  );
end; $$;
revoke execute on function public.admin_get_control_center() from public,anon;
grant execute on function public.admin_get_control_center() to authenticated;

create or replace function public.admin_update_config(p_section text,p_patch jsonb,p_reason text default 'HQ config update')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if p_patch is null or jsonb_typeof(p_patch)<>'object' then raise exception 'Patch object required'; end if;
  if p_section='app' then
    select to_jsonb(c) into v_before from public.app_config c where id=1;
    update public.app_config set
      min_age=coalesce((p_patch->>'min_age')::integer,min_age),
      username_change_days=coalesce((p_patch->>'username_change_days')::integer,username_change_days),
      old_username_reserve_days=coalesce((p_patch->>'old_username_reserve_days')::integer,old_username_reserve_days),
      min_interests=coalesce((p_patch->>'min_interests')::integer,min_interests),updated_at=now() where id=1;
    update private.user_private up set
      eligibility_status=case when up.birth_date is null then 'pending' when extract(year from age(current_date,up.birth_date))::integer >= (select min_age from public.app_config where id=1) then 'eligible' else 'ineligible' end,
      eligibility_checked_at=case when up.birth_date is null then up.eligibility_checked_at else now() end,
      updated_at=now();
    update public.profiles p set onboarding_complete=false,updated_at=now()
      where exists(select 1 from private.user_private up where up.user_id=p.user_id and up.eligibility_status='ineligible');
    select to_jsonb(c) into v_after from public.app_config c where id=1;
  elsif p_section='aura' then
    select to_jsonb(c) into v_before from public.aura_config c where id=1;
    update public.aura_config set
      daily_giver_limit=coalesce((p_patch->>'daily_giver_limit')::integer,daily_giver_limit),daily_pair_limit=coalesce((p_patch->>'daily_pair_limit')::integer,daily_pair_limit),
      daily_pair_combined_limit=coalesce((p_patch->>'daily_pair_combined_limit')::integer,daily_pair_combined_limit),new_account_hours=coalesce((p_patch->>'new_account_hours')::integer,new_account_hours),
      new_account_daily_limit=coalesce((p_patch->>'new_account_daily_limit')::integer,new_account_daily_limit),aura_moment_threshold=coalesce((p_patch->>'aura_moment_threshold')::integer,aura_moment_threshold),
      fyp_min_aura=coalesce((p_patch->>'fyp_min_aura')::integer,fyp_min_aura),fyp_min_unique_givers=coalesce((p_patch->>'fyp_min_unique_givers')::integer,fyp_min_unique_givers),
      fyp_max_age_hours=coalesce((p_patch->>'fyp_max_age_hours')::integer,fyp_max_age_hours),weight_velocity=coalesce((p_patch->>'weight_velocity')::numeric,weight_velocity),
      weight_unique_givers=coalesce((p_patch->>'weight_unique_givers')::numeric,weight_unique_givers),weight_total_aura=coalesce((p_patch->>'weight_total_aura')::numeric,weight_total_aura),
      weight_freshness=coalesce((p_patch->>'weight_freshness')::numeric,weight_freshness),updated_at=now() where id=1;
    select to_jsonb(c) into v_after from public.aura_config c where id=1;
  elsif p_section='chat' then
    select to_jsonb(c) into v_before from public.chat_config c where id=1;
    update public.chat_config set max_message_chars=coalesce((p_patch->>'max_message_chars')::integer,max_message_chars),max_group_members=coalesce((p_patch->>'max_group_members')::integer,max_group_members),
      message_per_minute_limit=coalesce((p_patch->>'message_per_minute_limit')::integer,message_per_minute_limit),new_account_message_per_minute_limit=coalesce((p_patch->>'new_account_message_per_minute_limit')::integer,new_account_message_per_minute_limit),
      direct_chat_create_hour_limit=coalesce((p_patch->>'direct_chat_create_hour_limit')::integer,direct_chat_create_hour_limit),group_create_day_limit=coalesce((p_patch->>'group_create_day_limit')::integer,group_create_day_limit),updated_at=now() where id=1;
    select to_jsonb(c) into v_after from public.chat_config c where id=1;
  elsif p_section='rooms' then
    select to_jsonb(c) into v_before from public.room_config c where id=1;
    update public.room_config set max_players=coalesce((p_patch->>'max_players')::integer,max_players),min_players=coalesce((p_patch->>'min_players')::integer,min_players),
      room_expiry_minutes=coalesce((p_patch->>'room_expiry_minutes')::integer,room_expiry_minutes),round_seconds=coalesce((p_patch->>'round_seconds')::integer,round_seconds),rounds_per_game=coalesce((p_patch->>'rounds_per_game')::integer,rounds_per_game),
      winner_aura=coalesce((p_patch->>'winner_aura')::integer,winner_aura),mvp_aura=coalesce((p_patch->>'mvp_aura')::integer,mvp_aura),winner_xp=coalesce((p_patch->>'winner_xp')::integer,winner_xp),participation_xp=coalesce((p_patch->>'participation_xp')::integer,participation_xp),updated_at=now() where id=1;
    select to_jsonb(c) into v_after from public.room_config c where id=1;
  elsif p_section='social' then
    select to_jsonb(c) into v_before from public.social_config c where id=1;
    update public.social_config set meet_session_minutes=coalesce((p_patch->>'meet_session_minutes')::integer,meet_session_minutes),meet_request_day_limit=coalesce((p_patch->>'meet_request_day_limit')::integer,meet_request_day_limit),
      meet_message_per_minute_limit=coalesce((p_patch->>'meet_message_per_minute_limit')::integer,meet_message_per_minute_limit),meet_max_messages_per_session=coalesce((p_patch->>'meet_max_messages_per_session')::integer,meet_max_messages_per_session),
      bond_message_points=coalesce((p_patch->>'bond_message_points')::integer,bond_message_points),bond_message_daily_cap=coalesce((p_patch->>'bond_message_daily_cap')::integer,bond_message_daily_cap),
      bond_aura_points=coalesce((p_patch->>'bond_aura_points')::integer,bond_aura_points),bond_aura_daily_cap=coalesce((p_patch->>'bond_aura_daily_cap')::integer,bond_aura_daily_cap),
      bond_shared_game_points=coalesce((p_patch->>'bond_shared_game_points')::integer,bond_shared_game_points),updated_at=now() where id=1;
    select to_jsonb(c) into v_after from public.social_config c where id=1;
  elsif p_section='money' then
    select to_jsonb(c) into v_before from public.monetization_config c where id=1;
    update public.monetization_config set
      vybe_plus_enabled=coalesce((p_patch->>'vybe_plus_enabled')::boolean,vybe_plus_enabled),
      vybe_plus_price_cents=coalesce((p_patch->>'vybe_plus_price_cents')::integer,vybe_plus_price_cents),
      currency=coalesce(upper(p_patch->>'currency'),currency),ads_enabled=coalesce((p_patch->>'ads_enabled')::boolean,ads_enabled),
      feed_ad_interval=coalesce((p_patch->>'feed_ad_interval')::integer,feed_ad_interval),gifting_enabled=coalesce((p_patch->>'gifting_enabled')::boolean,gifting_enabled),
      creator_marketplace_enabled=coalesce((p_patch->>'creator_marketplace_enabled')::boolean,creator_marketplace_enabled),sponsored_rooms_enabled=coalesce((p_patch->>'sponsored_rooms_enabled')::boolean,sponsored_rooms_enabled),updated_at=now() where id=1;
    select to_jsonb(c) into v_after from public.monetization_config c where id=1;
  else raise exception 'Unknown config section';
  end if;
  perform private.audit_admin('config_update',p_section,'1',v_before,v_after,p_reason,p_patch);
  return v_after;
end; $$;
revoke execute on function public.admin_update_config(text,jsonb,text) from public,anon;
grant execute on function public.admin_update_config(text,jsonb,text) to authenticated;

create or replace function public.admin_upsert_rank(p_id bigint,p_slug text,p_name text,p_min_aura bigint,p_badge text,p_active boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_id bigint; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if p_min_aura<1 then raise exception 'Minimum Aura must be at least 1'; end if;
  if p_id is not null then select to_jsonb(r) into v_before from public.aura_ranks r where r.id=p_id; end if;
  if p_id is null then
    insert into public.aura_ranks(slug,name,min_aura,badge,sort_order,active) values(lower(trim(p_slug)),trim(p_name),p_min_aura,coalesce(nullif(trim(p_badge),''),'⚡'),p_min_aura::integer,p_active) returning id into v_id;
  else
    update public.aura_ranks set slug=lower(trim(p_slug)),name=trim(p_name),min_aura=p_min_aura,badge=coalesce(nullif(trim(p_badge),''),'⚡'),active=p_active,sort_order=p_min_aura::integer,updated_at=now() where id=p_id returning id into v_id;
  end if;
  select to_jsonb(r) into v_after from public.aura_ranks r where r.id=v_id;
  perform private.audit_admin('rank_upsert','aura_rank',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_rank(bigint,text,text,bigint,text,boolean,text) from public,anon;
grant execute on function public.admin_upsert_rank(bigint,text,text,bigint,text,boolean,text) to authenticated;

create or replace function public.admin_upsert_age_band(p_id bigint,p_slug text,p_label text,p_min integer,p_max integer,p_active boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_id bigint; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if p_min<0 or p_max>120 or p_min>p_max then raise exception 'Invalid age range'; end if;
  if p_active and exists(select 1 from public.age_safety_bands b where b.active=true and b.id is distinct from p_id and int4range(b.min_age,b.max_age,'[]') && int4range(p_min,p_max,'[]')) then raise exception 'Age bands cannot overlap'; end if;
  if p_id is not null then select to_jsonb(b) into v_before from public.age_safety_bands b where b.id=p_id; end if;
  if p_id is null then insert into public.age_safety_bands(slug,label,min_age,max_age,active,sort_order) values(lower(trim(p_slug)),trim(p_label),p_min,p_max,p_active,p_min) returning id into v_id;
  else update public.age_safety_bands set slug=lower(trim(p_slug)),label=trim(p_label),min_age=p_min,max_age=p_max,active=p_active,sort_order=p_min,updated_at=now() where id=p_id returning id into v_id; end if;
  select to_jsonb(b) into v_after from public.age_safety_bands b where b.id=v_id;
  perform private.audit_admin('age_band_upsert','age_band',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_age_band(bigint,text,text,integer,integer,boolean,text) from public,anon;
grant execute on function public.admin_upsert_age_band(bigint,text,text,integer,integer,boolean,text) to authenticated;

create or replace function public.admin_upsert_interest(p_id bigint,p_slug text,p_label text,p_icon text,p_active boolean,p_sort integer,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_id bigint; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if p_id is not null then select to_jsonb(i) into v_before from public.interests i where i.id=p_id; end if;
  if p_id is null then insert into public.interests(slug,label,icon,active,sort_order) values(lower(trim(p_slug)),trim(p_label),coalesce(nullif(trim(p_icon),''),'✦'),p_active,coalesce(p_sort,0)) returning id into v_id;
  else update public.interests set slug=lower(trim(p_slug)),label=trim(p_label),icon=coalesce(nullif(trim(p_icon),''),'✦'),active=p_active,sort_order=coalesce(p_sort,sort_order) where id=p_id returning id into v_id; end if;
  select to_jsonb(i) into v_after from public.interests i where i.id=v_id;
  perform private.audit_admin('interest_upsert','interest',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_interest(bigint,text,text,text,boolean,integer,text) from public,anon;
grant execute on function public.admin_upsert_interest(bigint,text,text,text,boolean,integer,text) to authenticated;

create or replace function public.admin_set_feature_flag(p_key text,p_enabled boolean,p_payload jsonb default null,p_reason text default 'Feature flag update')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  select to_jsonb(f) into v_before from public.feature_flags f where f.key=p_key;
  if v_before is null then raise exception 'Unknown feature flag'; end if;
  update public.feature_flags set enabled=p_enabled,payload=coalesce(p_payload,payload),updated_at=now() where key=p_key;
  select to_jsonb(f) into v_after from public.feature_flags f where f.key=p_key;
  perform private.audit_admin('feature_flag','feature_flag',p_key,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_set_feature_flag(text,boolean,jsonb,text) from public,anon;
grant execute on function public.admin_set_feature_flag(text,boolean,jsonb,text) to authenticated;

-- Shop catalog is configuration only in V7; payment fulfillment remains a trusted-server concern.
create or replace function public.admin_list_shop_items()
returns setof public.shop_items language plpgsql stable security definer set search_path='' as $$
begin perform private.require_admin(array['super_admin','admin','analyst']); return query select * from public.shop_items order by sort_order,name; end; $$;
revoke execute on function public.admin_list_shop_items() from public,anon;
grant execute on function public.admin_list_shop_items() to authenticated;

create or replace function public.admin_upsert_shop_item(
  p_id uuid,p_slug text,p_name text,p_category text,p_description text,p_price_cents integer,p_currency text,p_asset_url text,p_active boolean,p_sort integer,p_reason text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if p_category not in('profile','aura_effect','room_theme','avatar_frame','game_pack') then raise exception 'Invalid shop category'; end if;
  if p_price_cents<0 then raise exception 'Invalid price'; end if;
  if p_id is not null then select to_jsonb(i) into v_before from public.shop_items i where i.id=p_id; end if;
  if p_id is null then insert into public.shop_items(slug,name,category,description,price_cents,currency,asset_url,active,sort_order)
    values(lower(trim(p_slug)),trim(p_name),p_category,trim(coalesce(p_description,'')),p_price_cents,upper(p_currency),nullif(trim(p_asset_url),''),p_active,coalesce(p_sort,0)) returning id into v_id;
  else update public.shop_items set slug=lower(trim(p_slug)),name=trim(p_name),category=p_category,description=trim(coalesce(p_description,'')),price_cents=p_price_cents,currency=upper(p_currency),asset_url=nullif(trim(p_asset_url),''),active=p_active,sort_order=coalesce(p_sort,sort_order),updated_at=now() where id=p_id returning id into v_id; end if;
  select to_jsonb(i) into v_after from public.shop_items i where i.id=v_id;
  perform private.audit_admin('shop_item_upsert','shop_item',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_shop_item(uuid,text,text,text,text,integer,text,text,boolean,integer,text) from public,anon;
grant execute on function public.admin_upsert_shop_item(uuid,text,text,text,text,integer,text,text,boolean,integer,text) to authenticated;

-- ---------------------------------------------------------------------------
-- MODERATION / CONTENT / ADMIN ROLES
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_reports(p_status text default 'open',p_limit integer default 50)
returns table(report_id uuid,status text,reason text,details text,created_at timestamptz,reporter jsonb,reported_user jsonb,message jsonb)
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_admin(array['super_admin','admin','moderator']);
  return query select sr.id,sr.status,sr.reason,sr.details,sr.created_at,
    jsonb_build_object('id',rp.user_id,'username',rp.username,'display_name',rp.display_name),
    case when tp.user_id is null then null else jsonb_build_object('id',tp.user_id,'username',tp.username,'display_name',tp.display_name,'aura',tp.aura_total) end,
    case when m.id is null then null else jsonb_build_object('id',m.id,'body',left(m.body,500),'conversation_id',m.conversation_id,'created_at',m.created_at) end
  from private.safety_reports sr
  left join public.profiles rp on rp.user_id=sr.reporter_id
  left join public.profiles tp on tp.user_id=sr.reported_user_id
  left join public.messages m on m.id=sr.message_id
  where (p_status='all' or (p_status='open' and sr.status in('pending','reviewing')) or sr.status=p_status)
  order by case sr.status when 'pending' then 0 when 'reviewing' then 1 else 2 end,sr.created_at desc
  limit least(greatest(coalesce(p_limit,50),1),100);
end; $$;
revoke execute on function public.admin_list_reports(text,integer) from public,anon;
grant execute on function public.admin_list_reports(text,integer) to authenticated;

create or replace function public.admin_update_report(p_report uuid,p_status text,p_note text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin','moderator']);
  if p_status not in('pending','reviewing','actioned','dismissed') then raise exception 'Invalid report status'; end if;
  select to_jsonb(r) into v_before from private.safety_reports r where r.id=p_report for update;
  if v_before is null then raise exception 'Report unavailable'; end if;
  update private.safety_reports set status=p_status where id=p_report;
  select to_jsonb(r) into v_after from private.safety_reports r where r.id=p_report;
  perform private.audit_admin('report_update','report',p_report::text,v_before,v_after,p_note);
  return v_after;
end; $$;
revoke execute on function public.admin_update_report(uuid,text,text) from public,anon;
grant execute on function public.admin_update_report(uuid,text,text) to authenticated;

create or replace function public.admin_create_announcement(p_title text,p_body text,p_audience text default 'all',p_starts timestamptz default now(),p_ends timestamptz default null,p_cta_label text default null,p_cta_url text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_id uuid; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  insert into public.announcements(title,body,audience,starts_at,ends_at,cta_label,cta_url,created_by)
  values(trim(p_title),trim(p_body),p_audience,coalesce(p_starts,now()),p_ends,nullif(trim(p_cta_label),''),nullif(trim(p_cta_url),''),auth.uid()) returning id into v_id;
  select to_jsonb(a) into v_after from public.announcements a where a.id=v_id;
  perform private.audit_admin('announcement_create','announcement',v_id::text,null,v_after,p_title);
  return v_after;
end; $$;
revoke execute on function public.admin_create_announcement(text,text,text,timestamptz,timestamptz,text,text) from public,anon;
grant execute on function public.admin_create_announcement(text,text,text,timestamptz,timestamptz,text,text) to authenticated;

create or replace function public.admin_list_announcements()
returns setof public.announcements language plpgsql stable security definer set search_path='' as $$
begin perform private.require_admin(); return query select * from public.announcements order by created_at desc limit 100; end; $$;
revoke execute on function public.admin_list_announcements() from public,anon;
grant execute on function public.admin_list_announcements() to authenticated;

create or replace function public.admin_list_audit(p_limit integer default 100)
returns table(id bigint,admin_id uuid,admin_username text,action text,target_type text,target_id text,reason text,metadata jsonb,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_admin(array['super_admin','admin','analyst']);
  return query select l.id,l.admin_id,p.username,l.action,l.target_type,l.target_id,l.reason,l.metadata,l.created_at
  from private.admin_audit_log l left join public.profiles p on p.user_id=l.admin_id order by l.created_at desc limit least(greatest(coalesce(p_limit,100),1),250);
end; $$;
revoke execute on function public.admin_list_audit(integer) from public,anon;
grant execute on function public.admin_list_audit(integer) to authenticated;

create or replace function public.admin_list_admins()
returns table(user_id uuid,username text,email text,role text,active boolean,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_admin(array['super_admin']);
  return query select a.user_id,p.username,u.email,a.role,a.active,a.created_at from private.admin_users a join auth.users u on u.id=a.user_id left join public.profiles p on p.user_id=a.user_id order by a.created_at;
end; $$;
revoke execute on function public.admin_list_admins() from public,anon;
grant execute on function public.admin_list_admins() to authenticated;

create or replace function public.admin_set_admin_role(p_user uuid,p_role text,p_active boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin']);
  if p_role not in('super_admin','admin','moderator','analyst') then raise exception 'Invalid admin role'; end if;
  if p_user=auth.uid() and p_active=false then raise exception 'Cannot disable your own super-admin access here'; end if;
  select to_jsonb(a) into v_before from private.admin_users a where a.user_id=p_user;
  insert into private.admin_users(user_id,role,active,created_by,updated_at) values(p_user,p_role,p_active,auth.uid(),now())
  on conflict(user_id) do update set role=excluded.role,active=excluded.active,updated_at=now();
  select to_jsonb(a) into v_after from private.admin_users a where a.user_id=p_user;
  perform private.audit_admin('admin_role','admin',p_user::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_set_admin_role(uuid,text,boolean,text) from public,anon;
grant execute on function public.admin_set_admin_role(uuid,text,boolean,text) to authenticated;

-- Question-bank control: answers remain private; only admin RPC returns them.
create or replace function public.admin_list_game_questions(p_game text default 'all')
returns table(id bigint,game_type text,prompt text,options jsonb,correct_answer text,active boolean)
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_admin(array['super_admin','admin']);
  return query select q.id,q.game_type,q.prompt,q.options,q.correct_answer,q.active from private.game_question_bank q where p_game='all' or q.game_type=p_game order by q.id desc limit 300;
end; $$;
revoke execute on function public.admin_list_game_questions(text) from public,anon;
grant execute on function public.admin_list_game_questions(text) to authenticated;

create or replace function public.admin_upsert_game_question(p_id bigint,p_game text,p_prompt text,p_options jsonb,p_correct text,p_active boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id bigint; v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if p_game not in('puzzle','trivia','most_likely') then raise exception 'Unknown game'; end if;
  if p_id is not null then select to_jsonb(q) into v_before from private.game_question_bank q where q.id=p_id; end if;
  if p_id is null then insert into private.game_question_bank(game_type,prompt,options,correct_answer,active) values(p_game,trim(p_prompt),coalesce(p_options,'[]'::jsonb),nullif(trim(p_correct),''),p_active) returning id into v_id;
  else update private.game_question_bank set game_type=p_game,prompt=trim(p_prompt),options=coalesce(p_options,'[]'::jsonb),correct_answer=nullif(trim(p_correct),''),active=p_active where id=p_id returning id into v_id; end if;
  select to_jsonb(q) into v_after from private.game_question_bank q where q.id=v_id;
  perform private.audit_admin('game_question_upsert','game_question',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_game_question(bigint,text,text,jsonb,text,boolean,text) from public,anon;
grant execute on function public.admin_upsert_game_question(bigint,text,text,jsonb,text,boolean,text) to authenticated;

-- Add updated_at triggers where useful.
drop trigger if exists feature_flags_touch on public.feature_flags;
create trigger feature_flags_touch before update on public.feature_flags for each row execute function public.touch_updated_at();
drop trigger if exists announcements_touch on public.announcements;
create trigger announcements_touch before update on public.announcements for each row execute function public.touch_updated_at();
drop trigger if exists monetization_touch on public.monetization_config;
create trigger monetization_touch before update on public.monetization_config for each row execute function public.touch_updated_at();
drop trigger if exists shop_items_touch on public.shop_items;
create trigger shop_items_touch before update on public.shop_items for each row execute function public.touch_updated_at();
drop trigger if exists age_bands_touch on public.age_safety_bands;
create trigger age_bands_touch before update on public.age_safety_bands for each row execute function public.touch_updated_at();


-- Expose effective account access to the authenticated user's route guard without exposing private controls.
create or replace function public.get_my_onboarding_state()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_result jsonb;
  v_access boolean;
  v_raw_status text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  insert into public.profiles(user_id) values(v_user) on conflict(user_id) do nothing;
  insert into private.user_private(user_id) values(v_user) on conflict(user_id) do nothing;
  insert into private.user_account_controls(user_id) values(v_user) on conflict(user_id) do nothing;

  v_access:=private.account_is_active(v_user);
  select status into v_raw_status from private.user_account_controls where user_id=v_user;

  select jsonb_build_object(
    'user_id',p.user_id,'username',p.username,'username_changed_at',p.username_changed_at,
    'display_name',p.display_name,'bio',p.bio,'avatar_url',p.avatar_url,'aura_total',p.aura_total,
    'onboarding_complete',p.onboarding_complete,'birth_date',up.birth_date,'birth_date_set',up.birth_date is not null,
    'eligibility_status',up.eligibility_status,'account_status',coalesce(v_raw_status,'active'),'app_access',v_access,
    'interests',coalesce((select jsonb_agg(i.slug order by i.sort_order) from public.user_interests ui join public.interests i on i.id=ui.interest_id where ui.user_id=v_user),'[]'::jsonb),
    'username_next_change_at',case when p.username_changed_at is null then null else p.username_changed_at + make_interval(days=>cfg.username_change_days) end
  ) into v_result
  from public.profiles p join private.user_private up on up.user_id=p.user_id cross join public.app_config cfg
  where p.user_id=v_user and cfg.id=1;
  return v_result;
end; $$;
revoke execute on function public.get_my_onboarding_state() from public,anon;
grant execute on function public.get_my_onboarding_state() to authenticated;

commit;
