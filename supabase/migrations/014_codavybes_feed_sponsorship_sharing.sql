-- CodaVybes V13
-- Brand transition, all-post For You feed, sponsorships, super-admin feed posts,
-- moment engagement notifications, share tracking and low-frequency promotion rails.

begin;

-- ---------------------------------------------------------------------------
-- BRAND-SAFE DATA DEFAULTS
-- ---------------------------------------------------------------------------
update public.aura_targets set context_label='Public CodaVybes' where context_label='Public VYBE';
update public.aura_targets set context_label='CodaVybes' where context_label='VYBE';
update public.monetization_config set coin_name='CodaCoins' where id=1 and coin_name='VYBE Coins';

-- Notification types now include public-post engagement.
alter table public.user_notifications drop constraint if exists user_notifications_type_check;
alter table public.user_notifications add constraint user_notifications_type_check
  check(type in ('aura','chat','room','meet','bond','system','shop','plus','reaction','comment','share'));

-- ---------------------------------------------------------------------------
-- EVERY PUBLIC POST CAN APPEAR IN FOR YOU
-- ---------------------------------------------------------------------------
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
  select * into v_cfg from public.aura_config where id=1;

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
      exists(
        select 1 from public.aura_events e
        where e.giver_id=v_user and e.target_id=t.id and e.source='peer' and e.status='counted'
      ) as has_aura,
      (
        (t.aura_count::numeric / greatest(extract(epoch from (now()-t.created_at))/3600.0,0.5))*coalesce(v_cfg.weight_velocity,0.35)
        + t.unique_givers::numeric*coalesce(v_cfg.weight_unique_givers,0.25)
        + t.aura_count::numeric*coalesce(v_cfg.weight_total_aura,0.15)
        + greatest(0::numeric,1-(extract(epoch from (now()-t.created_at))/3600.0)/168.0)*10*coalesce(v_cfg.weight_freshness,0.25)
      ) as score
    from public.aura_targets t
    join public.profiles p on p.user_id=t.owner_id
    where t.target_type='post'
      and t.status='active'
      and t.visibility='public'
      and p.onboarding_complete=true
      and private.account_is_active(p.user_id)
      and private.age_compatible(v_user,p.user_id)
      and not public.users_are_blocked(v_user,p.user_id)
  )
  select s.id,s.owner_id,s.display_name,s.username,s.aura_total,s.rank_json,
         s.content_text,s.context_label,s.aura_count,s.unique_givers,s.is_aura_moment,
         s.created_at,s.has_aura,s.score
  from scored s
  order by s.score desc,s.created_at desc
  limit v_limit offset v_offset;
end;
$$;
revoke execute on function public.get_for_you_feed(integer,integer) from public,anon;
grant execute on function public.get_for_you_feed(integer,integer) to authenticated;

-- ---------------------------------------------------------------------------
-- POST ENGAGEMENT NOTIFICATIONS
-- ---------------------------------------------------------------------------
create table if not exists public.moment_shares (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null references public.aura_targets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check(platform in ('native','instagram','tiktok','facebook','youtube','x','linkedin','download','copy')),
  created_at timestamptz not null default now()
);
create index if not exists moment_shares_target_created_idx on public.moment_shares(target_id,created_at desc);
create index if not exists moment_shares_user_created_idx on public.moment_shares(user_id,created_at desc);
alter table public.moment_shares enable row level security;
revoke all on public.moment_shares from anon,authenticated;

create or replace function public.toggle_moment_reaction(p_target uuid,p_emoji text default '❤️')
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid(); v_exists boolean; v_count integer; v_owner uuid; v_name text;
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  select t.owner_id into v_owner from public.aura_targets t
    where t.id=p_target and t.status='active' and t.visibility='public'
      and private.age_compatible(v_user,t.owner_id) and not public.users_are_blocked(v_user,t.owner_id);
  if v_owner is null then raise exception 'Moment unavailable'; end if;
  select exists(select 1 from public.moment_reactions where target_id=p_target and user_id=v_user) into v_exists;
  if v_exists then
    delete from public.moment_reactions where target_id=p_target and user_id=v_user;
  else
    insert into public.moment_reactions(target_id,user_id,emoji) values(p_target,v_user,left(coalesce(nullif(p_emoji,''),'❤️'),16));
    if v_owner<>v_user then
      select coalesce(display_name,username,'Someone') into v_name from public.profiles where user_id=v_user;
      perform private.push_notification(v_owner,'reaction','New reaction',v_name||' reacted to your post.',v_user,'aura_target',p_target,'/moments/'||p_target::text,jsonb_build_object('emoji',left(coalesce(nullif(p_emoji,''),'❤️'),16)));
    end if;
  end if;
  select count(*)::integer into v_count from public.moment_reactions where target_id=p_target;
  return jsonb_build_object('reacted',not v_exists,'count',v_count);
end; $$;
revoke execute on function public.toggle_moment_reaction(uuid,text) from public,anon;
grant execute on function public.toggle_moment_reaction(uuid,text) to authenticated;

create or replace function public.add_moment_comment(p_target uuid,p_body text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid; v_owner uuid; v_name text; v_body text:=trim(coalesce(p_body,''));
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  if char_length(v_body) not between 1 and 800 then raise exception 'Reply must be 1–800 characters'; end if;
  select t.owner_id into v_owner from public.aura_targets t where t.id=p_target and t.status='active' and t.visibility='public'
    and private.age_compatible(v_user,t.owner_id) and not public.users_are_blocked(v_user,t.owner_id);
  if v_owner is null then raise exception 'Moment unavailable'; end if;
  if (select count(*) from public.moment_comments where user_id=v_user and created_at>=now()-interval '1 minute')>=12 then raise exception 'Slow down for a moment'; end if;
  insert into public.moment_comments(target_id,user_id,body) values(p_target,v_user,v_body) returning id into v_id;
  if v_owner<>v_user then
    select coalesce(display_name,username,'Someone') into v_name from public.profiles where user_id=v_user;
    perform private.push_notification(v_owner,'comment','New reply',v_name||' replied: '||left(v_body,180),v_user,'aura_target',p_target,'/moments/'||p_target::text,jsonb_build_object('comment_id',v_id));
  end if;
  return jsonb_build_object('id',v_id,'body',v_body,'created_at',now());
end; $$;
revoke execute on function public.add_moment_comment(uuid,text) from public,anon;
grant execute on function public.add_moment_comment(uuid,text) to authenticated;

create or replace function public.record_moment_share(p_target uuid,p_platform text default 'native')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_owner uuid; v_name text; v_platform text:=lower(trim(coalesce(p_platform,'native'))); v_id uuid;
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  if v_platform not in ('native','instagram','tiktok','facebook','youtube','x','linkedin','download','copy') then v_platform:='native'; end if;
  select t.owner_id into v_owner from public.aura_targets t where t.id=p_target and t.status='active' and t.visibility='public'
    and private.age_compatible(v_user,t.owner_id) and not public.users_are_blocked(v_user,t.owner_id);
  if v_owner is null then raise exception 'Moment unavailable'; end if;
  if (select count(*) from public.moment_shares where user_id=v_user and created_at>=now()-interval '1 hour')>=60 then raise exception 'Share limit reached. Try again later.'; end if;
  insert into public.moment_shares(target_id,user_id,platform) values(p_target,v_user,v_platform) returning id into v_id;
  if v_owner<>v_user then
    select coalesce(display_name,username,'Someone') into v_name from public.profiles where user_id=v_user;
    perform private.push_notification(v_owner,'share','Your post was shared',v_name||' shared your post to '||initcap(replace(v_platform,'_',' '))||'.',v_user,'aura_target',p_target,'/moments/'||p_target::text,jsonb_build_object('platform',v_platform));
  end if;
  return jsonb_build_object('ok',true,'share_id',v_id,'platform',v_platform);
end; $$;
revoke execute on function public.record_moment_share(uuid,text) from public,anon;
grant execute on function public.record_moment_share(uuid,text) to authenticated;

-- ---------------------------------------------------------------------------
-- SPONSORED PROMOTIONS
-- ---------------------------------------------------------------------------
create table if not exists public.sponsored_promotions (
  id uuid primary key default gen_random_uuid(),
  brand_name text not null check(char_length(trim(brand_name)) between 1 and 80),
  headline text not null check(char_length(trim(headline)) between 1 and 120),
  body text not null default '' check(char_length(body)<=500),
  image_url text,
  destination_url text,
  cta_label text not null default 'Learn more' check(char_length(cta_label) between 1 and 40),
  active boolean not null default true,
  priority integer not null default 0 check(priority between -1000 and 1000),
  min_age integer not null default 18 check(min_age between 10 and 120),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(image_url is null or image_url ~* '^https?://'),
  check(destination_url is null or destination_url ~* '^https?://'),
  check(ends_at is null or ends_at>starts_at)
);
create index if not exists sponsored_promotions_live_idx on public.sponsored_promotions(active,starts_at,ends_at,priority desc);

create table if not exists public.promotion_events (
  id bigint generated always as identity primary key,
  promotion_id uuid not null references public.sponsored_promotions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check(event_type in ('impression','click')),
  created_at timestamptz not null default now()
);
create index if not exists promotion_events_promo_created_idx on public.promotion_events(promotion_id,created_at desc);
create index if not exists promotion_events_user_created_idx on public.promotion_events(user_id,created_at desc);

alter table public.sponsored_promotions enable row level security;
alter table public.promotion_events enable row level security;
revoke all on public.sponsored_promotions,public.promotion_events from anon,authenticated;

create or replace function public.get_active_sponsorships(p_limit integer default 6)
returns table(id uuid,brand_name text,headline text,body text,image_url text,destination_url text,cta_label text,priority integer,min_age integer)
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  return query
  select p.id,p.brand_name::text,p.headline::text,p.body::text,p.image_url::text,p.destination_url::text,p.cta_label::text,p.priority,p.min_age
  from public.sponsored_promotions p
  where p.active=true and coalesce(private.user_age(v_user),0)>=p.min_age and p.starts_at<=now() and (p.ends_at is null or p.ends_at>now())
  order by p.priority desc,md5(p.id::text||v_user::text||current_date::text)
  limit least(greatest(coalesce(p_limit,6),1),12);
end; $$;
revoke execute on function public.get_active_sponsorships(integer) from public,anon;
grant execute on function public.get_active_sponsorships(integer) to authenticated;

create or replace function public.record_promotion_event(p_promotion uuid,p_event text)
returns void language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_event text:=lower(trim(coalesce(p_event,'')));
begin
  if v_user is null or not private.account_is_active(v_user) then return; end if;
  if v_event not in ('impression','click') then return; end if;
  if not exists(select 1 from public.sponsored_promotions p where p.id=p_promotion and p.active=true and p.starts_at<=now() and (p.ends_at is null or p.ends_at>now())) then return; end if;
  if (select count(*) from public.promotion_events where user_id=v_user and created_at>=now()-interval '1 day')>=250 then return; end if;
  if v_event='impression' and exists(select 1 from public.promotion_events where user_id=v_user and promotion_id=p_promotion and event_type='impression' and created_at>=now()-interval '30 minutes') then return; end if;
  insert into public.promotion_events(promotion_id,user_id,event_type) values(p_promotion,v_user,v_event);
end; $$;
revoke execute on function public.record_promotion_event(uuid,text) from public,anon;
grant execute on function public.record_promotion_event(uuid,text) to authenticated;

create or replace function public.admin_list_promotions()
returns table(id uuid,brand_name text,headline text,body text,image_url text,destination_url text,cta_label text,active boolean,priority integer,min_age integer,starts_at timestamptz,ends_at timestamptz,impressions bigint,clicks bigint,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_admin(array['super_admin','admin','analyst']);
  return query select p.id,p.brand_name::text,p.headline::text,p.body::text,p.image_url::text,p.destination_url::text,p.cta_label::text,p.active,p.priority,p.min_age,p.starts_at,p.ends_at,
    (select count(*) from public.promotion_events e where e.promotion_id=p.id and e.event_type='impression')::bigint,
    (select count(*) from public.promotion_events e where e.promotion_id=p.id and e.event_type='click')::bigint,
    p.created_at
  from public.sponsored_promotions p order by p.active desc,p.priority desc,p.created_at desc;
end; $$;
revoke execute on function public.admin_list_promotions() from public,anon;
grant execute on function public.admin_list_promotions() to authenticated;

create or replace function public.admin_upsert_promotion(
  p_id uuid,p_brand text,p_headline text,p_body text,p_image_url text,p_destination_url text,p_cta_label text,
  p_active boolean,p_priority integer,p_min_age integer,p_starts timestamptz,p_ends timestamptz,p_reason text default 'Promotion update'
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if nullif(trim(p_brand),'') is null or nullif(trim(p_headline),'') is null then raise exception 'Brand and headline are required'; end if;
  if nullif(trim(coalesce(p_image_url,'')),'') is not null and p_image_url !~* '^https?://' then raise exception 'Image URL must use http/https'; end if;
  if nullif(trim(coalesce(p_destination_url,'')),'') is not null and p_destination_url !~* '^https?://' then raise exception 'Destination URL must use http/https'; end if;
  if p_id is not null then select to_jsonb(x) into v_before from public.sponsored_promotions x where x.id=p_id; end if;
  if p_id is null then
    insert into public.sponsored_promotions(brand_name,headline,body,image_url,destination_url,cta_label,active,priority,min_age,starts_at,ends_at,created_by)
    values(trim(p_brand),trim(p_headline),trim(coalesce(p_body,'')),nullif(trim(coalesce(p_image_url,'')),''),nullif(trim(coalesce(p_destination_url,'')),''),coalesce(nullif(trim(p_cta_label),''),'Learn more'),coalesce(p_active,true),coalesce(p_priority,0),greatest(18,coalesce(p_min_age,18)),coalesce(p_starts,now()),p_ends,auth.uid()) returning id into v_id;
  else
    update public.sponsored_promotions set brand_name=trim(p_brand),headline=trim(p_headline),body=trim(coalesce(p_body,'')),image_url=nullif(trim(coalesce(p_image_url,'')),''),destination_url=nullif(trim(coalesce(p_destination_url,'')),''),cta_label=coalesce(nullif(trim(p_cta_label),''),'Learn more'),active=coalesce(p_active,active),priority=coalesce(p_priority,priority),min_age=greatest(18,coalesce(p_min_age,min_age)),starts_at=coalesce(p_starts,starts_at),ends_at=p_ends,updated_at=now() where id=p_id returning id into v_id;
  end if;
  select to_jsonb(x) into v_after from public.sponsored_promotions x where x.id=v_id;
  perform private.audit_admin('promotion_upsert','promotion',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_promotion(uuid,text,text,text,text,text,text,boolean,integer,integer,timestamptz,timestamptz,text) from public,anon;
grant execute on function public.admin_upsert_promotion(uuid,text,text,text,text,text,text,boolean,integer,integer,timestamptz,timestamptz,text) to authenticated;

-- ---------------------------------------------------------------------------
-- SUPER-ADMIN PLATFORM POSTS: pinned feed surface + notify everyone
-- ---------------------------------------------------------------------------
create table if not exists public.platform_posts (
  id uuid primary key default gen_random_uuid(),
  body text not null check(char_length(trim(body)) between 1 and 1600),
  image_url text,
  cta_label text,
  cta_url text,
  active boolean not null default true,
  pinned_until timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(image_url is null or image_url ~* '^https?://'),
  check(cta_url is null or cta_url ~* '^https?://')
);
create index if not exists platform_posts_active_created_idx on public.platform_posts(active,created_at desc);
alter table public.platform_posts enable row level security;
revoke all on public.platform_posts from anon,authenticated;

create or replace function public.get_platform_posts(p_limit integer default 3)
returns table(id uuid,body text,image_url text,cta_label text,cta_url text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  return query select p.id,p.body::text,p.image_url::text,p.cta_label::text,p.cta_url::text,p.created_at
    from public.platform_posts p where p.active=true and (p.pinned_until is null or p.pinned_until>now())
    order by p.created_at desc limit least(greatest(coalesce(p_limit,3),1),5);
end; $$;
revoke execute on function public.get_platform_posts(integer) from public,anon;
grant execute on function public.get_platform_posts(integer) to authenticated;

create or replace function public.admin_list_platform_posts()
returns setof public.platform_posts language plpgsql stable security definer set search_path='' as $$
begin perform private.require_admin(array['super_admin','admin','analyst']); return query select * from public.platform_posts order by created_at desc limit 100; end; $$;
revoke execute on function public.admin_list_platform_posts() from public,anon;
grant execute on function public.admin_list_platform_posts() to authenticated;

create or replace function public.admin_create_platform_post(p_body text,p_image_url text default null,p_cta_label text default null,p_cta_url text default null,p_pinned_until timestamptz default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_after jsonb;
begin
  perform private.require_admin(array['super_admin']);
  if char_length(trim(coalesce(p_body,''))) not between 1 and 1600 then raise exception 'Post must be 1–1600 characters'; end if;
  if nullif(trim(coalesce(p_image_url,'')),'') is not null and p_image_url !~* '^https?://' then raise exception 'Image URL must use http/https'; end if;
  if nullif(trim(coalesce(p_cta_url,'')),'') is not null and p_cta_url !~* '^https?://' then raise exception 'CTA URL must use http/https'; end if;
  insert into public.platform_posts(body,image_url,cta_label,cta_url,pinned_until,created_by)
    values(trim(p_body),nullif(trim(coalesce(p_image_url,'')),''),nullif(trim(coalesce(p_cta_label,'')),''),nullif(trim(coalesce(p_cta_url,'')),''),p_pinned_until,auth.uid()) returning id into v_id;
  insert into public.user_notifications(user_id,type,title,body,actor_id,entity_type,entity_id,link,metadata)
    select p.user_id,'system','CodaVybes update',left(trim(p_body),400),auth.uid(),'platform_post',v_id,'/home',jsonb_build_object('platform_post',true)
    from public.profiles p
    where p.onboarding_complete=true and private.account_is_active(p.user_id) and private.notification_allowed(p.user_id,'system');
  select to_jsonb(x) into v_after from public.platform_posts x where x.id=v_id;
  perform private.audit_admin('platform_post_create','platform_post',v_id::text,null,v_after,'Super-admin feed broadcast');
  return v_after;
end; $$;
revoke execute on function public.admin_create_platform_post(text,text,text,text,timestamptz) from public,anon;
grant execute on function public.admin_create_platform_post(text,text,text,text,timestamptz) to authenticated;

create or replace function public.admin_set_platform_post_active(p_id uuid,p_active boolean,p_reason text default 'Platform post status')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin']);
  select to_jsonb(x) into v_before from public.platform_posts x where x.id=p_id for update;
  if v_before is null then raise exception 'Platform post not found'; end if;
  update public.platform_posts set active=p_active,updated_at=now() where id=p_id;
  select to_jsonb(x) into v_after from public.platform_posts x where x.id=p_id;
  perform private.audit_admin('platform_post_status','platform_post',p_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_set_platform_post_active(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_platform_post_active(uuid,boolean,text) to authenticated;

commit;
