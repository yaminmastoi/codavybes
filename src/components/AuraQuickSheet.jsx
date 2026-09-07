import { Award, X } from 'lucide-react'
import AuraRankCard from './AuraRankCard'

export default function AuraQuickSheet({ open, dashboard, onClose }) {
  if (!open) return null
  return <div className="quick-sheet-backdrop" onMouseDown={(e)=>e.target===e.currentTarget&&onClose()}>
    <section className="quick-sheet surface" role="dialog" aria-modal="true" aria-label="Aura rank">
      <header><div><span className="quick-sheet__icon"><Award size={19}/></span><div><small>AURA PROFILE</small><strong>Your rank & momentum</strong></div></div><button className="icon-btn" onClick={onClose}><X size={18}/></button></header>
      <AuraRankCard dashboard={dashboard}/>
      <div className="quick-sheet__note">Aura is earned through real interactions. CodaCoins never buy rank.</div>
    </section>
  </div>
}
