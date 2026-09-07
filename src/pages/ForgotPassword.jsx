import { useState } from 'react'
import { ArrowLeft, CheckCircle2, KeyRound, Mail, ShieldCheck } from 'lucide-react'
import { Link } from 'react-router-dom'
import Logo from '../components/Logo'
import SetupRequired from '../components/SetupRequired'
import { isSupabaseConfigured } from '../lib/supabase'
import { sendPasswordReset } from '../services/authService'

export default function ForgotPassword() {
  const [email, setEmail] = useState('')
  const [busy, setBusy] = useState(false)
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')
  const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())

  if (!isSupabaseConfigured) return <SetupRequired />

  async function submit(event) {
    event.preventDefault()
    if (!valid || busy) return
    try {
      setBusy(true); setError('')
      await sendPasswordReset(email)
      setSent(true)
    } catch (e) {
      setError(e.message || 'Could not start password recovery.')
    } finally { setBusy(false) }
  }

  return <main className="recovery-shell">
    <section className="recovery-brand">
      <Logo/>
      <div><p className="eyebrow">ACCOUNT RECOVERY</p><h1>Get back into CodaVybes.</h1><p>Secure recovery uses your verified inbox. We never reveal whether an email belongs to an account.</p></div>
      <div className="recovery-trust"><ShieldCheck size={17}/><span>Recovery links are handled by Supabase Auth and expire automatically.</span></div>
    </section>
    <section className="recovery-card surface">
      <Link className="icon-btn recovery-back" to="/onboarding" aria-label="Back to login"><ArrowLeft size={19}/></Link>
      {sent ? <div className="recovery-success"><CheckCircle2 size={34}/><p className="eyebrow">CHECK YOUR INBOX</p><h2>Recovery link sent.</h2><p>If an account exists for <strong>{email}</strong>, you'll receive a secure password reset link.</p><Link className="btn btn--primary" to="/onboarding">Back to login</Link></div> : <form className="recovery-form" onSubmit={submit}>
        <div className="recovery-icon"><KeyRound size={24}/></div>
        <p className="eyebrow">FORGOT PASSWORD</p>
        <h2>Reset your password</h2>
        <p className="muted">Enter your account email. For privacy, the confirmation looks the same whether or not that email is registered.</p>
        <label>Email<div className="input-wrap"><Mail size={18}/><input type="email" autoComplete="email" value={email} onChange={(e)=>setEmail(e.target.value)} placeholder="you@example.com"/></div></label>
        {error && <div className="notice error-box">{error}</div>}
        <button className="btn btn--primary recovery-submit" disabled={!valid || busy}>{busy ? 'Sending…' : 'Send recovery link'}</button>
        <Link className="auth-text-link" to="/onboarding">Remembered it? Log in</Link>
      </form>}
    </section>
  </main>
}
