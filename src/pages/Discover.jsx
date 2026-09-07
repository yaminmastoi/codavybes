import { useEffect, useMemo, useState } from 'react'
import { Check, Clock3, Link2, MessageCircle, Search, ShieldCheck, Sparkles, UserPlus, Users, X, Zap } from 'lucide-react'
import { useNavigate, useSearchParams } from 'react-router-dom'
import AuraPill from '../components/AuraPill'
import Avatar from '../components/Avatar'
import PlusBadge from '../components/PlusBadge'
import VerifiedBadge from '../components/VerifiedBadge'
import { getDiscoverPeople, getMeetRequests, getMyConnections, getMyMeetSessions, respondMeetRequest, sendMeetRequest } from '../services/socialService'
import { createDirectChat } from '../services/chatService'
import RankMark from '../components/RankMark'
import { PageSkeleton } from '../components/Loaders'
import InterestIcon from '../components/InterestIcon'

function initials(name = 'CodaVybes') {
  return name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'V'
}

function prettyInterest(value = '') {
  return value.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function IdentityBadges({ person, size = 15 }) {
  return <span className="identity-badges"><VerifiedBadge verified={person?.is_verified} size={size}/><PlusBadge active={person?.is_plus} size={size}/></span>
}

function ProfilePreview({ person, onClose, onMeet, busy }) {
  useEffect(() => {
    if (!person) return undefined
    const onKey = (event) => { if (event.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [person, onClose])

  if (!person) return null
  const name = person.display_name || person.username
  return <div className="discover-preview-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
    <section className="discover-preview surface" role="dialog" aria-modal="true" aria-label={`${name} profile preview`}>
      <button className="discover-preview__close" onClick={onClose} aria-label="Close profile preview"><X size={18}/></button>
      <div className="discover-preview__glow" aria-hidden="true"/>
      <div className="discover-preview__avatar"><Avatar src={person.avatar_url} alt={name} initials={initials(name)} size="xl"/></div>
      <div className="discover-preview__name"><h2>{name}</h2><IdentityBadges person={person} size={20}/></div>
      <p className="discover-preview__handle">@{person.username}{person.age_display ? ` · ${person.age_display}` : ''}</p>
      <div className="discover-preview__metrics">
        <div><span>VIBE MATCH</span><strong><Sparkles size={15}/>{person.match_score}%</strong></div>
        <div><span>AURA</span><strong><Zap size={15} fill="currentColor"/>+{Number(person.aura_total || 0).toLocaleString()}</strong></div>
        <div><span>SHARED</span><strong>{person.shared_count || 0}</strong></div>
      </div>
      <div className="discover-preview__rank"><RankMark rank={person.rank} size={16} label={false}/><span>{person.rank?.name || 'NEW VIBE'}</span></div>
      {!!person.shared_interests?.length && <div className="discover-preview__interests">{person.shared_interests.slice(0, 6).map((item) => <span key={item}><InterestIcon interest={item} size={14}/>{prettyInterest(item)}</span>)}</div>}
      <button className="btn btn--primary discover-preview__meet" disabled={busy} onClick={() => onMeet(person)}><UserPlus size={17}/>{busy ? 'Sending…' : 'Meet'}</button>
    </section>
  </div>
}

export default function Discover() {
  const navigate = useNavigate()
  const [searchParams, setSearchParams] = useSearchParams()
  const initialTab = ['for_you','new','requests','connections'].includes(searchParams.get('tab')) ? searchParams.get('tab') : 'for_you'
  const [tab, setTab] = useState(initialTab)
  const [searchOpen, setSearchOpen] = useState(false)
  const [searchQuery, setSearchQuery] = useState('')
  const [people, setPeople] = useState([])
  const [requests, setRequests] = useState([])
  const [connections, setConnections] = useState([])
  const [sessions, setSessions] = useState([])
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState('')
  const [busyId, setBusyId] = useState(null)
  const [previewPerson, setPreviewPerson] = useState(null)

  const load = async () => {
    setLoading(true)
    setNotice('')
    try {
      if (tab === 'requests') { const [reqs, active] = await Promise.all([getMeetRequests(), getMyMeetSessions()]); setRequests(reqs); setSessions(active) }
      else if (tab === 'connections') setConnections(await getMyConnections())
      else setPeople(await getDiscoverPeople(tab))
    } catch (error) {
      setNotice(error.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [tab])

  const visiblePeople = useMemo(() => {
    const q = searchQuery.trim().toLowerCase()
    if (!q) return people
    return people.filter((person) => [person.username, person.display_name, ...(person.shared_interests || [])].filter(Boolean).some((value) => String(value).toLowerCase().includes(q)))
  }, [people, searchQuery])

  const incoming = useMemo(() => requests.filter((item) => item.direction === 'incoming' && item.status === 'pending'), [requests])
  const outgoing = useMemo(() => requests.filter((item) => item.direction === 'outgoing' && item.status === 'pending'), [requests])

  const meet = async (user) => {
    try {
      setBusyId(user.user_id); setNotice('')
      await sendMeetRequest(user.user_id)
      setPeople((rows) => rows.filter((row) => row.user_id !== user.user_id))
      setPreviewPerson(null)
      setNotice(`Meet request sent to @${user.username}.`)
    } catch (error) { setNotice(error.message) }
    finally { setBusyId(null) }
  }

  const respond = async (request, accept) => {
    try {
      setBusyId(request.request_id); setNotice('')
      const result = await respondMeetRequest(request.request_id, accept)
      if (result?.accepted && result?.session_id) navigate(`/meet/${result.session_id}`)
      else await load()
    } catch (error) { setNotice(error.message) }
    finally { setBusyId(null) }
  }

  const openChat = async (connection) => {
    try {
      setBusyId(connection.user_id)
      const id = await createDirectChat(connection.user_id)
      navigate(`/chats/${id}`)
    } catch (error) { setNotice(error.message) }
    finally { setBusyId(null) }
  }

  return <div className="page discover-page discover-page--list">
    <header className="page-head discover-head-v133">
      <div><p className="eyebrow">FIND YOUR PEOPLE</p><h1>Discover</h1></div>
      <button className="icon-btn surface" aria-label="Search" onClick={() => setSearchOpen((v) => !v)}><Search size={20}/></button>
    </header>

    {searchOpen && <div className="discover-search surface"><Search size={17}/><input autoFocus value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} placeholder="Search people, interests, @username…"/><button onClick={() => { setSearchQuery(''); setSearchOpen(false) }} aria-label="Close search"><X size={16}/></button></div>}

    <div className="age-safety-chip"><ShieldCheck size={14}/><span>Discovery is automatically kept inside your age-safety pool.</span></div>

    <div className="filter-row discover-tabs discover-tabs--v133">
      <button className={tab === 'for_you' ? 'is-active' : ''} onClick={() => { setTab('for_you'); setSearchParams({ tab: 'for_you' }) }}>For You</button>
      <button className={tab === 'new' ? 'is-active' : ''} onClick={() => { setTab('new'); setSearchParams({ tab: 'new' }) }}>New Here</button>
      <button className={tab === 'requests' ? 'is-active' : ''} onClick={() => { setTab('requests'); setSearchParams({ tab: 'requests' }) }}>Requests</button>
      <button className={tab === 'connections' ? 'is-active' : ''} onClick={() => { setTab('connections'); setSearchParams({ tab: 'connections' }) }}>Bonds</button>
    </div>

    {notice && <div className="notice discover-notice">{notice}</div>}
    {loading ? <PageSkeleton variant="discover" count={3}/> : null}

    {!loading && (tab === 'for_you' || tab === 'new') && <section className="discover-people-list" aria-label="People you may want to meet">
      {visiblePeople.map((person) => {
        const name = person.display_name || person.username
        return <article className="discover-person-row" key={person.user_id}>
          <button className="discover-person-avatar" type="button" onClick={() => setPreviewPerson(person)} aria-label={`Open ${name} profile`}>
            <Avatar src={person.avatar_url} alt={name} initials={initials(name)} size="lg"/>
            <span className="discover-person-match"><Sparkles size={10}/>{person.match_score}%</span>
          </button>
          <button className="discover-person-copy" type="button" onClick={() => setPreviewPerson(person)}>
            <span className="discover-person-name"><strong>{name}</strong><IdentityBadges person={person} size={15}/></span>
            <span className="discover-person-handle">@{person.username}{person.age_display ? ` · ${person.age_display}` : ''}</span>
            <span className="discover-person-meta"><RankMark rank={person.rank} size={12} label={false}/><b>{person.rank?.name || 'NEW VIBE'}</b><i>·</i><span>{person.shared_count || 0} shared vibes</span><i>·</i><span><Zap size={11} fill="currentColor"/>+{Number(person.aura_total || 0).toLocaleString()}</span></span>
          </button>
          <button className="discover-meet-inline" disabled={busyId === person.user_id} onClick={() => meet(person)}><UserPlus size={15}/><span>{busyId === person.user_id ? 'Sending' : 'Meet'}</span></button>
        </article>
      })}
      {!visiblePeople.length && <article className="surface discover-empty"><Users size={28}/><h3>No fresh matches right now.</h3><p>Come back after more people enter your CodaVybes pool.</p></article>}
    </section>}

    {!loading && tab === 'requests' && <section className="meet-request-section">
      <div className="section-title"><div><p className="eyebrow">INCOMING</p><h3>People who want to meet</h3></div><span>{incoming.length}</span></div>
      <div className="request-list">{incoming.map((request) => <article className="surface request-card" key={request.request_id}>
        <Avatar src={request.avatar_url} alt={request.display_name || request.username} initials={initials(request.display_name || request.username)} size="md"/>
        <div><div className="identity-line"><strong>{request.display_name || request.username}</strong><IdentityBadges person={request} size={15}/></div><span>@{request.username} · {request.match_score}% match</span></div>
        <div className="request-actions"><button className="mini-action decline" onClick={() => respond(request, false)} disabled={busyId === request.request_id}><X size={16}/></button><button className="mini-action accept" onClick={() => respond(request, true)} disabled={busyId === request.request_id}><Check size={16}/></button></div>
      </article>)}</div>
      {!incoming.length && <div className="surface mini-empty"><Clock3 size={20}/><span>No incoming Meet requests.</span></div>}

      {!!sessions.length && <>
        <div className="section-title second"><div><p className="eyebrow">LIVE MEETS</p><h3>Jump back in</h3></div><span>{sessions.length}</span></div>
        <div className="request-list">{sessions.map((session) => <button className="surface request-card active-meet-card" key={session.session_id} onClick={() => session.status === 'connected' && session.conversation_id ? navigate(`/chats/${session.conversation_id}`) : navigate(`/meet/${session.session_id}`)}>
          <Avatar src={session.avatar_url} alt={session.display_name || session.username} initials={initials(session.display_name || session.username)} size="md"/>
          <div><div className="identity-line"><strong>{session.display_name || session.username}</strong><IdentityBadges person={session} size={15}/></div><span>{session.status === 'connected' ? 'Connected · open chat' : `${session.match_score}% match · Meet live`}</span></div>
          <span className="waiting-pill">{session.status === 'connected' ? <MessageCircle size={13}/> : <Clock3 size={13}/>} {session.status === 'connected' ? 'Chat' : 'Enter'}</span>
        </button>)}</div>
      </>}

      <div className="section-title second"><div><p className="eyebrow">OUTGOING</p><h3>Waiting on them</h3></div><span>{outgoing.length}</span></div>
      <div className="request-list">{outgoing.map((request) => <article className="surface request-card request-card--out" key={request.request_id}>
        <Avatar src={request.avatar_url} alt={request.display_name || request.username} initials={initials(request.display_name || request.username)} size="md"/>
        <div><div className="identity-line"><strong>{request.display_name || request.username}</strong><IdentityBadges person={request} size={15}/></div><span>@{request.username} · {request.match_score}% match</span></div>
        <span className="waiting-pill"><Clock3 size={13}/> Pending</span>
      </article>)}</div>
    </section>}

    {!loading && tab === 'connections' && <section className="bond-grid">
      {connections.map((connection) => <article className="surface bond-card" key={connection.connection_id}>
        <div className="bond-card__head"><Avatar src={connection.avatar_url} alt={connection.display_name || connection.username} initials={initials(connection.display_name || connection.username)} size="lg"/><div><div className="identity-line"><h3>{connection.display_name || connection.username}</h3><IdentityBadges person={connection} size={16}/></div><p>@{connection.username}</p></div><AuraPill value={connection.aura_total} size="sm"/></div>
        <div className="bond-meter"><span style={{ width: `${connection.bond_percent}%` }}/></div>
        <div className="row between bond-meta"><div><strong><Link2 size={14}/> {connection.bond_percent}%</strong><span>{connection.bond_label}</span></div><small>{connection.bond_points} bond pts</small></div>
        <button className="btn btn--outline" onClick={() => openChat(connection)} disabled={busyId === connection.user_id}><MessageCircle size={17}/> Open Chat</button>
      </article>)}
      {!connections.length && <article className="surface discover-empty"><Users size={28}/><h3>No Bonds yet.</h3><p>Meet someone, both choose Keep, then your Bond begins at 1%.</p></article>}
    </section>}

    <ProfilePreview person={previewPerson} onClose={() => setPreviewPerson(null)} onMeet={meet} busy={busyId === previewPerson?.user_id}/>
  </div>
}
