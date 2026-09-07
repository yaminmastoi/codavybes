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

export async function getCommerceSummary() {
  return (await rpc('get_my_commerce_summary')) ?? {}
}

export async function getShopItems() {
  const { data, error } = await client().from('shop_items').select('id,slug,name,category,description,price_coins,price_cents,currency,asset_url,metadata,sort_order').eq('active', true).order('sort_order').order('name')
  if (error) throw error
  return data ?? []
}

export async function getTopupPackages() {
  const { data, error } = await client().from('topup_packages').select('id,slug,name,coins,bonus_coins,price_cents,currency,sort_order').eq('active', true).order('sort_order').order('price_cents')
  if (error) throw error
  return data ?? []
}

export async function getWalletLedger(limit = 40) {
  const data = await rpc('get_my_wallet_ledger', { p_limit: limit })
  return data ?? []
}

export function createTopupCheckout(packageId) {
  return rpc('create_topup_checkout', { p_package: packageId })
}

export function buyShopItem(itemId) {
  return rpc('buy_shop_item', { p_item: itemId })
}

export function equipShopItem(itemId) {
  return rpc('equip_shop_item', { p_item: itemId })
}

export function subscribeVybePlus() {
  return rpc('subscribe_vybe_plus')
}
