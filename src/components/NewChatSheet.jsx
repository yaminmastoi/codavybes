import { useEffect, useState } from 'react'
import { LoaderCircle, Search, Users, X } from 'lucide-react'
import Avatar from './Avatar'
import AuraPill from './AuraPill'
import VerifiedBadge from './VerifiedBadge'
import { createDirectChat, createGroupChat, searchChatPeople } from '../services/chatService'

function initials(name = 'V') {
  return name.trim().split(/\s+/).slice(0,2).map((part) => part[0]?.toUpperCase()).join('') || 'V'
}

export default function NewChatSheet({ onClose, onCreated }) {
  const [mode, setMode] = useState('direct')
  const [query, setQuery] = useState('')
  const [results, setResults] = useState([])
  const [selected, setSelected] = useState([])
  const [title, setTitle] = useState('')
  const [loading, setLoading] = useState(false)
  const [creating, setCreating] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    const q = query.trim()
    if (q.length < 2) { setResults([]); return undefined }
    const timer = setTimeout(async () => {
      setLoading(true); setError('')
      try { setResults(await searchChatPeople(q, 20)) }
      catch (e) { setError(e.message || 'Search failed.') }
      finally { setLoading(false) }
    }, 280)
    return () => clearTimeout(timer)
  }, [query])

  async function chooseDirect(userId) {
    setCreating(true); setError('')
    try { onCreated(await createDirectChat(userId)) }
    catch (e) { setError(e.message || 'Could not start chat.') }
    finally { setCreating(false) }
  }

  function toggleSelected(person) {
    setSelected((current) => current.some((x) => x.user_id === person.user_id)
      ? current.filter((x) => x.user_id !== person.user_id)
      : [...current, person])
  }

  async function createGroup() {
    if (!title.trim() || selected.length < 1) return
    setCreating(true); setError('')
    try { onCreated(await createGroupChat(title.trim(), selected.map((x) => x.user_id))) }
    catch (e) { setError(e.message || 'Could not create group.') }
    finally { setCreating(false) }
  }

  return <div className="sheet-backdrop" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
    <section className="new-chat-sheet surface">
      <header className="sheet-head"><div><p className="eyebrow">START SOMETHING</p><h2>{mode === 'direct' ? 'New chat' : 'New group'}</h2></div><button className="icon-btn" onClick={onClose}><X size={20}/></button></header>
      <div className="mini-tabs chat-create-tabs">
        <button className={mode === 'direct' ? 'is-active' : ''} onClick={() => { setMode('direct'); setSelected([]) }}>1:1</button>
        <button className={mode === 'group' ? 'is-active' : ''} onClick={() => setMode('group')}><Users size={13}/> Group</button>
      </div>

      {mode === 'group' && <label>Group name<div className="input-wrap"><input value={title} maxLength={50} onChange={(e) => setTitle(e.target.value)} placeholder="Weekend Crew"/></div></label>}

      <label>Find people<div className="input-wrap"><Search size={17}/><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search username or name"/></div></label>
      {error && <div className="notice error-box">{error}</div>}
      {selected.length > 0 && <div className="selected-people">{selected.map((p) => <button key={p.user_id} onClick={() => toggleSelected(p)}>{p.display_name || p.username} ×</button>)}</div>}

      <div className="people-results">
        {loading && <div className="sheet-empty"><LoaderCircle className="spin" size={18}/> Searching...</div>}
        {!loading && query.trim().length >= 2 && results.length === 0 && <div className="sheet-empty">No people found.</div>}
        {results.map((person) => {
          const chosen = selected.some((x) => x.user_id === person.user_id)
          return <button key={person.user_id} className={`person-result ${chosen ? 'is-selected' : ''}`} onClick={() => mode === 'direct' ? chooseDirect(person.user_id) : toggleSelected(person)} disabled={creating}>
            <Avatar initials={initials(person.display_name || person.username)}/>
            <div><div className="identity-line"><strong>{person.display_name || person.username}</strong><VerifiedBadge verified={person.is_verified} size={14}/></div><span>@{person.username}</span></div>
            <AuraPill value={person.aura_total} size="sm"/>
          </button>
        })}
      </div>

      {mode === 'group' && <button className="btn btn--primary" onClick={createGroup} disabled={creating || selected.length < 1 || !title.trim()}>{creating ? <LoaderCircle className="spin" size={17}/> : <Users size={17}/>} Create group</button>}
    </section>
  </div>
}
