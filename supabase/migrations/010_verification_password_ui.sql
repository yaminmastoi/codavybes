-- VYBE V11 — Blue-tick verification foundation.
-- Apply after 001..009. Password recovery itself uses Supabase Auth and needs no DB secret.

begin;

-- Public trust state. Keep reviewer identity/reasons private.
alter table public.profiles
  add column if not exists is_verified boolean not null default false,
  add column if not exists verified_at timestamptz;

create index if not exists profiles_verified_idx
  on public.profiles(is_verified, verified_at desc)
  where is_verified = true;

create table if not exists private.verification_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null check(category in ('creator','public_figure','organization','notable','other')),
  reason text not null check(char_length(reason) between 20 and 600),
  evidence_url text check(evidence_url is null or char_length(evidence_url) <= 500),
  status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
  admin_note text check(admin_note is null or char_length(admin_note) <= 1000),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists verification_one_pending_per_user
  on private.verification_requests(user_id)
  where status='pending';
create index if not exists verification_requests_queue_idx
  on private.verification_requests(status, created_at asc);

-- User-facing state without exposing private reviewer data.
create or replace function public.get_my_verification_state()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_result jsonb;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select jsonb_build_object(
    'is_verified',p.is_verified,
    'verified_at',p.verified_at,
    'request',(
      select jsonb_build_object(
        'id',r.id,'category',r.category,'reason',r.reason,'evidence_url',r.evidence_url,
        'status',r.status,'created_at',r.created_at,'reviewed_at',r.reviewed_at,
        'admin_note',case when r.status in ('approved','rejected') then r.admin_note else null end
      )
      from private.verification_requests r
      where r.user_id=v_user
      order by r.created_at desc limit 1
    )
  ) into v_result
  from public.profiles p where p.user_id=v_user;
  return coalesce(v_result,jsonb_build_object('is_verified',false,'verified_at',null,'request',null));
end; $$;
revoke execute on function public.get_my_verification_state() from public,anon;
grant execute on function public.get_my_verification_state() to authenticated;

create or replace function public.request_verification(
  p_category text,
  p_reason text,
  p_evidence_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_id uuid;
  v_last_rejected timestamptz;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if not private.account_is_active(v_user) then raise exception 'Account restricted'; end if;
  if p_category not in ('creator','public_figure','organization','notable','other') then raise exception 'Choose a valid verification category'; end if;
  if char_length(trim(coalesce(p_reason,''))) < 20 then raise exception 'Tell us why this account should be verified (20+ characters)'; end if;
  if char_length(trim(coalesce(p_reason,''))) > 600 then raise exception 'Verification reason is too long'; end if;
  if p_evidence_url is not null and char_length(trim(p_evidence_url)) > 500 then raise exception 'Evidence link is too long'; end if;
  if nullif(trim(coalesce(p_evidence_url,'')),'') is not null and trim(p_evidence_url) !~* '^https?://' then raise exception 'Evidence link must start with http:// or https://'; end if;
  if not exists(select 1 from public.profiles p where p.user_id=v_user and p.onboarding_complete=true) then raise exception 'Finish onboarding first'; end if;
  if exists(select 1 from public.profiles p where p.user_id=v_user and p.is_verified=true) then raise exception 'This account is already verified'; end if;
  if exists(select 1 from private.verification_requests r where r.user_id=v_user and r.status='pending') then raise exception 'A verification request is already pending'; end if;

  select max(r.reviewed_at) into v_last_rejected
  from private.verification_requests r where r.user_id=v_user and r.status='rejected';
  if v_last_rejected is not null and v_last_rejected > now()-interval '30 days' then
    raise exception 'You can request verification again 30 days after the last review';
  end if;

  insert into private.verification_requests(user_id,category,reason,evidence_url)
  values(v_user,p_category,left(trim(p_reason),600),nullif(left(trim(coalesce(p_evidence_url,'')),500),''))
  returning id into v_id;

  return jsonb_build_object('ok',true,'request_id',v_id,'status','pending');
end; $$;
revoke execute on function public.request_verification(text,text,text) from public,anon;
grant execute on function public.request_verification(text,text,text) to authenticated;

create or replace function public.cancel_my_verification_request()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_id uuid;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  update private.verification_requests
  set status='cancelled',updated_at=now()
  where user_id=v_user and status='pending'
  returning id into v_id;
  return jsonb_build_object('ok',v_id is not null,'request_id',v_id);
end; $$;
revoke execute on function public.cancel_my_verification_request() from public,anon;
grant execute on function public.cancel_my_verification_request() to authenticated;

-- Admin queue. Moderators may view, admins/super-admins decide.
create or replace function public.admin_list_verification_requests(p_status text default 'pending',p_limit integer default 100)
returns table(
  request_id uuid,user_id uuid,username text,display_name text,email text,aura_total bigint,
  category text,reason text,evidence_url text,status text,admin_note text,created_at timestamptz,reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  perform private.require_admin(array['super_admin','admin','moderator']);
  return query
  select r.id::uuid,r.user_id::uuid,p.username::text,p.display_name::text,u.email::text,p.aura_total::bigint,
         r.category::text,r.reason::text,r.evidence_url::text,r.status::text,r.admin_note::text,
         r.created_at::timestamptz,r.reviewed_at::timestamptz
  from private.verification_requests r
  join public.profiles p on p.user_id=r.user_id
  join auth.users u on u.id=r.user_id
  where p_status='all' or r.status=p_status
  order by case r.status when 'pending' then 0 else 1 end,r.created_at asc
  limit least(greatest(coalesce(p_limit,100),1),200);
end; $$;
revoke execute on function public.admin_list_verification_requests(text,integer) from public,anon;
grant execute on function public.admin_list_verification_requests(text,integer) to authenticated;

create or replace function public.admin_review_verification_request(
  p_request uuid,
  p_approve boolean,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_req private.verification_requests%rowtype;
  v_before jsonb;
  v_after jsonb;
  v_name text;
begin
  perform private.require_admin(array['super_admin','admin']);
  select * into v_req from private.verification_requests where id=p_request for update;
  if v_req.id is null then raise exception 'Verification request unavailable'; end if;
  if v_req.status<>'pending' then raise exception 'Verification request is already reviewed'; end if;

  v_before:=to_jsonb(v_req);
  update private.verification_requests
  set status=case when p_approve then 'approved' else 'rejected' end,
      admin_note=nullif(left(trim(coalesce(p_note,'')),1000),''),
      reviewed_by=auth.uid(),reviewed_at=now(),updated_at=now()
  where id=p_request;

  update public.profiles
  set is_verified=p_approve,
      verified_at=case when p_approve then now() else null end,
      updated_at=now()
  where user_id=v_req.user_id;

  select to_jsonb(r) into v_after from private.verification_requests r where r.id=p_request;
  perform private.audit_admin(
    case when p_approve then 'verification_approve' else 'verification_reject' end,
    'user',v_req.user_id::text,v_before,v_after,p_note,
    jsonb_build_object('request_id',p_request)
  );

  select coalesce(display_name,username,'Your account') into v_name from public.profiles where user_id=v_req.user_id;
  perform private.push_notification(
    v_req.user_id,'system',
    case when p_approve then 'Your VYBE account is verified' else 'Verification request reviewed' end,
    case when p_approve then 'Your blue verification badge is now live across VYBE.' else coalesce(nullif(trim(p_note),''),'Your request was not approved this time.') end,
    auth.uid(),'verification',p_request,'/settings',jsonb_build_object('verified',p_approve)
  );

  return jsonb_build_object('ok',true,'verified',p_approve,'user_id',v_req.user_id,'request_id',p_request);
end; $$;
revoke execute on function public.admin_review_verification_request(uuid,boolean,text) from public,anon;
grant execute on function public.admin_review_verification_request(uuid,boolean,text) to authenticated;

create or replace function public.admin_set_user_verification(p_user uuid,p_verified boolean,p_reason text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare v_before jsonb; v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  if char_length(trim(coalesce(p_reason,'')))<3 then raise exception 'Audit reason required'; end if;
  select jsonb_build_object('is_verified',p.is_verified,'verified_at',p.verified_at) into v_before
  from public.profiles p where p.user_id=p_user for update;
  if v_before is null then raise exception 'User unavailable'; end if;
  update public.profiles set is_verified=p_verified,verified_at=case when p_verified then now() else null end,updated_at=now() where user_id=p_user;
  if p_verified then
    update private.verification_requests
    set status='approved',admin_note=coalesce(admin_note,left(trim(p_reason),1000)),reviewed_by=auth.uid(),reviewed_at=now(),updated_at=now()
    where user_id=p_user and status='pending';
  end if;
  select jsonb_build_object('is_verified',p.is_verified,'verified_at',p.verified_at) into v_after from public.profiles p where p.user_id=p_user;
  perform private.audit_admin('verification_override','user',p_user::text,v_before,v_after,p_reason,jsonb_build_object('verified',p_verified));
  perform private.push_notification(
    p_user,'system',case when p_verified then 'Your VYBE account is verified' else 'Verification badge removed' end,
    case when p_verified then 'Your blue verification badge is now live across VYBE.' else 'Your verification status was changed by VYBE support.' end,
    auth.uid(),'verification',p_user,'/settings',jsonb_build_object('verified',p_verified)
  );
  return jsonb_build_object('ok',true,'verified',p_verified);
end; $$;
revoke execute on function public.admin_set_user_verification(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_user_verification(uuid,boolean,text) to authenticated;

-- Keep existing JSON API stable while adding verification state for the signed-in user.
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
    'is_verified',p.is_verified,'verified_at',p.verified_at,
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

-- Admin user JSON can show the blue-tick state without changing the list-users return type.
create or replace function public.admin_get_user(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_out jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin','moderator']);
  select jsonb_build_object(
    'user_id',p.user_id,'username',p.username,'display_name',p.display_name,'bio',p.bio,'avatar_url',p.avatar_url,
    'is_verified',p.is_verified,'verified_at',p.verified_at,
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

commit;
