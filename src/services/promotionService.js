import { supabase } from '../lib/supabase'

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

export async function getActivePromotions(limit = 6) {
  const { data, error } = await client().rpc('get_active_sponsorships', { p_limit: limit })
  if (error) throw error
  return data ?? []
}

export async function recordPromotionEvent(id, event) {
  if (!id) return
  const { error } = await client().rpc('record_promotion_event', { p_promotion: id, p_event: event })
  if (error) console.warn('Promotion analytics:', error.message)
}
