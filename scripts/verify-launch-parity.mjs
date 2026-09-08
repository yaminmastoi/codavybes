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
const appRoutes = read('src/App.jsx')
const appShell = read('src/layouts/AppShell.jsx')
const manifest = json('public/manifest.webmanifest')
const vercel = json('vercel.json')

check(rootPackage.scripts?.build === 'vite build', 'Web uses the root Vite production build')
check(mobileConfig.includes("webDir: '../../dist'"), 'Android packages the shared root dist bundle')
check(mobilePackage.scripts?.['web:build'] === 'cd ../.. && npm run build', 'Android rebuilds the shared frontend before sync')
check(desktopConfig.build?.frontendDist === '../../../dist', 'Windows packages the shared root dist bundle')
check(desktopConfig.build?.beforeBuildCommand === 'cd ../.. && npm run build', 'Windows rebuilds the shared frontend from the correct root')
check(desktopPackage.scripts?.build === 'tauri build', 'Windows release script invokes Tauri build')
check(mobileConfig.includes("appName: 'CodaVybes'"), 'Android display name is CodaVybes')
check(desktopConfig.productName === 'CodaVybes' && desktopConfig.app?.windows?.[0]?.title === 'CodaVybes', 'Windows product and window names are CodaVybes')
check(manifest.name === 'CodaVybes' && manifest.short_name === 'CodaVybes', 'Web/PWA manifest is branded CodaVybes')
check(Array.isArray(vercel.rewrites) && vercel.rewrites.some((entry) => entry.destination === '/index.html'), 'Web host supports client-side routes')

const requiredRoutes = [
  '/home', '/discover', '/rooms', '/rooms/:roomId', '/chats', '/chats/:conversationId',
  '/meet/:sessionId', '/you', '/notifications', '/settings', '/wallet', '/shop',
  '/vybe-plus', '/moments/:targetId', '/privacy', '/cookies', '/security', '/terms', '/hq',
]
for (const route of requiredRoutes) check(appRoutes.includes(`path="${route}"`), `Shared route available: ${route}`)
check(appShell.includes('<Outlet />'), 'Every signed-in route renders through the shared platform shell')
const platformForks = sourceFiles(resolve(root, 'src')).filter((path) => /VITE_APP_PLATFORM|VITE_PLATFORM_ONLY/.test(readFileSync(path, 'utf8')))
check(platformForks.length === 0, 'No web, Android or Windows feature fork exists in the shared source')

const migrationNames = readdirSync(resolve(root, 'supabase/migrations'))
for (let index = 1; index <= 19; index += 1) {
  const prefix = String(index).padStart(3, '0') + '_'
  check(migrationNames.some((name) => name.startsWith(prefix)), `Supabase migration ${String(index).padStart(3, '0')} is present`)
}

check(existsSync(resolve(root, 'public/vybe-sw.js')), 'PWA service worker is present')
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
