// BoardView.swift: squares with territory tint, markers, pieces (shield, frost, lock), legal-move dots, effects, finisher.
import { useEffect, useRef, useState, type PointerEvent as RPointerEvent, type ReactElement } from 'react'
import { pieceImage } from '../art'
import { BOARD_COLORS } from '../game/catalog'
import type { GameController } from '../game/controller'
import { getProfile } from '../game/store'
import { isFrozen, isShielded, type Side } from '../engine'
import { Icon } from '../ui/Icon'

const FILES = 'abcdefgh'

export function Board({ c }: { c: GameController }) {
  const ref = useRef<HTMLDivElement>(null)
  const [drag, setDrag] = useState<{ from: number; x: number; y: number; active: boolean; sx: number; sy: number } | null>(null)
  const [kingFx, setKingFx] = useState<'none' | 'tilt' | 'gone'>('none')
  const settings = getProfile().settings
  const colors = BOARD_COLORS[settings.boardTheme] ?? BOARD_COLORS.green
  const flipped = c.flipped
  const me = c.perspective
  const control = settings.showTerritory ? c.control : null
  const s = c.state

  useEffect(() => {
    if (!c.finisher) { setKingFx('none'); return }
    const a = window.setTimeout(() => setKingFx('tilt'), 180)
    const b = window.setTimeout(() => setKingFx('gone'), 180 + 7 * 70 + 120)
    return () => { window.clearTimeout(a); window.clearTimeout(b) }
  }, [c.finisher])

  const pos = (i: number) => {
    const r = flipped ? 7 - (i >> 3) : i >> 3
    const f = flipped ? 7 - (i & 7) : i & 7
    return { x: f * 12.5, y: r * 12.5 }
  }
  const squareAt = (clientX: number, clientY: number) => {
    const el = ref.current
    if (!el) return null
    const box = el.getBoundingClientRect()
    const f = Math.floor(((clientX - box.left) / box.width) * 8)
    const r = Math.floor(((clientY - box.top) / box.height) * 8)
    if (f < 0 || f > 7 || r < 0 || r > 7) return null
    return flipped ? (7 - r) * 8 + (7 - f) : r * 8 + f
  }

  const onDown = (e: RPointerEvent) => {
    const sq = squareAt(e.clientX, e.clientY)
    if (sq === null) return
    ;(e.target as Element).setPointerCapture?.(e.pointerId)
    setDrag({ from: sq, x: e.clientX, y: e.clientY, sx: e.clientX, sy: e.clientY, active: false })
  }
  const onMove = (e: RPointerEvent) => {
    if (!drag) return
    const dist = Math.hypot(e.clientX - drag.sx, e.clientY - drag.sy)
    if (!drag.active && dist > 8 && c.canDrag(drag.from)) {
      c.beginDrag(drag.from)
      setDrag({ ...drag, x: e.clientX, y: e.clientY, active: true })
    } else if (drag.active) setDrag({ ...drag, x: e.clientX, y: e.clientY })
  }
  const onUp = (e: RPointerEvent) => {
    if (!drag) return
    const sq = squareAt(e.clientX, e.clientY)
    if (drag.active) { if (sq !== null) c.drop(drag.from, sq) } else if (sq !== null) c.tap(sq)
    setDrag(null)
  }

  const last = s.last
  const lastAnim = last ? { from: pos(last.f), to: pos(last.t), sq: last.t, ply: s.ply } : null
  const finisher = c.finisher
  const box = ref.current?.getBoundingClientRect()
  const checked = c.checkedKing

  const squares = []
  for (let i = 0; i < 64; i++) {
    const r = i >> 3, f = i & 7
    const light = (r + f) % 2 === 0
    const owner = control?.[i] ?? null
    const mine = owner === null ? null : owner === me
    const bg = mine === true ? (light ? colors.lightMine : colors.darkMine) : mine === false ? (light ? colors.lightTheirs : colors.darkTheirs) : light ? colors.light : colors.dark
    const p = pos(i)
    const hi = c.isLastMove(i) || c.selected === i
    const dispF = flipped ? 7 - f : f, dispR = flipped ? 7 - r : r
    squares.push(
      <div key={i} className="sq" style={{ left: `${p.x}%`, top: `${p.y}%`, background: bg }}>
        {hi && <i className="sq-hi" />}
        {settings.showCoordinates && dispF === 0 && <span className="coord rank" style={{ color: light ? colors.dark : colors.light }}>{8 - r}</span>}
        {settings.showCoordinates && dispR === 7 && <span className="coord file" style={{ color: light ? colors.dark : colors.light }}>{FILES[f]}</span>}
      </div>,
    )
  }

  const pieces = []
  for (let i = 0; i < 64; i++) {
    const piece = s.b[i]
    if (!piece) continue
    const p = pos(i)
    const dragged = drag?.active && drag.from === i
    const loser = finisher?.sq === i
    const animate = lastAnim && lastAnim.sq === i && !dragged
    let style: Record<string, string | number> = { left: `${p.x}%`, top: `${p.y}%` }
    if (dragged && box) {
      style = { left: `${((drag!.x - box.left) / box.width) * 100 - 6.25}%`, top: `${((drag!.y - box.top) / box.height) * 100 - 6.25}%`, zIndex: 10, transform: 'scale(1.2)', filter: 'drop-shadow(0 6px 6px #0006)' }
    } else if (animate) {
      style['--dx'] = `${(lastAnim!.from.x - lastAnim!.to.x) * 8}%`
      style['--dy'] = `${(lastAnim!.from.y - lastAnim!.to.y) * 8}%`
    }
    const skin = c.skin(piece.c as Side)?.id
    const shielded = isShielded(piece, s.ply)
    const frozen = isFrozen(piece, s.ply)
    const locked = s.isBonusLocked(i)
    pieces.push(
      <div key={animate ? `${i}-${lastAnim!.ply}` : `${i}`} className={`pc${animate ? ' slide' : ''}${loser ? ` loser ${kingFx}` : ''}`} style={style}>
        {shielded && <i className="pc-shield" />}
        <img src={pieceImage(piece.c as Side, piece.t, skin)} alt="" draggable={false} />
        {frozen && <i className="pc-frost" />}
        {(shielded || frozen) && <span className="pc-badge"><Icon name={frozen ? 'snowflake' : 'shield'} size={10} /></span>}
        {locked && <span className="pc-lock jiggle"><Icon name="lock" size={9} /></span>}
      </div>,
    )
  }

  return (
    <div className={`board${c.shake ? ' shake-' + (c.shake % 2) : ''}${finisher ? ' finisher' : ''}`} ref={ref}
      onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={() => setDrag(null)}
      style={finisher ? { ['--fx' as string]: `${pos(finisher.sq).x + 6.25}%`, ['--fy' as string]: `${pos(finisher.sq).y + 6.25}%` } : undefined}>
      <div className="board-zoom">
        {squares}
        {checked !== null && checked >= 0 && <i className="check-glow" style={{ left: `${pos(checked).x}%`, top: `${pos(checked).y}%` }} />}
        {c.cardTargets.map(sq => <i key={'c' + sq} className="card-target" style={{ left: `${pos(sq).x}%`, top: `${pos(sq).y}%` }} />)}
        {pieces}
        {c.legal.map((m, k) => (
          <i key={'d' + k} className={s.b[m.t] || m.epc ? 'dot ring' : 'dot'} style={{ left: `${pos(m.t).x}%`, top: `${pos(m.t).y}%` }} />
        ))}
        <TutorialGuide c={c} pos={pos} />
        {c.effects.map(e => <Effect key={e.id} kind={e.kind} x={pos(e.sq).x} y={pos(e.sq).y} duration={e.duration} />)}
        {finisher && kingFx === 'gone' && <Burst x={pos(finisher.sq).x} y={pos(finisher.sq).y} />}
      </div>
      {finisher && <i className="vignette" />}
    </div>
  )
}

/** First battle: the rest of the board goes dark, an arrow shows the move and a hand taps the next square –
 *  always exactly one place to tap (BoardView.tutorialLayer in the app). */
function TutorialGuide({ c, pos }: { c: GameController; pos: (i: number) => { x: number; y: number } }) {
  const spots = c.tutorialSpots
  if (!spots.length) return null
  const focus = c.tutorialFocus
  const arrow = c.tutorialArrow
  // pos() gives the top-left corner in percent; the SVG works in squares (0…8).
  const cell = (i: number) => ({ x: pos(i).x / 12.5, y: pos(i).y / 12.5 })
  const holes = spots.map(i => { const p = cell(i); return `M${p.x + 0.12},${p.y}h0.76a0.12,0.12 0 0 1 0.12,0.12v0.76a0.12,0.12 0 0 1 -0.12,0.12h-0.76a0.12,0.12 0 0 1 -0.12,-0.12v-0.76a0.12,0.12 0 0 1 0.12,-0.12z` }).join('')
  let line: ReactElement | null = null
  if (arrow) {
    const a = cell(arrow[0]), b = cell(arrow[1])
    const ax = a.x + 0.5, ay = a.y + 0.5, bx = b.x + 0.5, by = b.y + 0.5
    const len = Math.hypot(bx - ax, by - ay) || 1, ux = (bx - ax) / len, uy = (by - ay) / len
    const sx = ax + ux * 0.3, sy = ay + uy * 0.3, tx = bx - ux * 0.3, ty = by - uy * 0.3
    const hx = tx - ux * 0.3, hy = ty - uy * 0.3
    line = (
      <g className="tut-arrow">
        <line x1={sx} y1={sy} x2={hx} y2={hy} />
        <path d={`M${tx},${ty}L${hx - uy * 0.21},${hy + ux * 0.21}L${hx + uy * 0.21},${hy - ux * 0.21}Z`} />
      </g>
    )
  }
  return (
    <>
      <svg className="tut-guide" viewBox="0 0 8 8" preserveAspectRatio="none" aria-hidden="true">
        <path d={`M0,0H8V8H0Z${holes}`} fillRule="evenodd" fill={focus === null ? '#0000009e' : '#0000008c'} />
        {line}
      </svg>
      {focus !== null && <>
        <i className="tut-pulse" style={{ left: `${pos(focus).x}%`, top: `${pos(focus).y}%` }} />
        <span className="tut-hand" style={{ left: `${pos(focus).x + 8}%`, top: `${pos(focus).y + 9}%` }}><Icon name="handPoint" size={30} /></span>
      </>}
    </>
  )
}

function Effect({ kind, x, y, duration }: { kind: string; x: number; y: number; duration: number }) {
  const icon: Record<string, string> = { shield: 'shield', frost: 'snowflake', lightning: 'bolt', promotion: 'star', meteor: 'flame', revive: 'sparkles', sparkle: 'sparkle', iceWave: 'windSnow' }
  return (
    <div className={`fx fx-${kind}`} style={{ left: `${x}%`, top: `${y}%`, animationDuration: `${duration}ms` }}>
      <i className="fx-ring" style={{ animationDuration: `${duration}ms` }} />
      {icon[kind] && <span className="fx-icon" style={{ animationDuration: `${duration}ms` }}><Icon name={icon[kind]} size={28} /></span>}
      {(kind === 'capture' || kind === 'bigCapture' || kind === 'smoke') && Array.from({ length: kind === 'bigCapture' ? 12 : 8 }, (_, i) => (
        <i key={i} className="fx-spark" style={{ ['--a' as string]: `${(i / (kind === 'bigCapture' ? 12 : 8)) * 360}deg`, animationDuration: `${duration}ms` }} />
      ))}
    </div>
  )
}

function Burst({ x, y }: { x: number; y: number }) {
  const bits = ['crown', 'star', 'sparkle', 'flame']
  const colors = ['#F2C14E', '#FF7A2F', '#FFFFFF', '#FF4D6D', '#FFE38A']
  return (
    <div className="burst" style={{ left: `${x}%`, top: `${y}%` }}>
      <i className="burst-flash" />
      <i className="burst-ring" />
      <i className="burst-ring b2" />
      {Array.from({ length: 16 }, (_, i) => {
        const a = (i / 16) * Math.PI * 2
        const dist = 115 + (i % 4) * 28
        return (
          <span key={i} className="burst-bit" style={{ color: colors[i % colors.length], ['--tx' as string]: `${Math.cos(a) * dist}%`, ['--ty' as string]: `${Math.sin(a) * dist}%`,
            ['--rot' as string]: `${(i % 2 ? -1 : 1) * (80 + i * 18)}deg` }}>
            <Icon name={bits[i % bits.length]} size={i % 5 === 0 ? 30 : 16} />
          </span>
        )
      })}
    </div>
  )
}
