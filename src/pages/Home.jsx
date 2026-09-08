import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Award, ChevronRight, Flame, Gamepad2, LoaderCircle, MessageCircle, MoonStar, PenLine, Send, Sparkles, WalletCards, Zap } from 'lucide-react'
import Avatar from '../components/Avatar'
import FeedCard from '../components/FeedCard'
import SponsoredCard from '../components/SponsoredCard'
import PlatformPostCard from '../components/PlatformPostCard'
import AuraQuickSheet from '../components/AuraQuickSheet'
import { useAuth } from '../context/AuthContext'
import { createMoment, getAuraDashboard, getForYouFeed, getRisingFeed, giveAura } from '../services/auraService'
import NotificationBell from '../components/NotificationBell'
import { HomeSkeleton, PageSkeleton } from '../components/Loaders'
import VerifiedBadge from '../components/VerifiedBadge'
import { getActivePromotions } from '../services/promotionService'
import { getPlatformPosts } from '../services/platformService'
import { useCommerce } from '../context/CommerceContext'

function initials(name = 'CodaVybes') { return name.trim().split(/\s+/).slice(0, 2).map((part) => part[0]?.toUpperCase()).join('') || 'CV' }

function mixSponsored(items, promotions) {
  if (!promotions.length) return items.map((item)=>({kind:'post',item}))
  if (!items.length) return [{kind:'sponsor',item:promotions[0]}]

  // A small community must still be able to run its first campaign. With fewer
  // than seven organic posts, place one sponsor after the first post. As the
  // feed grows, return to the low-frequency 7/14-post cadence.
  const firstSponsorAfter = items.length < 7 ? 0 : 6
  const maxSponsored = Math.min(items.length >= 14 ? 2 : 1, promotions.length)
  const result=[];let sponsorIndex=0
  items.forEach((item,index)=>{
    result.push({kind:'post',item})
    const sponsorSlot = index === firstSponsorAfter || (index === 13 && sponsorIndex === 1)
    if (sponsorSlot && sponsorIndex<maxSponsored) {
      result.push({kind:'sponsor',item:promotions[sponsorIndex++]})
    }
  })
  return result
}

export default function Home() {
  const navigate = useNavigate()
  const { onboarding } = useAuth()
  const { adsEnabled } = useCommerce()
  const name = onboarding?.display_name || onboarding?.username || 'CodaVybes'
  const [dashboard, setDashboard] = useState(null)
  const [feed, setFeed] = useState([])
  const [promotions,setPromotions]=useState([])
  const [platformPosts,setPlatformPosts]=useState([])
  const [feedMode, setFeedMode] = useState('fyp')
  const [loading, setLoading] = useState(true)
  const [busyTarget, setBusyTarget] = useState(null)
  const [momentText, setMomentText] = useState('')
  const [posting, setPosting] = useState(false)
  const [composerOpen,setComposerOpen]=useState(false)
  const [auraOpen,setAuraOpen]=useState(false)
  const [notice, setNotice] = useState('')

  const load = useCallback(async (mode = feedMode) => {
    setLoading(true)
    try {
      const feedPromise = mode === 'rising' ? getRisingFeed(24, 0) : getForYouFeed(24, 0)
      const extras = mode === 'fyp' ? Promise.all([
        adsEnabled ? getActivePromotions(8).catch((error)=>{ console.warn('CodaVybes promotions:', error.message); return [] }) : Promise.resolve([]),
        getPlatformPosts(4).catch((error)=>{ console.warn('CodaVybes official feed:', error.message); return [] }),
      ]) : Promise.resolve([[],[]])
      const [dash, items, [sponsors, official]] = await Promise.all([getAuraDashboard(), feedPromise, extras])
      setDashboard(dash);setFeed(items);setPromotions(sponsors);setPlatformPosts(official)
    } catch (error) {
      console.error(error);setNotice(error.message || 'Could not load your feed right now.')
    } finally { setLoading(false) }
  }, [feedMode, adsEnabled])

  useEffect(() => { load(feedMode) }, [feedMode, load])

  async function handleAura(targetId) {
    setBusyTarget(targetId);setNotice('')
    try {
      const result = await giveAura(targetId)
      setFeed((current) => current.map((item) => item.target_id === targetId ? {...item,aura_count: result.target_aura,unique_givers: result.unique_givers ?? item.unique_givers,viewer_has_aura: true,is_aura_moment: result.is_aura_moment} : item))
      setNotice(result.already_given ? 'Aura already given.' : result.rank_up ? `Aura +1 — ${result.rank?.name} unlocked.` : result.became_aura_moment ? 'You helped create an Aura Moment.' : 'Aura +1')
    } catch (error) { setNotice(error.message || 'Aura could not be given.') }
    finally { setBusyTarget(null) }
  }

  async function handlePost(event) {
    event.preventDefault();const text = momentText.trim();if (!text || posting) return
    setPosting(true);setNotice('')
    try {
      await createMoment(text, 'Public CodaVybes');setMomentText('');setComposerOpen(false);setFeedMode('fyp');setNotice('Published. Every public post can now enter For You.');await load('fyp')
    } catch (error) { setNotice(error.message || 'Could not publish post.') }
    finally { setPosting(false) }
  }

  const mixedFeed=useMemo(()=>feedMode==='fyp'?mixSponsored(feed,promotions):feed.map(item=>({kind:'post',item})),[feedMode,feed,promotions])
  if (loading && !dashboard) return <HomeSkeleton />

  return <div className="page home-v13">
    <header className="home-head home-head--v13">
      <div className="row gap-12"><Avatar initials={initials(name)} online/><div className="home-welcome"><small className="muted">CodaVybes · powered by CodaBite</small><div className="identity-line"><h3>{name}</h3><VerifiedBadge verified={onboarding?.is_verified} size={15}/></div></div></div>
      <div className="home-utility-row">
        <button className="top-utility-btn" onClick={()=>setAuraOpen(true)} aria-label="Open Aura rank"><Award size={18}/><span>{dashboard?.rank?.name || 'Aura'}</span></button>
        <button className="top-utility-btn top-utility-btn--icon" onClick={()=>navigate('/wallet')} aria-label="Open wallet"><WalletCards size={19}/></button>
        <NotificationBell/>
      </div>
    </header>

    <button className={`rising-lab-trigger surface ${composerOpen?'is-open':''}`} onClick={()=>setComposerOpen(v=>!v)}><span><PenLine size={16}/><b>Drop a thought</b><small>Rising Lab</small></span><ChevronRight size={16}/></button>
    {composerOpen && <form className="moment-composer surface moment-composer--compact" onSubmit={handlePost}><textarea autoFocus value={momentText} onChange={(e)=>setMomentText(e.target.value)} maxLength={1200} placeholder="A joke, a take, a moment..."/><div className="row between"><small className="muted">Public posts appear in For You; organic ranking still decides order.</small><button className="btn btn--primary composer-btn" disabled={posting || !momentText.trim()}>{posting?<LoaderCircle className="spin" size={17}/>:<Send size={17}/>} Post</button></div></form>}

    {notice && <div className="aura-notice surface"><Zap size={17}/><span>{notice}</span></div>}

    <section className="section-block"><div className="section-title"><div><p className="eyebrow">RIGHT NOW</p><h2>What's the move?</h2></div><button className="text-btn" onClick={()=>navigate('/discover')}>See all <ChevronRight size={16}/></button></div><div className="move-grid"><button className="move-card surface" onClick={()=>navigate('/rooms')}><span><Gamepad2 size={19}/></span><strong>Play</strong><small>8 game modes</small></button><button className="move-card surface" onClick={()=>navigate('/chats')}><span><MessageCircle size={19}/></span><strong>Talk</strong><small>Open chats</small></button><button className="move-card surface" onClick={()=>navigate('/discover')}><span><Flame size={19}/></span><strong>Meet</strong><small>Find people</small></button><button className="move-card surface" onClick={()=>navigate('/discover?tab=for_you')}><span><MoonStar size={19}/></span><strong>Deep</strong><small>Same vibe</small></button></div></section>

    <section className="feed-tabs"><button className={feedMode==='fyp'?'is-active':''} onClick={()=>setFeedMode('fyp')}>For You</button><button className={feedMode==='rising'?'is-active':''} onClick={()=>setFeedMode('rising')}>Rising</button><button onClick={()=>navigate('/discover?tab=connections')}>Friends</button><button onClick={()=>navigate('/rooms')}>Rooms</button></section>

    {feedMode==='fyp' && platformPosts.length>0 && <section className="platform-post-list">{platformPosts.map(post=><PlatformPostCard key={post.id} post={post}/>)}</section>}

    {loading ? <PageSkeleton variant="feed" count={3}/> : mixedFeed.length ? <section className="feed-list">{mixedFeed.map((entry,index)=>entry.kind==='sponsor'?<SponsoredCard key={`sponsor-${entry.item.id}-${index}`} promotion={entry.item}/>:<FeedCard key={entry.item.target_id} item={entry.item} onAura={handleAura} auraBusy={busyTarget===entry.item.target_id} currentUserId={onboarding?.user_id}/>)}</section> : <section className="feed-empty surface"><div className="feed-empty-icon"><Sparkles size={26}/></div><h3>{feedMode==='fyp'?'For You is warming up.':'Rising is quiet.'}</h3><p className="muted">{feedMode==='fyp'?'Every public post is eligible here. Publish the first one or come back as the community posts.':'Fresh public posts will appear here as they start moving.'}</p></section>}
    <AuraQuickSheet open={auraOpen} dashboard={dashboard} onClose={()=>setAuraOpen(false)}/>
  </div>
}
