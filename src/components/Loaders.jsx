import Logo from './Logo'

export function AppLaunchLoader({ label = 'Opening CodaVybes' }) {
  return <div className="app-launch-loader" role="status" aria-live="polite">
    <div className="launch-brand-sequence" aria-hidden="true">
      <div className="launch-logo-wrap"><Logo markOnly/></div>
      <div className="launch-name-lockup"><strong>CodaVybes</strong><small>Powered by CodaBite</small></div>
    </div>
    <span className="launch-status-copy">{label}</span>
  </div>
}

export function PageSkeleton({ variant = 'feed', count = 3 }) {
  if (variant === 'discover') return <div className="skeleton-people-list" aria-hidden="true">
    {Array.from({ length: count }).map((_, i) => <div className="skeleton-person-row" key={i}><i className="skeleton-circle"/><span><b className="skeleton-line w-40"/><b className="skeleton-line w-72"/><b className="skeleton-line w-24"/></span><b className="skeleton-person-action"/></div>)}
  </div>
  return <div className={`skeleton-stack skeleton-stack--${variant}`} aria-hidden="true">
    {Array.from({ length: count }).map((_, i) => <div className="skeleton-card" key={i}>
      <div className="skeleton-head"><i className="skeleton-circle"/><span><b className="skeleton-line w-40"/><b className="skeleton-line w-24"/></span></div>
      <b className="skeleton-line w-90"/><b className="skeleton-line w-72"/>
      {variant !== 'compact' && <div className="skeleton-block"/>}
      <div className="skeleton-actions"><b/><b/><b/></div>
    </div>)}
  </div>
}


export function HomeSkeleton() {
  return <div className="page home-skeleton" aria-hidden="true">
    <div className="home-skeleton__head"><div className="skeleton-circle"/><div className="home-skeleton__name"><b className="skeleton-line w-40"/><b className="skeleton-line w-72"/></div><b className="home-skeleton__pill"/></div>
    <div className="home-skeleton__rank skeleton-card"><b className="skeleton-line w-24"/><b className="skeleton-line w-40"/><div className="skeleton-line w-90"/></div>
    <div className="home-skeleton__moves">{Array.from({length:4}).map((_,i)=><div className="skeleton-card home-skeleton__move" key={i}><i/><b className="skeleton-line w-40"/><b className="skeleton-line w-72"/></div>)}</div>
    <PageSkeleton variant="feed" count={3}/>
  </div>
}

export function InlineLoader({ label = 'Loading' }) {
  return <span className="inline-loader" role="status"><i/><span>{label}</span></span>
}
