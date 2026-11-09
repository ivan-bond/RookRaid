// Interactive introduction before the first battle (IntroView in the app). Five short screens:
// 1 Rocky: chess with superpowers · 2 mana (self-playing demo) · 3 cards (play Lightning on a pawn) ·
// 4 ultimate (drop the meteor) · 5 the first battle against Mila. Then the guided tutorial battle starts.
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { pieceImage, rockyFace } from '../art'
import { MAX_MANA } from '../engine'
import { BOARD_COLORS, CARDS, cardCost, ultCost, type CardId } from '../game/catalog'
import { GameController } from '../game/controller'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { openOverlay } from '../nav'
import { Icon } from '../ui/Icon'
import { CardView, ManaDrop, PlayerAvatar, Rays, Stars, UltimateCard } from '../ui/kit'
import { Welcome, type ChessLevel, type Hello } from './Welcome'

/** `signal` counts taps anywhere on the screen (Rocky reacts to them). `level`: the answer from the welcome (first start). */
type SceneProps = { onDone: () => void; done: boolean; signal: number; hello: Hello | null }
/** `waits`: no task, but „Weiter“ only appears once the scene says so (Rocky has finished talking). */
type Step = { kicker: string; title: string; text: string; task?: string; praise?: string; waits?: boolean; Scene: (p: SceneProps) => ReactNode }

const STEPS: Step[] = [
  { kicker: 'Willkommen', title: 'Schach mit Superkräften', text: 'Alles zieht wie im Schach, und wer den König mattsetzt, gewinnt. Dazu kommen Mana, Karten und eine Ultimate.',
    waits: true, Scene: RockyScene },
  { kicker: 'Mana', title: 'Jeder Zug lädt Mana', text: 'Jeder eigene Zug bringt +1 Mana. Schlagen oder Schach geben +1 extra. Höchstens 10.',
    Scene: ManaScene },
  { kicker: 'Karten', title: 'Karten: deine Tricks', text: 'Du hast 4 Karten auf der Hand. Karte antippen, dann das Ziel – das kostet Mana. Danach lädt die Karte ein paar Züge nach.',
    task: 'Tippe auf Blitz, dann auf den schwarzen Bauern!', praise: 'Zack! Bauer weg.', Scene: CardsScene },
  { kicker: 'Ultimate', title: 'Deine stärkste Waffe', text: 'Mana lädt auch deine Ultimate auf. Ist sie voll, kannst du sie zünden: Der Meteor zerstört eine Figur – nur König und Dame nicht.',
    task: 'Tippe auf den Meteor, dann auf eine schwarze Figur!', praise: 'Volltreffer!', Scene: MeteorScene },
  { kicker: 'Erste Schlacht', title: 'Bereit für Mila?', text: 'Setz Mila matt – dafür gibt es deine erste Truhe!',
    Scene: BattleScene },
]

/** First start: the welcome (who are you?) comes first, then the five intro screens. „Tutorial wiederholen“ skips it. */
export function Intro() {
  const [welcome, setWelcome] = useState(() => !S.getProfile().tutorialSeen)
  const [hello, setHello] = useState<Hello | null>(null)
  if (welcome) return <Welcome onDone={h => { setHello(h); setWelcome(false) }} />
  return <IntroSteps hello={hello} />
}

function IntroSteps({ hello }: { hello: Hello | null }) {
  const { t } = useI18n()
  const [i, setI] = useState(0)
  const [done, setDone] = useState(!STEPS[0].task && !STEPS[0].waits)
  const [signal, setSignal] = useState(0)
  const step = STEPS[i]
  const last = i === STEPS.length - 1
  const battle = () => openOverlay({ kind: 'game', game: new GameController({ mode: { kind: 'tutorial' }, human: 'w' }) })
  const next = () => {
    sound('select'); haptic('select')
    if (last) { battle(); return }
    setI(i + 1); setDone(!STEPS[i + 1].task && !STEPS[i + 1].waits)
  }
  const finish = () => {
    if (done) return
    setDone(true)
    sound('reward'); haptic('success')
  }
  // A tap anywhere: Rocky's next line, or – once the step is done – the next step (the battle itself only via the button).
  const tapAnywhere = (e: React.MouseEvent) => {
    if ((e.target as HTMLElement).closest('.intro-skip, .intro-next')) return
    if (!done) { if (step.waits) setSignal(n => n + 1); return }
    if (!last) next()
  }
  const { Scene } = step
  return (
    <div className="full intro" onClick={tapAnywhere}>
      <div className="intro-bg" />
      <Stars n={28} />
      <div className="intro-top">
        <div className="intro-dots">{STEPS.map((_, k) => <i key={k} className={k < i ? 'past' : k === i ? 'now' : ''} />)}</div>
        <button className="intro-skip" onClick={battle}>{t('Überspringen')}</button>
      </div>
      <div className="intro-stage" key={i}><Scene onDone={finish} done={done} signal={signal} hello={hello} /></div>
      <div className="intro-card" key={'c' + i}>
        <span className="intro-kicker">{t(step.kicker)} · {i + 1}/{STEPS.length}</span>
        <b className="intro-title">{t(step.title)}</b>
        <p className="intro-text">{t(step.text)}</p>
        {done
          ? <>
              {step.praise && <span className="intro-praise"><Icon name="checkCircle" size={16} />{t(step.praise)}</span>}
              <button className={`chunky ${last ? 'gold pulse-gold' : ''} intro-next`} onClick={next}>
                {last ? <><Icon name="bolt" size={18} />{t('Erste Schlacht starten')}</> : <>{t('Weiter')}<Icon name="chevronRight" size={16} /></>}
                {last && <span className="shine" />}
              </button>
            </>
          : step.task && <span className="intro-task"><Icon name="hand" size={16} />{t(step.task)}</span>}
      </div>
    </div>
  )
}

// MARK: Shared pieces

const SQ = 5
function MiniBoard({ children }: { children?: ReactNode }) {
  const c = BOARD_COLORS[S.getProfile().settings.boardTheme] ?? BOARD_COLORS.green
  return (
    <div className="mini-board">
      {Array.from({ length: SQ * SQ }, (_, k) => {
        const r = Math.floor(k / SQ), col = k % SQ
        return <div key={k} className="mb-sq" style={{ background: (r + col) % 2 ? c.dark : c.light }} />
      })}
      {children}
    </div>
  )
}
function Piece({ side, type, r, c, className = '', onClick }: { side: 'w' | 'b'; type: string; r: number; c: number; className?: string; onClick?: () => void }) {
  return (
    <button className={`mb-piece ${className}`} style={{ left: `${(c / SQ) * 100}%`, top: `${(r / SQ) * 100}%` }} onClick={onClick} tabIndex={onClick ? 0 : -1}>
      <img src={pieceImage(side, type)} alt="" draggable={false} />
    </button>
  )
}
/** Mana bar (10 cells). */
function ManaMeter({ mana, pop }: { mana: number; pop?: { id: number; text: string } | null }) {
  return (
    <div className="intro-meter">
      <ManaDrop text={mana} size={28} />
      <div className="mana-big">
        {Array.from({ length: MAX_MANA }, (_, k) => <i key={k} className={k < mana ? 'on' : ''} />)}
        {pop && <span key={pop.id} className="mana-pop" style={{ ['--pop-x' as string]: `${Math.max(8, (mana / MAX_MANA) * 100)}%` }}>{pop.text}</span>}
      </div>
    </div>
  )
}
/** Rocky with a speech bubble. `typed` shows only the first characters (typewriter); the full text keeps the bubble's size. */
function RockyBubble({ text, hop, big, typed, footer }: { text: string; hop: number; big?: boolean; typed?: number; footer?: ReactNode }) {
  return (
    <div className={`intro-rocky${big ? ' big' : ''}`}>
      <span className="intro-rocky-face" aria-hidden>
        <img key={hop} className="rocky-hop" src={rockyFace} alt="" draggable={false} />
      </span>
      <div className="intro-bubble" key={text} aria-label={text}>
        <span className="ghost">{text}</span>
        <span>{typed === undefined ? text : text.slice(0, typed)}</span>
        {footer}
      </div>
    </div>
  )
}

// MARK: 1 · Rocky

const LINES = [
  'Hi, ich bin Rocky! Ein Turm. Ich kann nur geradeaus – um die Ecke denken überlasse ich den Springern.',
  "Normales Schach? Das ist mir zu langweilig. Hier gibt's Superkräfte! Der König hat sich beschwert – aber auf den hört eh keiner.",
  'Du sammelst Mana, spielst Karten und lässt Meteore regnen. Die Bauern hassen diesen Trick!',
]
/** Rocky talks line by line (typewriter). The player taps for the next line; „Weiter“ comes after the last. */
/** After the welcome Rocky greets the player by name and answers the chess question (WelcomeView.swift: same lines). */
const LEVEL_LINES: Record<ChessLevel, string> = {
  new: 'Neu im Schach? Kein Problem – in der ersten Schlacht zeige ich dir jeden Zug.',
  rules: 'Du kennst die Regeln? Super – dann zeige ich dir nur die Superkräfte.',
  pro: 'Ein Profi! Dann pass gut auf – hier wird dich einiges überraschen.',
}
function rockyLines(hello: Hello | null, t: (k: string, ...a: Array<string | number>) => string): string[] {
  const lines = LINES.map(l => t(l))
  const name = S.getProfile().name
  if (hello?.named && !S.isDefaultName(name)) lines[0] = t('Hi {0}, ich bin Rocky! Ein Turm. Ich kann nur geradeaus – um die Ecke denken überlasse ich den Springern.', name)
  if (hello?.level) lines.splice(1, 0, t(LEVEL_LINES[hello.level]))
  return lines
}

function RockyScene({ onDone, signal, hello }: SceneProps) {
  const { t } = useI18n()
  const [line, setLine] = useState(0)
  const [chars, setChars] = useState(0)
  const [lines] = useState(() => rockyLines(hello, t))
  const text = lines[line]
  const typed = chars >= text.length
  const lastLine = line === lines.length - 1
  const nextLine = () => { setLine(l => l + 1); setChars(0); sound('select') }
  useEffect(() => {
    if (!typed) { const id = window.setTimeout(() => setChars(c => c + 2), 28); return () => window.clearTimeout(id) }
    if (lastLine) onDone()
  }, [chars, typed, lastLine, onDone])
  const tap = () => {
    haptic('select')
    if (!typed) setChars(text.length)
    else if (!lastLine) nextLine()
  }
  const tapRef = useRef(tap)
  tapRef.current = tap
  useEffect(() => { if (signal > 0) tapRef.current() }, [signal])
  const powers: Array<['drop' | 'stack' | 'flame', string, string]> = [['drop', 'Mana', 'var(--mana-light)'], ['stack', 'Karten', '#C084FC'], ['flame', 'Ultimate', 'var(--gold)']]
  return (
    <div className="scene">
      <RockyBubble text={text} typed={chars} hop={line} big
        footer={<span className="intro-lines">
          {lines.map((_, k) => <i key={k} className={k <= line ? 'on' : ''} />)}
          {typed && !lastLine && <span className="intro-more"><Icon name="chevronRight" size={14} /></span>}
        </span>} />
      <div className="intro-powers">
        {line >= lines.length - 2 && <span className="intro-power"><img src={pieceImage('w', 'k')} alt="" /><span>{t('Schach')}</span></span>}
        {lastLine && <>
          <b className="intro-plus">+</b>
          {powers.map(([icon, label, color], k) => (
            <span key={label} className="intro-power" style={{ animationDelay: `${200 + k * 160}ms` }}>
              <Icon name={icon} size={24} color={color} /><span>{t(label)}</span>
            </span>
          ))}
        </>}
      </div>
    </div>
  )
}

// MARK: 2 · Mana (plays by itself)

type DemoFrame = { mana: number; label: string; text: string; knight: [number, number]; rook: [number, number]; pawn: boolean }
const DEMO: DemoFrame[] = [
  { mana: 0, label: '', text: '', knight: [4, 1], rook: [4, 4], pawn: true },
  { mana: 1, label: '+1', text: 'Zug: +1 Mana', knight: [2, 2], rook: [4, 4], pawn: true },
  { mana: 3, label: '+2', text: 'Schlagen: +1 extra', knight: [1, 0], rook: [4, 4], pawn: false },
  { mana: 5, label: '+2', text: 'Schach: +1 extra', knight: [1, 0], rook: [0, 4], pawn: false },
]
function ManaScene() {
  const { t } = useI18n()
  const [k, setK] = useState(0)
  useEffect(() => {
    const id = window.setTimeout(() => {
      const n = (k + 1) % DEMO.length
      setK(n)
      if (n > 0) { sound(n === 2 ? 'capture' : n === 3 ? 'check' : 'move'); haptic('select') }
    }, k === DEMO.length - 1 ? 2600 : k === 0 ? 900 : 1600)
    return () => window.clearTimeout(id)
  }, [k])
  const f = DEMO[k]
  return (
    <div className="scene">
      <MiniBoard>
        <Piece side="b" type="k" r={0} c={1} className={k === 3 ? 'mb-check' : ''} />
        {f.pawn && <Piece side="b" type="p" r={1} c={0} />}
        <Piece side="w" type="n" r={f.knight[0]} c={f.knight[1]} />
        <Piece side="w" type="r" r={f.rook[0]} c={f.rook[1]} />
        <Piece side="w" type="k" r={4} c={2} />
      </MiniBoard>
      <ManaMeter mana={f.mana} pop={f.label ? { id: k, text: f.label } : null} />
      <span className="intro-why" key={k}>{f.text ? t(f.text) : ' '}</span>
    </div>
  )
}

// MARK: 3 · Cards (play Lightning)

const HAND: CardId[] = ['lightning', 'shield', 'sprint', 'freeze']
function CardsScene({ onDone, done }: SceneProps) {
  const { t } = useI18n()
  const [mana, setMana] = useState(5)
  const [armed, setArmed] = useState(false)
  const [peek, setPeek] = useState<CardId | null>(null)
  const [hit, setHit] = useState(false)
  const tapCard = (c: CardId) => {
    if (done || hit) return
    sound('card_flip'); haptic('select')
    if (c === 'lightning') { setArmed(true); setPeek(null) } else { setPeek(c); setArmed(false) }
  }
  const strike = () => {
    if (!armed || hit) return
    setHit(true); setMana(m => m - cardCost('lightning'))
    sound('lightning'); haptic('chestBig')
    window.setTimeout(onDone, 650)
  }
  const shown: CardId | null = peek ?? (armed ? 'lightning' : null)
  return (
    <div className="scene compact">
      <MiniBoard>
        <Piece side="b" type="k" r={0} c={2} />
        <Piece side="b" type="n" r={1} c={3} />
        {!hit && <Piece side="b" type="p" r={3} c={2} className={armed ? 'mb-target' : ''} onClick={strike} />}
        {hit && <div className="mb-bolt" style={{ left: '40%', top: '60%' }}><Icon name="bolt" size={46} /></div>}
        <Piece side="w" type="k" r={4} c={3} />
        <Piece side="w" type="p" r={4} c={1} />
      </MiniBoard>
      <ManaMeter mana={mana} pop={hit ? { id: 1, text: `−${cardCost('lightning')}` } : null} />
      <div className="intro-hand">
        {HAND.map((c, k) => (
          <div key={c} className="intro-card-slot" style={{ animationDelay: `${k * 90}ms` }}>
            <CardView card={c} selected={shown === c} onClick={() => tapCard(c)} spotlight={!armed && !hit && c === 'lightning'} />
          </div>
        ))}
      </div>
      <div className="intro-cardinfo" key={shown ?? 'none'}>
        {shown
          ? <><b>{t(CARDS[shown].name)} · <span className="num" style={{ color: '#8FB6FF' }}>{cardCost(shown)} {t('Mana')}</span></b><span>{t(CARDS[shown].short)}</span></>
          : <span className="muted">{t('Tippe eine Karte an, um zu sehen, was sie kann.')}</span>}
      </div>
    </div>
  )
}

// MARK: 4 · Ultimate (meteor)

function MeteorScene({ onDone, done }: SceneProps) {
  const { t } = useI18n()
  const [armed, setArmed] = useState(false)
  const [hit, setHit] = useState<[number, number] | null>(null)
  const [nope, setNope] = useState(0)
  const pieces: Array<{ type: string; r: number; c: number }> = [
    { type: 'k', r: 0, c: 2 }, { type: 'q', r: 0, c: 3 }, { type: 'r', r: 1, c: 1 }, { type: 'n', r: 1, c: 3 }, { type: 'b', r: 0, c: 1 },
  ]
  const target = (p: { type: string; r: number; c: number }) => {
    if (done || !armed || hit) return
    if (p.type === 'k' || p.type === 'q') { setNope(n => n + 1); sound('notify'); haptic('error'); return }
    setHit([p.r, p.c]); sound('lightning'); haptic('chestBig')
    window.setTimeout(onDone, 650)
  }
  const ult = ultCost('meteor')
  return (
    <div className="scene compact">
      <MiniBoard>
        <Piece side="w" type="k" r={4} c={2} />
        <Piece side="w" type="r" r={4} c={0} />
        {pieces.filter(p => !(hit && hit[0] === p.r && hit[1] === p.c && done)).map(p => (
          <Piece key={p.type} side="b" type={p.type} r={p.r} c={p.c}
            className={`${armed && !hit && p.type !== 'k' && p.type !== 'q' ? 'mb-target' : ''}${hit && hit[0] === p.r && hit[1] === p.c ? ' mb-vanish' : ''}`}
            onClick={() => target(p)} />
        ))}
        {hit && <div className="mb-meteor" style={{ left: `${(hit[1] / SQ) * 100}%`, top: `${(hit[0] / SQ) * 100}%` }}><i className="rock" /><i className="blast" /></div>}
      </MiniBoard>
      <ManaMeter mana={hit ? 0 : ult} pop={hit ? { id: 2, text: `−${ult}` } : null} />
      <span className="scene-note warn" key={nope} style={{ visibility: nope > 0 && !hit ? 'visible' : 'hidden' }}>{t('König und Dame sind geschützt!')}</span>
      <div className={armed ? '' : 'pulse-gold-soft'} style={{ borderRadius: 14 }}>
        <UltimateCard ult="meteor" mana={ult} usable selected={armed} onClick={() => { if (!done) { setArmed(true); sound('summon'); haptic('select') } }} spotlight={!armed} />
      </div>
    </div>
  )
}

// MARK: 5 · First battle

function BattleScene() {
  const { t } = useI18n()
  const p = S.useProfile()
  return (
    <div className="scene">
      <div className="intro-versus">
        <div className="intro-fighter" style={{ animationDelay: '0ms' }}>
          <PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={84} />
          <b>{S.shownName(p.name, t)}</b>
        </div>
        <span className="intro-vs">VS</span>
        <div className="intro-fighter" style={{ animationDelay: '150ms' }}>
          <span className="intro-bot"><Rays size={170} /><img src={pieceImage('w', 'k', 'medium')} alt="" /></span>
          <b>{t('Mila')}</b><small>{t('die Magierin')}</small>
        </div>
      </div>
      <RockyBubble text={t('Keine Sorge: Ich bin die ganze Zeit dabei und zeige dir jeden Zug.')} hop={0} />
    </div>
  )
}
