import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { supabase, isSupabaseConfigured } from '../lib/supabase'
import { getOnboardingState } from '../services/onboardingService'

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
    const timer = window.setTimeout(() => setIntroReady(true), 1450)
    return () => window.clearTimeout(timer)
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

    supabase.auth.getSession().then(({ data }) => {
      if (!mounted) return
      if (data.session?.user) setOnboardingLoading(true)
      setSession(data.session ?? null)
      setUser(data.session?.user ?? null)
      setLoading(false)
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
