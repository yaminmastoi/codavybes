import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { ArrowLeft, BrainCircuit, Check, Clock3, Crown, Eye, Gamepad2, Lightbulb, LoaderCircle, LogOut, Medal, Play, Puzzle, RefreshCw, Search, ShieldCheck, Shuffle, Smile, Split, Trophy, Users, Zap } from 'lucide-react'
import { useNavigate, useParams } from 'react-router-dom'
import Avatar from '../components/Avatar'
import AuraPill from '../components/AuraPill'
import { useAuth } from '../context/AuthContext'
import { advanceRoomGame, getRoomState, joinRoom, leaveRoom, startRoomGame, submitGameAnswer, subscribeToRoom } from '../services/roomService'
import { AppLaunchLoader } from '../components/Loaders'
import ConfirmDialog from '../components/ConfirmDialog'

const games = [
  { type: 'trivia', Icon: BrainCircuit, title: 'Rapid Trivia', meta: 'Knowledge · speed · streaks' },
  { type: 'puzzle', Icon: Puzzle, title: 'Puzzle Battle', meta: 'Patterns · logic · speed' },
  { type: 'most_likely', Icon: Eye, title: 'Most Likely To', meta: 'Vote on your people' },
  { type: 'would_you_rather', Icon: Split, title: 'Would You Rather', meta: 'Predict the room majority' },
  { type: 'emoji_decode', Icon: Smile, title: 'Emoji Decode', meta: 'Read the icons before they do' },
  { type: 'riddle', Icon: Lightbulb, title: 'Riddle Rush', meta: 'Quick clues · quick answers' },
  { type: 'word_scramble', Icon: Shuffle, title: 'Word Scramble', meta: 'Unscramble under pressure' },
  { type: 'spot_lie', Icon: Search, title: 'Spot the Lie', meta: 'One statement is fake' },
]

function initials(name = 'V') {
  return String(name ?? '').trim().split(/\s+/).slice(0,2).map((part) => part[0]?.toUpperCase()).join('') || 'V'
}

function secondsLeft(endsAt) {
  if (!endsAt) return 0
  return Math.max(0, Math.ceil((new Date(endsAt).getTime() - Date.now()) / 1000))
}

export default function RoomDetail() {
  const { roomId } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const [state, setState] = useState(null)
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState('')
  const [busy, setBusy] = useState(false)
  const [leaveConfirm, setLeaveConfirm] = useState(false)
  const [selectedGame, setSelectedGame] = useState('trivia')
  const [selectedAnswer, setSelectedAnswer] = useState('')
  const [answerResult, setAnswerResult] = useState(null)
  const [timeLeft, setTimeLeft] = useState(0)
  const advancingRef = useRef(false)

  const load = useCallback(async (first = false) => {
    if (first) setLoading(true)
    try {
      const next = await getRoomState(roomId)
      setState(next)
      const serverAnswer = next?.round?.my_answer || ''
      if (serverAnswer) setSelectedAnswer(serverAnswer)
      else setSelectedAnswer('')
      setTimeLeft(secondsLeft(next?.round?.ends_at))
    } catch (e) {
      setNotice(e.message || 'Room unavailable.')
    } finally {
      if (first) setLoading(false)
    }
  }, [roomId])

  useEffect(() => { load(true) }, [load])
  useEffect(() => {
    let timer
    return subscribeToRoom(roomId, () => {
      clearTimeout(timer)
      timer = setTimeout(() => load(false), 130)
    })
  }, [roomId,load])

  const roundId = state?.round?.id
  useEffect(() => {
    setAnswerResult(null)
    setSelectedAnswer(state?.round?.my_answer || '')
  }, [roundId]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!state?.round?.ends_at || !state?.session?.id) return undefined
    const tick = async () => {
      const left = secondsLeft(state.round.ends_at)
      setTimeLeft(left)
      if (left <= 0 && !advancingRef.current) {
        advancingRef.current = true
        try { await advanceRoomGame(state.session.id); await load(false) }
        catch { /* another client may have advanced already */ }
        finally { setTimeout(() => { advancingRef.current = false }, 500) }
      }
    }
    tick()
    const id = setInterval(tick, 800)
    return () => clearInterval(id)
  }, [state?.round?.ends_at,state?.session?.id,load])

  const members = Array.isArray(state?.members) ? state.members : []
  const activeMembers = members.filter((m) => m.status === 'active')
  const memberMap = useMemo(() => Object.fromEntries(members.map((m) => [m.user_id,m])), [members])
  const scoreboard = Array.isArray(state?.scoreboard) ? [...state.scoreboard].sort((a,b) => Number(b.score)-Number(a.score)) : []
  const results = Array.isArray(state?.last_results) ? [...state.last_results].sort((a,b) => Number(a.placement)-Number(b.placement)) : []
  const isHost = state?.viewer?.role === 'host' || state?.room?.host_id === user?.id
  const invited = state?.viewer?.status === 'invited'
  const gameActive = Boolean(state?.session && state?.round)
  const options = Array.isArray(state?.round?.options) ? state.round.options : []

  async function handleJoin() {
    setBusy(true); setNotice('')
    try { await joinRoom(roomId); await load(false); setNotice('You’re in. Room access confirmed.') }
    catch (e) { setNotice(e.message || 'Could not join Room.') }
    finally { setBusy(false) }
  }

  async function handleLeave() {
    setLeaveConfirm(false)
    setBusy(true)
    try { await leaveRoom(roomId); navigate('/rooms',{replace:true}) }
    catch (e) { setNotice(e.message || 'Could not leave Room.') }
    finally { setBusy(false) }
  }

  async function startGame() {
    setBusy(true); setNotice('')
    try { await startRoomGame(roomId,selectedGame); await load(false); setNotice('Game started. Scores are server-verified.') }
    catch (e) { setNotice(e.message || 'Could not start game.') }
    finally { setBusy(false) }
  }

  async function answer(value) {
    if (!state?.session?.id || !state?.round?.id || selectedAnswer || timeLeft <= 0) return
    setSelectedAnswer(value); setBusy(true); setNotice('')
    try {
      const result = await submitGameAnswer(state.session.id,state.round.id,value)
      setAnswerResult(result)
      if (result.correct === true) setNotice(`Locked in ✓ +${result.score} points`)
      else if (result.correct === false) setNotice('Answer locked. That one missed.')
      else setNotice('Vote locked.')
      await load(false)
      // Any player may safely ask the DB to advance; it only proceeds when all active players submitted or time expires.
      await advanceRoomGame(state.session.id).catch(() => null)
    } catch (e) {
      setSelectedAnswer('')
      setNotice(e.message || 'Could not submit answer.')
    } finally { setBusy(false) }
  }

  if (loading) return <AppLaunchLoader label="Opening Room" />
  if (!state?.room) return <div className="page"><div className="notice error-box">{notice || 'Room unavailable.'}</div></div>

  return <div className="room-detail-page">
    <header className="room-detail-head surface">
      <button className="icon-btn" onClick={() => navigate('/rooms')}><ArrowLeft size={20}/></button>
      <div><strong>{state.room.title}</strong><span>{activeMembers.length}/{state.room.max_players} in Room</span></div>
      <button className="icon-btn" onClick={()=>setLeaveConfirm(true)} disabled={busy}><LogOut size={19}/></button>
    </header>

    {notice && <div className="room-notice"><Zap size={14} fill="currentColor"/>{notice}</div>}

    {invited ? <main className="room-invite-screen">
      <div className="room-invite-orb"><Gamepad2 size={34}/></div>
      <p className="eyebrow">YOU GOT CALLED OUT</p>
      <h1>{state.room.title}</h1>
      <p className="muted">{activeMembers.length} people are already in. Enter before they start talking about you.</p>
      <button className="btn btn--primary" onClick={handleJoin} disabled={busy}>{busy ? <LoaderCircle className="spin"/> : <LogInIcon/>} Enter Room</button>
    </main> : <main className="room-detail-body">
      <section className="room-lobby-stage surface">
        <div className="room-lobby-top"><div><p className="eyebrow">{gameActive ? 'GAME LIVE' : 'ROOM LOBBY'}</p><h2>{gameActive ? games.find((g)=>g.type===state.session.game_type)?.title : 'Your people are here.'}</h2></div><span className="room-live-mark"><span/> {gameActive ? 'PLAYING' : 'LIVE'}</span></div>
        <div className="room-member-cloud">
          {members.map((member) => <div className={`room-member-node ${member.status !== 'active' ? 'is-invited' : ''}`} key={member.user_id}>
            <div className="room-member-avatar"><Avatar initials={initials(member.display_name || member.username)} online={member.status === 'active'}/>{member.role === 'host' && <span className="host-crown"><Crown size={10} fill="currentColor"/></span>}</div>
            <strong>{member.user_id === user?.id ? 'You' : (member.display_name || member.username)}</strong>
            <small>{member.status === 'invited' ? 'invited' : <AuraPill value={member.aura_total} size="sm"/>}</small>
          </div>)}
        </div>
      </section>

      {gameActive ? <section className="live-game-panel">
        <div className="game-round-head">
          <div><p className="eyebrow">ROUND {state.round.round_no} / {state.session.max_rounds}</p><h2>{state.round.prompt}</h2></div>
          <div className={`game-timer ${timeLeft <= 5 ? 'is-hot' : ''}`}><Clock3 size={16}/><strong>{timeLeft}s</strong></div>
        </div>

        <div className="game-options">
          {options.map((option) => {
            const value = typeof option === 'object' ? option.value : String(option)
            const label = typeof option === 'object' ? option.label : String(option)
            const chosen = selectedAnswer === value
            return <button key={value} className={`game-option surface ${chosen ? 'is-chosen' : ''}`} disabled={Boolean(selectedAnswer) || timeLeft <= 0 || busy} onClick={() => answer(value)}>
              <span>{label}</span>{chosen && <Check size={18}/>} 
            </button>
          })}
        </div>

        <div className="game-status-strip surface">
          <ShieldCheck size={17}/><div><strong>Server-scored</strong><span>Your browser can’t choose the winner or Aura reward.</span></div>
          {answerResult?.score != null && <b>+{answerResult.score}</b>}
        </div>

        <section className="room-scoreboard surface">
          <div className="section-title"><h3>Live scoreboard</h3><RefreshCw size={16}/></div>
          {scoreboard.map((row,index) => {
            const member = memberMap[row.user_id]
            return <div className="score-row" key={row.user_id}><span>#{index+1}</span><strong>{row.user_id === user?.id ? 'You' : (member?.display_name || member?.username || 'Player')}</strong><b>{row.score}</b></div>
          })}
        </section>
      </section> : <>
        {results.length > 0 && <section className="room-results surface">
          <div className="results-crown"><Trophy size={28}/></div><p className="eyebrow">LAST GAME</p><h2>{memberMap[results[0]?.user_id]?.display_name || memberMap[results[0]?.user_id]?.username || 'Winner'} cooked.</h2>
          <div className="results-list">{results.map((row) => <div className={`result-row ${row.winner ? 'is-winner' : ''}`} key={row.user_id}><span className="placement-mark">{row.placement <= 3 ? <Medal size={16}/> : `#${row.placement}`}</span><strong>{row.user_id === user?.id ? 'You' : (memberMap[row.user_id]?.display_name || memberMap[row.user_id]?.username || 'Player')}</strong><b>{row.score}</b>{row.mvp && <em><Zap size={12}/> MVP</em>}</div>)}</div>
          <div className="verified-reward"><ShieldCheck size={16}/> Winner reward is verified Aura + XP — calculated server-side.</div>
        </section>}

        <section className="room-games-section">
          <div className="section-title room-game-title"><div><p className="eyebrow">8 LIVE GAMES · 10K+ PROMPTS</p><h2>What are we playing?</h2></div>{isHost ? <Crown size={18} className="gold"/> : <span className="muted">Host chooses</span>}</div>
          <div className="room-game-grid">{games.map((game) => { const Icon = game.Icon; return <button key={game.type} onClick={() => setSelectedGame(game.type)} className={`room-game-card surface ${selectedGame === game.type ? 'is-selected' : ''}`} disabled={!isHost}><span><Icon size={22}/></span><strong>{game.title}</strong><small>{game.meta}</small></button> })}</div>
          {isHost ? <button className="btn btn--primary" onClick={startGame} disabled={busy || activeMembers.length < 2}>{busy ? <LoaderCircle className="spin"/> : <Play size={18} fill="currentColor"/>} Start Game</button> : <div className="host-wait surface"><Gamepad2 size={18}/><span>Waiting for the host to start the chaos.</span></div>}
          {activeMembers.length < 2 && <p className="room-helper"><Users size={14}/> Need at least 2 active players.</p>}
        </section>
      </>}
    </main>}
  <ConfirmDialog open={leaveConfirm} title="Leave this Room?" body="You can return later if the Room is still available." confirmLabel="Leave Room" busy={busy} onCancel={()=>setLeaveConfirm(false)} onConfirm={handleLeave}/>
  </div>
}

function LogInIcon() { return <Gamepad2 size={18}/> }
