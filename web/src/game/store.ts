// Port of ProfileStore (Persistence.swift and its extensions). Everything stays in this browser,
// like the iPhone app keeps it on the phone. Online backup goes through `online.ts`.
import { useSyncExternalStore } from 'react'
import {
  ARENAS, AVATARS, BOARD_PRICE, BOARD_THEMES, BOTS, CARD_IDS, CARDS, CHEST, CHEST_PRICES, CHEST_TITLES, COSMETIC_CHANCE,
  COSMETIC_RARITY, DECK_SIZE, FREEZE_PRICE, JACKPOT_SHARDS, MAX_FREEZES, PITY_LIMIT, PUZZLES_PER_CHEST, ROAD, SHOP_FRAMES,
  SHOP_FRAME_PRICE, STREAK_MILESTONES, TIERS, ULT_IDS, ULTS, WIN_CHESTS_PER_DAY, arenaFor, avatarPrice, botRecordName,
  isCollectibleBoard, ladderChest, levelStep, rankFor,
  type AvatarId, type BoardTheme, type Bot, type CardId, type ChestRarity, type ChestSource, type FrameId, type Guarantee,
  type Preset, type RoadStep, type Tier, type TimeControl, type UltId,
} from './catalog'
import puzzles from '../data/puzzles.json'

export type Puzzle = {
  id: string; title: string; goal: 'mate' | 'material' | 'territory'; n: number | null; difficulty: number
  fen: string; lines: string[][]; hand: string[]; mana: number; ultimate: string | null
}
export const PUZZLES = puzzles as Puzzle[]
export const puzzleXP = (p: Puzzle) => (p.difficulty === 1 ? 10 : p.difficulty === 2 ? 20 : 35)
export const isRookRaidPuzzle = (p: Puzzle) => p.goal === 'territory' || p.hand.length > 0 || !!p.ultimate

export type Settings = {
  haptics: boolean; sound: boolean; hints: boolean; boardTheme: BoardTheme; showCoordinates: boolean
  timeControl: TimeControl; playAsWhite: boolean; ultimate: UltId; deck: CardId[]; showTerritory: boolean
  botSkins: boolean
}
export type Result = 'win' | 'loss' | 'draw'
export type GameRecord = {
  id: string; date: number; opponent: string; result: Result; reason: string; moves: number
  trophyDelta: number; cardsPlayed: number; replayID?: string
  /** Server match (online games): the same game from another device or from the server is shown once. */
  matchId?: string
}
/** Games kept in the history (same number in the app). */
export const HISTORY_LIMIT = 100
export type Chest = { id: string; rarity: ChestRarity; source: ChestSource; guarantee?: Guarantee; scripted?: boolean; label?: string; date: number }
export type Reward =
  | { kind: 'xp'; n: number } | { kind: 'shards'; n: number } | { kind: 'card'; card: CardId } | { kind: 'board'; board: BoardTheme }
  | { kind: 'jackpot'; n: number } | { kind: 'avatar'; avatar: AvatarId } | { kind: 'frame'; frame: FrameId } | { kind: 'title'; title: string }

export type Profile = {
  name: string; trophies: number; bestTrophies: number; wins: number; losses: number; draws: number
  settings: Settings; history: GameRecord[]; tutorialSeen: boolean
  xp: number; solvedPuzzles: string[]; dailyBonusDay: string | null
  streak: number; bestStreak: number; lastStreakDay: string | null; activeDays: string[]; dailyChestDay: string | null
  ladderBeaten: number; ladderWins: Record<string, number>
  chests: Chest[]; shards: number; unlockedCards: string[]; ownedBoards: string[]; pityCounter: number; chestsOpened: number
  legendaryChests: number; levelChestsGranted: number; arenaChestsGranted: number; puzzleChestsGranted: number
  winChestDay: string | null; winChestsToday: number; tutorialChestGiven: boolean
  /** The gold chest for the first friend was given (friends.ts) */
  firstFriendChestGiven: boolean
  puzzleStreak: number; bestPuzzleStreak: number; rushBest: number; rushPlayed: number
  roadClaimed: number[]; selectedTitle: string | null; selectedFrame: string | null; seenCards: string[]
  streakFreezes: number; frozenDays: string[]; freezeNotice: number | null; streakMilestones: number[]
  shardsEarned: number; shardGoal: string | null; shopDay: string | null; shopBought: string[]; shopFrames: string[]
  claimedAchievements: string[]; cardsByType: Record<string, number>; ultimatesUsed: number; bonusActions: number
  tacticBonuses: number; mateWins: number; winStreak: number; bestWinStreak: number; cardsBought: number
  labDone: string[]; deckTourDone: boolean; ownedAvatars: string[]; selectedAvatar: string | null; chestTitles: string[]
  selectedSkin: string | null
}

function defaultSettings(): Settings {
  return {
    haptics: true, sound: true, hints: true, boardTheme: 'green', showCoordinates: true, timeControl: 'blitz3',
    playAsWhite: true, ultimate: 'meteor', deck: [], showTerritory: true, botSkins: true,
  }
}

export function freshProfile(): Profile {
  return {
    name: 'Du', trophies: 0, bestTrophies: 0, wins: 0, losses: 0, draws: 0, settings: defaultSettings(), history: [],
    tutorialSeen: false, xp: 0, solvedPuzzles: [], dailyBonusDay: null, streak: 0, bestStreak: 0, lastStreakDay: null,
    activeDays: [], dailyChestDay: null, ladderBeaten: 0, ladderWins: {}, chests: [], shards: 0, unlockedCards: [],
    ownedBoards: [], pityCounter: 0, chestsOpened: 0, legendaryChests: 0, levelChestsGranted: 1, arenaChestsGranted: 1,
    puzzleChestsGranted: 0, winChestDay: null, winChestsToday: 0, tutorialChestGiven: false, firstFriendChestGiven: false, puzzleStreak: 0,
    bestPuzzleStreak: 0, rushBest: 0, rushPlayed: 0, roadClaimed: [], selectedTitle: null, selectedFrame: null,
    seenCards: [], streakFreezes: 1, frozenDays: [], freezeNotice: null, streakMilestones: [], shardsEarned: 0,
    shardGoal: null, shopDay: null, shopBought: [], shopFrames: [], claimedAchievements: [], cardsByType: {},
    ultimatesUsed: 0, bonusActions: 0, tacticBonuses: 0, mateWins: 0, winStreak: 0, bestWinStreak: 0, cardsBought: 0,
    labDone: [], deckTourDone: false, ownedAvatars: [], selectedAvatar: null, chestTitles: [], selectedSkin: null,
  }
}

const KEY = 'rookraid.profile.v1'
/** Always a real UUID: ids go to the server and to the iPhone app, which only reads UUIDs. */
const uid = (): string => {
  if (crypto.randomUUID) return crypto.randomUUID()
  const b = crypto.getRandomValues(new Uint8Array(16))
  b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80
  const h = [...b].map(x => x.toString(16).padStart(2, '0')).join('')
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`
}

function load(): Profile {
  const base = freshProfile()
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return base
    const parsed = JSON.parse(raw) as Partial<Profile>
    const merged: Profile = { ...base, ...parsed, settings: { ...base.settings, ...(parsed.settings ?? {}) } }
    merged.settings.deck = [...new Set(merged.settings.deck.filter(c => (CARD_IDS as string[]).includes(c)))].slice(0, DECK_SIZE) as CardId[]
    if (!(ULT_IDS as string[]).includes(merged.settings.ultimate)) merged.settings.ultimate = 'meteor'
    return merged
  } catch {
    return base
  }
}

// MARK: Store plumbing

let profile: Profile = load()
let version = 0
const listeners = new Set<() => void>()
let saveTimer = 0
let achievementsCache: Achievement[] | null = null
const changeHooks: Array<(next: Profile, prev: Profile) => void> = []

export function onProfileChange(fn: (next: Profile, prev: Profile) => void) { changeHooks.push(fn) }

function commit(next: Profile) {
  const prev = profile
  profile = next
  version++
  achievementsCache = null
  window.clearTimeout(saveTimer)
  saveTimer = window.setTimeout(flushSave, 300)
  changeHooks.forEach(fn => fn(next, prev))
  listeners.forEach(fn => fn())
}

export function flushSave() {
  window.clearTimeout(saveTimer)
  try { localStorage.setItem(KEY, JSON.stringify(profile)) } catch { /* storage full or blocked */ }
}

/** Change the profile. The callback edits a copy. */
export function update(fn: (p: Profile) => void) {
  const draft: Profile = structuredClone(profile)
  fn(draft)
  commit(draft)
}

export function getProfile() { return profile }

export function useProfile(): Profile {
  return useSyncExternalStore(fn => { listeners.add(fn); return () => listeners.delete(fn) }, () => profile)
}
export function useVersion(): number {
  return useSyncExternalStore(fn => { listeners.add(fn); return () => listeners.delete(fn) }, () => version)
}

window.addEventListener('pagehide', flushSave)
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'hidden') flushSave() })

// MARK: Days

export function dayKey(d: Date = new Date()): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}
export function dayKeyAgo(days: number): string {
  const d = new Date()
  d.setDate(d.getDate() - days)
  return dayKey(d)
}
export function dateFromKey(key: string): Date | null {
  const [y, m, d] = key.split('-').map(Number)
  return y && m && d ? new Date(y, m - 1, d) : null
}

// MARK: Level and XP

export const xpForLevel = (n: number) => 25 * (n - 1) * n
export function levelFor(xp: number): number {
  let n = 1
  while (xpForLevel(n + 1) <= xp) n++
  return n
}
export const level = () => levelFor(profile.xp)
export function levelProgress(p: Profile = profile) {
  const lv = levelFor(p.xp)
  const lo = xpForLevel(lv), hi = xpForLevel(lv + 1)
  return { fraction: Math.min(1, Math.max(0, (p.xp - lo) / Math.max(1, hi - lo))), remaining: hi - p.xp, level: lv }
}

// MARK: Arena, ultimates and deck

export const arena = (p: Profile = profile) => arenaFor(p.trophies)
export const isUltUnlocked = (u: UltId, p: Profile = profile) => ULTS[u].arena <= arenaFor(p.trophies).n
export const activeUltimate = (p: Profile = profile): UltId => (isUltUnlocked(p.settings.ultimate, p) ? p.settings.ultimate : 'meteor')
export const isCardUnlocked = (c: CardId, p: Profile = profile) => CARDS[c].tier === 'starter' || p.unlockedCards.includes(c)
export const unlockedCards = (p: Profile = profile) => CARD_IDS.filter(c => isCardUnlocked(c, p))
export const isNewCard = (c: CardId, p: Profile = profile) =>
  CARDS[c].tier !== 'starter' && p.unlockedCards.includes(c) && !p.seenCards.includes(c)
export const newCardCount = (p: Profile = profile) => CARD_IDS.filter(c => isNewCard(c, p)).length
export function markAllSeen() {
  const fresh = CARD_IDS.filter(c => isNewCard(c))
  if (fresh.length) update(p => { p.seenCards.push(...fresh) })
}
export function activeDeck(p: Profile = profile): CardId[] {
  const out: CardId[] = []
  for (const c of p.settings.deck) if (isCardUnlocked(c, p) && !out.includes(c)) out.push(c)
  return out.slice(0, DECK_SIZE)
}
export const deckIsFull = (p: Profile = profile) => activeDeck(p).length >= DECK_SIZE
export const needsDeckTour = (p: Profile = profile) => p.tutorialSeen && !p.deckTourDone
export function setDeck(cards: CardId[]) {
  if (cards.length > DECK_SIZE || new Set(cards).size !== cards.length) return
  update(p => { p.settings.deck = cards })
}
export function addToDeck(c: CardId): boolean {
  const deck = activeDeck()
  if (!isCardUnlocked(c) || deck.includes(c) || deck.length >= DECK_SIZE) return false
  setDeck([...deck, c])
  return true
}
export const removeFromDeck = (c: CardId) => setDeck(activeDeck().filter(x => x !== c))
export const isPresetUnlocked = (preset: Preset) => preset.cards.every(c => isCardUnlocked(c)) && isUltUnlocked(preset.ultimate)
export function applyPreset(preset: Preset) {
  if (!isPresetUnlocked(preset)) return
  update(p => { p.settings.deck = [...preset.cards]; p.settings.ultimate = preset.ultimate })
}
export function setSettings(fn: (s: Settings) => void) { update(p => fn(p.settings)) }

// MARK: Game records

export function trophyDelta(mine: number, opponent: number, result: Result): number {
  mine = Math.max(0, mine)
  const gap = Math.min(800, Math.max(-800, Math.max(0, opponent) - mine))
  const shift = Math.trunc(gap / 100)
  let raw: number
  if (result === 'win') raw = Math.min(40, Math.max(8, 20 + shift * 4))
  else if (result === 'draw') raw = Math.min(12, Math.max(-12, shift * 2))
  else raw = Math.min(-8, Math.max(-40, -(20 - shift * 4)))
  return mine + raw < 0 ? -mine : raw
}

export function record(opts: {
  result: Result; rated: boolean; opponent: string; reason: string; moves: number; cardsPlayed: number
  replayID?: string; countsForStats?: boolean; opponentTrophies?: number; matchId?: string
}): number {
  let delta = 0
  update(p => {
    if (!opts.rated && opts.countsForStats) {
      if (opts.result === 'win') p.wins++; else if (opts.result === 'loss') p.losses++; else p.draws++
    }
    if (opts.rated) {
      delta = trophyDelta(p.trophies, opts.opponentTrophies ?? p.trophies, opts.result)
      if (opts.result === 'win') p.wins++; else if (opts.result === 'loss') p.losses++; else p.draws++
      p.trophies = Math.max(0, p.trophies + delta)
      p.bestTrophies = Math.max(p.bestTrophies, p.trophies)
    }
    p.history.unshift({ id: uid(), date: Date.now(), opponent: opts.opponent, result: opts.result, reason: opts.reason,
      moves: opts.moves, trophyDelta: delta, cardsPlayed: opts.cardsPlayed, replayID: opts.replayID, matchId: opts.matchId })
    if (p.history.length > HISTORY_LIMIT) p.history = p.history.slice(0, HISTORY_LIMIT)
  })
  return delta
}

// MARK: Flame

export function currentStreak(p: Profile = profile): number {
  if (!p.lastStreakDay) return 0
  return p.lastStreakDay === dayKey() || p.lastStreakDay === dayKeyAgo(1) ? p.streak : 0
}
export const flameLitToday = (p: Profile = profile) => p.lastStreakDay === dayKey()

/** Shown once on the menu: the flame for today was just lit. */
let flameCelebration: number | null = null
const flameListeners = new Set<() => void>()
export function useFlameCelebration() {
  return useSyncExternalStore(fn => { flameListeners.add(fn); return () => flameListeners.delete(fn) }, () => flameCelebration)
}
export function clearFlameCelebration() { flameCelebration = null; flameListeners.forEach(fn => fn()) }

export function registerActivity(): number | null {
  const today = dayKey()
  if (profile.lastStreakDay === today) return null
  let streak = 0
  update(p => {
    p.streak = p.lastStreakDay === dayKeyAgo(1) ? p.streak + 1 : 1
    p.bestStreak = Math.max(p.bestStreak, p.streak)
    p.lastStreakDay = today
    if (!p.activeDays.includes(today)) p.activeDays.push(today)
    if (p.activeDays.length > 400) p.activeDays = p.activeDays.slice(-400)
    streak = p.streak
  })
  grantStreakMilestones()
  flameCelebration = streak
  flameListeners.forEach(fn => fn())
  return streak
}

export function checkStreak() {
  // A streak that came with the account (another device) may not have granted its milestones here yet.
  try { checkStreakInner() } finally { grantStreakMilestones() }
}
function checkStreakInner() {
  if (profile.streak <= 0 || !profile.lastStreakDay) return
  const last = dateFromKey(profile.lastStreakDay)
  if (!last) return
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const gap = Math.round((today.getTime() - last.getTime()) / 86_400_000)
  const missed = gap - 1
  if (missed <= 0 || missed > profile.streakFreezes) return
  update(p => {
    for (let d = 1; d <= missed; d++) {
      const day = new Date(last); day.setDate(day.getDate() + d)
      const key = dayKey(day)
      if (!p.frozenDays.includes(key)) p.frozenDays.push(key)
    }
    if (p.frozenDays.length > 400) p.frozenDays = p.frozenDays.slice(-400)
    p.streakFreezes -= missed
    const y = new Date(today); y.setDate(y.getDate() - 1)
    p.lastStreakDay = dayKey(y)
    p.freezeNotice = missed
  })
}

export const nextStreakMilestone = (p: Profile = profile) => STREAK_MILESTONES.find(m => !p.streakMilestones.includes(m.days))
export const canBuyFreeze = (p: Profile = profile) => p.streakFreezes < MAX_FREEZES && p.shards >= FREEZE_PRICE
export function buyFreeze(): boolean {
  if (!canBuyFreeze()) return false
  update(p => { p.shards -= FREEZE_PRICE; p.streakFreezes++; if (p.shardGoal === 'freeze') p.shardGoal = null })
  return true
}
function grantStreakMilestones() {
  for (const m of STREAK_MILESTONES) {
    if (currentStreak(profile) < m.days || profile.streakMilestones.includes(m.days)) continue
    update(p => { p.streakMilestones.push(m.days) })
    if (m.chest !== undefined) grantChest('streak', m.chest, { label: `${m.days} Tage` })
    if (m.shards > 0) earnShards(m.shards)
    if (m.freeze) {
      if (profile.streakFreezes < MAX_FREEZES) update(p => { p.streakFreezes++ }); else earnShards(100)
    }
  }
}

// MARK: Daily goals

export type DailyGoal = { kind: 'flame' | 'puzzle' | 'win'; icon: string; title: string; done: boolean }
export const dailyBonusAvailable = (p: Profile = profile) => p.dailyBonusDay !== dayKey()
export function dailyGoals(p: Profile = profile): DailyGoal[] {
  const today = dayKey()
  const wonToday = p.history.some(h => dayKey(new Date(h.date)) === today && h.result === 'win' && h.opponent !== 'Zu zweit')
  return [
    { kind: 'flame', icon: 'flame', title: 'Flamme entzünden', done: flameLitToday(p) },
    { kind: 'puzzle', icon: 'puzzle', title: 'Tagespuzzle lösen', done: !dailyBonusAvailable(p) },
    { kind: 'win', icon: 'trophy', title: 'Eine Partie gewinnen', done: wonToday },
  ]
}
export const dailyChestOpened = (p: Profile = profile) => p.dailyChestDay === dayKey()
export const dailyChestReady = (p: Profile = profile) => !dailyChestOpened(p) && dailyGoals(p).every(g => g.done)
export function claimDailyChest(): Chest | null {
  if (!dailyChestReady()) return null
  update(p => { p.dailyChestDay = dayKey() })
  return grantChest('daily', 2)
}

// MARK: Ladder

export const ladderNext = (p: Profile = profile): Bot | null => (p.ladderBeaten < BOTS.length ? BOTS[p.ladderBeaten] : null)
export const isLadderUnlocked = (b: Bot, p: Profile = profile) => b.tier <= p.ladderBeaten + 1
export const isLadderBeaten = (b: Bot, p: Profile = profile) => b.tier <= p.ladderBeaten
export function recordLadderWin(b: Bot) {
  const first = !isLadderBeaten(b)
  const before = level()
  const xp = first ? b.xpFirstWin : 10
  let unlocked: Bot | null = null
  update(p => {
    p.ladderWins[b.id] = (p.ladderWins[b.id] ?? 0) + 1
    if (first && b.tier === p.ladderBeaten + 1) {
      p.ladderBeaten = b.tier
      if (b.tier < BOTS.length) unlocked = BOTS[b.tier]
    }
  })
  if (first) grantChest('ladder', ladderChest(b), { label: b.name })
  addXP(xp)
  return { xp, firstWin: first, unlocked: unlocked as Bot | null, levelUp: level() > before ? level() : null }
}

// MARK: Puzzles

export const isSolved = (pz: Puzzle, p: Profile = profile) => p.solvedPuzzles.includes(pz.id)
export function dailyPuzzle(): Puzzle {
  const start = new Date(); start.setHours(0, 0, 0, 0)
  // Same day index as the app (seconds since 1970 of local midnight / 86 400).
  const day = Math.floor(start.getTime() / 1000 / 86_400)
  return PUZZLES[(day * 7) % PUZZLES.length]
}
export function nextPuzzle(): Puzzle {
  const open = PUZZLES.filter(z => !isSolved(z))
  if (!open.length) return PUZZLES[Math.floor(Math.random() * PUZZLES.length)]
  return open.reduce((a, b) => (b.difficulty < a.difficulty ? b : a))
}
export function breakPuzzleStreak() { update(p => { p.puzzleStreak = 0 }) }
export function finishRush(score: number): boolean {
  const best = score > profile.rushBest
  update(p => { p.rushPlayed++; if (best) p.rushBest = score })
  addXP(score * 3)
  registerActivity()
  return best
}
export type PuzzleReward = { xp: number; dailyBonus: number; firstSolve: boolean; levelUp: number | null; streakLit: number | null; chest: boolean; puzzleStreak: number }
export function solvePuzzle(pz: Puzzle, clean: boolean, isDaily: boolean): PuzzleReward {
  const first = !isSolved(pz)
  const before = level()
  let gained = first ? (clean ? puzzleXP(pz) : Math.max(1, Math.floor(puzzleXP(pz) / 2))) : 0
  let bonus = 0
  update(p => {
    if (isDaily && p.dailyBonusDay !== dayKey()) { bonus = 15; p.dailyBonusDay = dayKey() }
    if (first) p.solvedPuzzles.push(pz.id)
    if (clean) { p.puzzleStreak++; p.bestPuzzleStreak = Math.max(p.bestPuzzleStreak, p.puzzleStreak) } else p.puzzleStreak = 0
  })
  gained += bonus
  const chest = first && grantPuzzleChestIfDue()
  addXP(gained)
  const lit = registerActivity()
  return { xp: gained - bonus, dailyBonus: bonus, firstSolve: first, levelUp: level() > before ? level() : null,
    streakLit: lit, chest, puzzleStreak: profile.puzzleStreak }
}

// MARK: Chests

export const pendingChests = (p: Profile = profile) => p.chests
export function grantChest(source: ChestSource, rarity: ChestRarity, opts: { guarantee?: Guarantee; label?: string; scripted?: boolean } = {}): Chest {
  const chest: Chest = { id: uid(), rarity, source, guarantee: opts.guarantee, scripted: opts.scripted, label: opts.label, date: Date.now() }
  update(p => { p.chests.push(chest) })
  return chest
}
export function addXP(n: number) {
  if (n <= 0) return
  update(p => { p.xp += n })
  grantLevelChests()
}
function grantLevelChests() {
  while (profile.levelChestsGranted < level()) {
    const next = profile.levelChestsGranted + 1
    update(p => { p.levelChestsGranted = next })
    const step = levelStep(next)
    grantChest('level', step.rarity, { guarantee: step.guarantee, label: `Level ${next}` })
  }
}
export function grantWinChest(): boolean {
  const today = dayKey()
  let granted = false
  update(p => {
    if (p.winChestDay !== today) { p.winChestDay = today; p.winChestsToday = 0 }
    if (p.winChestsToday < WIN_CHESTS_PER_DAY) { p.winChestsToday++; granted = true }
  })
  if (granted) grantChest('win', 0)
  return granted
}
export const winChestsLeftToday = (p: Profile = profile) =>
  p.winChestDay === dayKey() ? Math.max(0, WIN_CHESTS_PER_DAY - p.winChestsToday) : WIN_CHESTS_PER_DAY
function grantPuzzleChestIfDue(): boolean {
  const due = Math.floor(profile.solvedPuzzles.length / PUZZLES_PER_CHEST)
  if (due <= profile.puzzleChestsGranted) return false
  while (profile.puzzleChestsGranted < due) {
    update(p => { p.puzzleChestsGranted++ })
    grantChest('puzzle', 1)
  }
  return true
}
export function grantTutorialChest() {
  if (profile.tutorialChestGiven) return
  update(p => { p.tutorialChestGiven = true })
  grantChest('tutorial', 1, { guarantee: { card: 'reinforce' }, scripted: true })
}

export type ChestPlan = { chest: Chest; steps: ChestRarity[] }
export function planChest(chest: Chest): ChestPlan {
  let r = chest.rarity
  const steps: ChestRarity[] = []
  for (let i = 0; i < 3; i++) {
    const up = chest.scripted ? i === 1 : Math.random() < CHEST[r].up
    if (up && r < 4) r = (r + 1) as ChestRarity
    steps.push(r)
  }
  return { chest, steps }
}
const droppableCards = () => CARD_IDS.filter(c => !isCardUnlocked(c) && level() >= TIERS[CARDS[c].tier].gate)
function randomDroppable(): CardId | null {
  const pool = droppableCards()
  if (!pool.length) return null
  const total = pool.reduce((s, c) => s + TIERS[CARDS[c].tier].weight, 0)
  let x = Math.random() * total
  for (const c of pool) { x -= TIERS[CARDS[c].tier].weight; if (x < 0) return c }
  return pool[pool.length - 1]
}
function pickCard(tier: Tier): CardId | null {
  const same = CARD_IDS.filter(c => !isCardUnlocked(c) && CARDS[c].tier === tier)
  return same.length ? same[Math.floor(Math.random() * same.length)] : randomDroppable()
}
export const isBoardOwned = (b: BoardTheme, p: Profile = profile) => !isCollectibleBoard(b) || p.ownedBoards.includes(b)
export const isAvatarOwned = (a: AvatarId, p: Profile = profile) => a === 'knight' || p.ownedAvatars.includes(a)

export function openChest(plan: ChestPlan): Reward[] {
  const rarity = plan.steps[plan.steps.length - 1] ?? plan.chest.rarity
  const info = CHEST[rarity]
  const rewards: Reward[] = [{ kind: 'xp', n: info.xp }, { kind: 'shards', n: info.shards }]
  update(p => {
    p.chests = p.chests.filter(c => c.id !== plan.chest.id)
    p.chestsOpened++
    p.shards += info.shards
    p.shardsEarned += info.shards
    if (rarity === 4) p.legendaryChests++
  })
  const locked = BOARD_THEMES.filter(b => isCollectibleBoard(b) && !isBoardOwned(b))
  if (locked.length && Math.random() < info.board) {
    const board = locked[Math.floor(Math.random() * locked.length)]
    update(p => { p.ownedBoards.push(board) })
    rewards.push({ kind: 'board', board })
  }
  let card: CardId | null = null
  const g = plan.chest.guarantee
  if (g && 'card' in g) card = isCardUnlocked(g.card) ? pickCard(CARDS[g.card].tier) : g.card
  else if (g && 'tier' in g) card = pickCard(g.tier)
  let cardRoll = false
  if (!card) {
    const pity = profile.pityCounter >= PITY_LIMIT - 1
    if (pity || Math.random() < info.card) { cardRoll = true; card = randomDroppable() }
  }
  if (cardRoll && !card && CARD_IDS.every(c => isCardUnlocked(c))) {
    earnShards(JACKPOT_SHARDS)
    rewards.push({ kind: 'jackpot', n: JACKPOT_SHARDS })
  }
  if (card && !isCardUnlocked(card)) {
    const picked = card
    update(p => { p.unlockedCards.push(picked); p.pityCounter = 0 })
    rewards.push({ kind: 'card', card: picked })
  } else {
    update(p => { p.pityCounter++ })
  }
  const cosmetic = rollCosmetic(rarity)
  if (cosmetic) {
    const i = rewards.findIndex(r => r.kind === 'card')
    if (i >= 0) rewards.splice(i, 0, cosmetic); else rewards.push(cosmetic)
  }
  addXP(info.xp)
  return rewards
}

function rollCosmetic(chest: ChestRarity): Reward | null {
  if (Math.random() >= COSMETIC_CHANCE[chest]) return null
  const allowLegendary = chest >= 3
  const pool: Array<[Reward, number]> = []
  for (const a of AVATARS) if (!isAvatarOwned(a.id) && (allowLegendary || a.rarity < 3)) pool.push([{ kind: 'avatar', avatar: a.id }, COSMETIC_RARITY[a.rarity].weight])
  for (const f of SHOP_FRAMES) if (!profile.shopFrames.includes(f)) {
    const r = f === 'ruby' ? 1 : f === 'nebula' ? 2 : 3
    if (allowLegendary || r < 3) pool.push([{ kind: 'frame', frame: f }, COSMETIC_RARITY[r].weight])
  }
  for (const t of CHEST_TITLES) if (!profile.chestTitles.includes(t.title) && (allowLegendary || t.rarity < 3)) pool.push([{ kind: 'title', title: t.title }, COSMETIC_RARITY[t.rarity].weight])
  if (!pool.length) return null
  let x = Math.random() * pool.reduce((s, [, w]) => s + w, 0)
  let pick = pool[0][0]
  for (const [r, w] of pool) { x -= w; if (x < 0) { pick = r; break } }
  update(p => {
    if (pick.kind === 'avatar') p.ownedAvatars.push(pick.avatar)
    if (pick.kind === 'frame') p.shopFrames.push(pick.frame)
    if (pick.kind === 'title') p.chestTitles.push(pick.title)
  })
  return pick
}

export function earnShards(n: number) {
  if (n <= 0) return
  update(p => { p.shards += n; p.shardsEarned += n })
}
export const canBuyCard = (c: CardId) => !isCardUnlocked(c) && level() >= TIERS[CARDS[c].tier].gate && profile.shards >= TIERS[CARDS[c].tier].price
export function buyCard(c: CardId): boolean {
  if (!canBuyCard(c)) return false
  update(p => {
    p.shards -= TIERS[CARDS[c].tier].price
    p.unlockedCards.push(c); p.seenCards.push(c); p.cardsBought++
    if (p.shardGoal === `card.${c}`) p.shardGoal = null
  })
  return true
}

// MARK: Trophy road

export const roadTrophies = (p: Profile = profile) => Math.max(p.trophies, p.bestTrophies)
export function isRoadClaimed(s: RoadStep, p: Profile = profile) {
  if (p.roadClaimed.includes(s.trophies)) return true
  return s.reward.kind === 'arena' && s.reward.arena <= p.arenaChestsGranted
}
export const isRoadReached = (s: RoadStep, p: Profile = profile) => roadTrophies(p) >= s.trophies
export const canClaimRoad = (s: RoadStep, p: Profile = profile) => isRoadReached(s, p) && !isRoadClaimed(s, p)
export const claimableRoadSteps = (p: Profile = profile) => ROAD.filter(s => canClaimRoad(s, p))
export const nextRoadStep = (p: Profile = profile) => ROAD.find(s => !isRoadReached(s, p))
export type RoadClaim = { kind: 'chest'; chest: Chest } | { kind: 'shards'; n: number } | { kind: 'board'; board: BoardTheme }
export function claimRoad(s: RoadStep): RoadClaim | null {
  if (!canClaimRoad(s)) return null
  update(p => { p.roadClaimed.push(s.trophies) })
  const r = s.reward
  if (r.kind === 'chest') return { kind: 'chest', chest: grantChest('road', r.rarity, { label: `${s.trophies} Trophäen` }) }
  if (r.kind === 'arena') {
    update(p => { p.arenaChestsGranted = Math.max(p.arenaChestsGranted, r.arena) })
    return { kind: 'chest', chest: grantChest('arena', r.rarity, { label: ARENAS[r.arena - 1].name }) }
  }
  if (r.kind === 'shards') { earnShards(r.n); return { kind: 'shards', n: r.n } }
  if (profile.ownedBoards.includes(r.board)) { earnShards(BOARD_PRICE); return { kind: 'shards', n: BOARD_PRICE } }
  update(p => { p.ownedBoards.push(r.board) })
  return { kind: 'board', board: r.board }
}

// MARK: Cosmetics and skins

export const activeAvatar = (p: Profile = profile): AvatarId =>
  p.selectedAvatar && AVATARS.some(a => a.id === p.selectedAvatar) && isAvatarOwned(p.selectedAvatar as AvatarId, p) ? p.selectedAvatar as AvatarId : 'knight'
export function isSkinUnlocked(b: Bot, p: Profile = profile) {
  return p.ladderBeaten >= b.tier || p.history.some(h => h.opponent === botRecordName(b) && h.result === 'win')
}
export const activeSkin = (p: Profile = profile): Bot | null => {
  const b = BOTS.find(x => x.id === p.selectedSkin)
  return b && isSkinUnlocked(b, p) ? b : null
}

// MARK: Shop

export type ShopItem =
  | { kind: 'chest'; rarity: ChestRarity } | { kind: 'card'; card: CardId } | { kind: 'board'; board: BoardTheme }
  | { kind: 'frame'; frame: FrameId } | { kind: 'avatar'; avatar: AvatarId } | { kind: 'freeze' }
export type ShopOffer = { id: string; item: ShopItem; price: number; basePrice: number }
export const goalID = (i: ShopItem) =>
  i.kind === 'chest' ? `chest.${i.rarity}` : i.kind === 'card' ? `card.${i.card}` : i.kind === 'board' ? `board.${i.board}`
    : i.kind === 'frame' ? `frame.${i.frame}` : i.kind === 'avatar' ? `avatar.${i.avatar}` : 'freeze'
export function basePrice(i: ShopItem): number {
  switch (i.kind) {
    case 'chest': return CHEST_PRICES[i.rarity] ?? 220
    case 'card': return TIERS[CARDS[i.card].tier].price
    case 'board': return BOARD_PRICE
    case 'frame': return SHOP_FRAME_PRICE
    case 'avatar': return avatarPrice(i.avatar)
    case 'freeze': return FREEZE_PRICE
  }
}
// Same seeded generator as the app (FNV-1a seed, 64-bit LCG), so the daily offers match the phone.
function seedFor(day: string): bigint {
  let h = 1469598103934665603n
  const mask = (1n << 64n) - 1n
  for (const b of new TextEncoder().encode(day)) h = ((h ^ BigInt(b)) * 1099511628211n) & mask
  return h
}
class DayRNG {
  constructor(private state: bigint) {}
  next(): number {
    this.state = (this.state * 6364136223846793005n + 1442695040888963407n) & ((1n << 64n) - 1n)
    return Number((this.state >> 33n) % 1_000_000n) / 1_000_000
  }
  pick<T>(a: T[]): T | undefined { return a.length ? a[Math.min(a.length - 1, Math.floor(this.next() * a.length))] : undefined }
}
export function dailyOffers(): ShopOffer[] {
  const day = dayKey()
  const rng = new DayRNG(seedFor(day))
  const offers: ShopOffer[] = []
  const chest: ChestRarity = rng.next() < 0.7 ? 2 : 3
  const cp = CHEST_PRICES[chest]
  offers.push({ id: `${day}.chest`, item: { kind: 'chest', rarity: chest }, price: cp, basePrice: cp })
  const cards = CARD_IDS.filter(c => !isCardUnlocked(c) && level() >= TIERS[CARDS[c].tier].gate)
  const card = rng.pick(cards)
  if (card) {
    const price = TIERS[CARDS[card].tier].price
    offers.push({ id: `${day}.card`, item: { kind: 'card', card }, price: Math.floor(price * 4 / 5), basePrice: price })
  } else offers.push({ id: `${day}.silver`, item: { kind: 'chest', rarity: 1 }, price: 40, basePrice: 60 })
  const cosmetics: ShopItem[] = [
    ...SHOP_FRAMES.filter(f => !profile.shopFrames.includes(f)).map(frame => ({ kind: 'frame', frame }) as ShopItem),
    ...AVATARS.filter(a => !isAvatarOwned(a.id)).map(a => ({ kind: 'avatar', avatar: a.id }) as ShopItem),
    ...BOARD_THEMES.filter(b => isCollectibleBoard(b) && !isBoardOwned(b)).map(board => ({ kind: 'board', board }) as ShopItem),
  ]
  const item = rng.pick(cosmetics)
  if (item) {
    const base = basePrice(item)
    offers.push({ id: `${day}.cosmetic`, item, price: Math.floor(base * 9 / 10), basePrice: base })
  } else {
    const gold = CHEST_PRICES[2]
    offers.push({ id: `${day}.gold2`, item: { kind: 'chest', rarity: 2 }, price: Math.floor(gold * 4 / 5), basePrice: gold })
  }
  return offers
}
export const isOfferBought = (o: ShopOffer, p: Profile = profile) => p.shopDay === dayKey() && p.shopBought.includes(o.id)
export function isItemOwned(i: ShopItem, p: Profile = profile): boolean {
  switch (i.kind) {
    case 'chest': return false
    case 'card': return isCardUnlocked(i.card, p)
    case 'board': return isBoardOwned(i.board, p)
    case 'frame': return p.shopFrames.includes(i.frame)
    case 'avatar': return isAvatarOwned(i.avatar, p)
    case 'freeze': return p.streakFreezes >= MAX_FREEZES
  }
}
export function buyItem(i: ShopItem, price: number, offerID?: string): { kind: 'chest'; chest: Chest } | { kind: 'unlocked' } | null {
  if (offerID && profile.shopDay === dayKey() && profile.shopBought.includes(offerID)) return null
  if (isItemOwned(i) || profile.shards < price) return null
  if (i.kind === 'card' && level() < TIERS[CARDS[i.card].tier].gate) return null
  update(p => {
    p.shards -= price
    if (offerID) {
      if (p.shopDay !== dayKey()) { p.shopDay = dayKey(); p.shopBought = [] }
      p.shopBought.push(offerID)
    }
    if (p.shardGoal === goalID(i)) p.shardGoal = null
    if (i.kind === 'card') { p.unlockedCards.push(i.card); p.seenCards.push(i.card); p.cardsBought++ }
    if (i.kind === 'board') p.ownedBoards.push(i.board)
    if (i.kind === 'frame') { p.shopFrames.push(i.frame); p.selectedFrame = i.frame }
    if (i.kind === 'avatar') { p.ownedAvatars.push(i.avatar); p.selectedAvatar = i.avatar }
    if (i.kind === 'freeze') p.streakFreezes++
  })
  if (i.kind === 'chest') return { kind: 'chest', chest: grantChest('shop', i.rarity) }
  return { kind: 'unlocked' }
}
export function shardGoalItem(p: Profile = profile): { item: ShopItem; price: number } | null {
  if (!p.shardGoal) return null
  const [kind, value] = p.shardGoal.split('.')
  let item: ShopItem | null = null
  if (kind === 'card' && (CARD_IDS as string[]).includes(value)) item = { kind: 'card', card: value as CardId }
  if (kind === 'board' && (BOARD_THEMES as string[]).includes(value)) item = { kind: 'board', board: value as BoardTheme }
  if (kind === 'frame' && SHOP_FRAMES.includes(value as FrameId)) item = { kind: 'frame', frame: value as FrameId }
  if (kind === 'avatar' && AVATARS.some(a => a.id === value)) item = { kind: 'avatar', avatar: value as AvatarId }
  if (kind === 'chest' && Number(value) >= 0 && Number(value) <= 4) item = { kind: 'chest', rarity: Number(value) as ChestRarity }
  if (kind === 'freeze') item = { kind: 'freeze' }
  if (!item || isItemOwned(item, p)) return null
  return { item, price: basePrice(item) }
}
export const setShardGoal = (i: ShopItem | null) => update(p => { p.shardGoal = i ? goalID(i) : null })

// MARK: Achievements

export type Achievement = {
  id: string; category: string; icon: string; title: string; titleArgs?: Array<string | number>; detail: string
  detailArgs?: Array<string | number>; progress: number; goal: number; tier: number; shards: number
  rewardTitle?: string; rewardFrame?: FrameId
}
export const ACHIEVEMENT_CATEGORIES: Array<[string, string, string]> = [
  ['battle', 'Kampf', 'bolt'], ['ladder', 'Bot-Leiter', 'stairs'], ['trophies', 'Trophäen', 'trophy'],
  ['cards', 'Karten & Ultimates', 'stack'], ['puzzles', 'Puzzles', 'puzzle'], ['flames', 'Flammen', 'flame'],
  ['collection', 'Sammlung', 'box'], ['shards', 'Splitter', 'diamond'], ['level', 'Level', 'star'],
]
export function achievements(p: Profile = profile): Achievement[] {
  if (p === profile && achievementsCache) return achievementsCache
  const rated = p.history.filter(h => h.opponent !== 'Zu zweit')
  const beat = (b: Bot) => (p.ladderBeaten >= b.tier || rated.some(h => h.opponent === botRecordName(b) && h.result === 'win') ? 1 : 0)
  const cardsPlayed = Math.max(Object.values(p.cardsByType).reduce((a, b) => a + b, 0), p.history.reduce((a, h) => a + h.cardsPlayed, 0))
  const typesPlayed = CARD_IDS.filter(c => (p.cardsByType[c] ?? 0) > 0).length
  const collectible = CARD_IDS.filter(c => CARDS[c].tier !== 'starter')
  const collected = collectible.filter(c => p.unlockedCards.includes(c)).length
  const boards = BOARD_THEMES.filter(isCollectibleBoard)
  const ownedBoards = boards.filter(b => p.ownedBoards.includes(b)).length
  const solved = p.solvedPuzzles.length
  const lv = levelFor(p.xp)
  const A = (id: string, category: string, icon: string, title: string, detail: string, progress: number, goal: number,
    tier = 0, shards = 20, extra: Partial<Achievement> = {}): Achievement =>
    ({ id, category, icon, title, detail, progress, goal, tier, shards, ...extra })
  const list: Achievement[] = [
    A('firstWin', 'battle', 'crown', 'Erster Sieg', 'Gewinne eine Partie', p.wins, 1, 0, 20, { rewardTitle: 'Herausforderer' }),
    A('wins10', 'battle', 'medal', 'Kämpfer', 'Gewinne 10 Partien', p.wins, 10, 1, 30),
    A('wins50', 'battle', 'medal', 'Veteran', 'Gewinne 50 Partien', p.wins, 50, 2, 80, { rewardFrame: 'silver' }),
    A('wins100', 'battle', 'medal', 'Kriegsherr', 'Gewinne 100 Partien', p.wins, 100, 3, 150, { rewardTitle: 'Kriegsherr' }),
    A('wins250', 'battle', 'shieldHalf', 'Unbesiegbar', 'Gewinne 250 Partien', p.wins, 250, 3, 300, { rewardTitle: 'Unbesiegbar' }),
    A('mate10', 'battle', 'xShield', 'Mattsetzer', '10 Siege durch Schachmatt', p.mateWins, 10, 1, 40),
    A('mate50', 'battle', 'xShield', 'Mattkünstler', '50 Siege durch Schachmatt', p.mateWins, 50, 3, 120, { rewardTitle: 'Mattkünstler' }),
    A('wstreak3', 'battle', 'bolt', 'Siegesserie', '3 Siege in Folge', p.bestWinStreak, 3, 1, 30),
    A('wstreak5', 'battle', 'bolt', 'Heiße Serie', '5 Siege in Folge', p.bestWinStreak, 5, 2, 60),
    A('wstreak10', 'battle', 'boltCircle', 'Unaufhaltsam', '10 Siege in Folge', p.bestWinStreak, 10, 3, 150, { rewardTitle: 'Unaufhaltsam' }),
  ]
  const ladderShards = [20, 25, 30, 40, 50, 60, 75, 90, 110, 140, 170, 250]
  for (const b of BOTS) {
    const a = A(`ladder-${b.id}`, 'ladder', b.icon, '{0} besiegt', 'Schlage {0} {1}', beat(b), 1,
      b.tier >= 9 ? 3 : b.tier >= 5 ? 2 : 1, ladderShards[b.tier - 1], { titleArgs: [b.name], detailArgs: [b.name, b.title] })
    if (b.id === 'hard') a.rewardTitle = 'Bezwinger'
    if (b.id === 'queen') { a.rewardTitle = 'Königsbezwinger'; a.rewardFrame = 'crown' }
    list.push(a)
  }
  list.push(
    A('arena2', 'trophies', 'shieldHalf', 'Aufsteiger', 'Arena 2 erreicht', p.bestTrophies, 90, 1, 30),
    A('arena3', 'trophies', 'crown', 'Thronanwärter', 'Arena 3 erreicht', p.bestTrophies, 240, 1, 50),
    A('arena4', 'trophies', 'cloudBolt', 'Sturmreiter', 'Arena 4 erreicht', p.bestTrophies, 600, 2, 80, { rewardFrame: 'gold' }),
    A('arena5', 'trophies', 'flame', 'Drachentöter', 'Arena 5 erreicht', p.bestTrophies, 1200, 2, 120),
    A('arena6', 'trophies', 'mountain', 'Gipfelkönig', 'Arena 6 erreicht', p.bestTrophies, 2100, 3, 200, { rewardTitle: 'Gipfelkönig' }),
    A('road', 'trophies', 'flagCheckered', 'Ende des Pfads', '2400 Trophäen erreicht', p.bestTrophies, 2400, 3, 300),
    A('cards25', 'cards', 'stack', 'Kartenspieler', '25 Karten gespielt', cardsPlayed, 25, 1, 30),
    A('cards100', 'cards', 'stack', 'Kartenmeister', '100 Karten gespielt', cardsPlayed, 100, 2, 80, { rewardTitle: 'Kartenmeister' }),
    A('cards500', 'cards', 'wand', 'Großmagier', '500 Karten gespielt', cardsPlayed, 500, 3, 200, { rewardTitle: 'Großmagier' }),
    A('ult1', 'cards', 'sparkles', 'Ultimativ', 'Setze eine Ultimate ein', p.ultimatesUsed, 1, 0, 20),
    A('ult25', 'cards', 'sparkles', 'Ultimate-Meister', '25 Ultimates eingesetzt', p.ultimatesUsed, 25, 2, 100),
    A('allTypes', 'cards', 'grid', 'Allrounder', 'Spiele jede der {0} Karten einmal', typesPlayed, CARD_IDS.length, 2, 100, { detailArgs: [CARD_IDS.length] }),
    A('bonus50', 'cards', 'walk', 'Doppelschlag', '50 Bonusaktionen gespielt', p.bonusActions, 50, 2, 60),
    A('tactic25', 'cards', 'branch', 'Taktiker', '25 Taktiken (Gabel, Fesselung …)', p.tacticBonuses, 25, 2, 60, { rewardTitle: 'Taktiker' }),
    A('puzzles10', 'puzzles', 'puzzle', 'Rätselfuchs', '10 Puzzles gelöst', solved, 10, 1, 30, { rewardTitle: 'Rätselfuchs' }),
    A('puzzles50', 'puzzles', 'brain', 'Rätselmeister', '50 Puzzles gelöst', solved, 50, 2, 80, { rewardFrame: 'puzzle' }),
    A('puzzles100', 'puzzles', 'brain', 'Rätselgenie', '100 Puzzles gelöst', solved, 100, 3, 150),
    A('puzzlesAll', 'puzzles', 'seal', 'Rätselkönig', 'Alle {0} Puzzles gelöst', solved, PUZZLES.length, 3, 300, { rewardTitle: 'Rätselkönig', detailArgs: [PUZZLES.length] }),
    A('pstreak5', 'puzzles', 'target', 'Konzentriert', '5 Puzzles in Folge ohne Fehler oder Hinweis', p.bestPuzzleStreak, 5, 1, 30),
    A('pstreak10', 'puzzles', 'target', 'Fehlerlos', '10 Puzzles in Folge ohne Fehler oder Hinweis', p.bestPuzzleStreak, 10, 2, 60, { rewardTitle: 'Fehlerlos' }),
    A('pstreak25', 'puzzles', 'scope', 'Makellos', '25 Puzzles in Folge ohne Fehler oder Hinweis', p.bestPuzzleStreak, 25, 3, 150),
    A('rush10', 'puzzles', 'boltCircle', 'Schnelldenker', '10 Punkte im Puzzle-Rausch', p.rushBest, 10, 1, 40),
    A('rush20', 'puzzles', 'boltCircle', 'Blitzdenker', '20 Punkte im Puzzle-Rausch', p.rushBest, 20, 3, 100, { rewardTitle: 'Blitzdenker' }),
    A('streak3', 'flames', 'flame', 'Feuerserie', '3 Tage in Folge gespielt', p.bestStreak, 3, 1, 20, { rewardFrame: 'flame' }),
    A('streak7', 'flames', 'calendar', 'Unermüdlich', '7 Tage in Folge gespielt', p.bestStreak, 7, 1, 50, { rewardTitle: 'Unermüdlich' }),
    A('streak30', 'flames', 'heart', 'Feuerherz', '30 Tage in Folge gespielt', p.bestStreak, 30, 2, 150),
    A('streak100', 'flames', 'sun', 'Ewige Flamme', '100 Tage in Folge gespielt', p.bestStreak, 100, 3, 400, { rewardTitle: 'Ewige Flamme' }),
    A('frozen', 'flames', 'snowflake', 'Gerettet!', 'Ein Flammenschutz rettet deine Serie', p.frozenDays.length ? 1 : 0, 1, 0, 20),
    A('chests10', 'collection', 'box', 'Truhenöffner', '10 Truhen geöffnet', p.chestsOpened, 10, 1, 20),
    A('chests50', 'collection', 'box', 'Schatzjäger', '50 Truhen geöffnet', p.chestsOpened, 50, 2, 60, { rewardTitle: 'Schatzjäger' }),
    A('chests200', 'collection', 'box', 'Schatzkönig', '200 Truhen geöffnet', p.chestsOpened, 200, 3, 200),
    A('legendary', 'collection', 'sparkles', 'Legendär!', 'Eine Legendäre Truhe geöffnet', p.legendaryChests, 1, 2, 50, { rewardFrame: 'legendary' }),
    A('collector', 'collection', 'stack3d', 'Sammler', 'Alle Karten freigeschaltet', collected, collectible.length, 3, 150, { rewardTitle: 'Sammler' }),
    A('boards', 'collection', 'checker', 'Brettsammler', 'Alle Sammelbretter besitzen', ownedBoards, boards.length, 2, 150),
    A('shards500', 'shards', 'diamond', 'Glitzer', '500 Splitter gesammelt', p.shardsEarned, 500, 1, 25),
    A('shards2000', 'shards', 'diamond', 'Kristallhort', '2000 Splitter gesammelt', p.shardsEarned, 2000, 3, 100),
    A('firstBuy', 'shards', 'bag', 'Erster Kauf', 'Schalte eine Karte mit Splittern frei', p.cardsBought, 1, 0, 20),
    A('level5', 'level', 'star', 'Level 5', 'Erreiche Level 5', lv, 5, 1, 50),
    A('level10', 'level', 'star', 'Level 10', 'Erreiche Level 10', lv, 10, 2, 100),
    A('level15', 'level', 'starCircle', 'Level 15', 'Erreiche Level 15', lv, 15, 3, 150, { rewardTitle: 'Meister' }),
    A('level20', 'level', 'starCircle', 'Level 20', 'Erreiche Level 20', lv, 20, 3, 300),
  )
  if (p === profile) achievementsCache = list
  return list
}
export const isUnlockedAchievement = (a: Achievement) => a.progress >= a.goal
export const isClaimedAchievement = (a: Achievement, p: Profile = profile) => p.claimedAchievements.includes(a.id)
export const claimableAchievements = (p: Profile = profile) => achievements(p).filter(a => isUnlockedAchievement(a) && !isClaimedAchievement(a, p))
export function claimAchievement(a: Achievement): number {
  if (!isUnlockedAchievement(a) || isClaimedAchievement(a)) return 0
  update(p => { p.claimedAchievements.push(a.id) })
  earnShards(a.shards)
  return a.shards
}
export const unlockedTitles = (p: Profile = profile) =>
  [...achievements(p).filter(isUnlockedAchievement).flatMap(a => (a.rewardTitle ? [a.rewardTitle] : [])), ...p.chestTitles]
export function unlockedFrames(p: Profile = profile): FrameId[] {
  const won = new Set(achievements(p).filter(isUnlockedAchievement).flatMap(a => (a.rewardFrame ? [a.rewardFrame] : [])))
  return (['none', 'silver', 'gold', 'flame', 'crown', 'puzzle', 'legendary', 'ruby', 'nebula', 'prism'] as FrameId[])
    .filter(f => f === 'none' || won.has(f) || p.shopFrames.includes(f))
}
/** German key of the active title (a rank or an earned title). */
export function activeTitle(p: Profile = profile): string {
  if (p.selectedTitle && unlockedTitles(p).includes(p.selectedTitle)) return p.selectedTitle
  return rankFor(levelFor(p.xp))
}
export function activeFrame(p: Profile = profile): FrameId {
  const f = p.selectedFrame as FrameId | null
  return f && unlockedFrames(p).includes(f) ? f : 'none'
}

// MARK: Saved game and replays

const GAME_KEY = 'rookraid.game.v1'
const REPLAY_KEY = 'rookraid.replays.v1'
export type SavedGame = {
  mode: GameMode; human: 'w' | 'b'; timeControl: TimeControl; decks: { w: string[]; b: string[] }; ults: { w?: string; b?: string }
  actions: string[]; clocks: { w: number; b: number }; cardsPlayedByHuman: number; startedAt: number
  mana?: { w: number; b: number }
}
export type GameMode =
  | { kind: 'bot'; bot: string } | { kind: 'ladder'; bot: string } | { kind: 'practice'; bot: string }
  | { kind: 'hotseat' } | { kind: 'tutorial' } | { kind: 'online'; matchId: string }
export type Replay = {
  id: string; date: number; title: string; subtitle: string; human: 'w' | 'b'
  decks: { w: string[]; b: string[] }; ults: { w?: string; b?: string }; actions: string[]; mana: Array<[number, number]>
  texts?: Array<{ side: 'w' | 'b'; text: string; card?: string }>
}

let hasSaved = !!localStorage.getItem(GAME_KEY)
export const hasSavedGame = () => hasSaved
export function saveGame(g: SavedGame) {
  try { localStorage.setItem(GAME_KEY, JSON.stringify(g)) } catch { /* ignore */ }
  if (!hasSaved) { hasSaved = true; listeners.forEach(fn => fn()) }
}
export function loadGame(): SavedGame | null {
  try { const raw = localStorage.getItem(GAME_KEY); return raw ? JSON.parse(raw) as SavedGame : null } catch { return null }
}
export function clearGame() {
  localStorage.removeItem(GAME_KEY)
  if (hasSaved) { hasSaved = false; version++; listeners.forEach(fn => fn()) }
}
export function replays(): Replay[] {
  try { return JSON.parse(localStorage.getItem(REPLAY_KEY) ?? '[]') as Replay[] } catch { return [] }
}
export const replayFor = (id?: string) => (id ? replays().find(r => r.id === id) ?? null : null)
export function storeReplay(r: Omit<Replay, 'id'>): string {
  const id = uid()
  const list = [{ ...r, id }, ...replays()].slice(0, 10)
  try { localStorage.setItem(REPLAY_KEY, JSON.stringify(list)) } catch { /* ignore */ }
  return id
}

export function resetProgress() {
  const settings = profile.settings
  const next = freshProfile()
  next.settings = settings
  next.tutorialSeen = true
  next.deckTourDone = true
  localStorage.removeItem(REPLAY_KEY)
  clearGame()
  commit(next)
}

export function replaceProfile(next: Profile) { commit(next) }
export { uid }

/** The default name in every language ("Du" is saved translated by the app: "You", "Tú" …). */
const DEFAULT_NAMES = new Set(['Du', 'You', 'Tú', 'Toi', 'Tu', 'Ты', '你'])
export const isDefaultName = (name: string) => !name.trim() || DEFAULT_NAMES.has(name.trim())
/** The player's name as shown: the account's name, or "You" in the chosen language. */
export const shownName = (name: string, t: (k: string) => string) => (isDefaultName(name) ? t('Du') : name)

/** History reasons of older web versions ("Schachmatt") → the texts the app uses ("durch Schachmatt"). */
const OLD_REASONS: Record<string, string> = {
  'Schachmatt': 'durch Schachmatt', 'Patt': 'durch Patt', '50-Züge-Regel': 'durch die 50-Züge-Regel',
  'Stellungswiederholung': 'durch dreifache Stellungswiederholung', 'Zeit abgelaufen': 'durch Zeitüberschreitung',
  'Aufgegeben': 'durch Aufgabe', 'Remis vereinbart': 'durch Einigung',
}
export const reasonKey = (reason: string) => OLD_REASONS[reason] ?? reason
