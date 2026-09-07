import { useEffect, useState } from 'react'
import { Navigate } from 'react-router-dom'
import { ShieldAlert } from 'lucide-react'
import { adminService } from '../services/adminService'

export default function AdminGuard({ children }) {
  const [state, setState] = useState({ loading: true, session: null, error: '' })

  useEffect(() => {
    let alive = true
    adminService.session()
      .then((session) => alive && setState({ loading: false, session, error: '' }))
      .catch((error) => alive && setState({ loading: false, session: null, error: error.message || 'Admin access denied' }))
    return () => { alive = false }
  }, [])

  if (state.loading) return <div className="hq-gate"><div className="hq-loader"/><strong>Opening CodaVybes HQ…</strong></div>
  if (!state.session) return <Navigate to="/you" replace state={{ hqError: state.error }} />
  return children
}
