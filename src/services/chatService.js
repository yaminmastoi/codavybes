import { supabase } from '../lib/supabase'
import { enrichVerified, getVerificationMap } from './verificationService'

function requireSupabase() {
  if (!supabase) throw new Error('Supabase is not configured')
}

export async function getConversations(limit = 50) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_conversations', { p_limit: limit })
  if (error) throw error
  const rows = data ?? []
  const ids = rows.flatMap((row) => Array.isArray(row.members) ? row.members.map((m) => m.user_id) : [])
  const map = await getVerificationMap(ids)
  return rows.map((row) => ({
    ...row,
    members: Array.isArray(row.members) ? row.members.map((m) => ({ ...m, is_verified: map.get(m.user_id) || false })) : [],
  }))
}

export async function getChatHeader(conversationId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_chat_header', { p_conversation_id: conversationId })
  if (error) throw error
  if (!data?.members?.length) return data
  const map = await getVerificationMap(data.members.map((m) => m.user_id))
  return { ...data, members: data.members.map((m) => ({ ...m, is_verified: map.get(m.user_id) || false })) }
}

export async function getMessages(conversationId, limit = 60, before = null) {
  requireSupabase()
  const [messagesResult, receiptsResult] = await Promise.all([
    supabase.rpc('get_messages', {
      p_conversation_id: conversationId,
      p_limit: limit,
      p_before: before,
    }),
    supabase.rpc('get_message_receipts', {
      p_conversation_id: conversationId,
      p_limit: limit,
      p_before: before,
    }),
  ])
  if (messagesResult.error) throw messagesResult.error
  if (receiptsResult.error) throw receiptsResult.error
  const receipts = new Map((receiptsResult.data ?? []).map((row) => [row.message_id, row]))
  const rows = (messagesResult.data ?? []).reverse().map((row) => ({
    ...row,
    delivered_at: receipts.get(row.message_id)?.delivered_at ?? null,
    viewed_at: receipts.get(row.message_id)?.viewed_at ?? null,
  }))
  return enrichVerified(rows, 'sender_id', 'sender_verified')
}

export async function sendMessage(conversationId, body, replyTo = null) {
  requireSupabase()
  const { data, error } = await supabase.rpc('send_message', {
    p_conversation_id: conversationId,
    p_body: body,
    p_reply_to: replyTo,
  })
  if (error) throw error
  return data
}

export async function searchChatPeople(query, limit = 20) {
  requireSupabase()
  const { data, error } = await supabase.rpc('search_chat_people', {
    p_query: query,
    p_limit: limit,
  })
  if (error) throw error
  return enrichVerified(data ?? [], 'user_id', 'is_verified')
}

export async function createDirectChat(targetUserId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('create_direct_chat', { p_target_user: targetUserId })
  if (error) throw error
  return data
}

export async function createGroupChat(title, memberIds) {
  requireSupabase()
  const { data, error } = await supabase.rpc('create_group_chat', {
    p_title: title,
    p_member_ids: memberIds,
  })
  if (error) throw error
  return data
}

export async function toggleMessageReaction(messageId, emoji) {
  requireSupabase()
  const { data, error } = await supabase.rpc('toggle_message_reaction', {
    p_message_id: messageId,
    p_emoji: emoji,
  })
  if (error) throw error
  return data
}

export async function giveMessageAura(messageId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('give_message_aura', { p_message_id: messageId })
  if (error) throw error
  return data
}

export async function markConversationRead(conversationId) {
  requireSupabase()
  const { error } = await supabase.rpc('mark_conversation_read', { p_conversation_id: conversationId })
  if (error) throw error
}

export async function clearConversation(conversationId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('clear_conversation', { p_conversation_id: conversationId })
  if (error) throw error
  return data
}

export async function deleteMessage(messageId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('delete_message', { p_message_id: messageId })
  if (error) throw error
  return data
}

export async function markMyMessagesDelivered() {
  requireSupabase()
  const { data, error } = await supabase.rpc('mark_my_messages_delivered')
  if (error) throw error
  return data
}

export async function blockUser(targetUserId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('block_user', { p_target_user: targetUserId })
  if (error) throw error
  return data
}

export async function unblockUser(targetUserId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('unblock_user', { p_target_user: targetUserId })
  if (error) throw error
  return data
}

export async function reportMessage(messageId, reason = 'harassment', details = '') {
  requireSupabase()
  const { data, error } = await supabase.rpc('report_message', {
    p_message_id: messageId,
    p_reason: reason,
    p_details: details,
  })
  if (error) throw error
  return data
}


export function subscribeToMyChats(onChange) {
  requireSupabase()
  const channel = supabase
    .channel(`vybe-chat-list-${Math.random().toString(36).slice(2)}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, onChange)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'messages' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'conversation_members' }, onChange)
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}

export function subscribeToConversation(conversationId, onChange) {
  requireSupabase()
  const channel = supabase
    .channel(`vybe-chat-${conversationId}-${Math.random().toString(36).slice(2)}`)
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'messages', filter: `conversation_id=eq.${conversationId}` },
      onChange,
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'message_reactions', filter: `conversation_id=eq.${conversationId}` },
      onChange,
    )
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}

export function subscribeToIncomingMessages(onChange) {
  requireSupabase()
  const channel = supabase
    .channel(`vybe-chat-delivery-${Math.random().toString(36).slice(2)}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'messages' }, onChange)
    .subscribe()

  return () => {
    supabase.removeChannel(channel)
  }
}

export function createTypingChannel(conversationId, currentUser, onTyping) {
  requireSupabase()
  const channel = supabase
    .channel(`chat-typing:${conversationId}`, { config: { broadcast: { self: false } } })
    .on('broadcast', { event: 'typing' }, ({ payload }) => {
      if (!payload || payload.user_id === currentUser?.id) return
      onTyping(payload)
    })
    .subscribe()

  return {
    send(isTyping) {
      return channel.send({
        type: 'broadcast',
        event: 'typing',
        payload: {
          user_id: currentUser?.id,
          display_name: currentUser?.user_metadata?.display_name || currentUser?.user_metadata?.username || 'Someone',
          is_typing: Boolean(isTyping),
          sent_at: Date.now(),
        },
      })
    },
    close() {
      supabase.removeChannel(channel)
    },
  }
}
