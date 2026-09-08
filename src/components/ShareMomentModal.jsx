import { Check, Copy, Download, ExternalLink, Share2, Sparkles, X } from 'lucide-react'
import { useMemo, useState } from 'react'
import { recordMomentShare } from '../services/momentService'


function InstagramGlyph({size=20}){
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
    <rect x="3" y="3" width="18" height="18" rx="5" stroke="currentColor" strokeWidth="1.9"/>
    <circle cx="12" cy="12" r="4.1" stroke="currentColor" strokeWidth="1.9"/>
    <circle cx="17.35" cy="6.75" r="1.15" fill="currentColor"/>
  </svg>
}

function LinkedInGlyph({size=20}){
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" aria-hidden="true">
    <rect x="3" y="3" width="18" height="18" rx="3.5" stroke="currentColor" strokeWidth="1.8"/>
    <circle cx="8" cy="9" r="1.15" fill="currentColor"/>
    <path d="M7.1 11.1v5.8M11.1 16.9v-3.2c0-1.55.9-2.6 2.25-2.6 1.5 0 2.35 1 2.35 2.7v3.1M11.1 11.35v5.55" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/>
  </svg>
}

const THEMES={
  midnight:{label:'Midnight',bg:'#0d1020',fg:'#ffffff',accent:'#7c63ff',soft:'#1a2040'},
  pearl:{label:'Pearl',bg:'#f7f8fc',fg:'#141625',accent:'#6557e8',soft:'#ebeefe'},
  pulse:{label:'Pulse',bg:'#170f22',fg:'#fff7ff',accent:'#ff4fd8',soft:'#2d1735'},
}

function safeText(value=''){return String(value).replace(/\s+/g,' ').trim()}
function wrap(ctx,text,maxWidth){const words=safeText(text).split(' ');const lines=[];let line='';for(const word of words){const test=line?`${line} ${word}`:word;if(ctx.measureText(test).width>maxWidth&&line){lines.push(line);line=word}else line=test}if(line)lines.push(line);return lines}
function roundRect(ctx,x,y,w,h,r){if(typeof ctx.roundRect==='function'){ctx.roundRect(x,y,w,h,r);return}const rr=Math.min(r,w/2,h/2);ctx.moveTo(x+rr,y);ctx.arcTo(x+w,y,x+w,y+h,rr);ctx.arcTo(x+w,y+h,x,y+h,rr);ctx.arcTo(x,y+h,x,y,rr);ctx.arcTo(x,y,x+w,y,rr);ctx.closePath()}

async function makeCardBlob(item,themeKey='midnight'){
  const t=THEMES[themeKey]||THEMES.midnight
  const canvas=document.createElement('canvas');canvas.width=1080;canvas.height=1350
  const ctx=canvas.getContext('2d')
  ctx.fillStyle=t.bg;ctx.fillRect(0,0,1080,1350)
  const grad=ctx.createLinearGradient(120,80,950,1240);grad.addColorStop(0,t.accent+'55');grad.addColorStop(1,t.bg);ctx.fillStyle=grad;ctx.fillRect(0,0,1080,1350)
  ctx.fillStyle=t.soft;ctx.beginPath();roundRect(ctx,72,80,936,1190,42);ctx.fill()
  ctx.fillStyle=t.accent;ctx.beginPath();roundRect(ctx,102,112,126,38,19);ctx.fill()
  ctx.fillStyle=t.bg;ctx.font='700 18px system-ui';ctx.fillText('CODACARD',126,138)
  ctx.fillStyle=t.fg;ctx.font='800 42px system-ui';ctx.fillText('CodaVybes',102,225)
  ctx.globalAlpha=.66;ctx.font='600 22px system-ui';ctx.fillText('Powered by CodaBite',102,262);ctx.globalAlpha=1
  const user=safeText(item.display_name||item.username||'CodaVybes User');const handle=item.username?`@${item.username}`:'@codavybes'
  ctx.font='800 34px system-ui';ctx.fillText(user,102,368);ctx.globalAlpha=.65;ctx.font='500 22px system-ui';ctx.fillText(handle,102,408);ctx.globalAlpha=1
  ctx.font='800 54px system-ui';const lines=wrap(ctx,item.content_text||'',800).slice(0,7);let y=535;for(const line of lines){ctx.fillText(line,102,y);y+=68}
  ctx.fillStyle=t.accent;ctx.font='800 27px system-ui';ctx.fillText(`+${item.aura_count||0} Aura`,102,1080);ctx.fillStyle=t.fg;ctx.globalAlpha=.7;ctx.font='600 22px system-ui';ctx.fillText(`${item.unique_givers||0} people backed this · ${item.author_rank?.name||'NEW VIBE'}`,102,1124);ctx.globalAlpha=1
  ctx.fillStyle=t.fg;ctx.font='700 19px system-ui';ctx.fillText('codavybes.app  •  moments worth sharing',102,1214)
  return await new Promise(resolve=>canvas.toBlob(resolve,'image/png',0.94))
}

export default function ShareMomentModal({item,onClose}){
  const [theme,setTheme]=useState('midnight');const [notice,setNotice]=useState('');const [busy,setBusy]=useState(false)
  const url=useMemo(()=>`${window.location.origin}/moments/${item.target_id}`,[item.target_id])
  const caption=useMemo(()=>`${item.display_name||item.username||'Someone'} on CodaVybes: “${safeText(item.content_text).slice(0,220)}”`,[item])
  const log=(platform)=>recordMomentShare(item.target_id,platform).catch(()=>{})
  const download=async(platform='download')=>{setBusy(true);try{const blob=await makeCardBlob(item,theme);const href=URL.createObjectURL(blob);const a=document.createElement('a');a.href=href;a.download=`codavybes-${item.target_id.slice(0,8)}.png`;a.click();setTimeout(()=>URL.revokeObjectURL(href),1000);await log(platform);setNotice('CodaCard saved to your device.')}finally{setBusy(false)}}
  const native=async(platform='native')=>{setBusy(true);try{const blob=await makeCardBlob(item,theme);const file=new File([blob],'CodaCard.png',{type:'image/png'});if(navigator.canShare?.({files:[file]})&&navigator.share){await navigator.share({title:'CodaVybes',text:caption,url,files:[file]});await log(platform);setNotice('Shared from CodaVybes.');return}if(navigator.share){await navigator.share({title:'CodaVybes',text:caption,url});await log(platform);return}await navigator.clipboard.writeText(`${caption}\n${url}`);await download(platform);setNotice('Caption copied and CodaCard downloaded.')}catch(e){if(e?.name!=='AbortError')setNotice('Share cancelled or unavailable on this device.')}finally{setBusy(false)}}
  const direct=(platform,shareUrl)=>{window.open(shareUrl,'_blank','noopener,noreferrer');log(platform)}
  const copy=async()=>{await navigator.clipboard.writeText(`${caption}\n${url}`);await log('copy');setNotice('Caption + link copied.')}
  return <div className="share-modal-backdrop" onMouseDown={(e)=>e.target===e.currentTarget&&onClose()}><section className="share-modal surface" role="dialog" aria-modal="true">
    <header><div><p className="eyebrow"><Sparkles size={13}/> CODACARD</p><h2>Make the share look expensive.</h2><span>Your Aura, rank and moment become a branded social card.</span></div><button className="icon-btn" onClick={onClose}><X size={19}/></button></header>
    <div className={`share-preview share-preview--${theme}`}><div className="share-preview__brand"><b>CV</b><span><strong>CodaVybes</strong><small>Powered by CodaBite</small></span></div><div className="share-preview__copy"><small>@{item.username||'codavybes'}</small><h3>{item.content_text}</h3></div><footer><strong>+{item.aura_count||0} Aura</strong><span>{item.author_rank?.name||'NEW VIBE'}</span></footer></div>
    <div className="share-theme-row">{Object.entries(THEMES).map(([key,v])=><button key={key} className={theme===key?'is-active':''} onClick={()=>setTheme(key)}><i style={{background:v.bg,borderColor:v.accent}}/><span>{v.label}</span>{theme===key&&<Check size={13}/>}</button>)}</div>
    <div className="share-platform-grid">
      <button onClick={()=>native('instagram')}><InstagramGlyph size={20}/><span>Instagram</span></button>
      <button onClick={()=>native('tiktok')}><b className="share-letter">TT</b><span>TikTok</span></button>
      <button onClick={()=>direct('facebook',`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`)}><b className="share-letter">f</b><span>Facebook</span></button>
      <button onClick={()=>native('youtube')}><b className="share-letter">YT</b><span>YouTube Community</span></button>
      <button onClick={()=>direct('x',`https://twitter.com/intent/tweet?text=${encodeURIComponent(caption)}&url=${encodeURIComponent(url)}`)}><b className="share-letter">X</b><span>X</span></button>
      <button onClick={()=>direct('linkedin',`https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(url)}`)}><LinkedInGlyph size={20}/><span>LinkedIn</span></button>
    </div>
    <div className="share-vip-actions"><button className="btn btn--primary" onClick={()=>native('native')} disabled={busy}><Share2 size={17}/> Share CodaCard</button><button className="btn btn--outline" onClick={()=>download()} disabled={busy}><Download size={17}/> Download</button><button className="icon-btn" onClick={copy} title="Copy caption"><Copy size={17}/></button></div>
    <div className="share-vip-note"><Sparkles size={14}/><span><strong>VIP detail:</strong> CodaCard automatically carries the current Aura + rank without exposing private chat or account data.</span></div>
    {notice&&<div className="share-notice">{notice}</div>}
    <small className="share-platform-note"><ExternalLink size={12}/> Instagram, TikTok and YouTube use the device share sheet when available; desktop falls back to a downloadable card + copied caption.</small>
  </section></div>
}
