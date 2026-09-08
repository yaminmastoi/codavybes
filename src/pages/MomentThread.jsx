import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Heart, LoaderCircle, MessageCircle, Send, Share2, Zap } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import Avatar from '../components/Avatar'
import AuraPill from '../components/AuraPill'
import VerifiedBadge from '../components/VerifiedBadge'
import { giveAura } from '../services/auraService'
import { addMomentComment, getMomentThread, getPublicMoment, toggleMomentReaction } from '../services/momentService'
import { useAuth } from '../context/AuthContext'
import { PageSkeleton } from '../components/Loaders'
import ShareMomentModal from '../components/ShareMomentModal'

function initials(name = 'CodaVybes') {
  return name.trim().split(/\s+/).slice(0, 2).map((value) => value[0]?.toUpperCase()).join('') || 'CV'
}

export default function MomentThread() {
  const { targetId } = useParams()
  const navigate = useNavigate()
  const { onboarding } = useAuth()
  const [moment, setMoment] = useState(null)
  const [thread, setThread] = useState(null)
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [notice, setNotice] = useState('')
  const [shareOpen, setShareOpen] = useState(false)

  const load = useCallback(async () => {
    const [nextMoment, nextThread] = await Promise.all([getPublicMoment(targetId), getMomentThread(targetId)])
    setMoment(nextMoment)
    setThread(nextThread)
  }, [targetId])

  useEffect(() => {
    load().catch((error) => setNotice(error.message))
  }, [load])

  const react = async () => {
    try {
      setBusy(true)
      const result = await toggleMomentReaction(targetId)
      setThread((value) => ({ ...value, viewer_reacted: result.reacted, reaction_count: result.count }))
    } catch (error) {
      setNotice(error.message)
    } finally {
      setBusy(false)
    }
  }

  const aura = async () => {
    try {
      setBusy(true)
      const result = await giveAura(targetId)
      setMoment((value) => ({ ...value, aura_count: result.target_aura, viewer_has_aura: true }))
      setNotice(result.already_given ? 'Aura already given.' : 'Aura +1')
    } catch (error) {
      setNotice(error.message)
    } finally {
      setBusy(false)
    }
  }

  const reply = async (event) => {
    event.preventDefault()
    if (!text.trim()) return

    try {
      setBusy(true)
      await addMomentComment(targetId, text.trim())
      setText('')
      await load()
    } catch (error) {
      setNotice(error.message)
    } finally {
      setBusy(false)
    }
  }

  if (!moment) {
    return <div className="page moment-thread-page">
      <header className="page-head page-head--back">
        <button className="icon-btn surface" type="button" aria-label="Go back" onClick={() => navigate(-1)}><ArrowLeft size={20} /></button>
        <div><p className="eyebrow">AURA MOMENT</p><h1>Thread</h1></div>
        <span className="head-spacer" aria-hidden="true" />
      </header>
      <PageSkeleton variant="compact" count={2} />
    </div>
  }

  const user = moment.display_name || moment.username || 'CodaVybes User'
  const own = moment.author_id === onboarding?.user_id
  const auraLabel = own ? 'Your moment' : moment.viewer_has_aura ? 'Aura given' : 'Aura +'

  return <div className="page moment-thread-page">
    <header className="page-head page-head--back moment-thread-page__head">
      <button className="icon-btn surface" type="button" aria-label="Go back" onClick={() => navigate(-1)}><ArrowLeft size={20} /></button>
      <div><p className="eyebrow">AURA MOMENT</p><h1>Thread</h1></div>
      <span className="head-spacer" aria-hidden="true" />
    </header>

    <article className="feed-card surface moment-thread-card">
      <header className="feed-card__head moment-thread-author">
        <div className="feed-card__author">
          <Avatar initials={initials(user)} online />
          <div className="feed-card__identity">
            <div className="identity-line"><strong>{user}</strong><VerifiedBadge verified={moment.author_verified} size={14} /></div>
            <small className="muted feed-card__handle">@{moment.username} · {moment.context_label}</small>
          </div>
        </div>
        <AuraPill value={moment.author_aura} size="sm" />
      </header>

      <div className="moment-card moment-thread-card__content">
        <div className="eyebrow"><Zap size={14} fill="currentColor" /> {moment.is_aura_moment ? 'AURA MOMENT' : 'CODAVYBES MOMENT'}</div>
        <p>{moment.content_text}</p>
        <div className="moment-card__score">+{moment.aura_count} Aura · {moment.unique_givers} people</div>
      </div>

      <footer className="thread-actions" aria-label="Moment actions">
        <button type="button" aria-label={`Like moment, ${thread?.reaction_count || 0} likes`} className={thread?.viewer_reacted ? 'is-active' : ''} onClick={react} disabled={busy}><Heart size={18} fill={thread?.viewer_reacted ? 'currentColor' : 'none'} /><b>{thread?.reaction_count || 0}</b></button>
        <button type="button" className="aura-action" onClick={aura} disabled={busy || own || moment.viewer_has_aura}><Zap size={18} fill="currentColor" /><b>{auraLabel}</b></button>
        <span aria-label={`${thread?.comment_count || 0} replies`}><MessageCircle size={18} /><b>{thread?.comment_count || 0}</b></span>
        <button type="button" onClick={() => setShareOpen(true)}><Share2 size={18} /><b>Share</b></button>
      </footer>
    </article>

    {notice && <div className="notice" role="status">{notice}</div>}

    <section className="comment-list" aria-label="Replies">
      {(thread?.comments || []).map((comment) => <article className="surface comment-row" key={comment.id}>
        <Avatar initials={initials(comment.display_name || comment.username)} size="sm" />
        <div className="comment-row__copy">
          <div className="identity-line comment-row__identity">
            <strong>{comment.display_name || comment.username}</strong>
            <VerifiedBadge verified={comment.is_verified} size={13} />
            <small className="comment-row__handle">@{comment.username}</small>
          </div>
          <p>{comment.body}</p>
          <time dateTime={comment.created_at}>{new Date(comment.created_at).toLocaleString()}</time>
        </div>
      </article>)}
      {thread && !thread.comments.length && <div className="mini-empty surface">No replies yet. Be first.</div>}
    </section>

    <form className="comment-composer surface" onSubmit={reply}>
      <input aria-label="Reply to this moment" value={text} onChange={(event) => setText(event.target.value)} maxLength={800} placeholder="Reply to this moment…" />
      <button aria-label="Send reply" disabled={busy || !text.trim()}>{busy ? <LoaderCircle className="spin" size={17} /> : <Send size={17} />}</button>
    </form>

    {shareOpen && <ShareMomentModal item={{ ...moment, target_id: targetId, author_rank: moment.author_rank }} onClose={() => setShareOpen(false)} />}
  </div>
}
