import fs from 'node:fs'
import path from 'node:path'

const root = process.cwd()
const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'))
const version = process.env.CODAVYBES_VERSION || pkg.version || '13.4.0'
const runNumber = Number(process.env.CODAVYBES_BUILD_NUMBER || process.env.GITHUB_RUN_NUMBER || 1)
const versionCode = Math.min(2_100_000_000, 13_400_000 + Math.max(1, Math.floor(runNumber)))
const gradlePath = path.join(root, 'platforms', 'mobile-capacitor', 'android', 'app', 'build.gradle')
if (!fs.existsSync(gradlePath)) throw new Error('Android build.gradle not found. Generate Android first.')
let gradle = fs.readFileSync(gradlePath, 'utf8')
gradle = gradle.replace(/versionCode\s+\d+/, `versionCode ${versionCode}`)
gradle = gradle.replace(/versionName\s+["'][^"']+["']/, `versionName "${version}"`)
fs.writeFileSync(gradlePath, gradle)
console.log(`Applied Android versionName ${version}, versionCode ${versionCode}`)
