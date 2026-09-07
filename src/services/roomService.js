import { supabase } from '../lib/supabase'

function requireSupabase() {
  if (!supabase) throw new Error('Supabase is not configured')
}

export async function createRoomFromConversation(conversationId, title = null) {
  requireSupabase()
  const { data, error } = await supabase.rpc('create_room_from_conversation', {
    p_conversation_id: conversationId,
    p_title: title,
  })
  if (error) throw error
  return data
}

export async function getMyRooms(limit = 30) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_my_rooms', { p_limit: limit })
  if (error) throw error
  return data ?? []
}

export async function getRoomState(roomId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_room_state', { p_room: roomId })
  if (error) throw error
  return data
}

export async function joinRoom(roomId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('join_room', { p_room: roomId })
  if (error) throw error
  return data
}

export async function leaveRoom(roomId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('leave_room', { p_room: roomId })
  if (error) throw error
  return data
}

export async function startRoomGame(roomId, gameType) {
  requireSupabase()
  const { data, error } = await supabase.rpc('start_room_game', {
    p_room: roomId,
    p_game_type: gameType,
  })
  if (error) throw error
  return data
}

export async function submitGameAnswer(sessionId, roundId, answer) {
  requireSupabase()
  const { data, error } = await supabase.rpc('submit_game_answer', {
    p_session: sessionId,
    p_round: roundId,
    p_answer: answer,
  })
  if (error) throw error
  return data
}

export async function advanceRoomGame(sessionId) {
  requireSupabase()
  const { data, error } = await supabase.rpc('advance_room_game', { p_session: sessionId })
  if (error) throw error
  return data
}

export function subscribeToRoom(roomId, onChange) {
  requireSupabase()
  const tag = Math.random().toString(36).slice(2)
  const channel = supabase
    .channel(`vybe-room-${roomId}-${tag}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'rooms', filter: `id=eq.${roomId}` }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'room_members', filter: `room_id=eq.${roomId}` }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'game_sessions', filter: `room_id=eq.${roomId}` }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'room_events', filter: `room_id=eq.${roomId}` }, onChange)
    .subscribe()
  return () => supabase.removeChannel(channel)
}

export function subscribeToMyRooms(onChange) {
  requireSupabase()
  const channel = supabase
    .channel(`vybe-my-rooms-${Math.random().toString(36).slice(2)}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'rooms' }, onChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'room_members' }, onChange)
    .subscribe()
  return () => supabase.removeChannel(channel)
}

export async function getMyGameStats() {
  requireSupabase()
  const { data, error } = await supabase.rpc('get_my_game_stats')
  if (error) throw error
  return data || { vibe_xp: 0, vibe_level: 1, room_wins: 0, games_played: 0, verified_game_aura: 0 }
}
