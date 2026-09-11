import { supabase, isSupabaseConfigured } from '../lib/supabase'

const PENDING_KEY = 'codavybes-email-otp-pending-v1'

function requireSupabase() {
  if (!isSupabaseConfigured || !supabase) throw new Error('Supabase is not configured.')
  return supabase
}

function savePending(challenge) {
  if (typeof window === 'undefined') return
  window.localStorage.setItem(PENDING_KEY, JSON.stringify(challenge))
  window.dispatchEvent(new CustomEvent('codavybes:otp-pending', { detail: challenge }))
}

export function getPendingSecondFactor() {
  if (typeof window === 'undefined') return null
  try {
    const parsed = JSON.parse(window.localStorage.getItem(PENDING_KEY) || 'null')
    if (!parsed?.challenge_id || !parsed?.email) return null
    if (parsed.expires_at && new Date(parsed.expires_at).getTime() <= Date.now()) {
      window.localStorage.removeItem(PENDING_KEY)
      return null
    }
    return parsed
  } catch {
    return null
  }
}

export function clearPendingSecondFactor() {
  if (typeof window === 'undefined') return
  window.localStorage.removeItem(PENDING_KEY)
  window.dispatchEvent(new CustomEvent('codavybes:otp-cleared'))
}

async function invoke(body) {
  const client = requireSupabase()
  const { data, error } = await client.functions.invoke('email-auth-otp', { body })
  if (error) {
    // Supabase wraps non-2xx Edge Function responses in FunctionsHttpError.
    // Surface the function's own safe error message instead of the generic
    // “Edge Function returned a non-2xx status code” text.
    let message = error.message || 'Could not contact CodaVybes verification service.'
    const response = error.context
    if (response && typeof response.clone === 'function') {
      try {
        const payload = await response.clone().json()
        if (payload?.error) message = String(payload.error)
      } catch {}
    }
    throw new Error(message)
  }
  if (!data?.ok) throw new Error(data?.error || 'Verification request failed.')
  return data
}

export async function beginPasswordSecondFactor({ mode, email, password }) {
  const result = await invoke({
    action: 'start_password',
    mode,
    email: String(email || '').trim().toLowerCase(),
    password,
  })
  const pending = {
    challenge_id: result.challenge_id,
    email: result.email,
    masked_email: result.masked_email,
    expires_at: result.expires_at,
    purpose: mode,
  }
  savePending(pending)
  return pending
}

export async function beginAuthenticatedSecondFactor({ purpose = 'oauth' } = {}) {
  const client = requireSupabase()
  const result = await invoke({ action: 'start_authenticated', purpose })
  const pending = {
    challenge_id: result.challenge_id,
    email: result.email,
    masked_email: result.masked_email,
    expires_at: result.expires_at,
    purpose,
  }
  savePending(pending)
  // Keep other devices signed in, but remove this just-created local session.
  await client.auth.signOut({ scope: 'local' }).catch(() => null)
  return pending
}

export async function resendSecondFactor() {
  const current = getPendingSecondFactor()
  if (!current) throw new Error('Verification session expired. Sign in again.')
  const result = await invoke({
    action: 'resend',
    challenge_id: current.challenge_id,
    email: current.email,
  })
  const pending = {
    ...current,
    challenge_id: result.challenge_id,
    expires_at: result.expires_at,
    masked_email: result.masked_email || current.masked_email,
  }
  savePending(pending)
  return pending
}

export async function verifySecondFactor(code) {
  const client = requireSupabase()
  const current = getPendingSecondFactor()
  if (!current) throw new Error('Verification session expired. Sign in again.')
  const token = String(code || '').replace(/\D/g, '')
  if (!/^\d{4}$/.test(token)) throw new Error('Enter the 4-digit verification code.')

  const result = await invoke({
    action: 'verify',
    challenge_id: current.challenge_id,
    email: current.email,
    code: token,
  })

  const { data, error } = await client.auth.verifyOtp({
    token_hash: result.token_hash,
    type: 'email',
  })
  if (error) throw error
  if (!data.session) throw new Error('Verification succeeded but the session could not be created.')
  clearPendingSecondFactor()
  return data
}
