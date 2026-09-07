import { Heart, LoaderCircle, MessageCircle, Send, Zap } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Avatar from './Avatar'
import AuraPill from './AuraPill'
import { toggleMomentReaction } from '../services/momentService'
import { useState } from 'react'
import RankMark from './RankMark'
import VerifiedBadge from './VerifiedBadge'
import ShareMomentModal from './ShareMomentModal'

function initials(name = 'CodaVybes') { return name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'CV' }

export default function FeedCard({ item, onAura, auraBusy = false, currentUserId = null }) {
  const navigate = useNavigate();const [reacted,setReacted]=useState(false);const [reactBusy,setReactBusy]=useState(false);const [shareOpen,setShareOpen]=useState(false)
  const isOwn=currentUserId&&item.author_id===currentUserId;const rank=item.author_rank?.name||'NEW VIBE';const user=item.display_name||item.username||'CodaVybes User';const handle=item.username?`@${item.username}`:'@codavybes'
  const react=async()=>{try{setReactBusy(true);const result=await toggleMomentReaction(item.target_id);setReacted(!!result?.reacted)}catch(error){console.error(error)}finally{setReactBusy(false)}}
  const displayContext=(item.context_label||'CodaVybes').replace(/VYBE/gi,'CodaVybes')
  return <>
    <article className="feed-card surface">
      <header className="feed-card__head">
        <div className="feed-card__author"><Avatar initials={initials(user)} online/><div className="feed-card__identity"><div className="identity-line"><strong title={user}>{user}</strong><VerifiedBadge verified={item.author_verified}/></div><small className="muted feed-card__handle" title={`${handle} · ${displayContext}`}>{handle} · {displayContext}</small></div></div>
        <AuraPill value={item.author_aura??1} size="sm"/>
      </header>
      <div className="feed-card__status-row"><span className="rank-chip"><RankMark rank={item.author_rank||rank} size={12} label={false}/><span>{rank}</span></span><span className="feed-card__social-proof">{item.unique_givers??0} people backed this</span></div>
      <button className="moment-card moment-card--button" onClick={()=>navigate(`/moments/${item.target_id}`)}><div className="eyebrow"><Zap size={14}/> {item.is_aura_moment?'AURA MOMENT':'CODA MOMENT'}</div><p>{item.content_text}</p><div className="moment-card__score">+{item.aura_count??0} Aura · {item.unique_givers??0} people</div></button>
      <footer className="feed-actions"><button className={reacted?'is-reacted':''} onClick={react} disabled={reactBusy}><Heart size={18} fill={reacted?'currentColor':'none'}/> {reacted?'Reacted':'React'}</button><button className={`aura-action ${item.viewer_has_aura?'is-given':''}`} disabled={auraBusy||item.viewer_has_aura||isOwn} onClick={()=>onAura?.(item.target_id)}>{auraBusy?<LoaderCircle size={18} className="spin"/>:<Zap size={18}/>} {isOwn?'Yours':item.viewer_has_aura?'Given':'Aura +'}</button><button onClick={()=>navigate(`/moments/${item.target_id}`)}><MessageCircle size={18}/> Reply</button><button onClick={()=>setShareOpen(true)} aria-label="Share moment"><Send size={18}/> Share</button></footer>
    </article>
    {shareOpen&&<ShareMomentModal item={item} onClose={()=>setShareOpen(false)}/>} 
  </>
}
