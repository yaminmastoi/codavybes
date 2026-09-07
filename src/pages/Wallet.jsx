import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Coins, CreditCard, History, LoaderCircle, ShieldCheck, ShoppingBag, WalletCards } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { createTopupCheckout, getTopupPackages, getWalletLedger } from '../services/commerceService'
import { useCommerce } from '../context/CommerceContext'
import { PageSkeleton } from '../components/Loaders'

function money(cents, currency='USD') { try { return new Intl.NumberFormat(undefined,{style:'currency',currency}).format(Number(cents||0)/100) } catch { return `${currency} ${(Number(cents||0)/100).toFixed(2)}` } }

export default function Wallet() {
  const navigate = useNavigate()
  const { summary, loading: commerceLoading, refreshCommerce, topupsEnabled, shopEnabled } = useCommerce()
  const [packs,setPacks]=useState([]); const [ledger,setLedger]=useState([]); const [busy,setBusy]=useState(null); const [notice,setNotice]=useState(''); const [loading,setLoading]=useState(true)
  const load=useCallback(async()=>{setLoading(true);try{const [p,l]=await Promise.all([topupsEnabled?getTopupPackages():Promise.resolve([]),getWalletLedger()]);setPacks(p);setLedger(l);await refreshCommerce()}finally{setLoading(false)}},[topupsEnabled,refreshCommerce])
  useEffect(()=>{load().catch(e=>{setNotice(e.message);setLoading(false)})},[load])
  const topup=async(id)=>{try{setBusy(id);setNotice('');const result=await createTopupCheckout(id);if(!result.checkout_ready){setNotice(result.message);return}setNotice(`Checkout created for ${result.provider}. Continue through the configured secure payment provider.`)}catch(e){setNotice(e.message)}finally{setBusy(null)}}
  const balance=summary?.wallet?.coin_balance??0
  return <div className="page wallet-page">
    <header className="page-head page-head--back"><button className="icon-btn surface" onClick={()=>navigate(-1)}><ArrowLeft size={20}/></button><div><p className="eyebrow">WALLET</p><h1>CodaCoins</h1></div>{shopEnabled ? <Link className="icon-btn surface" to="/shop" aria-label="Open CodaVybes Shop"><ShoppingBag size={19}/></Link> : <span className="head-spacer"/>}</header>
    {commerceLoading || loading ? <PageSkeleton variant="compact" count={3}/> : <>
      <section className="wallet-hero"><span>AVAILABLE BALANCE</span><strong><Coins size={30}/> {Number(balance).toLocaleString()}</strong><p>CodaCoins</p><small>Aura remains earned reputation and is never sold.</small></section>
      {notice&&<div className="commerce-notice"><ShieldCheck size={17}/><span>{notice}</span></div>}
      {topupsEnabled && <>
        <div className="section-title"><div><p className="eyebrow">TOP UP</p><h2>Choose a pack</h2></div><CreditCard size={20}/></div>
        <section className="topup-grid">{packs.map(p=><button className="topup-card surface" key={p.id} onClick={()=>topup(p.id)} disabled={busy===p.id}><span>{p.name}</span><strong>{Number(p.coins+p.bonus_coins).toLocaleString()} <small>VC</small></strong>{p.bonus_coins>0&&<b>+{p.bonus_coins} bonus</b>}<em>{busy===p.id?<LoaderCircle className="spin" size={16}/>:money(p.price_cents,p.currency)}</em></button>)}</section>
        <div className="wallet-provider-note surface"><CreditCard size={19}/><div><strong>Secure payment rail</strong><p>Coins are granted only after a trusted server confirms payment. The browser cannot self-credit a wallet.</p></div></div>
      </>}
      {!topupsEnabled && <div className="feature-off-note surface"><WalletCards size={19}/><div><strong>Top-ups are currently unavailable</strong><span>Your balance and ledger remain available. This section will return automatically when HQ enables top-ups.</span></div></div>}
      <div className="section-title"><div><p className="eyebrow">LEDGER</p><h2>Recent activity</h2></div><History size={20}/></div>
      <section className="wallet-ledger surface">{ledger.map(x=><div key={x.id}><span><strong>{x.note||x.entry_type}</strong><small>{new Date(x.created_at).toLocaleString()}</small></span><b className={x.amount>0?'positive':'negative'}>{x.amount>0?'+':''}{x.amount} VC</b></div>)}{!ledger.length&&<p className="muted wallet-empty-ledger">No wallet activity yet.</p>}</section>
    </>}
  </div>
}
