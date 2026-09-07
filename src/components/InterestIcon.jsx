import { BookOpen, BrainCircuit, Camera, Clapperboard, Cpu, Dumbbell, Gamepad2, Gauge, Laugh, MoonStar, Music2, Palette, Plane, Rocket, Sparkles, Trophy, Utensils } from 'lucide-react'

export const INTEREST_ICON_KEYS = [
  ['gamepad','Gaming'],['trophy','Sport'],['gauge','Motorsport'],['music','Music'],['film','Movies'],['laugh','Memes'],['brain','Deep Talks'],['moon','Night'],['cpu','Tech'],['rocket','Startups'],['dumbbell','Fitness'],['camera','Photography'],['palette','Art'],['book','Books'],['plane','Travel'],['food','Food'],['sparkles','General'],
]
const icons={gamepad:Gamepad2,trophy:Trophy,gauge:Gauge,music:Music2,film:Clapperboard,laugh:Laugh,brain:BrainCircuit,moon:MoonStar,cpu:Cpu,rocket:Rocket,dumbbell:Dumbbell,camera:Camera,palette:Palette,book:BookOpen,plane:Plane,food:Utensils,sparkles:Sparkles}
const slugDefaults={gaming:'gamepad',football:'trophy',f1:'gauge',music:'music',movies:'film',memes:'laugh',deep_talks:'brain',night_owls:'moon',tech:'cpu',startups:'rocket',gym:'dumbbell',photography:'camera',art:'palette',books:'book',travel:'plane',food:'food'}

export default function InterestIcon({ interest, size=14 }) {
  const slug=typeof interest==='string'?interest:interest?.slug
  const key=typeof interest==='object' && icons[interest?.icon] ? interest.icon : slugDefaults[slug] || 'sparkles'
  const Icon=icons[key]||Sparkles
  return <Icon size={size} strokeWidth={1.9}/>
}
