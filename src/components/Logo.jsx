export default function Logo({ compact = false, markOnly = false, className = '' }) {
  return (
    <div className={`brand ${compact ? 'brand--compact' : ''} ${markOnly ? 'brand--mark-only' : ''} ${className}`} aria-label="CodaVybes Powered by CodaBite">
      <svg className="brand-symbol" viewBox="0 0 52 52" role="img" aria-hidden="true">
        <defs>
          <linearGradient id="codaMarkA" x1="7" y1="8" x2="44" y2="44" gradientUnits="userSpaceOnUse">
            <stop stopColor="var(--brand-violet)"/>
            <stop offset="1" stopColor="var(--brand-blue)"/>
          </linearGradient>
        </defs>
        <path d="M38.8 10.2A18.5 18.5 0 1 0 39.5 41" fill="none" stroke="url(#codaMarkA)" strokeWidth="7.4" strokeLinecap="round"/>
        <path d="M21.5 16.8 27 35.3l8-18.5" fill="none" stroke="var(--brand-ink)" strokeWidth="6" strokeLinecap="round" strokeLinejoin="round"/>
        <circle cx="41.4" cy="11.8" r="3.6" fill="var(--brand-highlight)"/>
      </svg>
      {!compact && !markOnly && <span className="brand-lockup"><strong>CodaVybes</strong><small>Powered by CodaBite</small></span>}
    </div>
  )
}
