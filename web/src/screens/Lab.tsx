// CardLabView.swift: the card school. One small position per card and ultimate, played with the real rules.
import { useMemo, useState } from 'react'
import { pieceImage, rockyFace } from '../art'
import { BOARD_COLORS, CARDS, CARD_IDS, TIERS, ULTS, ULT_IDS, cardCost, type CardId, type UltId } from '../game/catalog'
import { apply, E, fromFEN, isFrozen, isShielded, sqIndex, type MatchState, type Side } from '../engine'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeOverlay } from '../nav'
import { Icon } from '../ui/Icon'
import { CardView, Confetti, UltimateCard } from '../ui/kit'
import lab from '../data/lab.json'

type Scenario = {
  fen: string; mana?: number; opponentMana?: number; captured?: string[]; target?: string; mission: string; afterCard?: string
  bonusHint?: string; blocked?: Array<[string, string]>; blockedText?: string; reply?: string; replyText?: string; finale?: string
  finaleText?: string; lessons: string[]
}
const SCENARIOS = lab as unknown as Record<string, Scenario>
const LETTER: Record<string, string> = { rook: 'r', knight: 'n', bishop: 'b', queen: 'q', pawn: 'p' }

export const LAB_ITEMS: Array<{ key: string; id: string; ult: boolean }> = [
  ...[...CARD_IDS].sort((a, b) => {
    const sa = CARDS[a].tier === 'starter' ? 0 : 1, sb = CARDS[b].tier === 'starter' ? 0 : 1
    return sa !== sb ? sa - sb : cardCost(a) !== cardCost(b) ? cardCost(a) - cardCost(b) : a.localeCompare(b)
  }).map(c => ({ key: 'c-' + c, id: c, ult: false })),
  ...ULT_IDS.map(u => ({ key: 'u-' + u, id: u, ult: true })),
]

type Phase = 'mission' | 'bonus' | 'reply' | 'finale' | 'done'

export function CardLab({ startKey }: { startKey: string }) {
  const { t } = useI18n()
  const [key, setKey] = useState(startKey)
  const [attempt, setAttempt] = useState(0)
  const item = LAB_ITEMS.find(i => i.key === key) ?? LAB_ITEMS[0]
  const sc = SCENARIOS[key]
  const initial = useMemo(() => {
    const s = fromFEN(sc.fen)
    s.mana = { w: sc.mana ?? 0, b: sc.opponentMana ?? 0 }
    s.decks = { w: { hand: item.ult ? [] : [item.id], queue: [] }, b: { hand: [], queue: [] } } as MatchState['decks']
    if (item.ult) s.ults = { w: item.id } as MatchState['ults']
    if (sc.captured) s.captured = { w: sc.captured.map(tp => ({ t: LETTER[tp] ?? 'r', c: 'w', sh: -1, fr: -1 })), b: [] } as MatchState['captured']
    return s
  }, [key, attempt])
  const [state, setState] = useState(initial)
  const [phase, setPhase] = useState<Phase>('mission')
  const [aiming, setAiming] = useState(false)
  const [selected, setSelected] = useState<number | null>(null)
  const [text, setText] = useState(sc.mission)
  const [showBlocked, setShowBlocked] = useState(false)
  const [lastKey, setLastKey] = useState(key + attempt)
  if (lastKey !== key + attempt) {
    setLastKey(key + attempt); setState(initial); setPhase('mission'); setAiming(false); setSelected(null); setText(SCENARIOS[key].mission); setShowBlocked(false)
  }
  const s = state
  const name = item.ult ? t(ULTS[item.id as UltId].name) : t(CARDS[item.id as CardId].name)
  const done = () => {
    setPhase('done'); sound('victory'); haptic('victory')
    if (!S.getProfile().labDone.includes(key)) S.update(p => { p.labDone.push(key) })
  }
  const afterAction = (next: MatchState) => {
    setState(next)
    if (next.cur === 'w' && next.bonus) {
      setPhase('bonus'); setText(t(sc.afterCard ?? '')); setShowBlocked(!!sc.blocked?.length)
      return
    }
    setText(t(sc.afterCard ?? ''))
    setShowBlocked(!!sc.blocked?.length)
    goReply(next)
  }
  const goReply = (cur: MatchState) => {
    if (sc.reply) {
      setPhase('reply')
      window.setTimeout(() => {
        const n = cur.clone()
        if (apply(n, sc.reply!)) { sound('move'); setState(n); if (sc.replyText) setText(t(sc.replyText)) }
        if (sc.finale) { setPhase('finale'); window.setTimeout(() => setText(t(sc.finaleText ?? '')), 900) } else window.setTimeout(done, 1200)
      }, 1300)
    } else if (sc.finale) { setPhase('finale'); setText(t(sc.finaleText ?? '')) } else window.setTimeout(done, 1300)
  }
  const tapCard = () => {
    if (phase !== 'mission') return
    if (item.ult ? !s.canUseUlt('w') : !s.canPlay(item.id, 'w')) { haptic('invalid'); return }
    const needs = item.ult ? E.ultNeedsTarget(item.id) : !E.NO_TARGET[item.id]
    if (!needs) {
      const n = s.clone()
      if (apply(n, item.ult ? `ult:${item.id}` : `card:${item.id}`)) { sound('card'); afterAction(n) }
      return
    }
    setAiming(a => !a)
  }
  const tap = (i: number) => {
    if (phase === 'mission' && aiming) {
      const targets = item.ult ? s.ultTargets('w') : s.targets(item.id, 'w')
      if (!targets.includes(i)) { setAiming(false); return }
      const n = s.clone()
      if (apply(n, (item.ult ? `ult:${item.id}` : `card:${item.id}`) + '@' + E.sqName(i))) { sound(item.ult ? 'lightning' : 'card'); setAiming(false); afterAction(n) }
      return
    }
    if ((phase === 'bonus' || phase === 'finale') && s.cur === 'w') {
      if (selected !== null) {
        const m = s.legalMoves(selected).find(x => x.t === i)
        if (m) {
          const code = E.uci(s, m)
          if (phase === 'finale' && sc.finale && code.slice(0, 4) !== sc.finale.slice(0, 4)) { haptic('invalid'); setSelected(null); return }
          const n = s.clone()
          apply(n, code)
          sound(s.b[m.t] ? 'capture' : 'move')
          setSelected(null)
          setState(n)
          if (phase === 'finale') { window.setTimeout(done, 700); return }
          setShowBlocked(false)
          goReply(n)
          return
        }
      }
      const p = s.b[i]
      setSelected(p && p.c === 'w' && s.legalMoves(i).length ? i : null)
    }
  }
  const idx = LAB_ITEMS.findIndex(i => i.key === key)
  const nextItem = LAB_ITEMS[(idx + 1) % LAB_ITEMS.length]
  const targets = aiming ? (item.ult ? s.ultTargets('w') : s.targets(item.id, 'w')) : selected !== null ? s.legalMoves(selected).map(m => m.t) : []
  const goldSquares = phase === 'mission' && sc.target ? [sqIndex(sc.target)] : phase === 'bonus' && sc.bonusHint ? [sqIndex(sc.bonusHint.slice(0, 2)), sqIndex(sc.bonusHint.slice(2, 4))]
    : phase === 'finale' && sc.finale ? [sqIndex(sc.finale.slice(0, 2)), sqIndex(sc.finale.slice(2, 4))] : []
  const arrows: Array<{ from: string; to: string; kind: 'gold' | 'blocked' }> = [
    ...(phase === 'bonus' && sc.bonusHint ? [{ from: sc.bonusHint.slice(0, 2), to: sc.bonusHint.slice(2, 4), kind: 'gold' as const }] : []),
    ...(phase === 'finale' && sc.finale ? [{ from: sc.finale.slice(0, 2), to: sc.finale.slice(2, 4), kind: 'gold' as const }] : []),
    ...(showBlocked ? (sc.blocked ?? []).map(([from, to]) => ({ from, to, kind: 'blocked' as const })) : []),
  ]
  const progress = LAB_ITEMS.filter(i => S.getProfile().labDone.includes(i.key)).length

  return (
    <div className="full lab">
      <div className="g-top">
        <button className="icon-btn" onClick={closeOverlay} aria-label={t('Schließen')}><Icon name="xmark" size={18} /></button>
        <div className="g-title"><b>{t('Kartenschule')}</b><span className="num">{progress}/{LAB_ITEMS.length}</span></div>
        <span style={{ width: 40 }} />
      </div>
      <div className="lab-strip">
        {LAB_ITEMS.map(i => (
          <button key={i.key} className={`lab-pill${i.key === key ? ' on' : ''}${S.getProfile().labDone.includes(i.key) ? ' done' : ''}`} onClick={() => setKey(i.key)}>
            {i.ult ? t(ULTS[i.id as UltId].name) : t(CARDS[i.id as CardId].name)}
          </button>
        ))}
      </div>
      <div className="pz-scroll">
        <div className="pz-body">
          <div className="lab-rocky">
            <img src={rockyFace} alt="" className="rocky-face bob" />
            <div className="rocky-bubble small"><b>{name}</b><p>{phase === 'mission' ? t(sc.mission) : text}</p>
              {showBlocked && sc.blockedText && <p className="lab-blocked"><Icon name="xCircle" size={13} />{t(sc.blockedText)}</p>}
            </div>
          </div>
          <LabBoard s={s} gold={goldSquares} targets={targets} card={aiming} selected={selected} arrows={arrows} onTap={tap} />
          <div className="lab-hand">
            <div style={{ width: 86 }} onClick={tapCard}>
              {item.ult ? <UltimateCard ult={item.id} mana={s.mana.w} usable={phase === 'mission'} selected={aiming} spotlight={phase === 'mission' && !aiming} />
                : <CardView card={item.id} playable={phase === 'mission'} selected={aiming} spotlight={phase === 'mission' && !aiming} />}
            </div>
            <div className="col" style={{ gap: 4 }}>
              <span className="capsule chip">{t('{0} Mana', s.mana.w)}</span>
              {!item.ult && <span className="capsule chip" style={{ color: TIERS[CARDS[item.id as CardId].tier].color }}>{t(TIERS[CARDS[item.id as CardId].tier].name)}</span>}
            </div>
          </div>
        </div>
      </div>
      {phase === 'done' && (
        <div className="overlay-center fade-in">
          <Confetti />
          <div className="tut-done pop-in">
            <img src={rockyFace} alt="" style={{ width: 90, height: 90, margin: '0 auto' }} className="rocky-face bob" />
            <b className="title-l">{t('{0} gemeistert!', name)}</b>
            <div className="col" style={{ gap: 8, textAlign: 'left' }}>
              {sc.lessons.map((l, i) => <div key={i} className="row" style={{ alignItems: 'flex-start', gap: 8 }}><Icon name="checkCircle" size={16} color="var(--gold)" /><span>{t(l)}</span></div>)}
            </div>
            <div className="row">
              <button className="chunky gray sm" onClick={() => setAttempt(a => a + 1)}>{t('Nochmal')}</button>
              <button className="chunky gold sm" onClick={() => setKey(nextItem.key)}>{t('Nächste Karte')}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function LabBoard({ s, gold, targets, card, selected, arrows, onTap }: {
  s: MatchState; gold: number[]; targets: number[]; card: boolean; selected: number | null; arrows: Array<{ from: string; to: string; kind: 'gold' | 'blocked' }>; onTap: (i: number) => void
}) {
  const colors = BOARD_COLORS[S.getProfile().settings.boardTheme] ?? BOARD_COLORS.green
  const center = (n: string) => { const i = sqIndex(n); return { x: (i & 7) * 12.5 + 6.25, y: (i >> 3) * 12.5 + 6.25 } }
  return (
    <div className="board pz-board">
      <div className="board-zoom">
        {Array.from({ length: 64 }, (_, i) => {
          const light = ((i >> 3) + (i & 7)) % 2 === 0
          const p = s.b[i]
          return (
            <div key={i} className="sq" style={{ left: `${(i & 7) * 12.5}%`, top: `${(i >> 3) * 12.5}%`, background: s.controlMap()[i] === 'w' ? (light ? colors.lightMine : colors.darkMine) : light ? colors.light : colors.dark }} onClick={() => onTap(i)}>
              {(selected === i || (s.last && (s.last.f === i || s.last.t === i))) && <i className="sq-hi" />}
              {gold.includes(i) && <i className="tut-pulse" style={{ left: 0, top: 0, width: '100%', height: '100%' }} />}
              {p && <div className="pc static">
                {isShielded(p, s.ply) && <i className="pc-shield" />}
                <img src={pieceImage(p.c as Side, p.t)} alt="" draggable={false} />
                {isFrozen(p, s.ply) && <i className="pc-frost" />}
                {s.isBonusLocked(i) && <span className="pc-lock"><Icon name="lock" size={9} /></span>}
              </div>}
              {targets.includes(i) && (card ? <i className="card-target" style={{ left: 0, top: 0, width: '100%', height: '100%' }} /> : <i className={p ? 'dot ring' : 'dot'} style={{ left: 0, top: 0 }} />)}
            </div>
          )
        })}
        <svg className="arrows" viewBox="0 0 100 100" preserveAspectRatio="none">
          <defs>
            <marker id="ag" markerWidth="4" markerHeight="4" refX="2" refY="2" orient="auto"><path d="M0,0 L4,2 L0,4 Z" fill="#F2C14E" /></marker>
            <marker id="ar" markerWidth="4" markerHeight="4" refX="2" refY="2" orient="auto"><path d="M0,0 L4,2 L0,4 Z" fill="#E0413A" /></marker>
          </defs>
          {arrows.map((a, i) => {
            const f = center(a.from), to = center(a.to)
            const mid = { x: (f.x + to.x) / 2, y: (f.y + to.y) / 2 }
            return (
              <g key={i} opacity={0.9}>
                <line x1={f.x} y1={f.y} x2={to.x - (to.x - f.x) * 0.12} y2={to.y - (to.y - f.y) * 0.12} stroke={a.kind === 'gold' ? '#F2C14E' : '#E0413A'} strokeWidth="2.2" strokeLinecap="round" markerEnd={`url(#${a.kind === 'gold' ? 'ag' : 'ar'})`} className={a.kind === 'gold' ? 'arrow-pulse' : ''} />
                {a.kind === 'blocked' && <g transform={`translate(${mid.x} ${mid.y})`}><circle r="3.4" fill="#fff" /><path d="M-1.8,-1.8 L1.8,1.8 M1.8,-1.8 L-1.8,1.8" stroke="#E0413A" strokeWidth="1.1" /></g>}
              </g>
            )
          })}
        </svg>
      </div>
    </div>
  )
}
