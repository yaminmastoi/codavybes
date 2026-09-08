import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || import.meta.env.VITE_SUPABASE_ANON_KEY

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseKey)

const memoryFallback = new Map()

// Keep Supabase's default storage key, but make the backing store explicit so
// web, Capacitor WebView and Tauri WebView all restore the same refresh token
// after their process is closed and opened again.
const persistentStorage = {
  getItem(key) {
    try { return window.localStorage.getItem(key) }
    catch { return memoryFallback.get(key) ?? null }
  },
  setItem(key, value) {
    try { window.localStorage.setItem(key, value) }
    catch { memoryFallback.set(key, value) }
  },
  removeItem(key) {
    try { window.localStorage.removeItem(key) }
    catch { memoryFallback.delete(key) }
  },
}

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: false,
        flowType: 'pkce',
        storage: persistentStorage,
      },
    })
  : null
