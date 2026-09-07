export default function PlusBadge({ active, size = 17, label = 'CodaVybes+ member', className = '' }) {
  if (!active) return null
  return (
    <span className={`plus-badge ${className}`.trim()} title={label} aria-label={label} role="img">
      <svg width={size} height={size} viewBox="0 0 20 20" aria-hidden="true" focusable="false">
        <circle className="plus-badge__disc" cx="10" cy="10" r="8.35"/>
        <path className="plus-badge__star" d="M10 4.45l1.55 3.13 3.46.5-2.5 2.44.59 3.44L10 12.34l-3.1 1.62.59-3.44-2.5-2.44 3.46-.5L10 4.45z"/>
      </svg>
    </span>
  )
}
