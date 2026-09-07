import { Zap } from 'lucide-react'

export default function AuraPill({ value = 1, size = 'md', label = false }) {
  return (
    <div className={`aura-pill aura-pill--${size}`}>
      <Zap size={size === 'sm' ? 14 : 17} fill="currentColor" />
      <strong>+{value.toLocaleString()}</strong>
      {label && <span>Aura</span>}
    </div>
  )
}
