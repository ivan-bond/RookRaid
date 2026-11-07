// Port of GameViewModel.swift: one running match (battle, ladder, practice, two players, first battle, online).
import { useSyncExternalStore } from 'react'
import { apply, cooldownLeft, E, forkCount, fromFEN, initialFromRecord, isFrozen, sqIndex, type MatchState, type Move, type Side } from '../engine'
import { t } from '../i18n'
import { askBot } from './aiClient'
import {
  BOTS, CARDS, KEEPS_TURN, TIME_CONTROLS, ULTS, botById, botForTrophies, botRating, botRecordName, cardCost, isCard, ultCost,
  type Bot, type CardId, type TimeControl, type UltId,
} from './catalog'
import * as S from './store'
import type { GameMode, Result, Chest, SavedGame } from './store'
import { sound, haptic } from './feedback'
import * as Online from '../online'

export type EffectKind = 'capture' | 'bigCapture' | 'shield' | 'frost' | 'lightning' | 'promotion' | 'smoke' | 'meteor' | 'iceWave' | 'revive' | 'sparkle'
export type Effect = { id: number; kind: EffectKind; sq: number; duration: number }
export type ManaFloat = { id: number; side: Side; amount: number; label: string }
export type Announcement = { id: number; title: string; subtitle: string; icon: string; color: string }
export type CastBanner = { id: number; title: string; art: string; ult: boolean; caster: Side }
export type Finisher = { sq: number; winner: Side; kind: 'mate' | 'time' | 'resign' }
export type Coach = { step: number; total: number; icon: string; title: string; text: string; done: boolean; praise: string; rewards: Array<{ icon: string; text: string; tint: 'territory' | 'mana' | 'gold' }> }
export type GameOverInfo = {
  title: string; subtitle: string; result: Result | null; trophyDelta: number; rated: boolean; streakLit: number | null
  ladderXP: number | null; ladderUnlocked: string | null; skinUnlocked: Bot | null; chests: Chest[]; winChestsUsedUp: boolean
  roadReady: number | null; hasWinner: boolean; opponent: Bot | null; disguise: Online.PlayerCard | null; moveCount: number
  cardsPlayed: number; winnerColor: Side | null
}
export type Entry = { ply: number; side: Side; text: string; card?: string; code: string; mana: [number, number] }

type Step = {
  expect: { kind: 'move'; from: string; to: string } | { kind: 'card'; card: CardId; target?: string } | { kind: 'ult'; target?: string }
  icon: string; title: string; text: string; praise: string; reply?: string; highlight?: boolean; fillMana?: boolean
  reward?: { icon: string; text: string; tint: 'territory' | 'mana' | 'gold' }
}
export const TUTORIAL_HAND: CardId[] = ['lightning', 'shield', 'sprint', 'freeze']
export const tutorialSteps = (): Step[] => [
  { expect: { kind: 'move', from: 'e2', to: 'e4' }, icon: 'handPoint', title: 'Willkommen in der Arena!',
    text: 'Schach mit Karten und Superkräften. Zieh deinen Bauern von e2 nach e4.', praise: 'Starker Auftakt!', reply: 'e7e5' },
  { expect: { kind: 'move', from: 'g1', to: 'f3' }, icon: 'drop', title: 'Jeder Zug lädt Mana',
    text: '+1 Mana pro Zug, gute Züge +1 extra – unten siehst du deine Leiste. Springer nach f3: g1 → f3.', praise: 'Mana geladen!', reply: 'b8c6', highlight: true },
  { expect: { kind: 'move', from: 'f1', to: 'c4' }, icon: 'scope', title: 'Ziel: f7',
    text: 'f7 ist Milas schwächster Punkt – nur der König deckt ihn. Läufer nach c4, er zielt genau dorthin.', praise: 'Im Visier!', reply: 'g8f6' },
  { expect: { kind: 'move', from: 'f3', to: 'g5' }, icon: 'arrowUpRight', title: 'Doppelter Druck',
    text: 'Springer nach g5: Jetzt greifen Läufer und Springer f7 gemeinsam an.', praise: 'Mila muss reagieren!', reply: 'd7d5' },
  { expect: { kind: 'move', from: 'e4', to: 'd5' }, icon: 'burst', title: 'Schlag zu!',
    text: 'Mila sperrt deinen Läufer mit d5. Schlag den Bauern – Schlagen lädt extra Mana.', praise: 'Treffer!', reply: 'f6d5' },
  { expect: { kind: 'card', card: 'shield', target: 'g5' }, icon: 'shield', title: 'Achtung – Angriff!',
    text: 'Milas Dame bedroht deinen Springer g5. Tippe auf Schild, dann auf g5.', praise: 'Abgewehrt!',
    reward: { icon: 'shield', text: 'Springer geschützt', tint: 'territory' } },
  { expect: { kind: 'move', from: 'd1', to: 'f3' }, icon: 'walk', title: 'Bonuszug!',
    text: 'Schild kostet keinen Zug – zieh gleich noch: Dame nach f3. Sie droht, auf f7 Matt zu setzen.', praise: 'Verteidigt und angegriffen!', reply: 'c8e6' },
  { expect: { kind: 'ult', target: 'h8' }, icon: 'flame', title: 'Ultimate geladen!',
    text: 'Volle Leiste! Meteor vernichtet jede Figur außer König und Dame. Tippe auf Meteor, dann auf den Turm h8.', praise: 'METEOR!', reply: 'c6d4', fillMana: true,
    reward: { icon: 'flame', text: 'Turm zerstört', tint: 'gold' } },
  { expect: { kind: 'card', card: 'freeze', target: 'e6' }, icon: 'snowflake', title: 'Frost auf den Verteidiger',
    text: 'Nur Milas Läufer e6 deckt f7. Tippe auf Frost, dann auf e6 – eingefroren kann er nicht schlagen.', praise: 'Eingefroren!', fillMana: true,
    reward: { icon: 'snowflake', text: 'Läufer eingefroren', tint: 'territory' } },
  { expect: { kind: 'move', from: 'f3', to: 'f7' }, icon: 'crown', title: 'Das Finale',
    text: 'Frost kostet keinen Zug. Dame schlägt f7, der Springer deckt sie – Schachmatt!', praise: 'SCHACHMATT!' },
]

const TACTIC: Record<string, { title: string; short: string; icon: string }> = {
  double: { title: 'DOPPELSCHACH!', short: 'Doppelschach', icon: 'bolt' },
  discovered: { title: 'ABZUGSSCHACH!', short: 'Abzugsschach', icon: 'eye' },
  fork: { title: 'GABEL!', short: 'Gabel', icon: 'branch' },
  skewer: { title: 'SPIESS!', short: 'Spieß', icon: 'arrowRight' },
  pin: { title: 'FESSELUNG!', short: 'Fesselung', icon: 'pin' },
}

/** Same texts as GameStatus.reason in the app – also what the history stores, so both show the same. */
const REASON: Record<string, string> = {
  mate: 'durch Schachmatt', stalemate: 'durch Patt', fifty: 'durch die 50-Züge-Regel', repetition: 'durch dreifache Stellungswiederholung',
  timeout: 'durch Zeitüberschreitung', resigned: 'durch Aufgabe', draw: 'durch Einigung',
}
/** Subline of the big draw title (same texts as GameStatus.reason in the app). */
const REASON_LONG: Record<string, string> = { stalemate: 'durch Patt', fifty: 'durch die 50-Züge-Regel', repetition: 'durch dreifache Stellungswiederholung' }

let nextId = 1
const wait = (ms: number) => new Promise(r => setTimeout(r, ms))

export type StartOptions = {
  mode: GameMode
  human?: Side
  timeControl?: TimeControl
  saved?: SavedGame
  online?: Online.OnlineStart
  /** Reopening a running online match (after reload or leaving): no duel intro, "Zurück in deiner Partie". */
  resumed?: boolean
}

export class GameController {
  mode: GameMode
  human: Side
  timeControl: TimeControl
  state: MatchState
  initial: MatchState
  decks: { w: string[]; b: string[] }
  ults: { w?: string; b?: string }
  actions: string[] = []
  entries: Entry[] = []
  selected: number | null = null
  legal: Move[] = []
  pendingCard: string | null = null
  pendingUlt = false
  cardTargets: number[] = []
  promotion: Move | null = null
  thinking = false
  hint: string | null = null
  effects: Effect[] = []
  manaFloats: ManaFloat[] = []
  announcement: Announcement | null = null
  banner: CastBanner | null = null
  finisher: Finisher | null = null
  /** Draw (stalemate, repetition, 50 moves, agreed): the reason for the big draw title in the middle. */
  drawFinish: string | null = null
  gameOver: GameOverInfo | null = null
  shake = 0
  clocks = { w: 0, b: 0 }
  introActive = false
  cardsPlayedByHuman = 0
  startedAt = Date.now()
  // Tutorial
  coach: Coach | null = null
  tutorialIndex = 0
  tutorialSquares: number[] = []
  tutorialCard: string | null = null
  tutorialUlt = false
  tutorialHighlight = false
  questNudge = 0
  questNudgeText: string | null = null
  tutorialComplete: { xp: number; streak: number | null } | null = null
  closeRequested = false
  // Online
  online: Online.OnlineStart | null = null
  onlineNotice: string | null = null
  incomingDraw = false
  private serverResult: { result: string; winner: Side | null; delta: number | null } | null = null
  private sending = Promise.resolve()
  /** Last answered sign of life (for "Verbindung verloren – noch {0} s"); the claim on a silent opponent goes out once. */
  private lastHeartbeatOK: number | null = null
  private silenceClaimed = false
  private persistentNotice = false

  version = 0
  private listeners = new Set<() => void>()
  private timers: number[] = []
  private clockTimer = 0
  private lastTick = 0
  private finished = false
  private aiToken = 0
  private stats = { cards: {} as Record<string, number>, bonus: 0, ults: 0, tactics: 0 }
  private questMana = 0

  constructor(opts: StartOptions) {
    this.mode = opts.mode
    const profile = S.getProfile()
    if (opts.saved) {
      this.mode = opts.saved.mode
      this.human = opts.saved.human
      this.timeControl = opts.saved.timeControl
      this.decks = opts.saved.decks
      this.ults = opts.saved.ults
    } else if (opts.online) {
      this.online = opts.online
      this.human = opts.online.youWhite ? 'w' : 'b'
      this.timeControl = 'blitz5'
      this.decks = { w: opts.online.decks.white, b: opts.online.decks.black }
      this.ults = { w: opts.online.ultimates.white, b: opts.online.ultimates.black }
    } else {
      this.human = opts.human ?? (profile.settings.playAsWhite ? 'w' : 'b')
      this.timeControl = opts.timeControl ?? 'none'
      const setup = GameController.setup(this.mode, this.human)
      this.decks = setup.decks
      this.ults = setup.ults
    }
    if (opts.online) this.online = opts.online
    this.state = this.freshState()
    this.initial = this.state.clone()
    const secs = TIME_CONTROLS[this.timeControl].seconds
    this.clocks = { w: secs, b: secs }
    if (opts.online && !opts.online.bot) {
      this.clocks = { w: opts.online.clockWhiteMs / 1000, b: opts.online.clockBlackMs / 1000 }
    }
    if (opts.saved) {
      for (const code of opts.saved.actions) this.replayCode(code)
      this.clocks = { ...opts.saved.clocks }
      this.cardsPlayedByHuman = opts.saved.cardsPlayedByHuman
      this.startedAt = opts.saved.startedAt
      if (opts.saved.mana) this.state.mana = { ...opts.saved.mana }
    }
    this.introActive = !opts.saved && !opts.resumed && (this.mode.kind === 'bot' || this.mode.kind === 'ladder' || this.mode.kind === 'online')
    if (opts.resumed) this.hint = t('Zurück in deiner Partie')
    if (this.mode.kind === 'tutorial') this.showTutorialStep()
  }

  static setup(mode: GameMode, human: Side): { decks: { w: string[]; b: string[] }; ults: { w?: string; b?: string } } {
    const opp: Side = human === 'w' ? 'b' : 'w'
    if (mode.kind === 'tutorial') return { decks: { w: [...TUTORIAL_HAND], b: [] }, ults: { w: 'meteor' } }
    const mine = S.activeUltimate()
    const deck = S.activeDeck()
    if (mode.kind === 'bot' || mode.kind === 'ladder' || mode.kind === 'practice') {
      const bot = botById(mode.bot)
      let ult: UltId = bot.ult
      if (mode.kind === 'bot') {
        const pool = (Object.keys(ULTS) as UltId[]).filter(u => ULTS[u].arena <= S.arena().n)
        if (!pool.includes(ult)) ult = pool[Math.floor(Math.random() * pool.length)] ?? 'meteor'
      }
      return { decks: { [human]: deck, [opp]: [...bot.deck] } as { w: string[]; b: string[] }, ults: { [human]: mine, [opp]: ult } }
    }
    return { decks: { w: deck, b: deck }, ults: { w: mine, b: mine } }
  }

  private freshState(): MatchState {
    if (this.mode.kind === 'tutorial') {
      const s = E.State.initial({ w: 'meteor' }, Math.random, { w: [...TUTORIAL_HAND], b: [] })
      delete (s.decks as Partial<Record<Side, unknown>>).b
      return s
    }
    return initialFromRecord({ decks: { white: this.decks.w, black: this.decks.b }, ultimates: { white: this.ults.w ?? '', black: this.ults.b ?? '' } })
  }

  // MARK: Subscription

  subscribe = (fn: () => void) => { this.listeners.add(fn); return () => { this.listeners.delete(fn) } }
  emit() { this.version++; this.listeners.forEach(fn => fn()) }
  getVersion = () => this.version

  // MARK: Derived

  get bot(): Bot | null {
    const m = this.mode
    return m.kind === 'bot' || m.kind === 'ladder' || m.kind === 'practice' ? botById(m.bot) : null
  }
  get isBotMode() { return this.mode.kind === 'bot' || this.mode.kind === 'ladder' || this.mode.kind === 'practice' }
  get isOnlineHuman() { return this.mode.kind === 'online' }
  get isOnlineBot() { return !!this.online?.bot }
  get aiSide(): Side | null {
    if (this.mode.kind === 'hotseat' || this.mode.kind === 'online') return null
    return this.human === 'w' ? 'b' : 'w'
  }
  get flipped() { return (this.isBotMode || this.isOnlineHuman) && this.human === 'b' }
  get perspective(): Side { return this.flipped ? 'b' : 'w' }
  get handOwner(): Side { return this.mode.kind === 'hotseat' ? this.state.cur : this.human }
  get status() { return this.finished && this.endReason ? 'over' : this.state.status() }
  endReason: string | null = null
  winner: Side | null = null
  get over() { return this.finished }
  get isHumanTurn() {
    if (this.mode.kind === 'online') return this.state.cur === this.human
    return this.aiSide !== this.state.cur
  }
  get canInteract() {
    return !this.finished && this.isHumanTurn && !this.thinking && !this.gameOver && !this.coach?.done && !this.introActive
  }
  get control() { return this.state.controlMap() }
  get checkedKing(): number | null {
    const st = this.state.status()
    return st === 'check' || st === 'mate' ? this.state.kingSquare(this.state.cur) : null
  }
  skin(side: Side): Bot | null {
    const p = S.getProfile()
    if (this.mode.kind === 'tutorial' && side === 'b') return botById('medium')
    // Stand-in for an online opponent: standard pieces – a bot's piece set would give it away (E1, like the app)
    if (this.online && side !== this.human) return null
    if (this.isBotMode && side !== this.human && p.settings.botSkins) return this.bot
    if (side === this.human || this.mode.kind === 'hotseat') return S.activeSkin()
    return null
  }
  name(side: Side): string {
    const p = S.getProfile()
    if (this.mode.kind === 'tutorial') return side === 'w' ? S.shownName(p.name, t) : t('Mila')
    if (this.online && side !== this.human) return this.online.opponent.name || t('Gegner')
    if (this.isBotMode) return side === this.human ? (S.shownName(p.name, t)) : t(this.bot!.name)
    if (this.online) return p.name
    return side === 'w' ? t('Weiß') : t('Schwarz')
  }
  income(_side: Side) { return 1 }
  cooldown(card: string, side: Side) { return cooldownLeft(this.state, card, side) }
  isCardPlayable(card: string, side: Side) {
    return this.state.cur === side && this.state.canPlay(card, side) && this.canInteract
  }
  canUseUlt(side: Side) { return this.state.cur === side && this.state.canUseUlt(side) && this.canInteract }
  capturedBy(side: Side) {
    // Pieces the given side has taken (lost by the other side).
    const other: Side = side === 'w' ? 'b' : 'w'
    return this.state.captured[other] ?? []
  }
  materialBalance(side: Side): number {
    const v: Record<string, number> = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 }
    let n = 0
    for (const p of this.state.b) if (p) n += p.c === side ? v[p.t] : -v[p.t]
    return n
  }
  isLastMove(i: number) {
    const last = this.state.last
    return !!last && (last.f === i || last.t === i)
  }

  // MARK: Lifecycle

  /** An online match (person or stand-in bot) that is still running – it can be reopened after leaving. */
  get canResumeOnline() { return !!this.online && !this.finished && !this.gameOver }

  start() {
    this.lastTick = performance.now()
    if (this.online?.bot && this.actions.length) void this.checkStandInStillActive()
    this.clockTimer = window.setInterval(() => this.tick(), 100)
    if (this.online && !this.online.bot) this.startOnline()
    if (this.online?.bot) {
      // First sign of life right away: a stand-in game without any counts as never played (no rating).
      void this.ping()
      this.timers.push(window.setInterval(() => { void this.ping() }, 10_000))
      // Tab hidden or laptop asleep for a while: the server may have ended the game (45 s rule) – check on return.
      document.addEventListener('visibilitychange', this.onVisible)
    }
    if (!this.introActive) this.scheduleAI()
  }
  private onVisible = () => {
    if (document.visibilityState !== 'visible' || !this.online?.bot || this.finished) return
    void this.ping()
    void this.checkStandInStillActive()
  }
  stop() {
    document.removeEventListener('visibilitychange', this.onVisible)
    document.removeEventListener('visibilitychange', this.onVisibleOnline)
    window.clearInterval(this.clockTimer)
    this.timers.forEach(id => window.clearInterval(id))
    this.timers = []
    this.aiToken++
  }
  finishIntro() {
    if (!this.introActive) return
    this.introActive = false
    this.lastTick = performance.now()
    this.explainOnlineLeave()
    this.emit()
    this.scheduleAI()
  }

  private tick() {
    const now = performance.now()
    const dt = (now - this.lastTick) / 1000
    this.lastTick = now
    if (!TIME_CONTROLS[this.timeControl].seconds || this.finished || this.introActive || this.gameOver) return
    if (this.online && !this.online.bot && Date.now() < this.online.startedAt) { this.emit(); return }
    const side = this.state.cur
    this.clocks[side] = Math.max(0, this.clocks[side] - dt)
    if (this.clocks[side] <= 0) {
      if (this.online && !this.online.bot) { void this.claimTimeout(); return }
      this.endGame('timeout', side === 'w' ? 'b' : 'w')
      return
    }
    this.emit()
  }

  // MARK: Input

  tap(i: number) {
    if (!this.canInteract || this.promotion) return
    if (this.pendingCard || this.pendingUlt) { this.handleTarget(i); return }
    if (this.selected !== null) {
      const move = this.legal.find(m => m.t === i)
      if (move) { this.tryMove(move); return }
    }
    this.selectPiece(i)
  }
  canDrag(i: number) {
    const p = this.state.b[i]
    return this.canInteract && !this.pendingCard && !this.pendingUlt && !!p && p.c === this.state.cur && this.state.legalMoves(i).length > 0
  }
  beginDrag(i: number) {
    this.selected = i
    this.legal = this.state.legalMoves(i)
    this.emit()
  }
  drop(from: number, to: number) {
    if (from === to) return
    const move = this.state.legalMoves(from).find(m => m.t === to)
    if (move) this.tryMove(move)
    else {
      if (this.state.isBonusLocked(from)) { haptic('invalid'); this.hint = t('Diese Figur steht unter deinem Schild und bleibt in diesem Zug stehen – zieh eine andere.') }
      this.clearSelection(); this.emit()
    }
  }
  private selectPiece(i: number) {
    const p = this.state.b[i]
    if (p && p.c === this.state.cur && p.c === (this.mode.kind === 'hotseat' ? this.state.cur : this.human)) {
      const moves = this.state.legalMoves(i)
      if (this.selected === i) { this.clearSelection() } else {
        this.selected = i
        this.legal = moves
        // Same messages as select() in GameViewModel.swift
        if (!moves.length) {
          if (this.state.isBonusLocked(i)) this.hint = t('Diese Figur steht unter deinem Schild und bleibt in diesem Zug stehen – zieh eine andere.')
          else this.hint = isFrozen(p, this.state.ply) ? t('Diese Figur ist eingefroren.') : t('Diese Figur kann gerade nicht ziehen.')
        } else this.hint = null
        sound('select')
      }
    } else this.clearSelection()
    this.emit()
  }
  private tryMove(move: Move) {
    const piece = this.state.b[move.f]
    if (this.mode.kind === 'tutorial' && !this.tutorialAllows({ kind: 'move', from: E.sqName(move.f), to: E.sqName(move.t) })) {
      this.tutorialNudge()
      return
    }
    if (piece?.t === 'p' && (move.t >> 3) === (piece.c === 'w' ? 0 : 7)) {
      this.promotion = move
      this.emit()
      return
    }
    this.commit(E.uci(this.state, move))
  }
  choosePromotion(piece: string) {
    const move = this.promotion
    if (!move) return
    this.promotion = null
    this.commit(E.sqName(move.f) + E.sqName(move.t) + piece)
  }
  cancelPromotion() { this.promotion = null; this.clearSelection(); this.emit() }

  tapCard(card: string) {
    const side = this.state.cur
    if (!this.canInteract || side !== this.handOwner) return
    if (this.mode.kind === 'tutorial') {
      const exp = this.currentStep()?.expect
      if (!exp || exp.kind !== 'card' || exp.card !== card) { this.tutorialNudge(); return }
    }
    if (this.state.bonus) { this.hint = t('Erst noch dein Figurzug – dann wieder Karten.'); this.emit(); return }
    const cd = this.cooldown(card, side)
    const cardName = t(CARDS[card as CardId]?.name ?? card)
    if (cd > 0) { this.hint = t('{0} lädt noch {1} {2} nach.', cardName, cd, cd === 1 ? t('Zug') : t('Züge')); haptic('invalid'); this.emit(); return }
    if (this.state.mana[side] < cardCost(card)) { this.hint = t('Nicht genug Mana – {0} kostet {1}.', cardName, cardCost(card)); haptic('invalid'); this.emit(); return }
    if (!this.state.canPlay(card, side)) { this.hint = t('{0} hat gerade kein gültiges Ziel.', cardName); haptic('invalid'); this.emit(); return }
    if (this.pendingCard === card) { this.cancelPending(); return }
    this.clearSelection()
    this.pendingUlt = false
    if (E.NO_TARGET[card]) { this.commit('card:' + card); return }
    this.pendingCard = card
    this.cardTargets = this.state.targets(card, side)
    sound('select')
    this.emit()
  }
  tapUltimate() {
    const side = this.state.cur
    if (!this.canInteract || side !== this.handOwner) return
    const u = this.state.ults[side]
    if (!u) return
    if (this.mode.kind === 'tutorial') {
      const exp = this.currentStep()?.expect
      if (!exp || exp.kind !== 'ult') { this.tutorialNudge(); return }
    }
    if (this.state.bonus) { this.hint = t('Erst noch dein Figurzug – dann wieder Karten.'); this.emit(); return }
    const ultName = t(ULTS[u as UltId]?.name ?? u)
    if (this.state.mana[side] < ultCost(u)) { this.hint = t('{0} braucht {1} Mana ({2}/{1}).', ultName, ultCost(u), this.state.mana[side]); haptic('invalid'); this.emit(); return }
    if (!this.state.canUseUlt(side)) { this.hint = t('{0} hat gerade kein gültiges Ziel.', ultName); haptic('invalid'); this.emit(); return }
    if (this.pendingUlt) { this.cancelPending(); return }
    this.clearSelection()
    this.pendingCard = null
    if (!E.ultNeedsTarget(u)) { this.commit('ult:' + u); return }
    this.pendingUlt = true
    this.cardTargets = this.state.ultTargets(side)
    sound('select')
    this.emit()
  }
  cancelPending() {
    this.pendingCard = null
    this.pendingUlt = false
    this.cardTargets = []
    this.clearSelection()
    this.emit()
  }
  private handleTarget(i: number) {
    if (!this.cardTargets.includes(i)) {
      const p = this.state.b[i]
      if (p && p.c === this.state.cur && !this.pendingUlt && this.pendingCard && !['shield', 'swap', 'sprint', 'knighting', 'bishopize', 'sacrifice'].includes(this.pendingCard)) {
        this.cancelPending(); this.selectPiece(i); return
      }
      haptic('invalid')
      this.cancelPending()
      return
    }
    if (this.mode.kind === 'tutorial') {
      const exp = this.currentStep()?.expect
      if (exp && exp.kind !== 'move' && exp.target && exp.target !== E.sqName(i)) { this.tutorialNudge(); return }
    }
    if (this.pendingUlt) {
      const u = this.state.ults[this.state.cur]
      this.commit(`ult:${u}@${E.sqName(i)}`)
    } else if (this.pendingCard) {
      this.commit(`card:${this.pendingCard}@${E.sqName(i)}`)
    }
  }
  private clearSelection() {
    this.selected = null
    this.legal = []
  }

  // MARK: Actions

  /** Apply one wire action with all effects. `remote` = it came from the server or the bot. */
  private commit(code: string, remote = false) {
    if (this.finished) return
    const before = this.state.clone()
    const mover = before.cur
    const next = this.state.clone()
    if (!apply(next, code)) {
      if (!remote) { this.hint = t('Dieser Zug ist nicht erlaubt.'); this.cancelPending() }
      return false
    }
    this.state = next
    this.actions.push(code)
    this.pendingCard = null
    this.pendingUlt = false
    this.cardTargets = []
    this.promotion = null
    this.clearSelection()
    this.hint = null
    if (this.mode.kind === 'online' && mover === this.human && !remote) this.sendOnline(code, this.actions.length - 1)
    const tc = TIME_CONTROLS[this.timeControl]
    if (code.startsWith('card:')) this.afterCard(code, before, mover, tc.inc)
    else if (code.startsWith('ult:')) this.afterUlt(code, before, mover, tc.inc)
    else this.afterMove(code, before, mover, tc.inc)
    return true
  }

  private manaFloatsFor(before: MatchState, mover: Side, spent: number, label: string) {
    const opp: Side = mover === 'w' ? 'b' : 'w'
    const gainMover = this.state.mana[mover] - before.mana[mover] + spent
    if (gainMover > 0) this.showManaFloat(mover, gainMover, label)
    if (this.state.cur === opp && this.state.mana[opp] > before.mana[opp]) this.showManaFloat(opp, this.state.mana[opp] - before.mana[opp], t('Zug'))
  }

  private afterMove(code: string, before: MatchState, mover: Side, inc: number) {
    const from = sqIndex(code.slice(0, 2)), to = sqIndex(code.slice(2, 4))
    const move = before.allLegal(mover).find(m => m.f === from && m.t === to) ?? { f: from, t: to }
    if (inc) this.clocks[mover] += inc
    const victim = before.b[to] ?? (move.epc ? before.b[(from >> 3) * 8 + (to & 7)] : null)
    const opp: Side = mover === 'w' ? 'b' : 'w'
    if (victim) {
      const big = ['r', 'q'].includes(victim.t)
      this.addEffect(big ? 'bigCapture' : 'capture', move.epc ? (from >> 3) * 8 + (to & 7) : to, big ? 1000 : 900)
      sound('capture'); haptic(big ? 'heavy' : 'capture')
      if (big) this.bumpShake()
    }
    if (code.length === 5) this.addEffect('promotion', to, 1200)
    const givesCheck = this.state.inCheck(opp)
    const label = victim ? t('Schlag') : givesCheck ? t('Schach') : ''
    // Tactic: announced and counted for achievements, but no mana – the shared rules (and the server) have no tactic bonus.
    const st = this.state.status()
    if (st !== 'mate' && st !== 'stalemate') {
      const tac = E.detectTactic(this.state, move, mover)
      if (tac && TACTIC[tac]) {
        const info = TACTIC[tac]
        if (this.countsForStats(mover)) this.stats.tactics++
        const mine = !this.isBotMode || mover === this.human
        const title = tac === 'fork' && forkCount(this.state, move, mover) >= 3 ? 'MEGA-GABEL!' : info.title
        this.announce(t(title), t('Starker Zug von {0}', this.name(mover)), info.icon, mine ? '#2F6FE4' : '#E0413A')
        this.addEffect('sparkle', to, 1000)
      }
    }
    this.manaFloatsFor(before, mover, 0, label)
    if (st === 'check') { sound('check'); haptic('check') }
    else if (!victim) sound(move.crf !== undefined ? 'castle' : 'move')
    const text = this.notation(before, move) + (st === 'mate' ? '#' : st === 'check' ? '+' : '')
    this.finishAction({ ply: before.ply, side: mover, text, code, mana: [this.state.mana.w, this.state.mana.b] })
  }

  private afterCard(code: string, before: MatchState, mover: Side, inc: number) {
    const [card, tgt] = code.slice(5).split('@')
    const target = tgt ? sqIndex(tgt) : null
    const keeps = !!KEEPS_TURN[card]
    if (inc && !keeps) this.clocks[mover] += inc
    if (!this.isBotMode || mover === this.human) this.cardsPlayedByHuman++
    if (this.countsForStats(mover)) {
      this.stats.cards[card] = (this.stats.cards[card] ?? 0) + 1
      if (keeps) this.stats.bonus++
    }
    this.showBanner({ title: t(CARDS[card as CardId]?.name ?? card), art: `art-card-${card}`, ult: false, caster: mover })
    sound('card'); haptic('card')
    let fx: string = 'shield'
    const fwd = mover === 'w' ? -8 : 8
    switch (card) {
      case 'shield': if (target !== null) this.addEffect('shield', target); break
      case 'bulwark': this.state.b.forEach((p, i) => { if (p && p.c === mover && p.t === 'p') this.addEffect('shield', i) }); break
      case 'freeze': if (target !== null) this.addEffect('frost', target, 1100); fx = 'frost'; break
      case 'lightning': if (target !== null) this.addEffect('lightning', target, 800); fx = 'lightning'; this.bumpShake(); break
      case 'knighting': case 'bishopize': if (target !== null) this.addEffect('promotion', target, 1100); fx = 'summon'; break
      case 'sprint': if (target !== null) this.addEffect('smoke', target + 2 * fwd); fx = 'move'; break
      case 'retreat': if (target !== null) this.addEffect('smoke', target); fx = 'move'; break
      case 'reinforce': if (target !== null) this.addEffect('revive', target, 1100); fx = 'summon'; break
      case 'revive': if (target !== null) this.addEffect('revive', target, 1100); fx = 'summon'; break
      case 'advance': fx = 'move'; break
      case 'swap': if (target !== null) this.addEffect('smoke', target); this.addEffect('smoke', before.kingSquare(mover)); fx = 'castle'; break
      case 'drain': case 'focus': fx = 'notify'; break
      case 'sacrifice': if (target !== null) this.addEffect('lightning', target, 800); fx = 'trap'; break
    }
    window.setTimeout(() => sound(fx as never), 220)
    this.manaFloatsFor(before, mover, cardCost(card), t('Karte'))
    const name = t(CARDS[card as CardId]?.name ?? card)
    this.finishAction({ ply: before.ply, side: mover, text: name + (tgt ? ` → ${tgt}` : ''), card, code, mana: [this.state.mana.w, this.state.mana.b] })
    if (keeps && this.state.bonus && this.state.cur === mover && !this.finished) {
      const mine = !this.isBotMode || mover === this.human
      if (mine) {
        this.hint = card === 'shield' ? t('Schild steht! Jetzt noch ein Figurzug – die geschützte Figur bleibt stehen.')
          : card === 'sprint' ? t('Sturmlauf! Jetzt noch ein Figurzug mit einer anderen Figur.')
            : card === 'retreat' ? t('Rückzug! Jetzt noch ein Figurzug mit einer anderen Figur.')
              : t('{0} gespielt – jetzt noch dein Figurzug!', name)
      } else this.hint = t('{0} spielt {1} und zieht gleich noch.', this.name(mover), name)
      this.emit()
    }
  }

  private afterUlt(code: string, before: MatchState, mover: Side, inc: number) {
    const [u, tgt] = code.slice(4).split('@')
    const target = tgt ? sqIndex(tgt) : null
    const keeps = u === 'fortress'
    if (inc && !keeps) this.clocks[mover] += inc
    const name = t(ULTS[u as UltId]?.name ?? u)
    this.showBanner({ title: name, art: `art-ult-${u}`, ult: true, caster: mover })
    const mine = !this.isBotMode || mover === this.human
    if (this.countsForStats(mover)) this.stats.ults++
    this.announce(name.toUpperCase() + '!', t('Ultimate von {0}', this.name(mover)), ULTS[u as UltId]?.icon ?? 'sparkles', mine ? '#B8892B' : '#E0413A')
    sound('lightning'); haptic('heavy')
    this.bumpShake()
    const opp: Side = mover === 'w' ? 'b' : 'w'
    if (u === 'meteor' && target !== null) {
      this.addEffect('meteor', target, 1200)
      for (const d of [-9, -8, -7, -1, 1, 7, 8, 9]) {
        const n = target + d
        if (n < 0 || n > 63 || Math.abs((n & 7) - (target & 7)) > 1) continue
        const q = this.state.b[n], q0 = before.b[n]
        if (q && isFrozen(q, this.state.ply) && !(q0 && isFrozen(q0, this.state.ply))) this.addEffect('frost', n, 1100)
      }
    } else if (u === 'iceAge') {
      this.state.b.forEach((p, i) => { if (p && p.c === opp && p.t !== 'k') this.addEffect('frost', i, 1100) })
      this.addEffect('iceWave', this.state.kingSquare(opp), 1200)
    } else if (u === 'fortress') {
      this.state.b.forEach((p, i) => { if (p && p.c === mover && p.t !== 'k') this.addEffect('shield', i) })
    } else if (u === 'coronation' && target !== null) this.addEffect('promotion', target, 1200)
    else if (u === 'rebirth') {
      this.state.b.forEach((p, i) => { if (p && !before.b[i]) this.addEffect('revive', i, 1100) })
    }
    this.manaFloatsFor(before, mover, ultCost(u), '')
    this.finishAction({ ply: before.ply, side: mover, text: '★ ' + name + (tgt ? ` → ${tgt}` : ''), code, mana: [this.state.mana.w, this.state.mana.b] })
    if (keeps && this.state.bonus && this.state.cur === mover && !this.finished) {
      this.hint = mine ? t('{0} steht! Jetzt noch dein Figurzug.', name) : t('{0} setzt {1} ein und zieht gleich noch.', this.name(mover), name)
      this.emit()
    }
  }

  private notation(s: MatchState, m: Move): string {
    const p = s.b[m.f]
    if (!p) return E.sqName(m.f) + E.sqName(m.t)
    if (m.crf !== undefined) return (m.t & 7) > (m.f & 7) ? 'O-O' : 'O-O-O'
    const letter: Record<string, string> = { k: 'K', q: 'D', r: 'T', b: 'L', n: 'S', p: '' }
    const cap = s.b[m.t] || m.epc
    const prefix = p.t === 'p' ? (cap ? E.sqName(m.f)[0] : '') : letter[p.t]
    return prefix + (cap ? 'x' : '') + E.sqName(m.t)
  }

  private finishAction(entry: Entry) {
    this.entries.push(entry)
    const st = this.state.status()
    if (st === 'mate') { this.endGame('mate', entry.side); return }
    if (st === 'stalemate' || st === 'fifty' || st === 'repetition') { this.endGame(st, null); return }
    const side = this.state.cur
    if (this.mode.kind !== 'tutorial' && this.isHumanTurn && side === this.handOwner) {
      const u = this.state.ults[side]
      if (u && this.state.mana[side] >= ultCost(u) && this.state.canUseUlt(side) && !this.state.bonus) {
        this.hint = t('{0} Mana – deine Ultimate ist bereit!', ultCost(u))
      }
    }
    if (this.mode.kind === 'tutorial') this.tutorialAfterAction(entry.side)
    this.save()
    this.emit()
    this.scheduleAI()
  }

  // MARK: Displays

  private showBanner(b: Omit<CastBanner, 'id'>) {
    const banner = { ...b, id: nextId++ }
    this.banner = banner
    window.setTimeout(() => { if (this.banner?.id === banner.id) { this.banner = null; this.emit() } }, 1150)
  }
  private announce(title: string, subtitle: string, icon: string, color: string) {
    const a = { id: nextId++, title, subtitle, icon, color }
    this.announcement = a
    window.setTimeout(() => { if (this.announcement?.id === a.id) { this.announcement = null; this.emit() } }, 1600)
  }
  private showManaFloat(side: Side, amount: number, label: string) {
    const f = { id: nextId++, side, amount, label }
    this.manaFloats = [...this.manaFloats, f]
    if (side === this.handOwner) haptic('mana')
    window.setTimeout(() => { this.manaFloats = this.manaFloats.filter(x => x.id !== f.id); this.emit() }, 1600)
  }
  private addEffect(kind: EffectKind, sq: number, duration = 900) {
    if (sq < 0) return
    const e = { id: nextId++, kind, sq, duration }
    this.effects = [...this.effects, e]
    window.setTimeout(() => { this.effects = this.effects.filter(x => x.id !== e.id); this.emit() }, duration + 50)
  }
  private bumpShake() { this.shake++ }
  private countsForStats(side: Side) {
    return side === this.human && this.mode.kind !== 'practice' && this.mode.kind !== 'tutorial' && this.mode.kind !== 'hotseat'
  }

  flushStats() {
    const s = this.stats
    if (!Object.keys(s.cards).length && !s.bonus && !s.ults && !s.tactics) return
    S.update(p => {
      for (const [k, v] of Object.entries(s.cards)) p.cardsByType[k] = (p.cardsByType[k] ?? 0) + v
      p.bonusActions += s.bonus
      p.ultimatesUsed += s.ults
      p.tacticBonuses += s.tactics
    })
    this.stats = { cards: {}, bonus: 0, ults: 0, tactics: 0 }
  }

  // MARK: Bot

  private scheduleAI() {
    const ai = this.aiSide
    if (!ai || this.state.cur !== ai || this.finished || this.introActive) return
    if (this.mode.kind === 'tutorial') { this.playTutorialReply(); return }
    const token = ++this.aiToken
    this.thinking = true
    this.emit()
    const bot = this.bot ?? BOTS[2]
    const snapshot = this.state.clone()
    const tc = TIME_CONTROLS[this.timeControl]
    // With a clock: at most a twentieth of the remaining time plus most of the increment (as in the app).
    const maxSeconds = tc.seconds ? this.clocks[snapshot.cur] / 20 + tc.inc * 0.8 : undefined
    const pause = 0.45 + this.humanPause(snapshot)
    void (async () => {
      await wait(pause * 1000)
      if (token !== this.aiToken || this.finished || this.state.ply !== snapshot.ply) return
      const code = await askBot(snapshot, bot.search, maxSeconds)
      if (token !== this.aiToken || this.finished || this.state.ply !== snapshot.ply || this.state.bonus !== snapshot.bonus) return
      this.thinking = false
      if (!code || !this.commit(code, true)) {
        const fallback = this.state.allLegal(this.state.cur)[0]
        if (fallback) this.commit(E.uci(this.state, fallback), true)
      }
    })()
  }
  private humanPause(s: MatchState): number {
    if (this.mode.kind !== 'bot') return 0
    let extra = Math.pow(Math.random(), 1.5) * 7
    if (s.bonus) extra = Math.min(extra, 1.5)
    if (s.ply < 4) extra = Math.min(extra, 2)
    if (TIME_CONTROLS[this.timeControl].seconds) extra = Math.min(extra, Math.max(0, this.clocks[s.cur] / 12 - 0.5))
    return extra
  }

  // MARK: Resign, draw

  resign() {
    if (this.finished) return
    const loser: Side = this.mode.kind === 'hotseat' ? this.state.cur : this.human
    if (this.online && !this.online.bot) void Online.resignMatch(this.online.matchId).catch(() => undefined)
    this.endGame('resigned', loser === 'w' ? 'b' : 'w')
  }
  get canOfferDraw() { return !!this.online && !this.online.bot && !this.finished }
  async offerDraw() {
    if (!this.online || this.online.bot) return
    try { await Online.offerDraw(this.online.matchId); this.hint = t('Remis angeboten.'); this.emit() } catch (e) {
      const text = e instanceof Error ? e.message : String((e as { message?: unknown } | null)?.message ?? e)
      this.hint = text.includes('too_early') ? t('Remis erst nach dem ersten Zugpaar.') : t('Keine Verbindung zum Server.')
      this.emit()
    }
  }
  async answerDraw(accept: boolean) {
    if (!this.online) return
    this.incomingDraw = false
    this.emit()
    try { await Online.answerDraw(this.online.matchId, accept) } catch { /* the poll reads the result */ }
    void this.pulse()
  }
  private notice(text: string) {
    if (this.persistentNotice) return
    this.onlineNotice = text
    this.emit()
    window.setTimeout(() => { if (this.onlineNotice === text) { this.onlineNotice = null; this.emit() } }, 2600)
  }

  // MARK: Restart and save

  restart(): GameController {
    this.stop()
    this.flushStats()
    S.clearGame()
    return new GameController({ mode: this.mode, human: this.human, timeControl: this.timeControl })
  }

  save() {
    if (this.finished || this.mode.kind === 'tutorial' || this.mode.kind === 'online' || this.online) return
    S.saveGame({ mode: this.mode, human: this.human, timeControl: this.timeControl, decks: this.decks, ults: this.ults,
      actions: this.actions, clocks: { ...this.clocks }, cardsPlayedByHuman: this.cardsPlayedByHuman, startedAt: this.startedAt,
      mana: { ...this.state.mana } })
  }

  private replayCode(code: string) {
    const before = this.state.clone()
    if (!apply(this.state, code)) return
    this.actions.push(code)
    this.entries.push({ ply: before.ply, side: before.cur, text: code, code, mana: [this.state.mana.w, this.state.mana.b] })
  }

  // MARK: End of game

  private endGame(reason: string, winner: Side | null) {
    if (this.finished) return
    this.finished = true
    this.endReason = reason
    this.winner = winner
    this.thinking = false
    this.aiToken++
    this.clearSelection()
    this.pendingCard = null
    this.pendingUlt = false
    this.cardTargets = []
    if (winner && (reason === 'mate' || reason === 'timeout' || reason === 'resigned')) {
      const loser: Side = winner === 'w' ? 'b' : 'w'
      const kind = reason === 'mate' ? 'mate' : reason === 'timeout' ? 'time' : 'resign'
      this.finisher = { sq: this.state.kingSquare(loser), winner, kind }
      const humanWon = this.isBotMode || this.online ? winner === this.human : true
      window.setTimeout(() => { sound(humanWon ? 'victory' : 'defeat'); haptic(humanWon ? 'victory' : 'defeat') }, 900)
    } else if (!winner && this.mode.kind !== 'tutorial' && ['stalemate', 'fifty', 'repetition', 'draw'].includes(reason)) {
      this.drawFinish = reason === 'draw' ? t('durch Einigung') : t(REASON_LONG[reason])
    }
    this.flushStats()
    this.emit()
    window.clearInterval(this.clockTimer)
    if (this.mode.kind === 'tutorial') { this.finishTutorial(); return }
    void this.finish()
  }

  private async finish() {
    const p0 = S.getProfile()
    S.clearGame()
    const winner = this.winner
    const humanOnline = this.mode.kind === 'online'
    let title: string
    let result: Result | null
    const reasonText = t(REASON[this.endReason ?? ''] ?? this.endReason ?? '')
    if (this.isBotMode || humanOnline || this.online) {
      if (winner) {
        result = winner === this.human ? 'win' : 'loss'
        title = result === 'win'
          ? this.mode.kind === 'ladder' ? t('{0} besiegt!', this.name(winner === 'w' ? 'b' : 'w')) : this.mode.kind === 'practice' ? t('Übung gewonnen!') : t('Du hast gewonnen!')
          : t('{0} gewinnt', this.name(winner))
      } else { result = 'draw'; title = t('Remis') }
    } else {
      result = winner ? (winner === 'w' ? 'win' : 'loss') : 'draw'
      title = winner ? t('{0} gewinnt!', winner === 'w' ? t('Weiß') : t('Schwarz')) : t('Remis')
    }
    let replayID: string | undefined
    if (this.actions.length) {
      replayID = S.storeReplay({ date: Date.now(), title, subtitle: (this.isBotMode ? t('gegen {0}', this.name(this.human === 'w' ? 'b' : 'w')) : t('Zu zweit')) + ' · ' + reasonText,
        human: this.human, decks: this.decks, ults: this.ults, actions: this.actions, mana: this.entries.map(e => e.mana),
        texts: this.entries.map(e => ({ side: e.side, text: e.text, card: e.card })) })
    }
    const chestsBefore = new Set(p0.chests.map(c => c.id))
    const skinBefore = this.bot ? S.isSkinUnlocked(this.bot) : true
    const roadBefore = new Set(S.claimableRoadSteps().map(s => s.trophies))
    const serverRated = !!this.online
    const bot = this.bot
    let delta = 0
    if (this.mode.kind !== 'practice' && result) {
      delta = S.record({
        result, rated: this.mode.kind === 'bot' && !serverRated,
        opponent: serverRated ? (this.online?.opponent.name ?? '') : bot ? botRecordName(bot) : 'Zu zweit',
        reason: REASON[this.endReason ?? ''] ?? '', moves: this.actions.length, cardsPlayed: this.cardsPlayedByHuman, replayID,
        countsForStats: this.mode.kind === 'ladder' || serverRated, opponentTrophies: bot ? botRating(bot) : undefined,
        matchId: this.online?.matchId,
      })
    }
    if (this.isBotMode && this.mode.kind !== 'practice' && result) {
      S.update(p => {
        if (result === 'win') {
          p.winStreak++
          p.bestWinStreak = Math.max(p.bestWinStreak, p.winStreak)
          if (this.endReason === 'mate') p.mateWins++
        } else if (result === 'loss') p.winStreak = 0
      })
    }
    let ladder: ReturnType<typeof S.recordLadderWin> | null = null
    if (this.mode.kind === 'ladder' && result === 'win' && bot) ladder = S.recordLadderWin(bot)
    let winChestsUsedUp = false
    if ((this.mode.kind === 'bot' || serverRated) && result === 'win') winChestsUsedUp = !S.grantWinChest()
    const lit = this.actions.length >= 10 ? S.registerActivity() : null
    if (this.isBotMode && this.mode.kind !== 'practice' && S.dailyChestReady()) S.claimDailyChest()
    const earned = S.getProfile().chests.filter(c => !chestsBefore.has(c.id))
    const roadReady = S.claimableRoadSteps().find(s => !roadBefore.has(s.trophies))?.trophies ?? null
    if (!this.finisher) {
      if (result === 'win' || (!this.isBotMode && !this.online && winner)) sound('victory')
      else if (result === 'loss') sound('defeat')
      else sound('notify')
    }
    const info: GameOverInfo = {
      title, subtitle: this.endReason === 'draw' ? t('durch Remis') : reasonText,
      result: this.isBotMode || this.online ? result : null, trophyDelta: delta,
      rated: this.mode.kind === 'bot' || serverRated, streakLit: lit, ladderXP: ladder?.xp ?? null,
      ladderUnlocked: ladder?.unlocked ? t(ladder.unlocked.name) : null,
      skinUnlocked: this.online || !bot ? null : (!skinBefore && S.isSkinUnlocked(bot) ? bot : null),
      chests: earned, winChestsUsedUp, roadReady, hasWinner: !!winner,
      opponent: this.online ? null : (this.isBotMode ? bot : null), disguise: this.online?.opponent ?? null,
      moveCount: this.entries.filter(e => e.side === this.human || !this.isBotMode).length, cardsPlayed: this.cardsPlayedByHuman,
      winnerColor: winner,
    }
    if (this.online?.bot && result) {
      const reported = await this.reportOnlineBot()
      // Only the server counts trophies. Network gone: nothing changes here; the server's count arrives with the next refresh.
      info.trophyDelta = reported ?? 0
    }
    // Against a person – or a stand-in the server already ended (45 s rule): the server's change.
    if (this.online && !this.online.bot) {
      const until = Date.now() + 2500
      while (!this.serverResult && Date.now() < until) await wait(100)
      const d = this.serverResult?.delta
      if (typeof d === 'number') {
        info.trophyDelta = d
        this.noteServerDelta(d)
      }
    }
    await wait(this.finisher ? 3200 : this.drawFinish ? 2200 : 900)
    this.gameOver = info
    this.emit()
  }

  /** The server scored the game: trophies come from the account (no adding here – that could count twice), the history shows the change. */
  private noteServerDelta(d: number) {
    if (d !== 0) S.update(p => { if (p.history[0] && p.history[0].trophyDelta === 0) p.history[0].trophyDelta = d })
    void Online.refreshAccount().then(() => Online.backupQuietly())
  }

  /** Back in a stand-in match: if the server already ended it (45 s without a heartbeat), show the loss without reporting again. */
  private async checkStandInStillActive() {
    if (!this.online) return
    try {
      const row = await Online.matchStatus(this.online.matchId)
      if (row.status !== 'active' && !this.finished) {
        const delta = this.human === 'w' ? row.trophy_delta_white : row.trophy_delta_black
        this.serverResult = { result: row.result ?? 'abandoned', winner: this.human === 'w' ? 'b' : 'w', delta: typeof delta === 'number' ? delta : null }
        this.online = { ...this.online, bot: false }
        this.endGame('timeout', this.human === 'w' ? 'b' : 'w')
      }
    } catch { /* offline: keep playing, the next report sorts it out */ }
  }

  private async reportOnlineBot(): Promise<number | null> {
    if (!this.online) return 0
    const outcome = this.endReason === 'resigned' ? 'resigned' : this.endReason === 'timeout' && this.winner !== this.human ? 'timeout' : 'final'
    try {
      const data = await Online.finishBot(this.online.matchId, this.actions, outcome)
      const d = this.human === 'w' ? data?.trophy_delta_white : data?.trophy_delta_black
      if (typeof d !== 'number') return null
      this.noteServerDelta(d)
      return d
    } catch (e) {
      if (!Online.isServerRejection(e)) return null
      // The server refused: usually it already scored the game (45 s without a heartbeat → loss). Show that change.
      try {
        const row = await Online.matchStatus(this.online.matchId)
        const d = this.human === 'w' ? row.trophy_delta_white : row.trophy_delta_black
        if (row.status !== 'active' && typeof d === 'number') { this.noteServerDelta(d); return d }
      } catch { /* offline */ }
      void Online.refreshAccount()
      return 0
    }
  }

  // MARK: Online human match

  private startOnline() {
    this.timers.push(window.setInterval(() => { void this.pulse() }, 2000))
    this.timers.push(window.setInterval(() => { void this.ping() }, 10_000))
    void this.ping()
    document.addEventListener('visibilitychange', this.onVisibleOnline)
  }
  /** Reopened from the Play tab after leaving the match. */
  noteResumed() {
    this.hint = t('Zurück in deiner Partie')
    if (this.online && !this.online.bot) { void this.ping(); void this.pulse() }
    this.emit()
  }
  /** Back in the tab: ask the server right away instead of waiting for the next 10 s beat (resumeOnlinePresence). */
  private onVisibleOnline = () => {
    if (document.visibilityState !== 'visible' || this.finished) return
    void this.ping()
    void this.pulse()
  }
  /** Sign of life, like pingHeartbeatOnce() in the app. */
  private async ping() {
    if (!this.online || this.finished) return
    const snap = await Online.heartbeat(this.online.matchId)
    if (!snap) { this.noteOwnDisconnect(); return }
    this.lastHeartbeatOK = Date.now()
    if (this.persistentNotice) { this.persistentNotice = false; this.onlineNotice = null; this.emit() }
    if (snap.status !== 'active') {
      if (this.online.bot) void this.checkStandInStillActive()
      else void this.pulse()
      return
    }
    if (this.online.bot || snap.opponentSilent === null) return
    if (snap.opponentSilent >= 45 && !this.silenceClaimed) {
      this.silenceClaimed = true
      void this.claimTimeout()
    } else if (snap.opponentSilent >= 15) {
      this.setPersistentNotice(t('Verbindung zum Gegner unterbrochen – noch {0} s', Math.max(0, 45 - snap.opponentSilent)))
    }
  }
  private noteOwnDisconnect() {
    if (!this.online || this.online.bot || this.lastHeartbeatOK === null || this.finished) return
    const left = Math.max(0, Math.floor(45 - (Date.now() - this.lastHeartbeatOK) / 1000))
    this.setPersistentNotice(t('Verbindung verloren – noch {0} s, um zurückzukommen', left))
  }
  private setPersistentNotice(text: string) {
    this.persistentNotice = true
    this.onlineNotice = text
    this.emit()
  }
  /** Once per browser: leaving for more than 45 s loses the game (explainOnlineLeave). */
  private explainOnlineLeave() {
    if (!this.online) return
    try {
      if (localStorage.getItem('rookraid.online.leaveOnce')) return
      localStorage.setItem('rookraid.online.leaveOnce', '1')
    } catch { return }
    this.hint = t('Verlässt du die App länger als 45 Sekunden, gilt die Partie als verloren.')
  }
  private sendOnline(code: string, ply: number) {
    const id = this.online!.matchId
    this.sending = this.sending.then(async () => {
      for (let attempt = 0; ; attempt++) {
        try { await Online.submitAction(id, ply, code); return } catch (e) {
          const refusal = e instanceof Online.SubmitError ? e.refusal : null
          if (refusal === 'out_of_sync' || refusal === 'illegal_action' || refusal === 'not_your_turn') {
            this.hint = t('Die Stellung wurde abgeglichen.')
            await this.pulse(true)
            return
          }
          if (refusal === 'timeout' || refusal === 'not_active') { await this.pulse(); return }
          if (attempt >= 4) { this.noteOwnDisconnect(); await this.pulse(); return }
          await new Promise(r => setTimeout(r, 1000))
        }
      }
    })
  }
  private async claimTimeout() {
    if (!this.online) return
    try { await Online.claimTimeout(this.online.matchId) } catch { /* the poll reads the result */ }
    await this.pulse()
  }
  private async pulse(forceRebuild = false) {
    if (!this.online || this.online.bot || this.finished) return
    try {
      const [codes, row] = await Promise.all([Online.fetchActions(this.online.matchId), Online.matchStatus(this.online.matchId)])
      if (forceRebuild) this.rebuild(codes)
      this.incomingDraw = (row.draw_offer_by === 'white' ? 'w' : row.draw_offer_by === 'black' ? 'b' : null) === (this.human === 'w' ? 'b' : 'w')
      if (codes.length > this.actions.length) {
        for (const code of codes.slice(this.actions.length)) {
          if (!this.commit(code, true)) { this.rebuild(codes); break }
        }
      } else if (codes.length < this.actions.length) this.rebuild(codes)
      if (row.clock_white_ms != null && row.clock_black_ms != null) {
        // Server clocks are the truth; keep the local countdown for the side to move.
        const serverW = row.clock_white_ms / 1000, serverB = row.clock_black_ms / 1000
        if (this.state.cur !== 'w') this.clocks.w = serverW
        if (this.state.cur !== 'b') this.clocks.b = serverB
      }
      if (row.status !== 'active') {
        const winner: Side | null = row.winner_color === 'white' ? 'w' : row.winner_color === 'black' ? 'b' : null
        const delta = this.human === 'w' ? row.trophy_delta_white : row.trophy_delta_black
        this.serverResult = { result: row.result ?? '', winner, delta: typeof delta === 'number' ? delta : null }
        // Like the app: the 45 s rule ("abandoned") counts as running out of time; draws keep their real reason.
        const r = row.result ?? ''
        const reason = r === 'timeout' || r === 'abandoned' ? (winner ? 'timeout' : 'draw') : r === 'resigned' || r === 'mate' ? r
          : r === 'stalemate' || r === 'fifty' || r === 'repetition' || r === 'aborted' ? r : 'draw'
        if (!this.finished) this.endGame(reason, winner)
        void Online.refreshAccount()
      }
      this.emit()
    } catch {
      this.notice(t('Keine Verbindung zum Server.'))
    }
  }
  private rebuild(codes: string[]) {
    this.state = this.freshState()
    this.actions = []
    this.entries = []
    for (const c of codes) this.replayCode(c)
    this.emit()
  }

  // MARK: Tutorial

  currentStep() { return tutorialSteps()[this.tutorialIndex] }
  private tutorialAllows(a: { kind: 'move'; from: string; to: string }) {
    const exp = this.currentStep()?.expect
    return !!exp && exp.kind === 'move' && exp.from === a.from && exp.to === a.to
  }
  private tutorialNudge() {
    const nudges = ['Fast! Folge dem goldenen Leuchten.', 'Nicht ganz – schau auf die goldenen Felder.', "Probier's mit dem leuchtenden Ziel!"]
    haptic('invalid')
    this.questNudge++
    this.questNudgeText = t(nudges[this.questNudge % nudges.length])
    this.clearSelection()
    this.emit()
    const n = this.questNudge
    window.setTimeout(() => { if (this.questNudge === n) { this.questNudgeText = null; this.emit() } }, 2200)
  }
  private showTutorialStep() {
    const step = this.currentStep()
    if (!step) return
    if (step.fillMana) {
      const before = this.state.mana.w
      this.state.mana.w = 10
      if (10 > before) this.showManaFloat('w', 10 - before, t('Bonus'))
      sound('summon')
    }
    this.tutorialSquares = []
    this.tutorialCard = null
    this.tutorialUlt = false
    const e = step.expect
    if (e.kind === 'move') this.tutorialSquares = [sqIndex(e.from), sqIndex(e.to)]
    if (e.kind === 'card') { this.tutorialCard = e.card; this.tutorialSquares = e.target ? [sqIndex(e.target)] : [] }
    if (e.kind === 'ult') { this.tutorialUlt = true; this.tutorialSquares = e.target ? [sqIndex(e.target)] : [] }
    this.tutorialHighlight = !!step.highlight
    this.hint = null
    this.questNudgeText = null
    this.questMana = this.state.mana.w
    this.coach = { step: this.tutorialIndex, total: tutorialSteps().length, icon: step.icon, title: t(step.title), text: t(step.text), done: false, praise: '', rewards: [] }
    this.emit()
  }
  skipTutorial() {
    S.update(p => { p.tutorialSeen = true })
    S.grantTutorialChest()
    this.coach = null
    this.closeRequested = true
    this.emit()
  }
  private tutorialAfterAction(side: Side) {
    if (side === 'w') {
      const step = this.currentStep()
      if (!step || !this.coach) return
      this.tutorialSquares = []
      this.tutorialCard = null
      this.tutorialUlt = false
      this.tutorialHighlight = false
      const rewards: Coach['rewards'] = []
      if (step.reward) rewards.push({ ...step.reward, text: t(step.reward.text) })
      const mana = this.state.mana.w - this.questMana
      if (mana > 0) rewards.push({ icon: 'drop', text: t('+{0} Mana', mana), tint: 'mana' })
      if (!rewards.length) rewards.push({ icon: 'star', text: t('Weiter so'), tint: 'gold' })
      this.coach = { ...this.coach, done: true, praise: t(step.praise), rewards: rewards.slice(0, 2) }
      sound('notify'); haptic('victory')
      if (this.state.cur === 'w' && !this.finished) {
        window.setTimeout(() => { if (!this.finished) { this.tutorialIndex++; this.showTutorialStep() } }, 1300)
      }
    } else {
      window.setTimeout(() => { if (!this.finished) { this.tutorialIndex++; this.showTutorialStep() } }, 450)
    }
  }
  private playTutorialReply() {
    const reply = this.currentStep()?.reply
    if (!reply) return
    this.thinking = true
    this.emit()
    window.setTimeout(() => {
      this.thinking = false
      if (!this.finished) this.commit(reply, true)
    }, 900)
  }
  private finishTutorial() {
    S.update(p => { p.tutorialSeen = true })
    S.grantTutorialChest()
    S.addXP(50)
    const lit = S.registerActivity()
    this.tutorialSquares = []
    this.tutorialHighlight = false
    const last = tutorialSteps()[tutorialSteps().length - 1]
    if (this.coach) {
      this.coach = {
        ...this.coach, done: true, praise: t(last.praise),
        rewards: [{ icon: 'sparkles', text: t('+50 XP'), tint: 'mana' }, { icon: 'box', text: t('Erste Truhe'), tint: 'gold' },
          ...(lit !== null ? [{ icon: 'flame', text: t('Flamme'), tint: 'gold' as const }] : [])],
      }
    }
    this.emit()
    window.setTimeout(() => { this.tutorialComplete = { xp: 50, streak: lit }; this.emit() }, 2900)
  }
}

export function useController(c: GameController) {
  useSyncExternalStore(c.subscribe, c.getVersion)
  return c
}

export const isCardId = isCard
export function fenState(fen: string) { return fromFEN(fen) }
