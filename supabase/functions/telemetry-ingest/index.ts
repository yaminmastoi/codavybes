import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const publishableKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') || '{}')
  const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}')
  const anon = publishableKeys.default || Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRole = secretKeys.default || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const authorization = req.headers.get('Authorization')
  if (!url || !anon || !serviceRole || !authorization) return json({ error: 'Server configuration missing' }, 500)

  const caller = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: userData, error: userError } = await caller.auth.getUser()
  const user = userData?.user
  if (userError || !user) return json({ error: 'Authentication required' }, 401)

  const payload = await req.json().catch(() => ({}))
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) return json({ error: 'Invalid payload' }, 400)

  const ip = firstHeader(req, ['cf-connecting-ip', 'x-real-ip', 'x-forwarded-for'])
  const country = firstHeader(req, ['cf-ipcountry', 'x-vercel-ip-country', 'x-geo-country'])
  const region = firstHeader(req, ['x-vercel-ip-country-region', 'x-geo-region'])
  const city = decodeHeader(firstHeader(req, ['x-vercel-ip-city', 'x-geo-city']))

  const service = createClient(url, serviceRole, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data, error } = await service.rpc('telemetry_ingest_server', {
    p_user: user.id,
    p_payload: payload,
    p_ip: normalizeIp(ip),
    p_country: country,
    p_region: region,
    p_city: city,
  })
  if (error) return json({ error: error.message }, 400)
  return json(data || { ok: true })
})

function firstHeader(req: Request, names: string[]) {
  for (const name of names) {
    const value = req.headers.get(name)
    if (value) return value.split(',')[0].trim()
  }
  return null
}

function normalizeIp(value: string | null) {
  if (!value) return null
  const v = value.trim()
  if (v.startsWith('[')) return v.replace(/^\[|\](?::\d+)?$/g, '')
  const ipv4Port = v.match(/^(\d+\.\d+\.\d+\.\d+):\d+$/)
  return ipv4Port ? ipv4Port[1] : v
}

function decodeHeader(value: string | null) {
  if (!value) return null
  try { return decodeURIComponent(value) } catch { return value }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
}
