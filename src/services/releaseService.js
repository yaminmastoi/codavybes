import { supabase } from '../lib/supabase'
import { APP_PLATFORM, APP_VERSION } from './telemetryService'

export async function getLatestAppRelease() {
  if (!supabase) return null
  const { data, error } = await supabase.rpc('get_app_update', { p_platform: APP_PLATFORM, p_current_version: APP_VERSION })
  if (error) throw error
  return data
}

export function openAppUpdate(release) {
  if (!release?.update_available) return
  if (APP_PLATFORM === 'web') {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then((regs) => Promise.all(regs.map((r) => r.update().catch(() => null)))).finally(() => window.location.reload())
    } else window.location.reload()
    return
  }
  if (release.download_url) window.open(release.download_url, '_blank', 'noopener,noreferrer')
}
