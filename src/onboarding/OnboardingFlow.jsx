import { useEffect, useRef, useState } from 'react'
import { ArrowLeft, Check, Eye, EyeOff, Gamepad2, Link2, Mail, MonitorSmartphone, ShieldCheck, Sparkles, X, Zap } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import Logo from '../components/Logo'
import InterestIcon from '../components/InterestIcon'
import SetupRequired from '../components/SetupRequired'
import { useAuth } from '../context/AuthContext'
import { interests as fallbackInterests } from '../data/mock'
import {
  signInWithGoogle,
  signInWithX,
} from '../services/authService'
import {
  checkUsernameAvailability,
  claimUsername,
  completeOnboarding,
  listInterests,
  saveInterests,
  saveProfileDetails,
  setBirthDateAndGender,
} from '../services/onboardingService'
import {
  beginPasswordSecondFactor,
  clearPendingSecondFactor,
  getPendingSecondFactor,
  resendSecondFactor,
  verifySecondFactor,
} from '../services/secondFactorService'

const orderedSteps = ['welcome', 'email', 'otp', 'username', 'identity', 'profile', 'interests', 'reveal']

const fallbackSlugOverrides = { 'Late Night Talks': 'night_owls', Fitness: 'gym' }

const genderOptions = [
  { value: 'male', label: 'Male' },
  { value: 'female', label: 'Female' },
  { value: 'non_binary', label: 'Non-binary' },
  { value: 'other', label: 'Other' },
  { value: 'prefer_not_to_say', label: 'Prefer not to say' },
]

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
  if (!state.username) return 'username'
  if (!state.birth_date_set || !state.gender_set) return 'identity'
  if (!state.display_name) return 'profile'
  if (!Array.isArray(state.interests) || state.interests.length < 3) return 'interests'
  return 'reveal'
}

export default function OnboardingFlow() {
  const navigate = useNavigate()
  const { configured, loading, onboardingLoading, session, onboarding, refreshOnboarding } = useAuth()
  const [step, setStep] = useState('welcome')
  const [authMode, setAuthMode] = useState('signup')
  const [pendingChallenge, setPendingChallenge] = useState(() => getPendingSecondFactor())

  useEffect(() => {
    const syncPending = (event) => setPendingChallenge(event?.detail || getPendingSecondFactor())
    const clearPending = () => setPendingChallenge(null)
    window.addEventListener('codavybes:otp-pending', syncPending)
    window.addEventListener('codavybes:otp-cleared', clearPending)
    return () => {
      window.removeEventListener('codavybes:otp-pending', syncPending)
      window.removeEventListener('codavybes:otp-cleared', clearPending)
    }
  }, [])

  useEffect(() => {
    if (loading || onboardingLoading || !configured) return
    const pending = getPendingSecondFactor()
    if (!session && pending) {
      setPendingChallenge(pending)
      setStep('otp')
      return
    }
    if (session) {
      const next = pickStepFromState(onboarding)
      if (next === 'complete') navigate('/home', { replace: true })
      else setStep(next)
    } else if (step !== 'email' && step !== 'otp') {
      setStep('welcome')
    }
  }, [configured, loading, onboardingLoading, session, onboarding, navigate, step])

  if (!configured) return <SetupRequired />

  const visibleIndex = Math.max(0, orderedSteps.indexOf(step))
  const progress = ((visibleIndex + 1) / orderedSteps.length) * 100

  function back() {
    if (step === 'welcome') return
    if (!session) {
      if (step === 'otp') { clearPendingSecondFactor(); setPendingChallenge(null) }
      setStep(step === 'email' ? 'welcome' : 'welcome')
      return
    }
    const map = {
      username: 'welcome',
      identity: 'username',
      profile: 'identity',
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
          <h1>Real people.<br/><span>Better CodaVybes.</span></h1>
          <p>Meet, talk, play and build a reputation that follows you across every screen.</p>
        </div>
        <div className="onboarding-brand-features">
          <div><span><Link2 size={19}/></span><strong>Build Bonds</strong><small>Connections that actually grow.</small></div>
          <div><span><Zap size={19}/></span><strong>Earn Aura</strong><small>Reputation you cannot buy.</small></div>
          <div><span><Gamepad2 size={19}/></span><strong>Enter Rooms</strong><small>Hang out instead of just scrolling.</small></div>
          <div><span><MonitorSmartphone size={19}/></span><strong>Everywhere</strong><small>Web, mobile and desktop. One account.</small></div>
        </div>
        <div className="onboarding-brand-foot"><ShieldCheck size={15}/><span>Private by design · Open discovery · Synced in real time</span></div>
      </aside>
      <div className="onboarding-card">
        <header className="onboarding-topbar">
          <button className="icon-btn" onClick={back} disabled={step === 'welcome'}><ArrowLeft size={20} /></button>
          <Logo />
          <span className="step-count">{`${visibleIndex + 1}/${orderedSteps.length}`}</span>
        </header>
        <div className="progress"><span style={{ width: `${progress}%` }} /></div>

        {step === 'welcome' && <Welcome onGoogle={signInWithGoogle} onX={signInWithX} onEmail={() => openEmail('signup')} onLogin={() => openEmail('login')} />}
        {step === 'email' && <EmailStep mode={authMode} setMode={setAuthMode} onForgotPassword={() => navigate('/forgot-password')} onChallenge={(challenge) => { setPendingChallenge(challenge); setStep('otp') }} />}
        {step === 'otp' && <OtpStep challenge={pendingChallenge} onChallenge={setPendingChallenge} onVerified={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'username' && <UsernameStep initialValue={onboarding?.username || ''} onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'identity' && <IdentityStep initialBirthDate={onboarding?.birth_date || ''} initialGender={onboarding?.gender || ''} onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'profile' && <ProfileStep initialName={onboarding?.display_name || ''} initialBio={onboarding?.bio || ''} onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'interests' && <InterestsStep initialSelected={onboarding?.interests || []} onNext={async () => { const state = await refreshOnboarding(); setStep(pickStepFromState(state)) }} />}
        {step === 'reveal' && <RevealStep aura={onboarding?.aura_total || 1} onNext={async () => {
          await completeOnboarding()
          await refreshOnboarding()
          navigate('/home', { replace: true })
        }} />}
        <footer className="onboarding-codabite">Powered by <strong>CodaBite</strong></footer>
      </div>
    </div>
  )
}

function Welcome({ onGoogle, onX, onEmail, onLogin }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    const completed = () => setBusy(false)
    const failed = (event) => { setBusy(false); setError(event.detail || 'Social sign in could not finish.') }
    window.addEventListener('codavybes:auth-complete', completed)
    window.addEventListener('codavybes:auth-error', failed)
    return () => {
      window.removeEventListener('codavybes:auth-complete', completed)
      window.removeEventListener('codavybes:auth-error', failed)
    }
  }, [])

  async function oauth(provider) {
    try {
      setBusy(true); setError('')
      await provider()
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
      <button className="btn btn--light" onClick={() => oauth(onGoogle)} disabled={busy}>{busy ? 'Opening sign in…' : 'Continue with Google'}</button>
      <button className="btn btn--outline" onClick={onEmail}><Mail size={18}/> Continue with Email</button>
      <button className="btn btn--outline" onClick={() => oauth(onX)} disabled={busy}><span className="x-auth-mark">𝕏</span> Continue with X</button>
      <button className="btn btn--ghost" onClick={onLogin}>Sign in with email/password</button>
    </div>
  </section>
}

function EmailStep({ mode, setMode, onForgotPassword, onChallenge }) {
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
      const challenge = await beginPasswordSecondFactor({ mode, email, password })
      onChallenge(challenge)
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  return <section className="step">
    <p className="eyebrow">YOUR ACCOUNT</p>
    <h2>{mode === 'signup' ? 'Create your account' : 'Welcome back'}</h2>
    <p className="muted copy">{mode === 'signup' ? 'Create your account, then verify the 4-digit code sent to this inbox before onboarding unlocks.' : 'Enter your email and password first. A 4-digit code will then be sent to your registered email.'}</p>
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

function OtpStep({ challenge, onChallenge, onVerified }) {
  const [digits, setDigits] = useState(['', '', '', ''])
  const [busy, setBusy] = useState(false)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')
  const inputs = useRef([])

  useEffect(() => { inputs.current[0]?.focus() }, [])

  function setDigit(index, value) {
    const digit = String(value || '').replace(/\D/g, '').slice(-1)
    setDigits((current) => current.map((item, i) => i === index ? digit : item))
    if (digit && index < 3) inputs.current[index + 1]?.focus()
  }

  function keyDown(index, event) {
    if (event.key === 'Backspace' && !digits[index] && index > 0) inputs.current[index - 1]?.focus()
  }

  function paste(event) {
    const code = event.clipboardData.getData('text').replace(/\D/g, '').slice(0, 4)
    if (code.length !== 4) return
    event.preventDefault()
    setDigits(code.split(''))
    inputs.current[3]?.focus()
  }

  async function submit(event) {
    event?.preventDefault()
    const code = digits.join('')
    if (!/^\d{4}$/.test(code)) return
    try {
      setBusy(true); setError(''); setMessage('')
      await verifySecondFactor(code)
      await onVerified()
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  async function resend() {
    try {
      setBusy(true); setError(''); setMessage('')
      const next = await resendSecondFactor()
      onChallenge(next)
      setDigits(['', '', '', ''])
      setMessage('A new 4-digit code was sent.')
      setTimeout(() => inputs.current[0]?.focus(), 0)
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  const destination = challenge?.masked_email || challenge?.email || 'your registered email'
  return <section className="step verify-step otp-step">
    <div className="mail-orb"><Mail size={32}/></div>
    <p className="eyebrow">2-STEP VERIFICATION</p>
    <h2>Enter your 4-digit code.</h2>
    <p className="muted copy">We sent a one-time verification code to <strong>{destination}</strong>. The code expires in 5 minutes.</p>
    <form onSubmit={submit}>
      <div className="otp-grid" onPaste={paste} aria-label="4 digit email verification code">
        {digits.map((digit, index) => <input
          key={index}
          ref={(node) => { inputs.current[index] = node }}
          value={digit}
          onChange={(event) => setDigit(index, event.target.value)}
          onKeyDown={(event) => keyDown(index, event)}
          inputMode="numeric"
          autoComplete={index === 0 ? 'one-time-code' : 'off'}
          maxLength={1}
          aria-label={`Digit ${index + 1}`}
        />)}
      </div>
      <div className="notice"><ShieldCheck size={17}/> Password/social sign-in is only completed after this email code is verified.</div>
      {message && <div className="notice success-box"><Check size={18}/>{message}</div>}
      {error && <div className="notice error-box">{error}</div>}
      <button className="btn btn--primary" disabled={digits.join('').length !== 4 || busy}>{busy ? 'Verifying…' : 'Verify & continue'}</button>
    </form>
    <button type="button" className="btn btn--ghost" onClick={resend} disabled={busy}>Resend code</button>
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

function IdentityStep({ initialBirthDate, initialGender, onNext }) {
  const [birthDate, setBirthDateValue] = useState(initialBirthDate || '')
  const [gender, setGender] = useState(initialGender || '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const today = new Date().toISOString().slice(0, 10)

  async function submit() {
    try {
      setBusy(true); setError('')
      await setBirthDateAndGender({ birthDate, gender })
      await onNext()
    } catch (e) { setError(e.message) }
    finally { setBusy(false) }
  }

  return <section className="step">
    <p className="eyebrow">ABOUT YOU</p>
    <h2>DOB & gender</h2>
    <p className="muted copy">Add your date of birth and gender to complete your profile setup. DOB does not restrict who you can discover, follow, befriend, message or interact with.</p>
    <label>Date of birth<div className="input-wrap date-input"><input type="date" value={birthDate} onChange={(e) => setBirthDateValue(e.target.value)} max={today} disabled={Boolean(initialBirthDate)}/></div></label>
    <fieldset className="gender-fieldset">
      <legend>Gender</legend>
      <div className="gender-options" role="radiogroup" aria-label="Gender">
        {genderOptions.map((option) => <button
          type="button"
          key={option.value}
          role="radio"
          aria-checked={gender === option.value}
          className={gender === option.value ? 'gender-option is-selected' : 'gender-option'}
          onClick={() => setGender(option.value)}
        >
          <span>{option.label}</span>
          {gender === option.value && <Check size={16} aria-hidden="true"/>}
        </button>)}
      </div>
    </fieldset>
    <div className="notice"><ShieldCheck size={17}/> These profile details are stored in Supabase. They are not used as an age gate.</div>
    {error && <div className="notice error-box">{error}</div>}
    <button className="btn btn--primary" onClick={submit} disabled={!birthDate || !gender || busy}>{busy ? 'Saving…' : 'Continue'}</button>
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
