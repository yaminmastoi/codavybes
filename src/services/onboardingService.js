import { supabase, isSupabaseConfigured } from '../lib/supabase'

function requireSupabase() {
  if (!isSupabaseConfigured || !supabase) {
    throw new Error('Supabase is not configured.')
  }
  return supabase
}

export async function getOnboardingState() {
  const client = requireSupabase()
  const { data, error } = await client.rpc('get_my_onboarding_state')
  if (error) throw error
  return data || null
}

export async function checkUsernameAvailability(username) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('check_username_available', { p_username: username })
  if (error) throw error
  return data
}

export async function claimUsername(username) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('claim_username', { p_username: username })
  if (error) throw error
  return data
}

export async function setBirthDate(birthDate) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('set_birth_date', { p_birth_date: birthDate })
  if (error) throw error
  return data
}

export async function setBirthDateAndGender({ birthDate, gender }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('set_birth_date_and_gender', {
    p_birth_date: birthDate,
    p_gender: gender,
  })
  if (error) throw error
  return data
}

export async function saveProfileDetails({ displayName, bio }) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('set_profile_details', {
    p_display_name: displayName,
    p_bio: bio,
  })
  if (error) throw error
  return data
}

export async function listInterests() {
  const client = requireSupabase()
  const { data, error } = await client
    .from('interests')
    .select('slug,label,icon,sort_order')
    .eq('active', true)
    .order('sort_order', { ascending: true })
  if (error) throw error
  return data || []
}

export async function saveInterests(slugs) {
  const client = requireSupabase()
  const { data, error } = await client.rpc('set_my_interests', { p_slugs: slugs })
  if (error) throw error
  return data
}

export async function completeOnboarding() {
  const client = requireSupabase()
  const { data, error } = await client.rpc('complete_onboarding')
  if (error) throw error
  return data
}
