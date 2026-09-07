import { ArrowUpRight, BadgeDollarSign } from 'lucide-react'
import { useEffect, useRef } from 'react'
import { recordPromotionEvent } from '../services/promotionService'

export default function SponsoredCard({ promotion }) {
  const logged = useRef(false)
  useEffect(() => {
    if (!promotion?.id || logged.current) return
    logged.current = true
    recordPromotionEvent(promotion.id, 'impression')
  }, [promotion?.id])

  const open = () => {
    recordPromotionEvent(promotion.id, 'click')
    if (promotion.destination_url) window.open(promotion.destination_url, '_blank', 'noopener,noreferrer')
  }

  return <article className="sponsored-card surface">
    <header className="sponsored-card__top">
      <div className="sponsored-card__brand"><span className="sponsored-mark"><BadgeDollarSign size={16}/></span><div><strong>{promotion.brand_name}</strong><small>Sponsored on CodaVybes</small></div></div>
      <span className="sponsored-label">SPONSORED</span>
    </header>
    {promotion.image_url && <button className="sponsored-media" onClick={open} aria-label={`Open ${promotion.brand_name} promotion`}><img src={promotion.image_url} alt="" loading="lazy" referrerPolicy="no-referrer" onError={(e)=>{e.currentTarget.closest('.sponsored-media')?.classList.add('is-broken')}}/></button>}
    <div className="sponsored-card__copy"><h3>{promotion.headline}</h3>{promotion.body && <p>{promotion.body}</p>}</div>
    {promotion.destination_url && <button className="sponsored-cta" onClick={open}>{promotion.cta_label || 'Learn more'} <ArrowUpRight size={16}/></button>}
  </article>
}
