// StreakViews.swift: flame sheet, week strip, ignition overlay, freeze notice and the result-screen row.
import { useEffect, useState } from 'react'
import { CHEST, FLAME, FLAME_TIERS, FREEZE_PRICE, MAX_FREEZES, STREAK_MILESTONES, flameTier } from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n, getLang } from '../i18n'
import { closeSheet, openOverlay } from '../nav'
import { Icon } from '../ui/Icon'
import { ChestView, FlameIcon, LivingFlame, Sheet } from '../ui/kit'
import { useMidnight } from './Chests'

const OFF: [string, string, string] = [FLAME.off, '#7A86A3', '#A9B4C8']
const WEEK = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
const monday = (d = new Date()) => { const m = new Date(d); m.setHours(0, 0, 0, 0); m.setDate(m.getDate() - ((m.getDay() + 6) % 7)); return m }
const addDays = (d: Date, n: number) => { const x = new Date(d); x.setDate(x.getDate() + n); return x }

export function FlameSheet() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [appear, setAppear] = useState(false)
  const [bought, setBought] = useState(false)
  const [monthOffset, setMonthOffset] = useState(0)
  const lit = S.flameLitToday(p)
  const streak = S.currentStreak(p)
  const tier = flameTier(Math.max(1, streak))
  const midnight = useMidnight()
  useEffect(() => { const id = window.setTimeout(() => setAppear(true), 150); if (lit) haptic('chestBig'); return () => window.clearTimeout(id) }, [])
  const status = lit ? t('Heute entzündet – bis morgen!')
    : streak > 0 ? t('Noch {0}, um die Flamme zu entzünden.{1}', midnight, p.streakFreezes > 0 ? t(' Dein Flammenschutz springt notfalls ein.') : '')
      : t('Löse ein Puzzle oder beende eine Partie, um eine neue Serie zu starten.')
  const nextTier = FLAME_TIERS.find(f => f.days > streak)
  const n = p.streakFreezes, full = n >= MAX_FREEZES
  const start = monday()
  const todayKey = S.dayKey()
  return (
    <Sheet title={t('Flammen')} onClose={closeSheet}>
      <div className="flame-sheet" style={{ ['--glowc' as string]: (lit ? tier.colors[0] : FLAME.off) + '47' }}>
        <div className="fs-hero">
          <div className="fs-flame">
            <span style={{ transform: `scale(${appear ? 1 : 0.3})`, transformOrigin: 'bottom', transition: 'transform .55s cubic-bezier(.3,1.5,.5,1)' }}>
              <LivingFlame colors={lit ? tier.colors : OFF} lit={lit} embers={lit ? tier.embers : 3} width={210} height={230} />
            </span>
            <b className="fs-num" style={{ fontSize: streak >= 100 ? 50 : 60, opacity: appear ? 1 : 0, transform: `translateY(48px) scale(${appear ? 1 : 2.2})`, textShadow: `0 -2px 0 #ffffffb3, 0 0 10px ${lit ? tier.colors[2] : 'transparent'}` }}>{streak}</b>
          </div>
          <span className="fs-tier" style={lit ? { background: `linear-gradient(${tier.colors[2]}, ${tier.colors[0]})`, color: 'var(--navy)' } : undefined}>{lit ? t(tier.name).toUpperCase() : t('FLAMME AUS')}</span>
          <b className="r" style={{ fontSize: 24 }}>{streak === 1 ? t('1 Tag in Folge') : t('{0} Tage in Folge', streak)}</b>
          <span style={{ fontSize: 13, fontWeight: 600, textAlign: 'center', color: lit ? tier.colors[1] : 'var(--text2)' }}>{status}</span>
        </div>

        <div className="fs-week">
          {WEEK.map((d, i) => {
            const day = addDays(start, i)
            const key = S.dayKey(day)
            const active = p.activeDays.includes(key), frozen = p.frozenDays.includes(key), isToday = key === todayKey
            return (
              <span key={d} className="fs-day" style={{ transform: `scale(${appear ? 1 : 0.2})`, transitionDelay: `${0.25 + i * 0.05}s` }}>
                <span className="fs-day-ico" style={{ background: active ? '#FF7A2F40' : frozen ? '#6CC8FF38' : '#ffffff0d', boxShadow: isToday ? 'inset 0 0 0 2px var(--cream)' : undefined }}>
                  {active ? <FlameIcon size={20} /> : frozen ? <Icon name="snowflake" size={17} color={FLAME.ice} /> : <FlameOutline color={day > new Date() ? '#7E8AA366' : '#7E8AA3'} />}
                </span>
                <span style={{ fontSize: 10, fontWeight: isToday ? 900 : 700, color: isToday ? 'var(--cream)' : 'var(--muted)' }}>{t(d)}</span>
              </span>
            )
          })}
        </div>

        {!lit && (
          <button className="chunky sm" style={{ ['--c' as string]: FLAME.lit, ['--s' as string]: '#B3471A', position: 'relative', overflow: 'hidden' }}
            onClick={() => { closeSheet(); window.setTimeout(() => openOverlay({ kind: 'puzzle', puzzle: S.dailyPuzzle(), daily: true }), 350) }}>
            <FlameIcon size={18} colors={['#fff', '#fff']} />{t('Jetzt entzünden – Puzzle lösen')}<span className="shine" />
          </button>
        )}

        <div className="fs-tiers">
          {FLAME_TIERS.map(f => {
            const reached = streak >= f.days && streak > 0
            const current = f.days === tier.days && reached
            return (
              <span key={f.days} className="col" style={{ alignItems: 'center', gap: 4, flex: 1 }}>
                <span style={{ height: 28, display: 'grid', placeItems: 'end center', filter: reached ? `drop-shadow(0 0 6px ${f.colors[0]}b3)` : undefined }}>
                  <FlameIcon size={current ? 24 : 17} lit={reached} colors={[f.colors[2], f.colors[0]]} style={reached ? undefined : { opacity: 0.5 }} />
                </span>
                <b className="num" style={{ fontSize: 10, color: reached ? 'var(--text)' : 'var(--muted)' }}>{f.days}</b>
              </span>
            )
          })}
          {nextTier && <span className="fs-next" style={{ color: nextTier.colors[1] }}>{t('Noch {0} Tage bis {1}', nextTier.days - streak, t(nextTier.name))}</span>}
        </div>

        <div className="fs-stats">
          {([['Aktuell', streak, 'flame', FLAME.lit], ['Rekord', p.bestStreak, 'crown', '#F2C14E'], ['Aktive Tage', p.activeDays.length, 'calendar', '#6E9BF0'], ['Eingefroren', p.frozenDays.length, 'snowflake', FLAME.ice]] as const).map(([label, value, icon, tint]) => (
            <div key={label} className="fs-stat" style={{ borderColor: tint + '40' }}>
              <span className="fs-stat-ico" style={{ background: tint + '29' }}>{icon === 'flame' ? <FlameIcon size={15} colors={[tint, tint]} /> : <Icon name={icon} size={15} color={tint} />}</span>
              <b className="r num">{value}</b>
              <span>{t(label)}</span>
            </div>
          ))}
        </div>

        <div className="fs-freeze">
          <div className="row" style={{ gap: 10 }}>
            <div className="row" style={{ gap: 6 }}>
              {Array.from({ length: MAX_FREEZES }, (_, i) => (
                <span key={i} className={`fs-shield${i < n ? ' on' : ''}`} style={{ transform: bought && i === n - 1 ? 'scale(1.15)' : undefined }}>
                  <Icon name={i < n ? 'snowflake' : 'plus'} size={i < n ? 20 : 13} color={i < n ? '#fff' : 'var(--muted)'} />
                </span>
              ))}
            </div>
            <div className="col" style={{ gap: 2 }}>
              <b className="r" style={{ fontSize: 15 }}>{t('Flammenschutz {0}/{1}', n, MAX_FREEZES)}</b>
              <span className="dim" style={{ fontSize: 11, fontWeight: 600 }}>{t('Verpasst du einen Tag, friert ein Schutz deine Flamme automatisch ein – die Serie bleibt.')}</span>
            </div>
          </div>
          <button className="chunky sm" disabled={full} style={full ? { ['--c' as string]: 'var(--hi)', ['--s' as string]: 'var(--panel)' } : { ['--c' as string]: FLAME.ice, ['--s' as string]: FLAME.iceDark }}
            onClick={() => { if (S.buyFreeze()) { sound('reward'); haptic('chestBig'); setBought(true); window.setTimeout(() => setBought(false), 350) } else haptic('invalid') }}>
            <Icon name="snowflake" size={16} />
            <span className="grow" style={{ textAlign: 'left', fontSize: 16 }}>{full ? t('Vorrat voll') : t('Flammenschutz kaufen')}</span>
            {!full && <span className={`shard-price${p.shards >= FREEZE_PRICE ? '' : ' poor'}`}><Icon name="diamond" size={10} />{FREEZE_PRICE}</span>}
          </button>
          <span className="muted" style={{ fontSize: 10, fontWeight: 600 }}>{t('Gratis bei 7, 30, 100 und 365 Tagen in Folge.')}</span>
        </div>

        <div className="col" style={{ gap: 10 }}>
          <b className="r" style={{ fontSize: 16 }}>{t('Meilensteine')}</b>
          {STREAK_MILESTONES.map(m => {
            const reached = p.streakMilestones.includes(m.days)
            const isNext = S.nextStreakMilestone(p)?.days === m.days
            const reward = [m.chest !== undefined ? t(CHEST[m.chest].name) : '', m.shards ? t('{0} Splitter', m.shards) : '', m.freeze ? t('Flammenschutz') : ''].filter(Boolean).join(' + ')
            return (
              <div key={m.days} className={`fs-mile${isNext ? ' next' : ''}`}>
                <span className="fs-mile-n" style={{ background: reached ? FLAME.lit : 'var(--panel)', color: reached ? '#fff' : 'var(--text2)' }}>{m.days}</span>
                <span className="grow col" style={{ gap: 3 }}>
                  <b style={{ fontSize: 14, color: reached ? 'var(--text2)' : 'var(--text)' }}>{t('{0} Tage in Folge', m.days)}</b>
                  <span style={{ fontSize: 11, fontWeight: 600, color: reached ? 'var(--muted)' : 'var(--gold)' }}>{reward}</span>
                  {isNext && <span className="progress-pill"><i style={{ width: `${Math.min(1, streak / m.days) * 100}%` }} /><b>{Math.min(streak, m.days)}/{m.days}</b></span>}
                </span>
                {m.chest !== undefined && !reached && <ChestView rarity={m.chest} size={34} />}
                <Icon name={reached ? 'checkCircle' : 'lock'} size={reached ? 18 : 12} color={reached ? 'var(--blue)' : 'var(--muted)'} />
              </div>
            )
          })}
        </div>

        <Calendar offset={monthOffset} setOffset={setMonthOffset} profile={p} />
      </div>
    </Sheet>
  )
}

function FlameOutline({ color }: { color: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true">
      <path fill="none" stroke={color} strokeWidth="2" strokeLinejoin="round"
        d="M12.3 2c.6 3.3-1.3 5.3-3.1 7.4C7.4 11.5 6.6 13.3 6.6 15.6 6.6 18.9 9 21.5 12 21.5s5.4-2.6 5.4-5.9c0-3.2-1.8-5.6-3.6-7.7-.3 1.6-1 2.6-2 3.2.4-3.2-.1-6.3.5-9.1z" />
    </svg>
  )
}

function Calendar({ offset, setOffset, profile }: { offset: number; setOffset: (n: number) => void; profile: S.Profile }) {
  const { t } = useI18n()
  const now = new Date()
  const first = new Date(now.getFullYear(), now.getMonth() + offset, 1)
  const days = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
  const lead = (first.getDay() + 6) % 7
  const lang = getLang()
  const title = first.toLocaleDateString(lang === 'zh' ? 'zh-Hans' : lang, { month: 'long', year: 'numeric' })
  const todayKey = S.dayKey()
  return (
    <div className="fs-cal">
      <div className="row">
        <button className="icon-btn" disabled={offset <= -12} onClick={() => setOffset(offset - 1)}><Icon name="chevronLeft" size={14} /></button>
        <b className="r grow" style={{ textAlign: 'center', fontSize: 15 }}>{title}</b>
        <button className="icon-btn" disabled={offset >= 0} onClick={() => setOffset(offset + 1)}><Icon name="chevronRight" size={14} /></button>
      </div>
      <div className="fs-grid">
        {WEEK.map(d => <span key={d} className="muted" style={{ fontSize: 10, fontWeight: 700, textAlign: 'center' }}>{t(d)}</span>)}
        {Array.from({ length: lead }, (_, i) => <span key={'l' + i} />)}
        {Array.from({ length: days }, (_, i) => {
          const date = new Date(first.getFullYear(), first.getMonth(), i + 1)
          const key = S.dayKey(date)
          const active = profile.activeDays.includes(key), frozen = profile.frozenDays.includes(key)
          return (
            <span key={key} className="fs-cell" style={{ background: active ? '#FF7A2F40' : frozen ? '#6CC8FF40' : undefined, boxShadow: key === todayKey ? 'inset 0 0 0 1.5px var(--cream)' : undefined }}>
              {active ? <FlameIcon size={14} colors={[FLAME.lit, FLAME.lit]} /> : frozen ? <Icon name="snowflake" size={13} color={FLAME.ice} />
                : <span style={{ fontSize: 12, fontWeight: 600, color: date > now ? '#7E8AA380' : 'var(--text2)' }}>{i + 1}</span>}
            </span>
          )
        })}
      </div>
      <div className="row" style={{ gap: 14, justifyContent: 'center' }}>
        <span className="row" style={{ gap: 4 }}><FlameIcon size={10} colors={[FLAME.lit, FLAME.lit]} /><span className="muted" style={{ fontSize: 10, fontWeight: 600 }}>{t('Entzündet')}</span></span>
        <span className="row" style={{ gap: 4 }}><Icon name="snowflake" size={10} color={FLAME.ice} /><span className="muted" style={{ fontSize: 10, fontWeight: 600 }}>{t('Eingefroren')}</span></span>
      </div>
    </div>
  )
}

/** Shown once on the menu after a match or puzzle lit today's flame. */
export function FlameIgnition({ streak, onClose }: { streak: number; onClose: () => void }) {
  const { t } = useI18n()
  const [stage, setStage] = useState(0)
  useEffect(() => {
    const a = window.setTimeout(() => { setStage(1); haptic('chestBig'); sound('chest_open', 0.85) }, 280)
    const b = window.setTimeout(() => { setStage(2); haptic('victory'); sound('reward_big', 0.7) }, 460)
    const c = window.setTimeout(onClose, 2860)
    return () => { window.clearTimeout(a); window.clearTimeout(b); window.clearTimeout(c) }
  }, [])
  const tier = flameTier(Math.max(1, streak))
  return (
    <div className="ignite-overlay" onClick={onClose} style={{ background: `rgba(0,0,0,${stage ? 0.62 : 0.2})` }}>
      <div className="ign-glow" style={{ opacity: stage ? 1 : 0 }} />
      {[0, 1, 2].map(i => <i key={i} className={`ign-ring${stage ? ' go' : ''}`} style={{ animationDelay: `${0.35 + i * 0.12}s`, ['--s' as string]: 4.2 + i * 0.6 }} />)}
      <div className="col" style={{ alignItems: 'center', gap: 18, position: 'relative' }}>
        <div style={{ height: 220, display: 'grid', placeItems: 'center', position: 'relative' }}>
          {stage === 0 && <span className="ign-spark"><Icon name="sparkle" size={36} color={FLAME.glow} /></span>}
          <span style={{ transform: `scale(${stage ? 1 : 0.08})`, opacity: stage ? 1 : 0.15, transition: 'transform .45s cubic-bezier(.3,1.6,.5,1), opacity .3s', transformOrigin: 'bottom' }}>
            <LivingFlame colors={tier.colors} lit={stage > 0} embers={16} width={180} height={210} />
          </span>
        </div>
        <div className="col" style={{ alignItems: 'center', gap: 6, transform: `scale(${stage === 2 ? 1 : 0.4}) rotate(${stage === 2 ? 0 : -8}deg)`, opacity: stage === 2 ? 1 : 0, transition: 'all .45s cubic-bezier(.3,1.5,.5,1)' }}>
          <b className="r" style={{ fontSize: 28, color: '#fff', textShadow: `0 0 12px ${FLAME.lit}` }}>{t('Flamme entzündet!')}</b>
          <b className="r" style={{ fontSize: 18, color: FLAME.glow }}>{streak === 1 ? t('Tag 1 deiner Serie') : t('{0} Tage in Folge', streak)}</b>
        </div>
      </div>
    </div>
  )
}

export function FreezeNotice({ days, streak, onClose }: { days: number; streak: number; onClose: () => void }) {
  const { t } = useI18n()
  const [appear, setAppear] = useState(false)
  useEffect(() => { requestAnimationFrame(() => setAppear(true)); haptic('frost'); sound('frost') }, [])
  return (
    <div className="overlay-center fade-in" onClick={e => { if (e.target === e.currentTarget) onClose() }} style={{ background: '#000000a6' }}>
      <div className="freeze-box">
        <div className="freeze-art" style={{ transform: `scale(${appear ? 1 : 0.4})` }}>
          <i className="freeze-glow" />
          <FlameIcon size={86} colors={['#FFFFFF', FLAME.ice]} style={{ filter: `drop-shadow(0 0 16px ${FLAME.ice}cc)` }} />
          <span className="freeze-flake" style={{ transform: `translate(38px, -40px) rotate(${appear ? 180 : 0}deg)` }}><Icon name="snowflake" size={30} color="#fff" /></span>
        </div>
        <b className="r" style={{ fontSize: 26, color: '#fff' }}>{t('Flamme eingefroren!')}</b>
        <span className="dim" style={{ fontSize: 14, fontWeight: 600, textAlign: 'center' }}>{days === 1 ? t('Du hast gestern ausgesetzt – dein Flammenschutz hat deine Serie von {0} Tagen gerettet.', streak) : t('Du hast {0} Tage ausgesetzt – deine Flammenschutze haben deine Serie von {1} Tagen gerettet.', days, streak)}</span>
        <span style={{ fontSize: 12, fontWeight: 700, color: FLAME.glow, textAlign: 'center' }}>{t('Entzünde heute deine Flamme, damit sie weiterbrennt.')}</span>
        <button className="chunky sm" style={{ ['--c' as string]: FLAME.ice, ['--s' as string]: FLAME.iceDark, marginTop: 4 }} onClick={onClose}>{t('Weiter so!')}</button>
      </div>
    </div>
  )
}

/** FlameLitRow: the result screen line when this match lit the flame. */
export function FlameLitRow({ streak }: { streak: number }) {
  const { t } = useI18n()
  const p = S.useProfile()
  const m = streak >= p.bestStreak ? STREAK_MILESTONES.find(x => x.days === streak) : undefined
  return (
    <div className="flame-lit-row">
      <span className="pop-in" style={{ animationDelay: '.5s' }}><FlameIcon size={22} /></span>
      <span className="col" style={{ gap: 1 }}>
        <b style={{ fontSize: 15 }}>{t('Flamme entzündet!')}</b>
        <span className="dim" style={{ fontSize: 12, fontWeight: 600 }}>{streak === 1 ? t('Tag 1 deiner Serie') : t('{0} Tage in Folge', streak)}</span>
        {m && <span className="gold" style={{ fontSize: 11, fontWeight: 900 }}>{t('Meilenstein! {0}', [m.chest !== undefined ? t(CHEST[m.chest].name) : '', m.shards ? t('{0} Splitter', m.shards) : '', m.freeze ? t('Flammenschutz') : ''].filter(Boolean).join(' + '))}</span>}
      </span>
    </div>
  )
}
