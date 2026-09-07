import { Download, RefreshCw, X } from 'lucide-react'
import { useEffect, useState } from 'react'
import { APP_PLATFORM, APP_VERSION } from '../services/telemetryService'
import { getLatestAppRelease, openAppUpdate } from '../services/releaseService'

const DISMISS_KEY='codavybes-update-dismissed-v1'

export default function UpdateBanner(){
  const [release,setRelease]=useState(null)
  const [dismissed,setDismissed]=useState(false)
  useEffect(()=>{
    let alive=true
    const check=()=>getLatestAppRelease().then((next)=>{
      if(!alive||!next?.update_available)return
      let hidden=false
      try{hidden=localStorage.getItem(DISMISS_KEY)===`${next.platform}:${next.version}`}catch{}
      if(!hidden||next.required)setRelease(next)
    }).catch(()=>{})
    check();const timer=window.setInterval(check,10*60*1000)
    return()=>{alive=false;window.clearInterval(timer)}
  },[])
  if(!release||dismissed)return null
  const dismiss=()=>{if(release.required)return;try{localStorage.setItem(DISMISS_KEY,`${release.platform}:${release.version}`)}catch{};setDismissed(true)}
  return <aside className={`app-update-banner ${release.required?'is-required':''}`} role="status">
    <span className="app-update-banner__icon">{APP_PLATFORM==='web'?<RefreshCw size={18}/>:<Download size={18}/>}</span>
    <div><strong>CodaVybes {release.version} is ready</strong><p>{release.release_notes||`Update from ${APP_VERSION} for the latest CodaVybes experience.`}</p></div>
    <button className="btn btn--primary" disabled={APP_PLATFORM!=='web'&&!release.download_url} onClick={()=>openAppUpdate(release)}>{APP_PLATFORM==='web'?'Refresh now':'Get update'}</button>
    {!release.required&&<button className="app-update-dismiss" onClick={dismiss} aria-label="Dismiss update"><X size={16}/></button>}
  </aside>
}
