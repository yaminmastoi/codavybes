import { supabase } from '../lib/supabase'
import { enrichVerified } from './verificationService'

function requireSupabase() {
  if (!supabase) throw new Error('Supabase is not configured')
}

export async function getAuraDashboard() {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_my_aura_dashboard')
  if (error) throw error
  return data
}


export async function getAuraLedger(limit = 30) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_my_aura_ledger', { p_limit: limit })
  if (error) throw error
  return data ?? []
}

export async function getForYouFeed(limit = 20, offset = 0) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_for_you_feed', {
    p_limit: limit,
    p_offset: offset,
  })
  if (error) throw error
  return enrichVerified(data ?? [], 'author_id', 'author_verified')
}


export async function getRisingFeed(limit = 20, offset = 0) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_rising_feed', {
    p_limit: limit,
    p_offset: offset,
  })
  if (error) throw error
  return enrichVerified(data ?? [], 'author_id', 'author_verified')
}

export async function giveAura(targetId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('give_aura', {
    p_target_id: targetId,
  })
  if (error) throw error
  return data
}

export async function createMoment(text, contextLabel = 'CodaVybes') {
  requireSupabase()
  const { data, error } = await supabase.rpc('create_vybe_moment', {
    p_text: text,
    p_context_label: contextLabel,
  })
  if (error) throw error
  return data
}

export async function getMyThreads(limit = 20) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_my_moments', { p_limit: limit })
  if (error) throw error
  return data ?? []
}

export async function getAuraBoard(windowName = 'week', limit = 20) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_aura_board', {
    p_window: windowName,
    p_limit: limit,
  })
  if (error) throw error
  return enrichVerified(data ?? [], 'user_id', 'is_verified')
}
