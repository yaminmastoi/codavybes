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
  const { data: admin, error: adminError } = await caller.rpc('admin_get_session')
  if (adminError || !admin?.can_manage_users) return json({ error: 'Admin permission required' }, 403)

  const body = await req.json().catch(() => ({}))
  const userId = String(body.user_id || '')
  const action = String(body.action || '')
  if (!/^[0-9a-f-]{36}$/i.test(userId)) return json({ error: 'Invalid user id' }, 400)

  const service = createClient(url, serviceRole, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  let error: Error | null = null
  if (action === 'ban') {
    const duration = String(body.duration || '876000h')
    if (!/^\d+(ms|s|m|h)$/.test(duration)) return json({ error: 'Invalid ban duration' }, 400)
    ;({ error } = await service.auth.admin.updateUserById(userId, { ban_duration: duration }))
  } else if (action === 'unban') {
    ;({ error } = await service.auth.admin.updateUserById(userId, { ban_duration: 'none' }))
  } else if (action === 'delete') {
    if (admin.role !== 'super_admin') return json({ error: 'Super Admin required' }, 403)
    ;({ error } = await service.auth.admin.deleteUser(userId, true))
  } else {
    return json({ error: 'Unknown action' }, 400)
  }

  if (error) return json({ error: error.message }, 400)
  return json({ ok: true, action, user_id: userId })
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
