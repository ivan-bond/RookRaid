import { useSyncExternalStore } from 'react'
import { arenaOf, STARTER_CARDS, ultMinArena } from './engine'
import { supabase } from './supabase'

export type Account = {
  ready: boolean
  configured: boolean
  userId: string | null
  anonymous: boolean
  apple: boolean
  name: string | null
  trophies: number
  best: number
  unlocked: string[]
  deck: string[]
  ultimate: string
  needsName: boolean
  error: string | null
}

type Snapshot = {
  deck?: string[]
  ultimate?: string
  unlockedCards?: string[]
  name?: string
}

const blank: Account = {
  ready: false,
  configured: supabase != null,
  userId: null,
  anonymous: false,
  apple: false,
  name: null,
  trophies: 0,
  best: 0,
  unlocked: [...STARTER_CARDS],
  deck: [...STARTER_CARDS],
  ultimate: 'meteor',
  needsName: false,
  error: null,
}

let account: Account = { ...blank, unlocked: [...STARTER_CARDS], deck: [...STARTER_CARDS] }
const listeners = new Set<() => void>()

function emit() { listeners.forEach(fn => fn()) }

function guestId(): string {
  const key = 'rookraid.guest'
  const existing = localStorage.getItem(key)
  if (existing) return existing
  const id = crypto.randomUUID()
  localStorage.setItem(key, id)
  return id
}

function knownDeck(cards: unknown, unlocked: string[]): string[] {
  if (!Array.isArray(cards) || cards.length !== 4) return unlocked.slice(0, 4)
  const picked = cards.filter((c): c is string => typeof c === 'string' && unlocked.includes(c))
  return picked.length === 4 && new Set(picked).size === 4 ? picked : unlocked.slice(0, 4)
}

export function ownedUltimates(trophies: number): string[] {
  const arena = arenaOf(trophies)
  return ['meteor', 'fortress', 'iceAge', 'coronation', 'rebirth'].filter(id => arena >= ultMinArena(id))
}

function publish(next: Account) {
  account = next
  emit()
}

async function load(userId: string, anonymous: boolean, apple: boolean) {
  if (!supabase) return
  const [{ data: profile }, { data: progress }] = await Promise.all([
    supabase.from('profiles').select('display_name').eq('id', userId).maybeSingle(),
    supabase.from('progress').select('trophies,best_trophies,snapshot').eq('user_id', userId).maybeSingle(),
  ])
  const snap = (progress?.snapshot ?? null) as Snapshot | null
  const fromServer = (snap?.unlockedCards ?? []).filter((card): card is string => typeof card === 'string' && card.length > 0)
  const unique = [...new Set(fromServer.length ? fromServer : STARTER_CARDS)]
  const trophies = progress?.trophies ?? 0
  const best = Math.max(progress?.best_trophies ?? 0, trophies)
  const ults = ownedUltimates(best)
  const ultimate = snap?.ultimate && ults.includes(snap.ultimate) ? snap.ultimate : ults[0]
  publish({
    ...account,
    ready: true,
    configured: true,
    userId,
    anonymous,
    apple,
    name: profile?.display_name ?? null,
    trophies,
    best,
    unlocked: unique,
    deck: knownDeck(snap?.deck, unique),
    ultimate,
    needsName: !profile,
    error: null,
  })
}

export async function refreshAccount() {
  if (!supabase) {
    publish({ ...blank, ready: true, configured: false, unlocked: [...STARTER_CARDS], deck: [...STARTER_CARDS] })
    return
  }
  const { data } = await supabase.auth.getSession()
  const user = data.session?.user
  if (!user) {
    publish({ ...blank, ready: true, configured: true, unlocked: [...STARTER_CARDS], deck: [...STARTER_CARDS] })
    return
  }
  const apple = user.identities?.some(i => i.provider === 'apple') ?? false
  await load(user.id, user.is_anonymous === true || !apple, apple)
}

export async function ensureSession() {
  if (!supabase) throw new Error('offline')
  const { data } = await supabase.auth.getSession()
  if (!data.session) {
    const { error } = await supabase.auth.signInAnonymously()
    if (error) throw error
  }
  await refreshAccount()
}

export function playerCard() {
  return {
    name: account.name ?? '',
    avatar: 'knight',
    frame: null,
    title: null,
    trophies: account.trophies,
    level: 1,
    pieceSet: null,
  }
}

export function snapshot() {
  return {
    schema: 3,
    guestId: guestId(),
    createdAt: new Date().toISOString(),
    rulesVersion: 3,
    appVersion: 'web',
    name: account.name ?? '',
    trophies: account.trophies,
    bestTrophies: account.best,
    wins: 0, losses: 0, draws: 0, xp: 0, shards: 0, shardsEarned: 0,
    streak: 0, bestStreak: 0, ladderBeaten: 0,
    unlockedCards: account.unlocked,
    ownedBoards: [], ownedAvatars: ['knight'], chestTitles: [],
    claimedAchievements: [], solvedPuzzles: 0, labDone: [], pendingChests: 0,
    deck: account.deck, ultimate: account.ultimate,
  }
}

export async function createAccount(name: string) {
  if (!supabase) throw new Error('offline')
  await ensureSession()
  const { data: free, error: nameError } = await supabase.rpc('name_available', { p_name: name })
  if (nameError) throw nameError
  if (!free) throw new Error('name_taken')
  const card = { ...playerCard(), name }
  const { error } = await supabase.rpc('setup_account', { p_snapshot: { ...snapshot(), name }, p_card: card })
  if (error) throw error
  await refreshAccount()
}

export async function saveDeck(deck: string[], ultimate: string) {
  publish({ ...account, deck, ultimate })
  if (!supabase || !account.userId || account.needsName) return
  await supabase.rpc('backup_progress', { p_snapshot: snapshot() })
}

export function currentAccount() { return account }

export function useAccount() {
  return useSyncExternalStore(
    fn => { listeners.add(fn); return () => listeners.delete(fn) },
    () => account,
  )
}

if (supabase) {
  supabase.auth.onAuthStateChange(() => { void refreshAccount() })
}
void refreshAccount()
