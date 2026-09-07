import { Ban, Clock3, LogOut, ShieldAlert } from 'lucide-react'
import { signOut } from '../services/authService'

export default function AccountRestricted({ status = 'suspended' }) {
  const banned = status === 'banned'
  return <div className="restricted-shell"><div className="restricted-card surface">
    <div className={`restricted-icon ${banned?'is-ban':''}`}>{banned?<Ban size={28}/>:<Clock3 size={28}/>}</div>
    <p className="eyebrow"><ShieldAlert size={13}/> ACCOUNT ACCESS</p>
    <h1>{banned ? 'This CodaVybes account is banned.' : 'This CodaVybes account is suspended.'}</h1>
    <p className="muted">Your account cannot use Discover, chats, Rooms, Aura or Meet while this restriction is active. If you think this was a mistake, use the support process for your launch region.</p>
    <button className="btn btn--outline" onClick={signOut}><LogOut size={17}/> Sign out</button>
  </div></div>
}
