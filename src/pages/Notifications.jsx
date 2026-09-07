import { useCallback, useEffect, useMemo, useState } from 'react'
import { ArrowLeft, Bell, CheckCheck, Coins, Crown, Gamepad2, Heart, MessageCircle, Share2, Sparkles, UserPlus, Zap } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { getAnnouncements, getNotifications, markAllNotificationsRead, markNotificationRead } from '../services/notificationService'
import { PageSkeleton } from '../components/Loaders'

const ICONS = {
  aura: Zap, chat: MessageCircle, room: Gamepad2, meet: UserPlus, bond: Sparkles,
  shop: Coins, plus: Crown, system: Bell, reaction: Heart, comment: MessageCircle, share: Share2,
}

function timeAgo(value) {
  const diff = Date.now() - new Date(value).getTime()
  const min = Math.max(1, Math.floor(diff / 60000))
  if (min < 60) return `${min}m`
  const hr = Math.floor(min / 60)
  if (hr < 24) return `${hr}h`
  return `${Math.floor(hr / 24)}d`
}

export default function Notifications() {
  const navigate = useNavigate()
  const [rows, setRows] = useState([])
  const [announcements, setAnnouncements] = useState([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try {
      const [n, a] = await Promise.all([getNotifications(), getAnnouncements()])
      setRows(n); setAnnouncements(a)
    } catch (error) { setNotice(error.message) }
    finally { setLoading(false) }
  }, [])
  useEffect(() => { load() }, [load])

  const unread = useMemo(() => rows.filter((x) => !x.read_at).length, [rows])
  const open = async (row) => {
    if (!row.read_at) {
      await markNotificationRead(row.id).catch(() => {})
      setRows((current) => current.map((x) => x.id === row.id ? { ...x, read_at: new Date().toISOString() } : x))
    }
    if (row.link) navigate(row.link)
  }
  const markAll = async () => {
    await markAllNotificationsRead()
    setRows((current) => current.map((x) => ({ ...x, read_at: x.read_at || new Date().toISOString() })))
  }

  return <div className="page notifications-page">
    <header className="page-head page-head--back">
      <button className="icon-btn surface" onClick={() => navigate(-1)}><ArrowLeft size={20}/></button>
      <div><p className="eyebrow">ACTIVITY</p><h1>Notifications</h1></div>
      <button className="icon-btn surface" onClick={markAll} disabled={!unread} title="Mark all read"><CheckCheck size={20}/></button>
    </header>

    {!!announcements.length && <section className="announcement-strip">{announcements.slice(0, 3).map((a) => <article className="announcement-card surface" key={a.id}><span>CodaVybes HQ</span><strong>{a.title}</strong><p>{a.body}</p></article>)}</section>}
    {notice && <div className="notice">{notice}</div>}
    {loading ? <PageSkeleton variant="compact" count={4}/> : <section className="notification-list">
      {rows.map((row) => {
        const Icon = ICONS[row.type] || Bell
        return <button className={`notification-row surface ${row.read_at ? '' : 'is-unread'}`} key={row.id} onClick={() => open(row)}>
          <span className={`notification-icon type-${row.type}`}><Icon size={18}/></span>
          <span className="notification-copy"><strong>{row.title}</strong><span>{row.body}</span><small>{timeAgo(row.created_at)} ago</small></span>
          {!row.read_at && <i/>}
        </button>
      })}
      {!rows.length && <div className="feed-empty surface"><Bell size={28}/><h3>Quiet right now.</h3><p className="muted">Aura, reactions, replies, shares, messages, Meets and Room activity will show up here.</p></div>}
    </section>}
  </div>
}
