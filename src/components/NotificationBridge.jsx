import { useEffect } from 'react'
import { useAuth } from '../context/AuthContext'
import { getPreferences } from '../services/settingsService'
import { registerVybeServiceWorker, showSystemNotification } from '../services/systemNotificationService'
import { subscribeAnnouncements, subscribeNotifications } from '../services/notificationService'

export default function NotificationBridge() {
  const { user, refreshOnboarding } = useAuth()
  useEffect(() => {
    if (!user?.id) return undefined
    let enabled = false
    const updateEnabled = (event) => { enabled = !!event.detail }
    window.addEventListener('vybe:system-notifications', updateEnabled)
    registerVybeServiceWorker().catch(() => null)
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
    return () => { stopUser(); stopAnnouncements(); window.removeEventListener('vybe:system-notifications', updateEnabled) }
  }, [user?.id, refreshOnboarding])
  return null
}
