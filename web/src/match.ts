import { bestMove } from './bot'
import { apply, E, initialFromRecord, type MatchState, type Side } from './engine'
import {
  answerDraw, claimTimeout, fetchActions, finishBot, heartbeat, matchStatus, offerDraw, resignMatch, submitAction,
  type OnlineStart,
} from './online'
import { refreshAccount } from './profile'
import { translate } from './i18n'

export type Kind = 'practice' | 'hotseat' | 'online'

type Clock = { w: number; b: number; mark: number; start: number }

export class Match {
  state: MatchState
  actions: string[] = []
  kind: Kind
  human: Side
  onlineBot = false
  matchId: string | null = null
  opponentName: string
  selected: number | null = null
  aiming: 'card' | 'ult' | null = null
  card: string | null = null
  promo: { from: number; to: number } | null = null
  thinking = false
  busy = false
  note = ''
  overTitle = ''
  overDetail = ''
  burst: number | null = null
  askResign = false
  drawFrom: Side | null = null
  clocks: Clock | null = null
  version = 0
  private reported = false
  private started = false
  private botTimer = 0
  private timers: number[] = []
  private listeners = new Set<() => void>()
  private opening: { decks: { white: string[]; black: string[] }; ultimates: { white: string; black: string } }

  constructor(opts: {
    kind: Kind
    human: Side
    decks: { white: string[]; black: string[] }
    ultimates: { white: string; black: string }
    opponentName: string
    online?: OnlineStart
  }) {
    this.kind = opts.kind
    this.human = opts.human
    this.opponentName = opts.opponentName
    this.opening = { decks: opts.decks, ultimates: opts.ultimates }
    this.state = initialFromRecord({
      decks: { white: opts.decks.white, black: opts.decks.black },
      ultimates: { white: opts.ultimates.white, black: opts.ultimates.black },
    })
    if (opts.online) {
      this.matchId = opts.online.matchId
      this.onlineBot = opts.online.bot
      this.clocks = {
        w: opts.online.clockWhiteMs,
        b: opts.online.clockBlackMs,
        mark: Date.now(),
        start: opts.online.startedAt,
      }
    }
  }

  subscribe = (fn: () => void) => {
    this.listeners.add(fn)
    return () => this.listeners.delete(fn)
  }

  start() {
    if (this.started) return
    this.started = true
    this.maybeBot()
    if (!this.matchId) return
    this.timers.push(window.setInterval(() => { void this.pulse() }, 2000))
    this.timers.push(window.setInterval(() => { void heartbeat(this.matchId!) }, 10_000))
    void heartbeat(this.matchId)
  }

  stop() {
    this.started = false
    window.clearTimeout(this.botTimer)
    this.timers.forEach(id => window.clearInterval(id))
    this.timers = []
  }

  dismissResign() {
    this.askResign = false
    this.emit()
  }

  private emit() {
    this.version++
    this.listeners.forEach(fn => fn())
  }

  orientation(): Side {
    return this.kind === 'hotseat' ? this.state.cur : this.human
  }

  myTurn(): boolean {
    if (this.overTitle || this.thinking || this.busy) return false
    if (this.clocks && Date.now() < this.clocks.start) return false
    if (this.kind === 'hotseat') return true
    return this.state.cur === this.human
  }

  introLeft(): number {
    if (!this.clocks) return 0
    return Math.max(0, Math.ceil((this.clocks.start - Date.now()) / 1000))
  }

  remaining(side: Side): number {
    if (!this.clocks) return 0
    const now = Date.now()
    let ms = this.clocks[side]
    if (now >= this.clocks.start && this.state.cur === side && !this.overTitle) {
      ms -= now - Math.max(this.clocks.mark, this.clocks.start)
    }
    return Math.max(0, ms)
  }

  tick() {
    if (!this.clocks || this.overTitle) return
    const now = Date.now()
    if (now < this.clocks.start) { this.emit(); return }
    const side = this.state.cur
    if (this.remaining(side) <= 0) {
      this.clocks[side] = 0
      void this.onFlag(side)
      return
    }
    this.emit()
  }

  targets(): number[] {
    if (!this.myTurn()) return []
    const col = this.state.cur
    if (this.aiming === 'card' && this.card) return this.state.targets(this.card, col)
    if (this.aiming === 'ult') return this.state.ultTargets(col)
    if (this.selected != null) return this.state.legalMoves(this.selected).map(move => move.t)
    return []
  }

  clickSquare(index: number) {
    if (!this.myTurn() || this.promo) return
    const col = this.state.cur
    if (this.aiming === 'card' && this.card) {
      if (this.state.targets(this.card, col).includes(index)) void this.commit(`card:${this.card}@${E.sqName(index)}`)
      else this.clearAim()
      return
    }
    if (this.aiming === 'ult') {
      if (this.state.ultTargets(col).includes(index)) void this.commit(`ult:${this.state.ults[col]}@${E.sqName(index)}`)
      else this.clearAim()
      return
    }
    const moves = this.selected != null ? this.state.legalMoves(this.selected).filter(move => move.t === index) : []
    if (moves.length && this.selected != null) {
      const piece = this.state.b[this.selected]
      const promoRow = piece?.c === 'w' ? 0 : 7
      if (piece?.t === 'p' && (index >> 3) === promoRow) {
        this.promo = { from: this.selected, to: index }
        this.emit()
        return
      }
      void this.commit(E.uci(this.state, moves[0]))
      return
    }
    const piece = this.state.b[index]
    this.aiming = null
    this.card = null
    this.selected = piece && piece.c === col && this.state.legalMoves(index).length ? index : null
    this.emit()
  }

  clickCard(id: string) {
    if (!this.myTurn() || this.state.bonus) return
    const col = this.state.cur
    if (!this.state.canPlay(id, col)) return
    if (E.NO_TARGET[id]) { void this.commit('card:' + id); return }
    this.selected = null
    this.aiming = this.card === id && this.aiming === 'card' ? null : 'card'
    this.card = this.aiming === 'card' ? id : null
    this.emit()
  }

  clickUlt() {
    if (!this.myTurn() || this.state.bonus || !this.state.canUseUlt(this.state.cur)) return
    const ult = this.state.ults[this.state.cur]
    if (!E.ultNeedsTarget(ult)) { void this.commit('ult:' + ult); return }
    this.selected = null
    this.card = null
    this.aiming = this.aiming === 'ult' ? null : 'ult'
    this.emit()
  }

  choosePromo(piece: string) {
    if (!this.promo) return
    const code = E.sqName(this.promo.from) + E.sqName(this.promo.to) + piece
    this.promo = null
    void this.commit(code)
  }

  private clearAim() {
    this.aiming = null
    this.card = null
    this.selected = null
    this.emit()
  }

  private async commit(code: string) {
    if (this.busy || this.overTitle) return
    if (this.matchId && !this.onlineBot) {
      this.busy = true
      this.emit()
      try { await submitAction(this.matchId, this.actions.length, code) }
      catch (error) {
        this.busy = false
        this.note = error instanceof Error ? error.message : 'Keine Verbindung zum Server.'
        this.emit()
        return
      }
      this.busy = false
    }
    this.spendClock()
    if (!apply(this.state, code)) { this.note = '…'; this.emit(); return }
    this.actions.push(code)
    this.selected = null
    this.aiming = null
    this.card = null
    this.promo = null
    this.note = ''
    this.afterLocal()
  }

  private spendClock() {
    if (!this.clocks) return
    const now = Date.now()
    if (now < this.clocks.start) { this.clocks.mark = this.clocks.start; return }
    const side = this.state.cur
    this.clocks[side] = Math.max(0, this.clocks[side] - (now - Math.max(this.clocks.mark, this.clocks.start)))
    this.clocks.mark = now
  }

  private afterLocal() {
    const status = this.state.status()
    if (status === 'mate' || status === 'stalemate' || status === 'fifty' || status === 'repetition') {
      this.finishLocal(status)
      return
    }
    this.emit()
    this.maybeBot()
  }

  private maybeBot() {
    if (this.overTitle || this.kind === 'hotseat') return
    if (this.kind === 'online' && !this.onlineBot) return
    if (this.state.cur === this.human) return
    this.thinking = true
    this.emit()
    window.clearTimeout(this.botTimer)
    this.botTimer = window.setTimeout(() => {
      if (this.overTitle) return
      const noise = this.kind === 'practice' ? 18 : 6
      const code = bestMove(this.state, this.state.cur, noise)
      if (!code) { this.thinking = false; this.emit(); return }
      this.spendClock()
      apply(this.state, code)
      this.actions.push(code)
      if (!this.overTitle && this.state.bonus && this.state.cur !== this.human) {
        const follow = bestMove(this.state, this.state.cur, noise)
        if (follow) {
          apply(this.state, follow)
          this.actions.push(follow)
        }
      }
      this.thinking = false
      this.afterLocal()
    }, 450)
  }

  resign() {
    if (this.overTitle) return
    if (!this.askResign) { this.askResign = true; this.emit(); return }
    this.askResign = false
    const loser: Side = this.kind === 'hotseat' ? this.state.cur : this.human
    if (this.matchId && !this.onlineBot) void resignMatch(this.matchId).catch(() => undefined)
    this.burst = this.state.kingSquare(loser)
    this.overTitle = translate('AUFGEGEBEN!')
    this.overDetail = translate('Dein König platzt!')
    this.emit()
    void this.report('resigned', loser === this.human)
  }

  async sendDraw() {
    if (!this.matchId || this.onlineBot) return
    await offerDraw(this.matchId)
  }

  async replyDraw(accept: boolean) {
    if (!this.matchId) return
    await answerDraw(this.matchId, accept)
    this.drawFrom = null
    this.emit()
    void this.pulse()
  }

  private async onFlag(side: Side) {
    if (this.overTitle) return
    if (this.matchId && !this.onlineBot) {
      try { await claimTimeout(this.matchId) } catch { /* the poll reads the result */ }
      await this.pulse()
      return
    }
    const loser = side
    this.burst = this.state.kingSquare(loser)
    this.overTitle = translate('ZEIT UM!')
    const humanLost = loser === this.human && this.kind !== 'hotseat'
    this.overDetail = translate(humanLost ? 'Dein König platzt!' : 'Der König platzt!')
    this.emit()
    void this.report(humanLost ? 'timeout' : 'final', humanLost)
  }

  private finishLocal(status: string) {
    const titles: Record<string, string> = {
      mate: 'SCHACHMATT', stalemate: 'Patt', fifty: '50 Züge', repetition: 'Stellung wiederholt',
    }
    const loser = this.state.cur
    const humanWon = this.kind === 'hotseat' || loser !== this.human
    if (status === 'mate') this.burst = this.state.kingSquare(loser)
    this.overTitle = translate(titles[status] ?? status)
    if (status === 'mate') this.overDetail = translate(humanWon ? 'Der König platzt!' : 'Dein König platzt!')
    else if (this.kind === 'hotseat') this.overDetail = translate('Remis')
    else this.overDetail = translate(humanWon ? 'Du hast gewonnen!' : 'Du hast verloren')
    this.emit()
    const humanLost = this.kind !== 'hotseat' && loser === this.human && status === 'mate'
    void this.report('final', humanLost && status !== 'mate' ? false : status === 'mate' ? humanLost : false)
  }

  private async report(outcome: 'final' | 'resigned' | 'timeout', humanLost: boolean) {
    if (!this.matchId || !this.onlineBot || this.reported) {
      if (this.matchId && !this.onlineBot) await this.pulse()
      return
    }
    if (outcome === 'timeout' && !humanLost) outcome = 'final'
    this.reported = true
    try {
      const data = await finishBot(this.matchId, this.actions, outcome)
      const delta = this.human === 'w' ? data?.trophy_delta_white : data?.trophy_delta_black
      if (typeof delta === 'number' && delta !== 0) this.overDetail = `${this.overDetail}  ${delta > 0 ? '+' : ''}${delta}`
      this.emit()
      await refreshAccount()
    } catch {
      this.note = translate('Der Server hat die Partie anders gewertet.')
      this.emit()
    }
  }

  private async pulse() {
    if (!this.matchId || this.onlineBot) return
    try {
      const codes = await fetchActions(this.matchId)
      const row = await matchStatus(this.matchId)
      this.drawFrom = row.draw_offer_by === 'white' ? 'w' : row.draw_offer_by === 'black' ? 'b' : null
      if (row.status !== 'active') {
        const youWin = (row.winner_color === 'white' && this.human === 'w') || (row.winner_color === 'black' && this.human === 'b')
        const draw = !row.winner_color
        this.overTitle = translate(row.result === 'timeout' ? 'ZEIT UM!' : row.result === 'resigned' ? 'AUFGEGEBEN!' : row.result === 'mate' ? 'SCHACHMATT' : 'Remis')
        this.overDetail = translate(draw ? 'Remis' : youWin ? 'Du hast gewonnen!' : 'Du hast verloren')
        const delta = this.human === 'w' ? row.trophy_delta_white : row.trophy_delta_black
        if (typeof delta === 'number' && delta !== 0) this.overDetail += `  ${delta > 0 ? '+' : ''}${delta}`
        if (row.result === 'mate' || row.result === 'timeout' || row.result === 'resigned') {
          const loser: Side = youWin ? E.opp(this.human) : this.human
          this.burst = this.state.kingSquare(loser)
        }
        this.emit()
        await refreshAccount()
      } else if (codes.length !== this.actions.length) {
        this.rebuild(codes)
      } else this.emit()
    } catch {
      this.note = translate('Keine Verbindung zum Server.')
      this.emit()
    }
  }

  private rebuild(codes: string[]) {
    const next = initialFromRecord({
      decks: this.opening.decks,
      ultimates: this.opening.ultimates,
    })
    for (const code of codes) apply(next, code)
    this.state = next
    this.actions = codes.slice()
    this.selected = null
    this.aiming = null
    this.card = null
    this.emit()
  }
}
