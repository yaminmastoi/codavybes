import { supabase } from '../lib/supabase'

let cleanup = () => {}
let registeredForUser = ''

function capacitorNative() {
  const cap = typeof window !== 'undefined' ? window.Capacitor : null
  return Boolean(cap && (typeof cap.isNativePlatform !== 'function' || cap.isNativePlatform()))
}

async function plugin() {
  if (!capacitorNative() || window.Capacitor?.getPlatform?.() !== 'android') return null
  return import('@capacitor/push-notifications').then((mod) => mod.PushNotifications).catch(() => null)
}

export async function registerAndroidPush(userId, onOpen) {
  if (!userId || !supabase || registeredForUser === userId) return cleanup
  const PushNotifications = await plugin()
  if (!PushNotifications) return cleanup

  cleanup()
  const listeners = []
  const add = async (name, fn) => { const h = await PushNotifications.addListener(name, fn); listeners.push(h) }
  await add('registration', async ({ value }) => {
    if (!value) return
    const deviceId = localStorage.getItem('codavybes-device-id') || crypto.randomUUID?.() || `${Date.now()}-${Math.random()}`
    localStorage.setItem('codavybes-device-id', deviceId)
    const { error } = await supabase.rpc('register_my_push_token', { p_token: value, p_platform: 'android', p_device_id: deviceId })
    if (error) console.warn('[CodaVybes push] token save failed', error.message)
  })
  await add('registrationError', (error) => console.warn('[CodaVybes push] registration failed', error))
  await add('pushNotificationActionPerformed', (event) => {
    const link = event?.notification?.data?.link || '/notifications'
    onOpen?.(String(link))
  })
  // Foreground push is represented by the in-app Realtime event already, so do
  // not create a duplicate local notification here.
  await add('pushNotificationReceived', () => {})

  // FCM sends Android notifications on this channel while the app is in the
  // background/terminated state. Create it before registration so sound,
  // vibration and importance remain consistent across Android versions.
  await PushNotifications.createChannel({
    id: 'codavybes-alerts',
    name: 'CodaVybes Alerts',
    description: 'Messages, Meets, Moments, Rooms and account notifications',
    importance: 5,
    visibility: 1,
    vibration: true,
    lights: true,
    lightColor: '#FF7A1C',
  }).catch((error) => console.warn('[CodaVybes push] channel setup failed', error?.message || error))

  let permission = await PushNotifications.checkPermissions()
  if (permission.receive === 'prompt') permission = await PushNotifications.requestPermissions()
  if (permission.receive === 'granted') await PushNotifications.register()

  registeredForUser = userId
  cleanup = () => {
    for (const h of listeners) Promise.resolve(h.remove()).catch(() => {})
    registeredForUser = ''
  }
  return cleanup
}
