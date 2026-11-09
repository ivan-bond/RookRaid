// Web Push for friend requests (PushRegistration.swift in the app). Needs VITE_VAPID_PUBLIC_KEY and the service
// worker (public/push-sw.js is imported into the generated one). On iPhone/iPad, Safari only offers push to a
// Rook Raid that was added to the home screen.
import { getLang } from './i18n'
import { supabase } from './supabase'

const VAPID = import.meta.env.VITE_VAPID_PUBLIC_KEY || ''

export const pushSupported = () =>
  !!VAPID && !!supabase && typeof window !== 'undefined' && 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
export const pushPermission = (): NotificationPermission | 'unsupported' => (pushSupported() ? Notification.permission : 'unsupported')

function keyBytes(b64: string): Uint8Array<ArrayBuffer> {
  const s = atob(b64.replace(/-/g, '+').replace(/_/g, '/') + '=='.slice(0, (4 - b64.length % 4) % 4))
  const out = new Uint8Array(new ArrayBuffer(s.length))
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i)
  return out
}

/** Ask once (from a button – browsers require a tap), then register this browser. */
export async function enablePush(): Promise<boolean> {
  if (!pushSupported()) return false
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') return false
  await syncPush()
  return true
}

/** Register (again) when permission is already there – the subscription can change. Silent on errors. */
export async function syncPush(): Promise<void> {
  if (!pushSupported() || Notification.permission !== 'granted') return
  try {
    const reg = await navigator.serviceWorker.ready
    const sub = await reg.pushManager.getSubscription()
      ?? await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(VAPID) })
    await supabase!.rpc('register_push_token', {
      p_platform: 'web', p_token: null, p_environment: null, p_subscription: sub.toJSON(), p_locale: getLang(),
    })
  } catch { /* no service worker (dev server) or offline: next start */ }
}

/** Before signing out: this browser should not get the old account's notifications. */
export async function dropPush(): Promise<void> {
  if (!pushSupported()) return
  try {
    const reg = await navigator.serviceWorker.getRegistration()
    const sub = await reg?.pushManager.getSubscription()
    if (!sub) return
    await supabase!.rpc('unregister_push_token', { p_token: sub.endpoint })
    await sub.unsubscribe()
  } catch { /* offline: the server drops it once the push service reports it gone */ }
}
