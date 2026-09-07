import { Download, MonitorSmartphone } from 'lucide-react'
import { useEffect, useState } from 'react'

export default function InstallVybeButton({ className = '', compact = false }) {
  const [prompt, setPrompt] = useState(() => window.__vybeInstallPrompt || null)
  const [installed, setInstalled] = useState(() => window.matchMedia?.('(display-mode: standalone)')?.matches || window.navigator.standalone === true)

  useEffect(() => {
    const onPrompt = (event) => {
      event.preventDefault()
      window.__vybeInstallPrompt = event
      setPrompt(event)
    }
    const onAvailable = () => setPrompt(window.__vybeInstallPrompt || null)
    const onInstalled = () => {
      window.__vybeInstallPrompt = null
      setPrompt(null)
      setInstalled(true)
    }
    window.addEventListener('beforeinstallprompt', onPrompt)
    window.addEventListener('vybe:install-available', onAvailable)
    window.addEventListener('appinstalled', onInstalled)
    return () => {
      window.removeEventListener('beforeinstallprompt', onPrompt)
      window.removeEventListener('vybe:install-available', onAvailable)
      window.removeEventListener('appinstalled', onInstalled)
    }
  }, [])

  if (installed || !prompt) return null

  async function install() {
    try {
      await prompt.prompt()
      await prompt.userChoice
    } finally {
      window.__vybeInstallPrompt = null
      setPrompt(null)
    }
  }

  if (compact) return <button className={`install-vybe-button install-vybe-button--compact ${className}`} onClick={install}><Download size={17}/> Install CodaVybes</button>

  return <button className={`install-vybe-button ${className}`} onClick={install}>
    <span><MonitorSmartphone size={21}/></span>
    <div><strong>Install CodaVybes</strong><small>Open it like an app on this device.</small></div>
    <Download size={18}/>
  </button>
}
