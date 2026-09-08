import { ArrowUpRight, Radio, ShieldCheck } from 'lucide-react'
import Logo from './Logo'

export default function PlatformPostCard({ post }) {
  return <article className="platform-post surface">
    <header><div className="platform-post__identity"><Logo markOnly/><div><div><strong>CodaVybes</strong><ShieldCheck size={15}/></div><small>Official · powered by CodaBite</small></div></div><span><Radio size={13}/> UPDATE</span></header>
    {post.image_url && <img className="platform-post__image" src={post.image_url} alt="" loading="lazy" referrerPolicy="no-referrer"/>}
    <p>{post.body}</p>
    {post.cta_url && <a href={post.cta_url} target="_blank" rel="noreferrer" className="platform-post__cta">{post.cta_label || 'Open'} <ArrowUpRight size={15}/></a>}
  </article>
}
