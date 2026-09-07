-- VYBE V4: secure social Rooms + server-authoritative mini-games.
-- Run AFTER 001_auth_onboarding.sql, 002_aura_engine.sql, 003_chat_groups_realtime.sql.
-- Design:
--   * Rooms are created from an existing DM/group; only conversation members are invited.
--   * Client NEVER supplies score, winner, MVP, XP, or Aura rewards.
--   * Correct answers live in the private schema and are never selectable by authenticated users.
--   * Authenticated RPCs submit intent; SECURITY DEFINER functions validate and score server-side.

begin;

alter table public.profiles add column if not exists vibe_xp bigint not null default 0 check (vibe_xp >= 0);
alter table public.profiles add column if not exists room_wins integer not null default 0 check (room_wins >= 0);

create table if not exists public.room_config (
  id smallint primary key default 1 check (id = 1),
  max_players smallint not null default 8 check (max_players between 2 and 16),
  min_players smallint not null default 2 check (min_players between 2 and 8),
  room_expiry_minutes integer not null default 240 check (room_expiry_minutes between 30 and 1440),
  round_seconds smallint not null default 18 check (round_seconds between 5 and 90),
  rounds_per_game smallint not null default 3 check (rounds_per_game between 1 and 10),
  winner_aura smallint not null default 3 check (winner_aura between 1 and 20),
  mvp_aura smallint not null default 5 check (mvp_aura between 1 and 20),
  winner_xp integer not null default 25 check (winner_xp between 0 and 10000),
  participation_xp integer not null default 8 check (participation_xp between 0 and 10000),
  updated_at timestamptz not null default now()
);
insert into public.room_config(id) values(1) on conflict(id) do nothing;

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 60),
  status text not null default 'lobby' check (status in ('lobby','playing','ended')),
  max_players smallint not null default 8 check (max_players between 2 and 16),
  current_session_id uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);
create index if not exists rooms_conversation_status_idx on public.rooms(conversation_id,status,created_at desc);

create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'player' check (role in ('host','player')),
  status text not null default 'invited' check (status in ('invited','active','left','kicked')),
  joined_at timestamptz,
  last_seen_at timestamptz not null default now(),
  primary key(room_id,user_id)
);
create index if not exists room_members_user_idx on public.room_members(user_id,status,last_seen_at desc);

create table if not exists public.game_sessions (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  game_type text not null check (game_type in ('puzzle','trivia','most_likely')),
  status text not null default 'active' check (status in ('active','finished','cancelled')),
  max_rounds smallint not null default 3 check (max_rounds between 1 and 10),
  current_round smallint not null default 1 check (current_round >= 1),
  started_by uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz
);
create index if not exists game_sessions_room_idx on public.game_sessions(room_id,started_at desc);

alter table public.rooms drop constraint if exists rooms_current_session_fk;
alter table public.rooms add constraint rooms_current_session_fk foreign key(current_session_id) references public.game_sessions(id) on delete set null;

create table if not exists public.game_rounds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.game_sessions(id) on delete cascade,
  round_no smallint not null check (round_no >= 1),
  prompt text not null check (char_length(prompt) between 1 and 280),
  options jsonb not null default '[]'::jsonb,
  status text not null default 'active' check (status in ('active','finished')),
  started_at timestamptz not null default now(),
  ends_at timestamptz not null,
  finished_at timestamptz,
  unique(session_id,round_no)
);
create index if not exists game_rounds_session_idx on public.game_rounds(session_id,round_no desc);

create table if not exists private.game_question_bank (
  id bigint generated always as identity primary key,
  game_type text not null check (game_type in ('puzzle','trivia','most_likely')),
  prompt text not null,
  options jsonb not null default '[]'::jsonb,
  correct_answer text,
  active boolean not null default true,
  unique(game_type,prompt)
);

create table if not exists private.game_answer_keys (
  round_id uuid primary key references public.game_rounds(id) on delete cascade,
  correct_answer text
);

create table if not exists public.game_submissions (
  round_id uuid not null references public.game_rounds(id) on delete cascade,
  session_id uuid not null references public.game_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer text not null,
  score integer not null default 0 check (score >= 0),
  is_correct boolean,
  submitted_at timestamptz not null default now(),
  primary key(round_id,user_id)
);
create index if not exists game_submissions_session_user_idx on public.game_submissions(session_id,user_id);

create table if not exists public.game_results (
  session_id uuid not null references public.game_sessions(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  total_score integer not null default 0 check (total_score >= 0),
  placement smallint not null check (placement >= 1),
  is_winner boolean not null default false,
  is_mvp boolean not null default false,
  created_at timestamptz not null default now(),
  primary key(session_id,user_id)
);

create table if not exists public.room_events (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  event_type text not null check (event_type in ('joined','left','game_started','round_started','round_finished','game_finished')),
  actor_id uuid references auth.users(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists room_events_room_idx on public.room_events(room_id,created_at desc);

-- Starter question bank. Later VYBE HQ can manage these server-side.
insert into private.game_question_bank(game_type,prompt,options,correct_answer) values
('trivia','Which planet has the shortest day?','["Jupiter","Mars","Venus","Mercury"]','Jupiter'),
('trivia','What does HTTP stand for?','["HyperText Transfer Protocol","High Transfer Text Process","Hyper Terminal Transport Program","Hosted Text Transfer Port"]','HyperText Transfer Protocol'),
('trivia','Which ocean is the largest?','["Pacific","Atlantic","Indian","Arctic"]','Pacific'),
('trivia','How many players does a football team have on the pitch?','["11","10","9","12"]','11'),
('trivia','Which number is prime?','["29","27","21","39"]','29'),
('puzzle','Complete the sequence: 2, 6, 12, 20, ?','["30","28","32","26"]','30'),
('puzzle','If ALLY becomes BMMZ by shifting each letter +1, CODE becomes?','["DPEF","DPDF","CPDE","EPFG"]','DPEF'),
('puzzle','What comes next: 1, 1, 2, 3, 5, 8, ?','["13","11","15","12"]','13'),
('puzzle','Which one does not belong?','["Triangle","Square","Circle","Cube"]','Cube'),
('puzzle','A clock shows 3:00. What is the angle between the hands?','["90°","60°","120°","45°"]','90°'),
('most_likely','Who is most likely to disappear for 3 days and come back like nothing happened?','[]',null),
('most_likely','Who would survive the longest in a zombie apocalypse?','[]',null),
('most_likely','Who is most likely to become accidentally famous?','[]',null),
('most_likely','Who would start an argument and then say “I’m chill”?','[]',null),
('most_likely','Who has the strongest main-character energy?','[]',null)
on conflict do nothing;

create or replace function public.room_is_member(p_room uuid, p_include_invited boolean default true)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.room_members rm
    where rm.room_id=p_room and rm.user_id=auth.uid()
      and (rm.status='active' or (p_include_invited and rm.status='invited'))
  );
$$;
revoke execute on function public.room_is_member(uuid,boolean) from public,anon;
grant execute on function public.room_is_member(uuid,boolean) to authenticated;

create or replace function private.make_game_round(p_session uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_session public.game_sessions%rowtype;
  v_room public.rooms%rowtype;
  v_cfg public.room_config%rowtype;
  v_q private.game_question_bank%rowtype;
  v_round uuid;
  v_options jsonb;
begin
  select * into v_session from public.game_sessions where id=p_session for update;
  if not found or v_session.status<>'active' then raise exception 'Game session unavailable.'; end if;
  select * into v_room from public.rooms where id=v_session.room_id;
  select * into v_cfg from public.room_config where id=1;

  select * into v_q from private.game_question_bank q
  where q.game_type=v_session.game_type and q.active=true
    and not exists(select 1 from public.game_rounds gr where gr.session_id=v_session.id and gr.prompt=q.prompt)
  order by random() limit 1;
  if not found then raise exception 'No questions configured for this game.'; end if;

  if v_session.game_type='most_likely' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'value',p.user_id::text,
      'label',coalesce(p.display_name,p.username,'VYBE user'),
      'username',p.username
    ) order by coalesce(p.display_name,p.username)), '[]'::jsonb)
      into v_options
    from public.room_members rm join public.profiles p on p.user_id=rm.user_id
    where rm.room_id=v_session.room_id and rm.status='active';
  else
    v_options:=v_q.options;
  end if;

  insert into public.game_rounds(session_id,round_no,prompt,options,ends_at)
  values(v_session.id,v_session.current_round,v_q.prompt,v_options,now()+make_interval(secs=>v_cfg.round_seconds))
  returning id into v_round;

  insert into private.game_answer_keys(round_id,correct_answer) values(v_round,v_q.correct_answer);
  insert into public.room_events(room_id,event_type,actor_id,payload)
  values(v_session.room_id,'round_started',null,jsonb_build_object('session_id',v_session.id,'round_id',v_round,'round_no',v_session.current_round));
  return v_round;
end;
$$;
revoke execute on function private.make_game_round(uuid) from public,anon,authenticated;

create or replace function public.create_room_from_conversation(p_conversation_id uuid, p_title text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid(); v_room public.rooms%rowtype; v_cfg public.room_config%rowtype; v_title text; v_conv public.conversations%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not public.chat_is_member(p_conversation_id) then raise exception 'Conversation unavailable.'; end if;
  select * into v_cfg from public.room_config where id=1;
  select * into v_conv from public.conversations where id=p_conversation_id;

  select r.* into v_room from public.rooms r
  where r.conversation_id=p_conversation_id and r.status<>'ended' and r.expires_at>now()
  order by r.created_at desc limit 1;
  if found then
    if exists(select 1 from public.room_members where room_id=v_room.id and user_id=v_user and status in('invited','active')) then
      return jsonb_build_object('ok',true,'room_id',v_room.id,'existing',true);
    end if;
  end if;

  v_title:=left(coalesce(nullif(trim(p_title),''),nullif(trim(v_conv.title),''),'VYBE Room'),60);
  insert into public.rooms(conversation_id,created_by,title,max_players,expires_at)
  values(p_conversation_id,v_user,v_title,v_cfg.max_players,now()+make_interval(mins=>v_cfg.room_expiry_minutes)) returning * into v_room;

  insert into public.room_members(room_id,user_id,role,status,joined_at)
  select v_room.id,cm.user_id,case when cm.user_id=v_user then 'host' else 'player' end,
         case when cm.user_id=v_user then 'active' else 'invited' end,
         case when cm.user_id=v_user then now() else null end
  from public.conversation_members cm
  where cm.conversation_id=p_conversation_id and cm.status='active';

  insert into public.room_events(room_id,event_type,actor_id,payload) values(v_room.id,'joined',v_user,jsonb_build_object('host',true));
  return jsonb_build_object('ok',true,'room_id',v_room.id,'existing',false);
end;
$$;
revoke execute on function public.create_room_from_conversation(uuid,text) from public,anon;
grant execute on function public.create_room_from_conversation(uuid,text) to authenticated;

create or replace function public.join_room(p_room uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_count integer; v_max integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select max_players into v_max from public.rooms where id=p_room and status<>'ended' and expires_at>now() for update;
  if v_max is null then raise exception 'Room unavailable.'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room and user_id=v_user and status in('invited','active')) then raise exception 'You are not invited to this Room.'; end if;
  select count(*) into v_count from public.room_members where room_id=p_room and status='active';
  if v_count>=v_max and not exists(select 1 from public.room_members where room_id=p_room and user_id=v_user and status='active') then raise exception 'Room is full.'; end if;
  update public.room_members set status='active',joined_at=coalesce(joined_at,now()),last_seen_at=now() where room_id=p_room and user_id=v_user;
  insert into public.room_events(room_id,event_type,actor_id) values(p_room,'joined',v_user);
  return jsonb_build_object('ok',true,'room_id',p_room);
end;
$$;
revoke execute on function public.join_room(uuid) from public,anon;
grant execute on function public.join_room(uuid) to authenticated;

create or replace function public.leave_room(p_room uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_host uuid; v_next uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not public.room_is_member(p_room,true) then raise exception 'Room unavailable.'; end if;
  update public.room_members set status='left',last_seen_at=now() where room_id=p_room and user_id=v_user;
  select created_by into v_host from public.rooms where id=p_room;
  if v_host=v_user then
    select user_id into v_next from public.room_members where room_id=p_room and status='active' order by joined_at asc limit 1;
    if v_next is null then
      update public.game_sessions set status='cancelled',finished_at=now() where id=(select current_session_id from public.rooms where id=p_room) and status='active';
      update public.rooms set status='ended',current_session_id=null,updated_at=now() where id=p_room;
    else
      update public.rooms set created_by=v_next,updated_at=now() where id=p_room;
      update public.room_members set role='player' where room_id=p_room;
      update public.room_members set role='host' where room_id=p_room and user_id=v_next;
    end if;
  end if;
  insert into public.room_events(room_id,event_type,actor_id) values(p_room,'left',v_user);
  return jsonb_build_object('ok',true);
end;
$$;
revoke execute on function public.leave_room(uuid) from public,anon;
grant execute on function public.leave_room(uuid) to authenticated;

create or replace function public.get_my_rooms(p_limit integer default 30)
returns table(room_id uuid,title text,status text,conversation_id uuid,created_by uuid,member_status text,member_role text,active_count bigint,invited_count bigint,current_session_id uuid,game_type text,game_status text,updated_at timestamptz)
language sql stable security definer set search_path='' as $$
  select r.id,r.title,r.status,r.conversation_id,r.created_by,me.status,me.role,
    (select count(*) from public.room_members x where x.room_id=r.id and x.status='active'),
    (select count(*) from public.room_members x where x.room_id=r.id and x.status='invited'),
    r.current_session_id,gs.game_type,gs.status,r.updated_at
  from public.room_members me join public.rooms r on r.id=me.room_id
  left join public.game_sessions gs on gs.id=r.current_session_id
  where me.user_id=auth.uid() and me.status in('invited','active') and r.status<>'ended' and r.expires_at>now()
  order by case when me.status='invited' then 0 else 1 end,r.updated_at desc
  limit greatest(1,least(coalesce(p_limit,30),100));
$$;
revoke execute on function public.get_my_rooms(integer) from public,anon;
grant execute on function public.get_my_rooms(integer) to authenticated;

create or replace function public.get_room_state(p_room uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_room public.rooms%rowtype; v_session public.game_sessions%rowtype; v_round public.game_rounds%rowtype; v_user uuid:=auth.uid(); v_members jsonb; v_results jsonb; v_scoreboard jsonb; v_my_answer text;
begin
  if v_user is null or not public.room_is_member(p_room,true) then raise exception 'Room unavailable.'; end if;
  select * into v_room from public.rooms where id=p_room;
  if not found then raise exception 'Room unavailable.'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id',p.user_id,'username',p.username,'display_name',p.display_name,'avatar_url',p.avatar_url,'aura_total',p.aura_total,
    'status',rm.status,'role',rm.role,'joined_at',rm.joined_at
  ) order by case rm.role when 'host' then 0 else 1 end,coalesce(rm.joined_at,rm.last_seen_at)), '[]'::jsonb)
  into v_members from public.room_members rm join public.profiles p on p.user_id=rm.user_id where rm.room_id=p_room and rm.status in('active','invited');

  if v_room.current_session_id is not null then
    select * into v_session from public.game_sessions where id=v_room.current_session_id;
    if found then
      select * into v_round from public.game_rounds where session_id=v_session.id and status='active' order by round_no desc limit 1;
      if found then select answer into v_my_answer from public.game_submissions where round_id=v_round.id and user_id=v_user; end if;
      select coalesce(jsonb_agg(jsonb_build_object('user_id',s.user_id,'score',s.total_score) order by s.total_score desc),'[]'::jsonb)
        into v_scoreboard from (
          select rm.user_id,
        case when v_session.game_type='most_likely' then
          (select count(*)::integer*100 from public.game_submissions vote where vote.session_id=v_session.id and vote.answer=rm.user_id::text)
        else coalesce(sum(gs.score),0)::integer end as total_score
          from public.room_members rm left join public.game_submissions gs on gs.session_id=v_session.id and gs.user_id=rm.user_id
          where rm.room_id=p_room and rm.status='active' group by rm.user_id
        ) s;
    end if;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('user_id',gr.user_id,'score',gr.total_score,'placement',gr.placement,'winner',gr.is_winner,'mvp',gr.is_mvp) order by gr.placement),'[]'::jsonb)
    into v_results from public.game_results gr where gr.room_id=p_room and gr.session_id=(select id from public.game_sessions where room_id=p_room and status='finished' order by finished_at desc limit 1);

  return jsonb_build_object(
    'room',jsonb_build_object('id',v_room.id,'title',v_room.title,'status',v_room.status,'host_id',v_room.created_by,'max_players',v_room.max_players,'current_session_id',v_room.current_session_id,'expires_at',v_room.expires_at),
    'members',v_members,
    'viewer',jsonb_build_object('user_id',v_user,'member',true,'status',(select status from public.room_members where room_id=p_room and user_id=v_user),'role',(select role from public.room_members where room_id=p_room and user_id=v_user)),
    'session',case when v_session.id is null then null else jsonb_build_object('id',v_session.id,'game_type',v_session.game_type,'status',v_session.status,'current_round',v_session.current_round,'max_rounds',v_session.max_rounds,'started_at',v_session.started_at) end,
    'round',case when v_round.id is null then null else jsonb_build_object('id',v_round.id,'round_no',v_round.round_no,'prompt',v_round.prompt,'options',v_round.options,'started_at',v_round.started_at,'ends_at',v_round.ends_at,'my_answer',v_my_answer) end,
    'scoreboard',coalesce(v_scoreboard,'[]'::jsonb),
    'last_results',coalesce(v_results,'[]'::jsonb)
  );
end;
$$;
revoke execute on function public.get_room_state(uuid) from public,anon;
grant execute on function public.get_room_state(uuid) to authenticated;

create or replace function public.start_room_game(p_room uuid,p_game_type text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_room public.rooms%rowtype; v_cfg public.room_config%rowtype; v_count integer; v_session uuid; v_round uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_game_type not in('puzzle','trivia','most_likely') then raise exception 'Unknown game.'; end if;
  select * into v_room from public.rooms where id=p_room for update;
  if not found or v_room.status='ended' or v_room.expires_at<=now() then raise exception 'Room unavailable.'; end if;
  if v_room.created_by<>v_user then raise exception 'Only the host can start a game.'; end if;
  if v_room.current_session_id is not null then raise exception 'A game is already running.'; end if;
  select * into v_cfg from public.room_config where id=1;
  select count(*) into v_count from public.room_members where room_id=p_room and status='active';
  if v_count<v_cfg.min_players then raise exception 'At least % active players are required.',v_cfg.min_players; end if;
  insert into public.game_sessions(room_id,game_type,max_rounds,started_by) values(p_room,p_game_type,v_cfg.rounds_per_game,v_user) returning id into v_session;
  update public.rooms set status='playing',current_session_id=v_session,updated_at=now() where id=p_room;
  v_round:=private.make_game_round(v_session);
  insert into public.room_events(room_id,event_type,actor_id,payload) values(p_room,'game_started',v_user,jsonb_build_object('session_id',v_session,'game_type',p_game_type));
  return jsonb_build_object('ok',true,'session_id',v_session,'round_id',v_round);
end;
$$;
revoke execute on function public.start_room_game(uuid,text) from public,anon;
grant execute on function public.start_room_game(uuid,text) to authenticated;

create or replace function public.submit_game_answer(p_session uuid,p_round uuid,p_answer text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid(); v_session public.game_sessions%rowtype; v_round public.game_rounds%rowtype; v_key text; v_score integer:=0; v_correct boolean; v_elapsed numeric; v_option_ok boolean;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_session from public.game_sessions where id=p_session;
  if not found or v_session.status<>'active' or not public.room_is_member(v_session.room_id,false) then raise exception 'Game unavailable.'; end if;
  select * into v_round from public.game_rounds where id=p_round and session_id=p_session for update;
  if not found or v_round.status<>'active' then raise exception 'Round is closed.'; end if;
  if now()>v_round.ends_at then raise exception 'Time is up.'; end if;
  if exists(select 1 from public.game_submissions where round_id=p_round and user_id=v_user) then
    return jsonb_build_object('ok',true,'already_submitted',true);
  end if;
  select exists(
    select 1 from jsonb_array_elements(v_round.options) as elem(value)
    where (case when jsonb_typeof(elem.value)='object' then elem.value->>'value' else trim(both '"' from elem.value::text) end)=p_answer
  ) into v_option_ok;
  if not v_option_ok then raise exception 'Invalid answer.'; end if;

  select correct_answer into v_key from private.game_answer_keys where round_id=p_round;
  if v_session.game_type='most_likely' then
    if p_answer=v_user::text then raise exception 'Pick someone else 😭'; end if;
    v_correct:=null; v_score:=20;
  else
    v_correct:=(p_answer=v_key);
    v_elapsed:=greatest(extract(epoch from (now()-v_round.started_at)),0);
    v_score:=case when v_correct then 100+greatest(0,round(50-(v_elapsed*2)))::integer else 0 end;
  end if;
  insert into public.game_submissions(round_id,session_id,user_id,answer,score,is_correct) values(p_round,p_session,v_user,p_answer,v_score,v_correct);
  return jsonb_build_object('ok',true,'already_submitted',false,'score',v_score,'correct',v_correct);
end;
$$;
revoke execute on function public.submit_game_answer(uuid,uuid,text) from public,anon;
grant execute on function public.submit_game_answer(uuid,uuid,text) to authenticated;

create or replace function public.advance_room_game(p_session uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid(); v_session public.game_sessions%rowtype; v_round public.game_rounds%rowtype; v_active integer; v_submitted integer; v_next uuid; v_cfg public.room_config%rowtype; v_winner uuid; v_top integer; v_rank integer:=0; r record;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_session from public.game_sessions where id=p_session for update;
  if not found or v_session.status<>'active' or not public.room_is_member(v_session.room_id,false) then raise exception 'Game unavailable.'; end if;
  select * into v_round from public.game_rounds where session_id=p_session and status='active' order by round_no desc limit 1 for update;
  if not found then raise exception 'No active round.'; end if;
  select count(*) into v_active from public.room_members where room_id=v_session.room_id and status='active';
  select count(*) into v_submitted from public.game_submissions where round_id=v_round.id;
  if now()<v_round.ends_at and v_submitted<v_active then
    return jsonb_build_object('ok',true,'waiting',true,'submitted',v_submitted,'active_players',v_active,'ends_at',v_round.ends_at);
  end if;
  update public.game_rounds set status='finished',finished_at=now() where id=v_round.id;
  insert into public.room_events(room_id,event_type,actor_id,payload) values(v_session.room_id,'round_finished',v_user,jsonb_build_object('session_id',p_session,'round_no',v_round.round_no));

  if v_session.current_round < v_session.max_rounds then
    update public.game_sessions set current_round=current_round+1 where id=p_session returning * into v_session;
    v_next:=private.make_game_round(p_session);
    return jsonb_build_object('ok',true,'finished',false,'next_round_id',v_next,'round_no',v_session.current_round);
  end if;

  select * into v_cfg from public.room_config where id=1;
  -- Insert deterministic final placements. Ties break by earliest first submission, then user id.
  for r in
    select rm.user_id,
      case when v_session.game_type='most_likely' then
        (select count(*)::integer*100 from public.game_submissions vote where vote.session_id=p_session and vote.answer=rm.user_id::text)
      else coalesce(sum(s.score),0)::integer end as total_score,
      min(s.submitted_at) first_submit
    from public.room_members rm left join public.game_submissions s on s.session_id=p_session and s.user_id=rm.user_id
    where rm.room_id=v_session.room_id and rm.status='active'
    group by rm.user_id
    order by total_score desc, first_submit asc nulls last, rm.user_id
  loop
    v_rank:=v_rank+1;
    if v_rank=1 then v_winner:=r.user_id; v_top:=r.total_score; end if;
    insert into public.game_results(session_id,room_id,user_id,total_score,placement,is_winner,is_mvp)
    values(p_session,v_session.room_id,r.user_id,r.total_score,v_rank,v_rank=1,v_rank=1)
    on conflict(session_id,user_id) do nothing;
    update public.profiles set vibe_xp=vibe_xp+case when v_rank=1 then v_cfg.winner_xp else v_cfg.participation_xp end,
      room_wins=room_wins+case when v_rank=1 then 1 else 0 end where user_id=r.user_id;
  end loop;

  if v_winner is not null then
    perform public.award_verified_aura(v_winner,'game',p_session,v_cfg.winner_aura,'Room game winner');
    perform public.award_verified_aura(v_winner,'room_mvp',p_session,v_cfg.mvp_aura,'Room MVP');
  end if;
  update public.game_sessions set status='finished',finished_at=now() where id=p_session;
  update public.rooms set status='lobby',current_session_id=null,updated_at=now() where id=v_session.room_id;
  insert into public.room_events(room_id,event_type,actor_id,payload) values(v_session.room_id,'game_finished',null,jsonb_build_object('session_id',p_session,'winner_id',v_winner,'top_score',v_top));
  return jsonb_build_object('ok',true,'finished',true,'winner_id',v_winner,'winner_score',v_top,'winner_aura',v_cfg.winner_aura,'mvp_aura',v_cfg.mvp_aura);
end;
$$;
revoke execute on function public.advance_room_game(uuid) from public,anon;
grant execute on function public.advance_room_game(uuid) to authenticated;


create or replace function public.get_my_game_stats()
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'vibe_xp',coalesce(p.vibe_xp,0),
    'vibe_level',greatest(1,floor(sqrt(coalesce(p.vibe_xp,0)::numeric/100.0))+1)::integer,
    'room_wins',coalesce(p.room_wins,0),
    'games_played',(select count(*) from public.game_results gr where gr.user_id=auth.uid()),
    'verified_game_aura',(select coalesce(sum(e.amount),0) from public.aura_events e where e.receiver_id=auth.uid() and e.source in('game','room_mvp') and e.status='counted')
  ) from public.profiles p where p.user_id=auth.uid();
$$;
revoke execute on function public.get_my_game_stats() from public,anon;
grant execute on function public.get_my_game_stats() to authenticated;

-- Client reads safe room/realtime surfaces; writes only through RPCs.
alter table public.room_config enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.game_sessions enable row level security;
alter table public.game_rounds enable row level security;
alter table public.game_submissions enable row level security;
alter table public.game_results enable row level security;
alter table public.room_events enable row level security;

revoke all on table public.room_config,public.rooms,public.room_members,public.game_sessions,public.game_rounds,public.game_submissions,public.game_results,public.room_events from anon,authenticated;
grant select on table public.room_config to authenticated;
grant select on table public.rooms,public.room_members,public.game_sessions,public.game_rounds,public.game_results,public.room_events to authenticated;
-- Deliberately NO authenticated SELECT on game_submissions: other players' live answers remain private.

create policy "room config readable" on public.room_config for select to authenticated using(true);
create policy "room members can read rooms" on public.rooms for select to authenticated using(public.room_is_member(id,true));
create policy "room members can read member list" on public.room_members for select to authenticated using(public.room_is_member(room_id,true));
create policy "room members can read sessions" on public.game_sessions for select to authenticated using(public.room_is_member(room_id,true));
create policy "room members can read rounds" on public.game_rounds for select to authenticated using(exists(select 1 from public.game_sessions s where s.id=session_id and public.room_is_member(s.room_id,true)));
create policy "room members can read results" on public.game_results for select to authenticated using(public.room_is_member(room_id,true));
create policy "room members can read room events" on public.room_events for select to authenticated using(public.room_is_member(room_id,true));

-- Realtime on SAFE tables only. Never publish game_submissions/private answer keys.
do $$ begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='rooms') then execute 'alter publication supabase_realtime add table public.rooms'; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='room_members') then execute 'alter publication supabase_realtime add table public.room_members'; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='game_sessions') then execute 'alter publication supabase_realtime add table public.game_sessions'; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='game_rounds') then execute 'alter publication supabase_realtime add table public.game_rounds'; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='game_results') then execute 'alter publication supabase_realtime add table public.game_results'; end if;
    if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='room_events') then execute 'alter publication supabase_realtime add table public.room_events'; end if;
  end if;
end $$;

commit;
