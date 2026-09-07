import { useCallback, useEffect, useState } from 'react'
import { Bell } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { getUnreadNotificationCount, subscribeNotifications } from '../services/notificationService'

export default function NotificationBell({ className = '' }) {
  const { user } = useAuth()
  const [count, setCount] = useState(0)
  const load = useCallback(() => getUnreadNotificationCount().then(setCount).catch(() => setCount(0)), [])
  useEffect(() => {
    if (!user?.id) return undefined
    load()
    return subscribeNotifications(user.id, load, 'bell')
  }, [user?.id, load])
  return <Link className={`icon-btn surface notification-bell ${className}`} to="/notifications" aria-label={`${count} unread notifications`}>
    <Bell size={19}/>{count > 0 && <span>{count > 99 ? '99+' : count}</span>}
  </Link>
}
