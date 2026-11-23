// Design system of the menu redesign (V2 · list style) – DesignSystem.swift for the browser.
// One gold button per screen (the main action); everything else is a list row, a secondary button or a text link.
// Colours carry meaning: purple = mana/XP, orange = flame, blue = shards/shop, green = done, gold = main action/trophies.
import type { ReactNode } from 'react'
import { cardArt } from '../art'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { openSheet } from '../nav'
import { Icon } from './Icon'

/** ShardPill.short: 999 · 1.2k · 12k · 1.2M */
export function shortNumber(n: number): string {
  const one = (v: number, unit: string) => { const r = Math.floor(v * 10) / 10; return (Number.isInteger(r) ? String(r) : r.toFixed(1)) + unit }
  if (n < 1000) return String(n)
  if (n < 10_000) return one(n / 1000, 'k')
  if (n < 1_000_000) return Math.floor(n / 1000) + 'k'
  return one(n / 1_000_000, 'M')
}

/** Flame streak · shards (opens the shop) · trophies (opens the trophy road). `onArt`: darker fill without border. */
export function ResourcePills({ onArt = false }: { onArt?: boolean }) {
  const p = S.useProfile()
  const { t } = useI18n()
  const streak = S.currentStreak(p)
  const cls = `ds-pill num${onArt ? ' on-art' : ''}`
  return (
    <div className="ds-pills">
      <button className={cls} onClick={() => openSheet('flame')} aria-label={t('Flamme, {0} Tage in Folge', streak)}>
        <Icon name="flame" size={19} color={S.flameLitToday(p) ? 'var(--ds-flame)' : '#5A6785'} />{streak}
      </button>
      <button className={cls} onClick={() => openSheet('shop')} aria-label={t('Laden, {0} Splitter', p.shards)}>
        <Icon name="bag" size={19} color="var(--ds-gem)" />{shortNumber(p.shards)}
      </button>
      <button className={cls} onClick={() => openSheet('road')} aria-label={t('Trophäenpfad, {0} Trophäen', p.trophies)}>
        <Icon name="trophy" size={19} color="var(--ds-gold)" />{p.trophies}
      </button>
    </div>
  )
}

/** Same header on every tab: title left, pills right, optional settings gear. */
export function ScreenHeader({ title, gear = false, children }: { title: string; gear?: boolean; children?: ReactNode }) {
  const { t } = useI18n()
  return (
    <div className="ds-header">
      <h1 className="ds-title">{title}</h1>
      {children}
      <span className="spacer" />
      <ResourcePills />
      {gear && <button className="ds-gear" onClick={() => openSheet('settings')} aria-label={t('Einstellungen')}><Icon name="gear" size={22} /></button>}
    </div>
  )
}

export function SectionLabel({ text, trailing, trailingColor, action }: {
  text: string; trailing?: ReactNode; trailingColor?: string; action?: { label: string; onClick: () => void }
}) {
  return (
    <div className="ds-section">
      <span className="ds-section-t">{text}</span>
      <span className="spacer" />
      {trailing !== undefined && <span className="ds-section-tr" style={{ color: trailingColor }}>{trailing}</span>}
      {action && <button className="ds-link" onClick={action.onClick}>{action.label}</button>}
    </div>
  )
}

/** The one gold button of the screen, pinned above the tab bar. */
export function PrimaryButton({ title, sub, icon, disabled = false, onClick }: {
  title: string; sub?: string; icon?: string; disabled?: boolean; onClick: () => void
}) {
  return (
    <button className="ds-primary" disabled={disabled} onClick={onClick}>
      {icon && <Icon name={icon} size={20} />}
      <span className="ds-primary-t">{title}</span>
      {sub && <span className="ds-primary-s">{sub}</span>}
    </button>
  )
}

/** Pinned area for the gold button (stays above the tab bar; the page scrolls above it). */
export const PrimaryDock = ({ children }: { children: ReactNode }) => <div className="ds-dock">{children}</div>

export const ListGroup = ({ children }: { children: ReactNode }) => <div className="ds-group">{children}</div>

export const IconTile = ({ icon, color }: { icon: string; color?: string }) => (
  <span className="ds-tile"><Icon name={icon} size={19} color={color ?? 'var(--ds-text)'} /></span>
)

export type Trailing = { kind: 'chevron' } | { kind: 'value'; value: ReactNode; chevron?: boolean } | { kind: 'done' } | { kind: 'none' }

/** A full-width row: icon, title and subtitle, trailing value or chevron (64 px, compact 52 px). */
export function ListRow({ icon, title, sub, trailing = { kind: 'chevron' }, compact = false, onClick, children, label }: {
  icon: ReactNode; title: ReactNode; sub?: ReactNode; trailing?: Trailing; compact?: boolean; onClick?: () => void; children?: ReactNode; label?: string
}) {
  const { t } = useI18n()
  const body = (
    <>
      {icon}
      <span className="ds-row-text">
        <b className="ds-row-t">{title}</b>
        {sub && <span className="ds-row-s">{sub}</span>}
        {children}
      </span>
      {trailing.kind === 'value' && <b className="ds-row-v num">{trailing.value}</b>}
      {trailing.kind === 'done' && <span aria-label={t('Erledigt')}><Icon name="check" size={18} color="var(--ds-green)" /></span>}
      {(trailing.kind === 'chevron' || (trailing.kind === 'value' && trailing.chevron !== false)) && <Icon name="chevronRight" size={14} color="var(--ds-chevron)" />}
    </>
  )
  const cls = `ds-row${compact ? ' compact' : ''}`
  return onClick ? <button className={cls} onClick={onClick} aria-label={label}>{body}</button> : <div className={cls} aria-label={label}>{body}</div>
}

export const DSProgress = ({ value, color = 'var(--ds-gold)' }: { value: number; color?: string }) => (
  <span className="ds-bar" aria-hidden="true"><i style={{ width: `${Math.max(0, Math.min(1, value)) * 100}%`, background: color }} /></span>
)

/** Segmented filter; the selected segment uses the icon-tile fill (not gold or blue). */
export function Segmented<T extends string | null>({ items, value, onChange }: { items: Array<[T, string]>; value: T; onChange: (v: T) => void }) {
  return (
    <div className="ds-seg" role="tablist">
      {items.map(([v, label]) => (
        <button key={String(v)} role="tab" aria-selected={v === value} className={v === value ? 'on' : ''} onClick={() => onChange(v)}>{label}</button>
      ))}
    </div>
  )
}

/** Card art (4:5) for the deck strip and the collection. No art = free slot; `gold` = the ultimate. */
export function DeckThumb({ art, gold = false, dim = false, badge }: { art?: string; gold?: boolean; dim?: boolean; badge?: ReactNode }) {
  return (
    <span className={`ds-thumb${gold ? ' gold' : ''}${art ? '' : ' empty'}${dim ? ' dim' : ''}`}>
      {art ? <img src={cardArt(art)} alt="" draggable={false} /> : <Icon name="plus" size={16} />}
      {badge && <span className="ds-thumb-badge">{badge}</span>}
    </span>
  )
}
