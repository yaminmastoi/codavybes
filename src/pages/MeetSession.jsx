import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { ArrowLeft, Check, Clock3, MessageCircle, Send, ShieldCheck, Sparkles, X, Zap } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import Avatar from '../components/Avatar'
import AuraPill from '../components/AuraPill'
import VerifiedBadge from '../components/VerifiedBadge'
import { useAuth } from '../context/AuthContext'
import { decideMeet, getMeetMessages, getMeetSession, sendMeetMessage, subscribeToMeetSession } from '../services/socialService'
import { AppLaunchLoader } from '../components/Loaders'

function initials(name = 'CodaVybes') {
  return name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'V'
}

function formatTime(seconds) {
  const safe = Math.max(0, seconds)
  const m = Math.floor(safe / 60)
  const s = safe % 60
  return `${m}:${String(s).padStart(2, '0')}`
}

export default function MeetSession() {
  const { sessionId } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const [session, setSession] = useState(null)
  const [messages, setMessages] = useState([])
  const [body, setBody] = useState('')
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState('')
  const [seconds, setSeconds] = useState(0)
  const bottomRef = useRef(null)

  const load = useCallback(async () => {
    try {
      const [state, rows] = await Promise.all([getMeetSession(sessionId), getMeetMessages(sessionId)])
      setSession(state); setMessages(rows); setNotice('')
    } catch (error) { setNotice(error.message) }
    finally { setLoading(false) }
  }, [sessionId])

  useEffect(() => { load() }, [load])
  useEffect(() => subscribeToMeetSession(sessionId, load), [sessionId, load])

  useEffect(() => {
    if (!session?.expires_at) return undefined
    const tick = () => setSeconds(Math.max(0, Math.floor((new Date(session.expires_at).getTime() - Date.now()) / 1000)))
    tick(); const id = setInterval(tick, 1000); return () => clearInterval(id)
  }, [session?.expires_at])

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [messages.length])

  const ended = useMemo(() => session?.status !== 'active' || seconds <= 0, [session?.status, seconds])
  const other = session?.other || {}

  const send = async (event) => {
    event?.preventDefault()
    const text = body.trim()
    if (!text || busy || ended) return
    try {
      setBusy(true); setNotice('')
      const row = await sendMeetMessage(sessionId, text)
      setMessages((current) => [...current, row]); setBody('')
    } catch (error) { setNotice(error.message) }
    finally { setBusy(false) }
  }

  const decide = async (choice) => {
    try {
      setBusy(true); setNotice('')
      const result = await decideMeet(sessionId, choice)
      if (result?.connected && result?.conversation_id) {
        navigate(`/chats/${result.conversation_id}`, { replace: true })
        return
      }
      if (choice === 'move_on' || result?.status === 'closed') {
        navigate('/discover', { replace: true })
        return
      }
      await load()
      if (result?.waiting_for_other) setNotice('You chose Keep. Waiting for the other person.')
    } catch (error) { setNotice(error.message) }
    finally { setBusy(false) }
  }

  if (loading) return <AppLaunchLoader label="Opening Meet" />

  return <div className="page meet-page">
    <header className="meet-head surface">
      <button className="icon-btn" onClick={() => navigate('/discover')}><ArrowLeft size={20}/></button>
      <div className="meet-head__person"><Avatar initials={initials(other.display_name || other.username)} size="sm"/><div><div className="identity-line"><strong>{other.display_name || other.username || 'CodaVybes'}</strong><VerifiedBadge verified={other.is_verified || session?.other_verified} size={15}/></div><span>@{other.username || 'codavybes'}</span></div></div>
      <div className={`meet-timer ${seconds < 60 ? 'is-hot' : ''}`}><Clock3 size={14}/><strong>{formatTime(seconds)}</strong></div>
    </header>

    <section className="meet-intro surface">
      <div className="meet-intro__top"><div><p className="eyebrow"><Sparkles size={13}/> TEMPORARY MEET</p><h1>See if you click.</h1></div><AuraPill value={other.aura_total || 1} size="sm"/></div>
      <div className="icebreaker-card"><span>ICEBREAKER</span><strong>{session?.icebreaker}</strong></div>
      <div className="age-safety-chip"><ShieldCheck size={14}/><span>Meet only connects people inside the same age-safety pool. Exact DOB stays private.</span></div>
    </section>

    {notice && <div className="notice meet-notice">{notice}</div>}

    <main className="meet-message-stream">
      <div className="meet-system"><Zap size={14}/><span>You have a short window to talk. Both people must choose <b>Keep</b> before a permanent chat unlocks.</span></div>
      {messages.map((message) => {
        const mine = message.sender_id === user?.id
        return <div className={`meet-message ${mine ? 'is-mine' : ''}`} key={message.id}>
          {!mine && <Avatar initials={initials(other.display_name || other.username)} size="xs"/>}
          <div><p>{message.body}</p><small>{new Date(message.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</small></div>
        </div>
      })}
      <div ref={bottomRef}/>
    </main>

    {session?.status === 'connected' && session?.conversation_id ? <section className="meet-decision-panel surface"><div><Check size={22}/><strong>Connection made.</strong><span>Your Bond has started.</span></div><button className="btn btn--primary" onClick={() => navigate(`/chats/${session.conversation_id}`)}><MessageCircle size={18}/> Open Chat</button></section> : <>
      <section className="meet-decision-panel surface">
        <div className="meet-decision-copy"><strong>{session?.my_decision === 'keep' ? 'You chose Keep' : ended ? 'Time’s up. Decide.' : 'Want to keep this connection?'}</strong><span>{session?.my_decision === 'keep' ? 'Waiting for the other person.' : 'Keep only works if both of you choose it.'}</span></div>
        <div className="meet-decision-actions"><button className="decision-btn move" onClick={() => decide('move_on')} disabled={busy || session?.my_decision === 'keep'}><X size={18}/> Move On</button><button className="decision-btn keep" onClick={() => decide('keep')} disabled={busy || session?.my_decision === 'keep'}><Check size={18}/> Keep</button></div>
      </section>

      <form className="meet-composer" onSubmit={send}>
        <input value={body} onChange={(e) => setBody(e.target.value)} placeholder={ended ? 'Meet ended — choose Keep or Move On' : 'Say something worth keeping…'} maxLength={1200} disabled={ended}/>
        <button type="submit" disabled={!body.trim() || busy || ended}><Send size={18}/></button>
      </form>
    </>}
  </div>
}
