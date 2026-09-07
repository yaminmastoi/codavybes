import { Navigate } from 'react-router-dom'
import { useCommerce } from '../context/CommerceContext'
import { PageSkeleton } from './Loaders'

export default function CommerceGate({ feature, children }) {
  const commerce = useCommerce()
  if (commerce.loading) return <div className="page"><PageSkeleton variant="compact" count={2}/></div>
  const enabled = feature === 'shop' ? commerce.shopEnabled : feature === 'plus' ? commerce.plusEnabled : feature === 'topups' ? commerce.topupsEnabled : true
  if (!enabled) return <Navigate to="/home" replace />
  return children
}
