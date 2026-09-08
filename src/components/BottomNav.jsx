import { useEffect, useRef, useState } from 'react'
import { Gamepad2, Home, MessageCircle, Search, UserRound } from 'lucide-react'
import { NavLink, useLocation } from 'react-router-dom'

const items = [
  ['/home', Home, 'Home'],
  ['/discover', Search, 'Discover'],
  ['/rooms', Gamepad2, 'Rooms'],
  ['/chats', MessageCircle, 'Chats'],
  ['/you', UserRound, 'You'],
]

export default function BottomNav() {
  const location = useLocation()
  const [visible, setVisible] = useState(true)
  const scrollState = useRef({ top: 0, direction: 0, distance: 0 })

  useEffect(() => {
    setVisible(true)
    scrollState.current = { top: 0, direction: 0, distance: 0 }
  }, [location.pathname])

  useEffect(() => {
    const readTop = (target) => {
      if (target === document || target === document.documentElement || target === document.body) {
        return window.scrollY || document.documentElement.scrollTop || 0
      }
      return Number(target?.scrollTop) || 0
    }

    const handleScroll = (event) => {
      const top = readTop(event.target)
      const previous = scrollState.current.top
      const delta = top - previous
      if (Math.abs(delta) < 2) return

      const direction = delta > 0 ? 1 : -1
      const distance = scrollState.current.direction === direction
        ? scrollState.current.distance + Math.abs(delta)
        : Math.abs(delta)

      scrollState.current = { top, direction, distance }
      if (top < 36) setVisible(true)
      else if (direction > 0 && distance >= 18) setVisible(false)
      else if (direction < 0 && distance >= 10) setVisible(true)
    }

    window.addEventListener('scroll', handleScroll, { passive: true })
    document.addEventListener('scroll', handleScroll, { passive: true, capture: true })
    return () => {
      window.removeEventListener('scroll', handleScroll)
      document.removeEventListener('scroll', handleScroll, true)
    }
  }, [])

  return (
    <nav className={`bottom-nav ${visible ? 'is-visible' : 'is-hidden'}`} aria-label="Primary navigation">
      {items.map(([to, Icon, label]) => (
        <NavLink key={to} to={to} aria-label={label} className={({ isActive }) => `bottom-nav__item ${isActive ? 'is-active' : ''} ${label === 'Rooms' ? 'is-room' : ''}`}>
          <span className="bottom-nav__icon"><Icon size={20} /></span>
          <small>{label}</small>
        </NavLink>
      ))}
    </nav>
  )
}
