-- CodaVybes V13.18 — universal onboarding + custom 4-digit email verification support.
-- DOB remains profile metadata only. It must never gate visibility, friendship or chat.

begin;

alter table private.user_private add column if not exists gender text;

-- Existing rows that were marked ineligible by the historical age gate become usable.
update private.user_private
set eligibility_status='eligible', eligibility_checked_at=coalesce(eligibility_checked_at,now())
where eligibility_status is distinct from 'eligible';

-- Compatibility keeps the old helper name so existing policies/RPCs continue to work,
-- but age is no longer part of the decision.
create or replace function private.age_compatible(p_a uuid,p_b uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select p_a is not null and p_b is not null
    and private.account_is_active(p_a)
    and private.account_is_active(p_b);
$$;
revoke execute on function private.age_compatible(uuid,uuid) from public,anon,authenticated;

create or replace function public.set_birth_date_and_gender(p_birth_date date,p_gender text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid();
  v_existing date;
  v_gender text:=lower(trim(coalesce(p_gender,'')));
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_birth_date is null or p_birth_date>current_date or p_birth_date<current_date-interval '120 years' then
    raise exception 'Enter a valid birth date.';
  end if;
  if v_gender not in ('male','female','non_binary','prefer_not_to_say','other') then
    raise exception 'Choose a valid gender option.';
  end if;

  insert into private.user_private(user_id) values(v_user) on conflict(user_id) do nothing;
  select birth_date into v_existing from private.user_private where user_id=v_user for update;
  if v_existing is not null and v_existing<>p_birth_date then raise exception 'Birthday is already locked. Contact support for a correction.'; end if;

  update private.user_private
  set birth_date=coalesce(v_existing,p_birth_date),
      gender=v_gender,
      eligibility_status='eligible',
      eligibility_checked_at=now(),
      updated_at=now()
  where user_id=v_user;

  return jsonb_build_object('ok',true,'birth_date',p_birth_date,'gender',v_gender);
end; $$;
revoke execute on function public.set_birth_date_and_gender(date,text) from public,anon;
grant execute on function public.set_birth_date_and_gender(date,text) to authenticated;

-- Keep the old RPC callable for older clients, but remove age gating.
create or replace function public.set_birth_date(p_birth_date date)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid();
  v_existing date;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_birth_date is null or p_birth_date>current_date or p_birth_date<current_date-interval '120 years' then
    raise exception 'Enter a valid birth date.';
  end if;
  insert into private.user_private(user_id) values(v_user) on conflict(user_id) do nothing;
  select birth_date into v_existing from private.user_private where user_id=v_user for update;
  if v_existing is not null then raise exception 'Birthday is already locked. Contact support for a correction.'; end if;
  update private.user_private set birth_date=p_birth_date,eligibility_status='eligible',eligibility_checked_at=now(),updated_at=now() where user_id=v_user;
  return jsonb_build_object('ok',true,'birth_date',p_birth_date);
end; $$;
revoke execute on function public.set_birth_date(date) from public,anon;
grant execute on function public.set_birth_date(date) to authenticated;

create or replace function public.complete_onboarding()
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid();
  v_profile public.profiles%rowtype;
  v_private private.user_private%rowtype;
  v_interest_count integer;
  v_min_interests integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_profile from public.profiles where user_id=v_user for update;
  select * into v_private from private.user_private where user_id=v_user;
  select count(*) into v_interest_count from public.user_interests where user_id=v_user;
  select min_interests into v_min_interests from public.app_config where id=1;

  if v_profile.username is null then raise exception 'Choose a username first.'; end if;
  if v_private.birth_date is null then raise exception 'Add your birthday first.'; end if;
  if v_private.gender is null or trim(v_private.gender)='' then raise exception 'Choose a gender option.'; end if;
  if v_profile.display_name is null or trim(v_profile.display_name)='' then raise exception 'Add a display name.'; end if;
  if v_interest_count<v_min_interests then raise exception 'Choose at least % interests.',v_min_interests; end if;
  update public.profiles set onboarding_complete=true where user_id=v_user;
  return jsonb_build_object('ok',true,'aura_total',v_profile.aura_total);
end; $$;
revoke execute on function public.complete_onboarding() from public,anon;
grant execute on function public.complete_onboarding() to authenticated;

create or replace function public.get_my_onboarding_state()
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid:=auth.uid(); v_result jsonb; v_access boolean; v_raw_status text;
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
    'gender',up.gender,'gender_set',up.gender is not null,
    'eligibility_status','eligible','account_status',coalesce(v_raw_status,'active'),'app_access',v_access,
    'interests',coalesce((select jsonb_agg(i.slug order by i.sort_order) from public.user_interests ui join public.interests i on i.id=ui.interest_id where ui.user_id=v_user),'[]'::jsonb),
    'username_next_change_at',case when p.username_changed_at is null then null else p.username_changed_at+make_interval(days=>cfg.username_change_days) end
  ) into v_result
  from public.profiles p join private.user_private up on up.user_id=p.user_id cross join public.app_config cfg
  where p.user_id=v_user and cfg.id=1;
  return v_result;
end; $$;
revoke execute on function public.get_my_onboarding_state() from public,anon;
grant execute on function public.get_my_onboarding_state() to authenticated;

-- Service-role-only challenge store for custom 4-digit email codes.
create table if not exists public.auth_email_otp_challenges(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  purpose text not null check (purpose in ('signup','signin','oauth','reauth')),
  code_hash text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  attempts integer not null default 0,
  max_attempts integer not null default 5
);
alter table public.auth_email_otp_challenges enable row level security;
revoke all on table public.auth_email_otp_challenges from public,anon,authenticated;
grant select,insert,update,delete on table public.auth_email_otp_challenges to service_role;
create index if not exists auth_email_otp_user_created_idx on public.auth_email_otp_challenges(user_id,created_at desc);
create index if not exists auth_email_otp_email_created_idx on public.auth_email_otp_challenges(lower(email),created_at desc);

commit;
