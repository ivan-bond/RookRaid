// ChestViews.swift (opening) and PlayViews.swift (Schatzkammer / chest hub).
import { useEffect, useMemo, useRef, useState } from 'react'
import { avatarImage, cardArt } from '../art'
import { AVATARS, BOARD_COLORS, BOARD_NAMES, CARDS, CARD_IDS, CHEST, CHEST_SOURCE, FRAMES, PITY_LIMIT, PUZZLES_PER_CHEST, ROAD, ROLES, STREAK_MILESTONES, TIERS, WIN_CHESTS_PER_DAY, cardCost, ladderChest, levelStep, type CardId, type ChestRarity } from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeChests, closeSheet, openChests, openOverlay, openSheet, run } from '../nav'
import { Icon } from '../ui/Icon'
import { ChestView, Confetti, FlameIcon, ManaDrop, PlayerAvatar, Rays, Sheet, ShardIcon, Stars } from '../ui/kit'
import { BOTS } from '../game/catalog'

function chestTitle(c: S.Chest, t: (k: string, ...a: Array<string | number>) => string) {
  const src = t(CHEST_SOURCE[c.source].title)
  return c.label ? `${src} · ${localizedLabel(c.label, t)}` : src
}
function localizedLabel(label: string, t: (k: string, ...a: Array<string | number>) => string) {
  const [a, b] = label.split(' ')
  if (a === 'Level' && b) return t('Level {0}', Number(b))
  if (b === 'Tage') return t('{0} Tage', Number(a))
  if (b === 'Trophäen') return t('{0} Trophäen', Number(a))
  const bot = BOTS.find(x => x.name === label)
  return t(bot ? bot.name : label)
}
function reasonHeadline(c: S.Chest, t: (k: string, ...a: Array<string | number>) => string): string {
  const n = c.label ? Number(c.label.split(' ').find(x => /^\d+$/.test(x))) : NaN
  switch (c.source) {
    case 'tutorial': return t('Erste Schlacht gewonnen!')
    case 'win': return t('Für deinen Sieg!')
    case 'daily': return t('Alle Tagesziele geschafft!')
    case 'ladder': return c.label ? t('{0} besiegt!', localizedLabel(c.label, t)) : t('Leiter-Sieg!')
    case 'puzzle': return t('{0} Rätsel gelöst!', 5)
    case 'level': return Number.isFinite(n) ? t('Level {0} erreicht!', n) : t('Level aufgestiegen!')
    case 'arena': return c.label ? t('Neue Arena: {0}!', t(c.label)) : t('Neue Arena!')
    case 'welcome': return t('Willkommen in der Arena!')
    case 'road': return Number.isFinite(n) ? t('{0} Trophäen erreicht!', n) : t('Trophäenpfad!')
    case 'streak': return Number.isFinite(n) ? t('{0} Tage Flamme!', n) : t('Flamme gehalten!')
    case 'shop': return t('Frisch aus dem Laden!')
    case 'friend': return t('Dein erster Freund!')
  }
}

type Phase = 'drop' | 'charge' | 'burst' | 'reveal' | 'summary'

/** Full-screen chest opening. Opens `first`, then the other waiting chests (or only those in `only`). */
export function ChestOpening({ first, only }: { first: S.Chest; only: Set<string> | null }) {
  const { t } = useI18n()
  const [chest, setChest] = useState(first)
  const plan = useMemo(() => S.planChest(chest), [chest])
  const [phase, setPhase] = useState<Phase>('drop')
  const [taps, setTaps] = useState(0)
  const [rewards, setRewards] = useState<S.Reward[]>([])
  const [shown, setShown] = useState(0)
  const [shout, setShout] = useState<string | null>(null)
  const [shake, setShake] = useState(0)
  const timer = useRef(0)
  const rarity: ChestRarity = taps === 0 ? chest.rarity : plan.steps[taps - 1]
  const upgraded = taps > 0 && plan.steps[taps - 1] !== (taps === 1 ? chest.rarity : plan.steps[taps - 2])

  useEffect(() => {
    setPhase('drop'); setTaps(0); setRewards([]); setShown(0); setShout(null)
    sound('chest_land')
    const id = window.setTimeout(() => setPhase('charge'), 650)
    return () => window.clearTimeout(id)
  }, [chest])

  const remaining = () => S.pendingChests().filter(c => !only || only.has(c.id))

  const tap = () => {
    // During the drop and the burst the chest animates on its own – a tap must not cancel the step that follows.
    if (phase === 'drop' || phase === 'burst') return
    window.clearTimeout(timer.current)
    if (phase === 'charge') {
      if (taps < 3) {
        const next = taps + 1
        const before = taps === 0 ? chest.rarity : plan.steps[taps - 1]
        const after = plan.steps[next - 1]
        setTaps(next)
        setShake(s => s + 1)
        if (after !== before) { sound('chest_upgrade'); haptic('chestBig'); setShout(t(CHEST[after].shout)) } else { sound('chest_tap'); haptic('chest') }
      } else {
        setPhase('burst')
        sound('chest_open'); haptic('chestBig')
        const got = S.openChest(plan)
        setRewards(got)
      }
      return
    }
    if (phase === 'reveal') {
      if (shown < rewards.length) {
        const r = rewards[shown]
        const big = r.kind !== 'xp' && r.kind !== 'shards'
        sound(big ? 'reward_big' : r.kind === 'shards' ? 'shard_shower' : 'reward')
        if (big) haptic('chestBig')
        setShown(shown + 1)
      } else setPhase('summary')
      return
    }
    if (phase === 'summary') next()
  }

  useEffect(() => {
    if (phase !== 'burst') return
    const id = window.setTimeout(() => { setPhase('reveal'); setShown(1); sound('reward') }, 750)
    return () => window.clearTimeout(id)
  }, [phase])

  // Auto-advance like the app (tapping speeds it up).
  useEffect(() => {
    if (phase !== 'reveal') return
    const r = rewards[shown - 1]
    const big = r && r.kind !== 'xp' && r.kind !== 'shards'
    timer.current = window.setTimeout(tap, big ? 2200 : 1000)
    return () => window.clearTimeout(timer.current)
  })

  const next = () => {
    const rest = remaining()
    if (rest.length) setChest(rest[0])
    else closeChests()
  }

  const info = CHEST[rarity]
  const left = remaining().length
  const reward = phase === 'reveal' ? rewards[shown - 1] : null
  return (
    <div className="full chest-open" onClick={tap} style={{ ['--glow' as string]: info.glow, ['--body' as string]: info.body }}>
      <div className="co-bg" />
      <Stars n={40} />
      <div className="co-top">
        <span className="kicker" style={{ color: info.glow }}>{chestTitle(chest, t)}</span>
        <b className="co-reason">{reasonHeadline(chest, t)}</b>
        {left > 1 && phase !== 'summary' && <span className="dim" style={{ fontSize: 12 }}>{t('danach noch {0}', left - 1)}</span>}
      </div>
      {(phase === 'drop' || phase === 'charge' || phase === 'burst') && (
        <div className="co-stage">
          <Rays size={420} color={info.glow} style={{ opacity: phase === 'burst' ? 1 : 0.35 + taps * 0.18 }} />
          <div key={shake} className={`co-chest ${phase === 'drop' ? 'co-drop' : phase === 'burst' ? 'co-burst' : taps ? 'co-hit' : 'co-idle'}`}>
            <ChestView rarity={rarity} size={190} glow={phase === 'burst' ? 1 : taps / 3} lid={phase === 'burst' ? 1 : 0} />
          </div>
          {shout && upgraded && <b key={'s' + taps} className="co-shout" style={{ color: info.light }}>{shout}</b>}
          <div className="co-charge">{[0, 1, 2].map(i => <i key={i} className={i < taps ? 'on' : ''} style={i < taps ? { background: CHEST[plan.steps[i]].glow } : undefined} />)}</div>
          <span className="co-hint">{phase === 'charge' ? (taps < 3 ? t('Tippe auf die Truhe!') : t('Jetzt aufsprengen!')) : ''}</span>
          <b className="co-name" style={{ color: info.light }}>{t(info.name)}</b>
        </div>
      )}
      {phase === 'burst' && <div className="co-flash" />}
      {phase === 'reveal' && reward && (
        <div className="co-reveal" key={shown}>
          <RewardReveal r={reward} />
          <span className="co-hint">{t('Tippen zum Beschleunigen')}</span>
        </div>
      )}
      {phase === 'summary' && (
        <div className="co-summary pop-in">
          <Confetti count={40} />
          <b className="title-l">{t('Ausbeute')}</b>
          <div className="co-tiles">{rewards.map((r, i) => <RewardTile key={i} r={r} />)}</div>
          {left > 0 ? <span className="dim">{left === 1 ? t('Gleich kommt die nächste Truhe …') : t('Gleich: noch {0} Truhen', left)}</span> : null}
          <button className="chunky gold" onClick={e => { e.stopPropagation(); next() }}>{left > 0 ? t('Öffnen') : t('Weiter')}</button>
        </div>
      )}
      <button className="co-close icon-btn" onClick={e => { e.stopPropagation(); closeChests() }} aria-label={t('Schließen')}><Icon name="xmark" size={18} /></button>
    </div>
  )
}

const RAINBOW = 'linear-gradient(135deg, #FF6B6B, #FFC36B, #FFF06B, #6BFF9E, #6BD5FF, #9B6BFF, #FF6BE1)'
/** The whole card, not a cut-out of its art (ShowcaseCard in ChestViews.swift): art, name, role, mana, tier frame. */
function ShowcaseCard({ card }: { card: CardId }) {
  const { t } = useI18n()
  const info = CARDS[card]
  const tier = TIERS[info.tier].color
  const role = ROLES[info.role]
  const frame = info.tier === 'epic' ? RAINBOW : `linear-gradient(#fff, ${tier}, ${tier}b3)`
  return (
    <div className="showcase-card flip-in" style={{ ['--tier' as string]: tier, ['--frame' as string]: frame }}>
      <img src={cardArt(`art-card-${card}`)} alt="" draggable={false} />
      <div className="sc-foot">
        <b>{t(info.name)}</b>
        <span className="sc-role" style={{ background: role.color + 'd9' }}><Icon name={role.icon} size={10} />{t(role.name)}</span>
      </div>
      <ManaDrop text={cardCost(card)} size={40} style={{ left: 6, top: 6 }} />
    </div>
  )
}

function RewardReveal({ r }: { r: S.Reward }) {
  const { t } = useI18n()
  if (r.kind === 'xp') return <div className="rv"><div className="rv-big xp"><Icon name="sparkles" size={64} /></div><b className="rv-num">+{r.n}</b><span className="rv-label">{t('Erfahrung')}</span></div>
  if (r.kind === 'shards' || r.kind === 'jackpot') return (
    <div className="rv">
      <div className="rv-big"><ShardIcon size={92} /></div>
      <b className="rv-num">+{r.n}</b>
      <span className="rv-label">{r.kind === 'jackpot' ? t('SAMMLUNG KOMPLETT!') : t('Splitter')}</span>
      {r.kind === 'jackpot' && <span className="dim">{t('Splitter-Fund')}</span>}
    </div>
  )
  if (r.kind === 'card') {
    const info = CARDS[r.card as CardId]
    return (
      <div className="rv">
        <Rays size={460} color={TIERS[info.tier].color} />
        <span className="rv-shout" style={{ color: TIERS[info.tier].color }}>{t('NEUE KARTE!')}</span>
        <ShowcaseCard card={r.card as CardId} />
        <b className="rv-num" style={{ fontSize: 28 }}>{t(info.name)}</b>
        <span className="capsule chip" style={{ color: TIERS[info.tier].color, borderColor: TIERS[info.tier].color }}>{t(TIERS[info.tier].name)}</span>
        <span className="dim" style={{ maxWidth: 300, textAlign: 'center' }}>{t(info.text)}</span>
      </div>
    )
  }
  if (r.kind === 'board') {
    const c = BOARD_COLORS[r.board]
    return (
      <div className="rv">
        <Rays size={420} />
        <span className="rv-shout">{t('NEUES BRETT!')}</span>
        <div className="rv-board">{Array.from({ length: 16 }, (_, i) => <i key={i} style={{ background: (Math.floor(i / 4) + i) % 2 ? c.dark : c.light }} />)}</div>
        <b className="rv-num" style={{ fontSize: 26 }}>{t(BOARD_NAMES[r.board])}</b>
        <span className="dim">{t('Im Profil unter Garderobe → Bretter auswählbar.')}</span>
      </div>
    )
  }
  if (r.kind === 'avatar') return (
    <div className="rv"><Rays size={420} /><span className="rv-shout">{t('NEUER AVATAR!')}</span><PlayerAvatar avatar={r.avatar} size={150} />
      <b className="rv-num" style={{ fontSize: 26 }}>{t(AVATARS.find(a => a.id === r.avatar)?.name ?? '')}</b><span className="dim">{t('Im Profil: Tipp auf deinen Avatar.')}</span></div>
  )
  if (r.kind === 'frame') return (
    <div className="rv"><Rays size={420} color={FRAMES[r.frame].colors[0]} /><span className="rv-shout">{t('NEUER RAHMEN!')}</span><PlayerAvatar avatar={S.activeAvatar()} frame={r.frame} size={150} />
      <b className="rv-num" style={{ fontSize: 26 }}>{t(FRAMES[r.frame].name)}</b><span className="dim">{t('Im Profil: Tipp auf deinen Avatar.')}</span></div>
  )
  return (
    <div className="rv"><Rays size={420} /><span className="rv-shout">{t('NEUER TITEL!')}</span><div className="rv-title">{t(r.title).toUpperCase()}</div>
      <span className="dim">{t('Im Profil: Tipp auf deinen Avatar.')}</span></div>
  )
}

export function RewardTile({ r }: { r: S.Reward }) {
  const { t } = useI18n()
  let icon: React.ReactNode = null
  let label = ''
  if (r.kind === 'xp') { icon = <Icon name="sparkles" size={24} color="var(--mana-light)" />; label = t('+{0} XP', r.n) }
  if (r.kind === 'shards' || r.kind === 'jackpot') { icon = <ShardIcon size={24} />; label = t('+{0} Splitter', r.n) }
  if (r.kind === 'card') { icon = <img src={cardArt(`art-card-${r.card}`)} alt="" style={{ width: 30, height: 38, objectFit: 'cover', borderRadius: 6 }} />; label = t(CARDS[r.card].name) }
  if (r.kind === 'board') { icon = <Icon name="checker" size={24} color="var(--gold)" />; label = t(BOARD_NAMES[r.board]) }
  if (r.kind === 'avatar') { icon = <img src={avatarImage(r.avatar)} alt="" style={{ width: 32, height: 32, borderRadius: 16 }} />; label = t(AVATARS.find(a => a.id === r.avatar)?.name ?? '') }
  if (r.kind === 'frame') { icon = <PlayerAvatar avatar={S.activeAvatar()} frame={r.frame} size={32} />; label = t(FRAMES[r.frame].name) }
  if (r.kind === 'title') { icon = <Icon name="medal" size={24} color="var(--gold)" />; label = t(r.title) }
  // Subtitle like RewardRevealCard in the app
  const sub = r.kind === 'xp' ? t('Erfahrung') : r.kind === 'shards' ? t('für den Laden') : r.kind === 'jackpot' ? t('Sammlung komplett')
    : r.kind === 'card' ? t('Neue Karte · {0}', t(TIERS[CARDS[r.card as CardId].tier].name)) : r.kind === 'board' ? t('Neues Brett')
    : r.kind === 'avatar' ? t('Neuer Avatar') : r.kind === 'frame' ? t('Neuer Rahmen') : t('Neuer Titel')
  return <div className={`reward-tile${r.kind !== 'xp' && r.kind !== 'shards' ? ' big' : ''}`}>{icon}<span className="rt-text"><span>{label}</span><small>{sub}</small></span></div>
}

// MARK: Schatzkammer (ChestHubSheet)

type Spark = { id: number; x: number; y: number; color: string }
const SPARK_COLORS = ['#F2C14E', '#FFE38A', '#fff', '#7FE3FF', '#FF8A3D']

/** Golden sparks that fly out of the spot you tapped – pure fun, everywhere in the treasure chamber. */
function useSparks() {
  const [sparks, setSparks] = useState<Spark[]>([])
  const seq = useRef(0)
  const burst = (e: { clientX: number; clientY: number }, n = 12) => {
    const id0 = seq.current
    const fresh = Array.from({ length: n }, (_, i) => ({ id: id0 + i, x: e.clientX, y: e.clientY, color: SPARK_COLORS[i % SPARK_COLORS.length] }))
    seq.current += n
    setSparks(s => [...s, ...fresh])
    window.setTimeout(() => setSparks(s => s.filter(x => x.id < id0 || x.id >= id0 + n)), 900)
  }
  const layer = (
    <div className="hub-sparks" aria-hidden="true">
      {sparks.map((s, i) => {
        const a = (i * 137.5) % 360, d = 40 + ((i * 53) % 50)
        return <i key={s.id} style={{ left: s.x, top: s.y, background: s.color, ['--tx' as string]: `${Math.cos(a * Math.PI / 180) * d}px`, ['--ty' as string]: `${Math.sin(a * Math.PI / 180) * d}px` }} />
      })}
    </div>
  )
  return { burst, layer }
}

function SectionTitle({ icon, text, trailing }: { icon: string; text: string; trailing?: string }) {
  return (
    <div className="hub-title">
      <Icon name={icon} size={13} /><span>{text}</span><span className="spacer" />{trailing && <span className="num hub-title-trail">{trailing}</span>}
    </div>
  )
}

export function ChestHub() {
  const { t } = useI18n()
  const p = S.useProfile()
  const goals = S.dailyGoals(p)
  const done = goals.filter(g => g.done).length
  const pendingDaily = p.chests.find(c => c.source === 'daily')
  const ready = S.dailyChestReady(p) || !!pendingDaily
  const opened = S.dailyChestOpened(p) && !pendingDaily
  const earned = p.winChestDay === S.dayKey() ? p.winChestsToday : 0
  const pendingWin = p.chests.filter(c => c.source === 'win')
  const unopened = Math.min(earned, pendingWin.length)
  const stored = p.chests.filter(c => c.source !== 'daily').sort((a, b) => b.rarity - a.rarity)
  const best = [...p.chests].sort((a, b) => b.rarity - a.rarity)[0]
  const midnight = useMidnight()
  const { burst, layer } = useSparks()
  const [poke, setPoke] = useState<string | null>(null)
  const [hop, setHop] = useState(0)

  const open = (c: S.Chest) => { closeSheet(); window.setTimeout(() => openChests(c), 200) }
  const openDaily = () => {
    if (pendingDaily) return open(pendingDaily)
    const c = S.claimDailyChest(); if (c) open(c)
  }
  const goal = (kind: S.DailyGoal['kind']) => {
    closeSheet()
    window.setTimeout(() => {
      if (kind === 'win') run('quickBattle')
      else openOverlay({ kind: 'puzzle', puzzle: S.dailyPuzzle(), daily: true })
    }, 250)
  }
  /** A locked chest shakes its head; the treasure in the header hops and spits sparks. */
  const nope = (key: string) => { haptic('invalid'); sound('select'); setPoke(null); window.requestAnimationFrame(() => setPoke(key)) }
  const tickle = (e: React.MouseEvent) => { setHop(h => h + 1); burst(e, 16); sound('chest_tap'); haptic('chest') }

  const allCards = CARD_IDS.every(c => S.isCardUnlocked(c, p))
  const pityLeft = Math.max(1, PITY_LIMIT - p.pityCounter)
  const pity = allCards ? t('Alle Karten gesammelt') : pityLeft === 1 ? t('Neue Karte spätestens in der nächsten Truhe') : t('Neue Karte spätestens in {0} Truhen', pityLeft)

  return (
    <Sheet onClose={closeSheet} wide tall>
      <div className="hub2">
        <Stars n={22} />
        <div className="hub2-head">
          <button className="hub2-crest" onClick={tickle} aria-label={t('SCHATZKAMMER')}>
            <span className="hub2-crest-rays"><Rays size={92} /></span>
            <span key={hop} className={hop ? 'hub-hop' : 'bob'}><ChestView rarity={4} size={56} glow={0.6} /></span>
          </button>
          <div className="col grow" style={{ gap: 2, minWidth: 0 }}>
            <b className="hub2-name">{t('SCHATZKAMMER')}</b>
            <span className="muted" style={{ fontSize: 12, fontWeight: 600 }}>{t('Siege, Tagesziele und Belohnungen füllen deine Truhen.')}</span>
          </div>
        </div>

        <div className="hub2-chips">
          <span className={`hub2-chip${best ? ' hot' : ''}`}><Icon name="box" size={12} />{t('{0} bereit', p.chests.length)}</span>
          <span className="hub2-chip"><Icon name="checkCircle" size={12} />{t('{0} geöffnet', p.chestsOpened)}</span>
          <span className="hub2-chip pity"><Icon name="stack" size={12} />{pity}</span>
        </div>
        {best && (
          <button className="chunky gold pulse-gold hub2-best" onClick={() => best.source === 'daily' ? openDaily() : open(best)}>
            <span className="jiggle" style={{ display: 'inline-flex' }}><ChestView rarity={best.rarity} size={34} glow={0.6} /></span>
            {t('{0} öffnen', t(CHEST[best.rarity].name))}<span className="shine" />
          </button>
        )}

        <div className="hub-grid">
          <section className="hub2-wood">
            <i className="rivet tl" /><i className="rivet tr" /><i className="rivet bl" /><i className="rivet br" />
            <SectionTitle icon="trophy" text={t('SIEGTRUHEN HEUTE')} trailing={`${earned}/${WIN_CHESTS_PER_DAY}`} />
            <div className="hub2-pedestals">
              {Array.from({ length: WIN_CHESTS_PER_DAY }, (_, i) => {
                const closed = i < earned && i >= earned - unopened
                const wasOpened = i < earned && !closed
                const next = i === earned
                const key = 'p' + i
                return (
                  <button key={i} className={`hub2-ped${closed ? ' closed' : ''}${next ? ' next' : ''}${wasOpened ? ' opened' : ''}${poke === key ? ' nope' : ''}`}
                    onClick={e => { if (closed && pendingWin[0]) { burst(e, 20); open(pendingWin[0]) } else nope(key) }}
                    aria-label={closed ? t('Siegtruhe bereit, öffnen') : wasOpened ? t('Siegtruhe geöffnet') : t('Siegtruhe {0}: noch nicht gewonnen', i + 1)}>
                    <span className="hub2-ped-art">
                      {closed && <span className="hub2-ped-rays"><Rays size={100} /></span>}
                      <span className={closed ? 'jiggle' : ''} style={{ display: 'inline-flex' }}>
                        <ChestView rarity={0} size={60} lid={wasOpened ? 1 : 0} glow={closed ? 0.8 : 0} />
                      </span>
                      {wasOpened ? <span className="hub2-ped-check"><Icon name="checkCircle" size={22} /></span>
                        : !closed && <span className="hub2-ped-lock"><Icon name="lock" size={13} /></span>}
                    </span>
                    <span className="hub2-stone" />
                    <span className="hub2-ped-label">{closed ? t('Öffnen!') : wasOpened ? t('Geöffnet') : next ? t('Nächster Sieg') : t('Sieg {0}', i + 1)}</span>
                  </button>
                )
              })}
            </div>
            <span className="hub2-note"><Icon name="info" size={12} />{earned >= WIN_CHESTS_PER_DAY ? t('Alle Siegtruhen für heute geholt – neue in {0}', midnight) : t('Jeder Sieg im Kampf füllt einen Platz – bis zu {0} pro Tag.', WIN_CHESTS_PER_DAY)}</span>
          </section>

          <section className="hub2-daily">
            <SectionTitle icon="sun" text={t('TAGESTRUHE')} trailing={`${done}/${goals.length}`} />
            <div className="row" style={{ gap: 14, alignItems: 'center' }}>
              <button className={`hub2-ring${ready ? ' ready' : ''}${poke === 'daily' ? ' nope' : ''}`}
                onClick={e => { if (ready) { burst(e, 20); openDaily() } else nope('daily') }}>
                {ready && <span className="hub2-ring-rays"><Rays size={130} /></span>}
                <svg width="100" height="100" viewBox="0 0 100 100">
                  <defs><linearGradient id="hubring" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#FFE38A" /><stop offset=".5" stopColor="#F2C14E" /><stop offset="1" stopColor="#D98A1F" /></linearGradient></defs>
                  <circle cx="50" cy="50" r="45" fill="none" stroke="#ffffff1a" strokeWidth="6" />
                  {done > 0 && <circle className="hub2-ring-arc" cx="50" cy="50" r="45" fill="none" stroke="url(#hubring)" strokeWidth="6" strokeLinecap="round"
                    strokeDasharray={`${(done / Math.max(1, goals.length)) * 282.7} 300`} transform="rotate(-90 50 50)" />}
                </svg>
                <span className={ready ? 'jiggle' : ''} style={{ display: 'inline-flex', filter: opened ? 'saturate(.3)' : ready ? undefined : 'saturate(.6)' }}>
                  <ChestView rarity={2} size={66} lid={opened ? 1 : 0} glow={ready ? 0.9 : 0.15} />
                </span>
              </button>
              <div className="col grow" style={{ gap: 6, minWidth: 0 }}>
                <b className="hub2-daily-title">{opened ? t('Tagestruhe geöffnet!') : ready ? t('Alle Ziele geschafft!') : t('Goldtruhe')}</b>
                <span className="muted" style={{ fontSize: 12, fontWeight: 600 }}>{opened ? t('Morgen gibt es neue Ziele und eine neue Goldtruhe.') : ready ? t('Deine Goldtruhe wartet.') : t('Schaffe alle 3 Ziele – dann gehört dir die Goldtruhe.')}</span>
                <span className="dim num" style={{ fontSize: 11, fontWeight: 700 }}><Icon name="clock" size={11} /> {t('Neue Ziele in {0}', midnight)}</span>
              </div>
            </div>
            <div className="col" style={{ gap: 8 }}>
              {goals.map(g => (
                <div key={g.kind} className={`hub2-goal${g.done ? ' done' : ''}`}>
                  <span className="hub2-goal-dot"><Icon name={g.done ? 'check' : g.icon} size={15} /></span>
                  <div className="col grow" style={{ gap: 2, minWidth: 0 }}>
                    <b>{t(g.title)}</b>
                    <span className="dim" style={{ fontSize: 11, fontWeight: 600 }}>{g.kind === 'flame' ? t('Löse ein Puzzle oder beende eine Partie') : g.kind === 'puzzle' ? t('Das Rätsel des Tages im Puzzle-Tab') : t('Gewinne eine Partie – Kampf oder Leiter')}</span>
                  </div>
                  {g.done ? <span className="hub2-goal-star" aria-label={t('Erledigt')}><Icon name="star" size={17} /></span>
                    : <button className="hub2-go" onClick={() => goal(g.kind)}>{t('Los')}</button>}
                </div>
              ))}
            </div>
            {ready && (
              <button className="chunky gold pulse-gold" onClick={e => { burst(e, 20); openDaily() }}><Icon name="hand" size={18} />{t('Goldtruhe öffnen')}<span className="shine" /></button>
            )}
          </section>
        </div>

        {stored.length > 0 && (
          <section className="hub2-panel">
            <SectionTitle icon="box" text={t('IM LAGER')} trailing={String(stored.length)} />
            <div className="hub2-store">
              {stored.map(c => (
                <button key={c.id} className="hub2-stored" style={{ ['--glow' as string]: CHEST[c.rarity].glow }} onClick={e => { burst(e, 16); open(c) }} aria-label={t('{0} öffnen', chestTitle(c, t))}>
                  <span className="hub2-stored-art"><span className="jiggle" style={{ display: 'inline-flex' }}><ChestView rarity={c.rarity} size={54} glow={0.5} /></span></span>
                  <b>{t(CHEST[c.rarity].name)}</b>
                  <span className="dim clip1" style={{ fontSize: 10, fontWeight: 600, maxWidth: '100%' }}>{chestTitle(c, t)}</span>
                  <span className="hub2-open-pill">{t('Öffnen')}</span>
                </button>
              ))}
            </div>
          </section>
        )}

        <MoreChests p={p} />
        <button className="ghost" onClick={() => openSheet('shop')}><Icon name="bag" size={14} /> {t('Splitter-Laden')}</button>
      </div>
      {layer}
    </Sheet>
  )
}

/** Where the next chests come from, with live progress: level, puzzles, trophy road, flames, ladder. */
function MoreChests({ p }: { p: S.Profile }) {
  const { t } = useI18n()
  const lv = S.levelProgress(p)
  const solved = p.solvedPuzzles.length % PUZZLES_PER_CHEST
  const road = S.roadTrophies(p)
  const nextRoad = ROAD.find(s => s.trophies > road)
  const prevRoad = [...ROAD].reverse().find(s => s.trophies <= road)?.trophies ?? 0
  const streak = S.currentStreak(p)
  const nextFlame = STREAK_MILESTONES.find(m => m.chest !== undefined && !p.streakMilestones.includes(m.days) && m.days > streak)
  const prevFlame = [...STREAK_MILESTONES].reverse().find(m => m.days <= streak)?.days ?? 0
  const nextBot = p.ladderBeaten < BOTS.length ? BOTS[p.ladderBeaten] : null
  const roadRarity = (nextRoad?.reward.kind === 'chest' || nextRoad?.reward.kind === 'arena') ? nextRoad.reward.rarity : null
  const tiles: Array<{ key: string; icon: string; title: string; sub: string; frac: number; rarity: ChestRarity | null; tint: string }> = [
    { key: 'level', icon: 'arrowUpCircle', title: t('Level-Truhe'), sub: t('{0} XP bis Level {1}', lv.remaining, lv.level + 1), frac: lv.fraction, rarity: levelStep(lv.level + 1).rarity, tint: '#6E9BF0' },
    { key: 'puzzle', icon: 'puzzle', title: t('Rätseltruhe'), sub: t('{0}/{1} gelöst', solved, PUZZLES_PER_CHEST), frac: solved / PUZZLES_PER_CHEST, rarity: 1, tint: '#F2C14E' },
    { key: 'road', icon: 'trophy', title: t('Trophäenpfad'), sub: nextRoad ? t('Noch {0} Trophäen', nextRoad.trophies - road) : t('Alles erreicht'),
      frac: nextRoad ? (road - prevRoad) / Math.max(1, nextRoad.trophies - prevRoad) : 1, rarity: roadRarity, tint: '#F07A72' },
    { key: 'flame', icon: 'flame', title: t('Flammentruhe'), sub: nextFlame ? t('Noch {0} Tage', nextFlame.days - streak) : t('Alles erreicht'),
      frac: nextFlame ? (streak - prevFlame) / Math.max(1, nextFlame.days - prevFlame) : 1, rarity: nextFlame?.chest ?? null, tint: '#FF8A3D' },
    { key: 'ladder', icon: 'stairs', title: t('Leiter-Truhe'), sub: nextBot ? t('Nächster: {0}', t(nextBot.name)) : t('Alles erreicht'),
      frac: p.ladderBeaten / BOTS.length, rarity: nextBot ? ladderChest(nextBot) : null, tint: '#C084FC' },
  ]
  return (
    <section className="hub2-panel">
      <SectionTitle icon="plusCircle" text={t('MEHR TRUHEN')} />
      <div className="more-chests">
        {tiles.map(x => (
          <div key={x.key} className="mc-tile" style={{ ['--tint' as string]: x.tint }}>
            <span className="mc-ico"><Icon name={x.icon} size={15} /></span>
            <div className="col grow" style={{ gap: 4, minWidth: 0 }}>
              <b className="clip1">{x.title}</b>
              <span className="mc-sub clip1">{x.sub}</span>
              <span className="mc-bar"><i style={{ width: `${Math.round(Math.min(1, Math.max(0, x.frac)) * 100)}%` }} /></span>
            </div>
            {x.rarity !== null && <ChestView rarity={x.rarity} size={38} glow={x.frac >= 0.8 ? 0.6 : 0} className={x.frac >= 0.8 ? 'jiggle' : ''} />}
          </div>
        ))}
      </div>
    </section>
  )
}

export function useMidnight() {
  const { t } = useI18n()
  const [now, setNow] = useState(Date.now())
  useEffect(() => { const id = window.setInterval(() => setNow(Date.now()), 30_000); return () => window.clearInterval(id) }, [])
  const mid = new Date(now); mid.setHours(24, 0, 0, 0)
  const mins = Math.max(0, Math.round((mid.getTime() - now) / 60000))
  return mins >= 60 ? t('{0} h {1} min', Math.floor(mins / 60), mins % 60) : t('{0} min', mins)
}

export { openChests }
