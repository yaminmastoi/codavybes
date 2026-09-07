import { Gamepad2, RotateCcw, ShieldCheck, Trophy, Zap } from 'lucide-react'

function SourceIcon({ source }) {
  const Icon = source === 'game' ? Gamepad2 : source === 'room_mvp' ? Trophy : source === 'admin_adjustment' ? ShieldCheck : source === 'reversal' ? RotateCcw : Zap
  return <Icon size={14}/>
}
function sourceLabel(source) {
  if (source === 'game') return 'Verified game'
  if (source === 'room_mvp') return 'Room MVP'
  if (source === 'admin_adjustment') return 'Admin adjustment'
  if (source === 'reversal') return 'Aura correction'
  return 'Peer Aura'
}
export default function AuraHistory({ rows = [] }) {
  return <section className="aura-history surface">
    <div className="section-title aura-history__head"><div><p className="eyebrow">AURA LEDGER</p><h3>Recent Aura</h3></div><span className="ledger-lock">Immutable history</span></div>
    {rows.length === 0 ? <p className="muted">No Aura events yet. Your +1 starting Aura is the baseline.</p> : <div className="ledger-list">
      {rows.map((row) => <div className="ledger-row" key={row.event_id}>
        <div className="ledger-dot"><SourceIcon source={row.source}/></div>
        <div className="ledger-copy"><strong>{sourceLabel(row.source)}</strong><span>{row.giver_display_name || row.giver_username ? `From ${row.giver_display_name || `@${row.giver_username}`}` : (row.metadata?.label || row.metadata?.reason || 'Verified by CodaVybes')}</span>{row.target_text && <small>“{row.target_text.slice(0, 90)}{row.target_text.length > 90 ? '…' : ''}”</small>}</div>
        <strong className={row.amount >= 0 ? 'brand-accent-text' : 'danger-text'}>{row.amount >= 0 ? '+' : ''}{row.amount}</strong>
      </div>)}
    </div>}
  </section>
}
