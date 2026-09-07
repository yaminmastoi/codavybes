import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Check, Coins, Crown, LoaderCircle, ShieldCheck, Sparkles } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { subscribeVybePlus } from '../services/commerceService'
import { useCommerce } from '../context/CommerceContext'
import { PageSkeleton } from '../components/Loaders'

const PERKS=['Premium profile themes','Exclusive Aura visual effects','Premium avatar frames','Room customization','Early cosmetic drops','Ad-free premium surface when ads launch']
export default function VybePlus(){
 const navigate=useNavigate();const{summary,refreshCommerce,topupsEnabled,loading}=useCommerce();const[busy,setBusy]=useState(false);const[notice,setNotice]=useState('');const[subLoading,setSubLoading]=useState(false)
 const sub=summary?.subscription;const price=summary?.config?.vybe_plus_price_coins??499;const balance=summary?.wallet?.coin_balance??0
 const join=async()=>{try{setBusy(true);setNotice('');const r=await subscribeVybePlus();if(r.insufficient_balance){setNotice(topupsEnabled?`You need ${r.needed} more VC. Open Wallet to top up.`:`You need ${r.needed} more VC.`);return}setNotice('CodaVybes+ activated.');setSubLoading(true);await refreshCommerce()}catch(e){setNotice(e.message)}finally{setBusy(false);setSubLoading(false)}}
 return <div className="page plus-page"><header className="page-head page-head--back"><button className="icon-btn surface" onClick={()=>navigate(-1)}><ArrowLeft size={20}/></button><div><p className="eyebrow">PREMIUM MEMBERSHIP</p><h1>CodaVybes+</h1></div><Link className="coin-head-pill" to="/wallet"><Coins size={15}/>{Number(balance).toLocaleString()}</Link></header>
 {loading||subLoading?<PageSkeleton variant="compact" count={3}/>:<>
 <section className="plus-hero"><Crown size={42}/><span>CodaVybes+</span><h2>More control over how CodaVybes feels.</h2><p>Premium visual identity and customization. Aura, ranks and discovery reputation remain earned-only.</p></section>
 {sub&&<div className="plus-active surface"><ShieldCheck size={20}/><div><strong>CodaVybes+ ACTIVE</strong><span>Until {new Date(sub.ends_at).toLocaleDateString()}</span></div></div>}
 {notice&&<div className="commerce-notice"><Sparkles size={17}/><span>{notice}</span>{topupsEnabled&&notice.includes('Wallet')&&<Link to="/wallet">Wallet</Link>}</div>}
 <section className="plus-perks surface"><p className="eyebrow">MEMBERSHIP INCLUDES</p>{PERKS.map(x=><div key={x}><Check size={16}/><span>{x}</span></div>)}</section>
 <section className="plus-price surface"><div><small>30 DAYS</small><strong><Coins size={20}/>{price} VC</strong><span>{sub?'Extend your membership by 30 days.':'One membership period.'}</span></div><button className="btn btn--primary" onClick={join} disabled={busy}>{busy?<LoaderCircle className="spin" size={17}/>:<Crown size={17}/>} {sub?'Extend CodaVybes+':'Get CodaVybes+'}</button></section>
 <p className="plus-footnote"><Sparkles size={14}/> Reputation and competitive systems remain earned.</p></>}</div>
}
