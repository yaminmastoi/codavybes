import { supabase } from '../lib/supabase'

export async function getPlatformLeaderboard(limit = 10) {
  if (!supabase) throw new Error('Supabase is not configured')
  const { data, error } = await supabase.rpc('get_platform_leaderboard', { p_limit: Math.min(100, Math.max(1, Number(limit) || 10)) })
  if (error) throw error
  return data || []
}
