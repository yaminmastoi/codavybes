import { useEffect, useRef, useState } from 'react'
import { ChevronDown, Crown, Flame, Gamepad2, Link2, LogOut, Settings, Trophy, Users, Zap } from 'lucide-react'
import { Link } from 'react-router-dom'
import Avatar from '../components/Avatar'
import AuraRankCard from '../components/AuraRankCard'
import WalletMiniCard from '../components/WalletMiniCard'
import { PageSkeleton } from '../components/Loaders'
import InterestIcon from '../components/InterestIcon'
import VerifiedBadge from '../components/VerifiedBadge'
import PlusBadge from '../components/PlusBadge'
import { useAuth } from '../context/AuthContext'
import { useCommerce } from '../context/CommerceContext'
import { signOut } from '../services/authService'
import { getAuraDashboard, getMyThreads } from '../services/auraService'
import { getMyGameStats } from '../services/roomService'
import { getMyConnections } from '../services/socialService'
import { adminService } from '../services/adminService'

function initials(name = 'CodaVybes') { return String(name ?? '').trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'V' }
function niceSlug(slug) { return slug.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) }

export default function Profile() {
  const { onboarding } = useAuth()
  const { summary: commerceSummary } = useCommerce()
  const [compactIdentity, setCompactIdentity] = useState(false)
  const [dashboard, setDashboard] = useState(null)
  const [threads, setThreads] = useState([])
  const [gameStats, setGameStats] = useState({ vibe_level: 1, room_wins: 0, games_played: 0, verified_game_aura: 0 })
  const [connections, setConnections] = useState([])
  const [isAdmin, setIsAdmin] = useState(false)
  const [tab,setTab]=useState('threads')
  const [loading,setLoading]=useState(true)
  const pageRef = useRef(null)
  const heroRef = useRef(null)
  const motionFrameRef = useRef(0)
  const name = onboarding?.display_name || onboarding?.username || 'CodaVybes User'
  const username = onboarding?.username || 'new_vibe'
  const interests = onboarding?.interests || []
  const plusActive = !!commerceSummary?.subscription

  useEffect(() => {
    adminService.session().then(() => setIsAdmin(true)).catch(() => setIsAdmin(false))
    Promise.all([getAuraDashboard(), getMyThreads(20), getMyGameStats(), getMyConnections(20)])
      .then(([dash, ownThreads, stats, bonds]) => { setDashboard(dash); setThreads(ownThreads); setGameStats(stats); setConnections(bonds) })
      .catch((error) => console.error('Profile:', error)).finally(()=>setLoading(false))
  }, [])


  useEffect(() => {
    const handleScroll = (event) => {
      const target = event?.target
      const documentScroll = target === document || target === window || target === document.documentElement || target === document.body
      if (target && !documentScroll && !target.classList?.contains('app-main')) return
      const top = documentScroll
        ? (window.scrollY || document.documentElement.scrollTop || 0)
        : (Number(target?.scrollTop) || window.scrollY || 0)
      cancelAnimationFrame(motionFrameRef.current)
      motionFrameRef.current = requestAnimationFrame(() => {
        setCompactIdentity(top > 86)
        pageRef.current?.style.setProperty('--profile-scroll', Math.min(top / 420, 1).toFixed(3))
      })
    }
    window.addEventListener('scroll', handleScroll, { passive: true })
    document.addEventListener('scroll', handleScroll, { passive: true, capture: true })
    handleScroll({ target: document.querySelector('.app-main') || document })
    return () => {
      window.removeEventListener('scroll', handleScroll)
      document.removeEventListener('scroll', handleScroll, true)
      cancelAnimationFrame(motionFrameRef.current)
    }
  }, [])

  function tiltHero(event) {
    if (window.matchMedia('(pointer: coarse)').matches || !heroRef.current) return
    const bounds = heroRef.current.getBoundingClientRect()
    const x = ((event.clientX - bounds.left) / bounds.width - .5) * 2
    const y = ((event.clientY - bounds.top) / bounds.height - .5) * 2
    heroRef.current.style.setProperty('--profile-tilt-x', `${(-y * 5).toFixed(2)}deg`)
    heroRef.current.style.setProperty('--profile-tilt-y', `${(x * 7).toFixed(2)}deg`)
  }

  function resetHeroTilt() {
    heroRef.current?.style.setProperty('--profile-tilt-x', '0deg')
    heroRef.current?.style.setProperty('--profile-tilt-y', '0deg')
  }

  const aura = dashboard?.aura_total ?? onboarding?.aura_total ?? 1
  const rank = dashboard?.rank

  return <div ref={pageRef} className="page profile-page profile-page--v132 profile-page--v133 profile-page--motion">
    <div className={`profile-sticky-anchor ${compactIdentity ? 'is-visible' : ''}`} aria-hidden={!compactIdentity}>
      <div className="profile-sticky-identity surface">
        <Avatar src={onboarding?.avatar_url} alt={name} initials={initials(name)} size="md" online/>
        <div className="profile-sticky-copy"><div className="profile-sticky-name"><strong>{name}</strong><span className="identity-badges"><VerifiedBadge verified={onboarding?.is_verified} size={15}/><PlusBadge active={plusActive} size={15}/></span></div><span>@{username}</span></div>
        <b className="profile-sticky-score"><Zap size={14} fill="currentColor"/>+{Number(aura).toLocaleString()}</b>
      </div>
    </div>
    <section ref={heroRef} className="profile-identity-hero profile-identity-hero--3d" aria-label="Profile identity" onPointerMove={tiltHero} onPointerLeave={resetHeroTilt}>
      <div className="profile-3d-scene" aria-hidden="true">
        <i className="profile-orbit profile-orbit--one"/>
        <i className="profile-orbit profile-orbit--two"/>
        <span className="profile-float-chip profile-float-chip--aura"><Zap size={13}/> AURA</span>
        <span className="profile-float-chip profile-float-chip--rising"><Flame size={13}/> RISING</span>
        <span className="profile-float-chip profile-float-chip--bonds"><Link2 size={13}/> BONDS</span>
      </div>
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

      <div className="profile-tabs">{[['threads','Threads'],['rooms','Rooms'],['bonds','Bonds'],['about','About']].map(([key,label])=><button key={key} className={tab===key?'is-active':''} onClick={()=>setTab(key)}>{label}</button>)}</div>

      {tab==='threads' && <section className="my-moments profile-threads">{threads.length ? threads.map((thread) => <Link className="surface profile-moment profile-moment--link" to={`/moments/${thread.target_id}`} key={thread.target_id}><p className="eyebrow"><Flame size={13}/> RISING LAB THREAD</p><h3>{thread.content_text}</h3><div className="row between"><span className="muted">Published {new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric'}).format(new Date(thread.created_at))}</span><strong className="brand-accent-text"><Zap size={13}/> +{thread.aura_count}</strong></div></Link>) : <article className="surface profile-moment empty-moment"><p className="eyebrow">NO THREADS YET</p><h3>Thoughts uploaded from Rising Lab will appear here.</h3><div className="row between"><Link className="text-btn" to="/home">Open Rising Lab</Link><strong className="brand-accent-text"><Zap size={13}/> +{aura}</strong></div></article>}</section>}

      {tab==='rooms' && <section className="profile-tab-panel"><article className="surface profile-room-summary"><Trophy size={24}/><div><p className="eyebrow">ROOM RECORD</p><h2>{gameStats.room_wins ?? 0} wins</h2><span>{gameStats.games_played ?? 0} games played · +{gameStats.verified_game_aura ?? 0} verified game Aura</span></div></article><Link className="btn btn--primary" to="/rooms"><Gamepad2 size={18}/> Enter Rooms</Link></section>}

      {tab==='bonds' && <section className="profile-tab-panel"><div className="profile-circle-head"><div><p className="eyebrow">YOUR CIRCLE</p><h2>People you keep close</h2></div><span>{connections.length} connections</span></div><div className="profile-bond-strip">{connections.length?connections.map((connection) => <article className="surface profile-bond-mini" key={connection.connection_id}><div className="identity-line"><strong>{connection.display_name || connection.username}</strong><span className="identity-badges"><VerifiedBadge verified={connection.is_verified} size={13}/><PlusBadge active={connection.is_plus} size={13}/></span></div><span>@{connection.username}</span><div className="bond-meter"><i style={{width:`${connection.bond_percent}%`}}/></div><b><Link2 size={13}/> {connection.bond_percent}% · {connection.bond_label}</b></article>):<div className="mini-empty surface"><Users size={22}/><span>No Bonds yet.</span></div>}</div><Link className="btn btn--outline" to="/discover?tab=connections">Open Bonds</Link></section>}

      {tab==='about' && <section className="profile-tab-panel"><article className="surface profile-about-card"><p className="eyebrow">YOUR VIBE</p><h3>{name}</h3><p>{onboarding?.bio || 'No bio yet.'}</p><div className="chips compact">{interests.map((interest) => <span className="chip" key={interest}><InterestIcon interest={interest} size={13}/>{niceSlug(interest)}</span>)}</div></article><Link className="btn btn--outline" to="/settings"><Settings size={18}/> Account & Settings</Link></section>}

      {isAdmin && <Link className="btn btn--outline profile-hq-link" to="/hq"><Crown size={18}/> Open CodaVybes HQ</Link>}
      <button className="btn btn--outline profile-signout" onClick={signOut}><LogOut size={18}/> Sign out</button>
    </>}
    </section>
  </div>
}
