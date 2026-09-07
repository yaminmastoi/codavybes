import { useEffect, useRef } from 'react'
import { useLocation } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { analyticsConsentEnabled, heartbeatTelemetry, reportClientError } from '../services/telemetryService'

const HEARTBEAT_MS = 25_000

export default function TelemetryBridge() {
  const { user } = useAuth()
  const location = useLocation()
  const routeRef = useRef(location.pathname)
  const firstRef = useRef(true)

  useEffect(() => { routeRef.current = location.pathname }, [location.pathname])

  useEffect(() => {
    if (!user?.id) return undefined
    heartbeatTelemetry({ route: location.pathname, event: firstRef.current ? 'app_open' : 'page_view', properties: { navigation: firstRef.current ? 'launch' : 'route' } })
    firstRef.current = false
  }, [user?.id, location.pathname])

  useEffect(() => {
    if (!user?.id) return undefined
    const pulse = () => heartbeatTelemetry({ route: routeRef.current, status: document.hidden ? 'hidden' : navigator.onLine ? 'active' : 'offline' })
    const onVisibility = () => pulse()
    const onNetwork = () => pulse()
    const onConsent = () => pulse()
    const timer = window.setInterval(pulse, HEARTBEAT_MS)
    document.addEventListener('visibilitychange', onVisibility)
    window.addEventListener('online', onNetwork)
    window.addEventListener('offline', onNetwork)
    window.addEventListener('codavybes:privacy-consent', onConsent)
    window.addEventListener('codavybes:location-sharing', onConsent)
    pulse()
    return () => {
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', onVisibility)
      window.removeEventListener('online', onNetwork)
      window.removeEventListener('offline', onNetwork)
      window.removeEventListener('codavybes:privacy-consent', onConsent)
      window.removeEventListener('codavybes:location-sharing', onConsent)
    }
  }, [user?.id])

  useEffect(() => {
    if (!user?.id) return undefined
    const onError = (event) => {
      if (!analyticsConsentEnabled()) return
      reportClientError({ route: routeRef.current, kind: 'window_error', message: event.message, source: event.filename, line: event.lineno, column: event.colno })
    }
    const onRejection = (event) => {
      if (!analyticsConsentEnabled()) return
      const reason = event.reason
      reportClientError({ route: routeRef.current, kind: 'unhandled_rejection', message: reason?.message || String(reason || 'Unhandled promise rejection') })
    }
    window.addEventListener('error', onError)
    window.addEventListener('unhandledrejection', onRejection)
    return () => {
      window.removeEventListener('error', onError)
      window.removeEventListener('unhandledrejection', onRejection)
    }
  }, [user?.id])

  return null
}
