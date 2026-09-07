import { supabase } from '../lib/supabase'

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

export async function getPreferences() {
  const { data, error } = await client().rpc('get_my_preferences')
  if (error) throw error
  return data ?? {}
}

export async function updatePreferences(patch) {
  const { data, error } = await client().rpc('update_my_preferences', { p_patch: patch })
  if (error) throw error
  return data ?? {}
}
