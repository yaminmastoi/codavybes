import { supabase } from '../lib/supabase'

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

export async function getPlatformPosts(limit = 2) {
  const { data, error } = await client().rpc('get_platform_posts', { p_limit: limit })
  if (error) throw error
  return data ?? []
}
