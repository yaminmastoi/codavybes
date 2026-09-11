import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type Json = Record<string, unknown>

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { 'content-type': 'application/json; charset=utf-8' },
})
const env = (...names: string[]) => {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim()
    if (value) return value
  }
  return ''
}
const envMap = (name: string): Record<string,string> => {
  try { return JSON.parse(Deno.env.get(name) || '{}') }
  catch { return {} }
}
const b64url = (input: Uint8Array | string) => {
  const bytes = typeof input === 'string' ? new TextEncoder().encode(input) : input
  let binary = ''
  for (const b of bytes) binary += String.fromCharCode(b)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
}
function pemBytes(pem: string) {
  const raw = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '')
  return Uint8Array.from(atob(raw), c => c.charCodeAt(0))
}
async function firebaseAccessToken(serviceAccount: Json) {
  const privateKey = String(serviceAccount.private_key || '')
  const clientEmail = String(serviceAccount.client_email || '')
  if (!privateKey || !clientEmail) throw new Error('Firebase service account is incomplete')
  const now = Math.floor(Date.now() / 1000)
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claim = b64url(JSON.stringify({
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))
  const key = await crypto.subtle.importKey('pkcs8', pemBytes(privateKey), { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const unsigned = `${header}.${claim}`
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned))
  const assertion = `${unsigned}.${b64url(new Uint8Array(signature))}`
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  })
  const body = await response.json()
  if (!response.ok || !body.access_token) throw new Error(`Firebase OAuth failed: ${body.error_description || body.error || response.status}`)
  return String(body.access_token)
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405)
  const expected = env('PUSH_WEBHOOK_SECRET')
  if (!expected || request.headers.get('x-codavybes-push-secret') !== expected) return json({ error: 'UNAUTHORIZED' }, 401)

  const url = env('SUPABASE_URL', 'PRIVATE_SB_URL')
  const secretKeys = envMap('SUPABASE_SECRET_KEYS')
  const role = secretKeys.default || env('PRIVATE_SB_SECRET_KEY', 'SB_SERVICE_ROLE_KEY', 'SERVICE_ROLE_KEY', 'SUPABASE_SERVICE_ROLE_KEY')
  const serviceJson = env('FIREBASE_SERVICE_ACCOUNT_JSON')
  if (!url || !role || !serviceJson) return json({ error: 'PUSH_NOT_CONFIGURED' }, 503)

  const payload = await request.json().catch(() => ({})) as Json
  // Supabase Database Webhooks send the inserted row under `record`.
  const record = (payload.record || payload) as Json
  const userId = String(record.user_id || '')
  if (!userId) return json({ ok: true, skipped: 'no_user' })

  const supabase = createClient(url, role, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data: tokens, error } = await supabase.schema('private').from('push_device_tokens')
    .select('id,token,platform').eq('user_id', userId).eq('active', true)
  if (error) return json({ error: 'TOKEN_LOOKUP_FAILED', detail: error.message }, 500)
  if (!tokens?.length) return json({ ok: true, sent: 0 })

  const serviceAccount = JSON.parse(serviceJson) as Json
  const projectId = String(serviceAccount.project_id || '')
  if (!projectId) return json({ error: 'FIREBASE_PROJECT_ID_MISSING' }, 503)
  const accessToken = await firebaseAccessToken(serviceAccount)
  const title = String(record.title || 'CodaVybes').slice(0, 180)
  const body = String(record.body || '').slice(0, 1000)
  const link = String(record.link || '/notifications')
  const data: Record<string,string> = {
    notification_id: String(record.id || ''),
    type: String(record.type || 'system'),
    entity_type: String(record.entity_type || ''),
    entity_id: String(record.entity_id || ''),
    link,
  }

  let sent = 0
  const invalid: string[] = []
  for (const target of tokens) {
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`, {
      method: 'POST',
      headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ message: {
        token: target.token,
        notification: { title, body },
        data,
        android: { priority: 'high', notification: { channel_id: 'codavybes-alerts', sound: 'default' } },
        apns: { payload: { aps: { sound: 'default' } } },
      }}),
    })
    if (response.ok) { sent += 1; continue }
    const text = await response.text()
    if (/UNREGISTERED|registration-token-not-registered/i.test(text)) invalid.push(target.id)
    console.error('FCM send failed', response.status, text.slice(0, 700))
  }
  if (invalid.length) await supabase.schema('private').from('push_device_tokens').update({ active:false, updated_at:new Date().toISOString() }).in('id', invalid)
  return json({ ok: true, sent, invalidated: invalid.length })
})
