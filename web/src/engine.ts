import rules from '../../RookRaid/Engine/rookraid-rules.json'
import core from 'rookraid-rules'

type Port = {
  E: EngineApi
  applyRules: (rules: unknown) => unknown
  apply: (state: MatchState, code: string) => boolean
  initialFromRecord: (record: { decks: Record<string, string[]>; ultimates: Record<string, string> }) => MatchState
}

export type Side = 'w' | 'b'
export type Piece = { t: string; c: Side; moved?: boolean; sh: number; fr: number }
export type Move = { f: number; t: number; promo?: string; dbl?: boolean; epc?: boolean; crf?: number; crt?: number }

export type MatchState = {
  b: (Piece | null)[]
  ply: number
  mana: Record<Side, number>
  decks: Record<Side, { hand: string[]; queue: string[] }>
  ults: Record<Side, string>
  bonus: boolean
  cur: Side
  last: Move | null
  clone(): MatchState
  status(): string
  allLegal(col: Side): Move[]
  legalMoves(i: number): Move[]
  canPlay(card: string, col: Side): boolean
  targets(card: string, col: Side): number[]
  canUseUlt(col: Side): boolean
  ultTargets(col: Side): number[]
  material(col: Side): number
  inCheck(col: Side): boolean
  controlMap(): (Side | null)[]
  kingSquare(col: Side): number
}

type EngineApi = {
  COST: Record<string, number>
  NO_TARGET: Record<string, number>
  ultCost: (u: string) => number
  ultNeedsTarget: (u: string) => boolean
  sqName: (i: number) => string
  uci: (s: MatchState, m: Move) => string
  opp: (c: Side) => Side
}

const api = ((core as { default?: Port }).default ?? core) as Port
api.applyRules(rules)

export const E = api.E
export const apply = api.apply
export const initialFromRecord = api.initialFromRecord

export const RULES_VERSION = (rules as { version: number }).version

export const CARDS = [
  'lightning', 'shield', 'sprint', 'freeze',
  'reinforce', 'knighting', 'bulwark', 'advance', 'retreat',
  'revive', 'sacrifice', 'swap',
  'focus', 'drain', 'bishopize',
] as const

export const STARTER_CARDS = ['lightning', 'shield', 'sprint', 'freeze']
export const ULTS = ['meteor', 'fortress', 'iceAge', 'coronation', 'rebirth'] as const

export const CARD_NAME: Record<string, string> = {
  shield: 'Schild', freeze: 'Frost', bulwark: 'Bollwerk', sprint: 'Sturmlauf',
  lightning: 'Blitz', knighting: 'Ritterschlag', reinforce: 'Verstärkung', revive: 'Wiederkehr',
  bishopize: 'Läuferweihe', advance: 'Vormarsch', swap: 'Leibwache', drain: 'Manaraub',
  focus: 'Konzentration', sacrifice: 'Bauernopfer', retreat: 'Rückzug',
  meteor: 'Meteor', iceAge: 'Eiszeit', fortress: 'Festung', coronation: 'Krönung', rebirth: 'Wiedergeburt',
}

const art = import.meta.glob('../../RookRaid/Assets.xcassets/CardArtPainted/**/*.jpg', {
  eager: true, import: 'default', query: '?url',
}) as Record<string, string>

export function cardArt(id: string): string | undefined {
  const file = id === 'meteor' || id === 'iceAge' || id === 'fortress' || id === 'coronation' || id === 'rebirth'
    ? `painted-art-ult-${id}.jpg`
    : `painted-art-card-${id}.jpg`
  return Object.entries(art).find(([path]) => path.endsWith('/' + file))?.[1]
}

export function ultMinArena(id: string): number {
  if (id === 'iceAge' || id === 'coronation') return 2
  if (id === 'rebirth') return 3
  return 1
}

export function arenaOf(trophies: number): number {
  if (trophies >= 2100) return 6
  if (trophies >= 1200) return 5
  if (trophies >= 600) return 4
  if (trophies >= 240) return 3
  if (trophies >= 90) return 2
  return 1
}

export function sq(i: number): string {
  return E.sqName(i)
}

export const GLYPH: Record<string, string> = {
  wk: '♔', wq: '♕', wr: '♖', wb: '♗', wn: '♘', wp: '♙',
  bk: '♚', bq: '♛', br: '♜', bb: '♝', bn: '♞', bp: '♟',
}
