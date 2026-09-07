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

function initials(name='CodaVybes'){return name.trim().split(/\s+/).slice(0,2).map(v=>v[0]?.toUpperCase()).join('')||'V'}
export default function MomentThread(){
 const {targetId}=useParams();const navigate=useNavigate();const{onboarding}=useAuth();const[moment,setMoment]=useState(null);const[thread,setThread]=useState(null);const[text,setText]=useState('');const[busy,setBusy]=useState(false);const[notice,setNotice]=useState('');const[shareOpen,setShareOpen]=useState(false)
 const load=useCallback(async()=>{const[m,t]=await Promise.all([getPublicMoment(targetId),getMomentThread(targetId)]);setMoment(m);setThread(t)},[targetId]);useEffect(()=>{load().catch(e=>setNotice(e.message))},[load])
 const react=async()=>{try{setBusy(true);const r=await toggleMomentReaction(targetId);setThread(v=>({...v,viewer_reacted:r.reacted,reaction_count:r.count}))}catch(e){setNotice(e.message)}finally{setBusy(false)}}
 const aura=async()=>{try{setBusy(true);const r=await giveAura(targetId);setMoment(v=>({...v,aura_count:r.target_aura,viewer_has_aura:true}));setNotice(r.already_given?'Aura already given.':'Aura +1')}catch(e){setNotice(e.message)}finally{setBusy(false)}}
 const reply=async(e)=>{e.preventDefault();if(!text.trim())return;try{setBusy(true);await addMomentComment(targetId,text.trim());setText('');await load()}catch(err){setNotice(err.message)}finally{setBusy(false)}}
 if(!moment)return <div className="page"><header className="page-head page-head--back"><button className="icon-btn surface" onClick={()=>navigate(-1)}><ArrowLeft size={20}/></button><div><p className="eyebrow">AURA MOMENT</p><h1>Thread</h1></div><span className="head-spacer"/></header><PageSkeleton variant="compact" count={2}/></div>
 const user=moment.display_name||moment.username||'CodaVybes User';const own=moment.author_id===onboarding?.user_id
 return <div className="page moment-thread-page"><header className="page-head page-head--back"><button className="icon-btn surface" onClick={()=>navigate(-1)}><ArrowLeft size={20}/></button><div><p className="eyebrow">AURA MOMENT</p><h1>Thread</h1></div><span className="head-spacer"/></header>
 <article className="feed-card surface"><header className="feed-card__head"><div className="row gap-12"><Avatar initials={initials(user)} online/><div><div className="identity-line"><strong>{user}</strong><VerifiedBadge verified={moment.author_verified} size={14}/></div><small className="muted">@{moment.username} · {moment.context_label}</small></div></div><AuraPill value={moment.author_aura} size="sm"/></header><div className="moment-card"><div className="eyebrow"><Zap size={14} fill="currentColor"/> {moment.is_aura_moment?'AURA MOMENT':'CodaVybes MOMENT'}</div><p>{moment.content_text}</p><div className="moment-card__score">+{moment.aura_count} Aura · {moment.unique_givers} people</div></div><footer className="thread-actions"><button className={thread?.viewer_reacted?'is-active':''} onClick={react} disabled={busy}><Heart size={18} fill={thread?.viewer_reacted?'currentColor':'none'}/> {thread?.reaction_count||0}</button><button className="aura-action" onClick={aura} disabled={busy||own||moment.viewer_has_aura}><Zap size={18} fill="currentColor"/> {own?'Your moment':moment.viewer_has_aura?'Aura given':'Aura +'}</button><span><MessageCircle size={18}/>{thread?.comment_count||0}</span><button onClick={()=>setShareOpen(true)}><Share2 size={18}/> Share</button></footer></article>
 {notice&&<div className="notice">{notice}</div>}
 <section className="comment-list">{(thread?.comments||[]).map(c=><article className="surface comment-row" key={c.id}><Avatar initials={initials(c.display_name||c.username)} size="sm"/><div><div className="identity-line"><strong>{c.display_name||c.username}</strong><VerifiedBadge verified={c.is_verified} size={13}/><small> @{c.username}</small></div><p>{c.body}</p><time>{new Date(c.created_at).toLocaleString()}</time></div></article>)}{thread&&!thread.comments.length&&<div className="mini-empty surface">No replies yet. Be first.</div>}</section>
 <form className="comment-composer surface" onSubmit={reply}><input value={text} onChange={e=>setText(e.target.value)} maxLength={800} placeholder="Reply to this moment…"/><button disabled={busy||!text.trim()}>{busy?<LoaderCircle className="spin" size={17}/>:<Send size={17}/>}</button></form>{shareOpen&&<ShareMomentModal item={{...moment,target_id:targetId,author_rank:moment.author_rank}} onClose={()=>setShareOpen(false)}/>}</div>
}
