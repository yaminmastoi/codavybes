-- CodaVybes V13.7 — profile Threads contain only public Rising Lab posts.

begin;

create or replace function public.get_my_moments(p_limit integer default 20)
returns table (
  target_id uuid,
  content_text text,
  context_label text,
  aura_count integer,
  unique_givers integer,
  is_aura_moment boolean,
  fyp_eligible boolean,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select t.id, t.content_text, t.context_label, t.aura_count, t.unique_givers,
         t.is_aura_moment, t.fyp_eligible, t.created_at
  from public.aura_targets t
  where t.owner_id = auth.uid()
    and t.target_type = 'post'
    and t.visibility = 'public'
    and t.status = 'active'
  order by t.created_at desc
  limit least(greatest(coalesce(p_limit,20),1),50);
$$;

revoke execute on function public.get_my_moments(integer) from public, anon;
grant execute on function public.get_my_moments(integer) to authenticated;

commit;
