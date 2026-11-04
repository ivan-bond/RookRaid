import { apply, E, type MatchState, type Side } from './engine'

const LEVELS = [
  { id: 'easy', name: 'Bruno', deck: ['reinforce', 'bulwark', 'sprint', 'retreat'], ult: 'fortress' },
  { id: 'apprentice', name: 'Lotte', deck: ['lightning', 'shield', 'sprint', 'freeze'], ult: 'meteor' },
  { id: 'medium', name: 'Mila', deck: ['freeze', 'drain', 'focus', 'lightning'], ult: 'iceAge' },
  { id: 'jester', name: 'Kasimir', deck: ['swap', 'sprint', 'sacrifice', 'knighting'], ult: 'coronation' },
  { id: 'knight', name: 'Sir Konrad', deck: ['knighting', 'sprint', 'shield', 'advance'], ult: 'coronation' },
  { id: 'tactician', name: 'Frieda Falk', deck: ['shield', 'freeze', 'swap', 'sprint'], ult: 'meteor' },
  { id: 'shadow', name: 'Nox', deck: ['freeze', 'lightning', 'advance', 'sprint'], ult: 'meteor' },
  { id: 'baron', name: 'Baron Rabe', deck: ['freeze', 'advance', 'shield', 'focus'], ult: 'fortress' },
  { id: 'hard', name: 'Viktor', deck: ['freeze', 'advance', 'shield', 'focus'], ult: 'rebirth' },
  { id: 'frost', name: 'Magnus Frost', deck: ['freeze', 'advance', 'shield', 'focus'], ult: 'iceAge' },
  { id: 'sphinx', name: 'Die Sphinx', deck: ['freeze', 'advance', 'focus', 'sprint'], ult: 'rebirth' },
  { id: 'queen', name: 'Die Turmkönigin', deck: ['freeze', 'advance', 'swap', 'focus'], ult: 'iceAge' },
] as const

export type BotLevel = (typeof LEVELS)[number]

export function botForTrophies(trophies: number): BotLevel {
  return LEVELS[Math.min(LEVELS.length - 1, Math.max(0, Math.floor(trophies / 200)))]
}

export function botCard(level: BotLevel, trophies: number) {
  const rating = level === LEVELS[0] ? 100 : Math.floor(trophies / 200) * 200 + 100
  return { name: level.name, avatar: 'knight', frame: null, title: null, trophies: rating, level: 1, pieceSet: null }
}

function actionsOf(state: MatchState, col: Side): string[] {
  const out: string[] = []
  if (!state.bonus) {
    for (const card of state.decks[col].hand) {
      if (!state.canPlay(card, col)) continue
      if (E.NO_TARGET[card]) out.push('card:' + card)
      else for (const target of state.targets(card, col)) out.push(`card:${card}@${E.sqName(target)}`)
    }
    if (state.canUseUlt(col)) {
      const ult = state.ults[col]
      if (E.ultNeedsTarget(ult)) for (const target of state.ultTargets(col)) out.push(`ult:${ult}@${E.sqName(target)}`)
      else out.push('ult:' + ult)
    }
  }
  for (const move of state.allLegal(col)) {
    const code = E.uci(state, move)
    out.push(code)
    if (code.length === 5) for (const piece of ['r', 'b', 'n']) out.push(code.slice(0, 4) + piece)
  }
  return out
}

function score(state: MatchState, col: Side): number {
  const status = state.status()
  if (status === 'mate') return state.cur === col ? -100000 : 100000
  if (status === 'stalemate' || status === 'fifty' || status === 'repetition') return 0
  const opp = E.opp(col)
  let value = state.material(col) * 100
  value += (state.mana[col] - state.mana[opp]) * 8
  if (state.inCheck(opp)) value += 35
  if (state.inCheck(col)) value -= 45
  return value
}

export function bestMove(state: MatchState, col: Side, noise: number): string | null {
  let best: string | null = null
  let bestScore = -Infinity
  for (const code of actionsOf(state, col)) {
    const next = state.clone()
    if (!apply(next, code)) continue
    let value = score(next, col)
    if (next.bonus && next.cur === col && (next.status() === 'ongoing' || next.status() === 'check')) {
      const follow = bestMove(next, col, 0)
      if (follow) {
        const after = next.clone()
        if (apply(after, follow)) value = score(after, col)
      }
    }
    if (noise) value += Math.random() * noise
    if (value > bestScore) { bestScore = value; best = code }
  }
  return best
}
