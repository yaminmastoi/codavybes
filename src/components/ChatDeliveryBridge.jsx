import { useEffect } from 'react'
import { useAuth } from '../context/AuthContext'
import { markMyMessagesDelivered, subscribeToIncomingMessages } from '../services/chatService'

export default function ChatDeliveryBridge() {
  const { user } = useAuth()

  useEffect(() => {
    if (!user?.id) return undefined

    let timer
    const markDelivered = () => {
      clearTimeout(timer)
      timer = setTimeout(() => markMyMessagesDelivered().catch(() => null), 80)
    }
    const handleVisibility = () => {
      if (document.visibilityState === 'visible') markDelivered()
    }

    markDelivered()
    window.addEventListener('focus', markDelivered)
    document.addEventListener('visibilitychange', handleVisibility)
    const stop = subscribeToIncomingMessages((payload) => {
      if (payload?.eventType === 'INSERT' && payload.new?.sender_id !== user.id) markDelivered()
    })

    return () => {
      clearTimeout(timer)
      stop()
      window.removeEventListener('focus', markDelivered)
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [user?.id])

  return null
}
