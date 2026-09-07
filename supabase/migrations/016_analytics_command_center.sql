-- CodaVybes V13.4 — privacy-aware live analytics command center.
-- Run AFTER 015_discover_list_plus_badge.sql.
-- No mock rows are created. Telemetry history begins when V13.4 clients are deployed.

begin;

create table if not exists private.analytics_sessions (
  session_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  installation_id uuid,
  platform text not null default 'web' check (platform in ('web','android','windows','unknown')),
  app_version text not null default 'unknown' check (char_length(app_version) between 1 and 40),
  route text not null default '/' check (char_length(route) between 1 and 220),
  presence_status text not null default 'active' check (presence_status in ('active','idle','hidden','offline')),
  device_type text check (device_type is null or char_length(device_type) <= 40),
  os_name text check (os_name is null or char_length(os_name) <= 80),
  browser_name text check (browser_name is null or char_length(browser_name) <= 80),
  locale text check (locale is null or char_length(locale) <= 40),
  timezone text check (timezone is null or char_length(timezone) <= 100),
  viewport_width integer check (viewport_width is null or viewport_width between 0 and 20000),
  viewport_height integer check (viewport_height is null or viewport_height between 0 and 20000),
  network_type text check (network_type is null or char_length(network_type) <= 40),
  effective_type text check (effective_type is null or char_length(effective_type) <= 20),
  downlink_mbps numeric(8,2),
  rtt_ms integer,
  save_data boolean,
  analytics_consent boolean not null default false,
  location_consent boolean not null default false,
  latitude numeric(9,6),
  longitude numeric(9,6),
  location_accuracy_m numeric(12,2),
  country text check (country is null or char_length(country) <= 80),
  region text check (region is null or char_length(region) <= 120),
  city text check (city is null or char_length(city) <= 120),
  ip_address inet,
  ip_seen_at timestamptz,
  location_seen_at timestamptz,
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists analytics_sessions_user_last_idx on private.analytics_sessions(user_id,last_seen desc);
create index if not exists analytics_sessions_live_idx on private.analytics_sessions(last_seen desc);
create index if not exists analytics_sessions_platform_idx on private.analytics_sessions(platform,last_seen desc);
create index if not exists analytics_sessions_install_idx on private.analytics_sessions(installation_id) where installation_id is not null;

create table if not exists private.analytics_events (
  id bigint generated always as identity primary key,
  session_id uuid references private.analytics_sessions(session_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_name text not null check (event_name ~ '^[a-z0-9_]{2,80}$'),
  platform text not null default 'web' check (platform in ('web','android','windows','unknown')),
  app_version text not null default 'unknown' check (char_length(app_version) between 1 and 40),
  route text not null default '/' check (char_length(route) between 1 and 220),
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint analytics_event_properties_object check (jsonb_typeof(properties)='object'),
  constraint analytics_event_properties_size check (octet_length(properties::text) <= 8192)
);
create index if not exists analytics_events_created_idx on private.analytics_events(created_at desc);
create index if not exists analytics_events_user_idx on private.analytics_events(user_id,created_at desc);
create index if not exists analytics_events_name_idx on private.analytics_events(event_name,created_at desc);

create table if not exists private.analytics_errors (
  id bigint generated always as identity primary key,
  session_id uuid references private.analytics_sessions(session_id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'web' check (platform in ('web','android','windows','unknown')),
  app_version text not null default 'unknown' check (char_length(app_version) between 1 and 40),
  route text not null default '/' check (char_length(route) between 1 and 220),
  error_kind text not null default 'client_error' check (char_length(error_kind) between 1 and 80),
  message text not null default '' check (char_length(message) <= 500),
  source text check (source is null or char_length(source) <= 240),
  line_no integer,
  col_no integer,
  created_at timestamptz not null default now()
);
create index if not exists analytics_errors_created_idx on private.analytics_errors(created_at desc);
create index if not exists analytics_errors_user_idx on private.analytics_errors(user_id,created_at desc);
revoke all on private.analytics_sessions,private.analytics_events,private.analytics_errors from public,anon,authenticated;


create table if not exists public.app_releases (
  id uuid primary key default gen_random_uuid(),
  platform text not null check (platform in ('web','android','windows')),
  version text not null check (version ~ '^[0-9]+\.[0-9]+\.[0-9]+([-.+][A-Za-z0-9.-]+)?$'),
  build_number integer not null default 1 check (build_number > 0),
  download_url text,
  release_notes text not null default '' check (char_length(release_notes) <= 4000),
  required boolean not null default false,
  active boolean not null default true,
  published_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(platform,version,build_number),
  constraint app_releases_download_http check (download_url is null or download_url ~ '^https?://')
);
create index if not exists app_releases_latest_idx on public.app_releases(platform,active,build_number desc,published_at desc);
alter table public.app_releases enable row level security;
revoke all on public.app_releases from anon,authenticated;
grant select on public.app_releases to authenticated;
drop policy if exists "read active app releases" on public.app_releases;
create policy "read active app releases" on public.app_releases for select to authenticated using(active=true);

insert into public.app_releases(platform,version,build_number,download_url,release_notes,required,active)
values('web','13.4.0',13400,null,'CodaVybes V13.4 Analytics Command Center',false,true)
on conflict(platform,version,build_number) do nothing;

create or replace function private.analytics_safe_inet(p_value text)
returns inet language plpgsql immutable set search_path='' as $$
begin
  if nullif(trim(coalesce(p_value,'')),'') is null then return null; end if;
  return trim(p_value)::inet;
exception when others then return null;
end; $$;
revoke execute on function private.analytics_safe_inet(text) from public,anon,authenticated;

create or replace function private.analytics_platform(p_value text)
returns text language sql immutable set search_path='' as $$
  select case lower(coalesce(p_value,'')) when 'web' then 'web' when 'android' then 'android' when 'windows' then 'windows' else 'unknown' end
$$;
revoke execute on function private.analytics_platform(text) from public,anon,authenticated;

create or replace function private.analytics_housekeeping()
returns void language plpgsql security definer set search_path='' as $$
begin
  -- Sensitive operational metadata is deliberately shorter-lived than aggregate analytics.
  update private.analytics_sessions set ip_address=null
    where ip_address is not null and ip_seen_at < now()-interval '30 days';
  update private.analytics_sessions set latitude=null,longitude=null,location_accuracy_m=null
    where (latitude is not null or longitude is not null) and location_seen_at < now()-interval '14 days';
  delete from private.analytics_errors where created_at < now()-interval '90 days';
  delete from private.analytics_events where created_at < now()-interval '180 days';
  delete from private.analytics_sessions where last_seen < now()-interval '365 days';
end; $$;
revoke execute on function private.analytics_housekeeping() from public,anon,authenticated;

create or replace function private.analytics_ingest(
  p_user uuid,
  p_payload jsonb,
  p_ip text default null,
  p_country text default null,
  p_region text default null,
  p_city text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_session uuid;
  v_install uuid;
  v_platform text;
  v_version text;
  v_route text;
  v_presence text;
  v_analytics boolean;
  v_location boolean;
  v_event text;
  v_props jsonb;
  v_lat numeric;
  v_lon numeric;
  v_accuracy numeric;
  v_error jsonb;
begin
  if p_user is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from auth.users u where u.id=p_user) then raise exception 'User unavailable'; end if;
  if jsonb_typeof(coalesce(p_payload,'{}'::jsonb)) <> 'object' then raise exception 'Invalid telemetry payload'; end if;

  begin v_session := (p_payload->>'session_id')::uuid; exception when others then raise exception 'Invalid session id'; end;
  begin v_install := nullif(p_payload->>'installation_id','')::uuid; exception when others then v_install := null; end;
  v_platform := private.analytics_platform(p_payload->>'platform');
  v_version := left(coalesce(nullif(p_payload->>'app_version',''),'unknown'),40);
  v_route := left(coalesce(nullif(p_payload->>'route',''),'/'),220);
  v_presence := case coalesce(p_payload->>'presence_status','active') when 'idle' then 'idle' when 'hidden' then 'hidden' when 'offline' then 'offline' else 'active' end;
  v_analytics := coalesce((p_payload->>'analytics_consent')::boolean,false);
  v_location := v_analytics and coalesce((p_payload->>'location_consent')::boolean,false)
    and exists(
      select 1 from private.user_private up
      where up.user_id=p_user and up.birth_date is not null
        and extract(year from age(current_date,up.birth_date)) >= 18
    );

  if not v_analytics then v_install := null; end if;
  if not exists(select 1 from private.analytics_sessions s where s.session_id=v_session)
     and (select count(*) from private.analytics_sessions s where s.user_id=p_user and s.created_at>=now()-interval '1 hour') >= 40 then
    raise exception 'Telemetry session rate limit';
  end if;
  if v_location then
    begin v_lat := (p_payload->>'latitude')::numeric; exception when others then v_lat:=null; end;
    begin v_lon := (p_payload->>'longitude')::numeric; exception when others then v_lon:=null; end;
    begin v_accuracy := (p_payload->>'location_accuracy_m')::numeric; exception when others then v_accuracy:=null; end;
    if v_lat is not null and (v_lat < -90 or v_lat > 90) then v_lat:=null; end if;
    if v_lon is not null and (v_lon < -180 or v_lon > 180) then v_lon:=null; end if;
  end if;

  insert into private.analytics_sessions(
    session_id,user_id,installation_id,platform,app_version,route,presence_status,
    device_type,os_name,browser_name,locale,timezone,viewport_width,viewport_height,
    network_type,effective_type,downlink_mbps,rtt_ms,save_data,analytics_consent,location_consent,
    latitude,longitude,location_accuracy_m,country,region,city,ip_address,ip_seen_at,location_seen_at,
    first_seen,last_seen,created_at,updated_at
  ) values(
    v_session,p_user,v_install,v_platform,v_version,v_route,v_presence,
    left(nullif(p_payload->>'device_type',''),40),left(nullif(p_payload->>'os_name',''),80),left(nullif(p_payload->>'browser_name',''),80),
    left(nullif(p_payload->>'locale',''),40),left(nullif(p_payload->>'timezone',''),100),
    nullif(p_payload->>'viewport_width','')::integer,nullif(p_payload->>'viewport_height','')::integer,
    left(nullif(p_payload->>'network_type',''),40),left(nullif(p_payload->>'effective_type',''),20),
    nullif(p_payload->>'downlink_mbps','')::numeric,nullif(p_payload->>'rtt_ms','')::integer,
    nullif(p_payload->>'save_data','')::boolean,v_analytics,v_location,
    v_lat,v_lon,v_accuracy,left(nullif(p_country,''),80),left(nullif(p_region,''),120),left(nullif(p_city,''),120),
    private.analytics_safe_inet(p_ip),case when private.analytics_safe_inet(p_ip) is not null then now() else null end,
    case when v_lat is not null or v_lon is not null then now() else null end,
    now(),now(),now(),now()
  ) on conflict(session_id) do update set
    user_id=excluded.user_id,
    installation_id=coalesce(excluded.installation_id,private.analytics_sessions.installation_id),
    platform=excluded.platform,app_version=excluded.app_version,route=excluded.route,presence_status=excluded.presence_status,
    device_type=coalesce(excluded.device_type,private.analytics_sessions.device_type),
    os_name=coalesce(excluded.os_name,private.analytics_sessions.os_name),
    browser_name=coalesce(excluded.browser_name,private.analytics_sessions.browser_name),
    locale=coalesce(excluded.locale,private.analytics_sessions.locale),timezone=coalesce(excluded.timezone,private.analytics_sessions.timezone),
    viewport_width=coalesce(excluded.viewport_width,private.analytics_sessions.viewport_width),
    viewport_height=coalesce(excluded.viewport_height,private.analytics_sessions.viewport_height),
    network_type=coalesce(excluded.network_type,private.analytics_sessions.network_type),
    effective_type=coalesce(excluded.effective_type,private.analytics_sessions.effective_type),
    downlink_mbps=coalesce(excluded.downlink_mbps,private.analytics_sessions.downlink_mbps),
    rtt_ms=coalesce(excluded.rtt_ms,private.analytics_sessions.rtt_ms),save_data=coalesce(excluded.save_data,private.analytics_sessions.save_data),
    analytics_consent=excluded.analytics_consent,location_consent=excluded.location_consent,
    latitude=case when excluded.location_consent then coalesce(excluded.latitude,private.analytics_sessions.latitude) else null end,
    longitude=case when excluded.location_consent then coalesce(excluded.longitude,private.analytics_sessions.longitude) else null end,
    location_accuracy_m=case when excluded.location_consent then coalesce(excluded.location_accuracy_m,private.analytics_sessions.location_accuracy_m) else null end,
    location_seen_at=case when excluded.location_consent and (excluded.latitude is not null or excluded.longitude is not null) then now() when not excluded.location_consent then null else private.analytics_sessions.location_seen_at end,
    country=coalesce(excluded.country,private.analytics_sessions.country),region=coalesce(excluded.region,private.analytics_sessions.region),city=coalesce(excluded.city,private.analytics_sessions.city),
    ip_address=coalesce(excluded.ip_address,private.analytics_sessions.ip_address),
    ip_seen_at=case when excluded.ip_address is not null then now() else private.analytics_sessions.ip_seen_at end,
    last_seen=now(),updated_at=now();

  v_event := lower(left(coalesce(p_payload->>'event_name',''),80));
  if v_analytics and v_event ~ '^[a-z0-9_]{2,80}$'
     and (select count(*) from private.analytics_events e where e.user_id=p_user and e.created_at>=now()-interval '1 hour') < 600 then
    v_props := coalesce(p_payload->'properties','{}'::jsonb);
    if jsonb_typeof(v_props)<>'object' or octet_length(v_props::text)>8192 then v_props:='{}'::jsonb; end if;
    insert into private.analytics_events(session_id,user_id,event_name,platform,app_version,route,properties)
    values(v_session,p_user,v_event,v_platform,v_version,v_route,v_props);
  end if;

  v_error := p_payload->'error';
  if v_analytics and jsonb_typeof(v_error)='object'
     and (select count(*) from private.analytics_errors e where e.user_id=p_user and e.created_at>=now()-interval '1 hour') < 120 then
    insert into private.analytics_errors(session_id,user_id,platform,app_version,route,error_kind,message,source,line_no,col_no)
    values(
      v_session,p_user,v_platform,v_version,v_route,left(coalesce(nullif(v_error->>'kind',''),'client_error'),80),
      left(coalesce(v_error->>'message',''),500),left(nullif(v_error->>'source',''),240),
      nullif(v_error->>'line','')::integer,nullif(v_error->>'column','')::integer
    );
  end if;

  if random() < 0.01 then perform private.analytics_housekeeping(); end if;
  return jsonb_build_object('ok',true,'server_time',now(),'session_id',v_session);
end; $$;
revoke execute on function private.analytics_ingest(uuid,jsonb,text,text,text,text) from public,anon,authenticated;

-- Browser/native client fallback: records operational presence and consented analytics, but cannot claim an IP/geography.
create or replace function public.telemetry_ingest_client(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  return private.analytics_ingest(v_user,p_payload,null,null,null,null);
end; $$;
revoke execute on function public.telemetry_ingest_client(jsonb) from public,anon;
grant execute on function public.telemetry_ingest_client(jsonb) to authenticated;

-- Edge-only ingest: IP/coarse edge geography are accepted only from a service-role call after the function verifies the JWT.
create or replace function public.telemetry_ingest_server(
  p_user uuid,p_payload jsonb,p_ip text default null,p_country text default null,p_region text default null,p_city text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  return private.analytics_ingest(p_user,p_payload,p_ip,p_country,p_region,p_city);
end; $$;
revoke execute on function public.telemetry_ingest_server(uuid,jsonb,text,text,text,text) from public,anon,authenticated;
grant execute on function public.telemetry_ingest_server(uuid,jsonb,text,text,text,text) to service_role;

create or replace function public.admin_get_analytics_overview(p_hours integer default 24)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_role text;
  v_hours integer:=least(greatest(coalesce(p_hours,24),1),2160);
  v_since timestamptz:=now()-make_interval(hours=>least(greatest(coalesce(p_hours,24),1),2160));
  v_out jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin','analyst']);
  select jsonb_build_object(
    'role',v_role,'hours',v_hours,'generated_at',now(),
    'active_users',(select count(distinct user_id) from private.analytics_sessions where last_seen>=now()-interval '75 seconds'),
    'active_sessions',(select count(*) from private.analytics_sessions where last_seen>=now()-interval '75 seconds'),
    'unique_users_period',(select count(distinct user_id) from private.analytics_sessions where last_seen>=v_since),
    'sessions_period',(select count(*) from private.analytics_sessions where first_seen>=v_since),
    'installs_seen',(select count(distinct installation_id) from private.analytics_sessions where installation_id is not null),
    'events_period',(select count(*) from private.analytics_events where created_at>=v_since),
    'errors_period',(select count(*) from private.analytics_errors where created_at>=v_since),
    'posts_period',(select count(*) from public.aura_targets where target_type='post' and created_at>=v_since),
    'messages_period',(select count(*) from public.messages where created_at>=v_since),
    'comments_period',(select count(*) from public.moment_comments where created_at>=v_since),
    'reactions_period',(select count(*) from public.moment_reactions where created_at>=v_since),
    'shares_period',(select count(*) from public.moment_shares where created_at>=v_since),
    'rooms_period',(select count(*) from public.rooms where created_at>=v_since),
    'games_period',(select count(*) from public.game_sessions where started_at>=v_since),
    'plus_active',(select count(*) from public.user_subscriptions where status='active' and ends_at>now()),
    'paid_orders_period',(select count(*) from public.checkout_orders where status='paid' and paid_at>=v_since),
    'new_users_period',(select count(*) from public.profiles where created_at>=v_since),
    'platforms',coalesce((select jsonb_agg(to_jsonb(x) order by x.users_period desc) from (
      select s.platform,
        count(distinct s.user_id) filter(where s.last_seen>=now()-interval '75 seconds')::bigint active_users,
        count(distinct s.user_id) filter(where s.last_seen>=v_since)::bigint users_period,
        count(*) filter(where s.first_seen>=v_since)::bigint sessions_period,
        count(distinct s.installation_id) filter(where s.installation_id is not null)::bigint installs_seen
      from private.analytics_sessions s group by s.platform
    ) x),'[]'::jsonb),
    'versions',coalesce((select jsonb_agg(to_jsonb(x) order by x.users desc) from (
      select s.platform,s.app_version,count(distinct s.user_id)::bigint users,max(s.last_seen) last_seen
      from private.analytics_sessions s where s.last_seen>=v_since group by s.platform,s.app_version order by users desc limit 20
    ) x),'[]'::jsonb),
    'top_routes',coalesce((select jsonb_agg(to_jsonb(x) order by x.users desc) from (
      select s.route,count(distinct s.user_id)::bigint users,count(*)::bigint sessions
      from private.analytics_sessions s where s.last_seen>=v_since group by s.route order by users desc limit 12
    ) x),'[]'::jsonb),
    'top_events',coalesce((select jsonb_agg(to_jsonb(x) order by x.count desc) from (
      select e.event_name,count(*)::bigint count,count(distinct e.user_id)::bigint users
      from private.analytics_events e where e.created_at>=v_since group by e.event_name order by count desc limit 15
    ) x),'[]'::jsonb),
    'countries',coalesce((select jsonb_agg(to_jsonb(x) order by x.users desc) from (
      select s.country,count(distinct s.user_id)::bigint users from private.analytics_sessions s
      where s.last_seen>=v_since and s.country is not null group by s.country order by users desc limit 12
    ) x),'[]'::jsonb),
    'revenue_by_currency',coalesce((select jsonb_agg(to_jsonb(x) order by x.amount_cents desc) from (
      select o.currency,sum(o.amount_cents)::bigint amount_cents,count(*)::bigint orders from public.checkout_orders o
      where o.status='paid' and o.paid_at>=v_since group by o.currency
    ) x),'[]'::jsonb)
  ) into v_out;
  return v_out;
end; $$;
revoke execute on function public.admin_get_analytics_overview(integer) from public,anon;
grant execute on function public.admin_get_analytics_overview(integer) to authenticated;

create or replace function public.admin_list_live_users(p_limit integer default 100)
returns table(
  user_id uuid,username text,display_name text,avatar_url text,platform text,app_version text,route text,
  presence_status text,last_seen timestamptz,device_type text,os_name text,browser_name text,network text,
  timezone text,country text,region text,city text,ip_address text,latitude numeric,longitude numeric,
  location_accuracy_m numeric,analytics_consent boolean,location_consent boolean
) language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_limit integer:=least(greatest(coalesce(p_limit,100),1),250);
begin
  v_role:=private.require_admin(array['super_admin','admin','analyst']);
  return query
  select x.user_id,p.username,p.display_name,p.avatar_url,x.platform,x.app_version,x.route,x.presence_status,x.last_seen,
    x.device_type,x.os_name,x.browser_name,
    concat_ws(' · ',nullif(x.network_type,''),nullif(x.effective_type,''),case when x.downlink_mbps is not null then x.downlink_mbps::text||' Mbps' end,case when x.rtt_ms is not null then x.rtt_ms::text||' ms' end),
    x.timezone,x.country,x.region,x.city,
    case when v_role='super_admin' and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18 then x.ip_address::text else null end,
    case when v_role='super_admin' and x.location_consent and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18 then x.latitude else null end,
    case when v_role='super_admin' and x.location_consent and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18 then x.longitude else null end,
    case when v_role='super_admin' and x.location_consent and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18 then x.location_accuracy_m else null end,
    x.analytics_consent,x.location_consent
  from (
    select distinct on (s.user_id) s.* from private.analytics_sessions s
    where s.last_seen>=now()-interval '75 seconds'
    order by s.user_id,s.last_seen desc
  ) x join public.profiles p on p.user_id=x.user_id
      left join private.user_private up on up.user_id=x.user_id
  order by x.last_seen desc limit v_limit;
end; $$;
revoke execute on function public.admin_list_live_users(integer) from public,anon;
grant execute on function public.admin_list_live_users(integer) to authenticated;

create or replace function public.admin_get_user_analytics(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_out jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin','moderator']);
  if not exists(select 1 from public.profiles where user_id=p_user) then raise exception 'User unavailable'; end if;
  select jsonb_build_object(
    'active_now',exists(select 1 from private.analytics_sessions s where s.user_id=p_user and s.last_seen>=now()-interval '75 seconds'),
    'sessions_total',(select count(*) from private.analytics_sessions s where s.user_id=p_user),
    'installations_seen',(select count(distinct s.installation_id) from private.analytics_sessions s where s.user_id=p_user and s.installation_id is not null),
    'events_30d',(select count(*) from private.analytics_events e where e.user_id=p_user and e.created_at>=now()-interval '30 days'),
    'errors_30d',(select count(*) from private.analytics_errors e where e.user_id=p_user and e.created_at>=now()-interval '30 days'),
    'posts',(select count(*) from public.aura_targets t where t.owner_id=p_user and t.target_type='post'),
    'comments',(select count(*) from public.moment_comments c where c.user_id=p_user),
    'reactions',(select count(*) from public.moment_reactions r where r.user_id=p_user),
    'shares',(select count(*) from public.moment_shares sh where sh.user_id=p_user),
    'messages',(select count(*) from public.messages m where m.sender_id=p_user),
    'games',(select count(*) from public.game_results gr where gr.user_id=p_user),
    'latest_session',(select jsonb_build_object(
      'session_id',s.session_id,'platform',s.platform,'app_version',s.app_version,'route',s.route,'presence_status',s.presence_status,
      'last_seen',s.last_seen,'first_seen',s.first_seen,'device_type',s.device_type,'os_name',s.os_name,'browser_name',s.browser_name,
      'network_type',s.network_type,'effective_type',s.effective_type,'downlink_mbps',s.downlink_mbps,'rtt_ms',s.rtt_ms,'timezone',s.timezone,
      'country',s.country,'region',s.region,'city',s.city,'analytics_consent',s.analytics_consent,'location_consent',s.location_consent,
      'ip_address',case when v_role='super_admin' and exists(select 1 from private.user_private up where up.user_id=p_user and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18) then s.ip_address::text else null end,
      'latitude',case when v_role='super_admin' and s.location_consent and exists(select 1 from private.user_private up where up.user_id=p_user and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18) then s.latitude else null end,
      'longitude',case when v_role='super_admin' and s.location_consent and exists(select 1 from private.user_private up where up.user_id=p_user and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18) then s.longitude else null end,
      'location_accuracy_m',case when v_role='super_admin' and s.location_consent and exists(select 1 from private.user_private up where up.user_id=p_user and up.birth_date is not null and extract(year from age(current_date,up.birth_date))>=18) then s.location_accuracy_m else null end
    ) from private.analytics_sessions s where s.user_id=p_user order by s.last_seen desc limit 1),
    'recent_sessions',coalesce((select jsonb_agg(to_jsonb(x) order by x.last_seen desc) from (
      select s.session_id,s.platform,s.app_version,s.route,s.first_seen,s.last_seen,s.device_type,s.os_name,s.browser_name,s.timezone,s.country,s.city,s.analytics_consent,s.location_consent
      from private.analytics_sessions s where s.user_id=p_user order by s.last_seen desc limit 20
    ) x),'[]'::jsonb),
    'recent_events',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
      select e.id,e.event_name,e.platform,e.app_version,e.route,e.properties,e.created_at from private.analytics_events e where e.user_id=p_user order by e.created_at desc limit 80
    ) x),'[]'::jsonb),
    'recent_errors',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
      select e.id,e.error_kind,e.message,e.platform,e.app_version,e.route,e.created_at from private.analytics_errors e where e.user_id=p_user order by e.created_at desc limit 30
    ) x),'[]'::jsonb)
  ) into v_out;
  return v_out;
end; $$;
revoke execute on function public.admin_get_user_analytics(uuid) from public,anon;
grant execute on function public.admin_get_user_analytics(uuid) to authenticated;

create or replace function public.admin_list_activity_stream(p_limit integer default 120)
returns table(created_at timestamptz,user_id uuid,username text,display_name text,activity_type text,entity_id text,detail jsonb)
language plpgsql stable security definer set search_path='' as $$
declare v_limit integer:=least(greatest(coalesce(p_limit,120),1),300);
begin
  perform private.require_admin(array['super_admin','admin','moderator','analyst']);
  return query
  select a.created_at,a.user_id,p.username,p.display_name,a.activity_type,a.entity_id,a.detail
  from (
    select t.created_at,t.owner_id user_id,'post_created'::text activity_type,t.id::text entity_id,
      jsonb_build_object('visibility',t.visibility,'status',t.status,'aura',t.aura_count) detail
      from public.aura_targets t where t.target_type='post'
    union all
    select c.created_at,c.user_id,'comment_created',c.id::text,jsonb_build_object('target_id',c.target_id)
      from public.moment_comments c
    union all
    select r.created_at,r.user_id,'reaction_added',r.target_id::text,jsonb_build_object('emoji',r.emoji)
      from public.moment_reactions r
    union all
    select sh.created_at,sh.user_id,'share',sh.id::text,jsonb_build_object('platform',sh.platform,'target_id',sh.target_id)
      from public.moment_shares sh
    union all
    select m.created_at,m.sender_id,'message_sent',m.id::text,jsonb_build_object('kind',m.kind,'status',m.status,'aura',m.aura_count)
      from public.messages m
    union all
    select gr.created_at,gr.user_id,'game_result',gr.session_id::text,jsonb_build_object('score',gr.total_score,'placement',gr.placement,'winner',gr.is_winner,'mvp',gr.is_mvp)
      from public.game_results gr
    union all
    select ae.created_at,ae.receiver_id,'aura_received',ae.id::text,jsonb_build_object('amount',ae.amount,'source',ae.source,'status',ae.status)
      from public.aura_events ae
    union all
    select wl.created_at,wl.user_id,'wallet_entry',wl.id::text,jsonb_build_object('amount',wl.amount,'entry_type',wl.entry_type)
      from public.wallet_ledger wl
    union all
    select e.created_at,e.user_id,e.event_name,e.id::text,e.properties
      from private.analytics_events e
  ) a
  left join public.profiles p on p.user_id=a.user_id
  order by a.created_at desc limit v_limit;
end; $$;
revoke execute on function public.admin_list_activity_stream(integer) from public,anon;
grant execute on function public.admin_list_activity_stream(integer) to authenticated;

create or replace function public.admin_list_analytics_errors(p_limit integer default 80)
returns table(id bigint,user_id uuid,username text,display_name text,error_kind text,message text,platform text,app_version text,route text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare v_limit integer:=least(greatest(coalesce(p_limit,80),1),250);
begin
  perform private.require_admin(array['super_admin','admin','analyst']);
  return query select e.id,e.user_id,p.username,p.display_name,e.error_kind,e.message,e.platform,e.app_version,e.route,e.created_at
  from private.analytics_errors e left join public.profiles p on p.user_id=e.user_id order by e.created_at desc limit v_limit;
end; $$;
revoke execute on function public.admin_list_analytics_errors(integer) from public,anon;
grant execute on function public.admin_list_analytics_errors(integer) to authenticated;


create or replace function private.analytics_semver_weight(p_value text)
returns bigint language plpgsql immutable set search_path='' as $$
declare v text[]; a bigint:=0; b bigint:=0; c bigint:=0;
begin
  v:=regexp_match(coalesce(p_value,''),'^([0-9]+)\.([0-9]+)\.([0-9]+)');
  if v is null then return 0; end if;
  a:=least(v[1]::bigint,999999); b:=least(v[2]::bigint,999999); c:=least(v[3]::bigint,999999);
  return a*1000000000000+b*1000000+c;
exception when others then return 0;
end; $$;
revoke execute on function private.analytics_semver_weight(text) from public,anon,authenticated;

create or replace function public.get_app_update(p_platform text,p_current_version text default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_platform text:=private.analytics_platform(p_platform); v_row public.app_releases%rowtype;
begin
  if v_platform not in ('web','android','windows') then return null; end if;
  select * into v_row from public.app_releases r where r.platform=v_platform and r.active=true order by r.build_number desc,r.published_at desc limit 1;
  if v_row.id is null then return null; end if;
  return jsonb_build_object('platform',v_row.platform,'version',v_row.version,'build_number',v_row.build_number,'download_url',v_row.download_url,'release_notes',v_row.release_notes,'required',v_row.required,'published_at',v_row.published_at,'update_available',private.analytics_semver_weight(coalesce(p_current_version,'0.0.0')) < private.analytics_semver_weight(v_row.version));
end; $$;
revoke execute on function public.get_app_update(text,text) from public;
grant execute on function public.get_app_update(text,text) to anon,authenticated;

create or replace function public.admin_list_app_releases()
returns setof public.app_releases language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_admin(array['super_admin','admin','analyst']);
  return query select * from public.app_releases order by platform,build_number desc,published_at desc limit 100;
end; $$;
revoke execute on function public.admin_list_app_releases() from public,anon;
grant execute on function public.admin_list_app_releases() to authenticated;

create or replace function public.admin_upsert_app_release(
  p_id uuid,p_platform text,p_version text,p_build_number integer,p_download_url text,p_release_notes text,p_required boolean,p_active boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_id uuid; v_before jsonb; v_after jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  if p_platform not in ('web','android','windows') then raise exception 'Invalid platform'; end if;
  if p_version !~ '^[0-9]+\.[0-9]+\.[0-9]+([-.+][A-Za-z0-9.-]+)?$' then raise exception 'Version must be semver, e.g. 13.4.0'; end if;
  if coalesce(p_build_number,0)<=0 then raise exception 'Build number must be positive'; end if;
  if nullif(trim(coalesce(p_download_url,'')),'') is not null and p_download_url !~ '^https?://' then raise exception 'Download URL must use http(s)'; end if;
  if p_id is not null then select to_jsonb(r) into v_before from public.app_releases r where r.id=p_id; end if;
  insert into public.app_releases(id,platform,version,build_number,download_url,release_notes,required,active,published_at,created_by,updated_at)
  values(coalesce(p_id,gen_random_uuid()),p_platform,p_version,p_build_number,nullif(trim(coalesce(p_download_url,'')),''),left(coalesce(p_release_notes,''),4000),coalesce(p_required,false),coalesce(p_active,true),now(),auth.uid(),now())
  on conflict(id) do update set platform=excluded.platform,version=excluded.version,build_number=excluded.build_number,download_url=excluded.download_url,release_notes=excluded.release_notes,required=excluded.required,active=excluded.active,published_at=now(),updated_at=now()
  returning id into v_id;
  select to_jsonb(r) into v_after from public.app_releases r where r.id=v_id;
  perform private.audit_admin('app_release','release',v_id::text,v_before,v_after,'Release registry update');
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_app_release(uuid,text,text,integer,text,text,boolean,boolean) from public,anon;
grant execute on function public.admin_upsert_app_release(uuid,text,text,integer,text,text,boolean,boolean) to authenticated;

commit;
