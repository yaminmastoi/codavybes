import { supabase } from '../lib/supabase'
import { beginAuthenticatedSecondFactor } from './secondFactorService'

const CAPACITOR_SCHEME = 'app.codavybes.social:'
const TAURI_SCHEME = 'app.codavybes.desktop:'
const LEGACY_CAPACITOR_SCHEME = 'app.vybe.social:'
const LEGACY_TAURI_SCHEME = 'app.vybe.desktop:'
const activeCallbacks = new Map()
const completedCallbacks = new Map()

function capacitorRuntime() {
  if (typeof window === 'undefined') return null
  const capacitor = window.Capacitor
  if (!capacitor) return null
  const native = typeof capacitor.isNativePlatform === 'function'
    ? capacitor.isNativePlatform()
    : ['android', 'ios'].includes(capacitor.getPlatform?.())
  return native ? capacitor : null
}

function tauriRuntime() {
  if (typeof window === 'undefined') return null
  return window.__TAURI__ || null
}

function capacitorPlugin(name) {
  const capacitor = capacitorRuntime()
  if (!capacitor) return null
  if (typeof capacitor.isPluginAvailable === 'function' && !capacitor.isPluginAvailable(name)) return null
  return typeof capacitor.registerPlugin === 'function'
    ? capacitor.registerPlugin(name)
    : capacitor.Plugins?.[name] || null
}

export function nativeAuthPlatform() {
  if (capacitorRuntime()) return 'capacitor'
  if (tauriRuntime()) return 'tauri'
  return null
}

export function authRedirectUrl(destination = 'callback') {
  const cleanDestination = String(destination || 'callback').replace(/^\/+/, '')
  if (capacitorRuntime()) return `app.codavybes.social://auth/${cleanDestination}`
  if (tauriRuntime()) return `app.codavybes.desktop://auth/${cleanDestination}`
  return `${window.location.origin}/auth/${cleanDestination}`
}

function parsedCallback(rawUrl) {
  const url = new URL(rawUrl)
  const nativeScheme = [CAPACITOR_SCHEME, TAURI_SCHEME, LEGACY_CAPACITOR_SCHEME, LEGACY_TAURI_SCHEME].includes(url.protocol)
  const webCallback = url.origin === window.location.origin && url.pathname.startsWith('/auth/')
  if (!nativeScheme && !webCallback) return null
  if (nativeScheme && url.hostname !== 'auth') return null
  return url
}

function callbackDestination(url) {
  return url.pathname.endsWith('/reset-password') ? '/reset-password' : '/'
}

async function closeCapacitorBrowser() {
  const browser = capacitorPlugin('Browser')
  if (browser) await browser.close().catch(() => null)
}

export async function completeAuthCallback(rawUrl) {
  if (!supabase) throw new Error('Supabase is not configured.')
  const url = parsedCallback(rawUrl)
  if (!url) return null

  const oauthError = url.searchParams.get('error_description') || url.searchParams.get('error')
  if (oauthError) throw new Error(oauthError)

  const code = url.searchParams.get('code')
  const hash = new URLSearchParams(url.hash.replace(/^#/, ''))
  const accessToken = hash.get('access_token')
  const refreshToken = hash.get('refresh_token')
  const callbackKey = code || accessToken || rawUrl

  if (completedCallbacks.has(callbackKey)) return completedCallbacks.get(callbackKey)
  if (activeCallbacks.has(callbackKey)) return activeCallbacks.get(callbackKey)

  const task = (async () => {
    if (code) {
      const { error } = await supabase.auth.exchangeCodeForSession(code)
      if (error) throw error
    } else if (accessToken && refreshToken) {
      const { error } = await supabase.auth.setSession({ access_token: accessToken, refresh_token: refreshToken })
      if (error) throw error
    } else {
      const { data, error } = await supabase.auth.getSession()
      if (error) throw error
      if (!data.session) throw new Error('The authentication callback did not contain a valid session.')
    }

    const destination = callbackDestination(url)
    // Google/X are the first factor. For normal sign-in callbacks, send the
    // CodaVybes 4-digit email challenge and remove this temporary local OAuth
    // session. Recovery callbacks intentionally bypass this path.
    if (destination === '/') {
      await beginAuthenticatedSecondFactor({ purpose: 'oauth' })
    }

    await closeCapacitorBrowser()
    completedCallbacks.set(callbackKey, destination)
    return destination
  })()

  activeCallbacks.set(callbackKey, task)
  try { return await task }
  finally { activeCallbacks.delete(callbackKey) }
}

function enterApp(path) {
  window.history.replaceState({}, '', path || '/')
  window.dispatchEvent(new PopStateEvent('popstate'))
  window.dispatchEvent(new CustomEvent('codavybes:auth-complete'))
}

async function consumeNativeCallback(url) {
  try {
    const destination = await completeAuthCallback(url)
    if (destination) enterApp(destination)
  } catch (error) {
    console.error('CodaVybes auth callback:', error)
    window.dispatchEvent(new CustomEvent('codavybes:auth-error', { detail: error.message }))
  }
}

export async function openOAuthUrl(url) {
  if (!url) throw new Error('The sign-in provider did not return an authorization URL.')

  if (capacitorRuntime()) {
    const browser = capacitorPlugin('Browser')
    if (!browser) throw new Error('Native browser plugin is unavailable. Run Capacitor sync and rebuild the app.')
    await browser.open({ url, presentationStyle: 'popover' })
    return
  }

  const tauri = tauriRuntime()
  if (tauri) {
    if (!tauri.opener?.openUrl) throw new Error('Desktop OAuth support is unavailable. Reinstall the latest Windows build.')
    await tauri.opener.openUrl(url)
    return
  }

  window.location.assign(url)
}

export async function initializeAuthPlatformBridge() {
  const cleanups = []

  if (capacitorRuntime()) {
    const app = capacitorPlugin('App')
    if (!app) return () => {}

    const urlHandle = await app.addListener('appUrlOpen', ({ url }) => consumeNativeCallback(url))
    cleanups.push(() => urlHandle.remove())

    const stateHandle = await app.addListener('appStateChange', ({ isActive }) => {
      if (!supabase || !isActive) return
      supabase.auth.startAutoRefresh()
      // Android may suspend JS timers while backgrounded. Refresh immediately on
      // resume so a short project JWT lifetime never appears as a logout.
      supabase.auth.getSession()
        .then(({ data }) => data.session ? supabase.auth.refreshSession() : null)
        .catch(() => null)
    })
    cleanups.push(() => stateHandle.remove())

    const launch = await app.getLaunchUrl().catch(() => null)
    if (launch?.url) await consumeNativeCallback(launch.url)
  } else {
    const tauri = tauriRuntime()
    if (tauri?.deepLink) {
      const unlisten = await tauri.deepLink.onOpenUrl((urls) => urls.forEach(consumeNativeCallback))
      cleanups.push(() => unlisten())
      const current = await tauri.deepLink.getCurrent().catch(() => null)
      if (current) current.forEach(consumeNativeCallback)
    }
  }

  if (typeof window !== 'undefined' && supabase) {
    let refreshing = false
    const recover = async () => {
      if (refreshing || (typeof document !== 'undefined' && document.visibilityState === 'hidden')) return
      refreshing = true
      try {
        const { data } = await supabase.auth.getSession()
        if (data.session) await supabase.auth.refreshSession()
      } catch {}
      finally { refreshing = false }
    }
    const onVisibility = () => { if (document.visibilityState === 'visible') void recover() }
    window.addEventListener('focus', recover)
    window.addEventListener('online', recover)
    document.addEventListener('visibilitychange', onVisibility)
    cleanups.push(() => {
      window.removeEventListener('focus', recover)
      window.removeEventListener('online', recover)
      document.removeEventListener('visibilitychange', onVisibility)
    })
  }

  return () => cleanups.forEach((cleanup) => cleanup())
}
