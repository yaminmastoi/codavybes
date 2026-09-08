const ANDROID_CHANNEL_ID = 'codavybes-alerts'
let nativeLocalNotifications

function webNotificationsSupported() {
  return typeof window !== 'undefined' && 'Notification' in window && 'serviceWorker' in navigator
}

function nativePlatform() {
  if (typeof window === 'undefined') return false
  const capacitor = window.Capacitor
  if (!capacitor) return false
  if (typeof capacitor.isNativePlatform === 'function') return capacitor.isNativePlatform()
  const platform = typeof capacitor.getPlatform === 'function' ? capacitor.getPlatform() : ''
  return platform === 'android' || platform === 'ios'
}

function getNativeLocalNotifications() {
  if (!nativePlatform()) return null
  if (nativeLocalNotifications) return nativeLocalNotifications
  const capacitor = window.Capacitor
  if (typeof capacitor.isPluginAvailable === 'function' && !capacitor.isPluginAvailable('LocalNotifications')) return null
  nativeLocalNotifications = typeof capacitor.registerPlugin === 'function'
    ? capacitor.registerPlugin('LocalNotifications')
    : capacitor.Plugins?.LocalNotifications
  return nativeLocalNotifications || null
}

async function ensureNativeChannel(plugin) {
  if (!plugin || window.Capacitor?.getPlatform?.() !== 'android') return
  await plugin.createChannel({
    id: ANDROID_CHANNEL_ID,
    name: 'CodaVybes alerts',
    description: 'Chats, Aura, Rooms, Meet and account notifications',
    importance: 4,
    visibility: 1,
    vibration: true,
    lights: true,
    lightColor: '#FF7A1C',
  }).catch(() => null)
}

function notificationId(value) {
  const input = String(value || `${Date.now()}-${Math.random()}`)
  let hash = 0
  for (let index = 0; index < input.length; index += 1) hash = ((hash << 5) - hash + input.charCodeAt(index)) | 0
  return Math.max(1, Math.abs(hash % 2147483647))
}

export function systemNotificationsSupported() {
  return Boolean(getNativeLocalNotifications()) || webNotificationsSupported()
}

export async function registerVybeServiceWorker() {
  if (nativePlatform() || !webNotificationsSupported()) return null
  return navigator.serviceWorker.register('/codavybes-sw.js')
}

export async function checkSystemNotificationPermission() {
  const plugin = getNativeLocalNotifications()
  if (plugin) {
    const result = await plugin.checkPermissions().catch(() => ({ display: 'prompt' }))
    return result.display || 'prompt'
  }
  if (!webNotificationsSupported()) return 'unsupported'
  return Notification.permission
}

export async function requestSystemNotificationPermission() {
  const plugin = getNativeLocalNotifications()
  if (plugin) {
    let result = await plugin.checkPermissions()
    if (result.display !== 'granted') result = await plugin.requestPermissions()
    if (result.display === 'granted') await ensureNativeChannel(plugin)
    return result.display || 'denied'
  }
  if (!webNotificationsSupported()) return 'unsupported'
  await registerVybeServiceWorker().catch(() => null)
  return Notification.requestPermission()
}

export function getSystemNotificationPermission() {
  if (getNativeLocalNotifications()) return 'prompt'
  if (!webNotificationsSupported()) return 'unsupported'
  return Notification.permission
}

export async function showSystemNotification(notification) {
  const plugin = getNativeLocalNotifications()
  if (plugin) {
    const permission = await plugin.checkPermissions().catch(() => ({ display: 'denied' }))
    if (permission.display !== 'granted') return false
    await ensureNativeChannel(plugin)
    await plugin.schedule({
      notifications: [{
        id: notificationId(notification.id),
        title: notification.title || 'CodaVybes',
        body: notification.body || '',
        channelId: ANDROID_CHANNEL_ID,
        foreground: true,
        autoCancel: true,
        extra: { link: notification.link || '/notifications' },
      }],
    })
    return true
  }

  if (!webNotificationsSupported() || Notification.permission !== 'granted') return false
  const registration = await navigator.serviceWorker.ready.catch(() => null)
  if (!registration) return false
  await registration.showNotification(notification.title || 'CodaVybes', {
    body: notification.body || '',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    tag: notification.id ? `vybe:${notification.id}` : undefined,
    data: { link: notification.link || '/notifications' },
  })
  return true
}

export async function registerSystemNotificationActionListener(onOpen) {
  const plugin = getNativeLocalNotifications()
  if (!plugin) return () => {}
  const handle = await plugin.addListener('localNotificationActionPerformed', (event) => {
    const link = event?.notification?.extra?.link || '/notifications'
    onOpen(link)
  })
  return () => handle.remove()
}
