import { supabase } from '../lib/supabase'

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

function realtimeTopic(prefix, scope = '') {
  const random = typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2)}`
  return `${prefix}:${scope}:${random}`
}

export async function getNotifications(limit = 60, offset = 0) {
  const { data, error } = await client().rpc('get_my_notifications', { p_limit: limit, p_offset: offset })
  if (error) throw error
  return data ?? []
}

export async function getUnreadNotificationCount() {
  const { data, error } = await client().rpc('get_my_unread_notification_count')
  if (error) throw error
  return Number(data ?? 0)
}

export async function markNotificationRead(id) {
  const { error } = await client().rpc('mark_notification_read', { p_notification: id })
  if (error) throw error
}

export async function markAllNotificationsRead() {
  const { data, error } = await client().rpc('mark_all_notifications_read')
  if (error) throw error
  return Number(data ?? 0)
}

export async function getAnnouncements() {
  const { data, error } = await client()
    .from('announcements')
    .select('id,title,body,cta_label,cta_url,created_at')
    .order('created_at', { ascending: false })
    .limit(20)
  if (error) throw error
  return data ?? []
}

/**
 * Every consumer gets its own channel topic. Supabase Realtime channels cannot
 * accept new postgres_changes bindings after subscribe(), so reusing a topic
 * between NotificationBell and NotificationBridge can crash in React StrictMode.
 */
export function subscribeNotifications(userId, onChange, consumer = 'listener') {
  if (!supabase || !userId || typeof onChange !== 'function') return () => {}

  let channel = null
  try {
    channel = supabase
      .channel(realtimeTopic(`notifications-${consumer}`, userId))
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'user_notifications',
          filter: `user_id=eq.${userId}`,
        },
        onChange,
      )

    // Supabase requires every binding to be registered before subscribe().
    channel.subscribe((status) => {
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.warn(`[CodaVybes realtime] notifications (${consumer}) status:`, status)
      }
    })
  } catch (error) {
    console.error('[CodaVybes realtime] notification subscription failed:', error)
    if (channel) supabase.removeChannel(channel).catch(() => {})
    return () => {}
  }

  let stopped = false
  return () => {
    if (stopped) return
    stopped = true
    if (channel) supabase.removeChannel(channel).catch(() => {})
  }
}

export function subscribeAnnouncements(onChange, consumer = 'listener') {
  if (!supabase || typeof onChange !== 'function') return () => {}

  let channel = null
  try {
    channel = supabase
      .channel(realtimeTopic(`announcements-${consumer}`, 'live'))
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'announcements' },
        onChange,
      )

    channel.subscribe((status) => {
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.warn(`[CodaVybes realtime] announcements (${consumer}) status:`, status)
      }
    })
  } catch (error) {
    console.error('[CodaVybes realtime] announcement subscription failed:', error)
    if (channel) supabase.removeChannel(channel).catch(() => {})
    return () => {}
  }

  let stopped = false
  return () => {
    if (stopped) return
    stopped = true
    if (channel) supabase.removeChannel(channel).catch(() => {})
  }
}
