import { supabase } from '../lib/supabase'

const CAPACITOR_SCHEME = 'app.vybe.social:'
const TAURI_SCHEME = 'app.vybe.desktop:'
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
  if (capacitorRuntime()) return `app.vybe.social://auth/${cleanDestination}`
  if (tauriRuntime()) return `app.vybe.desktop://auth/${cleanDestination}`
  return `${window.location.origin}/auth/${cleanDestination}`
}

function parsedCallback(rawUrl) {
  const url = new URL(rawUrl)
  const nativeScheme = url.protocol === CAPACITOR_SCHEME || url.protocol === TAURI_SCHEME
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

    await closeCapacitorBrowser()
    const destination = callbackDestination(url)
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
  if (!url) throw new Error('Google did not return an authorization URL.')

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
      if (!supabase) return
      if (isActive) {
        supabase.auth.startAutoRefresh()
        supabase.auth.getSession().then(({ data }) => {
          if (data.session?.expires_at && data.session.expires_at * 1000 < Date.now() + 60000) {
            supabase.auth.refreshSession().catch(() => null)
          }
        })
      } else {
        supabase.auth.stopAutoRefresh()
      }
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

  return () => cleanups.forEach((cleanup) => cleanup())
}
