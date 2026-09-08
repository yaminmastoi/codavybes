import { Cookie, ShieldCheck, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { notifyAnalyticsConsent } from '../services/analyticsService'

const KEY='codavybes-consent-v1'
export default function ConsentBanner(){
  const [open,setOpen]=useState(false)
  useEffect(()=>{const sync=()=>{try{setOpen(!localStorage.getItem(KEY))}catch{setOpen(true)}};sync();window.addEventListener('codavybes:consent-reset',sync);return()=>window.removeEventListener('codavybes:consent-reset',sync)},[])
  const save=(analytics)=>{try{localStorage.setItem(KEY,JSON.stringify({essential:true,analytics,at:new Date().toISOString()}))}catch{};notifyAnalyticsConsent();setOpen(false)}
  if(!open)return null
  return <aside className="consent-banner surface" role="dialog" aria-label="Privacy and cookies">
    <button className="consent-close" onClick={()=>save(false)} aria-label="Use essential only"><X size={16}/></button>
    <div className="consent-icon"><Cookie size={20}/></div>
    <div className="consent-copy"><strong>Privacy, without the fine-print ambush.</strong><p>CodaVybes uses essential storage for login, security and preferences. Optional analytics can help improve the product. Read our <Link to="/privacy">Privacy</Link>, <Link to="/cookies">Cookies</Link>, <Link to="/security">Security</Link> and <Link to="/terms">Terms</Link>.</p><span><ShieldCheck size={13}/> Your chats stay private to their participants; public posts are public.</span></div>
    <div className="consent-actions"><button className="btn btn--outline" onClick={()=>save(false)}>Essential only</button><button className="btn btn--primary" onClick={()=>save(true)}>Accept all</button></div>
  </aside>
}
