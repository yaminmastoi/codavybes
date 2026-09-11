import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'))
const version = process.env.CODAVYBES_VERSION || pkg.version || '1.0.1'
const runNumber = Math.max(1, Number(process.env.CODAVYBES_BUILD_NUMBER || process.env.GITHUB_RUN_NUMBER || 1) || 1)
const [major = 1, minor = 0, patch = 0] = version.split('.').map((part) => Number.parseInt(part, 10) || 0)
// Stable, monotonic base per semantic release plus the CI run number.
const versionBase = Math.min(2_000_000_000, major * 10_000_000 + minor * 100_000 + patch * 1_000)
const versionCode = Math.min(2_100_000_000, versionBase + Math.min(runNumber, 999))
const gradlePath = path.join(root, 'platforms', 'mobile-capacitor', 'android', 'app', 'build.gradle')

if (!fs.existsSync(gradlePath)) throw new Error('Android build.gradle not found. Generate Android first.')
let gradle = fs.readFileSync(gradlePath, 'utf8')
gradle = gradle.replace(/versionCode\s+\d+/, `versionCode ${versionCode}`)
gradle = gradle.replace(/versionName\s+["'][^"']+["']/, `versionName "${version}"`)
fs.writeFileSync(gradlePath, gradle)
console.log(`Applied Android versionName ${version}, versionCode ${versionCode}`)
