begin;

-- VYBE V8 — user settings, in-app notifications, VYBE Coins, Shop and VYBE+.
-- Aura remains earned reputation and can never be purchased through this economy.

-- ---------------------------------------------------------------------------
-- USER SETTINGS
-- ---------------------------------------------------------------------------
create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  in_app_notifications boolean not null default true,
  aura_notifications boolean not null default true,
  chat_notifications boolean not null default true,
  room_notifications boolean not null default true,
  meet_notifications boolean not null default true,
  commerce_notifications boolean not null default true,
  marketing_notifications boolean not null default false,
  show_online_status boolean not null default true,
  reduce_motion boolean not null default false,
  sound_effects boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.user_preferences enable row level security;
revoke all on public.user_preferences from anon, authenticated;
grant select on public.user_preferences to authenticated;

drop policy if exists "read own preferences" on public.user_preferences;
create policy "read own preferences" on public.user_preferences
for select to authenticated using(user_id = auth.uid());

create or replace function public.get_my_preferences()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_row public.user_preferences%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  insert into public.user_preferences(user_id) values(v_user) on conflict(user_id) do nothing;
  select * into v_row from public.user_preferences where user_id=v_user;
  return to_jsonb(v_row);
end; $$;
revoke execute on function public.get_my_preferences() from public,anon;
grant execute on function public.get_my_preferences() to authenticated;

create or replace function public.update_my_preferences(p_patch jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_row public.user_preferences%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.account_is_active(v_user) then raise exception 'Account restricted'; end if;
  insert into public.user_preferences(user_id) values(v_user) on conflict(user_id) do nothing;
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
    updated_at=now()
  where user_id=v_user
  returning * into v_row;
  return to_jsonb(v_row);
end; $$;
revoke execute on function public.update_my_preferences(jsonb) from public,anon;
grant execute on function public.update_my_preferences(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- IN-APP NOTIFICATIONS
-- ---------------------------------------------------------------------------
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check(type in ('aura','chat','room','meet','bond','system','shop','plus')),
  title text not null check(char_length(title) between 1 and 100),
  body text not null default '' check(char_length(body)<=400),
  actor_id uuid references auth.users(id) on delete set null,
  entity_type text,
  entity_id uuid,
  link text,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists user_notifications_user_created_idx on public.user_notifications(user_id,created_at desc);
create index if not exists user_notifications_unread_idx on public.user_notifications(user_id,created_at desc) where read_at is null;

alter table public.user_notifications enable row level security;
revoke all on public.user_notifications from anon,authenticated;
grant select on public.user_notifications to authenticated;

drop policy if exists "read own notifications" on public.user_notifications;
create policy "read own notifications" on public.user_notifications for select to authenticated using(user_id=auth.uid());
drop policy if exists "mark own notifications" on public.user_notifications;
-- Read-state changes are only exposed through constrained RPCs; no direct client UPDATE grant.

create or replace function private.notification_allowed(p_user uuid,p_type text)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce((select p.in_app_notifications and case p_type
    when 'aura' then p.aura_notifications
    when 'chat' then p.chat_notifications
    when 'room' then p.room_notifications
    when 'meet' then p.meet_notifications
    when 'shop' then p.commerce_notifications
    when 'plus' then p.commerce_notifications
    else true end
    from public.user_preferences p where p.user_id=p_user),true);
$$;
revoke execute on function private.notification_allowed(uuid,text) from public,anon,authenticated;

create or replace function private.push_notification(
  p_user uuid,p_type text,p_title text,p_body text default '',p_actor uuid default null,
  p_entity_type text default null,p_entity_id uuid default null,p_link text default null,p_metadata jsonb default '{}'::jsonb
) returns void language plpgsql security definer set search_path='' as $$
begin
  if p_user is null or not private.notification_allowed(p_user,p_type) then return; end if;
  insert into public.user_notifications(user_id,type,title,body,actor_id,entity_type,entity_id,link,metadata)
  values(p_user,p_type,left(p_title,100),left(coalesce(p_body,''),400),p_actor,p_entity_type,p_entity_id,p_link,coalesce(p_metadata,'{}'::jsonb));
end; $$;
revoke execute on function private.push_notification(uuid,text,text,text,uuid,text,uuid,text,jsonb) from public,anon,authenticated;

create or replace function public.get_my_notifications(p_limit integer default 50,p_offset integer default 0)
returns table(id uuid,type text,title text,body text,actor_id uuid,actor_username text,actor_display_name text,link text,metadata jsonb,read_at timestamptz,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  return query select n.id,n.type,n.title,n.body,n.actor_id,p.username,p.display_name,n.link,n.metadata,n.read_at,n.created_at
  from public.user_notifications n left join public.profiles p on p.user_id=n.actor_id
  where n.user_id=v_user order by n.created_at desc limit least(greatest(coalesce(p_limit,50),1),100) offset greatest(coalesce(p_offset,0),0);
end; $$;
revoke execute on function public.get_my_notifications(integer,integer) from public,anon;
grant execute on function public.get_my_notifications(integer,integer) to authenticated;

create or replace function public.get_my_unread_notification_count()
returns integer language sql stable security definer set search_path='' as $$
  select count(*)::integer from public.user_notifications where user_id=auth.uid() and read_at is null;
$$;
revoke execute on function public.get_my_unread_notification_count() from public,anon;
grant execute on function public.get_my_unread_notification_count() to authenticated;

create or replace function public.mark_notification_read(p_notification uuid)
returns void language plpgsql security definer set search_path='' as $$
begin update public.user_notifications set read_at=coalesce(read_at,now()) where id=p_notification and user_id=auth.uid(); end; $$;
revoke execute on function public.mark_notification_read(uuid) from public,anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;

create or replace function public.mark_all_notifications_read()
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer;
begin
  update public.user_notifications set read_at=now() where user_id=auth.uid() and read_at is null;
  get diagnostics v_count=row_count; return v_count;
end; $$;
revoke execute on function public.mark_all_notifications_read() from public,anon;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- Event-backed notification triggers.
create or replace function private.notify_aura_event() returns trigger language plpgsql security definer set search_path='' as $$
declare v_name text;
begin
  if new.status='counted' and new.amount>0 and new.giver_id is not null and new.giver_id<>new.receiver_id then
    select coalesce(display_name,username,'Someone') into v_name from public.profiles where user_id=new.giver_id;
    perform private.push_notification(new.receiver_id,'aura','⚡ Aura +',v_name||' gave you +'||new.amount||' Aura.',new.giver_id,'aura_target',new.target_id,'/you',jsonb_build_object('amount',new.amount,'source',new.source));
  end if; return new;
end; $$;
drop trigger if exists v8_notify_aura on public.aura_events;
create trigger v8_notify_aura after insert on public.aura_events for each row execute function private.notify_aura_event();

create or replace function private.notify_chat_message() returns trigger language plpgsql security definer set search_path='' as $$
declare r record; v_name text;
begin
  if new.kind<>'text' then return new; end if;
  select coalesce(display_name,username,'Someone') into v_name from public.profiles where user_id=new.sender_id;
  for r in select cm.user_id from public.conversation_members cm where cm.conversation_id=new.conversation_id and cm.status='active' and cm.user_id<>new.sender_id and (cm.muted_until is null or cm.muted_until<now()) loop
    perform private.push_notification(r.user_id,'chat',v_name,left(new.body,180),new.sender_id,'conversation',new.conversation_id,'/chats/'||new.conversation_id::text,jsonb_build_object('message_id',new.id));
  end loop; return new;
end; $$;
drop trigger if exists v8_notify_message on public.messages;
create trigger v8_notify_message after insert on public.messages for each row execute function private.notify_chat_message();

create or replace function private.notify_meet_request() returns trigger language plpgsql security definer set search_path='' as $$
declare v_name text;
begin
  if new.status='pending' then
    select coalesce(display_name,username,'Someone') into v_name from public.profiles where user_id=new.sender_id;
    perform private.push_notification(new.receiver_id,'meet','👀 Someone wants to Meet',v_name||' is a '||new.match_score||'% Vibe Match.',new.sender_id,'meet_request',new.id,'/discover',jsonb_build_object('match_score',new.match_score));
  end if; return new;
end; $$;
drop trigger if exists v8_notify_meet on public.meet_requests;
create trigger v8_notify_meet after insert on public.meet_requests for each row execute function private.notify_meet_request();

create or replace function private.notify_room_invite() returns trigger language plpgsql security definer set search_path='' as $$
declare v_host uuid; v_name text;
begin
  if new.status='invited' then
    select created_by into v_host from public.rooms where id=new.room_id;
    select coalesce(display_name,username,'Someone') into v_name from public.profiles where user_id=v_host;
    perform private.push_notification(new.user_id,'room','🎮 Room invite',v_name||' invited you to a Room.',v_host,'room',new.room_id,'/rooms/'||new.room_id::text,'{}'::jsonb);
  end if; return new;
end; $$;
drop trigger if exists v8_notify_room_invite on public.room_members;
create trigger v8_notify_room_invite after insert on public.room_members for each row execute function private.notify_room_invite();

-- ---------------------------------------------------------------------------
-- PUBLIC MOMENT REACTIONS + REPLIES (removes dead feed buttons)
-- ---------------------------------------------------------------------------
create table if not exists public.moment_reactions (
  target_id uuid not null references public.aura_targets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null default '❤️' check(char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key(target_id,user_id)
);
create table if not exists public.moment_comments (
  id uuid primary key default gen_random_uuid(),
  target_id uuid not null references public.aura_targets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check(char_length(body) between 1 and 800),
  created_at timestamptz not null default now()
);
create index if not exists moment_comments_target_idx on public.moment_comments(target_id,created_at);

alter table public.moment_reactions enable row level security;
alter table public.moment_comments enable row level security;
revoke all on public.moment_reactions,public.moment_comments from anon,authenticated;
grant select on public.moment_reactions,public.moment_comments to authenticated;

create policy "read reactions on visible moments" on public.moment_reactions for select to authenticated using(exists(select 1 from public.aura_targets t where t.id=target_id and t.status='active' and t.visibility='public' and public.current_user_age_compatible(t.owner_id) and not public.users_are_blocked(auth.uid(),t.owner_id)));
create policy "read comments on visible moments" on public.moment_comments for select to authenticated using(exists(select 1 from public.aura_targets t where t.id=target_id and t.status='active' and t.visibility='public' and public.current_user_age_compatible(t.owner_id) and not public.users_are_blocked(auth.uid(),t.owner_id)));

create or replace function public.toggle_moment_reaction(p_target uuid,p_emoji text default '❤️')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_exists boolean; v_count integer;
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  if not exists(select 1 from public.aura_targets t where t.id=p_target and t.status='active' and t.visibility='public' and private.age_compatible(v_user,t.owner_id) and not public.users_are_blocked(v_user,t.owner_id)) then raise exception 'Moment unavailable'; end if;
  select exists(select 1 from public.moment_reactions where target_id=p_target and user_id=v_user) into v_exists;
  if v_exists then delete from public.moment_reactions where target_id=p_target and user_id=v_user;
  else insert into public.moment_reactions(target_id,user_id,emoji) values(p_target,v_user,left(coalesce(nullif(p_emoji,''),'❤️'),16)); end if;
  select count(*)::integer into v_count from public.moment_reactions where target_id=p_target;
  return jsonb_build_object('reacted',not v_exists,'count',v_count);
end; $$;
revoke execute on function public.toggle_moment_reaction(uuid,text) from public,anon;
grant execute on function public.toggle_moment_reaction(uuid,text) to authenticated;

create or replace function public.add_moment_comment(p_target uuid,p_body text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  if char_length(trim(coalesce(p_body,''))) not between 1 and 800 then raise exception 'Reply must be 1–800 characters'; end if;
  if not exists(select 1 from public.aura_targets t where t.id=p_target and t.status='active' and t.visibility='public' and private.age_compatible(v_user,t.owner_id) and not public.users_are_blocked(v_user,t.owner_id)) then raise exception 'Moment unavailable'; end if;
  if (select count(*) from public.moment_comments where user_id=v_user and created_at>=now()-interval '1 minute')>=12 then raise exception 'Slow down for a moment'; end if;
  insert into public.moment_comments(target_id,user_id,body) values(p_target,v_user,trim(p_body)) returning id into v_id;
  return jsonb_build_object('id',v_id,'body',trim(p_body),'created_at',now());
end; $$;
revoke execute on function public.add_moment_comment(uuid,text) from public,anon;
grant execute on function public.add_moment_comment(uuid,text) to authenticated;

create or replace function public.get_moment_thread(p_target uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.aura_targets t where t.id=p_target and t.status='active' and t.visibility='public' and private.age_compatible(v_user,t.owner_id) and not public.users_are_blocked(v_user,t.owner_id)) then raise exception 'Moment unavailable'; end if;
  select jsonb_build_object(
    'reaction_count',(select count(*) from public.moment_reactions where target_id=p_target),
    'viewer_reacted',exists(select 1 from public.moment_reactions where target_id=p_target and user_id=v_user),
    'comment_count',(select count(*) from public.moment_comments where target_id=p_target),
    'comments',coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'body',c.body,'created_at',c.created_at,'user_id',c.user_id,'username',p.username,'display_name',p.display_name) order by c.created_at) from public.moment_comments c join public.profiles p on p.user_id=c.user_id where c.target_id=p_target),'[]'::jsonb)
  ) into v_result;
  return v_result;
end; $$;
revoke execute on function public.get_moment_thread(uuid) from public,anon;
grant execute on function public.get_moment_thread(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- VYBE COINS + COMMERCE
-- ---------------------------------------------------------------------------
alter table public.monetization_config add column if not exists topups_enabled boolean not null default true;
alter table public.monetization_config add column if not exists coin_name text not null default 'VYBE Coins';
alter table public.monetization_config add column if not exists coin_symbol text not null default 'VC';
alter table public.monetization_config add column if not exists welcome_coins integer not null default 100 check(welcome_coins between 0 and 100000);
alter table public.monetization_config add column if not exists vybe_plus_price_coins integer not null default 499 check(vybe_plus_price_coins between 0 and 1000000);
alter table public.monetization_config add column if not exists payment_provider text not null default 'unconfigured';

update public.feature_flags set enabled=true,updated_at=now() where key in('shop','vybe_plus');
update public.monetization_config set vybe_plus_enabled=true,topups_enabled=true where id=1;

create table if not exists public.vybe_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  coin_balance bigint not null default 0 check(coin_balance>=0),
  lifetime_topup_coins bigint not null default 0 check(lifetime_topup_coins>=0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount integer not null check(amount<>0),
  entry_type text not null check(entry_type in ('welcome','topup','purchase','refund','admin','plus')),
  reference_type text,
  reference_id uuid,
  note text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists wallet_ledger_user_idx on public.wallet_ledger(user_id,created_at desc);

create table if not exists public.topup_packages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check(slug ~ '^[a-z0-9_]{2,80}$'),
  name text not null,
  coins integer not null check(coins>0),
  bonus_coins integer not null default 0 check(bonus_coins>=0),
  price_cents integer not null check(price_cents>0),
  currency text not null default 'USD' check(char_length(currency)=3),
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into public.topup_packages(slug,name,coins,bonus_coins,price_cents,currency,active,sort_order) values
('spark','Spark Pack',250,0,199,'USD',true,10),
('glow','Glow Pack',650,50,499,'USD',true,20),
('main_character','Main Character Pack',1400,200,999,'USD',true,30),
('lore_pack','Lore Pack',3200,800,1999,'USD',true,40)
on conflict(slug) do update set name=excluded.name,coins=excluded.coins,bonus_coins=excluded.bonus_coins,price_cents=excluded.price_cents,currency=excluded.currency,active=true,sort_order=excluded.sort_order;

create table if not exists public.checkout_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  order_type text not null check(order_type in ('topup','vybe_plus')),
  package_id uuid references public.topup_packages(id) on delete set null,
  amount_cents integer not null check(amount_cents>=0),
  currency text not null check(char_length(currency)=3),
  coins integer not null default 0 check(coins>=0),
  provider text not null default 'unconfigured',
  provider_reference text,
  status text not null default 'pending' check(status in ('pending','paid','failed','cancelled')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
create index if not exists checkout_orders_user_idx on public.checkout_orders(user_id,created_at desc);

alter table public.shop_items add column if not exists price_coins integer not null default 0 check(price_coins>=0);
update public.shop_items set price_coins=greatest(99,price_cents) where price_coins=0 and price_cents>0;

insert into public.shop_items(slug,name,category,description,price_cents,currency,price_coins,active,sort_order) values
('starter_spark','Starter Spark','aura_effect','A subtle first cosmetic to test your VYBE collection.',75,'USD',75,true,5),
('electric_aura','Electric Aura','aura_effect','A crisp electric profile Aura effect.',199,'USD',199,true,10),
('galaxy_aura','Galaxy Aura','aura_effect','Deep-space glow around your earned Aura.',299,'USD',299,true,20),
('gold_frame','Founders Gold Frame','avatar_frame','A premium metallic frame around your avatar.',249,'USD',249,true,30),
('midnight_profile','Midnight Profile','profile','Minimal black-and-gold profile treatment.',199,'USD',199,true,40),
('vip_room','VIP Room Theme','room_theme','A polished private-club Room theme.',349,'USD',349,true,50)
on conflict(slug) do update set name=excluded.name,description=excluded.description,price_coins=excluded.price_coins,active=true,sort_order=excluded.sort_order;

create table if not exists public.user_entitlements (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.shop_items(id) on delete cascade,
  source text not null default 'shop' check(source in ('shop','gift','admin','promo')),
  granted_at timestamptz not null default now(),
  primary key(user_id,item_id)
);
create table if not exists public.user_equipped_cosmetics (
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check(category in ('profile','aura_effect','room_theme','avatar_frame','game_pack')),
  item_id uuid not null references public.shop_items(id) on delete cascade,
  equipped_at timestamptz not null default now(),
  primary key(user_id,category)
);
create table if not exists public.user_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'vybe_plus' check(plan='vybe_plus'),
  status text not null default 'active' check(status in ('active','expired','cancelled')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  source text not null default 'coins' check(source in ('coins','payment','admin','promo')),
  updated_at timestamptz not null default now()
);

alter table public.vybe_wallets enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.topup_packages enable row level security;
alter table public.checkout_orders enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.user_equipped_cosmetics enable row level security;
alter table public.user_subscriptions enable row level security;
revoke all on public.vybe_wallets,public.wallet_ledger,public.topup_packages,public.checkout_orders,public.user_entitlements,public.user_equipped_cosmetics,public.user_subscriptions from anon,authenticated;
grant select on public.topup_packages to authenticated;
grant select on public.vybe_wallets,public.wallet_ledger,public.checkout_orders,public.user_entitlements,public.user_equipped_cosmetics,public.user_subscriptions to authenticated;

create policy "read own wallet" on public.vybe_wallets for select to authenticated using(user_id=auth.uid());
create policy "read own wallet ledger" on public.wallet_ledger for select to authenticated using(user_id=auth.uid());
create policy "read topup packages" on public.topup_packages for select to authenticated using(active=true);
create policy "read own checkouts" on public.checkout_orders for select to authenticated using(user_id=auth.uid());
create policy "read own entitlements" on public.user_entitlements for select to authenticated using(user_id=auth.uid());
create policy "read own equipped" on public.user_equipped_cosmetics for select to authenticated using(user_id=auth.uid());
create policy "read own subscriptions" on public.user_subscriptions for select to authenticated using(user_id=auth.uid());

create or replace function private.ensure_vybe_wallet(p_user uuid)
returns void language plpgsql security definer set search_path='' as $$
declare v_welcome integer:=100; v_rows integer:=0;
begin
  select coalesce(welcome_coins,100) into v_welcome from public.monetization_config where id=1;
  insert into public.vybe_wallets(user_id,coin_balance) values(p_user,v_welcome) on conflict(user_id) do nothing;
  get diagnostics v_rows = row_count;
  if v_rows > 0 then insert into public.wallet_ledger(user_id,amount,entry_type,note) values(p_user,v_welcome,'welcome','Welcome to VYBE'); end if;
  insert into public.user_preferences(user_id) values(p_user) on conflict(user_id) do nothing;
end; $$;
revoke execute on function private.ensure_vybe_wallet(uuid) from public,anon,authenticated;

-- Backfill and future profile creation.
select private.ensure_vybe_wallet(user_id) from public.profiles;
create or replace function private.v8_profile_bootstrap() returns trigger language plpgsql security definer set search_path='' as $$
begin perform private.ensure_vybe_wallet(new.user_id); return new; end; $$;
drop trigger if exists v8_profile_bootstrap on public.profiles;
create trigger v8_profile_bootstrap after insert on public.profiles for each row execute function private.v8_profile_bootstrap();

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
    'vybe_plus_enabled',coalesce((select enabled from public.feature_flags where key='vybe_plus'),false)
  ) into v_result;
  return v_result;
end; $$;
revoke execute on function public.get_my_commerce_summary() from public,anon;
grant execute on function public.get_my_commerce_summary() to authenticated;

create or replace function public.get_my_wallet_ledger(p_limit integer default 30)
returns setof public.wallet_ledger language plpgsql stable security definer set search_path='' as $$
begin if auth.uid() is null then raise exception 'Authentication required'; end if; return query select * from public.wallet_ledger where user_id=auth.uid() order by created_at desc limit least(greatest(coalesce(p_limit,30),1),100); end; $$;
revoke execute on function public.get_my_wallet_ledger(integer) from public,anon;
grant execute on function public.get_my_wallet_ledger(integer) to authenticated;

create or replace function public.create_topup_checkout(p_package uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_pkg public.topup_packages%rowtype; v_cfg public.monetization_config%rowtype; v_order uuid;
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  select * into v_pkg from public.topup_packages where id=p_package and active=true;
  if v_pkg.id is null then raise exception 'Top-up package unavailable'; end if;
  select * into v_cfg from public.monetization_config where id=1;
  if not v_cfg.topups_enabled then raise exception 'Top-ups are disabled right now'; end if;
  if coalesce(v_cfg.payment_provider,'unconfigured')='unconfigured' then
    return jsonb_build_object('checkout_ready',false,'reason','payment_provider_unconfigured','message','Top-up UI is live. Connect a payment provider in VYBE HQ/server before accepting real money.','coins',v_pkg.coins+v_pkg.bonus_coins,'price_cents',v_pkg.price_cents,'currency',v_pkg.currency);
  end if;
  insert into public.checkout_orders(user_id,order_type,package_id,amount_cents,currency,coins,provider)
  values(v_user,'topup',v_pkg.id,v_pkg.price_cents,v_pkg.currency,v_pkg.coins+v_pkg.bonus_coins,v_cfg.payment_provider) returning id into v_order;
  return jsonb_build_object('checkout_ready',true,'order_id',v_order,'provider',v_cfg.payment_provider,'coins',v_pkg.coins+v_pkg.bonus_coins,'amount_cents',v_pkg.price_cents,'currency',v_pkg.currency);
end; $$;
revoke execute on function public.create_topup_checkout(uuid) from public,anon;
grant execute on function public.create_topup_checkout(uuid) to authenticated;

create or replace function public.buy_shop_item(p_item uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_item public.shop_items%rowtype; v_wallet public.vybe_wallets%rowtype; v_balance bigint;
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  if not coalesce((select enabled from public.feature_flags where key='shop'),false) then raise exception 'Shop is disabled'; end if;
  perform private.ensure_vybe_wallet(v_user);
  select * into v_item from public.shop_items where id=p_item and active=true;
  if v_item.id is null then raise exception 'Item unavailable'; end if;
  if exists(select 1 from public.user_entitlements where user_id=v_user and item_id=p_item) then return jsonb_build_object('already_owned',true,'balance',(select coin_balance from public.vybe_wallets where user_id=v_user)); end if;
  if v_item.price_coins<=0 then raise exception 'This item is not configured for VYBE Coins'; end if;
  select * into v_wallet from public.vybe_wallets where user_id=v_user for update;
  if v_wallet.coin_balance<v_item.price_coins then return jsonb_build_object('purchased',false,'insufficient_balance',true,'balance',v_wallet.coin_balance,'needed',v_item.price_coins-v_wallet.coin_balance); end if;
  update public.vybe_wallets set coin_balance=coin_balance-v_item.price_coins,updated_at=now() where user_id=v_user returning coin_balance into v_balance;
  insert into public.wallet_ledger(user_id,amount,entry_type,reference_type,reference_id,note) values(v_user,-v_item.price_coins,'purchase','shop_item',v_item.id,'Purchased '||v_item.name);
  insert into public.user_entitlements(user_id,item_id,source) values(v_user,v_item.id,'shop');
  perform private.push_notification(v_user,'shop','🛍️ Added to your collection',v_item.name||' is now yours.',null,'shop_item',v_item.id,'/shop',jsonb_build_object('price_coins',v_item.price_coins));
  return jsonb_build_object('purchased',true,'balance',v_balance,'item',jsonb_build_object('id',v_item.id,'name',v_item.name,'category',v_item.category,'slug',v_item.slug));
end; $$;
revoke execute on function public.buy_shop_item(uuid) from public,anon;
grant execute on function public.buy_shop_item(uuid) to authenticated;

create or replace function public.equip_shop_item(p_item uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_item public.shop_items%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select i.* into v_item from public.shop_items i join public.user_entitlements e on e.item_id=i.id and e.user_id=v_user where i.id=p_item;
  if v_item.id is null then raise exception 'You do not own this item'; end if;
  insert into public.user_equipped_cosmetics(user_id,category,item_id) values(v_user,v_item.category,v_item.id)
  on conflict(user_id,category) do update set item_id=excluded.item_id,equipped_at=now();
  return jsonb_build_object('equipped',true,'category',v_item.category,'item_id',v_item.id,'name',v_item.name,'slug',v_item.slug);
end; $$;
revoke execute on function public.equip_shop_item(uuid) from public,anon;
grant execute on function public.equip_shop_item(uuid) to authenticated;

create or replace function public.subscribe_vybe_plus()
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_cfg public.monetization_config%rowtype; v_wallet public.vybe_wallets%rowtype; v_start timestamptz; v_end timestamptz; v_balance bigint;
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  if not coalesce((select enabled from public.feature_flags where key='vybe_plus'),false) then raise exception 'VYBE+ is disabled'; end if;
  select * into v_cfg from public.monetization_config where id=1;
  if not v_cfg.vybe_plus_enabled then raise exception 'VYBE+ is disabled'; end if;
  perform private.ensure_vybe_wallet(v_user);
  select * into v_wallet from public.vybe_wallets where user_id=v_user for update;
  if v_wallet.coin_balance<v_cfg.vybe_plus_price_coins then return jsonb_build_object('subscribed',false,'insufficient_balance',true,'balance',v_wallet.coin_balance,'needed',v_cfg.vybe_plus_price_coins-v_wallet.coin_balance); end if;
  select greatest(now(),coalesce((select ends_at from public.user_subscriptions where user_id=v_user and status='active'),now())) into v_start;
  v_end:=v_start+interval '30 days';
  update public.vybe_wallets set coin_balance=coin_balance-v_cfg.vybe_plus_price_coins,updated_at=now() where user_id=v_user returning coin_balance into v_balance;
  insert into public.wallet_ledger(user_id,amount,entry_type,note) values(v_user,-v_cfg.vybe_plus_price_coins,'plus','30 days VYBE+');
  insert into public.user_subscriptions(user_id,plan,status,starts_at,ends_at,source,updated_at) values(v_user,'vybe_plus','active',now(),v_end,'coins',now())
  on conflict(user_id) do update set status='active',starts_at=least(public.user_subscriptions.starts_at,now()),ends_at=v_end,source='coins',updated_at=now();
  perform private.push_notification(v_user,'plus','✦ VYBE+ activated','Your premium access is active until '||to_char(v_end,'Mon DD, YYYY')||'.',null,'subscription',null,'/vybe-plus',jsonb_build_object('ends_at',v_end));
  return jsonb_build_object('subscribed',true,'balance',v_balance,'ends_at',v_end);
end; $$;
revoke execute on function public.subscribe_vybe_plus() from public,anon;
grant execute on function public.subscribe_vybe_plus() to authenticated;

-- Verified payment settlement hook. Only server/service-role may execute it.
create or replace function public.settle_topup_order_server(p_order uuid,p_provider_reference text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_order public.checkout_orders%rowtype; v_balance bigint;
begin
  select * into v_order from public.checkout_orders where id=p_order for update;
  if v_order.id is null then raise exception 'Order unavailable'; end if;
  if v_order.order_type<>'topup' then raise exception 'Not a top-up order'; end if;
  if v_order.status='paid' then return jsonb_build_object('already_paid',true,'order_id',v_order.id); end if;
  if v_order.status<>'pending' then raise exception 'Order cannot be settled'; end if;
  perform private.ensure_vybe_wallet(v_order.user_id);
  update public.checkout_orders set status='paid',provider_reference=p_provider_reference,paid_at=now() where id=v_order.id;
  update public.vybe_wallets set coin_balance=coin_balance+v_order.coins,lifetime_topup_coins=lifetime_topup_coins+v_order.coins,updated_at=now() where user_id=v_order.user_id returning coin_balance into v_balance;
  insert into public.wallet_ledger(user_id,amount,entry_type,reference_type,reference_id,note) values(v_order.user_id,v_order.coins,'topup','checkout_order',v_order.id,'VYBE Coins top-up');
  perform private.push_notification(v_order.user_id,'shop','🪙 Top-up complete','+'||v_order.coins||' VC added to your wallet.',null,'checkout_order',v_order.id,'/wallet',jsonb_build_object('balance',v_balance));
  return jsonb_build_object('paid',true,'order_id',v_order.id,'coins',v_order.coins,'balance',v_balance);
end; $$;
revoke execute on function public.settle_topup_order_server(uuid,text) from public,anon,authenticated;
grant execute on function public.settle_topup_order_server(uuid,text) to service_role;

-- ---------------------------------------------------------------------------
-- V8 ADMIN COMMERCE CONTROLS
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_user_wallet(p_user uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin perform private.require_admin(array['super_admin','admin','moderator']); perform private.ensure_vybe_wallet(p_user); return (select to_jsonb(w) from public.vybe_wallets w where w.user_id=p_user); end; $$;
revoke execute on function public.admin_get_user_wallet(uuid) from public,anon;
grant execute on function public.admin_get_user_wallet(uuid) to authenticated;

create or replace function public.admin_adjust_user_coins(p_user uuid,p_amount integer,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if p_amount=0 or abs(p_amount)>1000000 then raise exception 'Invalid coin adjustment'; end if;
  perform private.ensure_vybe_wallet(p_user);
  select to_jsonb(w) into v_before from public.vybe_wallets w where w.user_id=p_user for update;
  if ((v_before->>'coin_balance')::bigint+p_amount)<0 then raise exception 'Adjustment would make wallet negative'; end if;
  update public.vybe_wallets set coin_balance=coin_balance+p_amount,updated_at=now() where user_id=p_user;
  insert into public.wallet_ledger(user_id,amount,entry_type,note) values(p_user,p_amount,'admin',coalesce(p_reason,'HQ coin adjustment'));
  select to_jsonb(w) into v_after from public.vybe_wallets w where w.user_id=p_user;
  perform private.audit_admin('coin_adjustment','user',p_user::text,v_before,v_after,p_reason,jsonb_build_object('amount',p_amount));
  return v_after;
end; $$;
revoke execute on function public.admin_adjust_user_coins(uuid,integer,text) from public,anon;
grant execute on function public.admin_adjust_user_coins(uuid,integer,text) to authenticated;

create or replace function public.admin_list_topup_packages()
returns setof public.topup_packages language plpgsql stable security definer set search_path='' as $$
begin perform private.require_admin(array['super_admin','admin','analyst']); return query select * from public.topup_packages order by sort_order,name; end; $$;
revoke execute on function public.admin_list_topup_packages() from public,anon;
grant execute on function public.admin_list_topup_packages() to authenticated;

create or replace function public.admin_upsert_topup_package(p_id uuid,p_slug text,p_name text,p_coins integer,p_bonus integer,p_price integer,p_currency text,p_active boolean,p_sort integer,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if p_coins<=0 or p_bonus<0 or p_price<=0 then raise exception 'Invalid package values'; end if;
  if p_id is not null then select to_jsonb(x) into v_before from public.topup_packages x where x.id=p_id; end if;
  if p_id is null then insert into public.topup_packages(slug,name,coins,bonus_coins,price_cents,currency,active,sort_order) values(lower(trim(p_slug)),trim(p_name),p_coins,p_bonus,p_price,upper(p_currency),p_active,p_sort) returning id into v_id;
  else update public.topup_packages set slug=lower(trim(p_slug)),name=trim(p_name),coins=p_coins,bonus_coins=p_bonus,price_cents=p_price,currency=upper(p_currency),active=p_active,sort_order=p_sort,updated_at=now() where id=p_id returning id into v_id; end if;
  select to_jsonb(x) into v_after from public.topup_packages x where x.id=v_id;
  perform private.audit_admin('topup_package_upsert','topup_package',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_topup_package(uuid,text,text,integer,integer,integer,text,boolean,integer,text) from public,anon;
grant execute on function public.admin_upsert_topup_package(uuid,text,text,integer,integer,integer,text,boolean,integer,text) to authenticated;

create or replace function public.admin_upsert_shop_item_v8(p_id uuid,p_slug text,p_name text,p_category text,p_description text,p_price_coins integer,p_price_cents integer,p_currency text,p_asset_url text,p_active boolean,p_sort integer,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if p_category not in('profile','aura_effect','room_theme','avatar_frame','game_pack') then raise exception 'Invalid shop category'; end if;
  if p_price_coins<0 or p_price_cents<0 then raise exception 'Invalid price'; end if;
  if p_id is not null then select to_jsonb(i) into v_before from public.shop_items i where i.id=p_id; end if;
  if p_id is null then insert into public.shop_items(slug,name,category,description,price_coins,price_cents,currency,asset_url,active,sort_order)
    values(lower(trim(p_slug)),trim(p_name),p_category,trim(coalesce(p_description,'')),p_price_coins,p_price_cents,upper(p_currency),nullif(trim(p_asset_url),''),p_active,coalesce(p_sort,0)) returning id into v_id;
  else update public.shop_items set slug=lower(trim(p_slug)),name=trim(p_name),category=p_category,description=trim(coalesce(p_description,'')),price_coins=p_price_coins,price_cents=p_price_cents,currency=upper(p_currency),asset_url=nullif(trim(p_asset_url),''),active=p_active,sort_order=coalesce(p_sort,sort_order),updated_at=now() where id=p_id returning id into v_id; end if;
  select to_jsonb(i) into v_after from public.shop_items i where i.id=v_id;
  perform private.audit_admin('shop_item_upsert','shop_item',v_id::text,v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_upsert_shop_item_v8(uuid,text,text,text,text,integer,integer,text,text,boolean,integer,text) from public,anon;
grant execute on function public.admin_upsert_shop_item_v8(uuid,text,text,text,text,integer,integer,text,text,boolean,integer,text) to authenticated;

create or replace function public.admin_update_commerce_v8(p_patch jsonb,p_reason text default 'Commerce settings update')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  select to_jsonb(c) into v_before from public.monetization_config c where id=1;
  update public.monetization_config set
    vybe_plus_enabled=coalesce((p_patch->>'vybe_plus_enabled')::boolean,vybe_plus_enabled),
    vybe_plus_price_cents=coalesce((p_patch->>'vybe_plus_price_cents')::integer,vybe_plus_price_cents),
    vybe_plus_price_coins=coalesce((p_patch->>'vybe_plus_price_coins')::integer,vybe_plus_price_coins),
    currency=coalesce(upper(p_patch->>'currency'),currency),
    topups_enabled=coalesce((p_patch->>'topups_enabled')::boolean,topups_enabled),
    coin_name=coalesce(nullif(trim(p_patch->>'coin_name'),''),coin_name),
    coin_symbol=coalesce(nullif(trim(p_patch->>'coin_symbol'),''),coin_symbol),
    welcome_coins=coalesce((p_patch->>'welcome_coins')::integer,welcome_coins),
    payment_provider=coalesce(nullif(trim(p_patch->>'payment_provider'),''),payment_provider),
    ads_enabled=coalesce((p_patch->>'ads_enabled')::boolean,ads_enabled),
    feed_ad_interval=coalesce((p_patch->>'feed_ad_interval')::integer,feed_ad_interval),
    gifting_enabled=coalesce((p_patch->>'gifting_enabled')::boolean,gifting_enabled),
    creator_marketplace_enabled=coalesce((p_patch->>'creator_marketplace_enabled')::boolean,creator_marketplace_enabled),
    sponsored_rooms_enabled=coalesce((p_patch->>'sponsored_rooms_enabled')::boolean,sponsored_rooms_enabled),
    updated_at=now() where id=1;
  select to_jsonb(c) into v_after from public.monetization_config c where id=1;
  perform private.audit_admin('commerce_config','config','monetization',v_before,v_after,p_reason);
  return v_after;
end; $$;
revoke execute on function public.admin_update_commerce_v8(jsonb,text) from public,anon;
grant execute on function public.admin_update_commerce_v8(jsonb,text) to authenticated;

-- User-safe public shop listing includes coin prices.
drop policy if exists "read active shop items" on public.shop_items;
create policy "read active shop items" on public.shop_items for select to authenticated using(active=true);

-- Announcement audience now respects the user's age band.
drop policy if exists "read live announcements" on public.announcements;
create policy "read live announcements" on public.announcements for select to authenticated using(
  active=true and starts_at<=now() and (ends_at is null or ends_at>now())
  and (audience='all' or audience=public.current_user_age_band())
);

-- Touch timestamps.
drop trigger if exists user_preferences_touch on public.user_preferences;
create trigger user_preferences_touch before update on public.user_preferences for each row execute function public.touch_updated_at();
drop trigger if exists vybe_wallets_touch on public.vybe_wallets;
create trigger vybe_wallets_touch before update on public.vybe_wallets for each row execute function public.touch_updated_at();
drop trigger if exists topup_packages_touch on public.topup_packages;
create trigger topup_packages_touch before update on public.topup_packages for each row execute function public.touch_updated_at();
drop trigger if exists user_subscriptions_touch on public.user_subscriptions;
create trigger user_subscriptions_touch before update on public.user_subscriptions for each row execute function public.touch_updated_at();

create or replace function public.get_public_moment(p_target uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select jsonb_build_object(
    'target_id',t.id,'author_id',t.owner_id,'content_text',t.content_text,'context_label',t.context_label,
    'aura_count',t.aura_count,'unique_givers',t.unique_givers,'is_aura_moment',t.is_aura_moment,'created_at',t.created_at,
    'username',p.username,'display_name',p.display_name,'author_aura',p.aura_total,'author_rank',public.get_aura_rank(p.aura_total),
    'viewer_has_aura',exists(select 1 from public.aura_events e where e.giver_id=v_user and e.target_id=t.id and e.source='peer' and e.status='counted')
  ) into v_result
  from public.aura_targets t join public.profiles p on p.user_id=t.owner_id
  where t.id=p_target and t.status='active' and t.visibility='public' and private.age_compatible(v_user,t.owner_id) and not public.users_are_blocked(v_user,t.owner_id);
  if v_result is null then raise exception 'Moment unavailable'; end if;
  return v_result;
end; $$;
revoke execute on function public.get_public_moment(uuid) from public,anon;
grant execute on function public.get_public_moment(uuid) to authenticated;

commit;
