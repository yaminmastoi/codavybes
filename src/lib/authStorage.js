import { Preferences } from '@capacitor/preferences'
import { load as loadTauriStore } from '@tauri-apps/plugin-store'

const memoryFallback = new Map()
let tauriStorePromise = null

function localGet(key) {
  try { return window.localStorage.getItem(key) }
  catch { return memoryFallback.get(key) ?? null }
}

function localSet(key, value) {
  try { window.localStorage.setItem(key, value) }
  catch { memoryFallback.set(key, value) }
}

function localRemove(key) {
  try { window.localStorage.removeItem(key) }
  catch { memoryFallback.delete(key) }
}

function isCapacitorNative() {
  if (typeof window === 'undefined') return false
  const capacitor = window.Capacitor
  if (!capacitor) return false
  return typeof capacitor.isNativePlatform === 'function'
    ? capacitor.isNativePlatform()
    : ['android', 'ios'].includes(capacitor.getPlatform?.())
}

function isTauriDesktop() {
  if (typeof window === 'undefined') return false
  return Boolean(window.__TAURI__ || window.__TAURI_INTERNALS__)
}

async function tauriStore() {
  if (!tauriStorePromise) tauriStorePromise = loadTauriStore('codavybes-auth.json')
  return tauriStorePromise
}

/**
 * Supabase accepts async custom storage. Web keeps normal localStorage while
 * Capacitor/Tauri mirror auth state into native app-owned persistent storage.
 * This prevents short JWT expiries from looking like a logout after a native
 * WebView is suspended/recreated.
 */
export const authStorage = {
  async getItem(key) {
    const local = localGet(key)
    try {
      if (isCapacitorNative()) {
        const { value } = await Preferences.get({ key })
        if (value != null) {
          if (local !== value) localSet(key, value)
          return value
        }
        if (local != null) await Preferences.set({ key, value: local })
      } else if (isTauriDesktop()) {
        const store = await tauriStore()
        const value = await store.get(key)
        if (typeof value === 'string') {
          if (local !== value) localSet(key, value)
          return value
        }
        if (local != null) { await store.set(key, local); await store.save() }
      }
    } catch (error) {
      console.warn('CodaVybes native auth storage read failed:', error)
    }
    return local
  },

  async setItem(key, value) {
    localSet(key, value)
    try {
      if (isCapacitorNative()) {
        await Preferences.set({ key, value })
      } else if (isTauriDesktop()) {
        const store = await tauriStore()
        await store.set(key, value)
        await store.save()
      }
    } catch (error) {
      console.warn('CodaVybes native auth storage write failed:', error)
    }
  },

  async removeItem(key) {
    localRemove(key)
    try {
      if (isCapacitorNative()) {
        await Preferences.remove({ key })
      } else if (isTauriDesktop()) {
        const store = await tauriStore()
        await store.delete(key)
        await store.save()
      }
    } catch (error) {
      console.warn('CodaVybes native auth storage cleanup failed:', error)
    }
  },
}
