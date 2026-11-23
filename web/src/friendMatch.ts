// Friendly matches (FriendMatch.swift in the app): invite, accept, decline – and the heartbeat behind the online status.
// Server: migrations 20261109120000_bot_players.sql and 20261123120000_friend_match_time.sql. The inviter picks the
// time control (3 | 2, 5 | 0, 5 | 3, 10 | 5), no trophies, counts for the record between the two. An invite stays open for 2 minutes.
import { useSyncExternalStore } from 'react'
import { RULES_VERSION } from './engine'
import type { TimeControl } from './game/catalog'
import * as S from './game/store'
import { supabase } from './supabase'
import * as Online from './online'
import { friendError } from './friends'

export const LIFETIME_MS = 120_000

/** Time controls for friendly matches (same values as tc_base_ms / tc_increment_ms on the server). */
export const FRIEND_TIMES: TimeControl[] = ['blitz3', 'blitz5', 'rapid5', 'rapid10']
const TIME_KEY = 'rr-friend-time'
/** The last chosen time control for friendly matches (default 5 | 0). */
export function friendTime(): TimeControl {
  try { const v = localStorage.getItem(TIME_KEY) as TimeControl | null; if (v && FRIEND_TIMES.includes(v)) return v } catch { /* storage blocked */ }
  return 'blitz5'
}
function rememberTime(tc: TimeControl) { try { localStorage.setItem(TIME_KEY, tc) } catch { /* storage blocked */ } }
const asTime = (v: unknown): TimeControl => FRIEND_TIMES.includes(v as TimeControl) ? v as TimeControl : 'blitz5'

export type MatchInvite = { id: string; userId: string; name: string; avatar: string; frame: string | null; createdAt: number; timeControl: TimeControl }
export type Outgoing = {
  inviteId: string; friend: string; name: string; avatar: string; frame: string | null; startedAt: number; timeControl: TimeControl
  state: 'waiting' | 'declined' | 'expired' | 'failed'
  /** state 'failed': the text key of the reason (friendError) */
  error?: string
}
/** The friend of the last friendly match (for „Revanche“ on the result screen). */
export type Opponent = { userId: string; name: string; avatar: string; frame: string | null; timeControl: TimeControl }
let lastOpponent: Opponent | null = null
export const getLastOpponent = () => lastOpponent
type State = { incoming: MatchInvite[]; outgoing: Outgoing | null }
let state: State = { incoming: [], outgoing: null }
const listeners = new Set<() => void>()
function set(patch: Partial<State>) { state = { ...state, ...patch }; listeners.forEach(fn => fn()) }
export function useFriendMatch(): State {
  return useSyncExternalStore(fn => { listeners.add(fn); return () => listeners.delete(fn) }, () => state)
}

/** Called with the match id when a friendly match is ready (App opens the game). */
let onReady: ((matchId: string) => void) | null = null
export function setReadyHandler(fn: (matchId: string) => void) { onReady = fn }

const dismissed = new Set<string>()
function db() {
  if (!supabase) throw new Error('offline')
  return supabase
}
const mySetup = () => ({ p_rules_version: RULES_VERSION, p_deck: S.activeDeck(), p_ultimate: S.activeUltimate(), p_card: Online.playerCard() })

type InviteRow = { id: string; user_id: string; display_name: string; avatar: string; frame: string | null; created_at: string; time_control?: string }
/** Heartbeat (online status) and new invites. Every 15 s while the page is visible. */
export async function touch() {
  if (!supabase || !Online.hasAccount()) { if (state.incoming.length) set({ incoming: [] }); return }
  const { data, error } = await supabase.rpc('touch_online')
  if (error || !data) return
  const now = Date.now()
  const incoming = ((data as { invites: InviteRow[] }).invites ?? [])
    .map(r => ({ id: r.id, userId: r.user_id, name: r.display_name, avatar: r.avatar, frame: r.frame, createdAt: Date.parse(r.created_at), timeControl: asTime(r.time_control) }))
    .filter(i => !dismissed.has(i.id) && now - i.createdAt < LIFETIME_MS)
  set({ incoming })
}

let watcher: number | null = null
export async function invite(friend: { userId: string; name: string; avatar: string; frame: string | null }, timeControl: TimeControl) {
  if (!S.deckIsFull()) throw new Error('deck_incomplete')
  const { data, error } = await db().rpc('invite_friend_match', { p_user: friend.userId, ...mySetup(), p_time_control: timeControl })
  if (error) throw error
  rememberTime(timeControl)
  void supabase?.functions.invoke('push-dispatch', { method: 'POST' }).catch(() => undefined)
  const inviteId = String(data)
  set({ outgoing: { inviteId, friend: friend.userId, name: friend.name, avatar: friend.avatar, frame: friend.frame, startedAt: Date.now(), timeControl, state: 'waiting' } })
  watch(inviteId)
}

function watch(inviteId: string) {
  if (watcher) window.clearInterval(watcher)
  watcher = window.setInterval(async () => {
    if (state.outgoing?.inviteId !== inviteId) { window.clearInterval(watcher!); watcher = null; return }
    const { data, error } = await db().rpc('friend_match_status', { p_invite: inviteId })
    if (error || !data) return
    const s = data as { status: string; match_id: string | null }
    if (s.status === 'pending') return
    window.clearInterval(watcher!); watcher = null
    if (s.status === 'accepted' && s.match_id) {
      const o = state.outgoing
      if (o) lastOpponent = { userId: o.friend, name: o.name, avatar: o.avatar, frame: o.frame, timeControl: o.timeControl }
      set({ outgoing: null }); onReady?.(s.match_id); return
    }
    if (state.outgoing) set({ outgoing: { ...state.outgoing, state: s.status === 'declined' ? 'declined' : 'expired' } })
  }, 1000) // every second: bot players answer after 3 s, the game should then start at once
}

export function cancelOutgoing() {
  if (watcher) { window.clearInterval(watcher); watcher = null }
  const out = state.outgoing
  if (out?.state === 'waiting') void supabase?.rpc('cancel_friend_match', { p_invite: out.inviteId })
  set({ outgoing: null })
}

function drop(id: string) { dismissed.add(id); set({ incoming: state.incoming.filter(i => i.id !== id) }) }

export async function accept(inv: MatchInvite) {
  if (!S.deckIsFull()) throw new Error('deck_incomplete')
  drop(inv.id)
  const { data, error } = await db().rpc('answer_friend_match', { p_invite: inv.id, p_accept: true, ...mySetup() })
  if (error) throw error
  lastOpponent = { userId: inv.userId, name: inv.name, avatar: inv.avatar, frame: inv.frame, timeControl: inv.timeControl }
  if (data) onReady?.(String(data))
}

/** „Revanche“ after a friendly match: challenge the same friend again with the same clock. A failure shows in the waiting dialog. */
export async function rematch() {
  const o = lastOpponent
  if (!o) return
  try { await invite(o, o.timeControl) } catch (e) {
    set({ outgoing: { inviteId: '', friend: o.userId, name: o.name, avatar: o.avatar, frame: o.frame, startedAt: Date.now(), timeControl: o.timeControl, state: 'failed', error: friendError(e) } })
  }
}

export function decline(inv: MatchInvite) {
  drop(inv.id)
  void supabase?.rpc('answer_friend_match', { p_invite: inv.id, p_accept: false, ...mySetup() })
}

export function reset() { cancelOutgoing(); lastOpponent = null; dismissed.clear(); set({ incoming: [] }) }

if (supabase) {
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') void touch() })
  window.setInterval(() => { if (document.visibilityState === 'visible') void touch() }, 15_000)
}
