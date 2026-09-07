export function systemNotificationsSupported() {
  return typeof window !== 'undefined' && 'Notification' in window && 'serviceWorker' in navigator
}

export async function registerVybeServiceWorker() {
  if (!systemNotificationsSupported()) return null
  return navigator.serviceWorker.register('/vybe-sw.js')
}

export async function requestSystemNotificationPermission() {
  if (!systemNotificationsSupported()) return 'unsupported'
  await registerVybeServiceWorker().catch(() => null)
  return Notification.requestPermission()
}

export function getSystemNotificationPermission() {
  if (!systemNotificationsSupported()) return 'unsupported'
  return Notification.permission
}

export async function showSystemNotification(notification) {
  if (!systemNotificationsSupported() || Notification.permission !== 'granted') return false
  const registration = await navigator.serviceWorker.ready.catch(() => null)
  if (!registration) return false
  await registration.showNotification(notification.title || 'CodaVybes', {
    body: notification.body || '',
    icon: '/vybe-mark.svg',
    badge: '/vybe-mark.svg',
    tag: notification.id ? `vybe:${notification.id}` : undefined,
    data: { link: notification.link || '/notifications' },
  })
  return true
}
