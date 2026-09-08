import { useEffect } from 'react'
import { useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { notifyAnalyticsConsent, trackPageView, trackSessionHeartbeat } from '../services/analyticsService'

export default function AnalyticsBridge() {
  const location = useLocation()
  const { loading, user } = useAuth()

  useEffect(() => {
    notifyAnalyticsConsent()
  }, [])

  useEffect(() => {
    if (loading) return
    trackPageView(`${location.pathname}${location.search}`, {
      signed_in: Boolean(user),
      route: location.pathname,
    })
  }, [loading, location.pathname, location.search, user])

  useEffect(() => {
    if (loading) return undefined
    const trackCurrentPage = () => {
      trackPageView(`${location.pathname}${location.search}`, {
        signed_in: Boolean(user),
        route: location.pathname,
        consent_update: true,
      })
      if (user) trackSessionHeartbeat()
    }
    window.addEventListener('codavybes:consent-change', trackCurrentPage)
    return () => window.removeEventListener('codavybes:consent-change', trackCurrentPage)
  }, [loading, location.pathname, location.search, user])

  useEffect(() => {
    if (loading || !user) return undefined
    const pulse = () => trackSessionHeartbeat()
    pulse()
    const interval = window.setInterval(pulse, 60000)
    window.addEventListener('focus', pulse)
    window.addEventListener('visibilitychange', pulse)
    return () => {
      window.clearInterval(interval)
      window.removeEventListener('focus', pulse)
      window.removeEventListener('visibilitychange', pulse)
    }
  }, [loading, user])

  return null
}
