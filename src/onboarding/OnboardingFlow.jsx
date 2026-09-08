import { useEffect, useState } from 'react'
import { ArrowLeft, Check, Eye, EyeOff, Gamepad2, Link2, Mail, MonitorSmartphone, ShieldCheck, Sparkles, X, Zap } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Logo from '../components/Logo'
import InterestIcon from '../components/InterestIcon'
import SetupRequired from '../components/SetupRequired'
import { useAuth } from '../context/AuthContext'
import { interests as fallbackInterests } from '../data/mock'
import {
  resendSignupConfirmation,
  signInWithEmail,
  signInWithGoogle,
  signUpWithEmail,
} from '../services/authService'
import {
  checkUsernameAvailability,
  claimUsername,
  completeOnboarding,
  listInterests,
  saveInterests,
  saveProfileDetails,
  setBirthDate,
} from '../services/onboardingService'
import { supabase } from '../lib/supabase'

const orderedSteps = ['welcome', 'email', 'verify', 'username', 'dob', 'profile', 'interests', 'reveal']

const fallbackSlugOverrides = { 'Late Night Talks': 'night_owls', Fitness: 'gym' }

function normalizeFallbackInterest(label) {
  return {
    slug: fallbackSlugOverrides[label] || label.toLowerCase().replace(/\s+/g, '_'),
    label,
    icon: null,
  }
}

function passwordScore(password) {
  return [
    password.length >= 8,
    /[a-z]/.test(password) && /[A-Z]/.test(password),
    /\d/.test(password),
    /[^A-Za-z0-9]/.test(password),
  ].filter(Boolean).length
}

function pickStepFromState(state) {
  if (!state) return 'username'
  if (state.onboarding_complete) return 'complete'
  if (state.eligibility_status === 'ineligible') return 'ineligible'
  if (!state.username) return 'username'
  if (!state.birth_date_set) return 'dob'
  if (!state.display_name) return 'profile'
  if (!Array.isArray(state.interests) || state.interests.length < 3) return 'interests'
  return 'reveal'
}

export default function OnboardingFlow() {
  const navigate = useNavigate()
  const { configured, loading, onboardingLoading, session, onboarding, refreshOnboarding } = useAuth()
  const [step, setStep] = useState('welcome')
  const [authMode, setAuthMode] = useState('signup')
  const [pendingEmail, setPendingEmail] = useState('')

  useEffect(() => {
    if (loading || onboardingLoading || !configured) return
    if (session) {
      const next = pickStepFromState(onboarding)
      if (next === 'complete') navigate('/home', { replace: true })
      else setStep(next)
    } else if (step !== 'email' && step !== 'verify') {
      setStep('welcome')
    }
  }, [configured, loading, onboardingLoading, session, onboarding, navigate])

  if (!configured) return <SetupRequired />

  const visibleIndex = Math.max(0, orderedSteps.indexOf(step))
  const progress = ((visibleIndex + 1) / orderedSteps.length) * 100

  function back() {
    if (step === 'welcome') return
    if (!session) {
      if (step === 'verify') setStep('email')
      else setStep('welcome')
      return
    }
    const map = {
      username: 'welcome',
      dob: 'username',
      profile: 'dob',
      interests: 'profile',
      reveal: 'interests',
    }
    setStep(map[step] || 'welcome')
  }

  function openEmail(mode) {
    setAuthMode(mode)
    setStep('email')
  }

  return (
    <div className="onboarding-shell">
      <div className="orb orb--one" />
      <div className="orb orb--two" />
      <aside className="onboarding-brand-panel">
        <Logo className="onboarding-brand-logo"/>
        <div className="onboarding-brand-copy">
          <p className="eyebrow">SOCIAL, REBUILT</p>
          <h1>Real people.<br/><span>Better CodaVybess.</span></h1>
          <p>Meet, talk, play and build a reputation that follows you across every screen.</p>
        </div>
        <div className="onboarding-brand-features">
          <div><span><Link2 size={19}/></span><strong>Build Bonds</strong><small>Connections that actually grow.</small></div>
          <div><span><Zap size={19}/></span><strong>Earn Aura</strong><small>Reputation you cannot buy.</small></div>
          <div><span><Gamepad2 size={19}/></span><strong>Enter Rooms</strong><small>Hang out instead of just scrolling.</small></div>
          <div><span><MonitorSmartphone size={19}/></span><strong>Everywhere</strong><small>Web, mobile and desktop. One account.</small></div>
        </div>
        <div className="onboarding-brand-foot"><ShieldCheck size={15}/><span>Private by design · Age-safe discovery · Synced in real time</span></div>
      </aside>
      <div className="onboarding-card">
        <header className="onboarding-topbar">
          <button className="icon-btn" onClick={back} disabled={step === 'welcome' || step === 'ineligible'}><ArrowLeft size={20} /></button>
          <Logo />
          <span className="step-count">{step === 'ineligible' ? 'Gate' : `${visibleIndex + 1}/${orderedSteps.length}`}</span>
        </header>
        {step !== 'ineligible' && <div className="progress"><span style={{ width: `${progress}%` }} /></div>}

        {step === 'welcome' && <Welcome onGoogle={signInWithGoogle} onEmail={() => openEmail('signup')} onLogin={() => openEmail('login')} />}
        {step === 'email' && <EmailStep mode={authMode} setMode={setAuthMode} onForgotPassword={() => navigate('/forgot-password')} onVerifiedEmail={(email) => { setPendingEmail(email); setStep('verify') }} onAuthenticated={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'verify' && <VerifyStep email={pendingEmail} onContinue={async () => {
          const { data } = await supabase.auth.getSession()
          if (!data.session) throw new Error('Email is not confirmed in this browser yet. Open the verification link, then try again.')
          const state = await refreshOnboarding()
          setStep(pickStepFromState(state))
        }} />}
        {step === 'username' && <UsernameStep initialValue={onboarding?.username || ''} onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'dob' && <DobStep onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'ineligible' && <IneligibleStep />}
        {step === 'profile' && <ProfileStep initialName={onboarding?.display_name || ''} initialBio={onboarding?.bio || ''} onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'interests' && <InterestsStep initialSelected={onboarding?.interests || []} onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'reveal' && <RevealStep aura={onboarding?.aura_total || 1} onNext={async () => {
          await completeOnboarding()
          await refreshOnboarding()
          navigate('/home', { replace: true })
        }} />}
      </div>
    </div>
  )
}

function Welcome({ onGoogle, onEmail, onLogin }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function google() {
    try {
      setBusy(true); setError('')
      await onGoogle()
    } catch (e) {
      setError(e.message)
      setBusy(false)
    }
  }

  return <section className="step hero-step">
    <div className="hero-emblem"><Logo markOnly/></div>
    <p className="eyebrow">A NEW SOCIAL UNIVERSE</p>
    <h1>Same people.<br/><span>Better vibes.</span></h1>
    <p className="lead">Meet people, build bonds, play together and earn Aura.</p>
    {error && <div className="notice error-box">{error}</div>}
    <div className="stack">
      <button className="btn btn--light" onClick={google} disabled={busy}>{busy ? 'Opening Google…' : 'Continue with Google'}</button>
      <button className="btn btn--outline" onClick={onEmail}><Mail size={18}/> Continue with Email</button>
      <button className="btn btn--ghost" onClick={onLogin}>Log in</button>
    </div>
  </section>
}

function EmailStep({ mode, setMode, onForgotPassword, onVerifiedEmail, onAuthenticated }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const score = passwordScore(password)
  const validEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())
  const validPassword = mode === 'login' ? password.length >= 1 : score === 4

  async function submit(event) {
    event.preventDefault()
    if (!validEmail || !validPassword) return
    try {
      setBusy(true); setError('')
      if (mode === 'signup') {
        const data = await signUpWithEmail({ email, password })
        if (data.session) await onAuthenticated()
        else onVerifiedEmail(email)
      } else {
        await signInWithEmail({ email, password })
        await onAuthenticated()
      }
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  return <section className="step">
    <p className="eyebrow">YOUR ACCOUNT</p>
    <h2>{mode === 'signup' ? 'Create your account' : 'Welcome back'}</h2>
    <p className="muted copy">{mode === 'signup' ? 'Use an inbox you actually control. Your email must be confirmed before CodaVybes onboarding unlocks.' : 'Sign in with your verified email and password.'}</p>
    <form onSubmit={submit}>
      <label>Email<div className="input-wrap"><Mail size={18}/><input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" autoComplete="email" />{validEmail && <Check className="valid" size={18}/>}</div></label>
      <label>Password<div className="input-wrap"><ShieldCheck size={18}/><input type={showPassword ? 'text' : 'password'} value={password} onChange={(e) => setPassword(e.target.value)} placeholder={mode === 'signup' ? 'Create a strong password' : 'Your password'} autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} /><button type="button" className="input-icon" onClick={() => setShowPassword((v) => !v)}>{showPassword ? <EyeOff size={18}/> : <Eye size={18}/>}</button></div></label>
      {mode === 'signup' && <><div className="strength">{[1,2,3,4].map((n) => <span key={n} className={score >= n ? '' : 'dim'} />)}</div><small className={score === 4 ? 'success' : 'muted'}>8+ chars · uppercase/lowercase · number · special character</small></>}
      {error && <div className="notice error-box">{error}</div>}
      {mode === 'login' && <button type="button" className="auth-text-link auth-text-link--button" onClick={onForgotPassword}>Forgot password?</button>}
      <button className="btn btn--primary" disabled={!validEmail || !validPassword || busy}>{busy ? 'Working…' : (mode === 'signup' ? 'Create account' : 'Log in')}</button>
    </form>
    <button className="btn btn--ghost mode-switch" onClick={() => { setError(''); setMode(mode === 'signup' ? 'login' : 'signup') }}>{mode === 'signup' ? 'Already on CodaVybes? Log in' : 'New here? Create account'}</button>
  </section>
}

function VerifyStep({ email, onContinue }) {
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  async function verify() {
    try {
      setBusy(true); setError('')
      await onContinue()
    } catch (e) {
      setError(e.message)
    } finally { setBusy(false) }
  }

  async function resend() {
    try {
      setBusy(true); setError(''); setMessage('')
      await resendSignupConfirmation(email)
      setMessage('Verification email sent again.')
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  return <section className="step verify-step">
    <div className="mail-orb"><Mail size={32}/></div>
    <p className="eyebrow">VERIFY YOUR EMAIL</p>
    <h2>Check your inbox.</h2>
    <p className="muted copy">We sent a confirmation link to <strong>{email || 'your email'}</strong>. CodaVybes will not unlock the identity setup until that inbox is verified.</p>
    <div className="notice"><ShieldCheck size={17}/> Random/unreachable emails cannot finish onboarding.</div>
    {message && <div className="notice success-box"><Check size={18}/>{message}</div>}
    {error && <div className="notice error-box">{error}</div>}
    <button className="btn btn--primary" onClick={verify} disabled={busy}>{busy ? 'Checking…' : "I've verified — continue"}</button>
    <button className="btn btn--ghost" onClick={resend} disabled={busy}>Resend verification email</button>
  </section>
}

function UsernameStep({ initialValue, onNext }) {
  const [username, setUsername] = useState(initialValue)
  const [availability, setAvailability] = useState(null)
  const [checking, setChecking] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const validFormat = /^[A-Za-z0-9_]{3,20}$/.test(username)

  useEffect(() => {
    setAvailability(null)
    if (!validFormat) return
    const timer = setTimeout(async () => {
      try {
        setChecking(true)
        setAvailability(await checkUsernameAvailability(username))
      } catch (e) {
        setAvailability({ available: false, reason: e.message })
      } finally { setChecking(false) }
    }, 420)
    return () => clearTimeout(timer)
  }, [username, validFormat])

  async function submit() {
    try {
      setBusy(true); setError('')
      await claimUsername(username)
      await onNext()
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  return <section className="step">
    <p className="eyebrow">YOUR IDENTITY</p>
    <h2>Claim your <span className="gold">@</span></h2>
    <p className="muted copy">One username across all of CodaVybes. Case doesn't create duplicates, and normal users can change it only once every 30 days.</p>
    <label>Username<div className="input-wrap"><span>@</span><input value={username} onChange={(e) => setUsername(e.target.value.replace(/\s/g, ''))} placeholder="mastoi_yamin" maxLength={20}/>{checking ? <span className="tiny-loader"/> : availability?.available ? <Check className="valid" size={18}/> : availability && <X className="invalid" size={18}/>}</div></label>
    {validFormat && availability && <div className={availability.available ? 'notice success-box' : 'notice error-box'}>{availability.available ? <Check size={18}/> : <X size={18}/>} {availability.reason}</div>}
    {!validFormat && username.length > 0 && <div className="notice">Use 3–20 letters, numbers or underscores.</div>}
    <ul className="rules"><li>Globally unique + case-insensitive</li><li>30-day self-change cooldown</li><li>Old username protected for 90 days after a change</li></ul>
    {error && <div className="notice error-box">{error}</div>}
    <button className="btn btn--primary" onClick={submit} disabled={!availability?.available || checking || busy}>{busy ? 'Claiming…' : 'Claim username'}</button>
  </section>
}

function DobStep({ onNext }) {
  const [birthDate, setBirthDateValue] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const today = new Date().toISOString().slice(0, 10)

  async function submit() {
    try {
      setBusy(true); setError('')
      const result = await setBirthDate(birthDate)
      if (!result?.eligible) throw new Error('CodaVybes is available for ages 10 and up.')
      await onNext()
    } catch (e) {
      setError(e.message)
      if (/outside CodaVybes/.test(e.message)) window.location.reload()
    } finally { setBusy(false) }
  }

  return <section className="step">
    <p className="eyebrow">AGE & SAFETY</p>
    <h2>When's your birthday?</h2>
    <p className="muted copy">DOB is private. It powers the 10+ eligibility gate and age-aware safety controls, and normal users cannot edit it later from Settings.</p>
    <label>Birthday<div className="input-wrap date-input"><input type="date" value={birthDate} onChange={(e) => setBirthDateValue(e.target.value)} max={today}/></div></label>
    <div className="notice"><ShieldCheck size={17}/> Current launch rule: age 10+. Eligible members can discover and connect across age groups; blocks and account restrictions decide availability.</div>
    {error && <div className="notice error-box">{error}</div>}
    <button className="btn btn--primary" onClick={submit} disabled={!birthDate || busy}>{busy ? 'Checking…' : 'Check eligibility'}</button>
  </section>
}

function IneligibleStep() {
  return <section className="step ineligible-step">
    <div className="gate-icon"><ShieldCheck size={34}/></div>
    <p className="eyebrow">CodaVybes AGE GATE</p>
    <h2>CodaVybes is available from age 10.</h2>
    <p className="muted copy">Your DOB is locked for safety. A genuine correction will require a support/admin review later; changing browser data cannot bypass the gate.</p>
    <div className="notice">The username claimed during onboarding has been released because this account is below CodaVybes’s minimum age.</div>
    <button className="btn btn--outline profile-signout" onClick={() => import('../services/authService').then(({ signOut }) => signOut())}>Sign out</button>
  </section>
}

function ProfileStep({ initialName, initialBio, onNext }) {
  const [displayName, setDisplayName] = useState(initialName)
  const [bio, setBio] = useState(initialBio)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const initials = displayName.trim().split(/\s+/).slice(0, 2).map((x) => x[0]?.toUpperCase()).join('') || 'V'

  async function submit() {
    try {
      setBusy(true); setError('')
      await saveProfileDetails({ displayName, bio })
      await onNext()
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  return <section className="step">
    <p className="eyebrow">PROFILE</p>
    <h2>Make it yours.</h2>
    <div className="profile-avatar">{initials}<span>+</span></div>
    <label>Display name<div className="input-wrap"><input value={displayName} onChange={(e) => setDisplayName(e.target.value)} maxLength={40} placeholder="Yamin Mastoi"/></div></label>
    <label>Bio<div className="input-wrap"><input value={bio} onChange={(e) => setBio(e.target.value)} maxLength={300} placeholder="F1. Tech. Memes. Bad decisions."/></div></label>
    <small className="muted">Profile photo upload comes with the private Storage phase; identity data here is already real.</small>
    {error && <div className="notice error-box">{error}</div>}
    <button className="btn btn--primary" onClick={submit} disabled={!displayName.trim() || busy}>{busy ? 'Saving…' : 'Continue'}</button>
  </section>
}

function InterestsStep({ initialSelected, onNext }) {
  const [items, setItems] = useState([])
  const [selected, setSelected] = useState(initialSelected)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    listInterests()
      .then(setItems)
      .catch(() => setItems(fallbackInterests.map(normalizeFallbackInterest)))
  }, [])

  const toggle = (slug) => setSelected((s) => s.includes(slug) ? s.filter((x) => x !== slug) : [...s, slug])

  async function submit() {
    try {
      setBusy(true); setError('')
      await saveInterests(selected)
      await onNext()
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  return <section className="step">
    <p className="eyebrow">PERSONALIZE</p>
    <h2>What are you into?</h2>
    <p className="muted copy">Pick at least 3. These become the first signals for Vibe Match and discovery.</p>
    <div className="chips">{items.map((i) => <button type="button" key={i.slug} className={selected.includes(i.slug) ? 'chip is-selected' : 'chip'} onClick={() => toggle(i.slug)}><InterestIcon interest={i} size={14}/>{i.label}</button>)}</div>
    {error && <div className="notice error-box">{error}</div>}
    <button className="btn btn--primary" onClick={submit} disabled={selected.length < 3 || busy}>{busy ? 'Saving…' : `Continue · ${selected.length} selected`}</button>
  </section>
}

function RevealStep({ aura, onNext }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function enter() {
    try {
      setBusy(true); setError('')
      await onNext()
    } catch (e) { setError(e.message); setBusy(false) }
  }

  return <section className="step reveal-step">
    <p className="eyebrow"><Sparkles size={13}/> YOUR VIBE IS</p>
    <div className="aura-orb"><Logo markOnly/></div>
    <h1>CHAOS<br/><span>ENERGY</span></h1>
    <p className="lead">You bring the fun, the chaos and the unfiltered energy.</p>
    <div className="reveal-score"><span><Zap size={15}/> Aura</span><strong>+{aura}</strong></div>
    <p className="muted">Aura is created server-side. The client cannot award itself points.</p>
    {error && <div className="notice error-box">{error}</div>}
    <button className="btn btn--primary" onClick={enter} disabled={busy}>{busy ? 'Entering…' : 'Enter CodaVybes →'}</button>
  </section>
}
