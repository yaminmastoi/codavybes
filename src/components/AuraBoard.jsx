import { useEffect, useState } from 'react'
import { getAuraBoard } from '../services/auraService'
import { InlineLoader } from './Loaders'
import VerifiedBadge from './VerifiedBadge'

export default function AuraBoard() {
  const [windowName, setWindowName] = useState('week')
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let alive = true
    setLoading(true)
    getAuraBoard(windowName, 10)
      .then((data) => { if (alive) setRows(data) })
      .catch((error) => console.error('Aura Board:', error))
      .finally(() => { if (alive) setLoading(false) })
    return () => { alive = false }
  }, [windowName])

  return <section className="aura-board surface">
    <div className="section-title aura-board__head">
      <div><p className="eyebrow">AURA BOARD</p><h3>Who's moving?</h3></div>
      <div className="mini-tabs">
        {['day','week','lifetime'].map((value) => <button key={value} className={windowName === value ? 'is-active' : ''} onClick={() => setWindowName(value)}>{value === 'day' ? 'Today' : value === 'week' ? 'Week' : 'All'}</button>)}
      </div>
    </div>
    {loading ? <InlineLoader label="Loading Aura board"/> : rows.length === 0 ? <p className="muted">No Aura movement yet.</p> : <div className="board-list">
      {rows.map((row, index) => <div className="board-row" key={row.user_id}>
        <span className="board-pos">#{index + 1}</span>
        <div className="board-user"><div className="identity-line"><strong>{row.display_name || row.username}</strong><VerifiedBadge verified={row.is_verified} size={13}/></div><small>@{row.username} · {row.rank?.name || 'NEW VIBE'}</small></div>
        <strong className="gold">+{Number(row.window_aura ?? 0).toLocaleString()}</strong>
      </div>)}
    </div>}
  </section>
}
