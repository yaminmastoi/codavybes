-- CodaVybes native push registrations. Device tokens are private account data.
begin;

create table if not exists private.push_device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android','ios')),
  device_id text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists push_device_tokens_user_active_idx
  on private.push_device_tokens(user_id, active, updated_at desc);

revoke all on private.push_device_tokens from public, anon, authenticated;
grant select, insert, update, delete on private.push_device_tokens to service_role;

create or replace function public.register_my_push_token(
  p_token text,
  p_platform text,
  p_device_id text default null
) returns jsonb
language plpgsql security definer
set search_path = public, private, auth, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := btrim(coalesce(p_token,''));
  v_platform text := lower(btrim(coalesce(p_platform,'')));
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if length(v_token) < 20 or length(v_token) > 4096 then raise exception 'INVALID_PUSH_TOKEN'; end if;
  if v_platform not in ('android','ios') then raise exception 'INVALID_PUSH_PLATFORM'; end if;

  insert into private.push_device_tokens(user_id, token, platform, device_id, active, updated_at, last_seen_at)
  values(v_uid, v_token, v_platform, nullif(btrim(coalesce(p_device_id,'')),''), true, now(), now())
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    device_id = excluded.device_id,
    active = true,
    updated_at = now(),
    last_seen_at = now();

  return jsonb_build_object('ok',true);
end;
$$;

revoke all on function public.register_my_push_token(text,text,text) from public, anon;
grant execute on function public.register_my_push_token(text,text,text) to authenticated;

create or replace function public.unregister_my_push_token(p_token text) returns void
language sql security definer
set search_path = public, private, auth, pg_temp
as $$
  update private.push_device_tokens
     set active=false, updated_at=now()
   where user_id=auth.uid() and token=p_token;
$$;
revoke all on function public.unregister_my_push_token(text) from public, anon;
grant execute on function public.unregister_my_push_token(text) to authenticated;

commit;
