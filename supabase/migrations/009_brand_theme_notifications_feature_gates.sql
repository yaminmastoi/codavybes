begin;

-- VYBE V9 — premium theme preferences, system-notification preference,
-- and reliable user-facing commerce capability gates.

alter table public.user_preferences
  add column if not exists theme_preference text not null default 'light'
    check (theme_preference in ('light','dark','system')),
  add column if not exists system_notifications boolean not null default false;

create or replace function public.update_my_preferences(p_patch jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_row public.user_preferences%rowtype; v_theme text;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.account_is_active(v_user) then raise exception 'Account restricted'; end if;
  insert into public.user_preferences(user_id) values(v_user) on conflict(user_id) do nothing;
  v_theme:=coalesce(nullif(p_patch->>'theme_preference',''),(select theme_preference from public.user_preferences where user_id=v_user));
  if v_theme not in ('light','dark','system') then raise exception 'Invalid theme preference'; end if;
  update public.user_preferences set
    in_app_notifications=coalesce((p_patch->>'in_app_notifications')::boolean,in_app_notifications),
    aura_notifications=coalesce((p_patch->>'aura_notifications')::boolean,aura_notifications),
    chat_notifications=coalesce((p_patch->>'chat_notifications')::boolean,chat_notifications),
    room_notifications=coalesce((p_patch->>'room_notifications')::boolean,room_notifications),
    meet_notifications=coalesce((p_patch->>'meet_notifications')::boolean,meet_notifications),
    commerce_notifications=coalesce((p_patch->>'commerce_notifications')::boolean,commerce_notifications),
    marketing_notifications=coalesce((p_patch->>'marketing_notifications')::boolean,marketing_notifications),
    show_online_status=coalesce((p_patch->>'show_online_status')::boolean,show_online_status),
    reduce_motion=coalesce((p_patch->>'reduce_motion')::boolean,reduce_motion),
    sound_effects=coalesce((p_patch->>'sound_effects')::boolean,sound_effects),
    system_notifications=coalesce((p_patch->>'system_notifications')::boolean,system_notifications),
    theme_preference=v_theme,
    updated_at=now()
  where user_id=v_user
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;
revoke execute on function public.update_my_preferences(jsonb) from public,anon;
grant execute on function public.update_my_preferences(jsonb) to authenticated;

-- Make all user-visible commerce capabilities explicit in one trusted summary.
create or replace function public.get_my_commerce_summary()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  perform private.ensure_vybe_wallet(v_user);
  select jsonb_build_object(
    'wallet',(select to_jsonb(w) from public.vybe_wallets w where w.user_id=v_user),
    'config',(select to_jsonb(m) from public.monetization_config m where m.id=1),
    'subscription',(select to_jsonb(s) from public.user_subscriptions s where s.user_id=v_user and s.status='active' and s.ends_at>now()),
    'owned',coalesce((select jsonb_agg(jsonb_build_object('item_id',e.item_id,'slug',i.slug,'name',i.name,'category',i.category,'granted_at',e.granted_at)) from public.user_entitlements e join public.shop_items i on i.id=e.item_id where e.user_id=v_user),'[]'::jsonb),
    'equipped',coalesce((select jsonb_agg(jsonb_build_object('category',q.category,'item_id',q.item_id,'slug',i.slug,'name',i.name)) from public.user_equipped_cosmetics q join public.shop_items i on i.id=q.item_id where q.user_id=v_user),'[]'::jsonb),
    'shop_enabled',coalesce((select enabled from public.feature_flags where key='shop'),false),
    'vybe_plus_enabled',coalesce((select enabled from public.feature_flags where key='vybe_plus'),false),
    'topups_enabled',coalesce((select topups_enabled from public.monetization_config where id=1),false)
  ) into v_result;
  return v_result;
end; $$;
revoke execute on function public.get_my_commerce_summary() from public,anon;
grant execute on function public.get_my_commerce_summary() to authenticated;



alter table public.interests alter column icon set default 'sparkles';

create or replace function public.admin_upsert_interest(p_id bigint,p_slug text,p_label text,p_icon text,p_active boolean,p_sort integer,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_role text; v_id bigint; v_before jsonb; v_after jsonb; v_icon text;
begin
  v_role:=private.require_admin(array['super_admin','admin']);
  v_icon:=case when coalesce(trim(p_icon),'') in ('gamepad','trophy','gauge','music','film','laugh','brain','moon','cpu','rocket','dumbbell','camera','palette','book','plane','food','sparkles') then trim(p_icon) else 'sparkles' end;
  if p_id is not null then select to_jsonb(i) into v_before from public.interests i where i.id=p_id; end if;
  if p_id is null then
    insert into public.interests(slug,label,icon,active,sort_order) values(lower(trim(p_slug)),trim(p_label),v_icon,p_active,coalesce(p_sort,0)) returning id into v_id;
  else
    update public.interests set slug=lower(trim(p_slug)),label=trim(p_label),icon=v_icon,active=p_active,sort_order=coalesce(p_sort,sort_order) where id=p_id returning id into v_id;
  end if;
  select to_jsonb(i) into v_after from public.interests i where i.id=v_id;
  perform private.audit_admin('interest_upsert','interest',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_interest(bigint,text,text,text,boolean,integer,text) from public,anon;
grant execute on function public.admin_upsert_interest(bigint,text,text,text,boolean,integer,text) to authenticated;

-- Replace legacy decorative emoji interest markers with stable semantic icon keys.
update public.interests set icon=case slug
  when 'gaming' then 'gamepad'
  when 'football' then 'trophy'
  when 'f1' then 'gauge'
  when 'music' then 'music'
  when 'movies' then 'film'
  when 'memes' then 'laugh'
  when 'deep_talks' then 'brain'
  when 'night_owls' then 'moon'
  when 'tech' then 'cpu'
  when 'startups' then 'rocket'
  when 'gym' then 'dumbbell'
  when 'photography' then 'camera'
  when 'art' then 'palette'
  when 'books' then 'book'
  when 'travel' then 'plane'
  when 'food' then 'food'
  else case when icon ~ '^[a-z_]+$' then icon else 'sparkles' end
end;

-- Ensure notification streams are available to Supabase Realtime clients.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='user_notifications') then
      execute 'alter publication supabase_realtime add table public.user_notifications';
    end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='announcements') then
      execute 'alter publication supabase_realtime add table public.announcements';
    end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='feature_flags') then
      execute 'alter publication supabase_realtime add table public.feature_flags';
    end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='monetization_config') then
      execute 'alter publication supabase_realtime add table public.monetization_config';
    end if;
  end if;
end $$;

commit;
