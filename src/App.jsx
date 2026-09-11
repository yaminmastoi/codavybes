import { Navigate, Route, Routes } from 'react-router-dom'
import OnboardingFlow from './onboarding/OnboardingFlow'
import AppShell from './layouts/AppShell'
import Home from './pages/Home'
import Discover from './pages/Discover'
import Rooms from './pages/Rooms'
import RoomDetail from './pages/RoomDetail'
import Chats from './pages/Chats'
import ChatDetail from './pages/ChatDetail'
import Profile from './pages/Profile'
import MeetSession from './pages/MeetSession'
import { RequireOnboarded, RootRedirect } from './components/RouteGuards'
import AdminGuard from './admin/AdminGuard'
import HQ from './admin/HQ'
import Notifications from './pages/Notifications'
import Settings from './pages/Settings'
import Wallet from './pages/Wallet'
import Shop from './pages/Shop'
import VybePlus from './pages/VybePlus'
import MomentThread from './pages/MomentThread'
import CommerceGate from './components/CommerceGate'
import ForgotPassword from './pages/ForgotPassword'
import ResetPassword from './pages/ResetPassword'
import LegalPage from './pages/LegalPage'
import ConsentBanner from './components/ConsentBanner'
import AuthCallback from './pages/AuthCallback'
import AnalyticsBridge from './components/AnalyticsBridge'
import Leaderboard from './pages/Leaderboard'

export default function App() {
  return (<>
    <AnalyticsBridge/>
    <Routes>
      <Route path="/" element={<RootRedirect />} />
      <Route path="/onboarding" element={<OnboardingFlow />} />
      <Route path="/auth/callback" element={<AuthCallback />} />
      <Route path="/auth/reset-password" element={<AuthCallback />} />
      <Route path="/forgot-password" element={<ForgotPassword />} />
      <Route path="/reset-password" element={<ResetPassword />} />
      <Route path="/privacy" element={<LegalPage type="privacy" />} />
      <Route path="/cookies" element={<LegalPage type="cookies" />} />
      <Route path="/security" element={<LegalPage type="security" />} />
      <Route path="/terms" element={<LegalPage type="terms" />} />
      <Route path="/hq" element={<RequireOnboarded><AdminGuard><HQ /></AdminGuard></RequireOnboarded>} />
      <Route element={<RequireOnboarded><AppShell /></RequireOnboarded>}>
        <Route path="/home" element={<Home />} />
        <Route path="/discover" element={<Discover />} />
        <Route path="/leaderboard" element={<Leaderboard />} />
        <Route path="/rooms" element={<Rooms />} />
        <Route path="/rooms/:roomId" element={<RoomDetail />} />
        <Route path="/chats" element={<Chats />} />
        <Route path="/chats/:conversationId" element={<ChatDetail />} />
        <Route path="/meet/:sessionId" element={<MeetSession />} />
        <Route path="/you" element={<Profile />} />
        <Route path="/notifications" element={<Notifications />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/wallet" element={<Wallet />} />
        <Route path="/shop" element={<CommerceGate feature="shop"><Shop /></CommerceGate>} />
        <Route path="/vybe-plus" element={<CommerceGate feature="plus"><VybePlus /></CommerceGate>} />
        <Route path="/moments/:targetId" element={<MomentThread />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
    <ConsentBanner/>
  </>)
}
