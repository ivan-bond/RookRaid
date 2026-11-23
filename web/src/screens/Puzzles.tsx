// PuzzleViews.swift: hub (redesign V2), adventure sheet, puzzle player and the 3-minute puzzle rush.
import { useEffect, useMemo, useRef, useState } from 'react'
import { pieceImage } from '../art'
import { BOARD_COLORS, CARDS, KEEPS_TURN, ULTS, PUZZLES_PER_CHEST, cardCost, ultCost, type CardId, type UltId } from '../game/catalog'
import { apply, E, fromFEN, isFrozen, isShielded, sqIndex, type MatchState, type Move, type Side } from '../engine'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeOverlay, closeSheet, openChests, openOverlay, openSheet } from '../nav'
import { Icon } from '../ui/Icon'
import { CardView, ChestView, Confetti, ManaDrop, Sheet, UltimateCard } from '../ui/kit'
import { FlameBadge } from './Home'
import { DSProgress, IconTile, ListGroup, ListRow, PrimaryButton, PrimaryDock, ScreenHeader, SectionLabel } from '../ui/ds'

const GROUPS: Array<{ key: string; title: string; sub: string; color: string; filter: (p: S.Puzzle) => boolean }> = [
  { key: 'rr', title: 'Karten-Matts', sub: 'Erst die Karte, dann das Matt', color: '#6E9BF0', filter: p => S.isRookRaidPuzzle(p) },
  { key: '1', title: 'Leicht', sub: 'Klassisch · 10 XP', color: '#FFF4DC', filter: p => !S.isRookRaidPuzzle(p) && p.difficulty === 1 },
  { key: '2', title: 'Mittel', sub: 'Klassisch · 20 XP', color: '#F2C14E', filter: p => !S.isRookRaidPuzzle(p) && p.difficulty === 2 },
  { key: '3', title: 'Schwer', sub: 'Klassisch · 35 XP', color: '#E0413A', filter: p => !S.isRookRaidPuzzle(p) && p.difficulty >= 3 },
]

export const goalTitle = (p: S.Puzzle, t: (k: string, ...a: Array<string | number>) => string) =>
  p.goal === 'mate' ? t('Matt in {0}', p.n ?? 1) : p.goal === 'material' ? t('Gewinne Material') : t('Erreiche {0} Felder', p.n ?? 0)
const diffName = (d: number) => (d === 1 ? 'Leicht' : d === 2 ? 'Mittel' : 'Schwer')

export function PuzzleHub() {
  const p = S.useProfile()
  const { t } = useI18n()
  const lp = S.levelProgress(p)
  const daily = S.dailyPuzzle()
  const next = useMemo(() => S.nextPuzzle(), [p.solvedPuzzles.length])
  const filled = p.solvedPuzzles.length % PUZZLES_PER_CHEST
  const dailyOpen = S.dailyBonusAvailable(p)
  const openNext = () => openOverlay({ kind: 'puzzle', puzzle: next, daily: false })
  return (
    <div className="page ds-page">
      <div className="ds-inner">
        <ScreenHeader title={t('Puzzles')} />
        <div className="pz-next">
          <button className="pz-next-board press" onClick={openNext} aria-label={t('Nächstes Puzzle: {0}', goalTitle(next, t))}><PuzzleThumb p={next} size={112} /></button>
          <div className="grow col" style={{ gap: 4, minWidth: 0 }}>
            <span className="pz-next-k">{t('NÄCHSTES PUZZLE')}</span>
            <b className="pz-next-t">{goalTitle(next, t)}</b>
            <span style={{ fontSize: 14, fontWeight: 600 }}>
              <span style={{ color: 'var(--ds-muted)' }}>{t(diffName(next.difficulty))}{S.isRookRaidPuzzle(next) ? ' · ' + t('mit Karten') : ''}</span>
              {!S.isSolved(next) && <span style={{ color: 'var(--ds-purple)' }}> · {t('+{0} XP', S.puzzleXP(next))}</span>}
            </span>
            <span className="row" style={{ marginTop: 6 }}>
              <b className="r grow" style={{ fontSize: 13 }}>{t('Level {0}', lp.level)}</b>
              <span className="num" style={{ fontSize: 13, color: 'var(--ds-muted)', fontWeight: 600 }}>{t('noch {0} XP', lp.remaining)}</span>
            </span>
            <DSProgress value={lp.fraction} color="var(--ds-purple)" />
          </div>
        </div>
        <SectionLabel text={t('Mehr Training')} />
        <ListGroup>
          <ListRow icon={<IconTile icon="bolt" color="var(--ds-flame)" />} title={t('Puzzle-Rausch')} sub={t('3 Minuten, 3 Leben')}
            trailing={p.rushBest > 0 ? { kind: 'value', value: p.rushBest } : { kind: 'chevron' }} onClick={() => openOverlay({ kind: 'rush' })} />
          <ListRow icon={<IconTile icon="calendar" color="var(--ds-gold)" />} title={t('Tagespuzzle')}
            sub={dailyOpen ? t('+15 XP Bonus') : t('Für heute erledigt · +15 XP')} trailing={dailyOpen ? { kind: 'chevron' } : { kind: 'done' }}
            onClick={() => openOverlay({ kind: 'puzzle', puzzle: daily, daily: true })} />
          <ListRow icon={<IconTile icon="map" color="var(--ds-purple)" />} title={t('Abenteuer')} sub={t('Wähle dein Abenteuer')}
            trailing={{ kind: 'value', value: `${p.solvedPuzzles.length}/${S.PUZZLES.length}` }} onClick={() => openSheet('adventure')} />
          <ListRow icon={<span className="ds-tile"><ChestView rarity={1} size={34} glow={filled === PUZZLES_PER_CHEST - 1 ? 0.6 : 0} /></span>} title={t('Rätseltruhe')}
            trailing={{ kind: 'value', value: `${filled}/${PUZZLES_PER_CHEST}`, chevron: false }}
            label={PUZZLES_PER_CHEST - filled === 1 ? t('Nächstes Puzzle: Rätseltruhe!') : t('Noch {0} bis zur Rätseltruhe', PUZZLES_PER_CHEST - filled)}>
            <span style={{ marginTop: 6 }}><DSProgress value={filled / PUZZLES_PER_CHEST} color="var(--ds-purple)" /></span>
          </ListRow>
        </ListGroup>
      </div>
      <PrimaryDock><PrimaryButton title={t('Puzzles lösen')} icon="play" onClick={openNext} /></PrimaryDock>
    </div>
  )
}

/** "Wähle dein Abenteuer": the four puzzle groups with their puzzles (a sheet, like the app). */
export function AdventureSheet() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [group, setGroup] = useState<string>('rr')
  const list = S.PUZZLES.filter(GROUPS.find(g => g.key === group)!.filter)
  const open = (z: S.Puzzle) => { closeSheet(); openOverlay({ kind: 'puzzle', puzzle: z, daily: false }) }
  return (
    <Sheet title={t('Wähle dein Abenteuer')} onClose={closeSheet} wide tall>
      <div className="col" style={{ gap: 14, padding: '4px 16px 20px' }}>
        <div className="group-tabs">
          {GROUPS.map(g => {
            const all = S.PUZZLES.filter(g.filter)
            const n = all.filter(z => p.solvedPuzzles.includes(z.id)).length
            return (
              <button key={g.key} className={`group-tab${group === g.key ? ' on' : ''}`} onClick={() => setGroup(g.key)} style={{ ['--tint' as string]: g.color }}>
                <b>{t(g.title)}</b><span>{t(g.sub)}</span>
                <span className="group-progress"><i style={{ width: `${(n / all.length) * 100}%` }} /></span>
                <span className="num muted" style={{ fontSize: 11 }}>{n}/{all.length}</span>
              </button>
            )
          })}
        </div>
        <div className="puzzle-grid">
          {list.map((z, i) => {
            const done = p.solvedPuzzles.includes(z.id)
            return (
              <button key={z.id} className={`puzzle-tile press${done ? ' done' : ''}`} onClick={() => open(z)}
                aria-label={t('Puzzle {0}, {1}{2}', i + 1, goalTitle(z, t), done ? t(', gelöst') : '')}>
                <PuzzleThumb p={z} size={120} />
                <span className="pt-info">
                  <b className="clip1">{t(z.title)}</b>
                  <span className="muted clip1">{goalTitle(z, t)} · {S.puzzleXP(z)} XP</span>
                </span>
                {done && <span className="pt-done"><Icon name="check" size={12} /></span>}
                {(z.hand.length > 0 || z.ultimate) && <span className="pt-card"><Icon name={z.ultimate ? ULTS[z.ultimate as UltId].icon : CARDS[(z.lines[0][0].startsWith('card:') ? z.lines[0][0].slice(5).split('@')[0] : z.hand[0]) as CardId]?.icon ?? 'stack'} size={11} /></span>}
              </button>
            )
          })}
        </div>
      </div>
    </Sheet>
  )
}

export function PuzzleThumb({ p, size }: { p: S.Puzzle; size: number }) {
  const s = useMemo(() => fromFEN(p.fen), [p.fen])
  const flip = s.cur === 'b'
  const colors = BOARD_COLORS[S.getProfile().settings.boardTheme] ?? BOARD_COLORS.green
  return (
    <span className="pthumb" style={{ width: size, height: size }}>
      {Array.from({ length: 64 }, (_, k) => {
        const i = flip ? 63 - k : k
        const piece = s.b[i]
        const light = ((i >> 3) + (i & 7)) % 2 === 0
        return <span key={k} style={{ background: light ? colors.light : colors.dark }}>{piece && <img src={pieceImage(piece.c as Side, piece.t)} alt="" />}</span>
      })}
    </span>
  )
}

// MARK: Puzzle run (PuzzleRun in Puzzle.swift)

class Run {
  state: MatchState
  played: string[] = []
  replies = 0
  constructor(public p: S.Puzzle) {
    const s = fromFEN(p.fen)
    const me = s.cur
    s.decks = { w: { hand: [], queue: [] }, b: { hand: [], queue: [] } } as MatchState['decks']
    if (p.hand.length) s.decks[me] = { hand: [...p.hand], queue: [] }
    if (p.ultimate) s.ults = { ...s.ults, [me]: p.ultimate } as MatchState['ults']
    s.mana = { ...s.mana, [me]: p.mana } as MatchState['mana']
    this.state = s
  }
  get player(): Side { return this.p.fen.split(' ')[1] === 'b' ? 'b' : 'w' }
  private matching() { return this.p.lines.filter(l => l.length >= this.played.length && this.played.every((x, i) => l[i] === x)) }
  hint(): string | null {
    const idx = this.played.length
    return this.matching().find(l => l.length > idx)?.[idx] ?? null
  }
  attempt(code: string): 'wrong' | 'solved' | 'same' | { reply: string } {
    const after = this.state.clone()
    if (!apply(after, code)) return 'wrong'
    const idx = this.played.length
    if (this.p.goal === 'mate' && after.status() === 'mate') { this.state = after; this.played.push(code); return 'solved' }
    if (this.p.goal === 'territory') {
      if (after.territory(this.player) >= (this.p.n ?? 99)) { this.state = after; this.played.push(code); return 'solved' }
      return 'wrong'
    }
    const cands = this.matching().filter(l => l.length > idx)
    let line = cands.find(l => l[idx] === code || l[idx].slice(0, 4) === code.slice(0, 4) && !code.includes(':') && l[idx].length === code.length)
    if (!line && this.p.goal === 'material' && !code.includes(':') && this.state.b[sqIndex(code.slice(2, 4))]) {
      line = cands.find(l => l.length === idx + 1 && l[idx].slice(2, 4) === code.slice(2, 4))
    }
    if (!line) {
      if (this.p.goal === 'mate' && (this.p.n ?? 1) - this.replies === 2 && after.cur !== this.player) {
        const reply = toughestReply(after)
        if (reply) { this.state = after; this.played.push(code); return { reply } }
      }
      return 'wrong'
    }
    this.state = after
    this.played.push(code)
    if (this.state.cur === this.player && this.state.bonus) return 'same'
    if (line.length > this.played.length) return { reply: line[this.played.length] }
    if (this.p.goal === 'material') return 'solved'
    return 'wrong'
  }
  applyReply(code: string) { apply(this.state, code); this.played.push(code); this.replies++ }
}

function toughestReply(s: MatchState): string | null {
  const replies = s.allLegal(s.cur)
  let best: string | null = null
  let fewest = Infinity
  for (const r of replies) {
    const c = s.clone()
    const code = E.uci(c, r)
    apply(c, code)
    let mates = 0
    for (const m of c.allLegal(c.cur)) {
      const d = c.clone()
      apply(d, E.uci(d, m))
      if (d.status() === 'mate') { mates++; if (mates >= fewest) break }
    }
    if (mates === 0) return null
    if (mates < fewest) { fewest = mates; best = code }
  }
  return best
}

type T = (k: string, ...a: Array<string | number>) => string
/** "Weiß am Zug · Matt in 2" (PuzzleViewModel.prompt in the app). */
const promptFor = (z: S.Puzzle, t: T) => t('{0} am Zug · {1}', z.fen.split(' ')[1] === 'b' ? t('Schwarz') : t('Weiß'), goalTitle(z, t))
/** First line under the board (PuzzleViewModel.instruction). */
function instructionFor(z: S.Puzzle, t: T): string {
  if (z.goal === 'territory') return t('Erreiche {0} Felder', z.n ?? 0)
  if (z.goal === 'mate') {
    if (z.ultimate) return t('Deine Ultimate ist geladen. Nutze sie – oder deine Karten.')
    if ((z.n ?? 1) === 1 && z.hand.some(c => KEEPS_TURN[c])) return t('Ein Zug allein reicht nicht – aber nach Schild oder Frost darfst du noch ziehen.')
    if (z.hand.length) return t('Ein Zug allein reicht nicht. Welche Karte bereitet das Matt vor?')
  }
  return promptFor(z, t)
}
/** Mate puzzles don't store the final move: the first mating move (mateMove in the app). */
function mateMove(s: MatchState, me: Side): string | null {
  for (const m of s.allLegal(me)) {
    const c = s.clone()
    const code = E.uci(c, m)
    if (apply(c, code) && c.status() === 'mate') return code
  }
  return null
}
const wait = (ms: number) => new Promise(r => setTimeout(r, ms))

export function PuzzlePlayer({ puzzle, daily, onDone }: { puzzle: S.Puzzle; daily: boolean; onDone?: (solved: boolean) => void }) {
  const { t } = useI18n()
  const [z, setZ] = useState(puzzle)
  const [run, setRun] = useState(() => new Run(puzzle))
  const [, force] = useState(0)
  const [selected, setSelected] = useState<number | null>(null)
  const [pending, setPending] = useState<string | null>(null)
  const [wrong, setWrong] = useState(0)
  const [mistakes, setMistakes] = useState(0)
  const [hinted, setHinted] = useState(false)
  const [showHint, setShowHint] = useState<string | null>(null)
  const [reward, setReward] = useState<S.PuzzleReward | null>(null)
  const [solvedState, setSolved] = useState(false)
  const [revealed, setRevealed] = useState(false)
  const [busy, setBusy] = useState(false)
  const [promo, setPromo] = useState<Move | null>(null)
  const [msg, setMsg] = useState(() => instructionFor(puzzle, t))
  /** The wrong move, shown for a moment before it is taken back (like the app). */
  const [preview, setPreview] = useState<MatchState | null>(null)
  const rush = !!onDone
  const s = preview ?? run.state
  const me = run.player
  const mistake = mistakes > 0
  const canInteract = !busy && !solvedState && !revealed && !preview && run.state.cur === me

  const restart = (next: S.Puzzle) => {
    setZ(next); setRun(new Run(next)); setSelected(null); setPending(null); setMistakes(0); setHinted(false); setShowHint(null)
    setReward(null); setSolved(false); setRevealed(false); setBusy(false); setPreview(null); setMsg(instructionFor(next, t))
  }
  const cancelPending = () => { setPending(null); setMsg(instructionFor(z, t)) }
  const fail = (code: string) => {
    sound('trap'); haptic('invalid')
    setWrong(w => w + 1)
    setSelected(null); setPending(null)
    const n = mistakes + 1
    setMistakes(n)
    if (rush) { onDone?.(false); return }
    const pv = run.state.clone()
    const legal = apply(pv, code)
    if (z.goal === 'territory') setMsg(t('Damit hast du {0} Felder – es müssen {1} sein.', (legal ? pv : run.state).territory(me), z.n ?? 0))
    else if (!code.startsWith('card:') && !code.startsWith('ult:')) setMsg(n >= 2 ? t('Noch nicht. Tipp: Nutze den Hinweis.') : t('Das ist es nicht – versuch es noch einmal.'))
    else setMsg(t('Diese Aktion führt nicht zum Ziel. Versuch es noch einmal.'))
    if (legal) { setPreview(pv); window.setTimeout(() => setPreview(null), 900) }
  }
  /** Message after a successful action (show() in the app). */
  const actionMessage = (code: string, before: MatchState) => {
    if (code.startsWith('card:')) setMsg(t('{0} gespielt.', t(CARDS[code.slice(5).split('@')[0] as CardId]?.name ?? '')))
    else if (code.startsWith('ult:')) { const u = before.ults[me]; setMsg(t('{0} eingesetzt!', u ? t(ULTS[u as UltId].name) : t('Ultimate'))) }
  }
  const act = (code: string) => {
    if (busy || solvedState || revealed) return
    const before = run.state.clone()
    const res = run.attempt(code)
    setSelected(null); setPending(null); setShowHint(null)
    if (res === 'wrong') { fail(code); force(x => x + 1); return }
    sound(code.startsWith('card:') || code.startsWith('ult:') ? 'card' : before.b[sqIndex(code.slice(2, 4))] ? 'capture' : 'move')
    actionMessage(code, before)
    if (res === 'solved') {
      setSolved(true); sound('victory'); haptic('victory')
      if (rush) { window.setTimeout(() => onDone?.(true), 500); force(x => x + 1); return }
      setMsg(z.goal === 'territory' ? t('Geschafft: {0} Felder!', run.state.territory(me)) : t('Gelöst!'))
      const r = S.solvePuzzle(z, !mistake && !hinted, daily)
      window.setTimeout(() => setReward(r), 700)
    } else if (res === 'same') {
      setMsg(t('Richtig! Jetzt noch dein Figurzug.'))
    } else {
      setMsg(t('Richtig! Weiter so …'))
      setBusy(true)
      window.setTimeout(() => { run.applyReply(res.reply); sound('move'); setBusy(false); setMsg(t('Du bist dran – finde den nächsten Zug.')); force(x => x + 1) }, 750)
    }
    force(x => x + 1)
  }
  const tap = (i: number) => {
    if (!canInteract) return
    if (pending) {
      const targets = pending === 'ult' ? s.ultTargets(me) : s.targets(pending, me)
      if (targets.includes(i)) act(pending === 'ult' ? `ult:${s.ults[me]}@${E.sqName(i)}` : `card:${pending}@${E.sqName(i)}`)
      else cancelPending()
      return
    }
    if (selected !== null) {
      const m = s.legalMoves(selected).find(x => x.t === i)
      if (m) {
        const pc = s.b[selected]
        if (pc?.t === 'p' && (i >> 3) === (pc.c === 'w' ? 0 : 7)) { setPromo(m); return }
        act(E.uci(s, m)); return
      }
    }
    const pc = s.b[i]
    if (pc && pc.c === me && selected !== i) {
      setSelected(i)
      if (s.isBonusLocked(i)) { setMsg(t('Die geschützte Figur bleibt in diesem Zug stehen – zieh eine andere.')); haptic('invalid') }
    } else setSelected(null)
  }
  const tapCard = (card: string) => {
    if (!canInteract) return
    if (pending === card) { cancelPending(); return }
    setSelected(null)
    const name = t(CARDS[card as CardId].name)
    if (s.mana[me] < cardCost(card)) { setMsg(t('Zu wenig Mana für {0} ({1}).', name, cardCost(card))); haptic('invalid'); return }
    if (!s.canPlay(card, me)) { setMsg(t('{0} hat hier kein gültiges Ziel.', name)); haptic('invalid'); return }
    if (E.NO_TARGET[card]) { act('card:' + card); return }
    setPending(card)
    setMsg(`${name}: ${t(CARDS[card as CardId].prompt || CARDS[card as CardId].text)}`)
  }
  const tapUlt = () => {
    const u = s.ults[me]
    if (!u || !canInteract) return
    if (pending === 'ult') { cancelPending(); return }
    setSelected(null)
    if (s.mana[me] < ultCost(u)) { setMsg(t('Die Ultimate braucht {0} Mana.', ultCost(u))); haptic('invalid'); return }
    if (!s.canUseUlt(me)) { setMsg(t('{0} ist hier nicht möglich.', t(ULTS[u as UltId].name))); haptic('invalid'); return }
    if (!E.ultNeedsTarget(u)) { act('ult:' + u); return }
    setPending('ult')
    setMsg(t(ULTS[u as UltId].prompt || ULTS[u as UltId].text))
  }
  const nextAction = () => run.hint() ?? (z.goal === 'mate' ? mateMove(run.state, me) : null)
  const hint = () => {
    if (!canInteract) return
    const h = nextAction()
    if (!h) return
    setHinted(true)
    if (!rush) S.breakPuzzleStreak()
    setShowHint(h)
    haptic('tick')
    if (h.startsWith('card:')) {
      const [c, target] = h.slice(5).split('@')
      setMsg(t('Hinweis: Spiele {0}', t(CARDS[c as CardId].name)) + (target ? t(' auf das markierte Feld.') : '.'))
    } else if (h.startsWith('ult:')) setMsg(t('Hinweis: Jetzt ist der Moment für deine Ultimate.'))
    else setMsg(t('Hinweis: Diese Figur ist der Schlüssel.'))
  }
  /** Plays the whole solution (revealSolution in the app). No XP afterwards. */
  const solution = async () => {
    if (!canInteract) return
    setPending(null); setSelected(null); setShowHint(null)
    setRevealed(true)
    S.breakPuzzleStreak()
    setMsg(t("So geht's:"))
    for (;;) {
      const h = nextAction()
      if (!h) break
      const before = run.state.clone()
      const res = run.attempt(h)
      if (res === 'wrong') break
      sound(h.startsWith('card:') || h.startsWith('ult:') ? 'card' : before.b[sqIndex(h.slice(2, 4))] ? 'capture' : 'move')
      actionMessage(h, before)
      force(x => x + 1)
      if (res === 'same') { await wait(800); continue }
      if (res === 'solved') break
      await wait(900)
      run.applyReply(res.reply); sound('move'); force(x => x + 1)
      await wait(900)
    }
    setMsg(t('Lösung gezeigt – probier das nächste Puzzle.'))
  }
  /** Next unsolved puzzle after this one, otherwise simply the next (next() in the app). */
  const nextAfter = () => {
    const i = S.PUZZLES.findIndex(x => x.id === z.id)
    const rest = [...S.PUZZLES.slice(i + 1), ...S.PUZZLES.slice(0, Math.max(0, i))]
    return rest.find(x => !S.isSolved(x)) ?? rest[0] ?? z
  }
  const targets = pending ? (pending === 'ult' ? s.ultTargets(me) : s.targets(pending, me)) : selected !== null ? s.legalMoves(selected).map(m => m.t) : []
  // Hint like the app: a move marks only the piece that is the key, a card or ultimate its target square.
  const hintSquares = showHint ? (showHint.includes('@') ? [sqIndex(showHint.split('@')[1])] : showHint.includes(':') ? [] : [sqIndex(showHint.slice(0, 2))]) : []
  const hintCard = showHint?.startsWith('card:') ? showHint.slice(5).split('@')[0] : showHint?.startsWith('ult:') ? 'ult' : null
  const nextOpen = S.nextPuzzle()
  // What this puzzle is worth right now (xpChip in the app)
  const solvedBefore = S.isSolved(z)
  const half = mistake || hinted
  const xpTotal = (solvedBefore ? 0 : half ? Math.floor(S.puzzleXP(z) / 2) : S.puzzleXP(z)) + (daily && S.dailyBonusAvailable() ? 15 : 0)

  const body = (
    <div className="pz-body">
      <div className="pz-prompt">
        <span className={`pz-side ${me}`} />
        <b className="grow">{promptFor(z, t)}</b>
        {!rush && <span className={`pz-xp${xpTotal > 0 ? '' : ' none'}`}><Icon name={xpTotal > 0 ? 'sparkles' : 'check'} size={10} />{xpTotal > 0 ? t('+{0} XP', xpTotal) : t('Gelöst')}{half && xpTotal > 0 ? ' ½' : ''}</span>}
      </div>
      {!rush && <p className="pz-msg" key={msg + wrong}>{msg}</p>}
      <PzBoard s={s} flip={me === 'b'} selected={selected} targets={targets} card={!!pending} hint={hintSquares} wrong={wrong} onTap={tap} />
      {(z.hand.length > 0 || z.ultimate) && (
        <div className="pz-hand">
          <div className="row" style={{ gap: 6 }}><ManaDrop text={s.mana[me]} size={24} style={{ position: 'relative', left: 0, top: 0 }} /><span className="dim" style={{ fontSize: 12 }}>{t('{0} Mana', s.mana[me])}</span></div>
          <div className="hand-row">
            {s.ults[me] && <div style={{ width: 62 }} onClick={tapUlt}><UltimateCard ult={s.ults[me]} mana={s.mana[me]} usable={s.canUseUlt(me)} selected={pending === 'ult'} spotlight={hintCard === 'ult'} /></div>}
            {s.decks[me]?.hand.map((c, i) => (
              <div key={i} className="hand-slot" onClick={() => tapCard(c)}>
                <CardView card={c} playable={s.canPlay(c, me)} selected={pending === c} spotlight={hintCard === c} />
              </div>
            ))}
          </div>
        </div>
      )}
      {!rush && !solvedState && (
        <div className="row pz-actions">
          <button className="chunky gray sm" onClick={hint} disabled={!canInteract}><Icon name="sparkles" size={15} />{t('Hinweis')}</button>
          <button className="chunky gray sm" onClick={() => void solution()} disabled={!canInteract}><Icon name="eye" size={15} />{t('Lösung')}</button>
          {revealed && <button className="chunky gray sm" onClick={() => restart(nextAfter())}><Icon name="arrowRight" size={15} />{t('Weiter')}</button>}
        </div>
      )}
    </div>
  )

  if (rush) return body
  return (
    <div className="full puzzle-full">
      <div className="g-top">
        <button className="icon-btn" onClick={closeOverlay} aria-label={t('Schließen')}><Icon name="xmark" size={18} /></button>
        <div className="g-title"><b>{daily ? t('Tagespuzzle') : t(z.title)}</b><span>{t('{0} · {1} XP', t(diffName(z.difficulty)), S.puzzleXP(z))}</span></div>
        <FlameBadge />
      </div>
      <div className="pz-scroll">{body}</div>
      {promo && (
        <div className="overlay-center" onClick={() => setPromo(null)}>
          <div className="promo pop-in">
            <div className="promo-grid">{['q', 'r', 'b', 'n'].map(x => <button key={x} className="promo-btn" onClick={() => { const m = promo; setPromo(null); act(E.sqName(m.f) + E.sqName(m.t) + x) }}><img src={pieceImage(me, x)} alt="" /></button>)}</div>
          </div>
        </div>
      )}
      {reward && (
        <div className="overlay-center fade-in">
          <Confetti />
          <div className="pz-reward pop-in">
            <Icon name="checkCircle" size={54} color="var(--gold)" />
            <b className="title-l">{t('Gelöst!')}</b>
            {reward.firstSolve ? (
              <>
                <b className="r" style={{ fontSize: 30, color: 'var(--mana-light)' }}>{t('+{0} XP', reward.xp + reward.dailyBonus)}</b>
                {reward.dailyBonus > 0 && <span className="dim">{t('inklusive {0} XP Tagesbonus', reward.dailyBonus)}</span>}
                {(mistake || hinted) && <span className="dim">{t('Halbe XP wegen Fehler oder Hinweis')}</span>}
              </>
            ) : <span className="dim">{reward.dailyBonus ? t('+15 XP Bonus') : t('Schon einmal gelöst – keine neuen XP')}</span>}
            <div className="row" style={{ gap: 6, flexWrap: 'wrap', justifyContent: 'center' }}>
              {reward.puzzleStreak > 1 && <span className="capsule chip gold"><Icon name="flame" size={10} />{t('{0} in Folge!', reward.puzzleStreak)}</span>}
              {reward.levelUp && <span className="capsule chip gold"><Icon name="star" size={10} />{t('Level {0} erreicht!', reward.levelUp)}</span>}
              {reward.streakLit !== null && <span className="capsule chip" style={{ color: '#FF7A2F' }}><Icon name="flame" size={10} />{t('Flamme entzündet!')}</span>}
            </div>
            {reward.chest && S.pendingChests().some(c => c.source === 'puzzle') && (
              <button className="chunky gold sm pulse-gold" onClick={() => { const c = S.pendingChests().find(x => x.source === 'puzzle'); if (c) { closeOverlay(); openChests(c) } }}>{t('Rätseltruhe')} · {t('Öffnen!')}</button>
            )}
            {!reward.chest && (S.getProfile().solvedPuzzles.length + 1) % PUZZLES_PER_CHEST === 0 && <span className="capsule chip gold">{t('Nächstes Puzzle: Rätseltruhe!')}</span>}
            <button className="chunky" onClick={() => restart(nextOpen)}>{t('Nächstes Puzzle')}<Icon name="chevronRight" size={16} /></button>
            <button className="ghost" onClick={closeOverlay}>{t('Zur Übersicht')}</button>
          </div>
        </div>
      )}
    </div>
  )
}

function PzBoard({ s, flip, selected, targets, card, hint, wrong, onTap }: {
  s: MatchState; flip: boolean; selected: number | null; targets: number[]; card: boolean; hint: number[]; wrong: number; onTap: (i: number) => void
}) {
  const colors = BOARD_COLORS[S.getProfile().settings.boardTheme] ?? BOARD_COLORS.green
  const last = s.last
  return (
    <div className={`board pz-board${wrong ? ' wrong-' + (wrong % 2) : ''}`}>
      <div className="board-zoom">
        {Array.from({ length: 64 }, (_, k) => {
          const i = flip ? 63 - k : k
          const r = i >> 3, f = i & 7
          const light = (r + f) % 2 === 0
          const p = s.b[i]
          const x = (k & 7) * 12.5, y = (k >> 3) * 12.5
          return (
            <div key={i} className="sq" style={{ left: `${x}%`, top: `${y}%`, background: light ? colors.light : colors.dark }} onClick={() => onTap(i)}>
              {(selected === i || (last && (last.f === i || last.t === i))) && <i className="sq-hi" />}
              {hint.includes(i) && <i className="tut-pulse" style={{ left: 0, top: 0, width: '100%', height: '100%' }} />}
              {p && <div className="pc static">
                {isShielded(p, s.ply) && <i className="pc-shield" />}
                <img src={pieceImage(p.c as Side, p.t)} alt="" draggable={false} />
                {isFrozen(p, s.ply) && <i className="pc-frost" />}
              </div>}
              {targets.includes(i) && (card ? <i className="card-target" style={{ left: 0, top: 0, width: '100%', height: '100%' }} /> : <i className={p ? 'dot ring' : 'dot'} style={{ left: 0, top: 0 }} />)}
              {(k & 7) === 0 && <span className="coord rank" style={{ color: light ? colors.dark : colors.light }}>{8 - r}</span>}
              {(k >> 3) === 7 && <span className="coord file" style={{ color: light ? colors.dark : colors.light }}>{'abcdefgh'[f]}</span>}
            </div>
          )
        })}
      </div>
    </div>
  )
}

// MARK: Rush

export function PuzzleRush() {
  const { t } = useI18n()
  const p = S.useProfile()
  const [phase, setPhase] = useState<'intro' | 'run' | 'done'>('intro')
  const [score, setScore] = useState(0)
  const [lives, setLives] = useState(3)
  const [left, setLeft] = useState(180)
  const [idx, setIdx] = useState(0)
  const [best, setBest] = useState(false)
  const order = useRef<S.Puzzle[]>([])
  useEffect(() => {
    if (phase !== 'run') return
    const id = window.setInterval(() => setLeft(l => { if (l <= 1) { window.clearInterval(id); end(); return 0 } return l - 1 }), 1000)
    return () => window.clearInterval(id)
  }, [phase])
  const startRush = () => {
    const pool = S.PUZZLES.filter(z => !S.isRookRaidPuzzle(z))
    const shuffle = (a: S.Puzzle[]) => a.map(x => [Math.random(), x] as const).sort((a, b) => a[0] - b[0]).map(x => x[1])
    order.current = [...shuffle(pool.filter(z => z.difficulty === 1)), ...shuffle(pool.filter(z => z.difficulty === 2)), ...shuffle(pool.filter(z => z.difficulty >= 3))]
    setScore(0); setLives(3); setLeft(180); setIdx(0); setPhase('run')
  }
  const end = () => { setPhase('done'); setScoreFinal() }
  const scoreRef = useRef(0)
  scoreRef.current = score
  const setScoreFinal = () => setBest(S.finishRush(scoreRef.current))
  const done = (ok: boolean) => {
    if (ok) setScore(s => s + 1)
    else setLives(l => { if (l <= 1) { window.setTimeout(end, 400); return 0 } return l - 1 })
    setIdx(i => i + 1)
  }
  const cur = order.current[idx % Math.max(1, order.current.length)]
  return (
    <div className="full puzzle-full rush">
      <div className="g-top">
        <button className="icon-btn" onClick={closeOverlay} aria-label={t('Schließen')}><Icon name="xmark" size={18} /></button>
        <div className="g-title"><b>{t('Puzzle-Rausch')}</b></div>
        <span style={{ width: 40 }} />
      </div>
      {phase === 'intro' && (
        <div className="rush-intro pop-in">
          <span className="rush-icon big"><Icon name="boltCircle" size={64} /></span>
          <b className="title-l">{t('Puzzle-Rausch')}</b>
          <p className="dim" style={{ whiteSpace: 'pre-line', textAlign: 'center' }}>{t('3 Minuten · 3 Leben · erst leicht, dann schwerer.\nJedes gelöste Puzzle zählt einen Punkt und bringt 3 XP.')}</p>
          <span className="capsule chip gold">{t('Bestwert: {0}', p.rushBest)}</span>
          <button className="chunky gold" onClick={startRush}>{t("LOS GEHT'S")}</button>
        </div>
      )}
      {phase === 'run' && cur && (
        <div className="pz-scroll">
          <div className="rush-bar">
            <span className="mono" style={{ fontSize: 20, fontWeight: 800, color: left < 20 ? 'var(--red-light)' : '#fff' }}>{Math.floor(left / 60)}:{String(left % 60).padStart(2, '0')}</span>
            <span className="row" style={{ gap: 2 }}>{[0, 1, 2].map(i => <Icon key={i} name="heart" size={18} color={i < lives ? '#E0413A' : '#ffffff26'} />)}</span>
            <b className="r num" style={{ fontSize: 22, color: 'var(--gold)' }}>{score}</b>
          </div>
          <PuzzlePlayer key={idx} puzzle={cur} daily={false} onDone={done} />
        </div>
      )}
      {phase === 'done' && (
        <div className="rush-intro pop-in">
          {best && <Confetti />}
          <b className="title-l">{left <= 0 ? t('Zeit um!') : t('Puzzle-Rausch')}</b>
          <b className="r" style={{ fontSize: 64, color: 'var(--gold)' }}>{score}</b>
          {best && <span className="capsule" style={{ background: 'var(--gold)', color: 'var(--navy)', fontWeight: 900 }}>{t('NEUER BESTWERT!')}</span>}
          <span className="dim">{t('gelöste Puzzles · +{0} XP', score * 3)}</span>
          <div className="row" style={{ width: '100%', maxWidth: 360 }}>
            <button className="chunky gold sm" onClick={startRush}>{t('Nochmal')}</button>
            <button className="chunky gray sm" onClick={closeOverlay}>{t('Fertig')}</button>
          </div>
        </div>
      )}
    </div>
  )
}

