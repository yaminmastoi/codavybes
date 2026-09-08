import { supabase } from '../lib/supabase'

function client() {
  if (!supabase) throw new Error('Supabase is not configured')
  return supabase
}

async function rpc(name, params = {}) {
  const { data, error } = await client().rpc(name, params)
  if (error) throw error
  return data
}

async function edge(name, body) {
  const { data, error } = await client().functions.invoke(name, { body })
  if (error) throw error
  if (data?.error) throw new Error(data.error)
  return data
}

export const adminService = {
  session: () => rpc('admin_get_session'),
  dashboard: () => rpc('admin_get_dashboard'),
  users: (query = '', status = 'all', limit = 50, offset = 0) => rpc('admin_list_users', { p_query: query, p_status: status, p_limit: limit, p_offset: offset }),
  user: async (id) => { const [base,wallet] = await Promise.all([rpc('admin_get_user', { p_user: id }), rpc('admin_get_user_wallet', { p_user: id })]); return { ...base, wallet_balance: wallet?.coin_balance ?? 0, lifetime_topup_coins: wallet?.lifetime_topup_coins ?? 0 } },
  setUserStatus: (id, status, reason, until = null) => rpc('admin_set_user_status', { p_user: id, p_status: status, p_reason: reason, p_until: until }),
  authAction: (id, action, duration = null) => edge('hq-auth-action', { user_id: id, action, duration }),
  changeUsername: (id, username, reason) => rpc('admin_change_username', { p_user: id, p_username: username, p_reason: reason }),
  correctDob: (id, birthDate, reason) => rpc('admin_correct_birth_date', { p_user: id, p_birth_date: birthDate, p_reason: reason }),
  adjustAura: (id, amount, reason) => rpc('admin_adjust_user_aura', { p_user: id, p_amount: Number(amount), p_reason: reason }),
  adjustCoins: (id, amount, reason) => rpc('admin_adjust_user_coins', { p_user: id, p_amount: Number(amount), p_reason: reason }),
  controls: () => rpc('admin_get_control_center'),
  updateConfig: (section, patch, reason = 'CodaVybes HQ update') => rpc('admin_update_config', { p_section: section, p_patch: patch, p_reason: reason }),
  upsertRank: (rank, reason = 'Rank update') => rpc('admin_upsert_rank', { p_id: rank.id ?? null, p_slug: rank.slug, p_name: rank.name, p_min_aura: Number(rank.min_aura), p_badge: rank.badge, p_active: !!rank.active, p_reason: reason }),
  upsertAgeBand: (band, reason = 'Age safety update') => rpc('admin_upsert_age_band', { p_id: band.id ?? null, p_slug: band.slug, p_label: band.label, p_min: Number(band.min_age), p_max: Number(band.max_age), p_active: !!band.active, p_reason: reason }),
  upsertInterest: (interest, reason = 'Interest update') => rpc('admin_upsert_interest', { p_id: interest.id ?? null, p_slug: interest.slug, p_label: interest.label, p_icon: interest.icon, p_active: !!interest.active, p_sort: Number(interest.sort_order || 0), p_reason: reason }),
  setFlag: (key, enabled, payload = null, reason = 'Feature flag update') => rpc('admin_set_feature_flag', { p_key: key, p_enabled: enabled, p_payload: payload, p_reason: reason }),
  verificationRequests: (status = 'pending', limit = 100) => rpc('admin_list_verification_waitlist', { p_status: status, p_limit: limit }),
  reviewVerification: (id, approve, note = '') => rpc('admin_review_verification_request', { p_request: id, p_approve: !!approve, p_note: note }),
  setUserVerification: (id, verified, reason) => rpc('admin_set_user_verification', { p_user: id, p_verified: !!verified, p_reason: reason }),
  reports: (status = 'open', limit = 50) => rpc('admin_list_reports', { p_status: status, p_limit: limit }),
  updateReport: (id, status, note = '') => rpc('admin_update_report', { p_report: id, p_status: status, p_note: note }),
  announcements: () => rpc('admin_list_announcements'),
  createAnnouncement: (payload) => rpc('admin_create_announcement', {
    p_title: payload.title, p_body: payload.body, p_audience: payload.audience || 'all',
    p_starts: payload.starts_at || null, p_ends: payload.ends_at || null,
    p_cta_label: payload.cta_label || null, p_cta_url: payload.cta_url || null,
  }),
  audit: (limit = 100) => rpc('admin_list_audit', { p_limit: limit }),
  admins: () => rpc('admin_list_admins'),
  setAdminRole: (id, role, active, reason) => rpc('admin_set_admin_role', { p_user: id, p_role: role, p_active: active, p_reason: reason }),
  shopItems: () => rpc('admin_list_shop_items'),
  upsertShopItem: (item, reason = 'Shop item update') => rpc('admin_upsert_shop_item_v8', { p_id: item.id ?? null, p_slug: item.slug, p_name: item.name, p_category: item.category, p_description: item.description || '', p_price_coins: Number(item.price_coins || 0), p_price_cents: Number(item.price_cents || 0), p_currency: item.currency || 'USD', p_asset_url: item.asset_url || null, p_active: !!item.active, p_sort: Number(item.sort_order || 0), p_reason: reason }),
  topupPackages: () => rpc('admin_list_topup_packages'),
  upsertTopupPackage: (item, reason = 'Top-up package update') => rpc('admin_upsert_topup_package', { p_id: item.id ?? null, p_slug: item.slug, p_name: item.name, p_coins: Number(item.coins || 0), p_bonus: Number(item.bonus_coins || 0), p_price: Number(item.price_cents || 0), p_currency: item.currency || 'USD', p_active: !!item.active, p_sort: Number(item.sort_order || 0), p_reason: reason }),
  updateCommerce: (patch, reason = 'Commerce settings update') => rpc('admin_update_commerce_v8', { p_patch: patch, p_reason: reason }),

  promotions: () => rpc('admin_list_promotions'),
  upsertPromotion: (item, reason = 'Sponsored promotion update') => rpc('admin_upsert_promotion', {
    p_id: item.id ?? null, p_brand: item.brand_name, p_headline: item.headline, p_body: item.body || '',
    p_image_url: item.image_url || null, p_destination_url: item.destination_url || null,
    p_cta_label: item.cta_label || 'Learn more', p_active: item.active !== false,
    p_priority: Number(item.priority || 0), p_min_age: Math.max(18, Number(item.min_age || 18)), p_starts: item.starts_at || null, p_ends: item.ends_at || null, p_reason: reason,
  }),
  platformPosts: () => rpc('admin_list_platform_posts'),
  createPlatformPost: (post) => rpc('admin_create_platform_post', {
    p_body: post.body, p_image_url: post.image_url || null, p_cta_label: post.cta_label || null,
    p_cta_url: post.cta_url || null, p_pinned_until: post.pinned_until || null,
  }),
  setPlatformPostActive: (id, active, reason = 'Platform post status') => rpc('admin_set_platform_post_active', { p_id: id, p_active: !!active, p_reason: reason }),
  questions: (game = 'all') => rpc('admin_list_game_questions', { p_game: game }),
  upsertQuestion: (q, reason = 'Game question update') => rpc('admin_upsert_game_question', {
    p_id: q.id ?? null, p_game: q.game_type, p_prompt: q.prompt,
    p_options: q.options || [], p_correct: q.correct_answer || null,
    p_active: q.active !== false, p_reason: reason,
  }),
}
