import { supabase, isSupabaseConfigured } from '../lib/supabase'
import { authRedirectUrl, nativeAuthPlatform, openOAuthUrl } from './authRedirectService'

function requireSupabase() {
  if (!isSupabaseConfigured || !supabase) {
    throw new Error('Supabase is not configured. Add VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY to .env.local.')
  }
  return supabase
}

export async function signUpWithEmail({ email, password }) {
  const client = requireSupabase()
  const redirectTo = authRedirectUrl('callback')
  const { data, error } = await client.auth.signUp({
    email: email.trim().toLowerCase(),
    password,
    options: { emailRedirectTo: redirectTo },
  })
  if (error) throw error
  return data
}

export async function signInWithEmail({ email, password }) {
  const client = requireSupabase()
  const { data, error } = await client.auth.signInWithPassword({
    email: email.trim().toLowerCase(),
    password,
  })
  if (error) throw error
  return data
}

export async function signInWithGoogle() {
  const client = requireSupabase()
  const native = nativeAuthPlatform()
  const { data, error } = await client.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: authRedirectUrl('callback'),
      skipBrowserRedirect: Boolean(native),
    },
  })
  if (error) throw error
  if (native) await openOAuthUrl(data.url)
  return data
}

export async function resendSignupConfirmation(email) {
  const client = requireSupabase()
  const { data, error } = await client.auth.resend({
    type: 'signup',
    email: email.trim().toLowerCase(),
    options: { emailRedirectTo: authRedirectUrl('callback') },
  })
  if (error) throw error
  return data
}


export async function sendPasswordReset(email) {
  const client = requireSupabase()
  const { data, error } = await client.auth.resetPasswordForEmail(email.trim().toLowerCase(), {
    redirectTo: authRedirectUrl('reset-password'),
  })
  if (error) throw error
  return data
}

export async function updatePassword(password) {
  const client = requireSupabase()
  const { data, error } = await client.auth.updateUser({ password })
  if (error) throw error
  return data
}

export async function signOut() {
  const client = requireSupabase()
  const { error } = await client.auth.signOut()
  if (error) throw error
}
