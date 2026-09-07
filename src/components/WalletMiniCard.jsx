import { Coins, Crown, ShoppingBag, WalletCards } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useCommerce } from '../context/CommerceContext'

export default function WalletMiniCard({ compact = false }) {
  const { summary, loading, topupsEnabled, shopEnabled, plusEnabled } = useCommerce()
  if (loading) return <section className={`wallet-mini surface wallet-mini--loading ${compact ? 'wallet-mini--compact' : ''}`}><span className="skeleton-line w-40"/><span className="skeleton-line w-72"/></section>
  const balance = summary?.wallet?.coin_balance ?? 0
  const plus = summary?.subscription
  return <section className={`wallet-mini surface ${compact ? 'wallet-mini--compact' : ''}`}>
    <div className="wallet-mini__top"><div><p className="eyebrow">CodaVybes WALLET</p><strong><Coins size={18}/> {Number(balance).toLocaleString()} <small>VC</small></strong></div>{plus && plusEnabled ? <span className="plus-live"><Crown size={13}/> CodaVybes+</span> : plusEnabled ? <Link to="/vybe-plus" className="wallet-plus-link"><Crown size={14}/> CodaVybes+</Link> : <WalletCards size={18}/>}</div>
    <div className="wallet-mini__actions">
      <Link to="/wallet">{topupsEnabled ? 'Wallet & top up' : 'Wallet'}</Link>
      {shopEnabled && <Link to="/shop"><ShoppingBag size={14}/> Shop</Link>}
      {plusEnabled && <Link to="/vybe-plus"><Crown size={14}/> CodaVybes+</Link>}
    </div>
  </section>
}
