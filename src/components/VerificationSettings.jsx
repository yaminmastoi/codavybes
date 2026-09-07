import { useEffect, useState } from 'react'
import { BadgeCheck, Clock3, LoaderCircle, ShieldCheck, X } from 'lucide-react'
import { getMyVerificationState, joinVerificationWaitlist, leaveVerificationWaitlist } from '../services/verificationService'
import VerifiedBadge from './VerifiedBadge'

export default function VerificationSettings({ fallbackVerified = false, onNotice }) {
  const [state, setState] = useState({ is_verified: fallbackVerified, eligible: false, request: null })
  const [loading, setLoading] = useState(true)
  const [busy, setBusy] = useState(false)

  const load = async () => {
    try { setState(await getMyVerificationState()) }
    catch (error) { onNotice?.(error.message) }
    finally { setLoading(false) }
  }

  useEffect(() => {
    load()
    const refresh = () => { setLoading(true); load() }
    window.addEventListener('vybe:verification-changed', refresh)
    return () => window.removeEventListener('vybe:verification-changed', refresh)
  }, [])

  async function join() {
    if (busy) return
    try {
      setBusy(true)
      await joinVerificationWaitlist()
      await load()
      onNotice?.('You joined the CodaVybes verification waitlist.')
    } catch (error) { onNotice?.(error.message) }
    finally { setBusy(false) }
  }

  async function leave() {
    if (busy) return
    try {
      setBusy(true)
      await leaveVerificationWaitlist()
      await load()
      onNotice?.('You left the verification waitlist.')
    } catch (error) { onNotice?.(error.message) }
    finally { setBusy(false) }
  }

  if (loading) {
    return <section className="settings-section surface verification-settings verification-settings--loading"><div className="verification-state"><LoaderCircle className="spin" size={18}/><span>Checking verification status…</span></div></section>
  }

  // Before Certified there is intentionally no "apply" surface at all.
  if (!state?.is_verified && !state?.eligible) return null

  const request = state?.request
  const waitlisted = request?.status === 'pending'
  const rejected = request?.status === 'rejected'

  return <section className="settings-section surface verification-settings" id="verification">
    <div className="settings-section__title"><BadgeCheck size={18}/><div><p className="eyebrow">VERIFICATION</p><h3>Blue tick</h3></div></div>

    {state?.is_verified ? (
      <div className="verification-state verification-state--verified">
        <VerifiedBadge verified size={28}/>
        <div><strong>Verified account</strong><span>Your CodaVybes blue tick is active. Only CodaVybes HQ can grant or remove verification.</span></div>
      </div>
    ) : waitlisted ? (
      <div className="verification-request-summary">
        <div><Clock3 size={20}/><span><strong>You’re on the waitlist</strong><small>Joined {new Date(request.created_at).toLocaleDateString()} · HQ review pending</small></span></div>
        <button className="settings-inline-action" disabled={busy} onClick={leave}>{busy ? <LoaderCircle className="spin" size={14}/> : <X size={14}/>} Leave waitlist</button>
      </div>
    ) : (
      <>
        {rejected && <div className="verification-review-note"><strong>Previous review complete</strong><span>{request.admin_note || 'CodaVybes HQ did not approve the previous waitlist entry.'}</span></div>}
        <div className="verification-intro verification-intro--eligible">
          <div><ShieldCheck size={23}/><span><strong>Certified unlocked verification</strong><small>You reached the Certified Aura tier. Join the waitlist; a blue tick is only granted after CodaVybes HQ approval.</small></span></div>
          <button className="btn btn--primary verification-join" disabled={busy || !state?.eligible} onClick={join}>{busy ? <LoaderCircle className="spin" size={16}/> : <BadgeCheck size={16}/>} Join waitlist</button>
        </div>
      </>
    )}
  </section>
}
