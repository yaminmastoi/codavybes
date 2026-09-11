-- Remove remaining age-based delivery filters from user-visible content.
-- DOB stays private profile data only.
begin;

-- Announcements are visible to every active authenticated user while live.
drop policy if exists "read live announcements" on public.announcements;
create policy "read live announcements" on public.announcements
for select to authenticated
using (active=true and starts_at<=now() and (ends_at is null or ends_at>now()));

-- Legacy min_age is retained only for schema/backward compatibility. It no
-- longer controls delivery and is normalized by trigger on future writes.
create or replace function public.normalize_sponsored_promotion_audience()
returns trigger language plpgsql set search_path='' as $$
begin
  new.min_age := 10;
  return new;
end;
$$;
drop trigger if exists sponsored_promotions_universal_audience on public.sponsored_promotions;
create trigger sponsored_promotions_universal_audience
before insert or update on public.sponsored_promotions
for each row execute function public.normalize_sponsored_promotion_audience();
update public.sponsored_promotions set min_age=10 where min_age<>10;

create or replace function public.get_active_sponsorships(p_limit integer default 6)
returns table(id uuid,brand_name text,headline text,body text,image_url text,destination_url text,cta_label text,priority integer,min_age integer)
language plpgsql stable security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
  if v_user is null or not private.account_is_active(v_user) then raise exception 'Account unavailable'; end if;
  return query
  select p.id,p.brand_name::text,p.headline::text,p.body::text,p.image_url::text,p.destination_url::text,p.cta_label::text,p.priority,p.min_age
  from public.sponsored_promotions p
  where p.active=true and p.starts_at<=now() and (p.ends_at is null or p.ends_at>now())
  order by p.priority desc,md5(p.id::text||v_user::text||current_date::text)
  limit least(greatest(coalesce(p_limit,6),1),12);
end;
$$;
revoke execute on function public.get_active_sponsorships(integer) from public,anon;
grant execute on function public.get_active_sponsorships(integer) to authenticated;

commit;
