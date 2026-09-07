import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const android = path.join(root, 'platforms', 'mobile-capacitor', 'android')
const appMain = path.join(android, 'app', 'src', 'main')
const drawable = path.join(appMain, 'res', 'drawable')
const sourceIcon = path.join(root, 'release', 'assets', 'codavybes-icon-512.png')

if (!fs.existsSync(appMain)) throw new Error('Android project not generated. Run cap add android first.')
fs.mkdirSync(drawable, { recursive: true })
fs.copyFileSync(sourceIcon, path.join(drawable, 'codavybes_icon.png'))

const manifestPath = path.join(appMain, 'AndroidManifest.xml')
let manifest = fs.readFileSync(manifestPath, 'utf8')
manifest = manifest
  .replace(/android:icon="@[^"]+"/, 'android:icon="@drawable/codavybes_icon"')
  .replace(/android:roundIcon="@[^"]+"/, 'android:roundIcon="@drawable/codavybes_icon"')
fs.writeFileSync(manifestPath, manifest)

console.log('Applied CodaVybes Android branding.')
