import { supabase } from '../lib/supabase'

export const CONSENT_KEY = 'codavybes-consent-v1'

let gaBooted = false
let lastHeartbeatAt = 0

function safeWindow() {
  return typeof window !== 'undefined' ? window : null
}

function getSessionId() {
  const win = safeWindow()
  if (!win) return ''
  try {
    const key = 'codavybes-analytics-session-v1'
    const current = win.sessionStorage.getItem(key)
    if (current) return current
    const generated = win.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`
    win.sessionStorage.setItem(key, generated)
    return generated
  } catch {
    return ''
  }
}

export function getAnalyticsConsent() {
  const win = safeWindow()
  if (!win) return { essential: true, analytics: false }
  try {
    return JSON.parse(win.localStorage.getItem(CONSENT_KEY) || '{"essential":true,"analytics":false}')
  } catch {
    return { essential: true, analytics: false }
  }
}

export function analyticsAllowed() {
  return getAnalyticsConsent()?.analytics === true
}

export function notifyAnalyticsConsent() {
  const win = safeWindow()
  if (!win) return
  win.dispatchEvent(new CustomEvent('codavybes:consent-change', { detail: getAnalyticsConsent() }))
}

function measurementId() {
  return String(import.meta.env.VITE_GA_MEASUREMENT_ID || import.meta.env.VITE_GOOGLE_ANALYTICS_ID || '').trim()
}

function platform() {
  const win = safeWindow()
  if (!win) return 'web'
  if (win.Capacitor?.isNativePlatform?.()) return 'android'
  if (win.__TAURI_INTERNALS__ || win.__TAURI__) return 'windows'
  return win.matchMedia?.('(display-mode: standalone)')?.matches ? 'pwa' : 'web'
}

function deviceType() {
  const win = safeWindow()
  if (!win) return 'unknown'
  const width = win.innerWidth || 0
  if (width && width < 768) return 'mobile'
  if (width && width < 1120) return 'tablet'
  return 'desktop'
}

function scrubMetadata(input = {}) {
  const blocked = /body|message|text|email|token|secret|password|phone|ip/i
  const out = {}
  for (const [key, value] of Object.entries(input || {})) {
    if (blocked.test(key)) continue
    if (value == null) continue
    if (['string', 'number', 'boolean'].includes(typeof value)) out[key] = String(value).slice(0, 180)
  }
  return out
}

function basePayload(eventName, metadata = {}) {
  const win = safeWindow()
  const doc = typeof document !== 'undefined' ? document : null
  const nav = typeof navigator !== 'undefined' ? navigator : null
  return {
    event_name: String(eventName || '').toLowerCase().replace(/[^a-z0-9_:.:-]/g, '_').slice(0, 80),
    session_id: getSessionId(),
    page_path: win ? `${win.location.pathname}${win.location.search}` : '/',
    referrer: doc?.referrer || '',
    platform: platform(),
    device_type: deviceType(),
    locale: nav?.language || '',
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || '',
    metadata: scrubMetadata(metadata),
    consent: { analytics: analyticsAllowed() },
  }
}

function bootGoogleAnalytics() {
  const win = safeWindow()
  const doc = typeof document !== 'undefined' ? document : null
  const id = measurementId()
  if (!win || !doc || !id || gaBooted || !analyticsAllowed()) return false

  win.dataLayer = win.dataLayer || []
  win.gtag = win.gtag || function gtag() { win.dataLayer.push(arguments) }
  win.gtag('js', new Date())
  win.gtag('config', id, { send_page_view: false, anonymize_ip: true })

  const script = doc.createElement('script')
  script.async = true
  script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(id)}`
  doc.head.appendChild(script)
  gaBooted = true
  return true
}

function trackGooglePageView(path) {
  const win = safeWindow()
  const id = measurementId()
  if (!win || !id || !analyticsAllowed()) return
  bootGoogleAnalytics()
  win.gtag?.('event', 'page_view', {
    page_path: path,
    page_location: `${win.location.origin}${path}`,
    page_title: document.title || 'CodaVybes',
  })
}

export async function trackEvent(eventName, metadata = {}) {
  if (!supabase || !analyticsAllowed()) return { ok: false, skipped: true }
  const payload = basePayload(eventName, metadata)
  if (!payload.event_name || payload.event_name.length < 2) return { ok: false, skipped: true }

  try {
    const { data, error } = await supabase.functions.invoke('track-analytics', { body: payload })
    if (!error && data?.ok !== false) return data || { ok: true }
  } catch {
    // Fallback below keeps analytics alive before the Edge Function is deployed.
  }

  const { data, error } = await supabase.rpc('track_analytics_event', {
    p_event: payload.event_name,
    p_session: payload.session_id || null,
    p_page: payload.page_path || '/',
    p_platform: payload.platform,
    p_device: payload.device_type,
    p_referrer: payload.referrer || null,
    p_locale: payload.locale || null,
    p_timezone: payload.timezone || null,
    p_metadata: payload.metadata || {},
  })
  if (error) return { ok: false, error: error.message }
  return data || { ok: true }
}

export function trackPageView(path, metadata = {}) {
  if (!analyticsAllowed()) return
  const pagePath = path || `${safeWindow()?.location.pathname || '/'}${safeWindow()?.location.search || ''}`
  trackGooglePageView(pagePath)
  void trackEvent('page_view', { ...metadata, path: pagePath })
}

export function trackSessionHeartbeat() {
  const now = Date.now()
  if (now - lastHeartbeatAt < 45000) return
  lastHeartbeatAt = now
  void trackEvent('session_heartbeat')
}
