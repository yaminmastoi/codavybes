import { useCallback, useEffect, useMemo, useState } from 'react'
import { MessageCirclePlus, Search, Users } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Avatar from '../components/Avatar'
import AuraPill from '../components/AuraPill'
import NewChatSheet from '../components/NewChatSheet'
import { useAuth } from '../context/AuthContext'
import { getConversations, subscribeToMyChats } from '../services/chatService'
import { PageSkeleton } from '../components/Loaders'
import VerifiedBadge from '../components/VerifiedBadge'

function initials(name = 'V') {
  return name.trim().split(/\s+/).slice(0,2).map((part) => part[0]?.toUpperCase()).join('') || 'V'
}

function ageLabel(value) {
  if (!value) return ''
  const date = new Date(value)
  const diff = Date.now() - date.getTime()
  if (diff < 60_000) return 'now'
  if (diff < 3_600_000) return `${Math.max(1,Math.floor(diff/60_000))}m`
  if (diff < 86_400_000) return `${Math.floor(diff/3_600_000)}h`
  return new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric'}).format(date)
}

export default function Chats() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [query, setQuery] = useState('')
  const [showCreate, setShowCreate] = useState(false)

  const load = useCallback(async () => {
    setLoading(true); setError('')
    try { setItems(await getConversations(80)) }
    catch (e) { setError(e.message || 'Could not load chats.') }
    finally { setLoading(false) }
  }, [])

  useEffect(() => { load() }, [load])
  useEffect(() => {
    let timer
    return subscribeToMyChats(() => { clearTimeout(timer); timer = setTimeout(load, 140) })
  }, [load])

  const rows = useMemo(() => items.map((chat) => {
    const members = Array.isArray(chat.members) ? chat.members : []
    const others = members.filter((m) => m.user_id !== user?.id)
    const primary = others[0]
    const name = chat.conversation_type === 'group' ? chat.title : (primary?.display_name || primary?.username || 'CodaVybes user')
    return { ...chat, members, others, primary, name }
  }).filter((chat) => {
    const q = query.trim().toLowerCase()
    if (!q) return true
    return chat.name?.toLowerCase().includes(q) || chat.others.some((m) => m.username?.toLowerCase().includes(q))
  }), [items,query,user?.id])

  function created(id) {
    setShowCreate(false)
    navigate(`/chats/${id}`)
  }

  return <div className="page chats-page">
    <header className="page-head"><div><p className="eyebrow">MESSAGES</p><h1>Chats</h1></div><button className="icon-btn surface" onClick={() => setShowCreate(true)} aria-label="New chat"><MessageCirclePlus size={20}/></button></header>

    <div className="chat-search surface"><Search size={17}/><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search your people"/></div>

    {error && <div className="notice error-box">{error}</div>}
    {loading ? <PageSkeleton variant="compact" count={5}/> : rows.length ? <div className="chat-list surface">
      {rows.map((chat) => <button className="chat-row chat-row--real" key={chat.conversation_id} onClick={() => navigate(`/chats/${chat.conversation_id}`)}>
        <div className="chat-avatar-wrap"><Avatar initials={chat.conversation_type === 'group' ? initials(chat.title) : initials(chat.name)}/>{chat.conversation_type === 'group' && <span className="group-mini"><Users size={10}/></span>}</div>
        <div className="chat-copy"><div className="row gap-8 identity-line"><strong>{chat.name}</strong>{chat.conversation_type === 'direct' && <VerifiedBadge verified={chat.primary?.is_verified} size={15}/>} {chat.conversation_type === 'direct' && chat.primary?.aura_total && <AuraPill value={chat.primary.aura_total} size="sm"/>}</div><span>{chat.last_message?.body || (chat.conversation_type === 'group' ? `${chat.members.length} people · say something` : 'Start the conversation')}</span></div>
        <div className="chat-trailing"><small>{ageLabel(chat.last_message?.created_at || chat.updated_at)}</small>{Number(chat.unread_count) > 0 && <b>{Number(chat.unread_count) > 99 ? '99+' : chat.unread_count}</b>}</div>
      </button>)}
    </div> : <div className="chat-empty surface"><MessageCirclePlus size={28}/><h3>No chats yet.</h3><p className="muted">Find someone worth talking to — or start the group chat that becomes a problem later.</p><button className="btn btn--primary" onClick={() => setShowCreate(true)}>Start a chat</button></div>}

    {showCreate && <NewChatSheet onClose={() => setShowCreate(false)} onCreated={created}/>} 
  </div>
}
