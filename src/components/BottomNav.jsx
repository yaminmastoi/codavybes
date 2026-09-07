import { Gamepad2, Home, MessageCircle, Search, UserRound } from 'lucide-react'
import { NavLink } from 'react-router-dom'

const items = [
  ['/home', Home, 'Home'],
  ['/discover', Search, 'Discover'],
  ['/rooms', Gamepad2, 'Rooms'],
  ['/chats', MessageCircle, 'Chats'],
  ['/you', UserRound, 'You'],
]

export default function BottomNav() {
  return (
    <nav className="bottom-nav">
      {items.map(([to, Icon, label]) => (
        <NavLink key={to} to={to} className={({ isActive }) => `bottom-nav__item ${isActive ? 'is-active' : ''} ${label === 'Rooms' ? 'is-room' : ''}`}>
          <span className="bottom-nav__icon"><Icon size={20} /></span>
          <small>{label}</small>
        </NavLink>
      ))}
    </nav>
  )
}
