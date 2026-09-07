export default function VerifiedBadge({ verified, size = 16, label = 'Verified account', className = '' }) {
  if (!verified) return null
  return (
    <span className={`verified-badge ${className}`.trim()} title={label} aria-label={label} role="img">
      <svg width={size} height={size} viewBox="0 0 20 20" aria-hidden="true" focusable="false">
        <path className="verified-badge__seal" d="M10 1.45l2.05 1.32 2.43-.08.75 2.31 2.02 1.36-.83 2.28.83 2.28-2.02 1.36-.75 2.31-2.43-.08L10 15.83l-2.05-1.32-2.43.08-.75-2.31-2.02-1.36.83-2.28-.83-2.28L4.77 5l.75-2.31 2.43.08L10 1.45z"/>
        <path className="verified-badge__check" d="M6.65 8.72l2.06 2.05 4.62-4.63"/>
      </svg>
    </span>
  )
}
