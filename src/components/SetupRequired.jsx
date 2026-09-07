import Logo from './Logo'

export default function SetupRequired() {
  return (
    <div className="onboarding-shell">
      <div className="orb orb--one" />
      <div className="orb orb--two" />
      <div className="onboarding-card setup-card">
        <Logo />
        <p className="eyebrow">BACKEND SETUP</p>
        <h1>Connect Supabase.</h1>
        <p className="lead">The UI is ready. Add your project URL and publishable key, then run the included SQL migration.</p>
        <div className="code-card">
          <code>VITE_SUPABASE_URL=...</code>
          <code>VITE_SUPABASE_PUBLISHABLE_KEY=...</code>
        </div>
        <p className="muted copy">See <strong>README.md</strong> and <strong>supabase/SETUP.md</strong> in the project.</p>
      </div>
    </div>
  )
}
