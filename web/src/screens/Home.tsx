// HomeView.swift (tab "Spielen", redesign V2): arena art, trophy-road bar, deck strip, list rows, slim ladder row and the gold Fight button.
import { useEffect, useState } from 'react'
import { arenaImage, avatarImage } from '../art'
import { BOARD_NAMES, BOTS, CARDS, CHEST, DECK_SIZE, ROAD, ULTS, botForTrophies, cardCost, type RoadReward, type UltId } from '../game/catalog'
import { GameController } from '../game/controller'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { onAction, openChests, openOverlay, openSheet, setTab, parkGame, parkedGame, useNav } from '../nav'
import * as Online from '../online'
import * as Friends from '../friends'
import { Icon } from '../ui/Icon'
import { ChestView, Dialog, FlameIcon } from '../ui/kit'
import { DSProgress, DeckThumb, IconTile, ListGroup, ListRow, PrimaryButton, PrimaryDock, ResourcePills, SectionLabel } from '../ui/ds'
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

  const deck = S.activeDeck(p)
  const ult = S.activeUltimate(p)
  const full = deck.length >= DECK_SIZE
  const avg = deck.length ? deck.reduce((sum, c) => sum + cardCost(c), 0) / deck.length : 0
  const waiting = p.chests.length + (S.dailyChestReady(p) ? 1 : 0)
  const goals = S.dailyGoals(p)
  const friendsList = Friends.useFriends().players.filter(f => f.relation === 'friend')
  const next = S.ladderNext(p)
  const lp = S.levelProgress(p)
  const chestsSub = waiting > 0 ? (waiting === 1 ? t('1 Truhe wartet') : t('{0} Truhen warten', waiting)) : t('Tagesziele {0}/{1}', goals.filter(g => g.done).length, goals.length)
  const friendsSub = friendsList.length === 0 ? t('Freunde einladen und herausfordern')
    : friendsList.length === 1 ? t('Herausfordern oder Revanche · 1 Freund') : t('Herausfordern oder Revanche · {0} Freunde', friendsList.length)

  return (
    <div className="page ds-page">
      <div className="play-art" style={{ backgroundImage: `url(${arenaImage(arena.n)})` }} />
      <div className="ds-inner">
        <div className="play-head">
          <button className="play-avatar" onClick={() => setTab('profile')} aria-label={t('Profil')}><img src={avatarImage(S.activeAvatar(p))} alt="" /></button>
          <div className="grow" style={{ lineHeight: 1.2 }}>
            <div className="play-name clip1">{S.shownName(p.name, t)}</div>
            <div className="play-rank clip1">{t('{0} · Level {1}', t(S.activeTitle(p)), lp.level)}</div>
          </div>
          <ResourcePills onArt />
        </div>
        <div style={{ padding: '10px 16px 0' }} className="col">
          <LoginCard />
          {account.pendingRestore && <RestoreBanner />}
        </div>
        <div className="play-gap" />
        <ArenaBlock />
        <SectionLabel text={t('Dein Deck · Ø {0} Mana', avg.toFixed(1))} action={{ label: t('Bearbeiten'), onClick: () => setTab('deck') }} />
        <button className="play-deck press" onClick={() => setTab('deck')}
          aria-label={t('Dein Deck: {0}, ', t(ULTS[ult as UltId].name)) + deck.map(c => t(CARDS[c].name)).join(', ') + t('. Tippen zum Ändern')}>
          {Array.from({ length: DECK_SIZE }, (_, i) => <DeckThumb key={i} art={deck[i] ? `art-card-${deck[i]}` : undefined} />)}
          <DeckThumb art={`art-ult-${ult}`} gold />
        </button>
        <ListGroup>
          {canContinue && <ListRow icon={<IconTile icon="play" color="var(--ds-gold)" />} title={t('Partie fortsetzen')} sub={t('Dein Gegner wartet auf deinen Zug')} onClick={resume} />}
          {Online.isConfigured() && <ListRow icon={<IconTile icon="person2" color="var(--ds-gem)" />} title={t('Gegen Freunde spielen')} sub={friendsSub} onClick={() => openSheet('friends')} />}
          <ListRow icon={<IconTile icon="box" color="var(--ds-gold)" />} title={t('Truhen & Tagesziele')} sub={chestsSub}
            trailing={waiting > 0 ? { kind: 'value', value: waiting } : { kind: 'chevron' }} onClick={() => openSheet('chestHub')} />
        </ListGroup>
        <button className="play-ladder" onClick={() => openSheet('ladder')}>
          {next ? <BotPortrait id={next.id} size={24} /> : <Icon name="crown" size={20} color="var(--ds-gold)" />}
          <span className="play-ladder-t"><b>{t('Bot-Leiter')}</b>{next ? t(' · nächster: {0} · {1}/{2}', t(next.name), p.ladderBeaten, BOTS.length) : t(' · alle besiegt')}</span>
          <Icon name="chevronRight" size={13} color="var(--ds-chevron)" />
        </button>
      </div>
      <PrimaryDock>
        {full && !online && <div className="ds-notice"><Icon name="wifiSlash" size={14} />{t('Keine Internetverbindung. Kampf ist gerade nicht möglich.')}</div>}
        {full
          ? <PrimaryButton title={t('Kampf')} sub={t('5 Min · gewertet')} icon="bolt" disabled={!online} onClick={quickBattle} />
          : <PrimaryButton title={deck.length === 0 ? t('Deck bauen') : t('Deck fertig bauen')} sub={t('{0}/{1} Karten', deck.length, DECK_SIZE)} icon="stack" onClick={() => setTab('deck')} />}
      </PrimaryDock>
      {emptyDeck && <EmptyDeckDialog onClose={() => setEmptyDeck(false)} />}
      {rulesNotice && <Dialog title={t(Online.RULES_LOCK_TEXT[rulesNotice].title)} message={t(Online.RULES_LOCK_TEXT[rulesNotice].detail)}
        onClose={() => setRulesNotice(null)} actions={[{ label: t('Fertig'), bold: true }]} />}
      {matchError && <Dialog title={t('Keine Verbindung')} message={t(matchError)} onClose={() => setMatchError(null)} actions={[{ label: t('Fertig'), bold: true }]} />}
    </div>
  )
}

/** Arena name and the bar to the next trophy-road reward. Tap → trophy road (all rewards stay reachable). */
function ArenaBlock() {
  const p = S.useProfile()
  const { t } = useI18n()
  const arena = S.arena(p)
  const ready = S.claimableRoadSteps(p).length
  const next = S.nextRoadStep(p)
  const prev = next ? [...ROAD].reverse().find(s => s.trophies < next.trophies)?.trophies ?? 0 : 0
  const progress = next ? (S.roadTrophies(p) - prev) / Math.max(1, next.trophies - prev) : 1
  const label = ready > 0 ? (ready === 1 ? t('Belohnung abholen') : t('{0} Belohnungen abholen', ready)) : next ? roadTitle(next.reward, t) : t('Pfad geschafft')
  const rarity = next && (next.reward.kind === 'chest' || next.reward.kind === 'arena') ? next.reward.rarity : 3
  return (
    <button className="play-arena" onClick={() => openSheet('road')} aria-label={t('Arena {0}, {1}. {2}. Trophäenpfad öffnen', arena.n, t(arena.name), label)}>
      <span>
        <span className="play-arena-k">{t('ARENA {0}', arena.n)}</span><br />
        <span className="play-arena-n">{t(arena.name)}</span>
      </span>
      <span className="play-chestbar">
        <ChestView rarity={rarity} size={30} glow={ready > 0 ? 0.6 : 0} />
        <span className="grow col" style={{ gap: 6 }}>
          <span className="row">
            <b className="grow clip1" style={{ color: ready > 0 ? 'var(--ds-gold)' : 'var(--ds-text)' }}>{label}</b>
            {next && ready === 0 && <b className="num">{S.roadTrophies(p)} / {next.trophies}</b>}
          </span>
          <DSProgress value={ready > 0 ? 1 : progress} />
        </span>
      </span>
    </button>
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

export function roadTitle(r: RoadReward, t: (k: string, ...a: Array<string | number>) => string) {
  if (r.kind === 'chest' || r.kind === 'arena') return t(CHEST[r.rarity].name)
  if (r.kind === 'shards') return t('{0} Splitter', r.n)
  return t('Brett „{0}“', t(BOARD_NAMES[r.board]))
}
