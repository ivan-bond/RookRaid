// Online play and the account, against the same Supabase project as the iPhone app.
// Snapshot format and RPC names follow Services/Online.swift and SupabaseAccountService.swift.
import { useSyncExternalStore } from 'react'
import { AVATARS, BOARD_THEMES, botForTrophies, botRating, botRecordName, CARD_IDS, ULT_IDS, type BoardTheme, type CardId, type ChestRarity, type ChestSource, type UltId } from './game/catalog'
import * as S from './game/store'
import { RULES_VERSION } from './engine'
import { appleClientId, appleIdToken, sessionClient, supabase } from './supabase'
import { setAuthCookie } from './cookies'
import { dropPush } from './push'

/** bot: a bot player from the server (openly marked). Missing for people and for the training opponent. */
export type PlayerCard = { name: string; avatar: string; frame: string | null; title: string | null; trophies: number; level: number; pieceSet: string | null; bot?: boolean }
export type OnlineStart = {
  matchId: string; bot: boolean; botId: string | null; youWhite: boolean; opponent: PlayerCard
  decks: { white: string[]; black: string[] }; ultimates: { white: string; black: string }
  clockWhiteMs: number; clockBlackMs: number; startedAt: number
  /** false = friendly match (no trophies) */
  rated: boolean
}
type ServerProgress = {
  trophies: number; best_trophies: number; snapshot: Record<string, unknown> | null; snapshot_rev?: number
  online_wins?: number; online_losses?: number; online_draws?: number
}

/** secured = signed in with Apple or Google (can sign in again on any device); anonymous = only this browser */
export type AccountStatus = 'unavailable' | 'guest' | 'anonymous' | 'secured'
export type SignInProvider = 'apple' | 'google'
export type AccountState = {
  status: AccountStatus; userId: string | null; name: string | null; serverTrophies: number | null
  busy: boolean; pendingRestore: ServerProgress | null; record: { wins: number; losses: number; draws: number } | null
  /** status 'secured': with whom (Apple or Google) */
  provider: SignInProvider | null
  /** Signed in with Apple/Google, but the account still needs a (unique) player name. */
  needsName: boolean
  /** Message after a failed Apple/Google sign-in (from the redirect). */
  signInError: string | null
  /** The server's own error text, shown small under the message. */
  signInErrorDetail?: string | null
  signInErrorProvider?: SignInProvider
}

let account: AccountState = {
  status: supabase ? 'guest' : 'unavailable', userId: null, name: null, serverTrophies: null, busy: false, pendingRestore: null, record: null,
  needsName: false, signInError: null, provider: null,
}
const listeners = new Set<() => void>()
function publish(patch: Partial<AccountState>) {
  account = { ...account, ...patch }
  if (account.status !== 'unavailable') setAuthCookie(account.status === 'secured' ? 'secured' : account.status === 'anonymous' ? 'anonymous' : 'guest')
  listeners.forEach(fn => fn())
}
export const clearSignInError = () => publish({ signInError: null, signInErrorDetail: null })
export const getAccount = () => account
export function useAccount(): AccountState {
  return useSyncExternalStore(fn => { listeners.add(fn); return () => listeners.delete(fn) }, () => account)
}
export const isConfigured = () => !!supabase
export const hasAccount = () => account.status === 'anonymous' || account.status === 'secured'

function client() {
  if (!supabase) throw new Error('offline')
  return supabase
}

function guestId(): string {
  const key = 'rookraid.guest'
  let id = localStorage.getItem(key)
  if (!id) { id = S.uid(); localStorage.setItem(key, id) }
  return id
}

// MARK: Player card and snapshot

export function playerCard(): PlayerCard {
  const p = S.getProfile()
  return {
    name: account.name ?? p.name, avatar: S.activeAvatar(p), frame: p.selectedFrame, title: S.activeTitle(p), trophies: p.trophies,
    level: S.levelFor(p.xp), pieceSet: S.activeSkin(p)?.id ?? null,
  }
}

function chestOut(c: S.Chest) {
  const guarantee = c.guarantee ? ('card' in c.guarantee ? { card: { _0: c.guarantee.card } } : { tier: { _0: c.guarantee.tier } }) : undefined
  return { id: c.id.toUpperCase(), rarity: c.rarity, source: c.source, guarantee, scriptedUpgrade: !!c.scripted, label: c.label, date: new Date(c.date).toISOString() }
}
function chestIn(raw: Record<string, unknown>): S.Chest | null {
  const rarity = Number(raw.rarity)
  if (!(rarity >= 0 && rarity <= 4)) return null
  const g = raw.guarantee as Record<string, { _0?: string }> | undefined
  let guarantee: S.Chest['guarantee']
  if (g?.card?._0 && (CARD_IDS as string[]).includes(g.card._0)) guarantee = { card: g.card._0 as CardId }
  if (g?.tier?._0) guarantee = { tier: g.tier._0 as 'common' }
  const date = typeof raw.date === 'string' ? Date.parse(raw.date) : typeof raw.date === 'number' ? (raw.date + 978_307_200) * 1000 : Date.now()
  return { id: String(raw.id ?? S.uid()).toLowerCase(), rarity: rarity as ChestRarity, source: (raw.source as ChestSource) ?? 'shop',
    guarantee, scripted: !!raw.scriptedUpgrade, label: (raw.label as string) ?? undefined, date }
}

export function snapshot() {
  const p = S.getProfile()
  return {
    schema: 5, guestId: guestId().toUpperCase(), createdAt: new Date().toISOString(), rulesVersion: RULES_VERSION, appVersion: 'web',
    name: p.name, trophies: p.trophies, bestTrophies: p.bestTrophies, wins: p.wins, losses: p.losses, draws: p.draws, xp: p.xp,
    shards: p.shards, shardsEarned: p.shardsEarned, streak: p.streak, bestStreak: p.bestStreak, ladderBeaten: p.ladderBeaten,
    unlockedCards: p.unlockedCards, ownedBoards: p.ownedBoards, ownedAvatars: p.ownedAvatars, chestTitles: p.chestTitles,
    claimedAchievements: p.claimedAchievements, solvedPuzzles: p.solvedPuzzles.length, labDone: p.labDone, pendingChests: p.chests.length,
    deck: S.activeDeck(p), ultimate: S.activeUltimate(p), solvedPuzzleIds: p.solvedPuzzles, chests: p.chests.map(chestOut),
    levelChestsGranted: p.levelChestsGranted, arenaChestsGranted: p.arenaChestsGranted, puzzleChestsGranted: p.puzzleChestsGranted,
    roadClaimed: p.roadClaimed, ladderWins: p.ladderWins, streakFreezes: p.streakFreezes, selectedAvatar: p.selectedAvatar,
    selectedFrame: p.selectedFrame, selectedTitle: p.selectedTitle, selectedSkin: p.selectedSkin, tutorialSeen: p.tutorialSeen,
    deckTourDone: p.deckTourDone, pityCounter: p.pityCounter, chestsOpened: p.chestsOpened, legendaryChests: p.legendaryChests,
    winChestDay: p.winChestDay, winChestsToday: p.winChestsToday, tutorialChestGiven: p.tutorialChestGiven, firstFriendChestGiven: p.firstFriendChestGiven, seenCards: p.seenCards,
    // Schema 4: the flame, shop, puzzle streaks, achievement counters and board – the whole save goes along (app and browser)
    lastStreakDay: p.lastStreakDay, activeDays: p.activeDays, frozenDays: p.frozenDays, streakMilestones: p.streakMilestones,
    dailyBonusDay: p.dailyBonusDay, dailyChestDay: p.dailyChestDay, puzzleStreak: p.puzzleStreak, bestPuzzleStreak: p.bestPuzzleStreak,
    rushBest: p.rushBest, rushPlayed: p.rushPlayed, shardGoal: p.shardGoal, shopDay: p.shopDay, shopBought: p.shopBought,
    shopFrames: p.shopFrames, cardsByType: p.cardsByType, ultimatesUsed: p.ultimatesUsed, bonusActions: p.bonusActions,
    tacticBonuses: p.tacticBonuses, mateWins: p.mateWins, winStreak: p.winStreak, bestWinStreak: p.bestWinStreak,
    cardsBought: p.cardsBought, boardTheme: p.settings.boardTheme,
    // Schema 5: every game played, on any device
    history: p.history.map(historyOut),
  }
}

/** Same JSON as GameRecord in the app (UUIDs in capitals, dates as ISO text). */
function historyOut(h: S.GameRecord) {
  return {
    id: h.id.toUpperCase(), date: new Date(h.date).toISOString(), opponent: h.opponent, result: h.result, reason: h.reason,
    moves: h.moves, trophyDelta: h.trophyDelta, cardsPlayed: h.cardsPlayed,
    ...(h.replayID ? { replayID: h.replayID.toUpperCase() } : {}), ...(h.matchId ? { matchId: h.matchId.toUpperCase() } : {}),
  }
}
function historyIn(raw: unknown): S.GameRecord | null {
  if (!raw || typeof raw !== 'object') return null
  const r = raw as Record<string, unknown>
  const result = r.result
  if (typeof r.id !== 'string' || (result !== 'win' && result !== 'loss' && result !== 'draw')) return null
  const date = typeof r.date === 'string' ? Date.parse(r.date) : typeof r.date === 'number' ? (r.date + 978_307_200) * 1000 : NaN
  if (!Number.isFinite(date)) return null
  const n = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0)
  return {
    id: r.id.toLowerCase(), date, opponent: typeof r.opponent === 'string' ? r.opponent : '', result, reason: typeof r.reason === 'string' ? r.reason : '',
    moves: n(r.moves), trophyDelta: n(r.trophyDelta), cardsPlayed: n(r.cardsPlayed),
    replayID: typeof r.replayID === 'string' ? r.replayID.toLowerCase() : undefined,
    matchId: typeof r.matchId === 'string' ? r.matchId.toLowerCase() : undefined,
  }
}
/** Both lists together, newest first, each game once (by id or by server match). */
export function mergeHistory(a: S.GameRecord[], b: S.GameRecord[]): S.GameRecord[] {
  const out: S.GameRecord[] = []
  const ids = new Set<string>(), matches = new Set<string>()
  for (const h of [...a, ...b].sort((x, y) => y.date - x.date)) {
    if (ids.has(h.id) || (h.matchId && matches.has(h.matchId))) continue
    ids.add(h.id)
    if (h.matchId) matches.add(h.matchId)
    out.push(h)
  }
  return out.slice(0, S.HISTORY_LIMIT)
}

/** Take over the progress saved on the account. The server is the truth: trophies, name and the whole save come from it.
 *  Only the game history is merged (games from this browser that the server does not know yet stay). */
export function restoreFrom(progress: ServerProgress) {
  const s = (progress.snapshot ?? {}) as Record<string, unknown>
  const arr = (k: string) => (Array.isArray(s[k]) ? (s[k] as unknown[]).filter((x): x is string => typeof x === 'string') : null)
  const num = (k: string) => (typeof s[k] === 'number' ? s[k] as number : null)
  S.update(p => {
    // The account name is the one on the server (profiles.display_name); the save only fills in without an account name.
    if (account.name) p.name = account.name
    else if (typeof s.name === 'string' && s.name) p.name = s.name
    p.trophies = progress.trophies
    p.bestTrophies = Math.max(progress.best_trophies, num('bestTrophies') ?? 0, progress.trophies)
    for (const k of ['wins', 'losses', 'draws', 'xp', 'shards', 'shardsEarned', 'streak', 'bestStreak', 'ladderBeaten',
      'levelChestsGranted', 'arenaChestsGranted', 'puzzleChestsGranted', 'streakFreezes', 'pityCounter', 'chestsOpened',
      'legendaryChests', 'winChestsToday', 'puzzleStreak', 'bestPuzzleStreak', 'rushBest', 'rushPlayed', 'ultimatesUsed', 'bonusActions',
      'tacticBonuses', 'mateWins', 'winStreak', 'bestWinStreak', 'cardsBought'] as const) {
      const v = num(k)
      if (v !== null) (p as Record<string, unknown>)[k] = v
    }
    p.unlockedCards = (arr('unlockedCards') ?? []).filter(c => (CARD_IDS as string[]).includes(c))
    p.ownedBoards = arr('ownedBoards') ?? p.ownedBoards
    p.ownedAvatars = arr('ownedAvatars') ?? p.ownedAvatars
    p.chestTitles = arr('chestTitles') ?? p.chestTitles
    p.claimedAchievements = arr('claimedAchievements') ?? p.claimedAchievements
    p.labDone = arr('labDone') ?? p.labDone
    p.seenCards = arr('seenCards') ?? p.unlockedCards
    p.solvedPuzzles = arr('solvedPuzzleIds') ?? p.solvedPuzzles
    if (Array.isArray(s.chests)) p.chests = (s.chests as Array<Record<string, unknown>>).map(chestIn).filter((c): c is S.Chest => !!c)
    if (Array.isArray(s.roadClaimed)) p.roadClaimed = (s.roadClaimed as unknown[]).filter((x): x is number => typeof x === 'number')
    if (s.ladderWins && typeof s.ladderWins === 'object') p.ladderWins = s.ladderWins as Record<string, number>
    p.selectedAvatar = (s.selectedAvatar as string) ?? null
    p.selectedFrame = (s.selectedFrame as string) ?? null
    p.selectedTitle = (s.selectedTitle as string) ?? null
    p.selectedSkin = (s.selectedSkin as string) ?? null
    if (s.tutorialSeen === true) p.tutorialSeen = true
    if (s.deckTourDone === true) p.deckTourDone = true
    if (typeof s.winChestDay === 'string') p.winChestDay = s.winChestDay
    if (typeof s.tutorialChestGiven === 'boolean') p.tutorialChestGiven = s.tutorialChestGiven
    if (s.firstFriendChestGiven === true) p.firstFriendChestGiven = true
    // Schema 4 (older saves leave these out: then this browser's values stay)
    for (const k of ['lastStreakDay', 'dailyBonusDay', 'dailyChestDay', 'shopDay'] as const) if (typeof s[k] === 'string') p[k] = s[k] as string
    for (const k of ['activeDays', 'frozenDays', 'shopBought', 'shopFrames'] as const) { const v = arr(k); if (v) p[k] = v }
    if (Array.isArray(s.streakMilestones)) p.streakMilestones = (s.streakMilestones as unknown[]).filter((x): x is number => typeof x === 'number')
    if (Number(s.schema) >= 4) p.shardGoal = typeof s.shardGoal === 'string' ? s.shardGoal : null
    if (s.cardsByType && typeof s.cardsByType === 'object') p.cardsByType = s.cardsByType as Record<string, number>
    if (typeof s.boardTheme === 'string' && (BOARD_THEMES as string[]).includes(s.boardTheme)) p.settings.boardTheme = s.boardTheme as BoardTheme
    const deck = (arr('deck') ?? []).filter(c => (CARD_IDS as string[]).includes(c)) as CardId[]
    p.settings.deck = deck.slice(0, 4)
    if (typeof s.ultimate === 'string' && (ULT_IDS as string[]).includes(s.ultimate)) p.settings.ultimate = s.ultimate as UltId
    // Schema 5: the games from every device
    if (Array.isArray(s.history)) {
      const remote = (s.history as unknown[]).map(historyIn).filter((h): h is S.GameRecord => !!h)
      p.history = mergeHistory(remote, p.history)
    }
  })
  S.checkStreak()
  S.flushSave()
  if (typeof progress.snapshot_rev === 'number') setSyncRev(progress.snapshot_rev)
  // What we just loaded is the server's state: no need to send it back (unless the merged history added games).
  lastBackup = backupKey()
  if (Array.isArray(s.history) && (s.history as unknown[]).length !== S.getProfile().history.length) lastBackup = ''
  publish({ pendingRestore: null })
}
export const dismissRestore = () => publish({ pendingRestore: null })

// MARK: Account

export async function refreshAccount() {
  if (!supabase) { publish({ status: 'unavailable' }); return }
  const { data } = await supabase.auth.getSession()
  const user = data.session?.user
  if (!user) { publish({ status: 'guest', provider: null, userId: null, name: null, serverTrophies: null, record: null }); return }
  const provider = securedBy(user.identities)
  const [{ data: profile }, { data: progress }] = await Promise.all([
    supabase.from('profiles').select('display_name').eq('id', user.id).maybeSingle(),
    supabase.from('progress').select('*').eq('user_id', user.id).maybeSingle(),
  ])
  if (!profile) {
    // Signed in (Apple redirect or an unfinished anonymous probe) but no account yet.
    if (provider) await finishSignInSetup()
    else publish({ status: 'guest', provider: null, userId: user.id, name: null, serverTrophies: null })
    return
  }
  const row = profile as { display_name: string }
  const pr = progress as (ServerProgress & { online_wins?: number; online_losses?: number; online_draws?: number }) | null
  publish({
    status: provider ? 'secured' : 'anonymous', provider, userId: user.id, name: row.display_name, serverTrophies: pr?.trophies ?? null, needsName: false,
    record: { wins: pr?.online_wins ?? 0, losses: pr?.online_losses ?? 0, draws: pr?.online_draws ?? 0 },
  })
  if (row.display_name && S.getProfile().name !== row.display_name) S.update(p => { p.name = row.display_name })
  if (pr) await adoptServer(pr, user.id)
  void mergeServerGames()
}

/** Bring this browser to the server's state: a newer save from another device replaces this one;
 *  if this browser has changes the server does not have yet, they are sent (and checked against the server's version). */
async function adoptServer(pr: ServerProgress, userId: string) {
  const sync = syncState()
  const known = sync?.userId === userId ? sync.rev : null
  const rev = pr.snapshot_rev ?? null
  if (pr.snapshot && (known === null || rev === null || rev !== known)) restoreFrom(pr)
  else if (!pr.snapshot) { setSyncRev(rev ?? 0); lastBackup = ''; await backupQuietly() }
  else if (backupTimer) { window.clearTimeout(backupTimer); backupTimer = 0; await backupQuietly() }
  // Trophies are always the server's.
  if (typeof pr.trophies === 'number') {
    S.update(p => { p.trophies = pr.trophies; p.bestTrophies = Math.max(p.bestTrophies, pr.best_trophies, pr.trophies) })
  }
}

/** Server games (every device, also games the app never saw end – e.g. lost after 45 s offline) go into the history. */
export const SERVER_REASON: Record<string, string> = {
  mate: 'durch Schachmatt', stalemate: 'durch Patt', fifty: 'durch die 50-Züge-Regel', repetition: 'durch dreifache Stellungswiederholung',
  timeout: 'durch Zeitüberschreitung', resigned: 'durch Aufgabe', draw_agreed: 'durch Einigung', abandoned: 'durch Verbindungsabbruch',
}
type MatchListRow = {
  id: string; result: string | null; winner_color: 'white' | 'black' | null; white: string | null; white_card: PlayerCard; black_card: PlayerCard
  trophy_delta_white: number | null; trophy_delta_black: number | null; action_count: number; ended_at: string | null; created_at: string
}
export async function mergeServerGames() {
  if (!supabase || !hasAccount() || !account.userId) return
  const me = account.userId
  const { data, error } = await supabase.from('matches')
    .select('id,result,winner_color,white,white_card,black_card,trophy_delta_white,trophy_delta_black,action_count,ended_at,created_at')
    .eq('status', 'finished').or(`white.eq.${me},black.eq.${me}`).order('ended_at', { ascending: false }).limit(S.HISTORY_LIMIT)
  if (error || !data) return
  const history = S.getProfile().history
  const known = new Set(history.map(h => h.matchId).filter(Boolean))
  const attach = new Map<string, { matchId: string; delta: number }>()
  const extra: S.GameRecord[] = []
  for (const m of data as MatchListRow[]) {
    const id = m.id.toLowerCase()
    if (known.has(id)) continue
    const white = m.white === me
    const result: S.Result = !m.winner_color ? 'draw' : (m.winner_color === 'white') === white ? 'win' : 'loss'
    const opp = (white ? m.black_card : m.white_card)?.name ?? ''
    const delta = (white ? m.trophy_delta_white : m.trophy_delta_black) ?? 0
    const date = Date.parse(m.ended_at ?? m.created_at)
    // Older entries of this browser have no match id yet: the same opponent and result within 15 minutes is the same game.
    const same = history.find(h => !h.matchId && !attach.has(h.id) && h.result === result && h.opponent === opp && Math.abs(h.date - date) < 15 * 60_000)
    if (same) { attach.set(same.id, { matchId: id, delta }); continue }
    extra.push({ id, date, opponent: opp, result, reason: SERVER_REASON[m.result ?? ''] ?? '', moves: m.action_count ?? 0, trophyDelta: delta, cardsPlayed: 0, matchId: id })
  }
  if (!extra.length && !attach.size) return
  S.update(p => {
    p.history = mergeHistory(p.history.map(h => {
      const a = attach.get(h.id)
      return a ? { ...h, matchId: a.matchId, trophyDelta: h.trophyDelta || a.delta } : h
    }), extra)
  })
}

async function ensureAnon() {
  const db = client()
  const { data } = await db.auth.getSession()
  if (!data.session) {
    const { error } = await db.auth.signInAnonymously()
    if (error) throw error
  }
}

export async function nameAvailable(name: string): Promise<boolean> {
  await ensureAnon()
  const { data, error } = await client().rpc('name_available', { p_name: name })
  if (error) throw error
  return !!data
}

/** First online account: anonymous sign-in plus `setup_account` with the chosen unique name. */
export async function createAccount(name: string) {
  publish({ busy: true })
  try {
    await ensureAnon()
    if (!(await nameAvailable(name))) throw new Error('name_taken')
    S.update(p => { p.name = name })
    const { data, error } = await client().rpc('setup_account', { p_snapshot: snapshot(), p_card: { ...playerCard(), name } })
    if (error) throw error
    const reply = data as { status: string; progress: ServerProgress; name?: string } | null
    lastBackup = ''
    setSyncRev(null)
    // An existing account always brings its progress along (no question): the server is the truth.
    await refreshAccount()
  } finally { publish({ busy: false }) }
}

export async function renameAccount(name: string) {
  if (!(await nameAvailable(name))) throw new Error('name_taken')
  const { error } = await client().rpc('set_display_name', { p_name: name })
  if (error) throw error
  S.update(p => { p.name = name })
  await refreshAccount()
}

const INTENT = 'rookraid.appleIntent'
/** The anonymous web account from before the Apple sign-in (its tokens). It is removed if Apple brings a brand-new account. */
const GUEST_SESSION = 'rookraid.guestSession'
const redirectTo = () => `${location.origin}/`

/**
 * Sign in with Apple – one step for everybody (same Apple ID as on the iPhone):
 * - the Apple ID already has an account → it is loaded right away (progress from the server replaces this browser's);
 * - otherwise a new account is created from this browser's progress (cards, chests, name …; trophies start at 0 and only come from server-scored games).
 * Without a Services ID for the JS popup, Supabase's redirect is used.
 */
export async function signInWithApple() {
  const db = client()
  await rememberGuestSession()
  if (appleClientId) {
    publish({ busy: true })
    try {
      const { token, nonce } = await appleIdToken()
      const { error } = await db.auth.signInWithIdToken({ provider: 'apple', token, nonce })
      if (error) throw error
      await finishSignInSetup()
    } finally { publish({ busy: false }) }
    return
  }
  const { data, error } = await db.auth.signInWithOAuth({ provider: 'apple', options: { redirectTo: redirectTo(), scopes: 'name email', skipBrowserRedirect: true } })
  if (error) throw error
  await goToProvider(data.url, 'apple')
}
/** "Secure with Apple" for an anonymous account is the same single step (no separate linking any more). */
export const linkApple = signInWithApple

/**
 * Sign in with Google – the same single step as Apple (Supabase's redirect to Google and back):
 * an existing account is loaded, otherwise a new one is created from this browser's progress.
 */
export async function signInWithGoogle() {
  const db = client()
  await rememberGuestSession()
  const { data, error } = await db.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: redirectTo(), skipBrowserRedirect: true } })
  if (error) throw error
  await goToProvider(data.url, 'google')
}

/** Apple or Google among the sign-ins of this user (null = only anonymous). */
function securedBy(identities: Array<{ provider: string }> | undefined | null): SignInProvider | null {
  if (identities?.some(i => i.provider === 'apple')) return 'apple'
  if (identities?.some(i => i.provider === 'google')) return 'google'
  return null
}

async function rememberGuestSession() {
  sessionStorage.removeItem(GUEST_SESSION)
  if (account.status !== 'anonymous') return
  const { data } = await client().auth.getSession()
  const sess = data.session
  if (sess?.user.is_anonymous) sessionStorage.setItem(GUEST_SESSION, JSON.stringify({ access_token: sess.access_token, refresh_token: sess.refresh_token }))
}

/** The old anonymous web account: delete it, so its name is free for the new Apple account (its progress goes along locally). */
async function discardGuestAccount() {
  const raw = sessionStorage.getItem(GUEST_SESSION)
  sessionStorage.removeItem(GUEST_SESSION)
  if (!raw) return
  try {
    const tokens = JSON.parse(raw) as { access_token: string; refresh_token: string }
    const guest = sessionClient()
    if (!guest) return
    const { data, error } = await guest.auth.setSession(tokens)
    if (error || !data.session?.user.is_anonymous) return
    await guest.functions.invoke('delete-account')
  } catch { /* the cleanup job removes it later */ }
}

/** Check the sign-in address first: a project without the provider set up answers with an error instead of a redirect. */
async function goToProvider(url: string | null | undefined, provider: SignInProvider) {
  const missing = `${provider}_not_configured`
  if (!url) throw new Error(missing)
  try {
    const res = await fetch(url, { redirect: 'manual' })
    if (res.type !== 'opaqueredirect' && res.status >= 400) throw new Error(missing)
  } catch (e) {
    if (e instanceof Error && e.message === missing) throw e
    // Network or CORS trouble with the check itself: try the redirect anyway.
  }
  sessionStorage.setItem(INTENT, provider)
  S.flushSave()
  location.assign(url)
}

/** After Apple/Google: load the existing account, or create one from this browser's progress. Runs once at a time
 *  (the sign-in event and the return from Apple's page both arrive here). */
let setupRun: Promise<void> | null = null
function finishSignInSetup(): Promise<void> {
  setupRun ??= runSignInSetup().finally(() => { setupRun = null })
  return setupRun
}
async function runSignInSetup() {
  lastBackup = ''
  const db = client()
  const { data: u } = await db.auth.getUser()
  const uid = u.user?.id ?? null
  if (uid) {
    const { data: known } = await db.from('profiles').select('id').eq('id', uid).maybeSingle()
    if (!known) await discardGuestAccount()
    else sessionStorage.removeItem(GUEST_SESSION)
  }
  const { data, error } = await db.rpc('setup_account', { p_snapshot: snapshot(), p_card: playerCard() })
  if (error) {
    const text = error.message ?? ''
    if (text.includes('name_invalid') || text.includes('name_taken')) {
      publish({ status: 'secured', provider: securedBy(u.user?.identities), userId: uid, needsName: true })
      return
    }
    throw error
  }
  const reply = data as { status: string; progress: ServerProgress; name?: string } | null
  if (reply?.status === 'existing' && reply.name) {
    publish({ name: reply.name })
    S.update(p => { p.name = reply.name! })
  }
  // Existing account: its progress replaces this browser's right away (no question) – like signing in on a new iPhone.
  // New account: this browser's progress is its first save.
  setSyncRev(null)
  publish({ needsName: false })
  await refreshAccount()
}

const FAILED: Record<SignInProvider, string> = { apple: 'Anmeldung mit Apple fehlgeschlagen.', google: 'Anmeldung mit Google fehlgeschlagen.' }

/** Called once on start: handles the return from Apple's or Google's sign-in page. */
export async function handleSignInReturn() {
  const params = new URLSearchParams(location.search + location.hash.replace(/^#/, '&'))
  const intent = sessionStorage.getItem(INTENT)
  sessionStorage.removeItem(INTENT)
  const provider: SignInProvider = intent === 'google' ? 'google' : 'apple'
  const err = params.get('error_description') ?? params.get('error')
  if (err && intent) {
    console.warn('Sign-in failed:', err)
    sessionStorage.removeItem(GUEST_SESSION)
    publish({ signInError: FAILED[provider], signInErrorDetail: err, signInErrorProvider: provider })
  }
  if (params.has('code') || params.has('access_token') || err) history.replaceState(null, '', location.pathname)
  if (intent && !err) {
    const { data } = await client().auth.getSession()
    if (securedBy(data.session?.user.identities)) {
      publish({ busy: true })
      try { await finishSignInSetup() } catch (e) {
        publish({ signInError: FAILED[provider], signInErrorDetail: e instanceof Error ? e.message : String(e), signInErrorProvider: provider })
        await refreshAccount()
      } finally { publish({ busy: false }) }
    } else await refreshAccount()
  }
}

export async function signOut() {
  // Everything still waiting goes to the account first – nothing is lost by signing out.
  if (backupTimer) { window.clearTimeout(backupTimer); backupTimer = 0 }
  try { await backupQuietly() } catch { /* offline: the next sign-in loads the server's state */ }
  await dropPush()
  await supabase?.auth.signOut()
  setSyncRev(null)
  lastBackup = ''
  publish({ status: supabase ? 'guest' : 'unavailable', userId: null, name: null, serverTrophies: null, record: null })
}

export async function deleteAccount() {
  publish({ busy: true })
  try {
    const db = client()
    const { error } = await db.functions.invoke('delete-account')
    if (error) throw error
    await dropPush()
    await db.auth.signOut()
    lastBackup = ''
    setSyncRev(null)
    publish({ status: 'guest', userId: null, name: null, serverTrophies: null, record: null })
  } finally { publish({ busy: false }) }
}

let backupTimer = 0
/** The last snapshot sent (without its time stamp): the same save is not sent twice. */
let lastBackup = ''
const backupKey = () => JSON.stringify({ ...snapshot(), createdAt: '' })

/** Which server save this browser's progress is based on (per account). */
const SYNC_KEY = 'rookraid.sync'
function syncState(): { userId: string; rev: number } | null {
  try {
    const v = JSON.parse(localStorage.getItem(SYNC_KEY) ?? 'null') as { userId?: unknown; rev?: unknown } | null
    return v && typeof v.userId === 'string' && typeof v.rev === 'number' ? { userId: v.userId, rev: v.rev } : null
  } catch { return null }
}
function setSyncRev(rev: number | null) {
  try {
    if (rev === null || !account.userId) localStorage.removeItem(SYNC_KEY)
    else localStorage.setItem(SYNC_KEY, JSON.stringify({ userId: account.userId, rev }))
  } catch { /* storage blocked */ }
}

let syncing: Promise<void> | null = null
/** Send the progress to the account. The server only takes it if it still has the version this browser started from;
 *  if another device saved in between, its state is loaded instead (and this browser's new games are kept). */
export function backupQuietly(): Promise<void> {
  if (!supabase || !hasAccount()) return Promise.resolve()
  const run = (syncing ?? Promise.resolve()).then(syncOnce).finally(() => { if (syncing === run) syncing = null })
  syncing = run
  return run
}
async function syncOnce() {
  if (!supabase || !hasAccount()) return
  const snap = snapshot()
  const key = JSON.stringify({ ...snap, createdAt: '' })
  if (key === lastBackup) return
  const sync = syncState()
  const base = sync && sync.userId === account.userId ? sync.rev : null
  lastBackup = key
  const { data, error } = await supabase.rpc('sync_progress', { p_snapshot: snap, p_base_rev: base })
  if (error) {
    // Server without the newer function (migration not run yet): the old way.
    if (error.code === 'PGRST202' || /sync_progress/.test(error.message ?? '')) {
      const old = await supabase.rpc('backup_progress', { p_snapshot: snap })
      if (old.error) lastBackup = ''
      return
    }
    lastBackup = ''
    return
  }
  const reply = data as { status: string; rev?: number; progress?: ServerProgress } | null
  if (reply?.status === 'saved' && typeof reply.rev === 'number') setSyncRev(reply.rev)
  else if (reply?.status === 'stale' && reply.progress) {
    restoreFrom(reply.progress)
    S.update(p => { p.trophies = reply.progress!.trophies })
  }
}
/** Everything in the save goes to the account (cards, XP, chests, shards, flame, shop, achievements, games …), bundled. */
S.onProfileChange(() => {
  if (!hasAccount()) return
  window.clearTimeout(backupTimer)
  backupTimer = window.setTimeout(() => { backupTimer = 0; void backupQuietly() }, 1500)
})
// Closing the tab: send what is still waiting.
window.addEventListener('pagehide', () => { if (backupTimer) { window.clearTimeout(backupTimer); backupTimer = 0; void backupQuietly() } })
// Back to the tab: another device may have played in the meantime.
let lastPull = 0
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState !== 'visible' || !hasAccount() || Date.now() - lastPull < 5000) return
  lastPull = Date.now()
  void refreshAccount()
})

/** After three anonymous online games, offer once to secure the account with Apple. */
export function noteFinishedOnlineGame() {
  if (account.status !== 'anonymous' || localStorage.getItem('rookraid.applePrompt')) return
  const n = Number(localStorage.getItem('rookraid.anonGames') ?? 0) + 1
  localStorage.setItem('rookraid.anonGames', String(n))
}
export function consumeApplePrompt(): boolean {
  if (account.status !== 'anonymous' || localStorage.getItem('rookraid.applePrompt')) return false
  if (Number(localStorage.getItem('rookraid.anonGames') ?? 0) < 3) return false
  localStorage.setItem('rookraid.applePrompt', '1')
  return true
}

// MARK: Matchmaking

let searching = false
/** One search at a time: a second call (React runs effects twice in development, double clicks) gets the same
 *  search instead of starting a second game on the server – that one would never be played and count as a loss. */
let inflight: Promise<OnlineStart> | null = null
export function findOnlineMatch(onPhase?: (seconds: number) => void): Promise<OnlineStart> {
  inflight ??= searchMatch(onPhase).finally(() => { inflight = null })
  return inflight
}
async function searchMatch(onPhase?: (seconds: number) => void): Promise<OnlineStart> {
  const db = client()
  const card = playerCard()
  const params = { p_rules_version: RULES_VERSION, p_time_control: 'blitz5', p_deck: S.activeDeck(), p_ultimate: S.activeUltimate(), p_card: card }
  const started = Date.now()
  searching = true
  try {
    while (Date.now() - started < 10_000) {
      if (!searching) throw new Error('cancelled')
      const { data, error } = await db.rpc('find_match', params)
      if (error) throw error
      if (data) return loadMatch(String(data))
      onPhase?.(Math.floor((Date.now() - started) / 1000))
      await new Promise(r => setTimeout(r, 2000))
    }
    if (!searching) throw new Error('cancelled')
    const level = botForTrophies(card.trophies)
    const { data, error } = await db.rpc('start_bot_match', {
      ...params, p_bot_card: botCard(card.trophies), p_bot_deck: [...level.deck], p_bot_ultimate: level.ult,
      p_human_white: Math.random() < 0.5,
    })
    if (error) throw error
    const row = Array.isArray(data) ? data[0] : data
    if (!row?.match_id) throw new Error('server')
    const start = await loadMatch(row.match_id)
    return { ...start, botId: start.botId ?? level.id }
  } finally { searching = false }
}

/** The stand-in bot is openly a training opponent (BotCards in the app): its own name, the robot, its rating. */
export function botCard(trophies: number): PlayerCard {
  const bot = botForTrophies(trophies)
  return { name: botRecordName(bot), avatar: 'robot', frame: null, title: 'Trainingsgegner', trophies: botRating(bot), level: bot.tier, pieceSet: null }
}

export async function cancelSearch() {
  searching = false
  try { await supabase?.rpc('cancel_matchmaking') } catch { /* ignore */ }
}

type MatchRow = {
  white: string | null; black: string | null; white_card: PlayerCard; black_card: PlayerCard; is_bot: boolean
  bot_level: string | null; rated: boolean | null
  setup: { decks: { white: string[]; black: string[] }; ultimates: { white: string; black: string } }
  clock_white_ms: number; clock_black_ms: number; clock_started_at: string
}
export async function loadMatch(id: string): Promise<OnlineStart> {
  const db = client()
  const { data, error } = await db.from('matches')
    .select('white,black,white_card,black_card,is_bot,bot_level,rated,setup,clock_white_ms,clock_black_ms,clock_started_at').eq('id', id).single()
  if (error) throw error
  const row = data as MatchRow
  const uid = (await db.auth.getUser()).data.user?.id
  const youWhite = row.white === uid
  return {
    matchId: id, bot: row.is_bot, botId: row.is_bot ? row.bot_level : null, youWhite, opponent: youWhite ? row.black_card : row.white_card,
    decks: row.setup.decks, ultimates: row.setup.ultimates, clockWhiteMs: row.clock_white_ms, clockBlackMs: row.clock_black_ms,
    startedAt: Date.parse(row.clock_started_at), rated: row.rated ?? true,
  }
}

/** A running game against a person (after a reload): open it again. */
export async function activeHumanMatch(): Promise<string | null> {
  if (!supabase || !hasAccount()) return null
  const uid = account.userId
  const { data } = await supabase.from('matches').select('id').eq('status', 'active').eq('is_bot', false)
    .or(`white.eq.${uid},black.eq.${uid}`).limit(1)
  return (data?.[0]?.id as string) ?? null
}

/** Why the server refused an action (submit-action answers 409/422 with `{ error }`), or null for a network problem. */
export type SubmitRefusal = 'out_of_sync' | 'illegal_action' | 'not_your_turn' | 'timeout' | 'not_active'
export class SubmitError extends Error {
  constructor(readonly refusal: SubmitRefusal | null) { super(refusal ?? 'network') }
}
export async function submitAction(matchId: string, ply: number, code: string) {
  const { error } = await client().functions.invoke('submit-action', { body: { match_id: matchId, ply, code } })
  if (!error) return
  let refusal: SubmitRefusal | null = null
  try {
    const ctx = (error as { context?: Response }).context
    const body = ctx && typeof ctx.json === 'function' ? await ctx.clone().json() : null
    const e = body?.error
    if (e === 'out_of_sync' || e === 'illegal_action' || e === 'not_your_turn' || e === 'timeout' || e === 'not_active') refusal = e
  } catch { /* no readable body: network */ }
  throw new SubmitError(refusal)
}
export async function fetchActions(matchId: string): Promise<string[]> {
  const { data, error } = await client().from('match_actions').select('code').eq('match_id', matchId).order('ply')
  if (error) throw error
  return (data ?? []).map(r => r.code as string)
}
/** Sign of life (OnlineHeartbeat in the app). Answers the match status and how long the opponent has been silent;
 *  null when the server could not be reached. */
export async function heartbeat(matchId: string): Promise<{ status: string; opponentSilent: number | null } | null> {
  if (!supabase) return null
  try {
    const { data, error } = await supabase.rpc('match_heartbeat', { p_match: matchId })
    if (error || !data) return null
    const row = (typeof data === 'string' ? JSON.parse(data) : data) as { status?: string; opponent_silent_s?: number | null }
    return { status: String(row.status ?? 'active'), opponentSilent: typeof row.opponent_silent_s === 'number' ? row.opponent_silent_s : null }
  } catch { return null }
}

// MARK: Rules version (OnlineRules.swift)

export type RulesLock = 'open' | 'updateAvailable' | 'serverBehind'
/** Compare the server's active rules with the ones this build plays. The browser cannot adopt new rules on the fly,
 *  so a newer server version only stays open while this version is still active (transition, like the app). */
export async function rulesLock(): Promise<RulesLock> {
  if (!supabase) return 'open'
  try {
    const { data, error } = await supabase.rpc('active_rules')
    if (error) return 'open'
    const rows = (Array.isArray(data) ? data : data ? [data] : []) as Array<{ version?: number | string }>
    const versions = rows.map(r => Number(r.version)).filter(Number.isFinite)
    if (!versions.length) return 'serverBehind'
    const server = Math.max(...versions)
    if (server === RULES_VERSION) return 'open'
    if (server < RULES_VERSION) return 'serverBehind'
    const { data: still } = await supabase.from('rules_config').select('version').eq('version', RULES_VERSION).eq('active', true).limit(1)
    return still && still.length ? 'open' : 'updateAvailable'
  } catch { return 'open' }
}
export const RULES_LOCK_TEXT: Record<Exclude<RulesLock, 'open'>, { title: string; detail: string }> = {
  updateAvailable: { title: 'Update verfügbar', detail: 'Bitte aktualisiere Rook Raid, um online zu spielen.' },
  serverBehind: { title: 'Online gerade nicht verfügbar', detail: 'Diese Fassung ist neuer als der Server. Online geht wieder, sobald der Server nachgezogen hat.' },
}
export async function resignMatch(matchId: string) {
  const { error } = await client().rpc('resign_match', { p_match: matchId })
  if (error) throw error
}
export async function offerDraw(matchId: string) {
  const { error } = await client().rpc('offer_draw', { p_match: matchId })
  if (error) throw error
}
export async function answerDraw(matchId: string, accept: boolean) {
  const { error } = await client().rpc('answer_draw', { p_match: matchId, p_accept: accept })
  if (error) throw error
}
export async function claimTimeout(matchId: string) {
  const { error } = await client().rpc('claim_timeout', { p_match: matchId })
  if (error) throw error
}
/** An Edge Function answered with 4xx: the request itself is refused, trying again changes nothing. */
export function isServerRejection(e: unknown): boolean {
  const status = (e as { context?: { status?: number } } | null)?.context?.status
  return typeof status === 'number' && status >= 400 && status < 500
}
export async function finishBot(matchId: string, actions: string[], outcome: 'final' | 'resigned' | 'timeout') {
  const { data, error } = await client().functions.invoke('finish-bot-match', { body: { match_id: matchId, actions, outcome } })
  if (error) throw error
  noteFinishedOnlineGame()
  return data as { trophy_delta_white?: number; trophy_delta_black?: number } | null
}
/** Live updates of one match, like SupabaseMatchSession.connect in the app: `onChange` runs when an action arrives or
 *  the match row changes (clocks, draw offer, end), and once the channel is connected (to catch up on anything missed).
 *  Returns the function that closes the channel. */
export function watchMatch(matchId: string, onChange: () => void): () => void {
  if (!supabase) return () => {}
  const db = supabase
  const ch = db.channel(`match-${matchId}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'match_actions', filter: `match_id=eq.${matchId}` }, () => onChange())
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'matches', filter: `id=eq.${matchId}` }, () => onChange())
    .subscribe(status => { if (status === 'SUBSCRIBED') onChange() })
  return () => { void db.removeChannel(ch) }
}
export async function matchStatus(matchId: string) {
  const { data, error } = await client().from('matches')
    .select('status,result,winner_color,draw_offer_by,trophy_delta_white,trophy_delta_black,clock_white_ms,clock_black_ms').eq('id', matchId).single()
  if (error) throw error
  return data as {
    status: string; result: string | null; winner_color: string | null; draw_offer_by: string | null
    trophy_delta_white: number | null; trophy_delta_black: number | null; clock_white_ms: number | null; clock_black_ms: number | null
  }
}

export function serverMessage(error: unknown): string {
  const text = error instanceof Error ? error.message : typeof error === 'object' && error && 'message' in error ? String((error as { message: unknown }).message) : String(error)
  if (text.includes('name_taken')) return 'Dieser Name ist schon vergeben.'
  if (text.includes('rules_outdated')) return 'Bitte aktualisiere Rook Raid, um online zu spielen.'
  if (text.includes('deck_incomplete') || text.includes('unknown_card') || text.includes('unknown_ultimate')) return 'Dein Deck braucht 4 verschiedene Karten.'
  if (text.includes('bad_time_control')) return 'Online gilt nur 5 | 0.'
  if (text.includes('no_account')) return 'Zuerst brauchst du ein Online-Konto.'
  if (text.includes('apple_not_configured')) return 'Anmeldung mit Apple ist in dieser Browser-Fassung noch nicht eingerichtet.'
  if (text.includes('google_not_configured')) return 'Anmeldung mit Google ist in dieser Browser-Fassung noch nicht eingerichtet.'
  if (text.includes('popup_closed') || text.includes('cancelled')) return 'Abgebrochen.'
  if (text === 'offline') return 'Kein Server konfiguriert. Üben geht weiter.'
  return 'Keine Verbindung zum Server.'
}

if (supabase) {
  supabase.auth.onAuthStateChange(event => { if (event === 'SIGNED_IN' || event === 'SIGNED_OUT' || event === 'USER_UPDATED') void refreshAccount() })
  void handleSignInReturn().then(() => refreshAccount())
}
