-- CodaVybes V13.14 — privacy-aware product analytics for HQ.
-- Apply after 019_fyp_promotions_delivery.sql.
--
-- This restores a first-party analytics layer for active users, platform/device
-- split, rough location, IP visibility for trusted admins, top pages and recent
-- sessions. Private chat bodies and user-generated message text are never logged.

begin;

create table if not exists private.analytics_events (
  id bigint generated always as identity primary key,
  event_id uuid not null default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  session_id text,
  event_name text not null check (event_name ~ '^[a-z0-9_:.:-]{2,80}$'),
  page_path text,
  platform text not null default 'web' check (platform in ('web','pwa','android','windows','unknown')),
  device_type text not null default 'unknown' check (device_type in ('mobile','tablet','desktop','unknown')),
  country text,
  region text,
  city text,
  ip_address inet,
  user_agent text,
  referrer text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- If an older/partial analytics table already exists, CREATE TABLE IF NOT EXISTS
-- will not add new columns. Keep this migration safe to re-run on live projects.
alter table private.analytics_events add column if not exists event_id uuid not null default gen_random_uuid();
alter table private.analytics_events add column if not exists user_id uuid references auth.users(id) on delete set null;
alter table private.analytics_events add column if not exists session_id text;
alter table private.analytics_events add column if not exists event_name text;
alter table private.analytics_events add column if not exists page_path text;
alter table private.analytics_events add column if not exists platform text not null default 'web';
alter table private.analytics_events add column if not exists device_type text not null default 'unknown';
alter table private.analytics_events add column if not exists country text;
alter table private.analytics_events add column if not exists region text;
alter table private.analytics_events add column if not exists city text;
alter table private.analytics_events add column if not exists ip_address inet;
alter table private.analytics_events add column if not exists user_agent text;
alter table private.analytics_events add column if not exists referrer text;
alter table private.analytics_events add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table private.analytics_events add column if not exists created_at timestamptz not null default now();

update private.analytics_events
set event_name = 'legacy_event'
where event_name is null;

alter table private.analytics_events alter column event_name set not null;

create index if not exists analytics_events_created_idx on private.analytics_events(created_at desc);
create index if not exists analytics_events_user_created_idx on private.analytics_events(user_id, created_at desc);
create index if not exists analytics_events_session_created_idx on private.analytics_events(session_id, created_at desc);
create index if not exists analytics_events_event_created_idx on private.analytics_events(event_name, created_at desc);
create index if not exists analytics_events_location_idx on private.analytics_events(country, region, city);

create or replace function private.mask_analytics_ip(p_ip inet)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_ip is null then null
    when family(p_ip) = 4 then regexp_replace(host(p_ip), '\.[0-9]+$', '.0')
    else regexp_replace(host(p_ip), '(:[0-9a-fA-F]{0,4}){4}$', '::')
  end;
$$;
revoke execute on function private.mask_analytics_ip(inet) from public, anon, authenticated;

create or replace function private.insert_analytics_event(
  p_user uuid,
  p_event text,
  p_session text default null,
  p_page text default null,
  p_platform text default 'web',
  p_device text default 'unknown',
  p_referrer text default null,
  p_locale text default null,
  p_timezone text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_ip text default null,
  p_country text default null,
  p_region text default null,
  p_city text default null,
  p_user_agent text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event text := lower(regexp_replace(trim(coalesce(p_event,'')), '[^a-z0-9_:.:-]+', '_', 'g'));
  v_platform text := lower(trim(coalesce(p_platform,'web')));
  v_device text := lower(trim(coalesce(p_device,'unknown')));
  v_session text := nullif(left(trim(coalesce(p_session,'')), 128), '');
  v_page text := nullif(left(trim(coalesce(p_page,'')), 500), '');
  v_referrer text := nullif(left(trim(coalesce(p_referrer,'')), 500), '');
  v_country text := nullif(upper(left(trim(coalesce(p_country,'')), 2)), '');
  v_region text := nullif(left(trim(coalesce(p_region,'')), 80), '');
  v_city text := nullif(left(trim(coalesce(p_city,'')), 80), '');
  v_user_agent text := nullif(left(trim(coalesce(p_user_agent,'')), 500), '');
  v_metadata jsonb := coalesce(p_metadata, '{}'::jsonb);
  v_ip inet;
  v_hour_count integer;
begin
  if p_user is null or not exists (select 1 from auth.users u where u.id = p_user) then
    return jsonb_build_object('ok', false, 'reason', 'auth_required');
  end if;

  if not private.account_is_active(p_user) then
    return jsonb_build_object('ok', false, 'reason', 'account_unavailable');
  end if;

  if char_length(v_event) < 2 or char_length(v_event) > 80 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_event');
  end if;

  if v_platform not in ('web','pwa','android','windows','unknown') then v_platform := 'unknown'; end if;
  if v_device not in ('mobile','tablet','desktop','unknown') then v_device := 'unknown'; end if;

  select count(*) into v_hour_count
  from private.analytics_events e
  where e.user_id = p_user and e.created_at >= now() - interval '1 hour';
  if v_hour_count >= 900 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  begin
    if nullif(trim(coalesce(p_ip,'')), '') is not null then
      v_ip := split_part(trim(p_ip), ',', 1)::inet;
    end if;
  exception when others then
    v_ip := null;
  end;

  v_metadata := jsonb_strip_nulls(
    v_metadata || jsonb_build_object(
      'locale', nullif(left(trim(coalesce(p_locale,'')), 40), ''),
      'timezone', nullif(left(trim(coalesce(p_timezone,'')), 80), '')
    )
  );

  insert into private.analytics_events(
    user_id, session_id, event_name, page_path, platform, device_type,
    country, region, city, ip_address, user_agent, referrer, metadata
  ) values (
    p_user, v_session, v_event, coalesce(v_page,'/'), v_platform, v_device,
    v_country, v_region, v_city, v_ip, v_user_agent, v_referrer, v_metadata
  );

  return jsonb_build_object('ok', true);
end;
$$;
revoke execute on function private.insert_analytics_event(uuid,text,text,text,text,text,text,text,text,jsonb,text,text,text,text,text) from public, anon, authenticated;

create or replace function public.track_analytics_event(
  p_event text,
  p_session text default null,
  p_page text default null,
  p_platform text default 'web',
  p_device text default 'unknown',
  p_referrer text default null,
  p_locale text default null,
  p_timezone text default null,
  p_metadata jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return private.insert_analytics_event(
    auth.uid(), p_event, p_session, p_page, p_platform, p_device,
    p_referrer, p_locale, p_timezone, p_metadata
  );
end;
$$;
revoke execute on function public.track_analytics_event(text,text,text,text,text,text,text,text,jsonb) from public, anon;
grant execute on function public.track_analytics_event(text,text,text,text,text,text,text,text,jsonb) to authenticated;

create or replace function public.track_analytics_event_server(
  p_user uuid,
  p_event text,
  p_session text default null,
  p_page text default null,
  p_platform text default 'web',
  p_device text default 'unknown',
  p_referrer text default null,
  p_locale text default null,
  p_timezone text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_ip text default null,
  p_country text default null,
  p_region text default null,
  p_city text default null,
  p_user_agent text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return private.insert_analytics_event(
    p_user, p_event, p_session, p_page, p_platform, p_device, p_referrer,
    p_locale, p_timezone, p_metadata, p_ip, p_country, p_region, p_city, p_user_agent
  );
end;
$$;
revoke execute on function public.track_analytics_event_server(uuid,text,text,text,text,text,text,text,text,jsonb,text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.track_analytics_event_server(uuid,text,text,text,text,text,text,text,text,jsonb,text,text,text,text,text) to service_role;

create or replace function public.admin_get_analytics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_full_ip boolean;
  v_out jsonb;
begin
  v_role := private.require_admin(array['super_admin','admin','analyst']);
  v_full_ip := v_role in ('super_admin','admin');

  select jsonb_build_object(
    'generated_at', now(),
    'privacy', jsonb_build_object(
      'ip_mode', case when v_full_ip then 'full' else 'masked' end,
      'note', 'Analytics stores operational metadata only. Private chat bodies and message text are not logged.'
    ),
    'kpis', jsonb_build_object(
      'active_users_15m', (select count(distinct user_id) from private.analytics_events where created_at >= now() - interval '15 minutes'),
      'active_sessions_15m', (select count(distinct session_id) from private.analytics_events where created_at >= now() - interval '15 minutes' and session_id is not null),
      'unique_users_24h', (select count(distinct user_id) from private.analytics_events where created_at >= now() - interval '24 hours'),
      'events_24h', (select count(*) from private.analytics_events where created_at >= now() - interval '24 hours'),
      'page_views_24h', (select count(*) from private.analytics_events where event_name = 'page_view' and created_at >= now() - interval '24 hours'),
      'new_users_24h', (select count(*) from public.profiles where created_at >= now() - interval '24 hours'),
      'messages_24h', (select count(*) from public.messages where created_at >= now() - interval '24 hours'),
      'posts_24h', (select count(*) from public.aura_targets where target_type = 'post' and created_at >= now() - interval '24 hours'),
      'promotion_impressions_24h', (select count(*) from public.promotion_events where event_type = 'impression' and created_at >= now() - interval '24 hours'),
      'promotion_clicks_24h', (select count(*) from public.promotion_events where event_type = 'click' and created_at >= now() - interval '24 hours')
    ),
    'platforms', coalesce((select jsonb_agg(jsonb_build_object('platform', platform, 'events', events, 'users', users) order by events desc)
      from (
        select platform, count(*)::bigint events, count(distinct user_id)::bigint users
        from private.analytics_events
        where created_at >= now() - interval '24 hours'
        group by platform
      ) s), '[]'::jsonb),
    'devices', coalesce((select jsonb_agg(jsonb_build_object('device_type', device_type, 'events', events, 'users', users) order by events desc)
      from (
        select device_type, count(*)::bigint events, count(distinct user_id)::bigint users
        from private.analytics_events
        where created_at >= now() - interval '24 hours'
        group by device_type
      ) s), '[]'::jsonb),
    'locations', coalesce((select jsonb_agg(jsonb_build_object('country', country, 'region', region, 'city', city, 'events', events, 'users', users) order by users desc, events desc)
      from (
        select coalesce(country,'--') country, coalesce(region,'Unknown') region, coalesce(city,'Unknown') city,
          count(*)::bigint events, count(distinct user_id)::bigint users
        from private.analytics_events
        where created_at >= now() - interval '7 days'
        group by 1,2,3
        order by users desc, events desc
        limit 24
      ) s), '[]'::jsonb),
    'top_pages', coalesce((select jsonb_agg(jsonb_build_object('page_path', page_path, 'views', views, 'users', users) order by views desc)
      from (
        select coalesce(page_path,'/') page_path, count(*)::bigint views, count(distinct user_id)::bigint users
        from private.analytics_events
        where event_name = 'page_view' and created_at >= now() - interval '7 days'
        group by 1
        order by views desc
        limit 18
      ) s), '[]'::jsonb),
    'recent_sessions', coalesce((select jsonb_agg(jsonb_build_object(
        'session_id', session_id,
        'user_id', user_id,
        'username', username,
        'display_name', display_name,
        'platform', platform,
        'device_type', device_type,
        'country', country,
        'region', region,
        'city', city,
        'ip_address', ip_address,
        'last_page', page_path,
        'last_event', event_name,
        'last_seen_at', created_at
      ) order by created_at desc)
      from (
        select distinct on (e.session_id)
          e.session_id, e.user_id, p.username, p.display_name, e.platform, e.device_type,
          coalesce(e.country,'--') country, coalesce(e.region,'Unknown') region, coalesce(e.city,'Unknown') city,
          case when v_full_ip then host(e.ip_address) else private.mask_analytics_ip(e.ip_address) end ip_address,
          e.page_path, e.event_name, e.created_at
        from private.analytics_events e
        left join public.profiles p on p.user_id = e.user_id
        where e.created_at >= now() - interval '24 hours' and e.session_id is not null
        order by e.session_id, e.created_at desc
        limit 80
      ) s), '[]'::jsonb)
  ) into v_out;

  return v_out;
end;
$$;
revoke execute on function public.admin_get_analytics() from public, anon;
grant execute on function public.admin_get_analytics() to authenticated;

create or replace function public.admin_prune_analytics(p_days integer default 90)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days integer := least(greatest(coalesce(p_days,90),7),365);
  v_deleted bigint;
begin
  perform private.require_admin(array['super_admin','admin']);
  delete from private.analytics_events where created_at < now() - make_interval(days => v_days);
  get diagnostics v_deleted = row_count;
  perform private.audit_admin('analytics_prune','analytics',null,null,jsonb_build_object('deleted',v_deleted,'retention_days',v_days),'Analytics retention cleanup');
  return jsonb_build_object('ok',true,'deleted',v_deleted,'retention_days',v_days);
end;
$$;
revoke execute on function public.admin_prune_analytics(integer) from public, anon;
grant execute on function public.admin_prune_analytics(integer) to authenticated;

commit;
