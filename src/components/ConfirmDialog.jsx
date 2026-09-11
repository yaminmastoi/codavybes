import { AlertTriangle, X } from 'lucide-react'

export default function ConfirmDialog({ open, title, body, confirmLabel = 'Confirm', tone = 'danger', busy = false, onConfirm, onCancel }) {
  if (!open) return null
  return <div className="coda-dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !busy) onCancel?.() }}>
    <section className="coda-dialog surface" role="dialog" aria-modal="true" aria-labelledby="coda-dialog-title">
      <button className="coda-dialog-close" type="button" aria-label="Close" disabled={busy} onClick={onCancel}><X size={18}/></button>
      <div className={`coda-dialog-icon is-${tone}`}><AlertTriangle size={23}/></div>
      <p className="eyebrow">CODAVYBES</p>
      <h2 id="coda-dialog-title">{title}</h2>
      <p>{body}</p>
      <div className="coda-dialog-actions">
        <button className="btn btn--outline" type="button" disabled={busy} onClick={onCancel}>Cancel</button>
        <button className={`btn coda-dialog-confirm is-${tone}`} type="button" disabled={busy} onClick={onConfirm}>{busy ? 'Working…' : confirmLabel}</button>
      </div>
    </section>
  </div>
}
