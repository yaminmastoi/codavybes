import { supabase } from '../lib/supabase'

export const TELEMETRY_CONSENT_KEY = 'codavybes-consent-v1'
export const LOCATION_SHARING_KEY = 'codavybes-location-share-v1'
const INSTALLATION_KEY = 'codavybes-installation-v1'
const SESSION_KEY = 'codavybes-session-v1'
const LOCATION_CACHE_MS = 15 * 60 * 1000

export const APP_PLATFORM = (() => {
  const configured = String(import.meta.env.VITE_APP_PLATFORM || '').toLowerCase()
  if (['web', 'android', 'windows'].includes(configured)) return configured
  if (typeof window !== 'undefined' && window.__TAURI_INTERNALS__) return 'windows'
  if (typeof window !== 'undefined' && window.Capacitor?.getPlatform?.() === 'android') return 'android'
  return 'web'
})()

export const APP_VERSION = String(import.meta.env.VITE_APP_VERSION || '13.4.0')

let locationCache = null
let edgeUnavailableUntil = 0

function uuid() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID()
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.random() * 16 | 0
    return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16)
  })
}

function safeStorage(storage, key, create = false) {
  try {
    const current = storage.getItem(key)
    if (current) return current
    if (create) {
      const next = uuid()
      storage.setItem(key, next)
      return next
    }
  } catch {}
  return create ? uuid() : null
}

export function getTelemetryConsent() {
  try {
    const raw = localStorage.getItem(TELEMETRY_CONSENT_KEY)
    if (!raw) return { essential: true, analytics: false }
    const parsed = JSON.parse(raw)
    return { essential: true, analytics: parsed?.analytics === true }
  } catch {
    return { essential: true, analytics: false }
  }
}

export function analyticsConsentEnabled() {
  return getTelemetryConsent().analytics
}

export function getLocationSharingEnabled() {
  try { return localStorage.getItem(LOCATION_SHARING_KEY) === 'true' } catch { return false }
}

export async function setPreciseLocationSharing(enabled) {
  if (!enabled) {
    try { localStorage.setItem(LOCATION_SHARING_KEY, 'false') } catch {}
    locationCache = null
    window.dispatchEvent(new CustomEvent('codavybes:location-sharing', { detail: false }))
    return { enabled: false }
  }
  if (!analyticsConsentEnabled()) throw new Error('Accept optional analytics before enabling precise location sharing.')
  if (!navigator.geolocation) throw new Error('Precise location is not supported on this device.')
  const point = await new Promise((resolve, reject) => navigator.geolocation.getCurrentPosition(
    ({ coords }) => resolve({ latitude: coords.latitude, longitude: coords.longitude, accuracy: coords.accuracy, at: Date.now() }),
    (error) => reject(new Error(error?.message || 'Location permission was not granted.')),
    { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 },
  ))
  locationCache = point
  try { localStorage.setItem(LOCATION_SHARING_KEY, 'true') } catch {}
  window.dispatchEvent(new CustomEvent('codavybes:location-sharing', { detail: true }))
  return { enabled: true, point }
}

function getSessionId() {
  return safeStorage(sessionStorage, SESSION_KEY, true)
}

function getInstallationId() {
  if (!analyticsConsentEnabled()) return null
  return safeStorage(localStorage, INSTALLATION_KEY, true)
}

function detectDevice() {
  const ua = navigator.userAgent || ''
  const mobile = /Android|iPhone|iPod|Mobile/i.test(ua)
  const tablet = /iPad|Tablet/i.test(ua)
  let os = 'Unknown'
  if (/Windows NT/i.test(ua)) os = 'Windows'
  else if (/Android/i.test(ua)) os = 'Android'
  else if (/iPhone|iPad|iPod/i.test(ua)) os = 'iOS/iPadOS'
  else if (/Mac OS X/i.test(ua)) os = 'macOS'
  else if (/Linux/i.test(ua)) os = 'Linux'
  let browser = 'WebView/Other'
  if (/Edg\//i.test(ua)) browser = 'Edge'
  else if (/Chrome\//i.test(ua) || /CriOS\//i.test(ua)) browser = 'Chrome'
  else if (/Firefox\//i.test(ua) || /FxiOS\//i.test(ua)) browser = 'Firefox'
  else if (/Safari\//i.test(ua)) browser = 'Safari'
  return { device_type: tablet ? 'tablet' : mobile ? 'mobile' : 'desktop', os_name: os, browser_name: browser }
}

function networkInfo() {
  const c = navigator.connection || navigator.mozConnection || navigator.webkitConnection
  if (!c) return {}
  return {
    network_type: typeof c.type === 'string' ? c.type : null,
    effective_type: typeof c.effectiveType === 'string' ? c.effectiveType : null,
    downlink_mbps: Number.isFinite(c.downlink) ? Number(c.downlink.toFixed(2)) : null,
    rtt_ms: Number.isFinite(c.rtt) ? Math.round(c.rtt) : null,
    save_data: typeof c.saveData === 'boolean' ? c.saveData : null,
  }
}

async function currentLocation() {
  if (!analyticsConsentEnabled() || !getLocationSharingEnabled() || !navigator.geolocation) return null
  if (locationCache && Date.now() - locationCache.at < LOCATION_CACHE_MS) return locationCache
  try {
    const point = await new Promise((resolve, reject) => navigator.geolocation.getCurrentPosition(
      ({ coords }) => resolve({ latitude: coords.latitude, longitude: coords.longitude, accuracy: coords.accuracy, at: Date.now() }),
      reject,
      { enableHighAccuracy: false, timeout: 8000, maximumAge: LOCATION_CACHE_MS },
    ))
    locationCache = point
    return point
  } catch {
    return null
  }
}

function sanitizeProperties(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return {}
  const blocked = /(password|secret|token|auth|email|message|body|content|text|phone|address|latitude|longitude|ip)/i
  const out = {}
  for (const [rawKey, rawValue] of Object.entries(input).slice(0, 30)) {
    const key = String(rawKey).replace(/[^A-Za-z0-9_]/g, '_').slice(0, 40)
    if (!key || blocked.test(key)) continue
    if (typeof rawValue === 'string') out[key] = rawValue.slice(0, 200)
    else if (typeof rawValue === 'number' && Number.isFinite(rawValue)) out[key] = rawValue
    else if (typeof rawValue === 'boolean' || rawValue === null) out[key] = rawValue
  }
  return out
}

function cleanErrorMessage(value) {
  return String(value || '')
    .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[email]')
    .replace(/eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}/g, '[token]')
    .replace(/([?&](?:token|key|secret|code|access_token|refresh_token)=)[^&\s]+/gi, '$1[redacted]')
    .slice(0, 500)
}

async function basePayload(route = '/', presenceStatus = 'active') {
  const consent = getTelemetryConsent()
  const loc = await currentLocation()
  return {
    session_id: getSessionId(),
    installation_id: consent.analytics ? getInstallationId() : null,
    platform: APP_PLATFORM,
    app_version: APP_VERSION,
    route: String(route || '/').slice(0, 220),
    presence_status: presenceStatus,
    ...detectDevice(),
    locale: navigator.language || null,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || null,
    viewport_width: Math.round(window.innerWidth || 0),
    viewport_height: Math.round(window.innerHeight || 0),
    ...networkInfo(),
    analytics_consent: consent.analytics,
    location_consent: Boolean(consent.analytics && getLocationSharingEnabled()),
    latitude: loc?.latitude ?? null,
    longitude: loc?.longitude ?? null,
    location_accuracy_m: loc?.accuracy ?? null,
  }
}

async function send(payload) {
  if (!supabase) return null
  if (Date.now() >= edgeUnavailableUntil) {
    try {
      const { data, error } = await supabase.functions.invoke('telemetry-ingest', { body: payload })
      if (!error && !data?.error) return data
      edgeUnavailableUntil = Date.now() + 5 * 60 * 1000
    } catch {
      edgeUnavailableUntil = Date.now() + 5 * 60 * 1000
    }
  }
  const { data, error } = await supabase.rpc('telemetry_ingest_client', { p_payload: payload })
  if (error) throw error
  return data
}

export async function heartbeatTelemetry({ route = '/', status = 'active', event = null, properties = null } = {}) {
  try {
    const payload = await basePayload(route, status)
    if (event && analyticsConsentEnabled()) {
      payload.event_name = String(event).toLowerCase().replace(/[^a-z0-9_]/g, '_').slice(0, 80)
      payload.properties = sanitizeProperties(properties)
    }
    return await send(payload)
  } catch (error) {
    if (import.meta.env.DEV) console.warn('[CodaVybes telemetry]', error?.message || error)
    return null
  }
}

export async function reportClientError({ route = '/', kind = 'client_error', message = '', source = null, line = null, column = null } = {}) {
  if (!analyticsConsentEnabled()) return null
  try {
    const payload = await basePayload(route, document.hidden ? 'hidden' : 'active')
    payload.error = {
      kind: String(kind || 'client_error').slice(0, 80),
      message: cleanErrorMessage(message),
      source: source ? String(source).split('?')[0].slice(0, 240) : null,
      line: Number.isFinite(Number(line)) ? Number(line) : null,
      column: Number.isFinite(Number(column)) ? Number(column) : null,
    }
    return await send(payload)
  } catch {
    return null
  }
}

export function telemetrySummary() {
  return {
    platform: APP_PLATFORM,
    version: APP_VERSION,
    analytics: analyticsConsentEnabled(),
    preciseLocation: getLocationSharingEnabled(),
  }
}
