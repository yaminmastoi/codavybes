import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { supabase, isSupabaseConfigured } from '../lib/supabase'
import { getOnboardingState } from '../services/onboardingService'
import { initializeAuthPlatformBridge } from '../services/authRedirectService'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null)
  const [user, setUser] = useState(null)
  const [onboarding, setOnboarding] = useState(null)
  const [onboardingLoading, setOnboardingLoading] = useState(false)
  const [loading, setLoading] = useState(isSupabaseConfigured)
  const [introReady, setIntroReady] = useState(!isSupabaseConfigured)

  useEffect(() => {
    if (!isSupabaseConfigured) return undefined
    const timer = window.setTimeout(() => setIntroReady(true), 2450)
    return () => window.clearTimeout(timer)
  }, [])

  useEffect(() => {
    if (!isSupabaseConfigured) return undefined
    let cleanup = () => {}
    let mounted = true
    initializeAuthPlatformBridge()
      .then((dispose) => { if (mounted) cleanup = dispose; else dispose() })
      .catch((error) => console.error('Unable to initialize native auth:', error))
    return () => { mounted = false; cleanup() }
  }, [])

  const refreshOnboarding = useCallback(async () => {
    if (!supabase) {
      setOnboarding(null)
      return null
    }
    try {
      setOnboardingLoading(true)
      const { data } = await supabase.auth.getSession()
      if (!data.session?.user) {
        setOnboarding(null)
        setOnboardingLoading(false)
        return null
      }
      const state = await getOnboardingState()
      setOnboarding(state)
      setOnboardingLoading(false)
      return state
    } catch (error) {
      console.error('Unable to load onboarding state:', error)
      setOnboarding(null)
      setOnboardingLoading(false)
      return null
    }
  }, [])

  useEffect(() => {
    if (!supabase) {
      setLoading(false)
      return undefined
    }

    let mounted = true

    supabase.auth.getSession().then(async ({ data, error }) => {
      if (!mounted) return
      let restored = data?.session ?? null
      if (error) console.warn('CodaVybes session restore:', error)
      // Native shells can resume after their JS timers were suspended. If a
      // persisted refresh token exists, refresh it before deciding the user is out.
      if (restored) {
        const expiresSoon = !restored.expires_at || restored.expires_at * 1000 < Date.now() + 10 * 60 * 1000
        if (expiresSoon) {
          const refreshed = await supabase.auth.refreshSession().catch(() => null)
          restored = refreshed?.data?.session || restored
        }
      }
      if (!mounted) return
      if (restored?.user) setOnboardingLoading(true)
      setSession(restored)
      setUser(restored?.user ?? null)
      setLoading(false)
    }).catch((error) => {
      console.error('Unable to restore CodaVybes session:', error)
      if (mounted) setLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession((previous) => {
        if (nextSession?.user && previous?.user?.id !== nextSession.user.id) setOnboardingLoading(true)
        return nextSession ?? null
      })
      setUser(nextSession?.user ?? null)
      if (!nextSession) { setOnboarding(null); setOnboardingLoading(false) }
    })

    return () => {
      mounted = false
      subscription.unsubscribe()
    }
  }, [])

  useEffect(() => {
    if (!loading && session?.user) refreshOnboarding()
  }, [loading, session?.user?.id, refreshOnboarding])

  const value = useMemo(() => ({
    session,
    user,
    onboarding,
    onboardingLoading,
    loading: loading || !introReady,
    configured: isSupabaseConfigured,
    refreshOnboarding,
  }), [session, user, onboarding, onboardingLoading, loading, introReady, refreshOnboarding])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth must be used inside AuthProvider')
  return value
}
