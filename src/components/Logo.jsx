export default function Logo({ compact = false, markOnly = false, className = '' }) {
  return (
    <div className={`brand ${compact ? 'brand--compact' : ''} ${markOnly ? 'brand--mark-only' : ''} ${className}`} aria-label="CodaVybes">
      <span className="brand-symbol" aria-hidden="true">
        <img src="/brand/codavybes-mark.png" alt="" draggable="false" />
      </span>
      {!compact && !markOnly && <span className="brand-lockup"><strong>CodaVybes</strong><small>Connect. Discover. Chat.</small></span>}
    </div>
  )
}
