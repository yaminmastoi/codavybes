import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import { useAuth } from './AuthContext'
import { getCommerceSummary } from '../services/commerceService'
import { supabase } from '../lib/supabase'

const CommerceContext = createContext(null)

export function CommerceProvider({ children }) {
  const { user } = useAuth()
  const [summary, setSummary] = useState(null)
  const [loading, setLoading] = useState(true)

  const refreshCommerce = useCallback(async () => {
    if (!user?.id) { setSummary(null); setLoading(false); return null }
    try {
      const next = await getCommerceSummary()
      setSummary(next)
      return next
    } catch (error) {
      console.error('Commerce config:', error)
      setSummary(null)
      return null
    } finally { setLoading(false) }
  }, [user?.id])

  useEffect(() => { setLoading(true); refreshCommerce() }, [refreshCommerce])
  useEffect(() => {
    const onFocus = () => refreshCommerce()
    const onVisibility = () => { if (document.visibilityState === 'visible') refreshCommerce() }
    window.addEventListener('focus', onFocus)
    document.addEventListener('visibilitychange', onVisibility)
    const timer = window.setInterval(refreshCommerce, 30000)
    return () => { window.removeEventListener('focus', onFocus); document.removeEventListener('visibilitychange', onVisibility); window.clearInterval(timer) }
  }, [refreshCommerce])


  useEffect(() => {
    if (!supabase || !user?.id) return undefined
    let timer
    const refresh = () => { clearTimeout(timer); timer = setTimeout(refreshCommerce, 120) }
    const channel = supabase.channel(`commerce-capabilities:${user.id}:${typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Math.random().toString(36).slice(2)}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'feature_flags' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'monetization_config' }, refresh)
      .subscribe()
    return () => { clearTimeout(timer); supabase.removeChannel(channel).catch(() => {}) }
  }, [user?.id, refreshCommerce])

  const value = useMemo(() => ({
    summary,
    loading,
    refreshCommerce,
    walletEnabled: true,
    topupsEnabled: !!summary?.config?.topups_enabled,
    shopEnabled: !!summary?.shop_enabled,
    plusEnabled: !!summary?.vybe_plus_enabled && !!summary?.config?.vybe_plus_enabled,
    adsEnabled: !!summary?.config?.ads_enabled,
  }), [summary, loading, refreshCommerce])

  return <CommerceContext.Provider value={value}>{children}</CommerceContext.Provider>
}

export function useCommerce() {
  const value = useContext(CommerceContext)
  if (!value) throw new Error('useCommerce must be used inside CommerceProvider')
  return value
}
