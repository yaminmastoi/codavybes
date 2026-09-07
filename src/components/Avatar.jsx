export default function Avatar({ initials = 'V', size = 'md', online = false, src = '', alt = '' }) {
  return (
    <div className={`avatar avatar--${size}`}>
      {src ? <img className="avatar-image" src={src} alt={alt || `${initials} profile`} loading="lazy" referrerPolicy="no-referrer"/> : <span>{initials}</span>}
      {online && <i className="avatar-online" />}
    </div>
  )
}
