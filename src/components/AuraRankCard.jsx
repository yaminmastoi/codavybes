import { Zap } from 'lucide-react'
import RankMark from './RankMark'

export default function AuraRankCard({ dashboard, compact = false }) {
  if (!dashboard) return null
  const rank = dashboard.rank || {}
  const progress = Math.max(0, Math.min(1, Number(rank.progress ?? 0)))

  return <section className={`aura-rank-card surface ${compact ? 'is-compact' : ''}`}>
    <div className="row between rank-card-top">
      <div><p className="eyebrow">AURA RANK</p><h2><RankMark rank={rank} size={18}/></h2></div>
      <strong className="rank-total"><Zap size={16}/> +{Number(dashboard.aura_total ?? 1).toLocaleString()}</strong>
    </div>
    {rank.next_name ? <>
      <div className="rank-progress-track"><span style={{ width: `${progress * 100}%` }} /></div>
      <div className="row between rank-progress-copy"><small className="muted">{rank.name}</small><small>{Number(rank.aura_to_next ?? 0).toLocaleString()} Aura to <strong>{rank.next_name}</strong></small></div>
    </> : <p className="muted rank-maxed">Maximum Aura rank reached.</p>}
  </section>
}
