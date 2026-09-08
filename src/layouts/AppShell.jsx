import { Outlet, useLocation } from 'react-router-dom'
import BottomNav from '../components/BottomNav'
import DesktopSidebar from '../components/DesktopSidebar'
import DesktopRail from '../components/DesktopRail'
import NotificationBridge from '../components/NotificationBridge'
import ChatDeliveryBridge from '../components/ChatDeliveryBridge'
import { CommerceProvider } from '../context/CommerceContext'

function AppChrome() {
  const location = useLocation()
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
    <BottomNav />
  </div>
}

export default function AppShell() {
  return <CommerceProvider><AppChrome /></CommerceProvider>
}
