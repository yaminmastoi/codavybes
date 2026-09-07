import { useCallback, useEffect, useState } from 'react'
import { BrainCircuit, Eye, Gamepad2, Lightbulb, LoaderCircle, LogIn, Puzzle, Search, Shuffle, Smile, Sparkles, Split, Users } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { getMyRooms, joinRoom, subscribeToMyRooms } from '../services/roomService'
import { PageSkeleton } from '../components/Loaders'

const gameMeta = {
  trivia: { label: 'Rapid Trivia', Icon: BrainCircuit },
  puzzle: { label: 'Puzzle Battle', Icon: Puzzle },
  most_likely: { label: 'Most Likely To', Icon: Eye },
  would_you_rather: { label: 'Would You Rather', Icon: Split },
  emoji_decode: { label: 'Emoji Decode', Icon: Smile },
  riddle: { label: 'Riddle Rush', Icon: Lightbulb },
  word_scramble: { label: 'Word Scramble', Icon: Shuffle },
  spot_lie: { label: 'Spot the Lie', Icon: Search },
}

export default function Rooms() {
  const navigate = useNavigate()
  const [rooms, setRooms] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [joining, setJoining] = useState(null)
  const load = useCallback(async () => { try { setError(''); setRooms(await getMyRooms(50)) } catch (e) { setError(e.message || 'Could not load Rooms.') } finally { setLoading(false) } }, [])
  useEffect(() => { load() }, [load])
  useEffect(() => { let timer; return subscribeToMyRooms(() => { clearTimeout(timer); timer = setTimeout(load, 160) }) }, [load])
  async function enter(room) { setJoining(room.room_id); setError(''); try { if (room.member_status === 'invited') await joinRoom(room.room_id); navigate(`/rooms/${room.room_id}`) } catch (e) { setError(e.message || 'Could not enter Room.') } finally { setJoining(null) } }

  return <div className="page rooms-index-page">
    <header className="page-head"><div><p className="eyebrow">SOCIAL PLAYGROUND</p><h1>Rooms</h1></div><div className="room-live-mark"><span/> LIVE</div></header>
    <div className="rooms-hero surface"><div className="rooms-hero__icon"><Gamepad2 size={28}/></div><div><strong>Talk, play, compete.</strong><p>8 live games backed by 10,000+ server-side prompts. Start a Room from any conversation and bring your people in.</p></div></div>
    {error && <div className="notice error-box">{error}</div>}
    <section className="section-block">
      <div className="section-title"><div><p className="eyebrow">YOUR ROOMS</p><h2>Jump back in</h2></div><span className="muted">{rooms.length}</span></div>
      {loading ? <PageSkeleton variant="compact" count={3}/> : rooms.length ? <div className="rooms-list">{rooms.map((room) => { const meta=gameMeta[room.game_type]; const Icon=meta?.Icon || Gamepad2; return <button key={room.room_id} className={`room-list-card surface ${room.member_status === 'invited' ? 'is-invite' : ''}`} onClick={() => enter(room)} disabled={joining === room.room_id}>
        <div className="room-list-card__top"><span className="room-game-glyph"><Icon size={18}/></span><div className="room-list-card__copy"><strong>{room.title}</strong><span>{room.member_status === 'invited' ? 'Invitation waiting' : room.status === 'playing' ? `${meta?.label || 'Game'} · in progress` : 'Lobby open · choose a game'}</span></div><span className={`room-state-pill ${room.status === 'playing' ? 'is-playing' : ''}`}>{room.status === 'playing' ? 'PLAYING' : room.member_status === 'invited' ? 'INVITED' : 'OPEN'}</span></div>
        <div className="room-list-card__foot"><span><Users size={14}/> {room.active_count} in · {room.invited_count} invited</span><span>{joining === room.room_id ? <LoaderCircle className="spin" size={15}/> : <><LogIn size={14}/> Enter</>}</span></div>
      </button>})}</div> : <div className="rooms-empty surface"><Sparkles size={30}/><h3>No active Rooms.</h3><p className="muted">Open a group or DM and use the Room action to invite that conversation.</p><button className="btn btn--primary" onClick={() => navigate('/chats')}><Gamepad2 size={17}/> Go to Chats</button></div>}
    </section>
  </div>
}
