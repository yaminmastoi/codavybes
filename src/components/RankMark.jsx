import { BadgeCheck, CircleDot, Crown, Gem, Orbit, Sparkles, Star, Zap } from 'lucide-react'

const RANK_ICONS = {
  'NEW VIBE': CircleDot,
  LOWKEY: Sparkles,
  VALID: BadgeCheck,
  CERTIFIED: BadgeCheck,
  'MAIN CHARACTER': Star,
  'AURA MAGNET': Orbit,
  'AURA DEMON': Zap,
  UNTOUCHABLE: Gem,
  LORE: Crown,
}

export default function RankMark({ rank, size = 14, label = true }) {
  const name = rank?.name || (typeof rank === 'string' ? rank : 'NEW VIBE')
  const Icon = RANK_ICONS[name] || Sparkles
  return <span className="rank-mark"><Icon size={size} strokeWidth={1.9}/>{label && <span>{name}</span>}</span>
}
