import { supabase } from '../lib/supabase'
import { enrichVerified } from './verificationService'

function requireSupabase() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}


async function getPlusMap(userIds = []) {
  const ids = [...new Set(userIds.filter(Boolean))]
  if (!ids.length) return new Map()
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_plus_statuses', { p_user_ids: ids })
  if (error) {
    // Migration 015 may not be installed yet; discovery should still work without the premium mark.
    console.warn('CodaVybes+ status unavailable:', error.message)
    return new Map()
  }
  return new Map((data || []).map((row) => [row.user_id, !!row.is_plus]))
}

async function enrichIdentity(rows = [], idKey = 'user_id') {
  if (!rows?.length) return rows || []
  const verifiedRows = await enrichVerified(rows, idKey, 'is_verified')
  const plusMap = await getPlusMap(verifiedRows.map((row) => row?.[idKey]))
  return verifiedRows.map((row) => ({ ...row, is_plus: plusMap.get(row?.[idKey]) || false }))
}

export async function getDiscoverPeople(mode = 'for_you', limit = 24) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_discover_people', { p_limit: limit, p_mode: mode })
  if (error) throw error
  return enrichIdentity(data ?? [], 'user_id')
}

export async function sendMeetRequest(targetUserId) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('send_meet_request', { p_target: targetUserId })
  if (error) throw error
  return data
}

export async function getMeetRequests(limit = 30) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_meet_requests', { p_limit: limit })
  if (error) throw error
  return enrichIdentity(data ?? [], 'other_user_id')
}

export async function respondMeetRequest(requestId, accept) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('respond_meet_request', { p_request: requestId, p_accept: accept })
  if (error) throw error
  return data
}

export async function getMyMeetSessions(limit = 20) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_my_meet_sessions', { p_limit: limit })
  if (error) throw error
  return enrichIdentity(data ?? [], 'other_user_id')
}

export async function getMeetSession(sessionId) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_meet_session', { p_session: sessionId })
  if (error) throw error
  if (!data) return data
  const otherId = data.other_user_id || data.other?.user_id || data.other?.id
  if (otherId) {
    const [row] = await enrichIdentity([{ user_id: otherId }], 'user_id')
    if (data.other) {
      data.other.is_verified = !!row?.is_verified
      data.other.is_plus = !!row?.is_plus
    } else {
      data.other_verified = !!row?.is_verified
      data.other_plus = !!row?.is_plus
    }
  }
  return data
}

export async function getMeetMessages(sessionId, limit = 100) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_meet_messages', { p_session: sessionId, p_limit: limit })
  if (error) throw error
  return data ?? []
}

export async function sendMeetMessage(sessionId, body) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('send_meet_message', { p_session: sessionId, p_body: body })
  if (error) throw error
  return data
}

export async function decideMeet(sessionId, decision) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('decide_meet', { p_session: sessionId, p_decision: decision })
  if (error) throw error
  return data
}

export async function getMyConnections(limit = 50) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_my_connections', { p_limit: limit })
  if (error) throw error
  return enrichIdentity(data ?? [], 'user_id')
}

export async function getBondWithUser(userId) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_bond_with_user', { p_user: userId })
  if (error) throw error
  return data
}

export function subscribeToMeetSession(sessionId, onChange) {
  const client = requireSupabase()
  const channel = client
    .channel(`vybe-meet-${sessionId}-${Math.random().toString(36).slice(2)}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'meet_messages', filter: `session_id=eq.${sessionId}` }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'meet_sessions', filter: `id=eq.${sessionId}` }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'meet_decisions', filter: `session_id=eq.${sessionId}` }, onChange)
    .subscribe()

  return () => client.removeChannel(channel)
}
