import {
  Bell,
  Crown,
  Gamepad2,
  Home,
  MessageCircle,
  Search,
  Settings,
  ShoppingBag,
  UserRound,
  WalletCards,
  Zap,
} from 'lucide-react'
import { NavLink } from 'react-router-dom'
import Logo from './Logo'
import Avatar from './Avatar'
import { useAuth } from '../context/AuthContext'
import { useCommerce } from '../context/CommerceContext'

const primary = [
  ['/home', Home, 'Home'],
  ['/discover', Search, 'Discover'],
  ['/rooms', Gamepad2, 'Rooms'],
  ['/chats', MessageCircle, 'Chats'],
  ['/you', UserRound, 'Profile'],
]

function initials(name = 'CodaVybes') {
  return name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'V'
}

function SideLink({ to, icon: Icon, label, end = false }) {
  return <NavLink to={to} end={end} className={({ isActive }) => `desktop-side-link ${isActive ? 'is-active' : ''}`}>
    <span><Icon size={20}/></span>
    <strong>{label}</strong>
  </NavLink>
}

export default function DesktopSidebar() {
  const { onboarding } = useAuth()
  const { shopEnabled, plusEnabled } = useCommerce()
  const name = onboarding?.display_name || onboarding?.username || 'CodaVybes'

  return <aside className="desktop-sidebar" aria-label="Primary navigation">
    <div className="desktop-sidebar__brand"><Logo/></div>

    <nav className="desktop-sidebar__nav">
      {primary.map(([to, Icon, label]) => <SideLink key={to} to={to} icon={Icon} label={label}/>) }
    </nav>

    <div className="desktop-sidebar__divider"/>
    <nav className="desktop-sidebar__nav desktop-sidebar__nav--secondary">
      <SideLink to="/notifications" icon={Bell} label="Notifications"/>
      <SideLink to="/wallet" icon={WalletCards} label="Wallet"/>
      {shopEnabled && <SideLink to="/shop" icon={ShoppingBag} label="Shop"/>}
      {plusEnabled && <SideLink to="/vybe-plus" icon={Crown} label="CodaVybes+"/>}
      <SideLink to="/settings" icon={Settings} label="Settings"/>
    </nav>

    <div className="desktop-sidebar__user surface">
      <Avatar initials={initials(name)} online/>
      <div className="desktop-sidebar__user-copy">
        <strong>{name}</strong>
        <span>@{onboarding?.username || 'codavybes'}</span>
      </div>
      <b className="desktop-sidebar__aura"><Zap size={13} fill="currentColor"/>{Number(onboarding?.aura_total || 1).toLocaleString()}</b>
    </div>
  </aside>
}
