import { useEffect, useRef, useState } from 'react'
import { ChevronDown, Crown, Flame, Gamepad2, Link2, LogOut, Settings, Trophy, Users, Zap } from 'lucide-react'
import { Link } from 'react-router-dom'
import Avatar from '../components/Avatar'
import AuraRankCard from '../components/AuraRankCard'
import AuraBoard from '../components/AuraBoard'
import AuraHistory from '../components/AuraHistory'
import WalletMiniCard from '../components/WalletMiniCard'
import { PageSkeleton } from '../components/Loaders'
import InterestIcon from '../components/InterestIcon'
import VerifiedBadge from '../components/VerifiedBadge'
import PlusBadge from '../components/PlusBadge'
import { useAuth } from '../context/AuthContext'
import { useCommerce } from '../context/CommerceContext'
import { signOut } from '../services/authService'
import { getAuraDashboard, getAuraLedger, getMyMoments } from '../services/auraService'
import { getMyGameStats } from '../services/roomService'
import { getMyConnections } from '../services/socialService'
import { adminService } from '../services/adminService'

function initials(name = 'CodaVybes') { return name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'V' }
function niceSlug(slug) { return slug.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) }

export default function Profile() {
  const { onboarding } = useAuth()
  const { summary: commerceSummary } = useCommerce()
  const heroRef = useRef(null)
  const [compactIdentity, setCompactIdentity] = useState(false)
  const [dashboard, setDashboard] = useState(null)
  const [moments, setMoments] = useState([])
  const [ledger, setLedger] = useState([])
  const [gameStats, setGameStats] = useState({ vibe_level: 1, room_wins: 0, games_played: 0, verified_game_aura: 0 })
  const [connections, setConnections] = useState([])
  const [isAdmin, setIsAdmin] = useState(false)
  const [tab,setTab]=useState('moments')
  const [loading,setLoading]=useState(true)
  const name = onboarding?.display_name || onboarding?.username || 'CodaVybes User'
  const username = onboarding?.username || 'new_vibe'
  const interests = onboarding?.interests || []
  const plusActive = !!commerceSummary?.subscription

  useEffect(() => {
    adminService.session().then(() => setIsAdmin(true)).catch(() => setIsAdmin(false))
    Promise.all([getAuraDashboard(), getMyMoments(12), getAuraLedger(20), getMyGameStats(), getMyConnections(20)])
      .then(([dash, ownMoments, auraLedger, stats, bonds]) => { setDashboard(dash); setMoments(ownMoments); setLedger(auraLedger); setGameStats(stats); setConnections(bonds) })
      .catch((error) => console.error('Profile:', error)).finally(()=>setLoading(false))
  }, [])


  useEffect(() => {
    const hero = heroRef.current
    if (!hero || typeof IntersectionObserver === 'undefined') return undefined
    const observer = new IntersectionObserver(([entry]) => {
      const above = entry.boundingClientRect.top < 0
      setCompactIdentity(above && entry.intersectionRatio < 0.2)
    }, { threshold: [0, 0.2, 0.55, 1] })
    observer.observe(hero)
    return () => observer.disconnect()
  }, [])

  const aura = dashboard?.aura_total ?? onboarding?.aura_total ?? 1
  const rank = dashboard?.rank

  return <div className="page profile-page profile-page--v132 profile-page--v133">
    <div className={`profile-sticky-anchor ${compactIdentity ? 'is-visible' : ''}`} aria-hidden={!compactIdentity}>
      <div className="profile-sticky-identity surface">
        <Avatar src={onboarding?.avatar_url} alt={name} initials={initials(name)} size="md" online/>
        <div className="profile-sticky-copy"><div className="profile-sticky-name"><strong>{name}</strong><span className="identity-badges"><VerifiedBadge verified={onboarding?.is_verified} size={15}/><PlusBadge active={plusActive} size={15}/></span></div><span>@{username}</span></div>
        <b className="profile-sticky-score"><Zap size={14} fill="currentColor"/>+{Number(aura).toLocaleString()}</b>
      </div>
    </div>
    <section ref={heroRef} className="profile-identity-hero" aria-label="Profile identity">
      <Link className="icon-btn profile-settings profile-settings--hero" to="/settings" aria-label="Settings"><Settings size={20}/></Link>
      <div className="profile-avatar-stage"><Avatar src={onboarding?.avatar_url} alt={name} initials={initials(name)} size="xl" online/></div>
      <div className="profile-name-line profile-name-line--hero"><h1 title={name}>{name}</h1><span className="identity-badges identity-badges--hero"><VerifiedBadge verified={onboarding?.is_verified} size={22}/><PlusBadge active={plusActive} size={21}/></span></div>
      <p className="profile-handle" title={`@${username}`}>@{username}</p>
      <div className="profile-vibe-score" aria-label={`Vibe score ${aura}`}>
        <span className="profile-vibe-label">VIBE SCORE</span>
        <strong><Zap size={24} fill="currentColor"/>+{Number(aura).toLocaleString()}</strong>
        <small>{rank?.name || 'NEW VIBE'} · reputation across CodaVybes</small>
      </div>
      <button className="profile-scroll-cue" type="button" onClick={()=>document.getElementById('profile-details')?.scrollIntoView({behavior:'smooth',block:'start'})}>
        <span>Explore profile</span><ChevronDown size={16}/>
      </button>
    </section>

    <section id="profile-details" className="profile-details-v132">
    {loading ? <PageSkeleton variant="compact" count={3}/> : <>
      <AuraRankCard dashboard={dashboard}/>
      <WalletMiniCard/>
      <div className="aura-mini-stats surface"><div><strong>+{Number(dashboard?.received_today ?? 0).toLocaleString()}</strong><span>Today</span></div><div><strong>+{Number(dashboard?.received_7d ?? 0).toLocaleString()}</strong><span>7 days</span></div><div><strong>{dashboard?.giving_remaining_today ?? '—'}</strong><span>Aura left to give</span></div></div>
      <div className="profile-stats surface"><div><strong>{gameStats.vibe_level ?? 1}</strong><span>Vibe Level</span></div><div><strong>{connections.length}</strong><span>Bonds</span></div><div><strong>{gameStats.room_wins ?? 0}</strong><span>Room Wins</span></div></div>
      <p className="profile-bio">{onboarding?.bio || 'Your CodaVybes story starts here.'}</p>

      <div className="profile-tabs">{[['moments','Moments'],['rooms','Rooms'],['bonds','Bonds'],['about','About']].map(([key,label])=><button key={key} className={tab===key?'is-active':''} onClick={()=>setTab(key)}>{label}</button>)}</div>

      {tab==='moments' && <>
        <section className="my-moments">{moments.length ? moments.map((moment) => <Link className="surface profile-moment profile-moment--link" to={`/moments/${moment.target_id}`} key={moment.target_id}><p className="eyebrow"><Zap size={13}/> {moment.is_aura_moment ? 'AURA MOMENT' : 'CodaVybes MOMENT'}</p><h3>{moment.content_text}</h3><div className="row between"><span className="muted"><><Flame size={13}/> For You eligible</></span><strong className="brand-accent-text"><Zap size={13}/> +{moment.aura_count}</strong></div></Link>) : <article className="surface profile-moment empty-moment"><p className="eyebrow">FIRST MOMENT</p><h3>Your Room wins and Aura Moments will appear here.</h3><div className="row between"><span className="muted">Nothing to fake. Earn it.</span><strong className="brand-accent-text"><Zap size={13}/> +{aura}</strong></div></article>}</section>
        <AuraHistory rows={ledger}/><AuraBoard/>
      </>}

      {tab==='rooms' && <section className="profile-tab-panel"><article className="surface profile-room-summary"><Trophy size={24}/><div><p className="eyebrow">ROOM RECORD</p><h2>{gameStats.room_wins ?? 0} wins</h2><span>{gameStats.games_played ?? 0} games played · +{gameStats.verified_game_aura ?? 0} verified game Aura</span></div></article><Link className="btn btn--primary" to="/rooms"><Gamepad2 size={18}/> Enter Rooms</Link></section>}

      {tab==='bonds' && <section className="profile-tab-panel"><div className="profile-circle-head"><div><p className="eyebrow">YOUR CIRCLE</p><h2>People you keep close</h2></div><span>{connections.length} connections</span></div><div className="profile-bond-strip">{connections.length?connections.map((connection) => <article className="surface profile-bond-mini" key={connection.connection_id}><div className="identity-line"><strong>{connection.display_name || connection.username}</strong><span className="identity-badges"><VerifiedBadge verified={connection.is_verified} size={13}/><PlusBadge active={connection.is_plus} size={13}/></span></div><span>@{connection.username}</span><div className="bond-meter"><i style={{width:`${connection.bond_percent}%`}}/></div><b><Link2 size={13}/> {connection.bond_percent}% · {connection.bond_label}</b></article>):<div className="mini-empty surface"><Users size={22}/><span>No Bonds yet.</span></div>}</div><Link className="btn btn--outline" to="/discover?tab=connections">Open Bonds</Link></section>}

      {tab==='about' && <section className="profile-tab-panel"><article className="surface profile-about-card"><p className="eyebrow">YOUR VIBE</p><h3>{name}</h3><p>{onboarding?.bio || 'No bio yet.'}</p><div className="chips compact">{interests.map((interest) => <span className="chip" key={interest}><InterestIcon interest={interest} size={13}/>{niceSlug(interest)}</span>)}</div></article><Link className="btn btn--outline" to="/settings"><Settings size={18}/> Account & Settings</Link></section>}

      {isAdmin && <Link className="btn btn--outline profile-hq-link" to="/hq"><Crown size={18}/> Open CodaVybes HQ</Link>}
      <button className="btn btn--outline profile-signout" onClick={signOut}><LogOut size={18}/> Sign out</button>
    </>}
    </section>
  </div>
}
