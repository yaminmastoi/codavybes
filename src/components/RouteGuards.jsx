import { Navigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import SetupRequired from './SetupRequired'
import AccountRestricted from './AccountRestricted'
import { AppLaunchLoader } from './Loaders'

function LoadingGate() {
  return <AppLaunchLoader label="Preparing your CodaVybes" />
}

export function RootRedirect() {
  const { configured, loading, onboardingLoading, session, onboarding } = useAuth()
  if (!configured) return <SetupRequired />
  if (loading || (session && onboardingLoading)) return <LoadingGate />
  if (!session) return <Navigate to="/onboarding" replace />
  if (onboarding?.app_access === false) return <AccountRestricted status={onboarding?.account_status} />
  if (onboarding?.onboarding_complete) return <Navigate to="/home" replace />
  return <Navigate to="/onboarding" replace />
}

export function RequireOnboarded({ children }) {
  const { configured, loading, onboardingLoading, session, onboarding } = useAuth()
  if (!configured) return <SetupRequired />
  if (loading || (session && onboardingLoading)) return <LoadingGate />
  if (!session) return <Navigate to="/onboarding" replace />
  if (onboarding?.app_access === false) return <AccountRestricted status={onboarding?.account_status} />
  if (!onboarding?.onboarding_complete) return <Navigate to="/onboarding" replace />
  return children
}
