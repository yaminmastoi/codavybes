-- CodaVybes V13.5 — per-member chat clearing, sender deletion, and receipts.

begin;

alter table public.conversation_members
  add column if not exists cleared_at timestamptz;

alter table public.messages
  add column if not exists delivered_at timestamptz,
  add column if not exists viewed_at timestamptz;

create index if not exists messages_pending_delivery_idx
  on public.messages(conversation_id, created_at)
  where delivered_at is null and status = 'active';

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
        'id',m.id,
        'body',case when m.status='active' then m.body else 'This message was deleted' end,
        'sender_id',m.sender_id,'created_at',m.created_at,'status',m.status
      )
      from public.messages m
      where m.conversation_id=c.id
        and m.created_at > coalesce(cm.cleared_at,'-infinity'::timestamptz)
      order by m.created_at desc limit 1
    ) as last_message,
    (
      select count(*)
      from public.messages m
      where m.conversation_id=c.id
        and m.created_at > greatest(cm.last_read_at,coalesce(cm.cleared_at,'-infinity'::timestamptz))
        and m.sender_id <> v_user
        and m.status='active'
    )::bigint as unread_count
  from public.conversations c
  join public.conversation_members cm
    on cm.conversation_id=c.id and cm.user_id=v_user and cm.status='active'
  where c.status='active'
  order by coalesce((
    select max(m2.created_at)
    from public.messages m2
    where m2.conversation_id=c.id
      and m2.created_at > coalesce(cm.cleared_at,'-infinity'::timestamptz)
  ),cm.cleared_at,c.updated_at) desc
  limit v_limit;
end;
$$;

revoke execute on function public.get_conversations(integer) from public, anon;
grant execute on function public.get_conversations(integer) to authenticated;

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
    case when m.status='active' then m.body else 'This message was deleted' end,
    m.reply_to_id,m.aura_target_id,m.aura_count,m.unique_aura_givers,m.is_aura_moment,
    exists(
      select 1 from public.aura_events ae
      where ae.giver_id=v_user and ae.target_id=m.aura_target_id and ae.source='peer' and ae.status='counted'
    ),
    case when m.status='active' then coalesce((
      select jsonb_agg(jsonb_build_object('emoji',r.emoji,'count',r.cnt,'viewer',r.viewer) order by r.cnt desc)
      from (
        select mr.emoji,count(*)::integer as cnt,bool_or(mr.user_id=v_user) as viewer
        from public.message_reactions mr where mr.message_id=m.id
        group by mr.emoji
      ) r
    ),'[]'::jsonb) else '[]'::jsonb end,
    m.status,m.created_at
  from public.messages m
  join public.profiles p on p.user_id=m.sender_id
  join public.conversation_members viewer
    on viewer.conversation_id=m.conversation_id and viewer.user_id=v_user and viewer.status='active'
  where m.conversation_id=p_conversation_id
    and m.created_at > coalesce(viewer.cleared_at,'-infinity'::timestamptz)
    and (p_before is null or m.created_at < p_before)
  order by m.created_at desc
  limit v_limit;
end;
$$;

revoke execute on function public.get_messages(uuid,integer,timestamptz) from public, anon;
grant execute on function public.get_messages(uuid,integer,timestamptz) to authenticated;

create or replace function public.get_message_receipts(
  p_conversation_id uuid,
  p_limit integer default 50,
  p_before timestamptz default null
)
returns table (message_id uuid, delivered_at timestamptz, viewed_at timestamptz)
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
  select m.id,m.delivered_at,m.viewed_at
  from public.messages m
  join public.conversation_members cm
    on cm.conversation_id=m.conversation_id and cm.user_id=v_user and cm.status='active'
  where m.conversation_id=p_conversation_id
    and m.created_at > coalesce(cm.cleared_at,'-infinity'::timestamptz)
    and (p_before is null or m.created_at < p_before)
  order by m.created_at desc
  limit v_limit;
end;
$$;

revoke execute on function public.get_message_receipts(uuid,integer,timestamptz) from public, anon;
grant execute on function public.get_message_receipts(uuid,integer,timestamptz) to authenticated;

create or replace function public.clear_conversation(p_conversation_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_cleared_at timestamptz := clock_timestamp();
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  update public.conversation_members
  set cleared_at=v_cleared_at,last_read_at=v_cleared_at
  where conversation_id=p_conversation_id and user_id=v_user and status='active';
  if not found then raise exception 'Conversation unavailable.'; end if;

  return v_cleared_at;
end;
$$;

revoke execute on function public.clear_conversation(uuid) from public, anon;
grant execute on function public.clear_conversation(uuid) to authenticated;

create or replace function public.delete_message(p_message_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_conversation uuid;
  v_target uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  select m.conversation_id,m.aura_target_id into v_conversation,v_target
  from public.messages m
  where m.id=p_message_id and m.sender_id=v_user and m.status='active' and m.kind='text';

  if v_conversation is null or not public.chat_is_member(v_conversation) then
    raise exception 'You can only delete your own active messages.';
  end if;

  update public.messages
  set body='Deleted message',status='deleted',edited_at=now()
  where id=p_message_id;

  delete from public.message_reactions where message_id=p_message_id;
  update public.aura_targets
  set content_text='Deleted message'
  where id=v_target;

  update public.conversations set updated_at=now() where id=v_conversation;
  return true;
end;
$$;

revoke execute on function public.delete_message(uuid) from public, anon;
grant execute on function public.delete_message(uuid) to authenticated;

create or replace function public.mark_my_messages_delivered()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_count bigint;
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  update public.messages m
  set delivered_at=coalesce(m.delivered_at,now())
  where m.sender_id<>v_user
    and m.status='active'
    and m.delivered_at is null
    and exists(
      select 1 from public.conversation_members cm
      where cm.conversation_id=m.conversation_id and cm.user_id=v_user and cm.status='active'
    );
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.mark_my_messages_delivered() from public, anon;
grant execute on function public.mark_my_messages_delivered() to authenticated;

create or replace function public.mark_conversation_read(p_conversation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_now timestamptz := now();
begin
  if v_user is null then raise exception 'Authentication required'; end if;

  update public.conversation_members set last_read_at=v_now
  where conversation_id=p_conversation_id and user_id=v_user and status='active';
  if not found then raise exception 'Conversation unavailable.'; end if;

  update public.messages
  set delivered_at=coalesce(delivered_at,v_now),viewed_at=coalesce(viewed_at,v_now)
  where conversation_id=p_conversation_id and sender_id<>v_user and status='active';
end;
$$;

revoke execute on function public.mark_conversation_read(uuid) from public, anon;
grant execute on function public.mark_conversation_read(uuid) to authenticated;

commit;
