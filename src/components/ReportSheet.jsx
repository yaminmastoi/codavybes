import { useState } from 'react'
import { Flag, LoaderCircle, X } from 'lucide-react'
import { reportMessage } from '../services/chatService'

const reasons = [
  ['harassment','Harassment'],['spam','Spam'],['threat','Threat'],['hate','Hate'],
  ['sexual_content','Sexual content'],['impersonation','Impersonation'],['scam','Scam'],['minor_safety','Minor safety'],['other','Other'],
]

export default function ReportSheet({ message, onClose, onReported }) {
  const [reason, setReason] = useState('harassment')
  const [details, setDetails] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  async function submit() {
    setBusy(true); setError('')
    try {
      await reportMessage(message.message_id, reason, details.trim())
      onReported?.('Report sent to CodaVybes Safety.')
      onClose()
    } catch (e) { setError(e.message || 'Could not send report.') }
    finally { setBusy(false) }
  }
  return <div className="sheet-backdrop" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
    <section className="report-sheet surface">
      <header className="sheet-head"><div><p className="eyebrow">CodaVybes SAFETY</p><h2>Report message</h2></div><button className="icon-btn" onClick={onClose}><X size={20}/></button></header>
      <p className="muted report-preview">“{message.body.slice(0,120)}{message.body.length > 120 ? '…' : ''}”</p>
      <div className="report-reasons">{reasons.map(([value,label]) => <button key={value} className={reason === value ? 'is-active' : ''} onClick={() => setReason(value)}>{label}</button>)}</div>
      <label>Optional details<div className="input-wrap report-details"><input maxLength={1000} value={details} onChange={(e) => setDetails(e.target.value)} placeholder="What happened?"/></div></label>
      {error && <div className="notice error-box">{error}</div>}
      <button className="btn btn--gold" onClick={submit} disabled={busy}>{busy ? <LoaderCircle className="spin" size={17}/> : <Flag size={17}/>} Send report</button>
    </section>
  </div>
}
