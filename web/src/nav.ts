// Which tab is shown and which full-screen views and sheets are open (the NotificationCenter routes of the app).
import { useSyncExternalStore } from 'react'
import type { GameController } from './game/controller'
import type { Chest, Puzzle } from './game/store'

export type Tab = 'arena' | 'puzzles' | 'play' | 'deck' | 'profile'
export type SheetId =
  | 'settings' | 'chestHub' | 'ladder' | 'shop' | 'flame' | 'achievements' | 'style' | 'stats' | 'feedback' | 'rules' | 'presets' | 'ultimates'
  | 'name' | 'onlineName' | 'language' | 'legal-privacy' | 'legal-imprint' | 'legal-terms' | 'legal-support' | 'roadGuide'
  | 'friends' | 'friendProfile'
export type Overlay =
  | { kind: 'game'; game: GameController }
  | { kind: 'puzzle'; puzzle: Puzzle; daily: boolean }
  | { kind: 'rush' }
  | { kind: 'lab'; key: string }
  | { kind: 'replay'; id: string }
  | { kind: 'matchmaking' }
  | { kind: 'intro' }

type NavState = {
  tab: Tab
  overlay: Overlay | null
  sheet: SheetId | null
  sheetArg: unknown
  chests: { first: Chest; only: Set<string> | null } | null
}

let state: NavState = { tab: 'play', overlay: null, sheet: null, sheetArg: null, chests: null }
const listeners = new Set<() => void>()
function set(patch: Partial<NavState>) { state = { ...state, ...patch }; listeners.forEach(fn => fn()) }

export const getNav = () => state
export function useNav(): NavState {
  return useSyncExternalStore(fn => { listeners.add(fn); return () => listeners.delete(fn) }, () => state)
}
export const setTab = (tab: Tab) => { if (state.tab !== tab) set({ tab }) }
export const openOverlay = (overlay: Overlay) => set({ overlay, sheet: null })
export const closeOverlay = () => set({ overlay: null })
export const openSheet = (sheet: SheetId, arg: unknown = null) => set({ sheet, sheetArg: arg })
export const closeSheet = () => set({ sheet: null, sheetArg: null })
/** Open chests one after another. `only`: just these (the ones a match earned). */
export const openChests = (first: Chest, only: Set<string> | null = null) => set({ chests: { first, only } })
export const closeChests = () => set({ chests: null })

/** Small event bus for the actions other screens trigger (start battle, open ladder, …). */
type Action = 'quickBattle' | 'openLadder' | 'startHotSeat' | 'startTutorial' | 'startPractice' | 'openPendingChest' | 'dailyPuzzle'
const actions = new Map<Action, () => void>()
export const onAction = (a: Action, fn: () => void) => { actions.set(a, fn); return () => { if (actions.get(a) === fn) actions.delete(a) } }
export const run = (a: Action) => actions.get(a)?.()

/** A running online match the player left (back button). It can be reopened from the Play tab. */
let parked: GameController | null = null
export const parkGame = (g: GameController | null) => { parked = g; set({}) }
export const parkedGame = () => (parked?.canResumeOnline ? parked : null)
