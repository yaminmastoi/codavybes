-- VYBE V3: secure DMs + groups + realtime message surfaces + message Aura.
-- Prerequisites: 001_auth_onboarding.sql, 002_aura_engine.sql
--
-- Security model:
--   * Chat writes are RPC-only; browser cannot impersonate sender/member/owner.
--   * RLS permits SELECT only to active conversation members.
--   * Message Aura uses the existing immutable aura_events ledger.
--   * Private chat Aura Moments NEVER auto-promote into the public FYP.
--   * Blocking prevents new/direct DMs and hides users from people search.
--   * Reports are private and only service_role can read them directly.

begin;

create table if not exists public.chat_config (
  id smallint primary key default 1 check (id = 1),
  max_message_chars integer not null default 1200 check (max_message_chars between 100 and 5000),
  max_group_members integer not null default 20 check (max_group_members between 2 and 100),
  message_per_minute_limit integer not null default 30 check (message_per_minute_limit between 1 and 300),
  new_account_message_per_minute_limit integer not null default 10 check (new_account_message_per_minute_limit between 1 and 100),
  direct_chat_create_hour_limit integer not null default 20 check (direct_chat_create_hour_limit between 1 and 200),
  group_create_day_limit integer not null default 10 check (group_create_day_limit between 1 and 100),
  updated_at timestamptz not null default now()
);

insert into public.chat_config (id) values (1)
on conflict (id) do nothing;

drop trigger if exists chat_config_touch_updated_at on public.chat_config;
create trigger chat_config_touch_updated_at
before update on public.chat_config
for each row execute function public.touch_updated_at();

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('direct','group')),
  title text,
  direct_key text unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  status text not null default 'active' check (status in ('active','archived','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint conversations_title_check check (
    (type = 'direct' and title is null and direct_key is not null)
    or (type = 'group' and title is not null and char_length(title) between 1 and 50 and direct_key is null)
  )
);

create index if not exists conversations_updated_idx on public.conversations(updated_at desc);

drop trigger if exists conversations_touch_updated_at on public.conversations;
create trigger conversations_touch_updated_at
before update on public.conversations
for each row execute function public.touch_updated_at();

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  status text not null default 'active' check (status in ('active','left','removed')),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz not null default now(),
  muted_until timestamptz,
  primary key (conversation_id, user_id)
);

create index if not exists conversation_members_user_idx
  on public.conversation_members(user_id, status, joined_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (char_length(body) between 1 and 5000),
  kind text not null default 'text' check (kind in ('text','system')),
  reply_to_id uuid references public.messages(id) on delete set null,
  aura_target_id uuid unique references public.aura_targets(id) on delete set null,
  aura_count integer not null default 0 check (aura_count >= 0),
  unique_aura_givers integer not null default 0 check (unique_aura_givers >= 0),
  is_aura_moment boolean not null default false,
  status text not null default 'active' check (status in ('active','deleted','removed')),
  edited_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists messages_conversation_created_idx
  on public.messages(conversation_id, created_at desc);
create index if not exists messages_sender_created_idx
  on public.messages(sender_id, created_at desc);

create unique index if not exists aura_targets_one_source
  on public.aura_targets(target_type, source_id)
  where source_id is not null;

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create index if not exists message_reactions_conversation_idx
  on public.message_reactions(conversation_id, created_at desc);

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_id);

create table if not exists private.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_user_id uuid references auth.users(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  conversation_id uuid references public.conversations(id) on delete set null,
  reason text not null check (reason in ('harassment','spam','sexual_content','threat','hate','impersonation','scam','minor_safety','other')),
  details text not null default '' check (char_length(details) <= 1000),
  status text not null default 'pending' check (status in ('pending','reviewing','actioned','dismissed')),
  created_at timestamptz not null default now()
);

create index if not exists safety_reports_pending_idx
  on private.safety_reports(status, created_at desc);

-- Safe RLS helper. It intentionally exposes only a boolean.
create or replace function public.chat_is_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = auth.uid()
      and cm.status = 'active'
  );
$$;

revoke execute on function public.chat_is_member(uuid) from public, anon;
grant execute on function public.chat_is_member(uuid) to authenticated;

create or replace function public.users_are_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a)
  );
$$;

revoke execute on function public.users_are_blocked(uuid,uuid) from public, anon, authenticated;

create or replace function public.search_chat_people(p_query text, p_limit integer default 20)
returns table (
  user_id uuid,
  username text,
  display_name text,
  avatar_url text,
  aura_total bigint,
  rank jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_query text := lower(trim(coalesce(p_query,'')));
  v_limit integer := least(greatest(coalesce(p_limit,20),1),30);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if char_length(v_query) < 2 then return; end if;

  return query
  select p.user_id, p.username, p.display_name, p.avatar_url, p.aura_total,
         public.get_aura_rank(p.aura_total)
  from public.profiles p
  where p.onboarding_complete = true
    and p.user_id <> v_user
    and not public.users_are_blocked(v_user, p.user_id)
    and (
      lower(coalesce(p.username,'')) like '%' || v_query || '%'
      or lower(coalesce(p.display_name,'')) like '%' || v_query || '%'
    )
  order by
    case when lower(coalesce(p.username,'')) = v_query then 0 else 1 end,
    p.aura_total desc
  limit v_limit;
end;
$$;

revoke execute on function public.search_chat_people(text,integer) from public, anon;
grant execute on function public.search_chat_people(text,integer) to authenticated;

create or replace function public.create_direct_chat(p_target_user uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_key text;
  v_conversation uuid;
  v_count integer;
  v_limit integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_target_user is null or p_target_user = v_user then raise exception 'Choose another user.'; end if;

  if not exists (select 1 from public.profiles where user_id=v_user and onboarding_complete=true) then
    raise exception 'Finish onboarding first.';
  end if;
  if not exists (select 1 from public.profiles where user_id=p_target_user and onboarding_complete=true) then
    raise exception 'User unavailable.';
  end if;
  if public.users_are_blocked(v_user,p_target_user) then
    raise exception 'This conversation is unavailable.';
  end if;

  v_key := least(v_user::text,p_target_user::text) || ':' || greatest(v_user::text,p_target_user::text);

  select id into v_conversation from public.conversations
  where direct_key=v_key and type='direct'
  limit 1;

  if v_conversation is not null then
    insert into public.conversation_members(conversation_id,user_id,role,status)
    values (v_conversation,v_user,'member','active')
    on conflict (conversation_id,user_id) do update set status='active';
    insert into public.conversation_members(conversation_id,user_id,role,status)
    values (v_conversation,p_target_user,'member','active')
    on conflict (conversation_id,user_id) do update set status='active';
    update public.conversations set status='active' where id=v_conversation;
    return v_conversation;
  end if;

  select direct_chat_create_hour_limit into v_limit from public.chat_config where id=1;
  select count(*) into v_count from public.conversations
  where created_by=v_user and type='direct' and created_at >= now()-interval '1 hour';
  if v_count >= v_limit then raise exception 'You are starting chats too quickly. Try again later.'; end if;

  begin
    insert into public.conversations(type,direct_key,created_by)
    values('direct',v_key,v_user)
    returning id into v_conversation;
  exception when unique_violation then
    select id into v_conversation from public.conversations where direct_key=v_key;
  end;

  insert into public.conversation_members(conversation_id,user_id,role)
  values (v_conversation,v_user,'member'),(v_conversation,p_target_user,'member')
  on conflict (conversation_id,user_id) do update set status='active';

  return v_conversation;
end;
$$;

revoke execute on function public.create_direct_chat(uuid) from public, anon;
grant execute on function public.create_direct_chat(uuid) to authenticated;

create or replace function public.create_group_chat(p_title text, p_member_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_title text := trim(coalesce(p_title,''));
  v_conversation uuid;
  v_members uuid[];
  v_member uuid;
  v_max integer;
  v_created integer;
  v_group_daily_limit integer;
  v_requested integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if char_length(v_title) < 1 or char_length(v_title) > 50 then raise exception 'Group name must be 1–50 characters.'; end if;
  if not exists(select 1 from public.profiles where user_id=v_user and onboarding_complete=true) then raise exception 'Finish onboarding first.'; end if;

  select max_group_members, group_create_day_limit into v_max, v_group_daily_limit
  from public.chat_config where id=1;
  select count(*) into v_created from public.conversations
  where created_by=v_user and type='group' and created_at >= date_trunc('day',now());
  if v_created >= v_group_daily_limit then
    raise exception 'You reached today''s group creation limit.';
  end if;

  select coalesce(array_agg(x order by x::text),'{}'::uuid[]) into v_members
  from (
    select distinct unnest(coalesce(p_member_ids,'{}'::uuid[])) as x
  ) s
  where x <> v_user;

  v_requested := coalesce(array_length(v_members,1),0);
  if v_requested < 1 then raise exception 'Add at least one other person.'; end if;
  if v_requested + 1 > v_max then raise exception 'This group is too large.'; end if;

  foreach v_member in array v_members loop
    if not exists(select 1 from public.profiles where user_id=v_member and onboarding_complete=true) then
      raise exception 'One selected user is unavailable.';
    end if;
    if public.users_are_blocked(v_user,v_member) then
      raise exception 'One selected user cannot be added.';
    end if;
  end loop;

  insert into public.conversations(type,title,created_by)
  values('group',v_title,v_user)
  returning id into v_conversation;

  insert into public.conversation_members(conversation_id,user_id,role)
  values(v_conversation,v_user,'owner');

  insert into public.conversation_members(conversation_id,user_id,role)
  select v_conversation, x, 'member' from unnest(v_members) x;

  return v_conversation;
end;
$$;

revoke execute on function public.create_group_chat(text,uuid[]) from public, anon;
grant execute on function public.create_group_chat(text,uuid[]) to authenticated;

create or replace function public.get_conversations(p_limit integer default 50)
returns table (
  conversation_id uuid,
  conversation_type text,
  title text,
  created_at timestamptz,
  updated_at timestamptz,
  members jsonb,
  last_message jsonb,
  unread_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit,50),1),100);
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  return query
  select c.id,c.type,c.title,c.created_at,c.updated_at,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id',p.user_id,'username',p.username,'display_name',p.display_name,
        'avatar_url',p.avatar_url,'aura_total',p.aura_total,'role',cm2.role
      ) order by cm2.joined_at)
      from public.conversation_members cm2
      join public.profiles p on p.user_id=cm2.user_id
      where cm2.conversation_id=c.id and cm2.status='active'
    ),'[]'::jsonb) as members,
    (
      select jsonb_build_object(
        'id',m.id,'body',case when m.status='active' then m.body else 'Message unavailable' end,
        'sender_id',m.sender_id,'created_at',m.created_at,'status',m.status
      )
      from public.messages m where m.conversation_id=c.id
      order by m.created_at desc limit 1
    ) as last_message,
    (
      select count(*)
      from public.messages m
      where m.conversation_id=c.id
        and m.created_at > cm.last_read_at
        and m.sender_id <> v_user
        and m.status='active'
    )::bigint as unread_count
  from public.conversations c
  join public.conversation_members cm on cm.conversation_id=c.id and cm.user_id=v_user and cm.status='active'
  where c.status='active'
  order by coalesce((select max(m2.created_at) from public.messages m2 where m2.conversation_id=c.id),c.updated_at) desc
  limit v_limit;
end;
$$;

revoke execute on function public.get_conversations(integer) from public, anon;
grant execute on function public.get_conversations(integer) to authenticated;

create or replace function public.get_chat_header(p_conversation_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not public.chat_is_member(p_conversation_id) then raise exception 'Conversation unavailable.'; end if;

  select jsonb_build_object(
    'id',c.id,
    'type',c.type,
    'title',c.title,
    'members',coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id',p.user_id,'username',p.username,'display_name',p.display_name,
        'avatar_url',p.avatar_url,'aura_total',p.aura_total,'rank',public.get_aura_rank(p.aura_total),
        'role',cm.role
      ) order by cm.joined_at)
      from public.conversation_members cm join public.profiles p on p.user_id=cm.user_id
      where cm.conversation_id=c.id and cm.status='active'
    ),'[]'::jsonb)
  ) into v_result
  from public.conversations c where c.id=p_conversation_id and c.status='active';

  if v_result is null then raise exception 'Conversation unavailable.'; end if;
  return v_result;
end;
$$;

revoke execute on function public.get_chat_header(uuid) from public, anon;
grant execute on function public.get_chat_header(uuid) to authenticated;

create or replace function public.get_messages(
  p_conversation_id uuid,
  p_limit integer default 50,
  p_before timestamptz default null
)
returns table (
  message_id uuid,
  sender_id uuid,
  sender_username text,
  sender_display_name text,
  sender_avatar_url text,
  body text,
  reply_to_id uuid,
  aura_target_id uuid,
  aura_count integer,
  unique_aura_givers integer,
  is_aura_moment boolean,
  viewer_has_aura boolean,
  reactions jsonb,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit,50),1),100);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not public.chat_is_member(p_conversation_id) then raise exception 'Conversation unavailable.'; end if;

  return query
  select m.id,m.sender_id,p.username,p.display_name,p.avatar_url,
    case when m.status='active' then m.body else 'Message unavailable' end,
    m.reply_to_id,m.aura_target_id,m.aura_count,m.unique_aura_givers,m.is_aura_moment,
    exists(
      select 1 from public.aura_events ae
      where ae.giver_id=v_user and ae.target_id=m.aura_target_id and ae.source='peer' and ae.status='counted'
    ),
    coalesce((
      select jsonb_agg(jsonb_build_object('emoji',r.emoji,'count',r.cnt,'viewer',r.viewer) order by r.cnt desc)
      from (
        select mr.emoji,count(*)::integer as cnt,bool_or(mr.user_id=v_user) as viewer
        from public.message_reactions mr where mr.message_id=m.id
        group by mr.emoji
      ) r
    ),'[]'::jsonb),
    m.status,m.created_at
  from public.messages m
  join public.profiles p on p.user_id=m.sender_id
  where m.conversation_id=p_conversation_id
    and (p_before is null or m.created_at < p_before)
  order by m.created_at desc
  limit v_limit;
end;
$$;

revoke execute on function public.get_messages(uuid,integer,timestamptz) from public, anon;
grant execute on function public.get_messages(uuid,integer,timestamptz) to authenticated;

create or replace function public.send_message(p_conversation_id uuid, p_body text, p_reply_to uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_body text := trim(coalesce(p_body,''));
  v_cfg public.chat_config%rowtype;
  v_profile_created timestamptz;
  v_recent integer;
  v_limit integer;
  v_type text;
  v_title text;
  v_other uuid;
  v_message public.messages%rowtype;
  v_target uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_cfg from public.chat_config where id=1;
  if char_length(v_body) < 1 or char_length(v_body) > v_cfg.max_message_chars then
    raise exception 'Message must be 1–% characters.',v_cfg.max_message_chars;
  end if;
  if not public.chat_is_member(p_conversation_id) then raise exception 'Conversation unavailable.'; end if;

  select c.type,c.title into v_type,v_title from public.conversations c
  where c.id=p_conversation_id and c.status='active';
  if v_type is null then raise exception 'Conversation unavailable.'; end if;

  if p_reply_to is not null and not exists(
    select 1 from public.messages m where m.id=p_reply_to and m.conversation_id=p_conversation_id
  ) then raise exception 'Reply target unavailable.'; end if;

  if v_type='direct' then
    select cm.user_id into v_other from public.conversation_members cm
    where cm.conversation_id=p_conversation_id and cm.user_id<>v_user and cm.status='active' limit 1;
    if v_other is null or public.users_are_blocked(v_user,v_other) then raise exception 'This conversation is unavailable.'; end if;
  end if;

  select created_at into v_profile_created from public.profiles
  where user_id=v_user and onboarding_complete=true;
  if v_profile_created is null then raise exception 'Finish onboarding first.'; end if;

  select count(*) into v_recent from public.messages
  where sender_id=v_user and created_at >= now()-interval '1 minute';
  v_limit := case when v_profile_created > now()-interval '72 hours'
    then least(v_cfg.message_per_minute_limit,v_cfg.new_account_message_per_minute_limit)
    else v_cfg.message_per_minute_limit end;
  if v_recent >= v_limit then raise exception 'You are sending messages too quickly.'; end if;

  insert into public.messages(conversation_id,sender_id,body,reply_to_id)
  values(p_conversation_id,v_user,v_body,p_reply_to)
  returning * into v_message;

  insert into public.aura_targets(owner_id,target_type,source_id,content_text,context_label,visibility)
  values(v_user,'message',v_message.id,left(v_body,1200),coalesce(nullif(v_title,''),'Private chat'),'private')
  returning id into v_target;

  update public.messages set aura_target_id=v_target where id=v_message.id;
  update public.conversations set updated_at=now() where id=p_conversation_id;

  return jsonb_build_object(
    'id',v_message.id,'conversation_id',p_conversation_id,'sender_id',v_user,'body',v_body,
    'aura_target_id',v_target,'aura_count',0,'created_at',v_message.created_at
  );
end;
$$;

revoke execute on function public.send_message(uuid,text,uuid) from public, anon;
grant execute on function public.send_message(uuid,text,uuid) to authenticated;

create or replace function public.toggle_message_reaction(p_message_id uuid, p_emoji text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_conversation uuid;
  v_emoji text := trim(coalesce(p_emoji,''));
  v_existing text;
  v_on boolean;
  v_counts jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if v_emoji not in ('😂','😭','💀','🔥','❤️','👀','👏','🤝') then raise exception 'Reaction unavailable.'; end if;

  select conversation_id into v_conversation from public.messages where id=p_message_id and status='active';
  if v_conversation is null or not public.chat_is_member(v_conversation) then raise exception 'Message unavailable.'; end if;

  select emoji into v_existing from public.message_reactions where message_id=p_message_id and user_id=v_user;
  if v_existing = v_emoji then
    delete from public.message_reactions where message_id=p_message_id and user_id=v_user;
    v_on := false;
  else
    insert into public.message_reactions(message_id,conversation_id,user_id,emoji)
    values(p_message_id,v_conversation,v_user,v_emoji)
    on conflict(message_id,user_id) do update set emoji=excluded.emoji,created_at=now();
    v_on := true;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('emoji',x.emoji,'count',x.cnt) order by x.cnt desc),'[]'::jsonb)
  into v_counts from (
    select emoji,count(*)::integer cnt from public.message_reactions where message_id=p_message_id group by emoji
  ) x;

  return jsonb_build_object('ok',true,'active',v_on,'emoji',v_emoji,'reactions',v_counts);
end;
$$;

revoke execute on function public.toggle_message_reaction(uuid,text) from public, anon;
grant execute on function public.toggle_message_reaction(uuid,text) to authenticated;

create or replace function public.give_message_aura(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_giver uuid := auth.uid();
  v_message public.messages%rowtype;
  v_target public.aura_targets%rowtype;
  v_cfg public.aura_config%rowtype;
  v_giver_created timestamptz;
  v_giver_complete boolean;
  v_receiver_before bigint;
  v_receiver_total bigint;
  v_receiver_complete boolean;
  v_giver_today integer;
  v_pair_today integer;
  v_pair_combined integer;
  v_limit integer;
  v_today timestamptz := date_trunc('day',now());
  v_became_moment boolean := false;
  v_rank jsonb;
begin
  if v_giver is null then raise exception 'Authentication required'; end if;

  select * into v_message from public.messages where id=p_message_id for update;
  if not found or v_message.status<>'active' then raise exception 'Message unavailable.'; end if;
  if not public.chat_is_member(v_message.conversation_id) then raise exception 'Message unavailable.'; end if;
  if v_message.sender_id=v_giver then raise exception 'You cannot give Aura to yourself.'; end if;
  if v_message.aura_target_id is null then raise exception 'Aura is unavailable for this message.'; end if;

  select * into v_target from public.aura_targets where id=v_message.aura_target_id for update;
  if not found or v_target.status<>'active' or v_target.target_type<>'message' or v_target.source_id<>v_message.id then
    raise exception 'Aura is unavailable for this message.';
  end if;

  select * into v_cfg from public.aura_config where id=1;
  select created_at,onboarding_complete into v_giver_created,v_giver_complete from public.profiles where user_id=v_giver;
  if coalesce(v_giver_complete,false)=false then raise exception 'Finish onboarding first.'; end if;

  select onboarding_complete,aura_total into v_receiver_complete,v_receiver_before
  from public.profiles where user_id=v_message.sender_id for update;
  if coalesce(v_receiver_complete,false)=false then raise exception 'This user is unavailable.'; end if;

  if exists(select 1 from public.aura_events where giver_id=v_giver and target_id=v_message.aura_target_id and source='peer' and status='counted') then
    return jsonb_build_object(
      'ok',true,'already_given',true,'message_id',v_message.id,'message_aura',v_message.aura_count,
      'receiver_aura',v_receiver_before,'rank',public.get_aura_rank(v_receiver_before),'is_aura_moment',v_message.is_aura_moment
    );
  end if;

  select count(*) into v_giver_today from public.aura_events
  where giver_id=v_giver and source='peer' and status='counted' and created_at>=v_today;
  v_limit := case when v_giver_created > now()-make_interval(hours=>v_cfg.new_account_hours)
    then least(v_cfg.daily_giver_limit,v_cfg.new_account_daily_limit) else v_cfg.daily_giver_limit end;
  if v_giver_today>=v_limit then raise exception 'You reached today''s Aura-giving limit. Come back tomorrow.'; end if;

  select count(*) into v_pair_today from public.aura_events
  where giver_id=v_giver and receiver_id=v_message.sender_id and source='peer' and status='counted' and created_at>=v_today;
  if v_pair_today>=v_cfg.daily_pair_limit then raise exception 'You have given this person enough Aura for today.'; end if;

  select count(*) into v_pair_combined from public.aura_events
  where source='peer' and status='counted' and created_at>=v_today
    and ((giver_id=v_giver and receiver_id=v_message.sender_id) or (giver_id=v_message.sender_id and receiver_id=v_giver));
  if v_pair_combined>=v_cfg.daily_pair_combined_limit then raise exception 'This Aura pair has reached today''s safety limit.'; end if;

  begin
    insert into public.aura_events(giver_id,receiver_id,target_id,amount,source)
    values(v_giver,v_message.sender_id,v_message.aura_target_id,v_cfg.peer_aura_amount,'peer');
  exception when unique_violation then
    return jsonb_build_object('ok',true,'already_given',true,'message_id',v_message.id,'message_aura',v_message.aura_count,'receiver_aura',v_receiver_before,'rank',public.get_aura_rank(v_receiver_before));
  end;

  v_became_moment := (not v_message.is_aura_moment) and (v_message.aura_count+v_cfg.peer_aura_amount>=v_cfg.aura_moment_threshold);

  update public.aura_targets
  set aura_count=aura_count+v_cfg.peer_aura_amount,
      unique_givers=unique_givers+1,
      is_aura_moment=is_aura_moment or v_became_moment,
      fyp_eligible=false
  where id=v_message.aura_target_id;

  update public.messages
  set aura_count=aura_count+v_cfg.peer_aura_amount,
      unique_aura_givers=unique_aura_givers+1,
      is_aura_moment=is_aura_moment or v_became_moment
  where id=v_message.id
  returning * into v_message;

  update public.profiles set aura_total=aura_total+v_cfg.peer_aura_amount
  where user_id=v_message.sender_id returning aura_total into v_receiver_total;
  v_rank := public.get_aura_rank(v_receiver_total);

  return jsonb_build_object(
    'ok',true,'already_given',false,'amount',v_cfg.peer_aura_amount,'message_id',v_message.id,
    'message_aura',v_message.aura_count,'unique_givers',v_message.unique_aura_givers,
    'receiver_aura',v_receiver_total,'old_rank',public.get_aura_rank(v_receiver_before),'rank',v_rank,
    'rank_up',coalesce(public.get_aura_rank(v_receiver_before)->>'slug','')<>coalesce(v_rank->>'slug',''),
    'became_aura_moment',v_became_moment,'is_aura_moment',v_message.is_aura_moment
  );
end;
$$;

revoke execute on function public.give_message_aura(uuid) from public, anon;
grant execute on function public.give_message_aura(uuid) to authenticated;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.conversation_members set last_read_at=now()
  where conversation_id=p_conversation_id and user_id=auth.uid() and status='active';
  if not found then raise exception 'Conversation unavailable.'; end if;
end;
$$;

revoke execute on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

create or replace function public.block_user(p_target_user uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_target_user is null or p_target_user=v_user then raise exception 'User unavailable.'; end if;
  insert into public.user_blocks(blocker_id,blocked_id) values(v_user,p_target_user)
  on conflict(blocker_id,blocked_id) do nothing;

  update public.conversation_members cm
  set status='left'
  where cm.user_id=v_user
    and cm.status='active'
    and exists(
      select 1 from public.conversations c
      where c.id=cm.conversation_id and c.type='direct'
    )
    and exists(
      select 1 from public.conversation_members other
      where other.conversation_id=cm.conversation_id and other.user_id=p_target_user
    );

  return true;
end;
$$;

revoke execute on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

create or replace function public.unblock_user(p_target_user uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  delete from public.user_blocks where blocker_id=auth.uid() and blocked_id=p_target_user;
  return true;
end;
$$;

revoke execute on function public.unblock_user(uuid) from public, anon;
grant execute on function public.unblock_user(uuid) to authenticated;

create or replace function public.report_message(p_message_id uuid, p_reason text, p_details text default '')
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid:=auth.uid();
  v_message public.messages%rowtype;
  v_reason text:=lower(trim(coalesce(p_reason,'')));
  v_report uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_message from public.messages where id=p_message_id;
  if not found or not public.chat_is_member(v_message.conversation_id) then raise exception 'Message unavailable.'; end if;
  if v_message.sender_id=v_user then raise exception 'You cannot report your own message.'; end if;
  if v_reason not in ('harassment','spam','sexual_content','threat','hate','impersonation','scam','minor_safety','other') then
    raise exception 'Choose a valid report reason.';
  end if;
  if char_length(coalesce(p_details,''))>1000 then raise exception 'Report details are too long.'; end if;
  if exists(select 1 from private.safety_reports where reporter_id=v_user and message_id=p_message_id and created_at>=now()-interval '1 hour') then
    raise exception 'You already reported this message.';
  end if;

  insert into private.safety_reports(reporter_id,reported_user_id,message_id,conversation_id,reason,details)
  values(v_user,v_message.sender_id,v_message.id,v_message.conversation_id,v_reason,left(coalesce(p_details,''),1000))
  returning id into v_report;
  return v_report;
end;
$$;

revoke execute on function public.report_message(uuid,text,text) from public, anon;
grant execute on function public.report_message(uuid,text,text) to authenticated;

-- RLS: read-only from browser. All mutations are through the constrained RPCs above.
alter table public.chat_config enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.user_blocks enable row level security;

revoke all on table public.chat_config from anon,authenticated;
revoke all on table public.conversations from anon,authenticated;
revoke all on table public.conversation_members from anon,authenticated;
revoke all on table public.messages from anon,authenticated;
revoke all on table public.message_reactions from anon,authenticated;
revoke all on table public.user_blocks from anon,authenticated;

grant select on table public.chat_config to authenticated;
grant select on table public.conversations to authenticated;
grant select on table public.conversation_members to authenticated;
grant select on table public.messages to authenticated;
grant select on table public.message_reactions to authenticated;

drop policy if exists "authenticated can read chat config" on public.chat_config;
drop policy if exists "members can read conversations" on public.conversations;
drop policy if exists "members can read conversation members" on public.conversation_members;
drop policy if exists "members can read messages" on public.messages;
drop policy if exists "members can read reactions" on public.message_reactions;

create policy "authenticated can read chat config"
on public.chat_config for select to authenticated using(true);

create policy "members can read conversations"
on public.conversations for select to authenticated
using(public.chat_is_member(id));

create policy "members can read conversation members"
on public.conversation_members for select to authenticated
using(public.chat_is_member(conversation_id));

create policy "members can read messages"
on public.messages for select to authenticated
using(public.chat_is_member(conversation_id));

create policy "members can read reactions"
on public.message_reactions for select to authenticated
using(public.chat_is_member(conversation_id));

-- Blocks have no direct SELECT grant. User-facing block management can be added via RPCs without exposing graphs.

-- Enable realtime when the standard Supabase publication exists.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then
      execute 'alter publication supabase_realtime add table public.messages';
    end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='message_reactions') then
      execute 'alter publication supabase_realtime add table public.message_reactions';
    end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='conversation_members') then
      execute 'alter publication supabase_realtime add table public.conversation_members';
    end if;
  end if;
end $$;

commit;
