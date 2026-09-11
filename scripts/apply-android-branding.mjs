import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const android = path.join(root, 'platforms', 'mobile-capacitor', 'android')
const appMain = path.join(android, 'app', 'src', 'main')
const drawable = path.join(appMain, 'res', 'drawable')

const iconCandidates = [
  path.join(root, 'platforms', 'mobile-capacitor', 'assets', 'icon.png'),
  path.join(root, 'public', 'brand', 'codavybes-app-icon.png'),
  path.join(root, 'public', 'brand', 'codavybes-fox-clean.png'),
  path.join(root, 'release', 'assets', 'codavybes-icon-512.png'),
]
const sourceIcon = iconCandidates.find((candidate) => fs.existsSync(candidate))

if (!fs.existsSync(appMain)) {
  throw new Error('Android project not generated. Run `npx cap add android` before applying branding.')
}
if (!sourceIcon) {
  throw new Error(`CodaVybes Android icon is missing. Expected one of:\n${iconCandidates.join('\n')}`)
}

fs.mkdirSync(drawable, { recursive: true })
fs.copyFileSync(sourceIcon, path.join(drawable, 'codavybes_icon.png'))

const manifestPath = path.join(appMain, 'AndroidManifest.xml')
let manifest = fs.readFileSync(manifestPath, 'utf8')
manifest = manifest
  .replace(/android:icon="@[^"]+"/, 'android:icon="@drawable/codavybes_icon"')
  .replace(/android:roundIcon="@[^"]+"/, 'android:roundIcon="@drawable/codavybes_icon"')

// Geolocation is optional in CodaVybes, but when a user explicitly enables it
// Android WebView needs matching native permissions. Never request it at startup.
if (!manifest.includes('android.permission.ACCESS_COARSE_LOCATION')) {
  manifest = manifest.replace(
    '<application',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />\n    <application',
  )
}

// Native Google/X OAuth returns to app.codavybes.social://auth/... . Capacitor
// receives appUrlOpen only after Android knows this activity owns the scheme.
if (!manifest.includes('android:scheme="app.codavybes.social"')) {
  const authIntent = `
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="app.codavybes.social" android:host="auth" />
            </intent-filter>`
  manifest = manifest.replace('</activity>', `${authIntent}\n        </activity>`)
}

// Ensure FCM notifications shown while the app is backgrounded/terminated use
// the CodaVybes icon instead of the generic Android application icon.
if (!manifest.includes('com.google.firebase.messaging.default_notification_icon')) {
  const fcmMeta = `
        <meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/codavybes_icon" />`
  manifest = manifest.replace('</application>', `${fcmMeta}\n    </application>`)
}

fs.writeFileSync(manifestPath, manifest)
console.log(`Applied CodaVybes Android branding from ${path.relative(root, sourceIcon)}.`)
