-- VYBE V11.1 — Fix admin verification queue RETURN QUERY type mismatch.
-- Run AFTER 010_verification_password_ui.sql on an existing database.
-- Safe to run more than once.

begin;

create or replace function public.admin_list_verification_requests(
  p_status text default 'pending',
  p_limit integer default 100
)
returns table(
  request_id uuid,
  user_id uuid,
  username text,
  display_name text,
  email text,
  aura_total bigint,
  category text,
  reason text,
  evidence_url text,
  status text,
  admin_note text,
  created_at timestamptz,
  reviewed_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  perform private.require_admin(array['super_admin','admin','moderator']);

  return query
  select
    r.id::uuid,
    r.user_id::uuid,
    p.username::text,
    p.display_name::text,
    u.email::text,
    p.aura_total::bigint,
    r.category::text,
    r.reason::text,
    r.evidence_url::text,
    r.status::text,
    r.admin_note::text,
    r.created_at::timestamptz,
    r.reviewed_at::timestamptz
  from private.verification_requests r
  join public.profiles p on p.user_id = r.user_id
  join auth.users u on u.id = r.user_id
  where p_status = 'all' or r.status = p_status
  order by
    case r.status when 'pending' then 0 else 1 end,
    r.created_at asc
  limit least(greatest(coalesce(p_limit,100),1),200);
end;
$$;

revoke execute on function public.admin_list_verification_requests(text,integer) from public,anon;
grant execute on function public.admin_list_verification_requests(text,integer) to authenticated;

commit;
