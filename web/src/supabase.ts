import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase: SupabaseClient | null = url && key
  ? createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } })
  : null

export const appleClientId = import.meta.env.VITE_APPLE_CLIENT_ID || ''

function randomNonce(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32))
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('')
}

async function sha256Hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))
  return Array.from(new Uint8Array(buf), b => b.toString(16).padStart(2, '0')).join('')
}

function loadApple(): Promise<NonNullable<Window['AppleID']>> {
  if (window.AppleID) return Promise.resolve(window.AppleID)
  return new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = 'https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js'
    script.async = true
    script.onload = () => window.AppleID ? resolve(window.AppleID) : reject(new Error('apple_js'))
    script.onerror = () => reject(new Error('apple_js'))
    document.head.appendChild(script)
  })
}

/** Same nonce split as the iPhone app: Apple receives the hash, Supabase the raw nonce. */
export async function appleIdToken(): Promise<{ token: string; nonce: string }> {
  if (!appleClientId) throw new Error('apple_not_configured')
  const nonce = randomNonce()
  const AppleID = await loadApple()
  AppleID.auth.init({
    clientId: appleClientId,
    scope: 'name email',
    redirectURI: `${window.location.origin}/`,
    nonce: await sha256Hex(nonce),
    usePopup: true,
  })
  const result = await AppleID.auth.signIn()
  const token = result.authorization?.id_token
  if (!token) throw new Error('apple_no_token')
  return { token, nonce }
}
