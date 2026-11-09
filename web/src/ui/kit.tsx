// Shared pieces of the interface, each a port of the SwiftUI view with the same name.
import { useEffect, useId, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { avatarImage, cardArt } from '../art'
import { CARDS, CHEST, FRAMES, TIERS, ULTS, cardCost, ultCost, type CardId, type ChestRarity, type FrameId, type UltId, FLAME, flameTier, KEEPS_TURN } from '../game/catalog'
import { useI18n } from '../i18n'
import { Icon } from './Icon'
import { CHEST_LAYERS, CHEST_PALETTES, CHEST_RARITY_KEYS } from './chestArt'

// MARK: Mana drop

export function ManaDrop({ text, size = 22, style }: { text: string | number; size?: number; style?: CSSProperties }) {
  const id = useId()
  return (
    <span className="mana-drop" style={{ width: size * 0.8, height: size, ...style }}>
      <svg viewBox="0 0 20 25">
        <defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#B9A2FF" /><stop offset=".5" stopColor="#8B5CF6" /><stop offset="1" stopColor="#5B37C2" /></linearGradient></defs>
        <path d="M10 0.5S19.5 10.6 19.5 16.2a9.5 9.5 0 0 1-19 0C.5 10.6 10 .5 10 .5z" fill={`url(#${id})`} />
      </svg>
      <b style={{ fontSize: size * 0.48 }}>{text}</b>
    </span>
  )
}

// MARK: Cards

export function CardView({ card, playable = true, selected = false, compact = false, cooldown = 0, onClick, spotlight = false, style, showName = true }: {
  card: string; playable?: boolean; selected?: boolean; compact?: boolean; cooldown?: number; onClick?: () => void; spotlight?: boolean
  style?: CSSProperties; showName?: boolean
}) {
  const { t } = useI18n()
  const info = CARDS[card as CardId]
  const tier = info ? TIERS[info.tier].color : '#34486F'
  return (
    <button type="button" className={`cardv${selected ? ' sel' : ''}${!playable && !cooldown ? ' off' : ''}${compact ? ' compact' : ''}${spotlight ? ' spotlight' : ''}`}
      onClick={onClick} style={{ ['--tier' as string]: tier, ...style }} aria-label={t(info?.name ?? card)}>
      <div className="face">
        <img className="art" src={cardArt(`art-card-${card}`)} alt="" draggable={false} />
        <i className="rim" />
        <ManaDrop text={cardCost(card)} size={compact ? 16 : 22} style={compact ? { left: -3, top: -4 } : undefined} />
        {KEEPS_TURN[card] && !compact && <span className="bonus-badge"><Icon name="plus" size={7} /><Icon name="walk" size={9} /></span>}
        {cooldown > 0 && <span className="cooldown"><Icon name="hourglass" size={compact ? 9 : 13} /><span style={{ fontSize: compact ? 13 : 20 }}>{cooldown}</span></span>}
        {spotlight && <Spotlight />}
      </div>
      {showName && <span className="nm">{t(info?.name ?? card)}</span>}
    </button>
  )
}

function Spotlight() {
  const { t } = useI18n()
  return (
    <>
      <i className="spot-ring" />
      <span className="spot-hand"><span className="capsule" style={{ background: 'var(--gold)', color: 'var(--navy)', fontSize: 9, fontWeight: 900 }}>{t('TIPPEN')}</span><Icon name="handDown" size={20} /></span>
    </>
  )
}

export function UltimateCard({ ult, mana, usable = false, selected = false, compact = false, onClick, spotlight = false, style }: {
  ult: string; mana: number; usable?: boolean; selected?: boolean; compact?: boolean; onClick?: () => void; spotlight?: boolean; style?: CSSProperties
}) {
  const { t } = useI18n()
  const cost = ultCost(ult)
  const progress = Math.min(mana, cost) / cost
  const full = mana >= cost
  const art = cardArt(`art-ult-${ult}`)
  return (
    <button type="button" className={`cardv ultv${selected ? ' sel' : ''}${usable ? ' ready' : ''}${compact ? ' compact' : ''}`} onClick={onClick} style={style}
      aria-label={t(ULTS[ult as UltId]?.name ?? ult)}>
      <div className="face">
        <img className="art gray" src={art} alt="" draggable={false} />
        <span className="fill" style={{ height: `${progress * 100}%` }}>
          <img src={art} alt="" style={{ height: `${100 / Math.max(progress, 0.0001)}%` }} draggable={false} />
        </span>
        {!full && progress > 0 && <i className="edge" style={{ top: `${(1 - progress) * 100}%` }} />}
        {full && <span className="shine" />}
        <i className="rim" style={selected ? { borderColor: '#fff', borderWidth: 3 } : undefined} />
        {spotlight && <Spotlight />}
      </div>
      <span className="nm">{full ? t(ULTS[ult as UltId]?.name ?? ult) : `${Math.min(mana, cost)}/${cost}`}</span>
    </button>
  )
}

export function CardThumb({ art, width = 22, border, empty = false, style }: { art?: string; width?: number; border?: string; empty?: boolean; style?: CSSProperties }) {
  if (empty || !art) {
    return <span className="thumb empty" style={{ width, ...style }}><Icon name="plus" size={width * 0.32} /></span>
  }
  return <span className="thumb" style={{ width, ['--tier' as string]: border, ...style }}><img src={cardArt(art)} alt="" draggable={false} /></span>
}

export const tierColor = (card: string) => (CARDS[card as CardId] ? TIERS[CARDS[card as CardId].tier].color : '#34486F')

// MARK: Avatar

export function PlayerAvatar({ avatar, frame = 'none', size = 34, style }: { avatar: string; frame?: FrameId | string | null; size?: number; style?: CSSProperties }) {
  // ProfileExtras.swift PlayerAvatar: portrait, gradient ring (7 % of the size), frame icon on top, coloured shadow.
  const id = useId().replace(/:/g, '')
  const key = (frame ?? 'none') as FrameId
  const f = FRAMES[key] ?? FRAMES.none
  const ring = size * 0.07
  const inner = size - ring * 1.4
  return (
    <span className="avatar" style={{ width: size, height: size, filter: `drop-shadow(0 0 ${size * 0.1}px ${f.colors[1]}${key === 'none' ? '4d' : '99'})`, ...style }}>
      <img src={avatarImage(avatar)} alt="" draggable={false} style={{ inset: (size - inner) / 2, width: inner, height: inner }} />
      <svg width={size} height={size} style={{ position: 'absolute', inset: 0, overflow: 'visible' }} aria-hidden="true">
        <defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={f.colors[0]} /><stop offset="1" stopColor={f.colors[1]} /></linearGradient></defs>
        <circle cx={size / 2} cy={size / 2} r={(size - ring) / 2} fill="none" stroke={`url(#${id})`} strokeWidth={ring} />
      </svg>
      {f.icon && (
        <span className="fr-icon" style={{ width: size * 0.3, height: size * 0.3, left: size * 0.35, top: -size * 0.13, background: `linear-gradient(${f.colors[0]}, ${f.colors[1]})` }}>
          <Icon name={f.icon} size={size * 0.16} color="var(--navy)" />
        </span>
      )}
    </span>
  )
}

// MARK: Header badges

export function LevelBadge({ level, progress, size = 40 }: { level: number; progress: number; size?: number }) {
  const r = (size - 4) / 2
  const c = 2 * Math.PI * r
  return (
    <span className="level-badge" style={{ width: size, height: size }}>
      <svg width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="var(--raised)" stroke="var(--hi)" strokeWidth={3.5} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--mana-light)" strokeWidth={3.5} strokeLinecap="round"
          strokeDasharray={`${c * progress} ${c}`} transform={`rotate(-90 ${size / 2} ${size / 2})`} />
      </svg>
      <b style={{ fontSize: size * 0.45 }}>{level}</b>
    </span>
  )
}

export function ShardIcon({ size = 18 }: { size?: number }) {
  const id = useId().replace(/:/g, '')
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: 'none', overflow: 'visible', filter: `drop-shadow(0 0 ${size * 0.25}px #7FE3FF99)` }} aria-hidden="true">
      <defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#FFFFFF" /><stop offset=".5" stopColor="#7FE3FF" /><stop offset="1" stopColor="#2A9CC4" /></linearGradient></defs>
      <path d="M12 1.2c.5 0 .9.2 1.2.6l8.3 9.1c.4.5.4 1.2 0 1.7l-8.3 9.1c-.6.7-1.8.7-2.4 0L2.5 12.6c-.4-.5-.4-1.2 0-1.7l8.3-9.1c.3-.4.7-.6 1.2-.6z" fill={`url(#${id})`} />
      <path d="M12 7.2 16.4 12 12 16.8 7.6 12z" fill="none" stroke="#ffffffb3" strokeWidth="1.5" strokeLinejoin="round" />
    </svg>
  )
}

/** SF Symbol flame.fill with the app's gradient (FlameStyle.glow → lit), grey when not lit today. */
export function FlameIcon({ size = 17, lit = true, colors, style }: { size?: number; lit?: boolean; colors?: [string, string]; style?: CSSProperties }) {
  const id = useId().replace(/:/g, '')
  const [top, bottom] = colors ?? [FLAME.glow, FLAME.lit]
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: 'none', ...style }} aria-hidden="true">
      <defs><linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={top} /><stop offset="1" stopColor={bottom} /></linearGradient></defs>
      <path fillRule="evenodd" fill={lit ? `url(#${id})` : FLAME.off}
        d="M12.3 1c.6 3.3-1.3 5.3-3.1 7.4C7.4 10.5 5.6 12.6 5.6 15.6 5.6 19.4 8.5 22.5 12 22.5s6.4-3.1 6.4-6.9c0-3.7-2.1-6.4-4-8.7-.2 1.9-1 3.1-2.3 3.8.5-3.6-.1-6.9.2-9.7zM12 21.3c-1.7 0-3-1.4-3-3.1 0-1.7 1.2-2.9 2.4-4.1.3 1 .9 1.6 1.8 1.9-.3-1.1-.2-2.1.3-3.1 1.3 1.4 2.4 2.9 2.4 4.7 0 2.1-1.7 3.7-3.9 3.7z" />
    </svg>
  )
}

/** LivingFlame (StreakViews.swift): three flickering tongues, rising embers, a soft glow and a dark outline. */
export function LivingFlame({ colors, lit = true, embers = 8, width, height, style }: { colors: [string, string, string]; lit?: boolean; embers?: number; width: number; height: number; style?: CSSProperties }) {
  const ref = useRef<HTMLCanvasElement>(null)
  useEffect(() => {
    const canvas = ref.current
    if (!canvas) return
    const dpr = Math.min(2, window.devicePixelRatio || 1)
    canvas.width = width * dpr; canvas.height = height * dpr
    const g = canvas.getContext('2d')!
    let raf = 0
    const tongue = (cx: number, by: number, w: number, h: number, t: number) => {
      const sway = Math.sin(t * 3.1) * w * 0.09, s2 = Math.sin(t * 4.3 + 1.2) * w * 0.05, s3 = Math.cos(t * 3.7) * w * 0.06
      const tip = { x: cx + sway, y: by - h }
      const p = new Path2D()
      p.moveTo(cx, by)
      p.bezierCurveTo(cx - w * 0.6, by, cx - w * 0.52 + s3, by - h * 0.42, cx - w * 0.16 + s2, by - h * 0.66)
      p.bezierCurveTo(cx - w * 0.06 + s2, by - h * 0.8, tip.x - w * 0.1, by - h * 0.9, tip.x, tip.y)
      p.bezierCurveTo(tip.x + w * 0.12, by - h * 0.86, cx + w * 0.16 + s2, by - h * 0.74, cx + w * 0.2 + s3, by - h * 0.56)
      p.bezierCurveTo(cx + w * 0.6, by - h * 0.4, cx + w * 0.58, by, cx, by)
      p.closePath()
      return p
    }
    const alpha = (hex: string, a: number) => hex + Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16).padStart(2, '0')
    const draw = (now: number) => {
      const t = lit ? now / 1000 : 0
      const w = width, h = height
      g.setTransform(dpr, 0, 0, dpr, 0, 0)
      g.clearRect(0, 0, w, h)
      const by = h * 0.96
      const glow = g.createRadialGradient(w / 2, h * 0.66, 2, w / 2, h * 0.66, w * 0.45)
      glow.addColorStop(0, alpha(colors[0], lit ? 0.5 : 0.15)); glow.addColorStop(1, alpha(colors[0], 0))
      g.fillStyle = glow
      g.beginPath(); g.ellipse(w / 2, h * 0.3 + h * 0.36, w * 0.38, h * 0.36, 0, 0, Math.PI * 2); g.fill()
      for (let i = 0; i < embers; i++) {
        const phase = (t * 0.45 + i * 0.137) % 1
        const x = w / 2 + Math.sin(i * 12.9 + t * 1.7) * w * 0.26 * (0.4 + phase)
        const y = by - phase * h
        const r = (2.2 + (i % 3)) * (1 - phase * 0.6) * (w / 210 + 0.4)
        g.globalAlpha = (1 - phase) * (lit ? 0.9 : 0.4)
        g.fillStyle = colors[1]
        g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2); g.fill()
      }
      g.globalAlpha = 1
      ;[1, 0.74, 0.46].forEach((scale, i) => {
        const p = tongue(w / 2, by, w * 0.78 * scale, h * 0.9 * scale, t * (1 + i * 0.25) + i)
        const grad = g.createLinearGradient(w / 2, by - h * 0.9 * scale, w / 2, by)
        grad.addColorStop(0, colors[Math.min(i + 1, 2)]); grad.addColorStop(1, colors[i])
        g.fillStyle = grad
        g.fill(p)
      })
      g.strokeStyle = '#0B1A33d9'
      g.lineWidth = Math.max(2, 5 * (w / 210))
      g.lineJoin = 'round'
      g.stroke(tongue(w / 2, by, w * 0.78, h * 0.9, t))
      if (lit) raf = requestAnimationFrame(draw)
    }
    raf = requestAnimationFrame(draw)
    return () => cancelAnimationFrame(raf)
  }, [colors.join(), lit, embers, width, height])
  return <canvas ref={ref} style={{ width, height, display: 'block', pointerEvents: 'none', ...style }} aria-hidden="true" />
}

export function FlameGlyph({ size = 18, lit = true, streak = 1 }: { size?: number; lit?: boolean; streak?: number }) {
  const id = useId()
  const tier = flameTier(Math.max(1, streak))
  const [outer, mid, inner] = lit ? tier.colors : [FLAME.off, FLAME.off, '#8D9AB8']
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: 'none' }}>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor={mid} /><stop offset="1" stopColor={outer} /></linearGradient>
      </defs>
      <path d="M12.4 1.5c.8 4-2.4 6-3.9 8.3C7 12 6 13.6 6 16a6 6 0 0 0 12 0c0-3-1.4-5-2.8-6.6-.1 1.6-.9 2.7-2 3.2.9-4-.2-7.6-.8-11.1z" fill={`url(#${id})`} />
      <path d="M12.3 12.5c1.6 1.4 2.7 2.6 2.7 4.3a3 3 0 0 1-6 0c0-1.5 1.1-2.6 2.2-3.6.3.8.8 1.2 1.3 1.4-.3-.7-.4-1.4-.2-2.1z" fill={inner} opacity={lit ? 1 : 0.5} />
    </svg>
  )
}

// MARK: Chest

const rarityKey = (r: ChestRarity) => CHEST_RARITY_KEYS[r]
const smooth = (a: number, b: number, x: number) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t) }
const PASSES = [['openLid'], ['shadow', 'body', 'runes', 'mouth', 'mouthGlow'], ['seam'], ['lid', 'gem', 'lock'], ['lockGlow']]

/** The drawn chest of the app (ChestArt): `lid` 0…1 blows the lid open, `glow` 0…1 lights seam, lock and runes. */
export function ChestView({ rarity, size = 60, lid = 0, glow = 0, style, className }: { rarity: ChestRarity; size?: number; lid?: number; glow?: number; style?: CSSProperties; className?: string }) {
  const uid = useId().replace(/:/g, '')
  const key = rarityKey(rarity)
  const pal = CHEST_PALETTES[key]
  const color = (k: string) => pal[k] ?? '#fff'
  const closed = 1 - smooth(0.08, 0.55, lid)
  const open = smooth(0.25, 0.8, lid)
  const animated = rarity >= 3 && size >= 70
  const k = size / 78
  const W = size * 1.2, H = size * 1.08
  const base = `translate(${W / 2 - 50 * k} ${H / 2 - 55 * k}) scale(${k})`
  const lidT = `${base} translate(0 ${-28 * lid}) rotate(${(-0.32 * lid * 180) / Math.PI} 50 54)`
  const defs: ReactNode[] = []
  const passes = PASSES.map((parts, pi) => {
    const nodes = CHEST_LAYERS.map((layer, li) => {
      if (!parts.includes(layer.part)) return null
      if (layer.only && !layer.only.includes(key)) return null
      let a = layer.alpha ?? 1
      const isShimmer = layer.part === 'runes' || layer.part === 'gem'
      if (layer.emissive) a *= isShimmer ? Math.max(0.65, glow) : glow
      if (layer.part === 'seam') a *= closed
      if (['mouth', 'mouthGlow', 'openLid'].includes(layer.part)) a *= open
      if (['lid', 'gem', 'lock', 'lockGlow'].includes(layer.part)) a *= closed
      if (a < 0.003) return null
      const id = `${uid}-${li}`
      let fill = 'none'
      if (layer.fill?.solid) {
        fill = color(layer.fill.solid)
      } else if (layer.fill?.stops) {
        defs.push(
          <linearGradient key={id} id={id} gradientUnits="userSpaceOnUse" x1={layer.fill.from![0]} y1={layer.fill.from![1]} x2={layer.fill.to![0]} y2={layer.fill.to![1]}>
            {layer.fill.stops.map((s, i) => <stop key={i} offset={s.o} stopColor={color(s.k)} stopOpacity={s.a} />)}
          </linearGradient>,
        )
        fill = `url(#${id})`
      }
      if (layer.clip) defs.push(<clipPath key={id + 'c'} id={id + 'c'}><path d={layer.clip} /></clipPath>)
      if (layer.blur) defs.push(<filter key={id + 'b'} id={id + 'b'} x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation={layer.blur * 0.5} /></filter>)
      return (
        <path key={li} d={layer.d} fill={fill} fillOpacity={layer.fill?.solid ? layer.fill.a ?? 1 : 1} opacity={a}
          stroke={layer.stroke ? color(layer.stroke) : undefined} strokeWidth={layer.w ?? 1} strokeLinecap="round" strokeLinejoin="round"
          clipPath={layer.clip ? `url(#${id}c)` : undefined} filter={layer.blur ? `url(#${id}b)` : undefined}
          className={animated && layer.part === 'gem' && rarity === 4 ? 'hue-cycle' : animated && isShimmer && layer.emissive ? 'shimmer' : undefined} />
      )
    })
    return <g key={pi} transform={pi >= 3 ? lidT : base}>{nodes}</g>
  })
  return (
    <span className={className} style={{ position: 'relative', display: 'inline-block', width: W, height: H, flex: 'none', ...style }} aria-label={CHEST[rarity].name}>
      <span style={{ position: 'absolute', left: '50%', top: '50%', width: size * 1.1, height: size * 0.9, transform: 'translate(-50%,-50%)', borderRadius: '50%',
        background: CHEST[rarity].glow, filter: `blur(${size * 0.15}px)`, opacity: 0.08 + 0.6 * glow }} />
      <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{ position: 'absolute', inset: 0, overflow: 'visible' }}>
        <defs>{defs}</defs>
        {passes}
      </svg>
    </span>
  )
}

// MARK: Sheet, dialog, toast

/** `sub`: a row that stays pinned under the title (e.g. tabs). */
export function Sheet({ title, onClose, children, wide = false, tall = false, left, doneLabel, sub }: {
  title?: ReactNode; onClose: () => void; children: ReactNode; wide?: boolean; tall?: boolean; left?: ReactNode; doneLabel?: string; sub?: ReactNode
}) {
  const { t } = useI18n()
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [onClose])
  return createPortal(
    <div className="scrim" onClick={e => { if (e.target === e.currentTarget) onClose() }}>
      <div className={`sheet${wide ? ' wide' : ''}${tall ? ' tall' : ''}`} role="dialog" aria-modal="true">
        <div className="sheet-head">
          <div className="left">{left}</div>
          <h2>{title}</h2>
          <button className="done" onClick={onClose}>{doneLabel ?? t('Fertig')}</button>
          {sub && <div className="sheet-sub">{sub}</div>}
        </div>
        {children}
      </div>
    </div>,
    document.body,
  )
}

export type DialogAction = { label: string; onClick?: () => void; destructive?: boolean; bold?: boolean }
export function Dialog({ title, message, actions, onClose }: { title: ReactNode; message?: ReactNode; actions: DialogAction[]; onClose: () => void }) {
  return createPortal(
    <div className="dialog" onClick={e => { if (e.target === e.currentTarget) onClose() }}>
      <div className="dialog-box" role="alertdialog">
        <h3>{title}</h3>
        {message && <p style={{ whiteSpace: 'pre-line' }}>{message}</p>}
        <div className="actions">
          {actions.map((a, i) => (
            <button key={i} className={`${a.destructive ? 'destructive' : ''}${a.bold ? ' bold' : ''}`} onClick={() => { onClose(); a.onClick?.() }}>{a.label}</button>
          ))}
        </div>
      </div>
    </div>,
    document.body,
  )
}

export function useToast(): [ReactNode, (text: string) => void] {
  const [text, setText] = useState<string | null>(null)
  const timer = useRef(0)
  const show = (value: string) => {
    setText(value)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setText(null), 2400)
  }
  return [text ? <div className="toast" key={text}>{text}</div> : null, show]
}

export function Switch({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label?: string }) {
  return <button type="button" role="switch" aria-checked={on} aria-label={label} className={`switch${on ? ' on' : ''}`} onClick={() => onChange(!on)} />
}

export function Progress({ value, kind, height = 7, style }: { value: number; kind?: 'mana' | 'blue'; height?: number; style?: CSSProperties }) {
  return <div className={`progress${kind ? ' ' + kind : ''}`} style={{ height, ...style }}><i style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%` }} /></div>
}

// MARK: Confetti

export function Confetti({ count = 80, duration = 2600 }: { count?: number; duration?: number }) {
  const [pieces] = useState(() => Array.from({ length: count }, (_, i) => ({
    left: Math.random() * 100, delay: Math.random() * 400, dur: duration * (0.7 + Math.random() * 0.6), rot: Math.random() * 720 - 360,
    drift: Math.random() * 30 - 15, color: ['#F2C14E', '#2F6FE4', '#E0413A', '#8B5CF6', '#6FBF73', '#FFF4DC', '#7FD3F5'][i % 7], w: 6 + Math.random() * 6,
  })))
  return (
    <div className="confetti" aria-hidden="true">
      {pieces.map((p, i) => (
        <i key={i} style={{ left: `${p.left}%`, width: p.w, height: p.w * 0.45, background: p.color, animationDelay: `${p.delay}ms`, animationDuration: `${p.dur}ms`,
          ['--rot' as string]: `${p.rot}deg`, ['--drift' as string]: `${p.drift}vw` }} />
      ))}
    </div>
  )
}

/** Rays behind a reward (LightRays). */
export function Rays({ color = '#F2C14E', size = 300, style }: { color?: string; size?: number; style?: CSSProperties }) {
  const rays = 14
  // Own gradient id per instance: with one shared id every ray set took the colour of the first one on the page.
  const id = 'rayfade' + useId().replace(/:/g, '')
  return (
    <svg className="spin-slow" width={size} height={size} viewBox="-50 -50 100 100" style={{ position: 'absolute', pointerEvents: 'none', ...style }} aria-hidden="true">
      <defs><radialGradient id={id}><stop offset="0" stopColor={color} stopOpacity=".55" /><stop offset="1" stopColor={color} stopOpacity="0" /></radialGradient></defs>
      {Array.from({ length: rays }, (_, i) => {
        const a = (i / rays) * Math.PI * 2, b = a + Math.PI / rays * 0.55
        return <path key={i} d={`M0 0 L${Math.cos(a) * 50} ${Math.sin(a) * 50} L${Math.cos(b) * 50} ${Math.sin(b) * 50} Z`} fill={`url(#${id})`} />
      })}
    </svg>
  )
}

export function Stars({ n = 26 }: { n?: number }) {
  const [stars] = useState(() => Array.from({ length: n }, () => ({ x: Math.random() * 100, y: Math.random() * 100, s: 1 + Math.random() * 2, d: Math.random() * 3 })))
  return (
    <div className="twinkle" aria-hidden="true">
      {stars.map((s, i) => <i key={i} style={{ left: `${s.x}%`, top: `${s.y}%`, width: s.s, height: s.s, animationDelay: `${s.d}s` }} />)}
    </div>
  )
}
