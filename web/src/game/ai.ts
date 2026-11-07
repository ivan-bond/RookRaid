// Port of AI.swift (AIPlayer): iterative deepening with alpha-beta, quiescence search, killer/history ordering,
// a transposition table and opponent card replies one level below the root. Same evaluation (v1/v2), same per-bot
// profiles (catalog.ts, BotProfile in the app), same noise, blunders and repetition handling.
import { E, type MatchState, type Move, type Side } from '../engine'

export type SearchProfile = {
  depth: number; deepProb: number; qDepth: number; qProb: number; noise: number; blunder: number; nodes: number; time: number
  cardSkill: number; targetLimit: number; smart: boolean; v2: boolean; replies: boolean; v3: boolean; tt: boolean
}

type S = MatchState & {
  pseudoMoves(i: number): Move[]
  fastClone(): S
  makeMove(m: Move): void
  playCard(card: string, hi: number, t: number): void
  useUlt(t: number): void
  key(): string
  hist: string[] | null
  ep: number
}

const VALUE: Record<string, number> = { k: 0, q: 9, r: 5, b: 3.2, n: 3, p: 1 }
const opp = (c: Side): Side => (c === 'w' ? 'b' : 'w')
const fwd = (c: Side) => (c === 'w' ? -1 : 1)
const homeRow = (c: Side) => (c === 'w' ? 7 : 0)
const rankOf = (c: Side, i: number) => (c === 'w' ? 8 - (i >> 3) : (i >> 3) + 1)
const promoRow = (c: Side) => (c === 'w' ? 0 : 7)

class Abort extends Error {}

// MARK: Transposition table (Zobrist keys as two 32-bit halves)

const TT_BITS = 18, TT_SIZE = 1 << TT_BITS, TT_MASK = TT_SIZE - 1
const Z_SIDE = 16 * 64, Z_BONUS = Z_SIDE + 1, Z_EP = Z_SIDE + 2
const ZOB_LO = new Int32Array(Z_EP + 1), ZOB_HI = new Int32Array(Z_EP + 1)
{
  let x = 0x9e3779b9 | 0, y = 0x7f4a7c15 | 0
  for (let i = 0; i < ZOB_LO.length; i++) {
    x ^= x << 13; x ^= x >>> 17; x ^= x << 5
    y ^= y << 13; y ^= y >>> 17; y ^= y << 5
    ZOB_LO[i] = x; ZOB_HI[i] = y
  }
}
class TT {
  lo = new Int32Array(TT_SIZE); hi = new Int32Array(TT_SIZE); depths = new Int8Array(TT_SIZE).fill(-1)
  values = new Float64Array(TT_SIZE); flags = new Uint8Array(TT_SIZE); moves = new Int16Array(TT_SIZE).fill(-1)
}
let sharedTT: TT | null = null

function hash(s: S): [number, number] {
  let lo = 0, hi = 0
  for (let i = 0; i < 64; i++) {
    const p = s.b[i]
    if (!p) continue
    let k = 'pnbrqk'.indexOf(p.t)
    if (p.c === 'b') k += 6
    if (p.fr >= s.ply) k = p.c === 'w' ? 12 : 14
    else if (p.sh >= s.ply) k = p.c === 'w' ? 13 : 15
    const j = k * 64 + i
    lo ^= ZOB_LO[j]; hi ^= ZOB_HI[j]
    if ((p.t === 'k' || p.t === 'r') && !p.moved) { lo ^= Math.imul(ZOB_LO[j], 31) + 7; hi ^= ZOB_HI[j] >>> 3 }
  }
  if (s.ply & 1) { lo ^= ZOB_LO[Z_SIDE]; hi ^= ZOB_HI[Z_SIDE] }
  if (s.bonus) { lo ^= ZOB_LO[Z_BONUS]; hi ^= ZOB_HI[Z_BONUS] }
  if (s.ep >= 0) { lo ^= (ZOB_LO[Z_EP] + s.ep) | 0; hi ^= ZOB_HI[Z_EP] }
  return [lo, hi]
}

// MARK: Context

class Ctx {
  nodes = 0
  killers = new Map<number, number>()
  killers2 = new Map<number, number>()
  history = new Int32Array(4096)
  tt: TT | null
  maxPly: number
  constructor(public nodeLimit: number, public deadline: number, public qDepth: number, public p: SearchProfile) {
    this.maxPly = p.depth + 6
    if (p.tt) {
      sharedTT ??= new TT()
      sharedTT.depths.fill(-1)
      this.tt = sharedTT
    } else this.tt = null
  }
  tick() {
    this.nodes++
    if ((this.nodes & 255) === 0 && (this.nodes > this.nodeLimit || performance.now() > this.deadline)) throw new Abort()
  }
}

const code = (m: Move) => m.f * 64 + m.t
const same = (a: Move, b: number | undefined) => b !== undefined && code(a) === b

// MARK: Decide

type Root = { code: string; child: S; bonus: number; isMove: boolean }

/** One action for the side to move, as a wire code. `maxSeconds` comes from the clock (as in the app). */
export function decide(state: MatchState, p: SearchProfile, maxSeconds?: number): string | null {
  const s = state as S
  const seconds = Math.max(0.3, Math.min(p.time, maxSeconds ?? p.time))
  const me = s.cur
  let depthCap = p.depth
  if (depthCap > 1 && Math.random() > p.deepProb) depthCap--
  let q = p.qDepth
  if (q > 0 && Math.random() > p.qProb) q--
  const start = performance.now()
  const ctx = new Ctx(p.nodes, start + seconds * 1000, q, p)

  let actions = rootActions(s, p)
  if (!actions.length) return null
  let completed: Array<{ a: Root; score: number }> = []
  let partial: Array<{ a: Root; score: number }> = []
  try {
    for (let d = 1; d <= Math.max(1, depthCap); d++) {
      const scored: Array<{ a: Root; score: number }> = []
      partial = []
      let alpha = -Infinity
      const margin = p.noise + 0.05
      for (const a of actions) {
        const sc = score(a, me, d, alpha - margin, ctx) + a.bonus
        scored.push({ a, score: sc })
        partial = scored.slice()
        if (sc > alpha) alpha = sc
      }
      completed = scored.sort((x, y) => y.score - x.score)
      actions = completed.map(x => x.a)
      if (Math.abs(completed[0].score) > 9000) break
      const elapsed = (performance.now() - start) / 1000
      if (elapsed > seconds * 0.45 || ctx.nodes > p.nodes * 0.3) break
    }
  } catch (e) {
    if (!(e instanceof Abort)) throw e
    if (p.v3 && partial.length && completed.length) completed = partial.sort((x, y) => y.score - x.score)
  }
  if (!completed.length) return actions[0]?.code ?? null

  // Repetitions: the side ahead avoids them, the side behind welcomes them.
  if (s.hist && s.hist.length) {
    const lead = completed[0].score
    const seen = new Set(s.hist)
    completed = completed.map(item => {
      if (!item.a.isMove || !seen.has(item.a.child.key())) return item
      return { a: item.a, score: item.score + (lead > 0.5 ? -0.8 : lead < -0.5 ? 0.4 : 0) }
    }).sort((x, y) => y.score - x.score)
  }
  let pick = completed[0]
  if (p.noise > 0) {
    let best = -Infinity
    for (const item of completed) {
      const v = item.score + Math.random() * p.noise
      if (v > best) { best = v; pick = item }
    }
  }
  if (p.blunder > 0 && Math.random() < p.blunder) {
    const moves = completed.filter(x => x.a.isMove)
    if (moves.length) pick = moves[Math.floor(Math.random() * moves.length)]
  }
  return pick.a.code
}

function rootActions(s: S, p: SearchProfile): Root[] {
  const me = s.cur
  const out: Root[] = []
  for (const m of ordered(s.allLegal(me), s)) {
    const c = s.clone() as S
    const wire = E.uci(s, m)
    c.makeMove({ ...m, promo: wire.length === 5 ? wire[4] : m.promo })
    out.push({ code: wire, child: c, bonus: 0, isMove: true })
  }
  if (s.bonus) return out
  const hand = s.decks[me]?.hand ?? []
  hand.forEach((card, i) => {
    if (Math.random() > p.cardSkill) return
    if (!s.canPlay(card, me)) return
    let all: number[] = E.NO_TARGET[card] ? [-1] : s.targets(card, me)
    if (!p.smart) all = shuffle(all).slice(0, p.targetLimit)
    for (const t of all) {
      const c = s.clone() as S
      c.playCard(card, i, t)
      out.push({ code: 'card:' + card + (t >= 0 ? '@' + E.sqName(t) : ''), child: c, bonus: KEEPS[card] ? -0.15 : -0.1, isMove: false })
    }
  })
  if (s.canUseUlt(me)) {
    const u = s.ults[me]
    const list = s.ultTargets(me)
    for (const t of list.length ? list : [-1]) {
      const c = s.clone() as S
      c.useUlt(t)
      out.push({ code: 'ult:' + u + (t >= 0 ? '@' + E.sqName(t) : ''), child: c, bonus: 0, isMove: false })
    }
  }
  return out
}
const KEEPS: Record<string, boolean> = { shield: true, freeze: true, bulwark: true, sprint: true, sacrifice: true, advance: true, swap: true, retreat: true }

function shuffle<T>(a: T[]): T[] {
  const b = a.slice()
  for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [b[i], b[j]] = [b[j], b[i]] }
  return b
}

function score(a: Root, me: Side, depth: number, alpha: number, ctx: Ctx): number {
  const c = a.child
  if (c.cur === me) {
    // Bonus card: we move again – best follow-up at the same depth.
    let best = -Infinity
    for (const m of ordered(c.allLegal(me), c)) {
      const g = c.fastClone()
      g.makeMove(m)
      const v = -negamax(g, depth - 1, -Infinity, -Math.max(alpha, best), 1, ctx)
      if (v > best) best = v
    }
    return best
  }
  return -negamax(c, depth - 1, -Infinity, -alpha, 1, ctx)
}

function negamax(s: S, depth: number, alpha: number, beta: number, ply: number, ctx: Ctx): number {
  ctx.tick()
  const me = s.cur
  const inCheck = ctx.p.v3 ? s.inCheck(me) : false
  if (depth <= 0 && inCheck && ply < ctx.maxPly) depth = 1
  if (depth <= 0) {
    if (ctx.qDepth > 0) return quiesce(s, alpha, beta, ctx.qDepth, ctx)
    const t = leafTerminal(s)
    return t ?? evaluate(s, me, ctx)
  }
  const alpha0 = alpha
  let best = -Infinity
  let anyLegal = false
  let slot = -1, klo = 0, khi = 0, ttMove = -1
  const tt = ctx.tt
  if (tt && ply > 1) {
    ;[klo, khi] = hash(s)
    slot = (klo ^ (khi << 7)) & TT_MASK
    if (tt.lo[slot] === klo && tt.hi[slot] === khi && tt.depths[slot] >= 0) {
      ttMove = tt.moves[slot]
      if (tt.depths[slot] >= depth && Math.abs(tt.values[slot]) < 9000) {
        const v = tt.values[slot]
        const f = tt.flags[slot]
        if (f === 0) return v
        if (f === 1 && v >= beta) return v
        if (f === 2 && v <= alpha) return v
      }
    }
  }
  let moves: Move[]
  if (ctx.p.v3) moves = orderedV3(pseudoAll(s, me), s, ply, ctx, ttMove)
  else {
    moves = ordered(pseudoAll(s, me), s)
    const k = ctx.killers.get(ply)
    if (k !== undefined) {
      const i = moves.findIndex(m => code(m) === k)
      if (i > 0 && !s.b[moves[i].t]) moves.unshift(moves.splice(i, 1)[0])
    }
  }
  let bestMove = -1
  for (const m of moves) {
    const quiet = !s.b[m.t] && !m.epc
    const child = s.fastClone()
    child.makeMove(m)
    if (child.inCheck(me)) continue
    anyLegal = true
    const sc = -negamax(child, depth - 1, -beta, -alpha, ply + 1, ctx)
    if (sc > best) { best = sc; bestMove = code(m) }
    if (best > alpha) alpha = best
    if (alpha >= beta) {
      if (quiet) {
        if (ctx.p.v3) {
          if (ctx.killers.get(ply) !== code(m)) {
            const k1 = ctx.killers.get(ply)
            if (k1 !== undefined) ctx.killers2.set(ply, k1)
            ctx.killers.set(ply, code(m))
          }
          ctx.history[code(m)] += depth * depth
        } else ctx.killers.set(ply, code(m))
      }
      break
    }
  }
  if (!anyLegal) return s.inCheck(me) ? -10000 - depth : 0
  // Opponent cards and ultimate as replies – only right below the root, with a few targets.
  if (ply === 1 && ctx.p.replies && !s.bonus && alpha < beta) {
    for (const child of cardChildren(s, me, 3)) {
      const sc = child.cur === me
        ? negamax(child, depth, alpha, beta, ply + 1, ctx) - 0.1
        : -negamax(child, depth - 1, -beta, -alpha, ply + 1, ctx) - 0.1
      if (sc > best) best = sc
      if (best > alpha) alpha = best
      if (alpha >= beta) break
    }
  }
  if (tt && slot >= 0) {
    tt.lo[slot] = klo; tt.hi[slot] = khi
    tt.depths[slot] = Math.min(127, depth)
    tt.values[slot] = best
    tt.moves[slot] = bestMove
    tt.flags[slot] = best <= alpha0 ? 2 : best >= beta ? 1 : 0
  }
  return best
}

function orderedV3(moves: Move[], s: S, ply: number, ctx: Ctx, ttMove: number): Move[] {
  const k1 = ctx.killers.get(ply), k2 = ctx.killers2.get(ply)
  return moves.map(m => {
    const c = code(m)
    const v = s.b[m.t]
    let sc: number
    if (c === ttMove) sc = 5000
    else if (v) sc = 1000 + VALUE[v.t] * 10 - (s.b[m.f] ? VALUE[s.b[m.f]!.t] : 0)
    else if (m.epc) sc = 1001
    else if (same(m, k1)) sc = 900
    else if (same(m, k2)) sc = 890
    else sc = Math.min(800, ctx.history[c])
    return [m, sc] as const
  }).sort((a, b) => b[1] - a[1]).map(x => x[0])
}

function cardChildren(s: S, me: Side, limit: number): S[] {
  const out: S[] = []
  const best = (sq: number[]) => sq.length <= limit ? sq : sq.slice().sort((a, b) => (s.b[b] ? VALUE[s.b[b]!.t] : 0) - (s.b[a] ? VALUE[s.b[a]!.t] : 0)).slice(0, limit)
  const hand = s.decks[me]?.hand ?? []
  hand.forEach((card, i) => {
    if (!s.canPlay(card, me)) return
    for (const t of E.NO_TARGET[card] ? [-1] : best(s.targets(card, me))) {
      const c = s.fastClone()
      c.playCard(card, i, t)
      out.push(c)
    }
  })
  if (s.canUseUlt(me)) {
    const list = best(s.ultTargets(me))
    for (const t of list.length ? list : [-1]) {
      const c = s.fastClone()
      c.useUlt(t)
      out.push(c)
    }
  }
  return out
}

function quiesce(s: S, alpha: number, beta: number, depth: number, ctx: Ctx): number {
  ctx.tick()
  const t = leafTerminal(s)
  if (t !== null) return t
  const me = s.cur
  const stand = evaluate(s, me, ctx)
  if (depth <= 0 || stand >= beta) return stand
  alpha = Math.max(alpha, stand)
  const captures = pseudoAll(s, me).filter(m => s.b[m.t] || m.epc)
  for (const m of ordered(captures, s)) {
    const child = s.fastClone()
    child.makeMove(m)
    if (child.inCheck(me)) continue
    const sc = -quiesce(child, -beta, -alpha, depth - 1, ctx)
    if (sc >= beta) return sc
    if (sc > alpha) alpha = sc
  }
  return alpha
}

function leafTerminal(s: S): number | null {
  const me = s.cur
  for (let i = 0; i < 64; i++) { const p = s.b[i]; if (p && p.c === me && p.t !== 'k' && p.t !== 'p') return null }
  if (s.hasAnyLegal(me)) return null
  return s.inCheck(me) ? -10000 : 0
}

function pseudoAll(s: S, c: Side): Move[] {
  let out: Move[] = []
  for (let i = 0; i < 64; i++) if (s.b[i]?.c === c) out = out.concat(s.pseudoMoves(i))
  return out
}

function ordered(moves: Move[], s: S): Move[] {
  return moves.map(m => [m, orderScore(m, s)] as const).sort((a, b) => b[1] - a[1]).map(x => x[0])
}
function orderScore(m: Move, s: S): number {
  const victim = s.b[m.t]
  if (!victim) {
    if (m.epc) return 1
    const p = s.b[m.f]
    if (p && p.t === 'p' && (m.t >> 3) === promoRow(p.c)) return 8
    return 0
  }
  return VALUE[victim.t] * 10 - (s.b[m.f] ? VALUE[s.b[m.f]!.t] : 0)
}

// MARK: Evaluation (GameState.evaluate / evaluateV2)

function evaluate(s: S, color: Side, ctx: Ctx): number {
  return ctx.p.v2 ? evaluateV2(s, color) : evaluateV1(s, color)
}

export function evaluateV1(s: MatchState, color: Side): number {
  let score = 0
  for (let i = 0; i < 64; i++) {
    const p = s.b[i]
    if (!p) continue
    const row = i >> 3, col = i & 7
    let v = VALUE[p.t]
    const cd = Math.abs(3.5 - row) + Math.abs(3.5 - col)
    if (p.t === 'n' || p.t === 'b') v += (7 - cd) * 0.04
    else if (p.t === 'p') v += (rankOf(p.c, i) - 2) * 0.06
    else if (p.t === 'q') v += (7 - cd) * 0.01
    else if (p.t === 'k') v += p.moved && Math.abs(col - 4) <= 1 ? -0.2 : 0
    if (p.fr >= s.ply) v -= 0.2
    score += p.c === color ? v : -v
  }
  score += (s.mana[color] - s.mana[opp(color)]) * 0.12
  return score
}

function evaluateV2(s: MatchState, color: Side): number {
  let score = evaluateV1(s, color)
  score += kingSafety(s, color) - kingSafety(s, opp(color))
  if (s.ply < 24) {
    for (const c of ['w', 'b'] as Side[]) {
      let undeveloped = 0
      const r = homeRow(c)
      for (let col = 0; col < 8; col++) { const p = s.b[r * 8 + col]; if (p && p.c === c && (p.t === 'n' || p.t === 'b')) undeveloped++ }
      score += (c === color ? -1 : 1) * undeveloped * 0.08
    }
  }
  let mat = 0
  for (const p of s.b) if (p) mat += p.c === color ? VALUE[p.t] : -VALUE[p.t]
  if (Math.abs(mat) >= 4) {
    const winner = mat > 0 ? color : opp(color)
    const loser = opp(winner)
    const loserPieces = s.b.filter(p => p && p.c === loser && p.t !== 'k' && p.t !== 'p').length
    const lk = s.kingSquare(loser), wk = s.kingSquare(winner)
    if (loserPieces <= 1 && lk >= 0 && wk >= 0) {
      const edge = Math.abs(3.5 - (lk >> 3)) + Math.abs(3.5 - (lk & 7))
      const dist = Math.abs((lk >> 3) - (wk >> 3)) + Math.abs((lk & 7) - (wk & 7))
      const bonus = edge * 0.12 + (14 - dist) * 0.06
      score += winner === color ? bonus : -bonus
    }
  }
  const o = opp(color)
  const uo = s.ults[o], um = s.ults[color]
  if (uo && s.mana[o] >= E.ultCost(uo)) score -= uo === 'meteor' ? 1.6 : 0.8
  if (um && s.mana[color] >= E.ultCost(um)) score += um === 'meteor' ? 1.2 : 0.6
  return score
}

function kingSafety(s: MatchState, color: Side): number {
  const k = s.kingSquare(color)
  if (k < 0) return 0
  const kr = k >> 3, kc = k & 7, f = fwd(color)
  let shield = 0
  for (let dc = -1; dc <= 1; dc++) {
    for (const dr of [f, 2 * f]) {
      const r = kr + dr, c = kc + dc
      if (r < 0 || r > 7 || c < 0 || c > 7) continue
      const p = s.b[r * 8 + c]
      if (p && p.t === 'p' && p.c === color) { shield += dr === f ? 0.12 : 0.06; break }
    }
  }
  let danger = 0
  for (let i = 0; i < 64; i++) {
    const p = s.b[i]
    if (!p || p.c === color || p.t === 'p' || p.t === 'k') continue
    if (Math.max(Math.abs((i >> 3) - kr), Math.abs((i & 7) - kc)) <= 2) danger += p.t === 'q' ? 0.25 : 0.1
  }
  const castled = (kc >= 6 || kc <= 2) && kr === homeRow(color) ? 0.25 : 0
  return shield + castled - danger
}
