import { useCallback, useEffect, useMemo, useState } from 'react'
import { ArrowLeft, Check, Coins, Crown, Frame, Gamepad2, Gem, Layers3, LoaderCircle, Orbit, ShoppingBag, Sparkles } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { buyShopItem, equipShopItem, getShopItems } from '../services/commerceService'
import { useCommerce } from '../context/CommerceContext'
import { PageSkeleton } from '../components/Loaders'

const ICONS={aura_effect:Orbit,profile:Layers3,room_theme:Gamepad2,avatar_frame:Frame,game_pack:Gem}
export default function Shop(){
 const navigate=useNavigate();const{summary,refreshCommerce,plusEnabled,topupsEnabled}=useCommerce();const[items,setItems]=useState([]);const[cat,setCat]=useState('all');const[busy,setBusy]=useState(null);const[notice,setNotice]=useState('');const[loading,setLoading]=useState(true)
 const load=useCallback(async()=>{setLoading(true);try{setItems(await getShopItems());await refreshCommerce()}finally{setLoading(false)}},[refreshCommerce]);useEffect(()=>{load().catch(e=>{setNotice(e.message);setLoading(false)})},[load])
 const owned=new Set((summary?.owned||[]).map(x=>x.item_id));const equipped=new Set((summary?.equipped||[]).map(x=>x.item_id));const visible=useMemo(()=>cat==='all'?items:items.filter(x=>x.category===cat),[items,cat])
 const action=async(item)=>{try{setBusy(item.id);setNotice('');if(owned.has(item.id)){await equipShopItem(item.id);setNotice(`${item.name} equipped.`)}else{const r=await buyShopItem(item.id);if(r.insufficient_balance){setNotice(topupsEnabled?`You need ${r.needed} more VC. Open your wallet to top up.`:`You need ${r.needed} more VC.`);return}setNotice(`${item.name} is now in your collection.`)}await load()}catch(e){setNotice(e.message)}finally{setBusy(null)}}
 const balance=summary?.wallet?.coin_balance??0
 return <div className="page shop-page"><header className="page-head page-head--back"><button className="icon-btn surface" onClick={()=>navigate(-1)}><ArrowLeft size={20}/></button><div><p className="eyebrow">COLLECTION</p><h1>CodaVybes Shop</h1></div><Link className="coin-head-pill" to="/wallet"><Coins size={15}/>{Number(balance).toLocaleString()}</Link></header>
 <section className="shop-hero"><div><span>CURATED DROP</span><h2>Designed for your identity.</h2><p>Premium expression around earned Aura — never a shortcut to reputation.</p></div><Sparkles size={32}/></section>
 {plusEnabled&&<div className="shop-plus-banner surface"><Crown size={20}/><div><strong>CodaVybes+</strong><span>Premium themes, effects and customization.</span></div><Link to="/vybe-plus">View</Link></div>}
 {notice&&<div className="commerce-notice"><ShoppingBag size={17}/><span>{notice}</span>{topupsEnabled&&notice.includes('wallet')&&<Link to="/wallet">Wallet</Link>}</div>}
 <div className="filter-row shop-filters">{['all','aura_effect','avatar_frame','profile','room_theme','game_pack'].map(x=><button key={x} className={cat===x?'is-active':''} onClick={()=>setCat(x)}>{x==='all'?'All':x.replaceAll('_',' ')}</button>)}</div>
 {loading?<PageSkeleton variant="compact" count={4}/>:<section className="shop-grid">{visible.map(item=>{const Icon=ICONS[item.category]||Gem;return <article className={`shop-item surface ${equipped.has(item.id)?'is-equipped':''}`} key={item.id}><div className="shop-item__art"><span><Icon size={34} strokeWidth={1.5}/></span>{equipped.has(item.id)&&<b><Check size={13}/> Equipped</b>}</div><small>{item.category.replaceAll('_',' ')}</small><h3>{item.name}</h3><p>{item.description}</p><div className="shop-item__foot"><strong><Coins size={14}/>{item.price_coins} VC</strong><button onClick={()=>action(item)} disabled={busy===item.id}>{busy===item.id?<LoaderCircle className="spin" size={15}/>:equipped.has(item.id)?'Equipped':owned.has(item.id)?'Equip':'Buy'}</button></div></article>})}</section>}
 {!loading&&!visible.length&&<div className="feed-empty surface"><ShoppingBag size={28}/><h3>No items in this collection.</h3></div>}</div>
}
