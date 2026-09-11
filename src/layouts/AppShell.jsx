import { useEffect } from 'react'
import { Outlet, useLocation } from 'react-router-dom'
import BottomNav from '../components/BottomNav'
import DesktopSidebar from '../components/DesktopSidebar'
import DesktopRail from '../components/DesktopRail'
import NotificationBridge from '../components/NotificationBridge'
import ChatDeliveryBridge from '../components/ChatDeliveryBridge'
import { CommerceProvider } from '../context/CommerceContext'

function AppChrome() {
  const location = useLocation()

  useEffect(() => {
    const root = document.documentElement
    const syncViewport = () => {
      const height = window.visualViewport?.height || window.innerHeight
      root.style.setProperty('--coda-viewport-height', `${Math.round(height)}px`)
    }
    syncViewport()
    window.addEventListener('resize', syncViewport, { passive: true })
    window.visualViewport?.addEventListener('resize', syncViewport, { passive: true })
    window.visualViewport?.addEventListener('scroll', syncViewport, { passive: true })
    return () => {
      window.removeEventListener('resize', syncViewport)
      window.visualViewport?.removeEventListener('resize', syncViewport)
      window.visualViewport?.removeEventListener('scroll', syncViewport)
    }
  }, [])
  const focusRoute = /^\/(chats|rooms)\/[^/]+/.test(location.pathname) || /^\/meet\//.test(location.pathname) || /^\/moments\//.test(location.pathname)
  const chatRoute = /^\/chats\/[^/]+/.test(location.pathname)

  return <div className={`app-frame ${focusRoute ? 'app-frame--focus' : ''} ${chatRoute ? 'app-frame--chat' : ''}`}>
    <NotificationBridge />
    <ChatDeliveryBridge />
    <DesktopSidebar />
    <div className="app-workspace">
      <main className={`app-main ${chatRoute ? 'app-main--chat' : ''}`}><Outlet /></main>
      <DesktopRail />
    </div>
    {!chatRoute && <BottomNav />}
  </div>
}

export default function AppShell() {
  return <CommerceProvider><AppChrome /></CommerceProvider>
}
