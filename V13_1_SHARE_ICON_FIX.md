# CodaVybes V13.1 Share Icon Hotfix

Fixes Vite runtime crash:
`lucide-react does not provide an export named Instagram`.

Changed `src/components/ShareMomentModal.jsx`:
- removed `Instagram` and `Linkedin` brand imports from `lucide-react`
- added local inline SVG `InstagramGlyph` and `LinkedInGlyph`
- no database migration required

Replace this file or deploy the full V13.1 package, then restart/redeploy the frontend.
