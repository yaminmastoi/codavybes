import { createClient } from 'npm:@supabase/supabase-js@2'

const defaultAllowedOrigins = [
  'https://app-codavybes.vercel.app',
  'https://codavybes.vercel.app',
  'http://localhost:5173',
  'http://localhost:3000',
  'http://localhost',
  'capacitor://localhost',
  'tauri://localhost',
  'http://tauri.localhost',
  'https://tauri.localhost',
]

function corsHeaders(req: Request) {
  const origin = req.headers.get('Origin') || ''
  const configured = (Deno.env.get('CORS_ALLOWED_ORIGINS') || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean)
  const allowed = new Set([...defaultAllowedOrigins, ...configured])
  const allowOrigin = origin && (origin === 'null' || allowed.has(origin)) ? origin : '*'

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  }
}

const safe = (value: unknown, fallback = '') => String(value || fallback).slice(0, 500)
const optionalSafe = (value: unknown) => safe(value) || null

function header(req: Request, ...names: string[]) {
  for (const name of names) {
    const value = req.headers.get(name)
    if (value) return value
  }
  return ''
}

function decodeHeader(value: string) {
  if (!value) return ''
  try { return decodeURIComponent(value) }
  catch { return value }
}

function env(...names: string[]) {
  for (const name of names) {
    const value = Deno.env.get(name)
    if (value) return value
  }
  return ''
}

function envMap(name: string) {
  try { return JSON.parse(Deno.env.get(name) || '{}') }
  catch { return {} }
}

Deno.serve(async (req) => {
  const headers = corsHeaders(req)
  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405, headers)

  const url = env('SUPABASE_URL', 'PRIVATE_SB_URL')
  const publishableKeys = envMap('SUPABASE_PUBLISHABLE_KEYS')
  const secretKeys = envMap('SUPABASE_SECRET_KEYS')
  const anon = publishableKeys.default || env('SUPABASE_ANON_KEY', 'PRIVATE_SB_ANON_KEY')
  const serviceRole = secretKeys.default || env('PRIVATE_SB_SECRET_KEY', 'SB_SERVICE_ROLE_KEY', 'SERVICE_ROLE_KEY', 'SUPABASE_SERVICE_ROLE_KEY')
  const authorization = req.headers.get('Authorization')
  if (!url || !anon || !serviceRole || !authorization) return json({ error: 'Server configuration missing' }, 500, headers)

  const caller = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: userData, error: userError } = await caller.auth.getUser()
  if (userError || !userData.user) return json({ ok: false, reason: 'auth_required' }, 200, headers)

  const body = await req.json().catch(() => ({}))
  if (body?.consent?.analytics !== true) return json({ ok: false, reason: 'analytics_consent_required' }, 200, headers)

  const ip = header(req, 'cf-connecting-ip', 'x-real-ip', 'x-forwarded-for')
  const country = header(req, 'cf-ipcountry', 'x-vercel-ip-country')
  const region = decodeHeader(header(req, 'x-vercel-ip-country-region', 'x-vercel-ip-region'))
  const city = decodeHeader(header(req, 'x-vercel-ip-city'))
  const userAgent = header(req, 'user-agent')

  const service = createClient(url, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data, error } = await service.rpc('track_analytics_event_server', {
    p_user: userData.user.id,
    p_event: safe(body.event_name),
    p_session: optionalSafe(body.session_id),
    p_page: safe(body.page_path, '/') || '/',
    p_platform: safe(body.platform, 'web'),
    p_device: safe(body.device_type, 'unknown'),
    p_referrer: optionalSafe(body.referrer),
    p_locale: optionalSafe(body.locale),
    p_timezone: optionalSafe(body.timezone),
    p_metadata: typeof body.metadata === 'object' && body.metadata ? body.metadata : {},
    p_ip: ip || null,
    p_country: country || null,
    p_region: region || null,
    p_city: city || null,
    p_user_agent: userAgent || null,
  })

  if (error) return json({ ok: false, error: error.message }, 200, headers)
  return json(data || { ok: true }, 200, headers)
})

function json(body: unknown, status = 200, cors: HeadersInit = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
