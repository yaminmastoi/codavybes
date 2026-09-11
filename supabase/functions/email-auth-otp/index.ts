import { createClient } from 'npm:@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const encoder = new TextEncoder()
const OTP_TTL_MS = 5 * 60 * 1000
const RESEND_COOLDOWN_MS = 60 * 1000

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

function configuration() {
  const url = env('SUPABASE_URL', 'PRIVATE_SB_URL')
  const publishableKeys = envMap('SUPABASE_PUBLISHABLE_KEYS')
  const secretKeys = envMap('SUPABASE_SECRET_KEYS')
  const anon = publishableKeys.default || env('SUPABASE_ANON_KEY', 'PRIVATE_SB_ANON_KEY')
  const serviceRole = secretKeys.default || env('PRIVATE_SB_SECRET_KEY', 'SB_SERVICE_ROLE_KEY', 'SERVICE_ROLE_KEY', 'SUPABASE_SERVICE_ROLE_KEY')
  const resendKey = env('RESEND_API_KEY')
  const from = env('AUTH_OTP_FROM')
  const pepper = env('AUTH_OTP_PEPPER')
  if (!url || !anon || !serviceRole || !resendKey || !from || !pepper) {
    throw new Error('Email verification service is not configured.')
  }
  return { url, anon, serviceRole, resendKey, from, pepper }
}

function normalizeEmail(value: unknown) {
  const email = String(value || '').trim().toLowerCase()
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) throw new Error('Enter a valid email address.')
  return email
}

function generateCode() {
  const values = new Uint16Array(1)
  do crypto.getRandomValues(values); while (values[0] >= 63000)
  return String(1000 + (values[0] % 9000))
}

async function hashCode(pepper: string, challengeId: string, code: string) {
  const input = encoder.encode(`${pepper}:${challengeId}:${code}`)
  const digest = await crypto.subtle.digest('SHA-256', input)
  return Array.from(new Uint8Array(digest)).map((x) => x.toString(16).padStart(2, '0')).join('')
}

function maskEmail(email: string) {
  const [name, domain] = email.split('@')
  const shown = name.length <= 2 ? name[0] || '*' : `${name.slice(0, 2)}${'*'.repeat(Math.min(6, name.length - 2))}`
  return `${shown}@${domain}`
}

async function sendEmail(resendKey: string, from: string, email: string, code: string) {
  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from,
      to: [email],
      subject: `${code} is your CodaVybes verification code`,
      html: `<!doctype html><html><body style="margin:0;background:#0b0b0d;color:#f7f7f8;font-family:Arial,sans-serif"><div style="max-width:520px;margin:0 auto;padding:38px 24px"><div style="font-size:13px;letter-spacing:2px;color:#ff7a1c;font-weight:800">CODAVYBES</div><h1 style="font-size:25px;margin:14px 0 8px">Verify your sign in</h1><p style="color:#b8b8be;line-height:1.6">Enter this 4-digit code in CodaVybes. It expires in 5 minutes.</p><div style="font-size:38px;letter-spacing:14px;font-weight:900;margin:28px 0;color:#ffffff">${code}</div><p style="color:#777780;font-size:12px;line-height:1.6">If you did not try to sign in or create a CodaVybes account, you can ignore this email.</p><div style="margin-top:34px;color:#777780;font-size:11px">Powered by CodaBite</div></div></body></html>`,
      text: `Your CodaVybes verification code is ${code}. It expires in 5 minutes. If you did not request this, ignore this email.`,
    }),
  })
  if (!response.ok) {
    const detail = await response.text().catch(() => '')
    console.error('Resend OTP email failed:', response.status, detail)
    throw new Error('Verification email could not be sent. Try again shortly.')
  }
}

async function createChallenge(service: any, cfg: any, userId: string, email: string, purpose: string) {
  const cutoff = new Date(Date.now() - RESEND_COOLDOWN_MS).toISOString()
  const { data: recent } = await service
    .from('auth_email_otp_challenges')
    .select('created_at')
    .eq('user_id', userId)
    .gte('created_at', cutoff)
    .order('created_at', { ascending: false })
    .limit(1)
  if (recent?.length) throw new Error('Please wait one minute before requesting another code.')

  const id = crypto.randomUUID()
  const code = generateCode()
  const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString()
  const codeHash = await hashCode(cfg.pepper, id, code)
  const { error } = await service.from('auth_email_otp_challenges').insert({
    id, user_id: userId, email, purpose, code_hash: codeHash, expires_at: expiresAt,
  })
  if (error) throw error

  try {
    await sendEmail(cfg.resendKey, cfg.from, email, code)
  } catch (error) {
    await service.from('auth_email_otp_challenges').delete().eq('id', id)
    throw error
  }
  return { id, expiresAt }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ ok: false, error: 'Method not allowed' }, 405)

  try {
    const cfg = configuration()
    const body = await req.json().catch(() => ({}))
    const action = String(body.action || '')
    const service = createClient(cfg.url, cfg.serviceRole, { auth: { persistSession: false, autoRefreshToken: false } })

    if (action === 'start_password') {
      const email = normalizeEmail(body.email)
      const password = String(body.password || '')
      const mode = body.mode === 'signup' ? 'signup' : 'signin'
      if (password.length > 128 || (mode === 'signup' && password.length < 8) || (mode === 'signin' && password.length < 1)) {
        throw new Error(mode === 'signup' ? 'Password must be 8–128 characters.' : 'Enter your password.')
      }

      let user: any = null
      let createdUser = false
      if (mode === 'signup') {
        const { data, error } = await service.auth.admin.createUser({ email, password, email_confirm: true })
        if (error) {
          if (/already|registered|exists/i.test(error.message)) throw new Error('An account with this email already exists. Log in instead.')
          throw error
        }
        user = data.user
        createdUser = true
      } else {
        const verifier = createClient(cfg.url, cfg.anon, { auth: { persistSession: false, autoRefreshToken: false } })
        const { data, error } = await verifier.auth.signInWithPassword({ email, password })
        if (error || !data.user) throw new Error('Invalid email or password.')
        user = data.user
      }

      try {
        const challenge = await createChallenge(service, cfg, user.id, user.email || email, mode)
        return json({ ok: true, challenge_id: challenge.id, email: user.email || email, masked_email: maskEmail(user.email || email), expires_at: challenge.expiresAt })
      } catch (error) {
        if (createdUser) await service.auth.admin.deleteUser(user.id).catch(() => null)
        throw error
      }
    }

    if (action === 'start_authenticated') {
      const authorization = req.headers.get('Authorization')
      if (!authorization) return json({ ok: false, error: 'Authentication required' }, 401)
      const caller = createClient(cfg.url, cfg.anon, {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      })
      const { data, error } = await caller.auth.getUser()
      if (error || !data.user?.email) return json({ ok: false, error: 'A verified email is required for this sign in.' }, 401)
      const purpose = ['oauth', 'reauth'].includes(body.purpose) ? body.purpose : 'oauth'
      const challenge = await createChallenge(service, cfg, data.user.id, data.user.email, purpose)
      return json({ ok: true, challenge_id: challenge.id, email: data.user.email, masked_email: maskEmail(data.user.email), expires_at: challenge.expiresAt })
    }

    if (action === 'resend') {
      const challengeId = String(body.challenge_id || '')
      const email = normalizeEmail(body.email)
      const { data: existing, error } = await service.from('auth_email_otp_challenges')
        .select('id,user_id,email,purpose,created_at,consumed_at')
        .eq('id', challengeId).eq('email', email).maybeSingle()
      if (error || !existing || existing.consumed_at) throw new Error('Verification session expired. Sign in again.')
      if (Date.now() - new Date(existing.created_at).getTime() < RESEND_COOLDOWN_MS) throw new Error('Please wait one minute before requesting another code.')

      const code = generateCode()
      const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString()
      const codeHash = await hashCode(cfg.pepper, existing.id, code)
      const { error: updateError } = await service.from('auth_email_otp_challenges').update({
        code_hash: codeHash, expires_at: expiresAt, created_at: new Date().toISOString(), attempts: 0,
      }).eq('id', existing.id)
      if (updateError) throw updateError
      await sendEmail(cfg.resendKey, cfg.from, email, code)
      return json({ ok: true, challenge_id: existing.id, email, masked_email: maskEmail(email), expires_at: expiresAt })
    }

    if (action === 'verify') {
      const challengeId = String(body.challenge_id || '')
      const email = normalizeEmail(body.email)
      const code = String(body.code || '').replace(/\D/g, '')
      if (!/^\d{4}$/.test(code)) throw new Error('Enter the 4-digit verification code.')

      const { data: challenge, error } = await service.from('auth_email_otp_challenges')
        .select('id,user_id,email,code_hash,expires_at,consumed_at,attempts,max_attempts')
        .eq('id', challengeId).eq('email', email).maybeSingle()
      if (error || !challenge || challenge.consumed_at) throw new Error('Verification session expired. Sign in again.')
      if (new Date(challenge.expires_at).getTime() <= Date.now()) throw new Error('That code expired. Request a new one.')
      if (challenge.attempts >= challenge.max_attempts) throw new Error('Too many incorrect attempts. Request a new code.')

      const candidate = await hashCode(cfg.pepper, challenge.id, code)
      if (candidate !== challenge.code_hash) {
        await service.from('auth_email_otp_challenges').update({ attempts: challenge.attempts + 1 }).eq('id', challenge.id)
        throw new Error('Incorrect verification code.')
      }

      await service.from('auth_email_otp_challenges').update({ consumed_at: new Date().toISOString() }).eq('id', challenge.id)
      const { data: link, error: linkError } = await service.auth.admin.generateLink({ type: 'magiclink', email })
      if (linkError || !link?.properties?.hashed_token) throw new Error('Could not finish sign in. Request a new code.')
      return json({ ok: true, token_hash: link.properties.hashed_token })
    }

    return json({ ok: false, error: 'Unknown verification action' }, 400)
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Verification failed.'
    const status = /wait one minute/i.test(message) ? 429 : 400
    return json({ ok: false, error: message }, status)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
}
