-- CodaVybes V13.12 — reliable For You inventory and short-feed promotions.
-- Run once AFTER migration 018.

begin;

-- Every existing active public Moment is eligible for For You. The current
-- ranking function determines order; this legacy flag must not hide inventory.
update public.aura_targets
set fyp_eligible = true
where target_type = 'post'
  and status = 'active'
  and visibility = 'public'
  and fyp_eligible is distinct from true;

create index if not exists aura_targets_public_feed_idx
  on public.aura_targets(created_at desc)
  where target_type = 'post' and status = 'active' and visibility = 'public';

-- Reinforce the all-public-post FYP contract even when an older Aura migration
-- was the last function definition applied to the production database.
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
  if not private.account_is_active(v_user) then raise exception 'Account restricted'; end if;
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

-- An already-live campaign means the owner intended feed ads to run. This
-- repairs installations where a campaign was saved while the separate global
-- switch remained off. The switch can still be turned off later from HQ.
update public.monetization_config c
set ads_enabled=true,updated_at=now()
where c.id=1
  and c.ads_enabled=false
  and exists(
    select 1 from public.sponsored_promotions p
    where p.active=true
      and p.starts_at<=now()
      and (p.ends_at is null or p.ends_at>now())
  );

-- Keep the server as the source of truth for the global Feed ads switch.
create or replace function public.get_active_sponsorships(p_limit integer default 6)
returns table(id uuid,brand_name text,headline text,body text,image_url text,destination_url text,cta_label text,priority integer,min_age integer)
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  if not coalesce((select c.ads_enabled from public.monetization_config c where c.id=1),false) then return; end if;

  return query
  select p.id,p.brand_name::text,p.headline::text,p.body::text,p.image_url::text,p.destination_url::text,p.cta_label::text,p.priority,p.min_age
  from public.sponsored_promotions p
  where p.active=true
    and coalesce(private.user_age(v_user),0)>=p.min_age
    and p.starts_at<=now()
    and (p.ends_at is null or p.ends_at>now())
  order by p.priority desc,md5(p.id::text||v_user::text||current_date::text)
  limit least(greatest(coalesce(p_limit,6),1),12);
end;
$$;

revoke execute on function public.get_active_sponsorships(integer) from public,anon;
grant execute on function public.get_active_sponsorships(integer) to authenticated;

commit;
