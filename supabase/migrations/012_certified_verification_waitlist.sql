-- VYBE V11.2 — Certified-only blue-tick waitlist.
-- Apply after 001..011. Existing verification data is preserved.

begin;

create table if not exists private.verification_unlocks (
  user_id uuid primary key references auth.users(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  notified_at timestamptz
);

revoke all on table private.verification_unlocks from public,anon,authenticated;

create or replace function private.verification_certified_min_aura()
returns bigint
language sql
stable
security definer
set search_path=''
as $$
  select r.min_aura::bigint
  from public.aura_ranks r
  where r.active=true and lower(r.slug)='certified'
  order by r.min_aura asc
  limit 1;
$$;
revoke execute on function private.verification_certified_min_aura() from public,anon,authenticated;

create or replace function private.verification_is_eligible(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce((
    select p.onboarding_complete
       and p.aura_total >= coalesce(private.verification_certified_min_aura(),9223372036854775807::bigint)
    from public.profiles p
    where p.user_id=p_user
  ),false);
$$;
revoke execute on function private.verification_is_eligible(uuid) from public,anon,authenticated;

create or replace function private.ensure_verification_unlock(p_user uuid,p_notify boolean default true)
returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_eligible boolean;
  v_verified boolean;
  v_notified timestamptz;
  v_rank jsonb;
begin
  if p_user is null then return false; end if;
  v_eligible:=private.verification_is_eligible(p_user);
  if not v_eligible then return false; end if;

  select p.is_verified,public.get_aura_rank(p.aura_total)
  into v_verified,v_rank
  from public.profiles p where p.user_id=p_user;

  insert into private.verification_unlocks(user_id,unlocked_at)
  values(p_user,now())
  on conflict(user_id) do nothing;

  select notified_at into v_notified from private.verification_unlocks where user_id=p_user for update;
  if p_notify and v_notified is null and not coalesce(v_verified,false) then
    perform private.push_notification(
      p_user,'system','Blue tick waitlist unlocked',
      'You reached Certified. You can now join the VYBE verification waitlist from Settings.',
      null,'verification',p_user,'/settings#verification',
      jsonb_build_object('verification_waitlist_unlocked',true,'rank',v_rank)
    );
    update private.verification_unlocks set notified_at=now() where user_id=p_user;
  end if;
  return true;
end;
$$;
revoke execute on function private.ensure_verification_unlock(uuid,boolean) from public,anon,authenticated;

create or replace function private.notify_verification_unlock_on_aura()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
begin
  if new.onboarding_complete=true
     and new.aura_total >= coalesce(private.verification_certified_min_aura(),9223372036854775807::bigint)
     and coalesce(old.aura_total,0) < coalesce(private.verification_certified_min_aura(),9223372036854775807::bigint) then
    perform private.ensure_verification_unlock(new.user_id,true);
  end if;
  return new;
end;
$$;
revoke execute on function private.notify_verification_unlock_on_aura() from public,anon,authenticated;

drop trigger if exists profiles_verification_unlock_on_aura on public.profiles;
create trigger profiles_verification_unlock_on_aura
after update of aura_total on public.profiles
for each row execute function private.notify_verification_unlock_on_aura();

-- Old pre-V11.2 requests from users below Certified are no longer eligible.
update private.verification_requests r
set status='cancelled',updated_at=now()
where r.status='pending'
  and not private.verification_is_eligible(r.user_id);

create or replace function public.get_my_verification_state()
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_user uuid:=auth.uid();
  v_result jsonb;
  v_eligible boolean;
  v_min bigint;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  v_eligible:=private.ensure_verification_unlock(v_user,true);
  v_min:=private.verification_certified_min_aura();

  select jsonb_build_object(
    'is_verified',p.is_verified,
    'verified_at',p.verified_at,
    'eligible',v_eligible,
    'required_rank','CERTIFIED',
    'required_aura',v_min,
    'current_rank',public.get_aura_rank(p.aura_total),
    'request',(
      select jsonb_build_object(
        'id',r.id,'status',r.status,'created_at',r.created_at,'reviewed_at',r.reviewed_at,
        'admin_note',case when r.status in ('approved','rejected') then r.admin_note else null end
      )
      from private.verification_requests r
      where r.user_id=v_user
      order by r.created_at desc limit 1
    )
  ) into v_result
  from public.profiles p where p.user_id=v_user;

  return coalesce(v_result,jsonb_build_object('is_verified',false,'eligible',false,'request',null));
end;
$$;
revoke execute on function public.get_my_verification_state() from public,anon;
grant execute on function public.get_my_verification_state() to authenticated;

create or replace function public.join_verification_waitlist()
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
  if not private.verification_is_eligible(v_user) then raise exception 'Reach Certified Aura rank to unlock the blue tick waitlist'; end if;
  if exists(select 1 from public.profiles p where p.user_id=v_user and p.is_verified=true) then raise exception 'This account is already verified'; end if;
  if exists(select 1 from private.verification_requests r where r.user_id=v_user and r.status='pending') then
    select id into v_id from private.verification_requests where user_id=v_user and status='pending' order by created_at desc limit 1;
    return jsonb_build_object('ok',true,'already_waitlisted',true,'request_id',v_id,'status','pending');
  end if;

  select max(r.reviewed_at) into v_last_rejected
  from private.verification_requests r where r.user_id=v_user and r.status='rejected';
  if v_last_rejected is not null and v_last_rejected > now()-interval '30 days' then
    raise exception 'You can rejoin the verification waitlist 30 days after the last review';
  end if;

  insert into private.verification_requests(user_id,category,reason,evidence_url,status)
  values(v_user,'other','Certified Aura rank verification waitlist',null,'pending')
  returning id into v_id;

  return jsonb_build_object('ok',true,'already_waitlisted',false,'request_id',v_id,'status','pending');
end;
$$;
revoke execute on function public.join_verification_waitlist() from public,anon;
grant execute on function public.join_verification_waitlist() to authenticated;

create or replace function public.leave_verification_waitlist()
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
end;
$$;
revoke execute on function public.leave_verification_waitlist() from public,anon;
grant execute on function public.leave_verification_waitlist() to authenticated;

-- Compatibility for an older V11 frontend during rolling deployment.
create or replace function public.request_verification(p_category text,p_reason text,p_evidence_url text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  return public.join_verification_waitlist();
end; $$;
revoke execute on function public.request_verification(text,text,text) from public,anon;
grant execute on function public.request_verification(text,text,text) to authenticated;

create or replace function public.cancel_my_verification_request()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  return public.leave_verification_waitlist();
end; $$;
revoke execute on function public.cancel_my_verification_request() from public,anon;
grant execute on function public.cancel_my_verification_request() to authenticated;

create or replace function public.admin_list_verification_waitlist(p_status text default 'pending',p_limit integer default 100)
returns table(
  request_id uuid,user_id uuid,username text,display_name text,email text,aura_total bigint,
  rank jsonb,status text,joined_at timestamptz,reviewed_at timestamptz
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
         public.get_aura_rank(p.aura_total)::jsonb,r.status::text,r.created_at::timestamptz,r.reviewed_at::timestamptz
  from private.verification_requests r
  join public.profiles p on p.user_id=r.user_id
  join auth.users u on u.id=r.user_id
  where (p_status='all' or r.status=p_status)
    and (r.status<>'pending' or private.verification_is_eligible(r.user_id))
  order by case r.status when 'pending' then 0 else 1 end,r.created_at asc
  limit least(greatest(coalesce(p_limit,100),1),200);
end;
$$;
revoke execute on function public.admin_list_verification_waitlist(text,integer) from public,anon;
grant execute on function public.admin_list_verification_waitlist(text,integer) to authenticated;

create or replace function public.admin_review_verification_request(p_request uuid,p_approve boolean,p_note text default '')
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_req private.verification_requests%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  perform private.require_admin(array['super_admin','admin']);
  select * into v_req from private.verification_requests where id=p_request for update;
  if v_req.id is null then raise exception 'Waitlist entry unavailable'; end if;
  if v_req.status<>'pending' then raise exception 'Waitlist entry is already reviewed'; end if;
  if p_approve and not private.verification_is_eligible(v_req.user_id) then raise exception 'User must still be Certified or higher before a blue tick can be granted'; end if;

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
    case when p_approve then 'verification_waitlist_approve' else 'verification_waitlist_decline' end,
    'user',v_req.user_id::text,v_before,v_after,p_note,jsonb_build_object('request_id',p_request)
  );

  perform private.push_notification(
    v_req.user_id,'system',
    case when p_approve then 'Your VYBE blue tick is live' else 'Verification waitlist reviewed' end,
    case when p_approve then 'VYBE HQ approved your Certified account. Your blue tick is now active.' else coalesce(nullif(trim(p_note),''),'VYBE HQ did not approve this waitlist entry.') end,
    auth.uid(),'verification',p_request,'/settings#verification',jsonb_build_object('verified',p_approve,'waitlist',true)
  );

  return jsonb_build_object('ok',true,'verified',p_approve,'user_id',v_req.user_id,'request_id',p_request);
end;
$$;
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
  if p_verified and not private.verification_is_eligible(p_user) then raise exception 'User must be Certified or higher before a blue tick can be granted'; end if;

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
  perform private.audit_admin('verification_override','user',p_user::text,v_before,v_after,p_reason,jsonb_build_object('verified',p_verified,'certified_required',true));
  perform private.push_notification(
    p_user,'system',case when p_verified then 'Your VYBE blue tick is live' else 'Verification badge removed' end,
    case when p_verified then 'VYBE HQ verified your Certified account.' else 'Your verification status was changed by VYBE HQ.' end,
    auth.uid(),'verification',p_user,'/settings#verification',jsonb_build_object('verified',p_verified)
  );
  return jsonb_build_object('ok',true,'verified',p_verified);
end;
$$;
revoke execute on function public.admin_set_user_verification(uuid,boolean,text) from public,anon;
grant execute on function public.admin_set_user_verification(uuid,boolean,text) to authenticated;


-- Add explicit eligibility to the existing admin user JSON without changing its RPC signature.
create or replace function public.admin_get_user(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_role text; v_out jsonb;
begin
  v_role:=private.require_admin(array['super_admin','admin','moderator']);
  select jsonb_build_object(
    'user_id',p.user_id,'username',p.username,'display_name',p.display_name,'bio',p.bio,'avatar_url',p.avatar_url,
    'is_verified',p.is_verified,'verified_at',p.verified_at,'verification_eligible',private.verification_is_eligible(p.user_id),
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

-- Backfill currently eligible users and emit the unlock notification once.
do $$
declare v_user uuid;
begin
  for v_user in
    select p.user_id from public.profiles p
    where p.onboarding_complete=true
      and p.is_verified=false
      and private.verification_is_eligible(p.user_id)
  loop
    perform private.ensure_verification_unlock(v_user,true);
  end loop;
end $$;

commit;
