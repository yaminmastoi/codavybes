import { useEffect, useState } from 'react'
import { Award, Crown, Trophy, Zap } from 'lucide-react'
import Avatar from '../components/Avatar'
import VerifiedBadge from '../components/VerifiedBadge'
import RankMark from '../components/RankMark'
import { PageSkeleton } from '../components/Loaders'
import { getPlatformLeaderboard } from '../services/leaderboardService'

function initials(name = 'C') {
  return String(name || '').trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'C'
}

export default function Leaderboard() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    let alive = true
    getPlatformLeaderboard(10)
      .then((data) => { if (alive) setRows(data) })
      .catch((err) => { if (alive) setError(err?.message || 'Could not load the leaderboard.') })
      .finally(() => { if (alive) setLoading(false) })
    return () => { alive = false }
  }, [])

  return <div className="page leaderboard-page">
    <header className="leaderboard-head">
      <div><p className="eyebrow">PLATFORM RANKING</p><h1><Trophy size={30}/> Leaderboard</h1><p>Top 10 CodaVybes users ranked by Aura across the whole active platform.</p></div>
      <div className="leaderboard-crown"><Crown size={28}/></div>
    </header>
    {error && <div className="settings-save-note">{error}</div>}
    {loading ? <PageSkeleton variant="compact" count={6}/> : <section className="leaderboard-list surface">
      {rows.length ? rows.map((row) => {
        const name = row.display_name || row.username
        return <article key={row.user_id} className={`leaderboard-row ${row.position <= 3 ? `is-top is-top-${row.position}` : ''}`}>
          <strong className="leaderboard-position">{row.position <= 3 ? <Award size={21}/> : `#${row.position}`}</strong>
          <Avatar src={row.avatar_url} initials={initials(name)}/>
          <div className="leaderboard-person"><div className="identity-line"><strong>{name}</strong><VerifiedBadge verified={row.is_verified} size={15}/></div><span>@{row.username}</span></div>
          <div className="leaderboard-rank"><RankMark rank={row.rank} size={14}/><b><Zap size={14} fill="currentColor"/>+{Number(row.aura_total || 0).toLocaleString()}</b></div>
        </article>
      }) : <div className="mini-empty">The leaderboard will appear as users complete onboarding and earn Aura.</div>}
    </section>}
  </div>
}
