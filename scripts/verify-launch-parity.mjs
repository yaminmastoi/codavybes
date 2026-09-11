import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { resolve } from 'node:path'
import process from 'node:process'

const root = resolve(import.meta.dirname, '..')
const failures = []
const confirmations = []
const production = process.argv.includes('--production')

const read = (path) => readFileSync(resolve(root, path), 'utf8')
const json = (path) => JSON.parse(read(path))
const check = (condition, message) => condition ? confirmations.push(message) : failures.push(message)

const sourceFiles = (directory) => readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
  const path = resolve(directory, entry.name)
  if (entry.isDirectory()) return sourceFiles(path)
  return /\.(?:js|jsx|ts|tsx)$/.test(entry.name) ? [path] : []
})

const rootPackage = json('package.json')
const mobileConfig = read('platforms/mobile-capacitor/capacitor.config.ts')
const mobilePackage = json('platforms/mobile-capacitor/package.json')
const desktopConfig = json('platforms/desktop-tauri/src-tauri/tauri.conf.json')
const desktopPackage = json('platforms/desktop-tauri/package.json')
const logoComponent = read('src/components/Logo.jsx')
const appRoutes = read('src/App.jsx')
const appShell = read('src/layouts/AppShell.jsx')
const indexHtml = read('index.html')
const manifest = json('public/manifest.webmanifest')
const vercel = json('vercel.json')

check(rootPackage.scripts?.build === 'vite build', 'Web uses the root Vite production build')
check(mobileConfig.includes("webDir: '../../dist'"), 'Android packages the shared root dist bundle')
check(mobilePackage.scripts?.['web:build'] === 'cd ../.. && npm run build', 'Android rebuilds the shared frontend before sync')
check(desktopConfig.build?.frontendDist === '../../../dist', 'Windows packages the shared root dist bundle')
check(desktopConfig.build?.beforeBuildCommand === 'cd ../.. && npm run build', 'Windows rebuilds the shared frontend from the correct root')
check(desktopPackage.scripts?.build === 'tauri build', 'Windows release script invokes Tauri build')
check(desktopPackage.scripts?.['build:windows']?.includes('msi,nsis'), 'Windows release script targets MSI and NSIS')
check(desktopPackage.scripts?.['build:linux']?.includes('deb,rpm,appimage'), 'Linux release script targets deb, rpm and AppImage')
check(mobileConfig.includes("appName: 'CodaVybes'"), 'Android display name is CodaVybes')
check(mobileConfig.includes("appId: 'app.codavybes.social'"), 'Android application id uses CodaVybes')
check(mobilePackage.scripts?.assets?.includes('capacitor-assets') && mobilePackage.scripts?.['sync:android']?.includes('npm run assets'), 'Android release sync regenerates native brand assets')
check(desktopConfig.productName === 'CodaVybes' && desktopConfig.app?.windows?.[0]?.title === 'CodaVybes', 'Windows product and window names are CodaVybes')
check(desktopConfig.identifier === 'app.codavybes.desktop', 'Windows identifier uses CodaVybes')
check(manifest.name === 'CodaVybes' && manifest.short_name === 'CodaVybes', 'Web/PWA manifest is branded CodaVybes')
check(logoComponent.includes('/brand/codavybes-mark.png'), 'React logo uses the final fox PNG mark')
check(indexHtml.includes('property="og:image"') && indexHtml.includes('/og-image.png'), 'Open Graph launch image metadata is present')
check(indexHtml.includes('name="twitter:card"') && indexHtml.includes('summary_large_image'), 'Twitter/X large-card metadata is present')
check(Array.isArray(vercel.rewrites) && vercel.rewrites.some((entry) => entry.destination === '/index.html'), 'Web host supports client-side routes')

const requiredRoutes = [
  '/home', '/discover', '/rooms', '/rooms/:roomId', '/chats', '/chats/:conversationId',
  '/meet/:sessionId', '/you', '/notifications', '/settings', '/wallet', '/shop',
  '/vybe-plus', '/moments/:targetId', '/privacy', '/cookies', '/security', '/terms', '/hq',
]
for (const route of requiredRoutes) check(appRoutes.includes(`path="${route}"`), `Shared route available: ${route}`)
check(appShell.includes('<Outlet />'), 'Every signed-in route renders through the shared platform shell')
const featureSurfaceFiles = sourceFiles(resolve(root, 'src')).filter((path) => /[\/](pages|components|onboarding)[\/]|[\/]App\.jsx$/.test(path))
const platformForks = featureSurfaceFiles.filter((path) => /VITE_APP_PLATFORM|VITE_PLATFORM_ONLY/.test(readFileSync(path, 'utf8')))
check(platformForks.length === 0, 'No web, Android, Windows or Linux feature fork exists in shared UI/features')

const migrationNames = readdirSync(resolve(root, 'supabase/migrations'))
for (let index = 1; index <= 25; index += 1) {
  const prefix = String(index).padStart(3, '0') + '_'
  check(migrationNames.some((name) => name.startsWith(prefix)), `Supabase migration ${String(index).padStart(3, '0')} is present`)
}
check(existsSync(resolve(root, 'V13_16_SUPABASE_HOTFIX.md')), 'Supabase signup and analytics hotfix guide is present')
check(read('supabase/migrations/021_signup_analytics_hotfix.sql').includes('v_welcome <> 0') && read('supabase/migrations/021_signup_analytics_hotfix.sql').includes('alter column session_id type text'), 'Supabase hotfix guards zero wallet ledger entries and normalizes analytics sessions')
check(read('supabase/migrations/024_platform_leaderboard.sql').includes('public.users_are_blocked') && read('supabase/migrations/024_platform_leaderboard.sql').includes('\"position\" integer'), 'Leaderboard migration uses the existing block helper and quoted position column')
check(read('scripts/apply-android-branding.mjs').includes('platforms') && read('scripts/apply-android-branding.mjs').includes('mobile-capacitor') && read('scripts/apply-android-branding.mjs').includes('assets'), 'Android branding uses a source-controlled app icon fallback')
check(read('src/services/pushNotificationService.js').includes("id: 'codavybes-alerts'") && read('src/services/pushNotificationService.js').includes('createChannel'), 'Android FCM channel is created before push registration')
check(read('.github/workflows/desktop-linux.yml').includes('VITE_APP_PLATFORM: linux'), 'Linux workflow injects Linux platform metadata and Supabase production env')

check(existsSync(resolve(root, 'public/codavybes-sw.js')), 'CodaVybes PWA service worker is present')
check(existsSync(resolve(root, 'public/vybe-sw.js')), 'Legacy PWA service worker remains for older installs')
check(existsSync(resolve(root, 'public/og-image.png')), '1200x630 social preview image is present')
check(existsSync(resolve(root, 'public/icons/favicon.ico')), 'Browser favicon ICO is present')
check(existsSync(resolve(root, 'public/icons/icon-192.png')) && existsSync(resolve(root, 'public/icons/icon-512.png')), 'PWA install icons are present')
check(existsSync(resolve(root, 'public/brand/codavybes-fox-clean.png')) && existsSync(resolve(root, 'public/brand/codavybes-mark.png')), 'Final cleaned fox brand assets are present')
check(manifest.icons?.some((icon) => icon.src === '/brand/codavybes-mark.png'), 'Web manifest points to the final fox mark')
check(existsSync(resolve(root, 'platforms/mobile-capacitor/assets/icon.png')) && existsSync(resolve(root, 'platforms/mobile-capacitor/assets/splash.png')), 'Android source icon and splash assets are present')
check(existsSync(resolve(root, 'platforms/desktop-tauri/src-tauri/icons/icon.ico')), 'Windows bundle ICO is present')
check(desktopConfig.bundle?.icon?.includes('icons/icon.ico'), 'Windows bundle config points to the ICO icon')
check(desktopConfig.bundle?.icon?.includes('icons/512x512.png') && desktopConfig.bundle?.icon?.includes('icons/icon.png'), 'Linux desktop bundle PNG icons are present in Tauri config')
check(existsSync(resolve(root, '.github/workflows/desktop-linux.yml')), 'Linux desktop GitHub Actions workflow is present')
check(appRoutes.includes('<AnalyticsBridge/>'), 'First-party analytics bridge is mounted in the shared app')
check(existsSync(resolve(root, 'supabase/functions/track-analytics/index.ts')), 'Analytics Edge Function is present for IP/location capture')
check(manifest.icons?.some((icon) => icon.src === '/icons/icon-192.png') && manifest.icons?.some((icon) => icon.src === '/icons/icon-512.png'), 'Web manifest points to generated PNG icons')
check(mobilePackage.dependencies?.['@capacitor/local-notifications'], 'Android native notification bridge dependency is present')
check(read('platforms/desktop-tauri/src-tauri/Cargo.toml').includes('tauri-plugin-deep-link'), 'Windows OAuth deep-link dependency is present')

if (production) {
  const envPath = resolve(root, '.env.local')
  check(existsSync(envPath), 'Production environment file exists')
  if (existsSync(envPath)) {
    const environment = readFileSync(envPath, 'utf8')
    const url = environment.match(/^VITE_SUPABASE_URL=(.+)$/m)?.[1]?.trim()
    const key = environment.match(/^VITE_SUPABASE_PUBLISHABLE_KEY=(.+)$/m)?.[1]?.trim()
    check(Boolean(url && /^https:\/\/.+\.supabase\.co$/i.test(url) && !url.includes('YOUR_PROJECT')), 'Production Supabase URL is configured')
    check(Boolean(key && !key.includes('YOUR_') && key.length > 20), 'Production Supabase publishable key is configured')
    check(!/service_role/i.test(environment), 'No service-role secret is exposed through frontend environment values')
  }
}

for (const message of confirmations) console.log(`PASS  ${message}`)
if (failures.length) {
  for (const message of failures) console.error(`FAIL  ${message}`)
  console.error(`\nLaunch verification failed: ${failures.length} check(s) need attention.`)
  process.exit(1)
}

console.log(`\nLaunch verification passed: ${confirmations.length} checks.`)
if (!production) console.log('Run npm run verify:launch:production before a signed production release.')
