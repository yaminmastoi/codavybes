import { useEffect, useState } from 'react'
import { ArrowLeft, Bell, Check, ChevronRight, Coins, Cookie, Crown, FileText, KeyRound, Laptop, LogOut, MapPin, Moon, Palette, Shield, ShoppingBag, SlidersHorizontal, Sun, Volume2 } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { useTheme } from '../context/ThemeContext'
import { useCommerce } from '../context/CommerceContext'
import { signOut } from '../services/authService'
import { getPreferences, updatePreferences } from '../services/settingsService'
import { checkUsernameAvailability, claimUsername } from '../services/onboardingService'
import { getSystemNotificationPermission, requestSystemNotificationPermission, showSystemNotification, systemNotificationsSupported } from '../services/systemNotificationService'
import InstallVybeButton from '../components/InstallVybeButton'
import VerificationSettings from '../components/VerificationSettings'
import { analyticsConsentEnabled, getLocationSharingEnabled, setPreciseLocationSharing, telemetrySummary } from '../services/telemetryService'

function Toggle({ label, description, value, onChange, disabled = false }) {
  return <label className={`settings-toggle ${disabled ? 'is-disabled' : ''}`}><span><strong>{label}</strong><small>{description}</small></span><input type="checkbox" checked={!!value} disabled={disabled} onChange={(e) => onChange(e.target.checked)}/><i/></label>
}

function ThemeChoice({ value, current, icon: Icon, label, onClick }) {
  const active = current === value
  return <button className={`theme-choice ${active ? 'is-active' : ''}`} onClick={() => onClick(value)}><span><Icon size={19}/></span><strong>{label}</strong>{active && <Check size={15}/>}</button>
}

export default function Settings() {
  const navigate = useNavigate()
  const { user, onboarding, refreshOnboarding } = useAuth()
  const { preference, setTheme } = useTheme()
  const { topupsEnabled, shopEnabled, plusEnabled } = useCommerce()
  const [prefs, setPrefs] = useState(null)
  const [notice, setNotice] = useState('')
  const [editingUsername, setEditingUsername] = useState(false)
  const [usernameDraft, setUsernameDraft] = useState('')
  const [usernameCheck, setUsernameCheck] = useState(null)
  const [usernameBusy, setUsernameBusy] = useState(false)
  const [systemPermission, setSystemPermission] = useState(getSystemNotificationPermission())
  const [locationSharing, setLocationSharing] = useState(getLocationSharingEnabled())
  const [locationBusy, setLocationBusy] = useState(false)
  const [telemetryState, setTelemetryState] = useState(telemetrySummary())
  const preciseLocationEligible = (() => { const d=onboarding?.birth_date?new Date(`${onboarding.birth_date}T00:00:00`):null; if(!d||Number.isNaN(d.getTime()))return true; const now=new Date(); let age=now.getFullYear()-d.getFullYear(); const m=now.getMonth()-d.getMonth(); if(m<0||(m===0&&now.getDate()<d.getDate()))age--; return age>=18 })()

  useEffect(() => {
    getPreferences().then((p) => {
      setPrefs(p)
      if (p?.theme_preference && !localStorage.getItem('vybe-theme')) setTheme(p.theme_preference)
    }).catch((e) => setNotice(e.message))
  }, [])

  const set = async (key, value) => {
    const previous = prefs
    setPrefs((p) => ({ ...p, [key]: value }))
    try { const next = await updatePreferences({ [key]: value }); setPrefs(next); setNotice('Saved') }
    catch (e) { setPrefs(previous); setNotice(e.message) }
  }

  const changeTheme = async (next) => {
    setTheme(next)
    try { const updated = await updatePreferences({ theme_preference: next }); setPrefs(updated); setNotice(`Theme set to ${next}.`) }
    catch (e) { setNotice(e.message) }
  }

  const enableSystemNotifications = async () => {
    const permission = await requestSystemNotificationPermission()
    setSystemPermission(permission)
    if (permission === 'granted') { await set('system_notifications', true); window.dispatchEvent(new CustomEvent('vybe:system-notifications', { detail: true })) }
    else if (permission === 'denied') { await set('system_notifications', false); window.dispatchEvent(new CustomEvent('vybe:system-notifications', { detail: false })); setNotice('System notifications are blocked in your browser settings.') }
    else setNotice('System notifications are not supported on this device.')
  }


  const changeLocationSharing = async (enabled) => {
    if (locationBusy) return
    setLocationBusy(true); setNotice('')
    try {
      const result = await setPreciseLocationSharing(enabled)
      setLocationSharing(result.enabled)
      setTelemetryState(telemetrySummary())
      setNotice(result.enabled ? 'Precise location sharing enabled for this device.' : 'Precise location sharing disabled.')
    } catch (e) {
      setLocationSharing(getLocationSharingEnabled())
      setNotice(e.message)
    } finally { setLocationBusy(false) }
  }

  useEffect(() => { setUsernameDraft(onboarding?.username || '') }, [onboarding?.username])
  const nextUsername = onboarding?.username_next_change_at ? new Date(onboarding.username_next_change_at) : null
  const canChange = !nextUsername || nextUsername <= new Date()
  const checkUsername = async () => {
    if (!usernameDraft.trim() || usernameDraft.trim().toLowerCase() === (onboarding?.username || '').toLowerCase()) { setUsernameCheck(null); return }
    try { setUsernameCheck(await checkUsernameAvailability(usernameDraft.trim())) }
    catch (e) { setUsernameCheck({ available: false, reason: e.message }) }
  }
  const saveUsername = async () => {
    if (!canChange || usernameBusy) return
    setUsernameBusy(true); setNotice('')
    try { const result = await claimUsername(usernameDraft.trim()); await refreshOnboarding(); setEditingUsername(false); setUsernameCheck(null); setNotice(`Username updated to @${result?.username || usernameDraft.trim()}`) }
    catch (e) { setNotice(e.message) } finally { setUsernameBusy(false) }
  }

  return <div className="page settings-page">
    <header className="page-head page-head--back"><button className="icon-btn surface" onClick={() => navigate(-1)}><ArrowLeft size={20}/></button><div><p className="eyebrow">PREFERENCES</p><h1>Settings</h1></div><span className="head-spacer"/></header>
    {notice && <div className="settings-save-note">{notice}</div>}

    <section className="settings-section surface appearance-panel">
      <div className="settings-section__title"><Palette size={18}/><div><p className="eyebrow">APPEARANCE</p><h3>Choose your environment</h3></div></div>
      <div className="theme-grid">
        <ThemeChoice value="light" current={preference} icon={Sun} label="Light" onClick={changeTheme}/>
        <ThemeChoice value="dark" current={preference} icon={Moon} label="Dark" onClick={changeTheme}/>
        <ThemeChoice value="system" current={preference} icon={Laptop} label="System" onClick={changeTheme}/>
      </div>
      <p className="settings-caption">Light is the CodaVybes default. Dark mode keeps the same hierarchy, contrast and premium surfaces.</p>
    </section>

    <section className="settings-section surface">
      <div className="settings-section__title"><SlidersHorizontal size={18}/><div><p className="eyebrow">ACCOUNT</p><h3>Your identity</h3></div></div>
      <div className="settings-row settings-row--action"><span><strong>@{onboarding?.username}</strong><small>{canChange ? 'Username change available' : `Change available ${nextUsername.toLocaleDateString()}`}</small></span><button className="settings-inline-action" disabled={!canChange} onClick={() => { setEditingUsername((v) => !v); setUsernameCheck(null) }}>{canChange ? (editingUsername ? 'Cancel' : 'Change @') : 'Locked'}</button></div>
      {editingUsername && canChange && <div className="username-editor"><label><span>New username</span><div className="username-input-wrap"><b>@</b><input value={usernameDraft} maxLength={20} autoCapitalize="none" autoCorrect="off" onChange={(e) => { setUsernameDraft(e.target.value.replace(/[^A-Za-z0-9_]/g, '')); setUsernameCheck(null) }} onBlur={checkUsername} placeholder="your_username"/></div></label>{usernameCheck && <small className={usernameCheck.available ? 'username-check username-check--ok' : 'username-check username-check--bad'}>{usernameCheck.available ? 'Available — ' : 'Unavailable — '}{usernameCheck.reason}</small>}<div className="username-editor__actions"><button className="btn btn--outline" onClick={checkUsername}>Check</button><button className="btn btn--primary" disabled={usernameBusy || !usernameDraft.trim() || usernameCheck?.available === false} onClick={saveUsername}>{usernameBusy ? 'Saving…' : 'Save username'}</button></div><small className="muted">After saving, your next self-service change is locked for 30 days. Admin corrections stay separate.</small></div>}
      <div className="settings-row"><span><strong>{user?.email}</strong><small>Verified account email</small></span><Shield size={17}/></div>
      <div className="settings-row"><span><strong>{onboarding?.birth_date || 'Birthday set'}</strong><small>DOB correction requires support/admin.</small></span><Shield size={17}/></div>
    </section>

    <VerificationSettings fallbackVerified={!!onboarding?.is_verified} onNotice={setNotice}/>

    <section className="settings-section surface security-settings">
      <div className="settings-section__title"><KeyRound size={18}/><div><p className="eyebrow">SECURITY</p><h3>Password recovery</h3></div></div>
      <div className="settings-row settings-row--action"><span><strong>Reset your password</strong><small>We'll send a secure recovery link to your verified account email.</small></span><Link className="settings-inline-action" to="/forgot-password">Reset</Link></div>
    </section>

    <section className="settings-section surface">
      <div className="settings-section__title"><Bell size={18}/><div><p className="eyebrow">NOTIFICATIONS</p><h3>What gets your attention</h3></div></div>
      {prefs ? <>
        <Toggle label="In-app notifications" description="Master switch for the notification inbox." value={prefs.in_app_notifications} onChange={(v) => set('in_app_notifications', v)}/>
        <Toggle label="Aura" description="When someone gives you Aura." value={prefs.aura_notifications} onChange={(v) => set('aura_notifications', v)}/>
        <Toggle label="Chats" description="Messages from your conversations." value={prefs.chat_notifications} onChange={(v) => set('chat_notifications', v)}/>
        <Toggle label="Rooms" description="Room invites and game activity." value={prefs.room_notifications} onChange={(v) => set('room_notifications', v)}/>
        <Toggle label="Meet" description="Meet requests and connection updates." value={prefs.meet_notifications} onChange={(v) => set('meet_notifications', v)}/>
        {(shopEnabled || plusEnabled) && <Toggle label="Shop & CodaVybes+" description="Purchases and premium account notices." value={prefs.commerce_notifications} onChange={(v) => set('commerce_notifications', v)}/>} 
        <div className="system-notification-row"><div><strong>System notifications</strong><small>Show CodaVybes alerts in your device notification center while CodaVybes is active or installed.</small>{systemPermission === 'granted' && prefs.system_notifications && <button className="system-test-btn" onClick={() => showSystemNotification({ title: 'CodaVybes notifications are on', body: 'Aura, chats, Rooms and Meet alerts can now reach your device.', link: '/notifications' })}>Send test notification</button>}</div>{systemPermission === 'granted' ? <Toggle label="" description="" value={prefs.system_notifications} onChange={async (v) => { await set('system_notifications', v); window.dispatchEvent(new CustomEvent('vybe:system-notifications', { detail: v })) }}/> : <button className="settings-inline-action" onClick={enableSystemNotifications} disabled={!systemNotificationsSupported()}>{systemPermission === 'denied' ? 'Blocked' : 'Enable'}</button>}</div>
      </> : <div className="mini-empty">Loading preferences…</div>}
    </section>

    <section className="settings-section surface">
      <div className="settings-section__title"><Volume2 size={18}/><div><p className="eyebrow">EXPERIENCE</p><h3>App behavior</h3></div></div>
      {prefs && <><Toggle label="Sound effects" description="Aura and game UI sound preference." value={prefs.sound_effects} onChange={(v) => set('sound_effects', v)}/><Toggle label="Reduce motion" description="Use calmer transitions and effects." value={prefs.reduce_motion} onChange={(v) => set('reduce_motion', v)}/><Toggle label="Online status" description="Let eligible people see when you're active." value={prefs.show_online_status} onChange={(v) => set('show_online_status', v)}/></>}
    </section>


    <section className="settings-section surface telemetry-settings">
      <div className="settings-section__title"><MapPin size={18}/><div><p className="eyebrow">PRIVACY & TELEMETRY</p><h3>This device</h3></div></div>
      <div className="settings-row"><span><strong>{telemetryState.platform.toUpperCase()} · v{telemetryState.version}</strong><small>Platform and app version are used for reliability and update diagnostics.</small></span><Shield size={17}/></div>
      <Toggle label="Share precise location" description="Optional for 18+ accounts. Sends latitude/longitude only after this device grants location permission; you can turn it off any time." value={locationSharing} disabled={locationBusy||!preciseLocationEligible} onChange={changeLocationSharing}/>
      <p className="settings-caption">Operational session telemetry helps CodaVybes detect active sessions, app versions and reliability. Optional analytics follow your privacy choice. Precise coordinates are never collected unless an eligible adult account enables the separate location toggle.</p>
      {!analyticsConsentEnabled() && <p className="settings-caption settings-caption--warn">Optional analytics are currently off. Use “Review privacy choices” below before enabling precise location.</p>}
      {!preciseLocationEligible && <p className="settings-caption settings-caption--warn">Precise location sharing is unavailable for under-18 accounts. Coarse operational region signals may still be available where the hosting edge supplies them.</p>}
    </section>

    <section className="settings-section surface install-settings-section">
      <div className="settings-section__title"><Laptop size={18}/><div><p className="eyebrow">THIS DEVICE</p><h3>Install CodaVybes</h3></div></div>
      <div className="settings-install-body"><p>Install the web app for a dedicated window, home-screen icon and faster return to your CodaVybes.</p><InstallVybeButton compact/></div>
    </section>

    <section className="settings-links surface">
      <Link to="/wallet"><Coins size={18}/><span><strong>CodaVybes Wallet</strong><small>{topupsEnabled ? 'Balance, top-ups and ledger' : 'Balance and transaction ledger'}</small></span><ChevronRight size={17}/></Link>
      {shopEnabled && <Link to="/shop"><ShoppingBag size={18}/><span><strong>CodaVybes Shop</strong><small>Cosmetics and owned items</small></span><ChevronRight size={17}/></Link>}
      {plusEnabled && <Link to="/vybe-plus"><Crown size={18}/><span><strong>CodaVybes+</strong><small>Premium customization</small></span><ChevronRight size={17}/></Link>}
    </section>

    <section className="settings-links surface legal-settings-links">
      <Link to="/privacy"><FileText size={18}/><span><strong>Privacy Policy</strong><small>Public, private and safety data</small></span><ChevronRight size={17}/></Link>
      <Link to="/security"><Shield size={18}/><span><strong>Security</strong><small>Account, chat and platform protections</small></span><ChevronRight size={17}/></Link>
      <Link to="/cookies"><FileText size={18}/><span><strong>Cookies & storage</strong><small>Essential and optional browser storage</small></span><ChevronRight size={17}/></Link>
      <Link to="/terms"><FileText size={18}/><span><strong>Terms of Use</strong><small>Community and product rules</small></span><ChevronRight size={17}/></Link>
    </section>

    <button className="btn btn--outline settings-consent-reset" onClick={()=>{try{localStorage.removeItem('codavybes-consent-v1')}catch{};window.dispatchEvent(new CustomEvent('codavybes:consent-reset'));setTelemetryState(telemetrySummary());setNotice('Privacy choice reset. The consent panel is open again.')}}><Cookie size={18}/> Review privacy choices</button>
    <button className="btn btn--outline settings-signout" onClick={signOut}><LogOut size={18}/> Sign out</button>
  </div>
}
