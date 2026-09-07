import { supabase } from '../lib/supabase'
import { enrichVerified } from './verificationService'

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

async function rpc(name, params = {}) {
  const { data, error } = await client().rpc(name, params)
  if (error) throw error
  return data
}

export async function getMomentThread(targetId) {
  const data = await rpc('get_moment_thread', { p_target: targetId })
  if (Array.isArray(data?.comments)) data.comments = await enrichVerified(data.comments, 'user_id', 'is_verified')
  return data
}

export function toggleMomentReaction(targetId, emoji = '❤️') {
  return rpc('toggle_moment_reaction', { p_target: targetId, p_emoji: emoji })
}

export function addMomentComment(targetId, body) {
  return rpc('add_moment_comment', { p_target: targetId, p_body: body })
}

export async function getPublicMoment(targetId) {
  const data = await rpc('get_public_moment', { p_target: targetId })
  if (!data) return data
  const [row] = await enrichVerified([data], 'author_id', 'author_verified')
  return row
}

export function recordMomentShare(targetId, platform = 'native') {
  return rpc('record_moment_share', { p_target: targetId, p_platform: platform })
}
