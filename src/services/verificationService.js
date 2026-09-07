import { supabase } from '../lib/supabase'

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

export async function getMyVerificationState() {
  const { data, error } = await client().rpc('get_my_verification_state')
  if (error) throw error
  return data || { is_verified: false, eligible: false, request: null }
}

export async function joinVerificationWaitlist() {
  const { data, error } = await client().rpc('join_verification_waitlist')
  if (error) throw error
  return data
}

export async function leaveVerificationWaitlist() {
  const { data, error } = await client().rpc('leave_verification_waitlist')
  if (error) throw error
  return data
}

// Compatibility aliases for any older component/import that survives a partial deployment.
export const requestVerification = () => joinVerificationWaitlist()
export const cancelVerificationRequest = () => leaveVerificationWaitlist()

export async function getVerificationMap(userIds = []) {
  const ids = [...new Set(userIds.filter(Boolean))]
  if (!ids.length) return new Map()
  const { data, error } = await client()
    .from('profiles')
    .select('user_id,is_verified')
    .in('user_id', ids)
  if (error) { console.warn('Verification status unavailable:', error.message); return new Map() }
  return new Map((data || []).map((row) => [row.user_id, !!row.is_verified]))
}

export async function enrichVerified(rows = [], idKey = 'user_id', outputKey = 'is_verified') {
  if (!rows?.length) return rows || []
  const map = await getVerificationMap(rows.map((row) => row?.[idKey]))
  return rows.map((row) => ({ ...row, [outputKey]: map.get(row?.[idKey]) || false }))
}
