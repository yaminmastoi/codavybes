import { useEffect, useState } from 'react'
import { ArrowLeft, CheckCircle2, Eye, EyeOff, KeyRound, ShieldCheck } from 'lucide-react'
import { Link, useNavigate } from 'react-router-dom'
import Logo from '../components/Logo'
import SetupRequired from '../components/SetupRequired'
import { isSupabaseConfigured, supabase } from '../lib/supabase'
import { updatePassword } from '../services/authService'

function score(password) {
  return [password.length >= 8, /[a-z]/.test(password) && /[A-Z]/.test(password), /\d/.test(password), /[^A-Za-z0-9]/.test(password)].filter(Boolean).length
}

export default function ResetPassword() {
  const navigate = useNavigate()
  const [password,setPassword]=useState('')
  const [confirm,setConfirm]=useState('')
  const [show,setShow]=useState(false)
  const [ready,setReady]=useState(false)
  const [busy,setBusy]=useState(false)
  const [done,setDone]=useState(false)
  const [error,setError]=useState('')
  const strength=score(password)
  const valid=strength===4 && password===confirm

  useEffect(()=>{
    if (!supabase) return
    let mounted=true
    supabase.auth.getSession().then(({data})=>{ if(mounted) setReady(!!data.session) })
    const { data:{subscription} }=supabase.auth.onAuthStateChange((event,session)=>{
      if (!mounted) return
      if (event==='PASSWORD_RECOVERY' || session) setReady(true)
    })
    return ()=>{mounted=false;subscription.unsubscribe()}
  },[])

  if (!isSupabaseConfigured) return <SetupRequired/>

  async function submit(event){
    event.preventDefault()
    if(!valid||busy)return
    try{setBusy(true);setError('');await updatePassword(password);setDone(true)}
    catch(e){setError(e.message||'Password could not be updated.')}
    finally{setBusy(false)}
  }

  return <main className="recovery-shell">
    <section className="recovery-brand"><Logo/><div><p className="eyebrow">SECURE RESET</p><h1>Choose a new password.</h1><p>Your new password updates the same CodaVybes account across web, mobile and desktop.</p></div><div className="recovery-trust"><ShieldCheck size={17}/><span>CodaVybes never stores or displays your plaintext password.</span></div></section>
    <section className="recovery-card surface">
      <Link className="icon-btn recovery-back" to="/onboarding" aria-label="Back to login"><ArrowLeft size={19}/></Link>
      {done ? <div className="recovery-success"><CheckCircle2 size={34}/><p className="eyebrow">PASSWORD UPDATED</p><h2>You're secure again.</h2><p>Your new password is active. Continue back into CodaVybes.</p><button className="btn btn--primary" onClick={()=>navigate('/',{replace:true})}>Continue to CodaVybes</button></div> : !ready ? <div className="recovery-success"><KeyRound size={34}/><p className="eyebrow">RECOVERY SESSION</p><h2>Open your reset link.</h2><p className="muted">This page needs the secure link from your recovery email. If the link expired, request a new one.</p><Link className="btn btn--outline" to="/forgot-password">Send a new link</Link></div> : <form className="recovery-form" onSubmit={submit}>
        <div className="recovery-icon"><KeyRound size={24}/></div><p className="eyebrow">NEW PASSWORD</p><h2>Make it strong.</h2>
        <label>New password<div className="input-wrap"><ShieldCheck size={18}/><input type={show?'text':'password'} autoComplete="new-password" value={password} onChange={(e)=>setPassword(e.target.value)} placeholder="New password"/><button type="button" className="input-icon" onClick={()=>setShow(v=>!v)}>{show?<EyeOff size={18}/>:<Eye size={18}/>}</button></div></label>
        <div className="strength">{[1,2,3,4].map(n=><span key={n} className={strength>=n?'':'dim'}/>)}</div><small className={strength===4?'success':'muted'}>8+ chars · upper/lowercase · number · special character</small>
        <label>Confirm password<div className="input-wrap"><KeyRound size={18}/><input type={show?'text':'password'} autoComplete="new-password" value={confirm} onChange={(e)=>setConfirm(e.target.value)} placeholder="Repeat password"/></div></label>
        {confirm && password!==confirm && <small className="danger-text">Passwords do not match.</small>}
        {error && <div className="notice error-box">{error}</div>}
        <button className="btn btn--primary recovery-submit" disabled={!valid||busy}>{busy?'Updating…':'Update password'}</button>
      </form>}
    </section>
  </main>
}
