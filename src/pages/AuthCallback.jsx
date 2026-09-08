import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { AppLaunchLoader } from '../components/Loaders'
import { completeAuthCallback } from '../services/authRedirectService'

export default function AuthCallback() {
  const navigate = useNavigate()
  const [error, setError] = useState('')

  useEffect(() => {
    let mounted = true
    completeAuthCallback(window.location.href)
      .then((destination) => { if (mounted) navigate(destination || '/', { replace: true }) })
      .catch((reason) => { if (mounted) setError(reason.message || 'Authentication could not be completed.') })
    return () => { mounted = false }
  }, [navigate])

  if (!error) return <AppLaunchLoader label="Finishing sign in" />
  return <main className="auth-callback-error">
    <h1>Sign in could not finish.</h1>
    <p>{error}</p>
    <button className="btn btn--primary" onClick={() => navigate('/onboarding', { replace: true })}>Back to sign in</button>
  </main>
}
