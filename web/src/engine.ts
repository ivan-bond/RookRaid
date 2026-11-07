// The rules are the shared JavaScript port (Tools/rules-js), the same code the server uses to check moves.
import rules from '../../RookRaid/Engine/rookraid-rules.json'
import core from 'rookraid-rules'

export type Side = 'w' | 'b'
export type Piece = { t: string; c: Side; moved?: boolean; sh: number; fr: number }
export type Move = { f: number; t: number; promo?: string; dbl?: boolean; epc?: boolean; crf?: number; crt?: number }

export type MatchState = {
  b: (Piece | null)[]
  ply: number
  ep: number
  half: number
  mana: Record<Side, number>
  decks: Record<Side, { hand: string[]; queue: string[] }>
  ults: Record<Side, string>
  captured: Record<Side, Piece[]>
  cd: Record<Side, Record<string, number>>
  bonus: boolean
  lock: number
  peace?: boolean
  readonly cur: Side
  last: Move | null
  clone(): MatchState
  status(): 'ongoing' | 'check' | 'mate' | 'stalemate' | 'fifty' | 'repetition'
  allLegal(col: Side): Move[]
  legalMoves(i: number): Move[]
  hasAnyLegal(col: Side): boolean
  canPlay(card: string, col: Side): boolean
  cardReady(card: string, col: Side): boolean
  targets(card: string, col: Side): number[]
  canUseUlt(col: Side): boolean
  ultTargets(col: Side): number[]
  material(col: Side): number
  inCheck(col: Side): boolean
  attacked(i: number, by: Side): boolean
  controlMap(): (Side | null)[]
  territory(c: Side): number
  kingSquare(col: Side): number
  isBonusLocked(i: number): boolean
  attackSquares(i: number): number[]
}

type EngineApi = {
  State: { new (): MatchState; fromFEN(fen: string): MatchState; initial(ults: Partial<Record<Side, string>>, rng: () => number, decks: Record<Side, string[]>): MatchState }
  COST: Record<string, number>
  NO_TARGET: Record<string, number>
  CFG: Record<string, unknown> & { cooldown: Record<string, number> }
  ultCost: (u: string) => number
  ultNeedsTarget: (u: string) => boolean
  sqName: (i: number) => string
  uci: (s: MatchState, m: Move) => string
  opp: (c: Side) => Side
  detectTactic: (s: MatchState, m: Move, mover: Side) => string | null
  VALUE: Record<string, number>
}

type Port = {
  E: EngineApi
  applyRules: (rules: unknown) => unknown
  apply: (state: MatchState, code: string) => boolean
  initialFromRecord: (record: { decks: Record<string, string[]>; ultimates: Record<string, string> }) => MatchState
}

const api = ((core as { default?: Port }).default ?? core) as Port
api.applyRules(rules)

export const E = api.E
export const apply = api.apply
export const initialFromRecord = api.initialFromRecord
export const RULES_VERSION = (rules as { version: number }).version
export const MAX_MANA = (rules as { maxMana: number }).maxMana

export const sqIndex = (name: string) => (8 - Number(name[1])) * 8 + (name.charCodeAt(0) - 97)
export const sqName = (i: number) => E.sqName(i)

/** A fresh state from a position (puzzles, card school, tutorial). */
export function fromFEN(fen: string): MatchState {
  return E.State.fromFEN(fen)
}

/** Remaining own turns until a card is ready again (0 = ready). */
export function cooldownLeft(s: MatchState, card: string, col: Side): number {
  const ready = s.cd[col]?.[card]
  if (ready === undefined || s.ply >= ready) return 0
  return Math.ceil((ready - s.ply) / 2)
}

export const isShielded = (p: Piece, ply: number) => p.sh >= ply
export const isFrozen = (p: Piece, ply: number) => p.fr >= ply

/** Wire code for a move (with promotion letter). */
export const uci = (s: MatchState, m: Move) => E.uci(s, m)

/** How many pieces a fork hits – same targets as detectTactic (Tactic.fork(count:) in the app: 3+ is a "MEGA-GABEL!"). */
export function forkCount(s: MatchState, m: Move, mover: Side): number {
  const p = s.b[m.t]
  if (!p) return 0
  const o = E.opp(mover)
  return s.attackSquares(m.t).filter(t => {
    const q = s.b[t]
    if (!q || q.c !== o) return false
    if (q.t === 'k') return true
    if (E.VALUE[q.t] > E.VALUE[p.t] + 0.5) return true
    return E.VALUE[q.t] >= 3 && !s.attacked(t, o)
  }).length
}
