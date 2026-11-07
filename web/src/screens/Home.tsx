// HomeView.swift (tab "Spielen"): header, continue banner, battle hero card and ladder tile.
import { useEffect, useRef, useState } from 'react'
import { arenaImage } from '../art'
import { ARENA_PALETTE, ARENAS, BOTS, CHEST, DECK_SIZE, TIME_CONTROLS, ULTS, botForTrophies, cardCost, ladderChest, type UltId } from '../game/catalog'
import { GameController } from '../game/controller'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { onAction, openChests, openOverlay, openSheet, run, setTab, parkGame, parkedGame, useNav } from '../nav'
import * as Online from '../online'
import { Icon } from '../ui/Icon'
import { CardThumb, ChestView, Dialog, FlameIcon, LevelBadge, PlayerAvatar, Progress, ShardIcon, tierColor } from '../ui/kit'
import { BotPortrait } from './Game'
import { useOnline } from '../useOnline'
import { haptic } from '../game/feedback'
import { LoginCard } from './Login'

export function useStartGame() {
  const [emptyDeck, setEmptyDeck] = useState(false)
  const start = (mode: S.GameMode, timeControl: 'none' | 'blitz5' = 'none') => {
    if (mode.kind !== 'tutorial' && !S.deckIsFull()) { setEmptyDeck(true); return }
    S.clearGame()
    parkGame(null)
    openOverlay({ kind: 'game', game: new GameController({ mode, timeControl }) })
  }
  return { start, emptyDeck, setEmptyDeck }
}

export function EmptyDeckDialog({ onClose }: { onClose: () => void }) {
  const { t } = useI18n()
  return (
    <Dialog title={t('Dein Deck braucht 4 Karten')} message={t('Du hast {0} von {1} Karten. Stell dein Deck fertig, dann geht\'s los.', S.activeDeck().length, DECK_SIZE)}
      onClose={onClose} actions={[{ label: t('Zum Deck'), bold: true, onClick: () => setTab('deck') }, { label: t('Abbrechen') }]} />
  )
}

export function HomeScreen() {
  const p = S.useProfile()
  const { t } = useI18n()
  const online = useOnline()
  const account = Online.useAccount()
  const { start, emptyDeck, setEmptyDeck } = useStartGame()
  const [matchError, setMatchError] = useState<string | null>(null)
  const [rulesNotice, setRulesNotice] = useState<Exclude<Online.RulesLock, 'open'> | null>(null)
  const arena = S.arena(p)
  const colors = ARENA_PALETTE[arena.n]

  const quickBattle = () => {
    if (!online) return
    if (!S.deckIsFull()) { setEmptyDeck(true); return }
    if (Online.isConfigured()) {
      // Like beginOnline() in the app: compare the rules first, then account or search.
      void Online.rulesLock().then(lock => {
        if (lock !== 'open') { haptic('invalid'); setRulesNotice(lock); return }
        if (Online.hasAccount()) openOverlay({ kind: 'matchmaking' })
        else openSheet('onlineName', 'battle')
      })
      return
    }
    start({ kind: 'bot', bot: botForTrophies(p.trophies).id }, 'blitz5')
  }

  useEffect(() => onAction('quickBattle', quickBattle))
  useEffect(() => onAction('startHotSeat', () => start({ kind: 'hotseat' })))
  useEffect(() => onAction('startPractice', () => start({ kind: 'practice', bot: 'easy' })))
  useEffect(() => onAction('startTutorial', () => openOverlay({ kind: 'intro' })))
  useEffect(() => onAction('openLadder', () => openSheet('ladder')))
  useEffect(() => onAction('openPendingChest', () => { const c = S.pendingChests()[0]; if (c) openChests(c) }))
  useEffect(() => {
    const id = window.setInterval(() => {
      const err = sessionStorage.getItem('rookraid.matchError')
      if (!err) return
      sessionStorage.removeItem('rookraid.matchError')
      // The server refused the rules version: same notice as the check before the search.
      if (err === Online.RULES_LOCK_TEXT.updateAvailable.detail) void Online.rulesLock().then(l => setRulesNotice(l === 'serverBehind' ? l : 'updateAvailable'))
      else setMatchError(err)
    }, 400)
    return () => window.clearInterval(id)
  }, [])

  // A match against a person still running on the server (e.g. after closing the tab).
  const [serverMatch, setServerMatch] = useState<string | null>(null)
  const nav = useNav()
  useEffect(() => {
    if (nav.overlay || parkedGame()) { setServerMatch(null); return }
    let alive = true
    void Online.activeHumanMatch().then(id => { if (alive) setServerMatch(id) })
    const onVis = () => { if (document.visibilityState === 'visible') void Online.activeHumanMatch().then(id => { if (alive) setServerMatch(id) }) }
    document.addEventListener('visibilitychange', onVis)
    return () => { alive = false; document.removeEventListener('visibilitychange', onVis) }
  }, [nav.overlay, account.status])
  const canContinue = !!parkedGame() || !!serverMatch || S.hasSavedGame()

  const resume = () => {
    const parked = parkedGame()
    if (parked) { parkGame(null); parked.noteResumed(); openOverlay({ kind: 'game', game: parked }); return }
    if (serverMatch) {
      const id = serverMatch
      setServerMatch(null)
      void Online.loadMatch(id).then(found => openOverlay({ kind: 'game', game: new GameController({ mode: { kind: 'online', matchId: id }, online: found, resumed: true }) }))
        .catch(() => setMatchError(Online.serverMessage(new Error('server'))))
      return
    }
    const saved = S.loadGame()
    if (!saved) { S.clearGame(); return }
    openOverlay({ kind: 'game', game: new GameController({ mode: saved.mode, saved }) })
  }

  return (
    <div className="page">
      <div className="page-glow" style={{ background: `linear-gradient(${colors[1]}99, transparent)` }} />
      <div className="page-inner home">
        <HomeHeader />
        <LoginCard />
        {account.pendingRestore && <RestoreBanner />}
        {canContinue && (
          <button className="panel-btn continue" onClick={resume}>
            <span className="continue-play pulse-gold"><Icon name="play" size={16} color="var(--navy)" /></span>
            <span className="grow"><b className="r" style={{ fontSize: 16, fontWeight: 900 }}>{t('Partie fortsetzen')}</b><br /><span className="dim" style={{ fontSize: 12 }}>{t('Dein Gegner wartet auf deinen Zug')}</span></span>
            <Icon name="chevronRight" size={16} color="var(--muted)" />
          </button>
        )}
        <div className="home-grid">
          <BattleHero online={online} onBattle={quickBattle} />
          <div className="home-side">
            <LadderTile onOpen={() => openSheet('ladder')} />
            <SideExtras onHotSeat={() => start({ kind: 'hotseat' })} />
          </div>
        </div>
      </div>
      {emptyDeck && <EmptyDeckDialog onClose={() => setEmptyDeck(false)} />}
      {rulesNotice && <Dialog title={t(Online.RULES_LOCK_TEXT[rulesNotice].title)} message={t(Online.RULES_LOCK_TEXT[rulesNotice].detail)}
        onClose={() => setRulesNotice(null)} actions={[{ label: t('Fertig'), bold: true }]} />}
      {matchError && <Dialog title={t('Keine Verbindung')} message={t(matchError)} onClose={() => setMatchError(null)} actions={[{ label: t('Fertig'), bold: true }]} />}
    </div>
  )
}

export function HomeHeader() {
  const p = S.useProfile()
  const { t } = useI18n()
  const lp = S.levelProgress(p)
  return (
    <div className="hdr">
      <LevelBadge level={lp.level} progress={lp.fraction} />
      <div className="grow" style={{ lineHeight: 1.15 }}>
        <div className="r clip1" style={{ fontSize: 18, fontWeight: 900 }}>{t('Level {0}', lp.level)}</div>
        <div className="muted clip1" style={{ fontSize: 11, fontWeight: 600 }}>{t('noch {0} XP', lp.remaining)}</div>
      </div>
      <FlameBadge />
      <ShardPill />
      <button className="trophy-pill num" onClick={() => setTab('arena')}><Icon name="trophy" size={17} color="var(--gold)" />{p.trophies}</button>
    </div>
  )
}

export function FlameBadge() {
  const p = S.useProfile()
  const { t } = useI18n()
  const streak = S.currentStreak(p)
  const lit = S.flameLitToday(p)
  return (
    <button className="flame-pill num" onClick={() => openSheet('flame')}
      aria-label={t('{0} Tage in Folge{1}, {2} Flammenschutz. Tippen für Statistik', streak, lit ? t(', heute entzündet') : t(', heute noch offen'), p.streakFreezes)}>
      <FlameIcon size={17} lit={lit} />
      <span style={{ color: lit ? 'var(--text)' : 'var(--text2)' }}>{streak}</span>
    </button>
  )
}

/** ShardPill.short: 999 · 1.2k · 12k · 1.2M */
export function shortNumber(n: number): string {
  const one = (v: number, unit: string) => { const r = Math.floor(v * 10) / 10; return (Number.isInteger(r) ? String(r) : r.toFixed(1)) + unit }
  if (n < 1000) return String(n)
  if (n < 10_000) return one(n / 1000, 'k')
  if (n < 1_000_000) return Math.floor(n / 1000) + 'k'
  return one(n / 1_000_000, 'M')
}

export function ShardPill() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [gain, setGain] = useState<{ n: number; id: number } | null>(null)
  const last = useRef(p.shards)
  useEffect(() => {
    const diff = p.shards - last.current
    last.current = p.shards
    if (diff > 0) { setGain({ n: diff, id: Date.now() }); const id = window.setTimeout(() => setGain(null), 1200); return () => window.clearTimeout(id) }
  }, [p.shards])
  return (
    <button className={`shard-pill num${gain ? ' pop' : ''}`} onClick={() => openSheet('shop')} aria-label={t('{0} Splitter. Tippen für den Laden', p.shards)}>
      <ShardIcon size={15} />{shortNumber(p.shards)}
      {gain && <span key={gain.id} className="shard-gain">+{gain.n}</span>}
    </button>
  )
}

function RestoreBanner() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  const pr = acc.pendingRestore!
  const snap = (pr.snapshot ?? {}) as { unlockedCards?: unknown[]; wins?: number; createdAt?: string }
  const date = snap.createdAt ? new Date(snap.createdAt).toLocaleDateString() : '–'
  return (
    <div className="card gold-edge col">
      <b className="title-m">{t('Spielstand vom Konto laden?')}</b>
      <span className="dim" style={{ fontSize: 13 }}>{t('Auf deinem Konto ist ein Spielstand gesichert: {0} Trophäen, {1} Karten, {2} Siege (Stand {3}). Laden ersetzt den Spielstand auf diesem iPhone.', pr.trophies, (snap.unlockedCards?.length ?? 0) + 4, snap.wins ?? 0, date).replace('iPhone', t('Gerät'))}</span>
      <div className="row">
        <button className="chunky sm gold" onClick={() => Online.restoreFrom(pr)}>{t('Spielstand laden')}</button>
        <button className="chunky sm gray" onClick={() => Online.dismissRestore()}>{t('Diesen Stand behalten')}</button>
      </div>
    </div>
  )
}

// MARK: Battle hero card

function BattleHero({ online, onBattle }: { online: boolean; onBattle: () => void }) {
  const p = S.useProfile()
  const { t } = useI18n()
  const arena = S.arena(p)
  const colors = ARENA_PALETTE[arena.n]
  const deck = S.activeDeck(p)
  const ult = S.activeUltimate(p)
  const full = deck.length >= DECK_SIZE
  const waiting = p.chests.length + (S.dailyChestReady(p) ? 1 : 0)
  const avg = deck.length ? deck.reduce((s, c) => s + cardCost(c), 0) / deck.length : 0
  const fan: Array<{ art?: string; border: string }> = [{ art: `art-ult-${ult}`, border: 'var(--gold)' }, ...deck.map(c => ({ art: `art-card-${c}`, border: tierColor(c) })),
    ...Array.from({ length: DECK_SIZE - deck.length }, () => ({ border: 'var(--gold)' }))]
  const mid = (fan.length - 1) / 2
  return (
    <section className="hero" style={{ borderColor: colors[0] + '8c' }}>
      <div className="hero-bg" style={{ backgroundImage: `url(${arenaImage(arena.n)})` }} />
      <div className="hero-scrim" />
      <ArenaRow />
      <div className="hero-stage">
        <button className="hero-chest jiggle-if" data-on={waiting > 0} onClick={() => openSheet('chestHub')} aria-label={t('Truhen')}>
          <span className="hero-chest-in" style={{ color: waiting ? 'var(--gold)' : 'var(--text2)', borderColor: waiting ? '#F2C14Eb3' : '#F2C14E40' }}>
            <Icon name="box" size={17} />
          </span>
          {waiting > 0 && <span className="badge" style={{ top: -4, right: -4, borderColor: 'transparent' }}>{Math.min(9, waiting)}</span>}
        </button>
        <div className="hero-me">
          <div className="podium" style={{ background: `radial-gradient(closest-side, ${colors[0]}bf, transparent)` }} />
          <div className="bob"><PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={112} /></div>
          <b className="hero-name">{S.shownName(p.name, t)}</b>
          <span className="hero-rank">{t(S.activeTitle(p)).toUpperCase()}</span>
        </div>
        <button className="hero-deck press" onClick={() => setTab('deck')}
          aria-label={t('Dein Deck: {0}, ', t(ULTS[ult as UltId].name)) + deck.map(c => t(c)).join(', ') + t('. Tippen zum Ändern')}>
          <span className="row" style={{ gap: 5, justifyContent: 'center' }}>
            <span className="kicker" style={{ color: 'var(--gold)', fontSize: 13, letterSpacing: 1.4 }}>{t('DEIN DECK')}</span>
            <Icon name="pencilCircle" size={16} color="var(--blue-light)" />
          </span>
          <span className="fan">
            {fan.map((f, i) => {
              const k = i - mid
              return <span key={i} className="fan-card" style={{ transform: `translateY(${k * k * 2.5}px) rotate(${k * 8}deg)`, zIndex: 10 - Math.abs(k) }}>
                <CardThumb art={f.art} empty={!f.art} width={60} border={f.border} />
              </span>
            })}
          </span>
          <span className="row" style={{ gap: 4, justifyContent: 'center' }}>
            <span className="capsule chip gold"><Icon name="sparkles" size={9} />{t(ULTS[ult as UltId].name)}</span>
            {full ? <span className="capsule chip"><Icon name="drop" size={9} />Ø {avg.toFixed(1)}</span>
              : <span className={`capsule chip gold${deck.length === 0 ? ' jiggle' : ''}`}><Icon name="plusCircle" size={9} />{deck.length === 0 ? t('Deck bauen') : t('{0}/{1} Karten', deck.length, DECK_SIZE)}</span>}
          </span>
        </button>
      </div>
      {full ? (
        <div className="col" style={{ gap: 8 }}>
          <div style={{ position: 'relative' }}>
            <button className={`chunky gold battle${online ? ' pulse-gold' : ''}`} disabled={!online} onClick={onBattle}
              style={online ? undefined : { ['--c' as string]: 'var(--hi)', ['--s' as string]: 'var(--panel)', ['--fg' as string]: 'var(--muted)' }}>
              <span className={online ? 'jiggle' : ''}><Icon name={online ? 'bolt' : 'wifiSlash'} size={20} /></span>
              {t('KAMPF!')}
              <Icon name="trophy" size={15} />
              {online && <span className="shine" />}
            </button>
            {S.winChestsLeftToday(p) > 0 && online && (
              <span className="win-chest-tag bob"><ChestView rarity={0} size={18} />+1</span>
            )}
          </div>
          {!online && <span className="offline-note"><Icon name="wifiSlash" size={14} />{t('Keine Internetverbindung. Kampf ist gerade nicht möglich.')}</span>}
        </div>
      ) : (
        <button className="chunky pulse-blue" onClick={() => setTab('deck')}>
          <span className="jiggle"><Icon name="stack" size={20} /></span>
          <span style={{ textAlign: 'left', lineHeight: 1.1 }}>
            {deck.length === 0 ? t('DECK BAUEN') : t('DECK FERTIG BAUEN')}
            <br /><small style={{ fontSize: 11, fontWeight: 800, opacity: 0.85 }}>{t('Für Kämpfe brauchst du 4 Karten')}</small>
          </span>
          <span className="slots-mini">{Array.from({ length: DECK_SIZE }, (_, i) => <i key={i} className={i < deck.length ? 'on' : ''} />)}</span>
        </button>
      )}
      <div className="match-row">
        <span className="row grow" style={{ gap: 4, color: 'var(--text2)' }}><Icon name="person2" size={12} /><span className="clip1" style={{ fontSize: 12, fontWeight: 600 }}>{t('Gegner mit ähnlich vielen Trophäen')}</span></span>
        <span className="capsule chip gold"><Icon name="timer" size={9} />{TIME_CONTROLS.blitz5.name}</span>
      </div>
    </section>
  )
}

function ArenaRow() {
  const p = S.useProfile()
  const { t } = useI18n()
  const arena = S.arena(p)
  const colors = ARENA_PALETTE[arena.n]
  const ready = S.claimableRoadSteps(p).length
  const next = S.nextRoadStep(p)
  const prev = next ? [...ROAD_STEPS()].reverse().find(s => s.trophies < next.trophies)?.trophies ?? 0 : 0
  const progress = next ? Math.min(1, Math.max(0, (S.roadTrophies(p) - prev) / Math.max(1, next.trophies - prev))) : 1
  return (
    <button className="arena-row" onClick={() => setTab('arena')}>
      <span className="arena-medal" style={{ background: `linear-gradient(${colors[0]}, ${colors[1]})`, boxShadow: `0 0 8px ${colors[0]}b3` }}>
        <Icon name={arena.icon} size={16} color="#fff" />
      </span>
      <span className="grow col" style={{ gap: 5 }}>
        <span className="row" style={{ gap: 6 }}>
          <span className="kicker clip1" style={{ color: 'var(--gold)', letterSpacing: 1 }}>{t('ARENA {0} · {1}', arena.n, t(arena.name).toUpperCase())}</span>
          <span className="spacer" />
          {ready > 0 ? <span className="capsule pulse-gold" style={{ background: 'var(--gold)', color: 'var(--navy)', fontWeight: 900, fontSize: 10 }}>{ready === 1 ? t('BELOHNUNG ABHOLEN') : t('{0} BELOHNUNGEN', ready)}</span>
            : next && <span className="dim clip1 num" style={{ fontSize: 11, fontWeight: 700 }}>{t('{0} bei {1}', roadTitle(next.reward, t), next.trophies)}</span>}
        </span>
        <span style={{ position: 'relative' }}><Progress value={ready ? 1 : progress} /><span className="shine" /></span>
      </span>
    </button>
  )
}
import { ROAD, BOARD_NAMES, type RoadReward } from '../game/catalog'
const ROAD_STEPS = () => ROAD
export function roadTitle(r: RoadReward, t: (k: string, ...a: Array<string | number>) => string) {
  if (r.kind === 'chest' || r.kind === 'arena') return t(CHEST[r.rarity].name)
  if (r.kind === 'shards') return t('{0} Splitter', r.n)
  return t('Brett „{0}“', t(BOARD_NAMES[r.board]))
}

// MARK: Ladder tile

function LadderTile({ onOpen }: { onOpen: () => void }) {
  const p = S.useProfile()
  const { t } = useI18n()
  const next = S.ladderNext(p)
  const beaten = p.ladderBeaten
  return (
    <button className="ladder-tile press" onClick={onOpen} style={{ ['--tint' as string]: next?.color ?? 'var(--gold)' }}
      aria-label={next ? t('Bot-Leiter, nächster Gegner {0}', t(next.name)) : t('Bot-Leiter, alle besiegt')}>
      <span className="ladder-stripe" />
      {next ? <span className="ladder-vs"><BotPortrait id={next.id} size={58} /><span className="vs-mini">VS</span></span>
        : <span className="ladder-vs"><Icon name="crown" size={40} color="var(--gold)" /></span>}
      <span className="grow col" style={{ gap: 3 }}>
        <span className="kicker" style={{ color: 'var(--gold)' }}>{t('BOT-LEITER')}</span>
        <b className="r" style={{ fontSize: 17, fontWeight: 900 }}>{next ? t(next.name) : t('Alle besiegt!')}</b>
        {!next && <span className="dim clip1" style={{ fontSize: 12 }}>{t('Revanchen bringen weiter XP')}</span>}
        {next && <span className="row" style={{ gap: 4 }}>
          <span className="capsule chip gold">{t('+{0} XP', next.xpFirstWin)}</span>
          <span className="capsule chip"><ChestView rarity={ladderChest(next)} size={14} />{t(CHEST[ladderChest(next)].short)}</span>
        </span>}
      </span>
      <span className="ladder-stairs">
        {BOTS.map((b, i) => <i key={b.id} style={{ height: 6 + i * 3.2, background: i < beaten ? b.color : i === beaten ? 'transparent' : '#ffffff1a', outline: i === beaten ? '1.5px solid var(--gold)' : undefined }} />)}
        <Icon name="crown" size={12} color={beaten >= 12 ? 'var(--gold)' : 'var(--muted)'} />
      </span>
    </button>
  )
}

/** Wide screens show the extras of the app's settings and chest hub next to the battle card. */
function SideExtras({ onHotSeat }: { onHotSeat: () => void }) {
  const { t } = useI18n()
  const p = S.useProfile()
  const goals = S.dailyGoals(p)
  const done = goals.filter(g => g.done).length
  return (
    <>
      <button className="card side-goals press" onClick={() => openSheet('chestHub')}>
        <div className="row"><span className="section-h">{t('TAGESZIELE')}</span><span className="spacer" /><span className="dim r" style={{ fontWeight: 800, fontSize: 12 }}>{t('Ziele {0}/{1}', done, goals.length)}</span></div>
        {goals.map(g => (
          <div key={g.kind} className="row" style={{ gap: 10 }}>
            <span className="goal-dot" data-done={g.done}><Icon name={g.done ? 'check' : g.icon} size={12} /></span>
            <span style={{ fontWeight: 700, textDecoration: g.done ? 'line-through' : undefined, color: g.done ? 'var(--muted)' : undefined }}>{t(g.title)}</span>
          </div>
        ))}
      </button>
      <div className="list side-modes">
        <button className="li" onClick={onHotSeat}><span className="ico" style={{ background: '#2F6FE4' }}><Icon name="person2" size={16} /></span><span className="t">{t('Zu zweit')}<br /><span className="muted" style={{ fontSize: 12, fontWeight: 500 }}>{t('Beide an diesem Gerät')}</span></span><Icon name="chevronRight" size={14} color="var(--muted)" /></button>
        <button className="li" onClick={() => openSheet('rules')}><span className="ico" style={{ background: '#8B5CF6' }}><Icon name="book" size={16} /></span><span className="t">{t('Regeln')}</span><Icon name="chevronRight" size={14} color="var(--muted)" /></button>
      </div>
    </>
  )
}

export { ARENAS, run }
