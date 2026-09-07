import { Bell, Crown, Gamepad2, MessageCircle, Search, Settings, ShoppingBag, WalletCards, Zap } from 'lucide-react'
import { Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { useCommerce } from '../context/CommerceContext'
import NotificationBell from './NotificationBell'
import InstallVybeButton from './InstallVybeButton'

export default function DesktopRail() {
  const { onboarding } = useAuth()
  const { shopEnabled, plusEnabled } = useCommerce()
  const aura = Number(onboarding?.aura_total || 1)

  return <aside className="desktop-rail" aria-label="CodaVybes quick access">
    <div className="desktop-rail__top">
      <div>
        <span className="desktop-rail__kicker">YOUR SPACE</span>
        <strong>Stay in the loop.</strong>
      </div>
      <NotificationBell className="desktop-rail__bell"/>
    </div>

    <section className="desktop-aura-card surface">
      <span>AURA</span>
      <strong><Zap size={22} fill="currentColor"/>{aura.toLocaleString()}</strong>
      <p>Your reputation stays synced across web, mobile and desktop.</p>
      <Link to="/you">View profile</Link>
    </section>

    <section className="desktop-quick-card surface">
      <div className="desktop-quick-card__head"><span>Quick move</span><Search size={16}/></div>
      <Link to="/discover"><span><Search size={18}/></span><div><strong>Find people</strong><small>Discover your next connection</small></div></Link>
      <Link to="/rooms"><span><Gamepad2 size={18}/></span><div><strong>Enter a Room</strong><small>Play, talk and compete</small></div></Link>
      <Link to="/chats"><span><MessageCircle size={18}/></span><div><strong>Open chats</strong><small>Continue your conversations</small></div></Link>
    </section>

    <section className="desktop-quick-card desktop-quick-card--compact surface">
      <Link to="/wallet"><span><WalletCards size={18}/></span><div><strong>Wallet</strong><small>Coins and transactions</small></div></Link>
      {shopEnabled && <Link to="/shop"><span><ShoppingBag size={18}/></span><div><strong>Shop</strong><small>Own your look</small></div></Link>}
      {plusEnabled && <Link to="/vybe-plus"><span><Crown size={18}/></span><div><strong>CodaVybes+</strong><small>Premium expression</small></div></Link>}
      <Link to="/settings"><span><Settings size={18}/></span><div><strong>Settings</strong><small>Theme, privacy and alerts</small></div></Link>
    </section>

    <InstallVybeButton className="desktop-install-card"/>

    <p className="desktop-rail__footer"><Bell size={13}/> Notifications and account state stay synced in real time.</p>
  </aside>
}
