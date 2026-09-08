import { Check, CheckCheck, Flame, Flag, Laugh, LoaderCircle, Skull, Trash2, Zap } from 'lucide-react'
import VerifiedBadge from './VerifiedBadge'

const QUICK_REACTIONS = [
  { value: '😂', label: 'Laugh', Icon: Laugh },
  { value: '💀', label: 'Dead', Icon: Skull },
  { value: '🔥', label: 'Fire', Icon: Flame },
]
function ReactionIcon({ value, size = 13 }) {
  const item = QUICK_REACTIONS.find((x) => x.value === value)
  const Icon = item?.Icon || Laugh
  return <Icon size={size}/>
}
function timeLabel(value) { if (!value) return ''; return new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit' }).format(new Date(value)) }

function MessageReceipt({ message }) {
  if (message.viewed_at) return <span className="message-receipt is-viewed" title="Viewed" aria-label="Viewed"><CheckCheck size={13}/></span>
  if (message.delivered_at) return <span className="message-receipt" title="Delivered" aria-label="Delivered"><CheckCheck size={13}/></span>
  return <span className="message-receipt" title="Sent · recipient offline" aria-label="Sent; recipient offline"><Check size={13}/></span>
}

export default function MessageBubble({ message, isMine, busyAura, busyReaction, busyDelete, onAura, onReaction, onReport, onDelete }) {
  const reactions = Array.isArray(message.reactions) ? message.reactions : []
  const isDeleted = message.status !== 'active'
  return <article className={`message-wrap ${isMine ? 'message-wrap--me' : ''}`}>
    {!isMine && <div className="message-sender identity-line"><span>{message.sender_display_name || message.sender_username || 'CodaVybes user'}</span><VerifiedBadge verified={message.sender_verified} size={13}/></div>}
    <div className={`message-bubble ${isMine ? 'message-bubble--me' : ''} ${message.is_aura_moment && !isDeleted ? 'message-bubble--moment' : ''} ${isDeleted ? 'message-bubble--deleted' : ''}`}>
      {message.is_aura_moment && !isDeleted && <div className="message-aura-label"><Zap size={12}/> AURA MOMENT</div>}
      <p className={isDeleted ? 'message-deleted-copy' : ''}>{message.body}</p>
      <div className="message-meta"><span>{timeLabel(message.created_at)}</span>{!isDeleted && message.aura_count > 0 && <strong><Zap size={11}/> +{message.aura_count}</strong>}{isMine && <MessageReceipt message={message}/>}</div>
    </div>
    {!isDeleted && reactions.length > 0 && <div className={`reaction-counts ${isMine ? 'reaction-counts--me' : ''}`}>{reactions.map((reaction) => <button key={reaction.emoji} className={reaction.viewer ? 'is-viewer' : ''} onClick={() => onReaction(message.message_id, reaction.emoji)} disabled={busyReaction} aria-label={`${reaction.count} reactions`}><ReactionIcon value={reaction.emoji}/>{reaction.count}</button>)}</div>}
    {!isDeleted && <div className={`message-actions ${isMine ? 'message-actions--me' : ''}`}>
      {QUICK_REACTIONS.map(({ value, label, Icon }) => <button key={value} onClick={() => onReaction(message.message_id, value)} disabled={busyReaction} aria-label={label}>{!busyReaction && <Icon size={14}/>}</button>)}
      {isMine ? <button className="message-delete" onClick={() => onDelete(message)} disabled={busyDelete} aria-label="Delete message">{busyDelete ? <LoaderCircle className="spin" size={13}/> : <Trash2 size={13}/>}</button> : <><button className={message.viewer_has_aura ? 'aura-done' : 'aura-quick'} onClick={() => onAura(message.message_id)} disabled={busyAura || message.viewer_has_aura}>{busyAura ? <LoaderCircle className="spin" size={13}/> : <Zap size={13}/>} {message.viewer_has_aura ? 'Aura given' : 'Aura +1'}</button><button className="report-quick" onClick={() => onReport(message)} aria-label="Report message"><Flag size={13}/></button></>}
    </div>}
  </article>
}
