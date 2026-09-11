import { useEffect } from 'react'
import { useAuth } from '../context/AuthContext'
import { getPreferences } from '../services/settingsService'
import { registerSystemNotificationActionListener, registerVybeServiceWorker, showSystemNotification } from '../services/systemNotificationService'
import { subscribeAnnouncements, subscribeNotifications } from '../services/notificationService'
import { registerAndroidPush } from '../services/pushNotificationService'

export default function NotificationBridge() {
  const { user, refreshOnboarding } = useAuth()
  useEffect(() => {
    if (!user?.id) return undefined
    let enabled = false
    const updateEnabled = (event) => { enabled = !!event.detail }
    window.addEventListener('vybe:system-notifications', updateEnabled)
    let disposed = false
    registerVybeServiceWorker().catch(() => null)
    let stopPush = () => {}
    registerAndroidPush(user.id, (link) => {
      if (typeof link === 'string' && link.startsWith('/')) window.location.assign(link)
    }).then((stop) => { if (disposed) stop(); else stopPush = stop }).catch((error) => {
      console.warn('[CodaVybes push] native registration unavailable:', error?.message || error)
    })
    let stopNativeAction = () => {}
    registerSystemNotificationActionListener((link) => {
      if (typeof link === 'string' && link.startsWith('/')) window.location.assign(link)
    }).then((stop) => { if (disposed) stop(); else stopNativeAction = stop }).catch(() => {})
    getPreferences().then((p) => { enabled = !!p.system_notifications }).catch(() => {})
    const stopUser = subscribeNotifications(user.id, (payload) => {
      if (payload?.eventType !== 'INSERT' || !payload?.new) return
      if (payload.new.entity_type === 'verification' || typeof payload.new.metadata?.verified === 'boolean' || payload.new.metadata?.verification_waitlist_unlocked) {
        refreshOnboarding().catch(() => null)
        window.dispatchEvent(new CustomEvent('vybe:verification-changed', { detail: payload.new }))
      }
      if (enabled) showSystemNotification(payload.new).catch(() => {})
    }, 'system-bridge')
    const stopAnnouncements = subscribeAnnouncements((payload) => {
      if (!enabled || payload?.eventType !== 'INSERT' || !payload?.new) return
      showSystemNotification({ ...payload.new, link: payload.new.cta_url || '/notifications' }).catch(() => {})
    }, 'system-bridge')
    return () => { disposed = true; stopUser(); stopAnnouncements(); stopNativeAction(); stopPush(); window.removeEventListener('vybe:system-notifications', updateEnabled) }
  }, [user?.id, refreshOnboarding])
  return null
}
