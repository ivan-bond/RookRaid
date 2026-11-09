// Friends (FriendsService.swift in the app): list, requests, search by name or friend code, invite link,
// profile summary, blocking and reporting. Everything goes through the server functions of
// Backend/supabase/migrations/20261107120000_friends.sql.
import { useSyncExternalStore } from 'react'
import { supabase } from './supabase'
import * as Online from './online'

export type Relation = 'none' | 'self' | 'friend' | 'incoming' | 'outgoing'
export type Player = {
  userId: string; name: string; avatar: string; frame: string | null; title: string | null
  level: number; trophies: number; relation: Relation; since: string | null
}
export type FriendProfile = Player & {
  bestTrophies: number; wins: number; losses: number; draws: number; rank: number; friends: number
  memberSince: string | null; vsWins: number; vsLosses: number; vsDraws: number
}
export type ReportReason = 'name' | 'cheating' | 'abuse' | 'other'
/** What changed since the last refresh: shown as a small banner (like the app's in-app notice). */
export type FriendNews = { kind: 'request' | 'accepted'; name: string; userId: string } | null

type State = { players: Player[]; code: string | null; loaded: boolean; news: FriendNews }
let state: State = { players: [], code: null, loaded: false, news: null }
const listeners = new Set<() => void>()
function set(patch: Partial<State>) { state = { ...state, ...patch }; listeners.forEach(fn => fn()) }
export function useFriends(): State {
  return useSyncExternalStore(fn => { listeners.add(fn); return () => listeners.delete(fn) }, () => state)
}
export const getFriends = () => state
export const incomingCount = (s: State = state) => s.players.filter(p => p.relation === 'incoming').length
export const clearNews = () => set({ news: null })

function db() {
  if (!supabase) throw new Error('offline')
  return supabase
}

type Row = { user_id: string; display_name: string; avatar: string; frame: string | null; title: string | null; level: number; trophies: number; relation: Relation; since?: string | null }
const toPlayer = (r: Row): Player => ({
  userId: r.user_id, name: r.display_name, avatar: r.avatar, frame: r.frame, title: r.title, level: r.level,
  trophies: r.trophies, relation: r.relation, since: r.since ?? null,
})

/** Server error text → German key (shown with t()). */
export function friendError(e: unknown): string {
  const text = e instanceof Error ? e.message : typeof e === 'object' && e && 'message' in e ? String((e as { message: unknown }).message) : String(e)
  if (text.includes('too_many_requests')) return 'Zu viele Anfragen. Versuche es später noch einmal.'
  if (text.includes('friend_limit')) return 'Ihr könnt höchstens 200 Freunde haben.'
  if (text.includes('no_account')) return 'Zuerst brauchst du ein Online-Konto.'
  if (text.includes('not_found')) return 'Niemand gefunden. Prüfe den Namen oder den Code.'
  return Online.serverMessage(e)
}

let refreshing: Promise<void> | null = null
export function refreshFriends(): Promise<void> {
  if (!Online.hasAccount() || !supabase) { set({ players: [], code: null, loaded: false, news: null }); return Promise.resolve() }
  refreshing ??= (async () => {
    try {
      const [list, code] = await Promise.all([db().rpc('my_friends'), state.code ? Promise.resolve({ data: state.code, error: null }) : db().rpc('my_friend_code')])
      if (list.error) throw list.error
      const players = ((list.data ?? []) as Row[]).map(toPlayer)
      // News: a new request for me, or someone accepted mine (only after the first load).
      let news: FriendNews = state.news
      if (state.loaded) {
        const before = new Map(state.players.map(p => [p.userId, p.relation]))
        const fresh = players.find(p => p.relation === 'incoming' && before.get(p.userId) !== 'incoming')
        const accepted = players.find(p => p.relation === 'friend' && before.get(p.userId) === 'outgoing')
        if (fresh) news = { kind: 'request', name: fresh.name, userId: fresh.userId }
        else if (accepted) news = { kind: 'accepted', name: accepted.name, userId: accepted.userId }
      }
      set({ players, code: (code.data as string | null) ?? state.code, loaded: true, news })
    } catch { /* offline: keep the last list */ } finally { refreshing = null }
  })()
  return refreshing
}

/** The push for the other player goes out right away (push-dispatch only sends what the server queued). */
function dispatchPush() { void supabase?.functions.invoke('push-dispatch', { method: 'POST' }).catch(() => undefined) }

export async function findPlayers(query: string): Promise<Player[]> {
  const { data, error } = await db().rpc('find_player', { p_query: query.trim() })
  if (error) throw error
  return ((data ?? []) as Row[]).map(toPlayer)
}

/** 'sent' | 'accepted' | 'already_friends' */
export async function sendRequest(userId: string): Promise<string> {
  const { data, error } = await db().rpc('send_friend_request', { p_user: userId })
  if (error) throw error
  dispatchPush()
  await refreshFriends()
  return String(data)
}
export async function respond(userId: string, accept: boolean) {
  const { error } = await db().rpc('respond_friend_request', { p_user: userId, p_accept: accept })
  if (error && !String(error.message).includes('no_request')) throw error
  if (accept) dispatchPush()
  await refreshFriends()
}
export async function cancelRequest(userId: string) {
  const { error } = await db().rpc('cancel_friend_request', { p_user: userId }); if (error) throw error
  await refreshFriends()
}
export async function removeFriend(userId: string) {
  const { error } = await db().rpc('remove_friend', { p_user: userId }); if (error) throw error
  await refreshFriends()
}
export async function block(userId: string) {
  const { error } = await db().rpc('block_player', { p_user: userId }); if (error) throw error
  await refreshFriends()
}
export async function unblock(userId: string) {
  const { error } = await db().rpc('unblock_player', { p_user: userId }); if (error) throw error
}
export async function blockedPlayers(): Promise<Array<{ userId: string; name: string; avatar: string; frame: string | null }>> {
  const { data, error } = await db().rpc('blocked_players')
  if (error) throw error
  return ((data ?? []) as Array<{ user_id: string; display_name: string; avatar: string; frame: string | null }>)
    .map(r => ({ userId: r.user_id, name: r.display_name, avatar: r.avatar, frame: r.frame }))
}
export async function report(userId: string, reason: ReportReason) {
  const { error } = await db().rpc('report_player', { p_user: userId, p_reason: reason }); if (error) throw error
}
export async function profile(userId: string): Promise<FriendProfile> {
  const { data, error } = await db().rpc('friend_profile', { p_user: userId })
  if (error) throw error
  const r = data as Record<string, unknown>
  const n = (k: string) => Number(r[k] ?? 0)
  return {
    userId: String(r.user_id), name: String(r.display_name), avatar: String(r.avatar), frame: (r.frame as string | null) ?? null,
    title: (r.title as string | null) ?? null, level: n('level'), trophies: n('trophies'), relation: r.relation as Relation,
    since: (r.since as string | null) ?? null, bestTrophies: n('best_trophies'), wins: n('online_wins'), losses: n('online_losses'),
    draws: n('online_draws'), rank: n('rank'), friends: n('friends'), memberSince: (r.member_since as string | null) ?? null,
    vsWins: n('vs_wins'), vsLosses: n('vs_losses'), vsDraws: n('vs_draws'),
  }
}

// MARK: Invite link

/** The same link the app shares: https://<site>/f/<CODE>. The app opens it directly when installed (Universal Link). */
export const inviteLink = (code: string) => `${location.origin}/f/${code}`
export const CODE_RE = /^[2-9A-HJ-NP-Z]{6}$/

/** A friend link or a push tap the page was opened with. Read once at start, then the address is cleaned up. */
let launch: { code: string | null; openFriends: boolean } = { code: null, openFriends: false }
{
  const m = location.pathname.match(/^\/f\/([2-9A-HJ-NP-Za-hj-np-z]{6})\/?$/)
  const push = new URLSearchParams(location.search).get('friends') === '1'
  if (m || push) {
    launch = { code: m ? m[1].toUpperCase() : null, openFriends: true }
    history.replaceState(null, '', '/')
  }
}
export function takeLaunch(): { code: string | null; openFriends: boolean } {
  const l = launch
  launch = { code: null, openFriends: false }
  if (l.code) invite = l.code
  return l
}
/** The invite code waits until there is an account (a new player first creates one, then lands on the friend). */
let invite: string | null = null
export function consumeInvite(): string | null { const c = invite; invite = null; return c }

// Keep the list fresh: on return to the tab and every minute while visible (requests arrive without a reload).
if (supabase) {
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') void refreshFriends() })
  window.setInterval(() => { if (document.visibilityState === 'visible' && Online.hasAccount()) void refreshFriends() }, 60_000)
}
