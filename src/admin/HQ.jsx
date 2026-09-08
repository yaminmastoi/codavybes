import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  Activity, BadgeCheck, BadgeDollarSign, Ban, BarChart3, BellRing, ChevronRight, CircleDollarSign, Clock3, Crown, Flag, Gamepad2,
  Gauge, Globe2, Image, LayoutDashboard, LockKeyhole, LogOut, MapPin, Megaphone, MessageCircle, MonitorSmartphone, MousePointerClick, Pin, Radio, RefreshCw, Search,
  Settings2, Shield, ShieldAlert, SlidersHorizontal, Sparkles, Trash2, UserCog, Users, X, Zap,
} from 'lucide-react'
import Logo from '../components/Logo'
import { signOut } from '../services/authService'
import { adminService } from '../services/adminService'
import RankMark from '../components/RankMark'
import VerifiedBadge from '../components/VerifiedBadge'
import InterestIcon, { INTEREST_ICON_KEYS } from '../components/InterestIcon'

const NAV = [
  ['overview', LayoutDashboard, 'Overview'],
  ['analytics', BarChart3, 'Analytics'],
  ['users', Users, 'Users'],
  ['verification', BadgeCheck, 'Verification'],
  ['aura', Zap, 'Aura & FYP'],
  ['product', SlidersHorizontal, 'Product Control'],
  ['moderation', ShieldAlert, 'Moderation'],
  ['money', CircleDollarSign, 'Monetization'],
  ['promotions', BadgeDollarSign, 'Promotions'],
  ['content', Megaphone, 'Content'],
  ['system', Settings2, 'System'],
]

const CONFIG_FIELDS = {
  app: [['min_age','Minimum age'],['username_change_days','Username cooldown (days)'],['old_username_reserve_days','Old username reserve'],['min_interests','Min interests']],
  aura: [['daily_giver_limit','Daily giver limit'],['daily_pair_limit','Daily pair limit'],['daily_pair_combined_limit','Pair combined limit'],['new_account_hours','New-account window'],['new_account_daily_limit','New-account Aura/day'],['aura_moment_threshold','Aura Moment threshold'],['weight_velocity','Velocity weight'],['weight_unique_givers','Unique giver weight'],['weight_total_aura','Total Aura weight'],['weight_freshness','Freshness weight']],
  chat: [['max_message_chars','Max message chars'],['max_group_members','Max group members'],['message_per_minute_limit','Messages/minute'],['new_account_message_per_minute_limit','New-user messages/min'],['direct_chat_create_hour_limit','DM creates/hour'],['group_create_day_limit','Groups/day']],
  rooms: [['max_players','Max players'],['min_players','Min players'],['room_expiry_minutes','Room expiry (min)'],['round_seconds','Round seconds'],['rounds_per_game','Rounds/game'],['winner_aura','Winner Aura'],['mvp_aura','MVP Aura'],['winner_xp','Winner XP'],['participation_xp','Participation XP']],
  social: [['meet_session_minutes','Meet session (min)'],['meet_request_day_limit','Meet requests/day'],['meet_message_per_minute_limit','Meet messages/min'],['meet_max_messages_per_session','Meet message cap'],['bond_message_points','Bond points/message'],['bond_message_daily_cap','Message bond cap'],['bond_aura_points','Bond points/Aura'],['bond_aura_daily_cap','Aura bond cap'],['bond_shared_game_points','Shared game points']],
}

function fmt(n) { return Number(n || 0).toLocaleString() }
function dt(value) { if (!value) return '—'; return new Date(value).toLocaleString() }
function initials(name='CodaVybes') { return name.trim().split(/\s+/).slice(0,2).map(v=>v[0]?.toUpperCase()).join('') || 'V' }

function Toast({ message, tone='ok', onClose }) {
  if (!message) return null
  return <div className={`hq-toast ${tone==='error'?'is-error':''}`}><span>{message}</span><button onClick={onClose}><X size={15}/></button></div>
}

function Stat({ icon: Icon, label, value, note }) {
  return <article className="hq-stat"><div className="hq-stat__icon"><Icon size={18}/></div><span>{label}</span><strong>{value}</strong>{note && <small>{note}</small>}</article>
}

function SectionHead({ eyebrow, title, action }) {
  return <div className="hq-section-head"><div><span>{eyebrow}</span><h2>{title}</h2></div>{action}</div>
}

function ConfigCard({ section, data, onSave, disabled }) {
  const [draft, setDraft] = useState(data || {})
  useEffect(()=>setDraft(data || {}),[data])
  return <article className="hq-card hq-config-card">
    <div className="hq-card-title"><div><span>{section.toUpperCase()}</span><h3>{section==='aura'?'Aura + FYP Engine':section==='rooms'?'Rooms + Game Rewards':section==='social'?'Meet + Bonds':section==='chat'?'Chat Limits':'Account Rules'}</h3></div><Gauge size={19}/></div>
    <div className="hq-field-grid">{CONFIG_FIELDS[section].map(([key,label])=><label key={key}><span>{label}</span><input type="number" step={key.startsWith('weight_')?'0.01':'1'} value={draft[key] ?? ''} onChange={e=>setDraft(v=>({...v,[key]:e.target.value}))}/></label>)}</div>
    <button className="hq-btn hq-btn--gold" disabled={disabled} onClick={()=>onSave(section,Object.fromEntries(CONFIG_FIELDS[section].map(([key])=>[key,Number(draft[key])]))) }>Save {section}</button>
  </article>
}

function UserDrawer({ id, permissions, onClose, onChanged, notify }) {
  const [user,setUser]=useState(null); const [busy,setBusy]=useState(false)
  const [reason,setReason]=useState('Admin support action'); const [username,setUsername]=useState(''); const [dob,setDob]=useState(''); const [aura,setAura]=useState(0); const [coins,setCoins]=useState(0)
  const load=useCallback(()=>adminService.user(id).then(v=>{setUser(v);setUsername(v.username||'');setDob(v.birth_date||'')}),[id])
  useEffect(()=>{load().catch(e=>notify(e.message,'error'))},[load,notify])
  const run=async(fn,msg)=>{try{setBusy(true);await fn();await load();onChanged?.();notify(msg)}catch(e){notify(e.message,'error')}finally{setBusy(false)}}
  if(!user)return <div className="hq-drawer-backdrop"><aside className="hq-drawer"><div className="hq-loader"/></aside></div>
  return <div className="hq-drawer-backdrop" onMouseDown={e=>e.target===e.currentTarget&&onClose()}><aside className="hq-drawer">
    <button className="hq-close" onClick={onClose}><X/></button>
    <div className="hq-user-hero"><div className="hq-avatar">{initials(user.display_name||user.username)}</div><div><span>@{user.username}</span><h2 className="hq-verified-title">{user.display_name||user.username}<VerifiedBadge verified={user.is_verified} size={20}/></h2><p>{user.email}</p></div></div>
    <div className="hq-user-badges"><b><Zap size={13}/> +{fmt(user.aura_total)}</b><b><RankMark rank={user.rank} size={13}/></b><b className={`status-${user.account_status}`}>{user.account_status}</b></div>
    <div className="hq-detail-grid"><div><span>Age</span><strong>{user.age ?? '—'} · {user.age_band || '—'}</strong></div><div><span>DOB</span><strong>{user.birth_date || 'restricted'}</strong></div><div><span>Reports</span><strong>{fmt(user.reports)}</strong></div><div><span>Messages</span><strong>{fmt(user.messages)}</strong></div><div><span>Connections</span><strong>{fmt(user.connections)}</strong></div><div><span>Room wins</span><strong>{fmt(user.room_wins)}</strong></div><div><span>CodaCoins</span><strong>{fmt(user.wallet_balance)} VC</strong></div></div>
    <label className="hq-wide-field"><span>Audit reason</span><input value={reason} onChange={e=>setReason(e.target.value)}/></label>
    {permissions.can_manage_users && <div className="hq-action-block"><h3>Account control</h3><div className="hq-actions-3"><button disabled={busy} onClick={()=>run(()=>adminService.setUserStatus(id,'active',reason),'Account restored')}>Activate</button><button disabled={busy} className="warn" onClick={()=>run(()=>adminService.setUserStatus(id,'suspended',reason,new Date(Date.now()+86400000).toISOString()),'Suspended for 24h')}>Suspend 24h</button><button disabled={busy} className="danger" onClick={()=>run(()=>adminService.setUserStatus(id,'banned',reason),'User banned in CodaVybes')}>Ban</button></div><div className="hq-auth-actions"><button disabled={busy} className="danger" onClick={()=>run(()=>adminService.authAction(id,'ban','876000h'),'Supabase Auth ban synced')}>Sync Auth ban</button><button disabled={busy} onClick={()=>run(()=>adminService.authAction(id,'unban'),'Supabase Auth ban lifted')}>Lift Auth ban</button></div><small>Auth sync uses the optional HQ Edge Function; your service-role key never enters the browser.</small></div>}
    {permissions.can_manage_config && <>
      <div className="hq-action-block"><h3>Identity</h3><div className="hq-inline-edit"><input value={username} onChange={e=>setUsername(e.target.value)}/><button disabled={busy} onClick={()=>run(()=>adminService.changeUsername(id,username,reason),'Username changed')}>Change @</button></div><div className="hq-inline-edit"><input type="date" value={dob} onChange={e=>setDob(e.target.value)}/><button disabled={busy||!dob} onClick={()=>run(()=>adminService.correctDob(id,dob,reason),'DOB corrected')}>Correct DOB</button></div></div>
      <div className="hq-action-block"><h3>Verification</h3><div className={`hq-user-verified-state ${user.is_verified?'is-verified':''}`}>{user.is_verified?<><VerifiedBadge verified size={17}/><span>Blue tick active</span></>:user.verification_eligible?<><Shield size={17}/><span>Certified · eligible</span></>:<><Shield size={17}/><span>Locked until Certified</span></>}</div><button className="hq-btn" disabled={busy||(!user.is_verified&&!user.verification_eligible)} onClick={()=>run(()=>adminService.setUserVerification(id,!user.is_verified,reason),user.is_verified?'Verification removed':'User verified')}>{user.is_verified?'Remove blue tick':'Grant blue tick'}</button><small>Blue tick can only be granted to Certified-or-higher users. Every change is audited.</small></div>
      <div className="hq-action-block"><h3>Aura economy</h3><div className="hq-inline-edit"><input type="number" value={aura} onChange={e=>setAura(e.target.value)}/><button disabled={busy||Number(aura)===0} onClick={()=>run(()=>adminService.adjustAura(id,aura,reason),'Aura adjusted')}>Apply Aura</button></div><small>HQ adjustments append an audit ledger event. Aura is never silently overwritten.</small></div><div className="hq-action-block"><h3>CodaCoins</h3><div className="hq-inline-edit"><input type="number" value={coins} onChange={e=>setCoins(e.target.value)}/><button disabled={busy||Number(coins)===0} onClick={()=>run(()=>adminService.adjustCoins(id,coins,reason),'CodaCoins adjusted')}>Apply Coins</button></div><small>Coins are spendable commerce balance. They never affect Aura or rank.</small></div>
    </>}
  </aside></div>
}

export default function HQ() {
  const [tab,setTab]=useState('overview'); const [session,setSession]=useState(null); const [dashboard,setDashboard]=useState(null); const [controls,setControls]=useState(null)
  const [users,setUsers]=useState([]); const [query,setQuery]=useState(''); const [userStatus,setUserStatus]=useState('all'); const [selectedUser,setSelectedUser]=useState(null)
  const [reports,setReports]=useState([]); const [verificationRequests,setVerificationRequests]=useState([]); const [analytics,setAnalytics]=useState(null); const [audit,setAudit]=useState([]); const [announcements,setAnnouncements]=useState([]); const [questions,setQuestions]=useState([]); const [admins,setAdmins]=useState([]); const [shopItems,setShopItems]=useState([]); const [topupPackages,setTopupPackages]=useState([]); const [promotions,setPromotions]=useState([]); const [platformPosts,setPlatformPosts]=useState([])
  const [busy,setBusy]=useState(false); const [toast,setToast]=useState({message:'',tone:'ok'})
  const notify=useCallback((message,tone='ok')=>setToast({message,tone}),[])

  const loadCore=useCallback(async()=>{ const [s,d,c]=await Promise.all([adminService.session(),adminService.dashboard(),adminService.controls()]); setSession(s);setDashboard(d);setControls(c) },[])
  const loadAnalytics=useCallback(async()=>setAnalytics(await adminService.analytics()),[])
  const loadUsers=useCallback(async()=>setUsers(await adminService.users(query,userStatus,50,0)),[query,userStatus])
  const loadModeration=useCallback(async()=>setReports(await adminService.reports('open',80)),[])
  const loadVerification=useCallback(async()=>setVerificationRequests(await adminService.verificationRequests('pending',100)),[])
  const loadContent=useCallback(async()=>{const [a,q,p]=await Promise.all([adminService.announcements(),adminService.questions('all'),adminService.platformPosts()]);setAnnouncements(a||[]);setQuestions(q||[]);setPlatformPosts(p||[])},[])
  const loadMoney=useCallback(async()=>{const [items,packs]=await Promise.all([adminService.shopItems(),adminService.topupPackages()]);setShopItems(items||[]);setTopupPackages(packs||[])},[])
  const loadPromotions=useCallback(async()=>setPromotions(await adminService.promotions()||[]),[])
  const loadSystem=useCallback(async()=>{const a=await adminService.audit(120);setAudit(a||[]); if(session?.can_manage_admins){try{setAdmins(await adminService.admins())}catch{setAdmins([])}}},[session?.can_manage_admins])

  useEffect(()=>{loadCore().catch(e=>notify(e.message,'error'))},[loadCore,notify])
  useEffect(()=>{if(tab==='analytics')loadAnalytics().catch(e=>notify(e.message,'error'));if(tab==='users')loadUsers().catch(e=>notify(e.message,'error'));if(tab==='verification')loadVerification().catch(e=>notify(e.message,'error'));if(tab==='moderation')loadModeration().catch(e=>notify(e.message,'error'));if(tab==='money')loadMoney().catch(e=>notify(e.message,'error'));if(tab==='promotions')loadPromotions().catch(e=>notify(e.message,'error'));if(tab==='content')loadContent().catch(e=>notify(e.message,'error'));if(tab==='system')loadSystem().catch(e=>notify(e.message,'error'))},[tab,loadAnalytics,loadUsers,loadVerification,loadModeration,loadMoney,loadPromotions,loadContent,loadSystem,notify])

  const refresh=async()=>{try{setBusy(true);await loadCore(); if(tab==='analytics')await loadAnalytics(); if(tab==='users')await loadUsers(); if(tab==='verification')await loadVerification(); if(tab==='moderation')await loadModeration(); if(tab==='money')await loadMoney(); if(tab==='promotions')await loadPromotions(); if(tab==='content')await loadContent(); if(tab==='system')await loadSystem();notify('HQ refreshed')}catch(e){notify(e.message,'error')}finally{setBusy(false)}}
  const saveConfig=async(section,patch)=>{try{setBusy(true);await adminService.updateConfig(section,patch);await loadCore();notify(`${section} controls saved`)}catch(e){notify(e.message,'error')}finally{setBusy(false)}}
  const saveRank=async(rank)=>{try{setBusy(true);await adminService.upsertRank(rank);await loadCore();notify('Rank saved')}catch(e){notify(e.message,'error')}finally{setBusy(false)}}
  const setFlag=async(flag)=>{try{setBusy(true);await adminService.setFlag(flag.key,!flag.enabled,flag.payload);await loadCore();notify(`${flag.label} ${!flag.enabled?'enabled':'disabled'}`)}catch(e){notify(e.message,'error')}finally{setBusy(false)}}

  const pageTitle=useMemo(()=>NAV.find(([k])=>k===tab)?.[2]||'CodaVybes HQ',[tab])
  if(!session||!dashboard||!controls)return <div className="hq-gate"><div className="hq-loader"/><strong>Loading control plane…</strong></div>

  return <div className="hq-shell">
    <aside className="hq-sidebar"><div className="hq-brand"><Logo/><span>CONTROL PLANE</span></div><nav>{NAV.map(([key,Icon,label])=><button key={key} className={tab===key?'is-active':''} onClick={()=>setTab(key)}><Icon size={18}/><span>{label}</span></button>)}</nav><div className="hq-side-foot"><div><Shield size={16}/><span>{session.role.replace('_',' ')}</span></div><Link to="/home">Back to CodaVybes</Link><button onClick={signOut}><LogOut size={16}/>Sign out</button></div></aside>
    <main className="hq-main"><header className="hq-topbar"><div><span>CodaVybes HQ / {pageTitle}</span><h1>{pageTitle}</h1></div><div className="hq-top-actions"><button className="hq-icon-btn" disabled={busy} onClick={refresh}><RefreshCw size={17}/></button><div className="hq-admin-pill"><Crown size={16}/><span>{session.role.replace('_',' ')}</span></div></div></header>

      {tab==='overview' && <div className="hq-view"><div className="hq-kpis"><Stat icon={Users} label="Total users" value={fmt(dashboard.users_total)} note={`+${fmt(dashboard.users_24h)} / 24h`}/><Stat icon={MessageCircle} label="Messages / 24h" value={fmt(dashboard.messages_24h)}/><Stat icon={Zap} label="Aura / 24h" value={`+${fmt(dashboard.aura_24h)}`}/><Stat icon={Gamepad2} label="Rooms / 24h" value={fmt(dashboard.rooms_24h)} note={`${fmt(dashboard.games_24h)} games`}/><Stat icon={BadgeCheck} label="Connections" value={fmt(dashboard.connections_total)}/><Stat icon={ShieldAlert} label="Open reports" value={fmt(dashboard.pending_reports)} note={`${fmt(dashboard.suspended)} suspended`}/></div>
        <div className="hq-grid-2"><article className="hq-card"><SectionHead eyebrow="LIVE PRODUCT" title="Feature switches"/><div className="hq-flag-list">{controls.flags.slice(0,7).map(f=><button key={f.key} className={`hq-flag ${f.enabled?'on':''}`} disabled={!session.can_manage_config||busy} onClick={()=>setFlag(f)}><div><strong>{f.label}</strong><span>{f.description}</span></div><i/></button>)}</div></article><article className="hq-card hq-command-card"><SectionHead eyebrow="STATUS" title="CodaVybes at a glance"/><div className="hq-command-row"><span>Onboarded profiles</span><strong>{fmt(dashboard.onboarded)}</strong></div><div className="hq-command-row"><span>Banned accounts</span><strong>{fmt(dashboard.banned)}</strong></div><div className="hq-command-row"><span>Meet requests / 24h</span><strong>{fmt(dashboard.meet_requests_24h)}</strong></div><div className="hq-command-row"><span>Active feature flags</span><strong>{fmt(dashboard.active_flags)}</strong></div><div className="hq-command-row"><span>Control snapshot</span><strong>{dt(dashboard.generated_at)}</strong></div></article></div></div>}

      {tab==='analytics' && <AnalyticsPanel data={analytics} canPrune={session.can_manage_config} onRefresh={loadAnalytics} notify={notify}/>}

      {tab==='users' && <div className="hq-view"><SectionHead eyebrow="ACCOUNT CONTROL" title="Users" action={<div className="hq-user-filters"><div className="hq-search"><Search size={16}/><input value={query} onChange={e=>setQuery(e.target.value)} onKeyDown={e=>e.key==='Enter'&&loadUsers()} placeholder="username, name or email"/></div><select value={userStatus} onChange={e=>setUserStatus(e.target.value)}><option value="all">All</option><option value="active">Active</option><option value="suspended">Suspended</option><option value="banned">Banned</option></select><button className="hq-btn" onClick={loadUsers}>Search</button></div>}/><div className="hq-table-wrap"><table className="hq-table"><thead><tr><th>User</th><th>Aura</th><th>Age data</th><th>Status</th><th>Reports</th><th>Joined</th><th/></tr></thead><tbody>{users.map(u=><tr key={u.user_id}><td><div className="hq-table-user"><div>{initials(u.display_name||u.username)}</div><span><strong>{u.display_name||u.username}</strong><small>@{u.username} · {u.email}</small></span></div></td><td><strong className="gold hq-aura-value"><Zap size={13}/> +{fmt(u.aura_total)}</strong><small>{u.rank?.name}</small></td><td>{u.age ?? '—'}<small>{u.age_band||'—'}</small></td><td><span className={`hq-status status-${u.account_status}`}>{u.account_status}</span></td><td>{fmt(u.report_count)}</td><td>{new Date(u.created_at).toLocaleDateString()}</td><td><button className="hq-row-open" onClick={()=>setSelectedUser(u.user_id)}><ChevronRight size={17}/></button></td></tr>)}</tbody></table></div></div>}

      {tab==='verification' && <VerificationPanel rows={verificationRequests} canEdit={session.can_manage_config} onRefresh={loadVerification} notify={notify} onOpenUser={setSelectedUser}/>}

      {tab==='aura' && <div className="hq-view"><SectionHead eyebrow="REPUTATION ECONOMY" title="Aura & For You"/><div className="hq-grid-2"><ConfigCard section="aura" data={controls.aura} onSave={saveConfig} disabled={!session.can_manage_config||busy}/><article className="hq-card"><div className="hq-card-title"><div><span>FYP LOGIC</span><h3>Current ranking recipe</h3></div><Sparkles size={19}/></div><div className="hq-weight-viz">{[['Velocity',controls.aura.weight_velocity],['Unique givers',controls.aura.weight_unique_givers],['Total Aura',controls.aura.weight_total_aura],['Freshness',controls.aura.weight_freshness]].map(([l,v])=><div key={l}><span>{l}</span><b>{v}</b><i><em style={{width:`${Math.min(100,Number(v)*100)}%`}}/></i></div>)}</div><p className="hq-help">Every active public post is eligible for For You. These weights only influence ordering, while lifetime Aura continues to control prestige and rank.</p></article></div><SectionHead eyebrow="PRESTIGE" title="Aura ranks"/><div className="hq-rank-grid">{controls.ranks.map(rank=><RankEditor key={rank.id} rank={rank} disabled={!session.can_manage_config||busy} onSave={saveRank}/>)}</div></div>}

      {tab==='product' && <div className="hq-view"><SectionHead eyebrow="NO DEPLOY REQUIRED" title="Product control"/><div className="hq-grid-2"><ConfigCard section="app" data={controls.app} onSave={saveConfig} disabled={!session.can_manage_config||busy}/><ConfigCard section="chat" data={controls.chat} onSave={saveConfig} disabled={!session.can_manage_config||busy}/><ConfigCard section="rooms" data={controls.rooms} onSave={saveConfig} disabled={!session.can_manage_config||busy}/><ConfigCard section="social" data={controls.social} onSave={saveConfig} disabled={!session.can_manage_config||busy}/></div><SectionHead eyebrow="AGE-AWARE CONTROLS" title="Age bands (not used to separate Discover or chat)"/><div className="hq-band-grid">{controls.age_bands.map(b=><AgeBandEditor key={b.id} band={b} disabled={!session.can_manage_config||busy} onSaved={async draft=>{try{setBusy(true);await adminService.upsertAgeBand(draft);await loadCore();notify('Age band saved')}catch(e){notify(e.message,'error')}finally{setBusy(false)}}}/>)}</div><SectionHead eyebrow="DISCOVERY TAXONOMY" title="Interests"/><div className="hq-interest-grid">{controls.interests.map(i=><InterestEditor key={i.id} interest={i} disabled={!session.can_manage_config||busy} onSaved={async draft=>{try{setBusy(true);await adminService.upsertInterest(draft);await loadCore();notify('Interest saved')}catch(e){notify(e.message,'error')}finally{setBusy(false)}}}/>)}</div></div>}

      {tab==='moderation' && <div className="hq-view"><SectionHead eyebrow="TRUST & SAFETY" title="Moderation queue"/><div className="hq-report-list">{reports.length?reports.map(r=><article className="hq-card hq-report" key={r.report_id}><div className="hq-report-top"><span className="hq-status status-suspended">{r.reason.replaceAll('_',' ')}</span><time>{dt(r.created_at)}</time></div><h3>{r.reported_user?.display_name||r.reported_user?.username||'Unknown target'}</h3><p>{r.details||'No additional reporter note.'}</p>{r.message&&<blockquote>{r.message.body}</blockquote>}<div className="hq-report-meta">Reporter: @{r.reporter?.username||'unknown'} · Status: {r.status}</div><div className="hq-report-actions"><button onClick={async()=>{await adminService.updateReport(r.report_id,'reviewing','Opened in HQ');await loadModeration();notify('Report marked reviewing')}}>Reviewing</button><button className="ok" onClick={async()=>{await adminService.updateReport(r.report_id,'actioned','Action completed');await loadModeration();notify('Report actioned')}}>Actioned</button><button onClick={async()=>{await adminService.updateReport(r.report_id,'dismissed','Dismissed in HQ');await loadModeration();notify('Report dismissed')}}>Dismiss</button>{r.reported_user?.id&&<button className="danger" onClick={()=>setSelectedUser(r.reported_user.id)}>Open user</button>}</div></article>):<div className="hq-empty"><Shield size={28}/><h3>Queue clear</h3><p>No open reports right now.</p></div>}</div></div>}

      {tab==='money' && <MonetizationPanel config={controls.monetization} items={shopItems} packages={topupPackages} canEdit={session.can_manage_config} onSaveConfig={async patch=>{try{setBusy(true);await adminService.updateCommerce(patch,'Monetization update');await loadCore();await loadMoney();notify('Monetization settings saved')}catch(e){notify(e.message,'error')}finally{setBusy(false)}}} onRefresh={loadMoney} notify={notify}/>}

      {tab==='promotions' && <PromotionsPanel rows={promotions} adsEnabled={!!controls.monetization?.ads_enabled} canEdit={session.can_manage_config} onRefresh={async()=>{await Promise.all([loadPromotions(),loadCore()])}} notify={notify}/>}

      {tab==='content' && <ContentPanel announcements={announcements} questions={questions} platformPosts={platformPosts} canEdit={session.can_manage_config} superAdmin={session.role==='super_admin'} onRefresh={loadContent} notify={notify}/>} 

      {tab==='system' && <SystemPanel audit={audit} admins={admins} session={session} onRefresh={loadSystem} notify={notify}/>} 
    </main>
    <Toast message={toast.message} tone={toast.tone} onClose={()=>setToast({message:'',tone:'ok'})}/>
    {selectedUser&&<UserDrawer id={selectedUser} permissions={session} onClose={()=>setSelectedUser(null)} onChanged={loadUsers} notify={notify}/>} 
  </div>
}

function MetricList({ rows = [], labelKey, valueKey = 'events', secondaryKey = 'users', empty = 'No analytics yet' }) {
  const max = Math.max(1, ...rows.map(row=>Number(row[valueKey] || 0)))
  return <div className="hq-metric-list">{rows.length ? rows.map((row,index)=><div className="hq-metric-row" key={`${labelKey}-${index}`}>
    <div><strong>{row[labelKey] || 'Unknown'}</strong><span>{fmt(row[secondaryKey])} users</span></div>
    <em>{fmt(row[valueKey])}</em>
    <i><b style={{width:`${Math.max(7, Math.round((Number(row[valueKey] || 0) / max) * 100))}%`}}/></i>
  </div>) : <div className="hq-empty hq-empty--small"><Activity size={24}/><h3>{empty}</h3></div>}</div>
}

function AnalyticsPanel({ data, canPrune, onRefresh, notify }) {
  const [days,setDays]=useState(90)
  const prune=async()=>{try{const res=await adminService.pruneAnalytics(days);await onRefresh();notify(`Analytics cleaned: ${fmt(res?.deleted)} events older than ${res?.retention_days||days} days`)}catch(e){notify(e.message,'error')}}
  if(!data)return <div className="hq-view"><div className="hq-card hq-loading-card"><div className="hq-loader"/><strong>Loading analytics…</strong></div></div>
  const k=data.kpis||{}
  const locationRows=(data.locations||[]).map(row=>({...row, label:[row.city,row.region,row.country].filter(v=>v&&v!=='Unknown'&&v!=='--').join(', ') || 'Unknown'}))
  const pageRows=(data.top_pages||[]).map(row=>({...row, label:row.page_path || '/'}))
  return <div className="hq-view">
    <SectionHead eyebrow="FIRST-PARTY ANALYTICS" title="Active users, locations and launch health" action={<div className="hq-analytics-actions"><button className="hq-btn" onClick={onRefresh}><RefreshCw size={15}/> Refresh</button>{canPrune&&<><input type="number" min="7" max="365" value={days} onChange={e=>setDays(e.target.value)}/><button className="hq-btn" onClick={prune}><Trash2 size={15}/> Prune</button></>}</div>}/>
    <div className="hq-alert hq-analytics-note"><Shield size={17}/><div><strong>Private chats are not tracked.</strong><span>{data.privacy?.note} IP mode for your role: {data.privacy?.ip_mode || 'masked'}.</span></div></div>
    <div className="hq-kpis hq-kpis--analytics"><Stat icon={Activity} label="Active users" value={fmt(k.active_users_15m)} note={`${fmt(k.active_sessions_15m)} sessions / 15m`}/><Stat icon={Users} label="Unique users" value={fmt(k.unique_users_24h)} note="Last 24h"/><Stat icon={MousePointerClick} label="Events" value={fmt(k.events_24h)} note={`${fmt(k.page_views_24h)} page views`}/><Stat icon={MessageCircle} label="Messages" value={fmt(k.messages_24h)} note="Last 24h"/><Stat icon={Megaphone} label="Posts" value={fmt(k.posts_24h)} note={`+${fmt(k.new_users_24h)} users`}/><Stat icon={BadgeDollarSign} label="Ads / 24h" value={fmt(k.promotion_impressions_24h)} note={`${fmt(k.promotion_clicks_24h)} clicks`}/></div>
    <div className="hq-grid-2">
      <article className="hq-card"><div className="hq-card-title"><div><span>PLATFORM MIX</span><h3>Web, Android, Windows</h3></div><MonitorSmartphone size={18}/></div><MetricList rows={data.platforms||[]} labelKey="platform"/></article>
      <article className="hq-card"><div className="hq-card-title"><div><span>DEVICE MIX</span><h3>Mobile, tablet, desktop</h3></div><BarChart3 size={18}/></div><MetricList rows={data.devices||[]} labelKey="device_type"/></article>
      <article className="hq-card"><div className="hq-card-title"><div><span>LOCATION</span><h3>Top countries and cities</h3></div><MapPin size={18}/></div><MetricList rows={locationRows} labelKey="label"/></article>
      <article className="hq-card"><div className="hq-card-title"><div><span>PAGES</span><h3>Most viewed screens</h3></div><Globe2 size={18}/></div><MetricList rows={pageRows} labelKey="label" valueKey="views"/></article>
    </div>
    <SectionHead eyebrow="LIVE SESSIONS" title="Recent active users"/>
    <div className="hq-table-wrap"><table className="hq-table hq-analytics-table"><thead><tr><th>User</th><th>Platform</th><th>Location</th><th>IP</th><th>Last page</th><th>Last seen</th></tr></thead><tbody>{(data.recent_sessions||[]).map(row=><tr key={row.session_id}><td><div className="hq-session-user"><strong>{row.display_name||row.username||'Unknown'}</strong><small>@{row.username||'unknown'}</small></div></td><td>{row.platform}<small>{row.device_type}</small></td><td>{[row.city,row.region,row.country].filter(v=>v&&v!=='Unknown'&&v!=='--').join(', ') || 'Unknown'}</td><td>{row.ip_address||'—'}</td><td>{row.last_page||'/'}</td><td><span className="hq-time-cell"><Clock3 size={13}/>{dt(row.last_seen_at)}</span></td></tr>)}</tbody></table>{!(data.recent_sessions||[]).length&&<div className="hq-empty hq-empty--small"><Activity size={26}/><h3>No live sessions yet</h3><p>Ask a signed-in user to accept analytics consent and browse the app.</p></div>}</div>
  </div>
}


function VerificationPanel({ rows, canEdit, onRefresh, notify, onOpenUser }) {
  const [notes,setNotes]=useState({})
  const [busyId,setBusyId]=useState(null)
  const decide=async(row,approve)=>{
    if(!canEdit||busyId)return
    try{
      setBusyId(row.request_id)
      await adminService.reviewVerification(row.request_id,approve,notes[row.request_id]||'')
      await onRefresh()
      notify(approve?'Blue tick approved':'Waitlist entry declined')
    }catch(e){notify(e.message,'error')}finally{setBusyId(null)}
  }
  return <div className="hq-view">
    <SectionHead eyebrow="CERTIFIED ACCOUNTS" title="Blue tick waitlist"/>
    <div className="hq-verification-list">
      {rows.length ? rows.map(row=><article className="hq-card hq-verification-card" key={row.request_id}>
        <div className="hq-verification-card__head">
          <div className="hq-table-user"><div>{initials(row.display_name||row.username)}</div><span><strong>{row.display_name||row.username}</strong><small>@{row.username} · {row.email}</small></span></div>
          <span className="hq-verification-category">WAITLIST</span>
        </div>
        <div className="hq-verification-meta"><span><Zap size={14}/> +{fmt(row.aura_total)} Aura</span><span><RankMark rank={row.rank} size={13}/> {row.rank?.name||'CERTIFIED'}</span><span>Joined {dt(row.joined_at)}</span></div>
        <p className="hq-help">This user unlocked the verification waitlist by reaching Certified or a higher Aura rank. Approval grants the blue tick immediately.</p>
        <label className="hq-wide-field"><span>Reviewer note</span><textarea value={notes[row.request_id]||''} maxLength={1000} onChange={e=>setNotes(v=>({...v,[row.request_id]:e.target.value}))} placeholder="Optional internal/user-facing review note"/></label>
        <div className="hq-verification-actions"><button className="hq-btn" onClick={()=>onOpenUser(row.user_id)}>Open user</button><button className="hq-btn danger" disabled={!canEdit||busyId===row.request_id} onClick={()=>decide(row,false)}>Decline</button><button className="hq-btn hq-btn--gold" disabled={!canEdit||busyId===row.request_id} onClick={()=>decide(row,true)}><BadgeCheck size={16}/> Grant blue tick</button></div>
      </article>):<div className="hq-empty"><BadgeCheck size={30}/><h3>Waitlist clear</h3><p>No Certified users are waiting for verification review.</p></div>}
    </div>
  </div>
}

function RankEditor({ rank, onSave, disabled }) {
  const [d,setD]=useState(rank); useEffect(()=>setD(rank),[rank])
  return <article className={`hq-rank ${d.active?'':'is-off'}`}><div className="hq-rank-mark"><RankMark rank={d} size={15} label={false}/></div><input className="hq-rank-name" value={d.name} onChange={e=>setD(v=>({...v,name:e.target.value}))}/><label><span>Minimum Aura</span><input type="number" value={d.min_aura} onChange={e=>setD(v=>({...v,min_aura:e.target.value}))}/></label><div className="hq-rank-foot"><label className="hq-switch"><input type="checkbox" checked={d.active} onChange={e=>setD(v=>({...v,active:e.target.checked}))}/><i/></label><button disabled={disabled} onClick={()=>onSave(d)}>Save</button></div></article>
}

function AgeBandEditor({ band, onSaved, disabled }) {
  const [d,setD]=useState(band); useEffect(()=>setD(band),[band])
  return <article className="hq-card hq-age-band"><div><Shield size={18}/><input value={d.label} onChange={e=>setD(v=>({...v,label:e.target.value}))}/></div><div className="hq-band-range"><label><span>Min</span><input type="number" value={d.min_age} onChange={e=>setD(v=>({...v,min_age:e.target.value}))}/></label><span>→</span><label><span>Max</span><input type="number" value={d.max_age} onChange={e=>setD(v=>({...v,max_age:e.target.value}))}/></label></div><button className="hq-btn" disabled={disabled} onClick={()=>onSaved(d)}>Save safety band</button></article>
}

function InterestEditor({ interest, onSaved, disabled }) {
  const [d,setD]=useState(interest); useEffect(()=>setD(interest),[interest])
  return <article className={`hq-interest ${d.active?'':'is-off'}`}><div className="hq-interest-icon"><InterestIcon interest={d} size={17}/></div><div><input value={d.label} onChange={e=>setD(v=>({...v,label:e.target.value}))}/><span>{d.slug}</span><select className="hq-interest-icon-select" value={INTEREST_ICON_KEYS.some(([key])=>key===d.icon)?d.icon:'sparkles'} onChange={e=>setD(v=>({...v,icon:e.target.value}))}>{INTEREST_ICON_KEYS.map(([key,label])=><option value={key} key={key}>{label}</option>)}</select></div><label className="hq-switch"><input type="checkbox" checked={d.active} onChange={e=>setD(v=>({...v,active:e.target.checked}))}/><i/></label><button disabled={disabled} onClick={()=>onSaved(d)}>Save</button></article>
}

function MonetizationPanel({ config, items, packages, canEdit, onSaveConfig, onRefresh, notify }) {
  const [d,setD]=useState(config||{})
  const [item,setItem]=useState({slug:'',name:'',category:'aura_effect',description:'',price_coins:199,price_cents:199,currency:'USD',active:true,sort_order:0})
  const [pack,setPack]=useState({slug:'',name:'',coins:250,bonus_coins:0,price_cents:199,currency:'USD',active:true,sort_order:0})
  useEffect(()=>setD(config||{}),[config])
  const saveItem=async()=>{try{await adminService.upsertShopItem(item);setItem({slug:'',name:'',category:'aura_effect',description:'',price_coins:199,price_cents:199,currency:'USD',active:true,sort_order:0});await onRefresh();notify('Shop item saved')}catch(e){notify(e.message,'error')}}
  const savePack=async()=>{try{await adminService.upsertTopupPackage(pack);setPack({slug:'',name:'',coins:250,bonus_coins:0,price_cents:199,currency:'USD',active:true,sort_order:0});await onRefresh();notify('Top-up package saved')}catch(e){notify(e.message,'error')}}
  return <div className="hq-view">
    <SectionHead eyebrow="REVENUE WITHOUT SELLING AURA" title="Monetization"/>
    <div className="hq-grid-2">
      <article className="hq-card"><div className="hq-card-title"><div><span>CodaVybes ECONOMY</span><h3>Wallet + CodaVybes+</h3></div><Crown size={18}/></div>
        <div className="hq-money-toggles">{[['vybe_plus_enabled','CodaVybes+'],['topups_enabled','Coin top-ups'],['ads_enabled','Feed ads'],['gifting_enabled','Gifting'],['creator_marketplace_enabled','Creator marketplace'],['sponsored_rooms_enabled','Sponsored Rooms']].map(([key,label])=><label key={key}><span>{label}</span><input type="checkbox" checked={!!d[key]} onChange={e=>setD(v=>({...v,[key]:e.target.checked}))}/></label>)}</div>
        <div className="hq-field-grid"><label><span>CodaVybes+ price (VC)</span><input type="number" value={d.vybe_plus_price_coins??499} onChange={e=>setD(v=>({...v,vybe_plus_price_coins:e.target.value}))}/></label><label><span>Welcome coins</span><input type="number" value={d.welcome_coins??100} onChange={e=>setD(v=>({...v,welcome_coins:e.target.value}))}/></label><label><span>Coin name</span><input value={d.coin_name||'CodaCoins'} onChange={e=>setD(v=>({...v,coin_name:e.target.value}))}/></label><label><span>Coin symbol</span><input value={d.coin_symbol||'VC'} onChange={e=>setD(v=>({...v,coin_symbol:e.target.value.toUpperCase()}))}/></label><label><span>Payment provider</span><input value={d.payment_provider||'unconfigured'} onChange={e=>setD(v=>({...v,payment_provider:e.target.value}))}/></label><label><span>Currency</span><input value={d.currency||'USD'} onChange={e=>setD(v=>({...v,currency:e.target.value.toUpperCase()}))}/></label></div>
        <button className="hq-btn hq-btn--gold" disabled={!canEdit} onClick={()=>onSaveConfig({...d,vybe_plus_price_coins:Number(d.vybe_plus_price_coins),welcome_coins:Number(d.welcome_coins),feed_ad_interval:Number(d.feed_ad_interval||12),vybe_plus_price_cents:Number(d.vybe_plus_price_cents||399)})}>Save commerce</button>
        <p className="hq-help">Payment provider remains server-side. Aura can never be purchased with CodaCoins.</p>
      </article>
      <article className="hq-card"><div className="hq-card-title"><div><span>SHOP CATALOG</span><h3>Add cosmetic</h3></div><CircleDollarSign size={18}/></div><div className="hq-form"><input placeholder="slug e.g. galaxy_aura" value={item.slug} onChange={e=>setItem(v=>({...v,slug:e.target.value}))}/><input placeholder="Name" value={item.name} onChange={e=>setItem(v=>({...v,name:e.target.value}))}/><select value={item.category} onChange={e=>setItem(v=>({...v,category:e.target.value}))}><option value="aura_effect">Aura effect</option><option value="profile">Profile</option><option value="room_theme">Room theme</option><option value="avatar_frame">Avatar frame</option><option value="game_pack">Game pack</option></select><textarea placeholder="Description" value={item.description} onChange={e=>setItem(v=>({...v,description:e.target.value}))}/><div className="hq-money-row"><input type="number" title="VC price" value={item.price_coins} onChange={e=>setItem(v=>({...v,price_coins:e.target.value}))}/><input value={item.currency} onChange={e=>setItem(v=>({...v,currency:e.target.value.toUpperCase()}))}/><label><input type="checkbox" checked={item.active} onChange={e=>setItem(v=>({...v,active:e.target.checked}))}/> Live</label></div><button className="hq-btn hq-btn--gold" disabled={!canEdit||!item.slug||!item.name} onClick={saveItem}>Save catalog item</button></div></article>
    </div>
    <SectionHead eyebrow="TOP-UP RAIL" title="Coin packages"/>
    <div className="hq-grid-2"><article className="hq-card"><div className="hq-form"><input placeholder="slug" value={pack.slug} onChange={e=>setPack(v=>({...v,slug:e.target.value}))}/><input placeholder="Package name" value={pack.name} onChange={e=>setPack(v=>({...v,name:e.target.value}))}/><div className="hq-field-grid"><label><span>Coins</span><input type="number" value={pack.coins} onChange={e=>setPack(v=>({...v,coins:e.target.value}))}/></label><label><span>Bonus</span><input type="number" value={pack.bonus_coins} onChange={e=>setPack(v=>({...v,bonus_coins:e.target.value}))}/></label><label><span>Price cents</span><input type="number" value={pack.price_cents} onChange={e=>setPack(v=>({...v,price_cents:e.target.value}))}/></label></div><button className="hq-btn hq-btn--gold" disabled={!canEdit||!pack.slug||!pack.name} onClick={savePack}>Save top-up package</button></div></article><article className="hq-card"><div className="hq-mini-list">{packages.map(x=><div key={x.id}><strong>{x.name} · {x.coins+x.bonus_coins} VC</strong><span>{x.currency} {(x.price_cents/100).toFixed(2)} · {x.active?'live':'off'}</span></div>)}</div></article></div>
    <SectionHead eyebrow="CATALOG" title="Shop items"/>
    <div className="hq-catalog-grid">{items.length?items.map(x=><article className={`hq-card hq-catalog-item ${x.active?'':'is-off'}`} key={x.id}><span>{x.category.replaceAll('_',' ')}</span><h3>{x.name}</h3><p>{x.description||'No description'}</p><div><strong>{x.price_coins||0} VC</strong><b>{x.active?'LIVE':'DRAFT'}</b></div></article>):<div className="hq-empty"><CircleDollarSign size={28}/><h3>No cosmetics yet</h3><p>Add the first CodaVybes shop item.</p></div>}</div>
  </div>
}

function PromotionsPanel({ rows, adsEnabled, canEdit, onRefresh, notify }) {
  const empty={id:null,brand_name:'',headline:'',body:'',image_url:'',destination_url:'',cta_label:'Learn more',active:true,priority:0,min_age:18,starts_at:'',ends_at:''}
  const [d,setD]=useState(empty)
  const edit=(row)=>setD({...empty,...row,starts_at:row.starts_at?new Date(row.starts_at).toISOString().slice(0,16):'',ends_at:row.ends_at?new Date(row.ends_at).toISOString().slice(0,16):''})
  const save=async()=>{
    try {
      await adminService.upsertPromotion({...d,starts_at:d.starts_at?new Date(d.starts_at).toISOString():null,ends_at:d.ends_at?new Date(d.ends_at).toISOString():null})
      if(d.active&&!adsEnabled)await adminService.updateCommerce({ads_enabled:true},'Enable feed ads for active promotion')
      setD(empty)
      await onRefresh()
      notify(d.active?'Promotion is live and Feed ads are enabled':'Promotion saved as inactive')
    } catch(e) { notify(e.message,'error') }
  }
  const campaignState=(row)=>{
    const now=Date.now()
    if(!row.active)return'OFF'
    if(row.starts_at&&new Date(row.starts_at).getTime()>now)return'SCHEDULED'
    if(row.ends_at&&new Date(row.ends_at).getTime()<=now)return'EXPIRED'
    return adsEnabled?'LIVE':'ADS OFF'
  }

  return <div className="hq-view">
    <SectionHead eyebrow="PAID PLACEMENT" title="Sponsored promotions"/>
    {!adsEnabled&&<div className="hq-alert"><BadgeDollarSign size={18}/><span><strong>Feed ads are currently off.</strong> Saving an active campaign will enable them automatically.</span></div>}
    <div className="hq-grid-2">
      <article className="hq-card">
        <div className="hq-card-title"><div><span>CAMPAIGN</span><h3>{d.id?'Edit promotion':'New promotion'}</h3></div><BadgeDollarSign size={18}/></div>
        <div className="hq-form">
          <input placeholder="Brand name" value={d.brand_name} onChange={e=>setD(v=>({...v,brand_name:e.target.value}))}/>
          <input placeholder="Headline" value={d.headline} onChange={e=>setD(v=>({...v,headline:e.target.value}))}/>
          <textarea placeholder="Short sponsored copy" value={d.body} onChange={e=>setD(v=>({...v,body:e.target.value}))}/>
          <label className="hq-url-field"><Image size={15}/><input placeholder="https://... image URL" value={d.image_url||''} onChange={e=>setD(v=>({...v,image_url:e.target.value}))}/></label>
          <input placeholder="https://... destination URL" value={d.destination_url||''} onChange={e=>setD(v=>({...v,destination_url:e.target.value}))}/>
          <div className="hq-field-grid">
            <label><span>CTA</span><input value={d.cta_label} onChange={e=>setD(v=>({...v,cta_label:e.target.value}))}/></label>
            <label><span>Priority</span><input type="number" value={d.priority} onChange={e=>setD(v=>({...v,priority:e.target.value}))}/></label>
            <label><span>Minimum age</span><input type="number" min="18" max="120" value={d.min_age||18} onChange={e=>setD(v=>({...v,min_age:e.target.value}))}/></label>
            <label><span>Starts</span><input type="datetime-local" value={d.starts_at||''} onChange={e=>setD(v=>({...v,starts_at:e.target.value}))}/></label>
            <label><span>Ends</span><input type="datetime-local" value={d.ends_at||''} onChange={e=>setD(v=>({...v,ends_at:e.target.value}))}/></label>
          </div>
          <label className="hq-check"><input type="checkbox" checked={!!d.active} onChange={e=>setD(v=>({...v,active:e.target.checked}))}/> Active campaign</label>
          <div className="hq-form-actions"><button className="hq-btn hq-btn--gold" disabled={!canEdit||!d.brand_name||!d.headline} onClick={save}>Save promotion</button>{d.id&&<button className="hq-btn" onClick={()=>setD(empty)}>New campaign</button>}</div>
        </div>
        <p className="hq-help">Short feeds show one sponsored card after the first organic post. Larger feeds use a low-frequency placement after roughly every seven organic posts, capped at two sponsored cards per feed window. Campaign age, start and end settings still apply.</p>
      </article>
      <article className="hq-card">
        <div className="hq-card-title"><div><span>LIVE INVENTORY</span><h3>{rows.filter(r=>campaignState(r)==='LIVE').length} live campaigns</h3></div><Radio size={18}/></div>
        <div className="hq-promo-list">{rows.length?rows.map(r=>{
          const state=campaignState(r)
          return <button key={r.id} className={`hq-promo-row ${state==='LIVE'?'':'is-off'}`} onClick={()=>edit(r)}>
            <div>{r.image_url?<img src={r.image_url} alt=""/>:<span><BadgeDollarSign size={16}/></span>}</div>
            <section><strong>{r.brand_name}</strong><b>{r.headline}</b><small>{Number(r.impressions||0).toLocaleString()} impressions · {Number(r.clicks||0).toLocaleString()} clicks · {r.min_age||18}+</small></section>
            <em>{state}</em>
          </button>
        }):<div className="hq-empty"><BadgeDollarSign size={28}/><h3>No campaigns yet</h3><p>Add a paid placement from an image URL and destination link.</p></div>}</div>
      </article>
    </div>
  </div>
}

function ContentPanel({ announcements, questions, platformPosts, canEdit, superAdmin, onRefresh, notify }) {
  const [a,setA]=useState({title:'',body:'',audience:'all'})
  const [q,setQ]=useState({game_type:'trivia',prompt:'',options:'',correct_answer:'',active:true})
  const [post,setPost]=useState({body:'',image_url:'',cta_label:'',cta_url:'',pinned_until:''})
  const createA=async()=>{try{await adminService.createAnnouncement(a);setA({title:'',body:'',audience:'all'});await onRefresh();notify('Announcement published')}catch(e){notify(e.message,'error')}}
  const createQ=async()=>{try{const opts=q.options.split('|').map(v=>v.trim()).filter(Boolean);await adminService.upsertQuestion({...q,options:opts});setQ({game_type:'trivia',prompt:'',options:'',correct_answer:'',active:true});await onRefresh();notify('Game question added')}catch(e){notify(e.message,'error')}}
  const createPost=async()=>{try{await adminService.createPlatformPost({...post,pinned_until:post.pinned_until?new Date(post.pinned_until).toISOString():null});setPost({body:'',image_url:'',cta_label:'',cta_url:'',pinned_until:''});await onRefresh();notify('Official post sent to the feed and all users notified')}catch(e){notify(e.message,'error')}}
  const togglePost=async(row)=>{try{await adminService.setPlatformPostActive(row.id,!row.active);await onRefresh();notify(`Official post ${row.active?'hidden':'restored'}`)}catch(e){notify(e.message,'error')}}
  return <div className="hq-view"><SectionHead eyebrow="COMMUNICATION" title="Content control"/>
    {superAdmin&&<><div className="hq-grid-2"><article className="hq-card hq-platform-publisher"><div className="hq-card-title"><div><span>SUPER ADMIN POST</span><h3>Post as CodaVybes</h3></div><Pin size={18}/></div><div className="hq-form"><textarea placeholder="Official update shown at the top of For You" value={post.body} maxLength={1600} onChange={e=>setPost(v=>({...v,body:e.target.value}))}/><input placeholder="Optional image URL" value={post.image_url} onChange={e=>setPost(v=>({...v,image_url:e.target.value}))}/><div className="hq-field-grid"><label><span>CTA label</span><input value={post.cta_label} onChange={e=>setPost(v=>({...v,cta_label:e.target.value}))}/></label><label><span>CTA URL</span><input value={post.cta_url} onChange={e=>setPost(v=>({...v,cta_url:e.target.value}))}/></label><label><span>Pin until</span><input type="datetime-local" value={post.pinned_until} onChange={e=>setPost(v=>({...v,pinned_until:e.target.value}))}/></label></div><button className="hq-btn hq-btn--gold" disabled={!post.body.trim()} onClick={createPost}>Publish + notify everyone</button></div><p className="hq-help">Only super_admin can publish this feed surface. Users receive a system notification and the latest active post is pinned above organic For You content.</p></article><article className="hq-card"><div className="hq-card-title"><div><span>OFFICIAL FEED</span><h3>Recent posts</h3></div><Megaphone size={18}/></div><div className="hq-mini-list">{platformPosts.slice(0,8).map(x=><div key={x.id}><strong>{x.body.slice(0,90)}</strong><span>{x.active?'live':'hidden'} · {dt(x.created_at)}</span><button className="hq-mini-toggle" onClick={()=>togglePost(x)}>{x.active?'Hide':'Restore'}</button></div>)}</div></article></div></>}
    <div className="hq-grid-2"><article className="hq-card"><div className="hq-card-title"><div><span>BROADCAST</span><h3>Announcement</h3></div><BellRing size={18}/></div><div className="hq-form"><input placeholder="Title" value={a.title} onChange={e=>setA(v=>({...v,title:e.target.value}))}/><textarea placeholder="What should users see?" value={a.body} onChange={e=>setA(v=>({...v,body:e.target.value}))}/><select value={a.audience} onChange={e=>setA(v=>({...v,audience:e.target.value}))}><option value="all">Everyone</option><option value="10_12">10–12</option><option value="13_17">13–17</option><option value="18_plus">18+</option></select><button className="hq-btn hq-btn--gold" disabled={!canEdit||!a.title||!a.body} onClick={createA}>Publish announcement</button></div><div className="hq-mini-list">{announcements.slice(0,5).map(x=><div key={x.id}><strong>{x.title}</strong><span>{x.audience} · {x.active?'live':'off'}</span></div>)}</div></article><article className="hq-card"><div className="hq-card-title"><div><span>GAME ENGINE</span><h3>Add question</h3></div><Gamepad2 size={18}/></div><div className="hq-form"><select value={q.game_type} onChange={e=>setQ(v=>({...v,game_type:e.target.value}))}><option value="trivia">Rapid Trivia</option><option value="puzzle">Puzzle Battle</option><option value="most_likely">Most Likely To</option><option value="would_you_rather">Would You Rather</option><option value="emoji_decode">Emoji Decode</option><option value="riddle">Riddle Rush</option><option value="word_scramble">Word Scramble</option><option value="spot_lie">Spot the Lie</option></select><textarea placeholder="Prompt" value={q.prompt} onChange={e=>setQ(v=>({...v,prompt:e.target.value}))}/><input placeholder="Options separated with |" value={q.options} onChange={e=>setQ(v=>({...v,options:e.target.value}))}/><input placeholder="Correct answer (blank for social vote games)" value={q.correct_answer} onChange={e=>setQ(v=>({...v,correct_answer:e.target.value}))}/><button className="hq-btn hq-btn--gold" disabled={!canEdit||!q.prompt} onClick={createQ}>Add to question bank</button></div><div className="hq-mini-list">{questions.slice(0,6).map(x=><div key={x.id}><strong>{x.game_type} · {x.prompt}</strong><span>{x.active?'active':'disabled'}</span></div>)}</div></article></div></div>
}

function SystemPanel({ audit, admins, session, onRefresh, notify }) {
  const [form,setForm]=useState({user_id:'',role:'moderator',active:true,reason:'Admin access update'})
  const apply=async()=>{try{await adminService.setAdminRole(form.user_id,form.role,form.active,form.reason);await onRefresh();notify('Admin role updated')}catch(e){notify(e.message,'error')}}
  return <div className="hq-view"><SectionHead eyebrow="CONTROL PLANE" title="System & audit"/><div className="hq-grid-2">{session.can_manage_admins&&<article className="hq-card"><div className="hq-card-title"><div><span>RBAC</span><h3>Admin access</h3></div><LockKeyhole size={18}/></div><div className="hq-form"><input placeholder="User UUID" value={form.user_id} onChange={e=>setForm(v=>({...v,user_id:e.target.value}))}/><select value={form.role} onChange={e=>setForm(v=>({...v,role:e.target.value}))}><option value="super_admin">Super Admin</option><option value="admin">Admin</option><option value="moderator">Moderator</option><option value="analyst">Analyst</option></select><input placeholder="Reason" value={form.reason} onChange={e=>setForm(v=>({...v,reason:e.target.value}))}/><button className="hq-btn hq-btn--gold" disabled={!form.user_id} onClick={apply}>Apply access</button></div><div className="hq-mini-list">{admins.map(a=><div key={a.user_id}><strong>@{a.username||a.email}</strong><span>{a.role} · {a.active?'active':'disabled'}</span></div>)}</div></article>}<article className="hq-card"><div className="hq-card-title"><div><span>SECURITY</span><h3>HQ guarantees</h3></div><Shield size={18}/></div><ul className="hq-security-list"><li>Every privileged RPC validates admin role server-side.</li><li>Config and user mutations append an immutable audit entry.</li><li>Moderator, admin, analyst and super-admin powers are separated.</li><li>Suspended accounts are removed from age/discovery pools and core chat/Room membership checks.</li><li>Secret/service-role keys never enter the browser.</li></ul></article></div><SectionHead eyebrow="AUDIT TRAIL" title="Recent admin actions"/><div className="hq-table-wrap"><table className="hq-table"><thead><tr><th>Admin</th><th>Action</th><th>Target</th><th>Reason</th><th>Time</th></tr></thead><tbody>{audit.map(row=><tr key={row.id}><td>@{row.admin_username||'system'}</td><td><strong>{row.action}</strong></td><td>{row.target_type||'—'}<small>{row.target_id||''}</small></td><td>{row.reason||'—'}</td><td>{dt(row.created_at)}</td></tr>)}</tbody></table></div></div>
}
