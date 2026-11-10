// RootView (HomeViews.swift): five tabs, full-screen views on top, sheets and the little celebrations.
import { lazy, Suspense, useEffect, useState } from 'react'
import { appLogo, logoMark, rockyFace } from './art'
import { unlockAudio } from './game/feedback'
import * as S from './game/store'
import { useI18n } from './i18n'
import { closeSheet, openChests, openOverlay, openSheet, setTab, useNav, type Tab } from './nav'
import * as Online from './online'
import { Icon } from './ui/Icon'
import { ChestOpening, ChestHub } from './screens/Chests'
import { DeckScreen, PresetSheet, UltimateSheet } from './screens/Deck'
import { HomeScreen } from './screens/Home'
import { LEGAL_PATHS } from './screens/Legal'
import { AchievementsSheet, ProfileScreen, StatisticsSheet, StyleSheet } from './screens/Profile'
import { PuzzleHub } from './screens/Puzzles'
import { LadderSheet, RoadGuide, RoadScreen } from './screens/Road'
import { RulesSheet } from './screens/Rules'
import { LanguageSheet, LegalSheet, NameSheet, SettingsSheet } from './screens/Settings'
import { ShopSheet } from './screens/Shop'
import { FlameIgnition, FlameSheet, FreezeNotice } from './screens/Flame'
import { isFirstVisit, markVisited } from './cookies'
import { SignInButtons, SignInErrorDialog } from './screens/Login'
import { FriendBanner, FriendProfileSheet, FriendsSheet, OpenInAppBar } from './screens/Friends'
import * as Friends from './friends'
import * as FriendMatch from './friendMatch'
import { FriendMatchInviteBanner, FriendMatchWaiting, installFriendMatchStart } from './screens/FriendMatch'
import { syncPush } from './push'

// Full-screen views load when first opened, so the first visit and the public pages download less.
const GameScreen = lazy(() => import('./screens/Game').then(m => ({ default: m.GameScreen })))
const Matchmaking = lazy(() => import('./screens/Matchmaking').then(m => ({ default: m.Matchmaking })))
const CardLab = lazy(() => import('./screens/Lab').then(m => ({ default: m.CardLab })))
const PuzzlePlayer = lazy(() => import('./screens/Puzzles').then(m => ({ default: m.PuzzlePlayer })))
const PuzzleRush = lazy(() => import('./screens/Puzzles').then(m => ({ default: m.PuzzleRush })))
const ReplayViewer = lazy(() => import('./screens/Replay').then(m => ({ default: m.ReplayViewer })))
const Intro = lazy(() => import('./screens/Intro').then(m => ({ default: m.Intro })))

const TABS: Array<[Tab, string, string]> = [
  ['arena', 'Pfad', 'trophy'], ['puzzles', 'Puzzles', 'puzzle'], ['play', 'Spielen', 'bolt'], ['deck', 'Deck', 'stack'], ['profile', 'Profil', 'person'],
]

function badge(tab: Tab, p: S.Profile, requests = 0): { count: number; dot: boolean } {
  switch (tab) {
    case 'play': return { count: p.chests.length + (S.dailyChestReady(p) ? 1 : 0), dot: false }
    case 'puzzles': return { count: 0, dot: S.dailyBonusAvailable(p) }
    case 'deck': return { count: S.newCardCount(p), dot: p.tutorialSeen && !S.deckIsFull(p) }
    case 'arena': return { count: S.claimableRoadSteps(p).length, dot: false }
    case 'profile': return { count: S.claimableAchievements(p).length + requests, dot: false }
  }
}
const Badge = ({ b }: { b: { count: number; dot: boolean } }) =>
  b.count > 0 ? <span className="badge">{b.count > 9 ? '9+' : b.count}</span> : b.dot ? <span className="badge dot" /> : null

export function App() {
  const nav = useNav()
  const p = S.useProfile()
  const { t } = useI18n()
  const flame = S.useFlameCelebration()
  const splash = false
  const account = Online.useAccount()
  const [invite, setInvite] = useState(false)
  const [snoozed, setSnoozed] = useState(false)
  const [applePrompt, setApplePrompt] = useState(false)
  const friends = Friends.useFriends()
  const requests = Friends.incomingCount(friends)

  useEffect(() => {
    S.checkStreak()
    // No loading screen: the first visit (cookie rr_visited) goes straight into the first battle.
    const first = isFirstVisit() && !S.getProfile().tutorialSeen
    markVisited()
    // First the short interactive introduction, then the guided battle against Mila.
    if (first) openOverlay({ kind: 'intro' })
    const unlock = () => { unlockAudio(); window.removeEventListener('pointerdown', unlock) }
    window.addEventListener('pointerdown', unlock)
    const onVis = () => { if (document.visibilityState === 'visible') { S.checkStreak(); if (!nav.overlay) void Online.refreshAccount() } }
    document.addEventListener('visibilitychange', onVis)
    return () => document.removeEventListener('visibilitychange', onVis)
  }, [])
  // Friends and push follow the account: load the list, register this browser for push (if allowed).
  useEffect(() => { installFriendMatchStart() }, [])
  useEffect(() => {
    if (account.status !== 'anonymous' && account.status !== 'secured') { void Friends.refreshFriends(); FriendMatch.reset(); return }
    void Friends.refreshFriends()
    void FriendMatch.touch()
    void syncPush()
    const code = Friends.consumeInvite()
    if (code) openSheet('friends', code)
  }, [account.status, account.userId])
  // Opened from a friend link (/f/CODE) or a push tap: straight to the friends list.
  useEffect(() => {
    const launch = Friends.takeLaunch()
    if (launch.openFriends) openSheet('friends', launch.code)
    const onMessage = (e: MessageEvent) => { if (e.data?.type === 'rookraid-open') openSheet('friends') }
    navigator.serviceWorker?.addEventListener('message', onMessage)
    return () => navigator.serviceWorker?.removeEventListener('message', onMessage)
  }, [])
  // Signed in with Apple, but the name is taken or invalid: ask for a player name (like the app's name sheet).
  useEffect(() => { if (account.needsName && nav.sheet !== 'onlineName') openSheet('onlineName', 'apple') }, [account.needsName])

  // Rocky invites to the deck workshop after the first battle (only on the play tab, nothing else open).
  useEffect(() => {
    if (splash || nav.overlay || nav.chests || flame !== null || nav.tab !== 'play' || snoozed || !S.needsDeckTour(p) || invite) return
    const id = window.setTimeout(() => setInvite(true), 900)
    return () => window.clearTimeout(id)
  }, [splash, nav.overlay, nav.chests, nav.tab, flame, p.chests.length, p.deckTourDone, p.tutorialSeen])
  useEffect(() => {
    if (splash || nav.overlay || invite || flame !== null) return
    const id = window.setTimeout(() => { if (Online.isConfigured() && Online.consumeApplePrompt()) setApplePrompt(true) }, 1100)
    return () => window.clearTimeout(id)
  }, [splash, nav.overlay])

  const overlay = nav.overlay
  const sheet = nav.sheet
  return (
    <div className="app">
      <nav className="rail" aria-label="Rook Raid">
        <div className="rail-brand"><img src={appLogo} alt="" /><b>Rook Raid</b></div>
        {(account.status === 'guest' || account.status === 'anonymous') && <SignInButtons compact />}
        {TABS.map(([id, label, icon]) => (
          <button key={id} className={`rail-tab${nav.tab === id ? ' on' : ''}`} onClick={() => setTab(id)}>
            <Icon name={icon} size={20} />{t(label)}<Badge b={badge(id, p, requests)} />
          </button>
        ))}
        <div className="rail-sep" />
        <button className="rail-tab" onClick={() => openSheet('chestHub')}><Icon name="box" size={20} />{t('Truhen')}</button>
        <button className="rail-tab" onClick={() => openSheet('shop')}><Icon name="bag" size={20} />{t('Splitter-Laden')}</button>
        <button className="rail-tab" onClick={() => openSheet('ladder')}><Icon name="stairs" size={20} />{t('Bot-Leiter')}</button>
        <div className="rail-foot">
          <button className="rail-link" onClick={() => openSheet('settings')}><Icon name="gear" size={16} />{t('Einstellungen')}</button>
          <button className="rail-link" onClick={() => openSheet('rules')}><Icon name="book" size={16} />{t('Regeln')}</button>
          <a className="rail-link" href={LEGAL_PATHS.privacy} onClick={e => { e.preventDefault(); openSheet('legal-privacy') }}><Icon name="shield" size={16} />{t('Datenschutz')}</a>
          <a className="rail-link" href={LEGAL_PATHS.imprint} onClick={e => { e.preventDefault(); openSheet('legal-imprint') }}><Icon name="doc" size={16} />{t('Impressum')}</a>
          <a className="rail-link" href={LEGAL_PATHS.terms} onClick={e => { e.preventDefault(); openSheet('legal-terms') }}><Icon name="bookOpen" size={16} />{t('Nutzungsbedingungen')}</a>
          <a className="rail-link" href={LEGAL_PATHS.support} onClick={e => { e.preventDefault(); openSheet('legal-support') }}><Icon name="envelope" size={16} />{t('Hilfe & Kontakt')}</a>
          <span className="rail-copy">© 2026 Ivan Bondarenko</span>
        </div>
      </nav>

      <div className="app-main">
        {nav.tab === 'play' && <HomeScreen />}
        {nav.tab === 'arena' && <RoadScreen />}
        {nav.tab === 'puzzles' && <PuzzleHub />}
        {nav.tab === 'deck' && <DeckScreen />}
        {nav.tab === 'profile' && <ProfileScreen />}
      </div>

      <nav className="tabbar" aria-label="Rook Raid">
        {TABS.map(([id, label, icon]) => (
          <button key={id} className={`tab${nav.tab === id ? ' on' : ''}`} onClick={() => setTab(id)} aria-label={t(label)}>
            <span className="pill-bg">
              {id === 'play' ? <img src={logoMark} alt="" className={`tab-logo${nav.tab === id ? ' on' : ''}`} /> : <Icon name={icon} size={18} />}
              <Badge b={badge(id, p, requests)} />
            </span>
            <span className="lbl">{t(label)}</span>
            <span className="bar" />
          </button>
        ))}
      </nav>

      <Suspense fallback={null}>
      {overlay?.kind === 'game' && <GameScreen key={String(overlay.game.startedAt) + overlay.game.mode.kind} game={overlay.game} />}
      {overlay?.kind === 'puzzle' && <PuzzlePlayer key={overlay.puzzle.id} puzzle={overlay.puzzle} daily={overlay.daily} />}
      {overlay?.kind === 'rush' && <PuzzleRush />}
      {overlay?.kind === 'lab' && <CardLab startKey={overlay.key} />}
      {overlay?.kind === 'matchmaking' && <Matchmaking />}
      {overlay?.kind === 'intro' && <Intro />}
      {overlay?.kind === 'replay' && <ReplayViewer id={overlay.id} />}
      </Suspense>

      {sheet === 'settings' && <SettingsSheet />}
      {sheet === 'chestHub' && <ChestHub />}
      {sheet === 'ladder' && <LadderSheet />}
      {sheet === 'shop' && <ShopSheet />}
      {sheet === 'flame' && <FlameSheet />}
      {sheet === 'achievements' && <AchievementsSheet />}
      {sheet === 'style' && <StyleSheet />}
      {sheet === 'rules' && <RulesSheet onClose={closeSheet} />}
      {sheet === 'stats' && <StatisticsSheet />}
      {sheet === 'presets' && <PresetSheet />}
      {sheet === 'ultimates' && <UltimateSheet />}
      {sheet === 'name' && <NameSheet online={false} />}
      {sheet === 'onlineName' && <NameSheet online />}
      {sheet === 'language' && <LanguageSheet />}
      {sheet === 'roadGuide' && <RoadGuide />}
      {sheet === 'friends' && <FriendsSheet />}
      {sheet === 'friendProfile' && <FriendProfileSheet />}
      {sheet === 'legal-privacy' && <LegalSheet page="privacy" />}
      {sheet === 'legal-imprint' && <LegalSheet page="imprint" />}
      {sheet === 'legal-terms' && <LegalSheet page="terms" />}
      {sheet === 'legal-support' && <LegalSheet page="support" />}

      {nav.chests && <ChestOpening key={nav.chests.first.id} first={nav.chests.first} only={nav.chests.only} />}

      {!splash && !overlay && !nav.chests && p.freezeNotice === null && flame !== null && (
        <FlameIgnition streak={flame} onClose={() => S.clearFlameCelebration()} />
      )}
      {!splash && p.freezeNotice !== null && !overlay && (
        <FreezeNotice days={p.freezeNotice} streak={S.currentStreak(p)} onClose={() => S.update(x => { x.freezeNotice = null })} />
      )}
      {invite && !overlay && !nav.chests && (
        <RockyInvite chests={p.chests.length > 0}
          onPrimary={() => { setInvite(false); if (p.chests.length) openChests(p.chests[0]); else setTab('deck') }}
          onSecondary={() => { setInvite(false); if (p.chests.length) setTab('deck'); else setSnoozed(true) }} />
      )}
      {applePrompt && <AppleSecure onClose={() => setApplePrompt(false)} />}
      {!overlay && <FriendBanner />}
      {!overlay && <FriendMatchInviteBanner />}
      <FriendMatchWaiting />
      <OpenInAppBar />
      <SignInErrorDialog />
    </div>
  )
}

function RockyInvite({ chests, onPrimary, onSecondary }: { chests: boolean; onPrimary: () => void; onSecondary: () => void }) {
  const { t } = useI18n()
  return (
    <div className="overlay-center fade-in invite">
      <div className="invite-box slide-up">
        <img src={rockyFace} alt="" className="rocky-face bob" />
        <div className="rocky-bubble">
          <p>{chests ? t('Starke erste Schlacht! In deinen Truhen warten neue Karten – öffne sie zuerst, dann bauen wir zusammen dein Deck.')
            : t('Starke erste Schlacht! Jetzt brauchst du ein eigenes Deck – komm mit in meine Werkstatt, ich zeig dir, wie\'s geht.')}</p>
          <button className="chunky gold sm" onClick={onPrimary}>{chests ? t('Truhen öffnen') : t('Ab in die Werkstatt!')}</button>
          <button className="ghost" onClick={onSecondary}>{chests ? t('Gleich zum Deck') : t('Später')}</button>
        </div>
      </div>
    </div>
  )
}

function AppleSecure({ onClose }: { onClose: () => void }) {
  const { t } = useI18n()
  return (
    <div className="overlay-center fade-in">
      <div className="invite-box slide-up">
        <img src={rockyFace} alt="" className="rocky-face bob" />
        <div className="rocky-bubble">
          <p>{t('Nicht gesichert – geht verloren, wenn du die Browserdaten löschst.')} {t('Mit Apple oder Google kannst du dich jederzeit wieder anmelden und deinen Fortschritt laden.')}</p>
          <SignInButtons highlighted={false} />
          <button className="ghost" onClick={onClose}>{t('Später')}</button>
        </div>
      </div>
    </div>
  )
}

