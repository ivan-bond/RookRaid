import { useEffect, useState } from 'react'
import { ARENA_COLORS, arenaImage, knightAvatar } from './art'
import { botForTrophies } from './bot'
import { arenaOf, cardArt, CARD_NAME, E, STARTER_CARDS } from './engine'
import { useI18n, type Lang } from './i18n'
import { Match } from './match'
import { MatchView } from './MatchView'
import { cancelSearch, deleteAccount, findOnlineMatch, linkApple, serverMessage, signInWithApple, signOut } from './online'
import { createAccount, currentAccount, ensureSession, ownedUltimates, saveDeck, useAccount } from './profile'
import { appleClientId } from './supabase'
import './styles.css'

type Screen = { id: 'home' | 'name' | 'search' } | { id: 'match'; match: Match }
type Tab = 'path' | 'puzzles' | 'play' | 'deck' | 'profile'

const TABS: Array<[Tab, string]> = [
  ['path', 'Pfad'],
  ['puzzles', 'Puzzles'],
  ['play', 'Spielen'],
  ['deck', 'Deck'],
  ['profile', 'Profil'],
]

const ARENAS = [
  [1, 'Trainingsgelände', 0],
  [2, 'Kasernenhof', 90],
  [3, 'Thronarena', 240],
  [4, 'Sturmfeste', 600],
  [5, 'Drachenhort', 1200],
  [6, 'Königsgipfel', 2100],
] as const

const LANGS: Array<[Lang, string]> = [['de', 'Deutsch'], ['en', 'English'], ['fr', 'Français'], ['es', 'Español'], ['it', 'Italiano'], ['zh', '中文'], ['ru', 'Русский']]

export function App() {
  const account = useAccount()
  const { t, lang, setLang } = useI18n()
  const [screen, setScreen] = useState<Screen>({ id: 'home' })
  const [tab, setTab] = useState<Tab>('play')
  const [error, setError] = useState('')
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (screen.id !== 'search') return
    let stop = false
    void (async () => {
      try {
        await ensureSession()
        if (stop) return
        const now = currentAccount()
        if (now.needsName) { setScreen({ id: 'name' }); return }
        const found = await findOnlineMatch(now.deck, now.ultimate)
        if (stop) return
        const human = found.youWhite ? 'w' as const : 'b' as const
        const match = new Match({
          kind: 'online', human, opponentName: found.opponent.name,
          decks: found.decks, ultimates: found.ultimates, online: found,
        })
        setScreen({ id: 'match', match })
      } catch (err) {
        if (stop) return
        setError(t(serverMessage(err)))
        setScreen({ id: 'home' })
      }
    })()
    return () => { stop = true; void cancelSearch() }
  }, [screen.id, t])

  function practice() {
    const bot = botForTrophies(account.trophies)
    const human = Math.random() < 0.5 ? 'w' as const : 'b' as const
    const decks = human === 'w'
      ? { white: account.deck, black: [...bot.deck] }
      : { white: [...bot.deck], black: account.deck }
    const ultimates = human === 'w'
      ? { white: account.ultimate, black: bot.ult }
      : { white: bot.ult, black: account.ultimate }
    setScreen({ id: 'match', match: new Match({ kind: 'practice', human, decks, ultimates, opponentName: bot.name }) })
  }

  function hotseat() {
    setScreen({
      id: 'match',
      match: new Match({
        kind: 'hotseat', human: 'w', opponentName: '',
        decks: { white: account.deck, black: account.deck },
        ultimates: { white: account.ultimate, black: account.ultimate },
      }),
    })
  }

  async function submitName() {
    setBusy(true)
    setError('')
    try {
      await createAccount(name.trim())
      setScreen({ id: 'search' })
    } catch (err) {
      setError(t(serverMessage(err)))
    } finally { setBusy(false) }
  }

  const arena = arenaOf(account.trophies)
  const full = screen.id === 'match'

  if (!account.ready) return <main className="stage"><p className="note">{t('Suche einen Gegner …')}</p></main>

  return (
    <div className={full ? 'shell full' : 'shell'}>
      {!full && (
        <nav className="rail" aria-label="Rook Raid">
          <div className="rail-mark">Rook Raid</div>
          {TABS.map(([id, label]) => (
            <button key={id} className={tab === id ? 'tab on' : 'tab'} onClick={() => setTab(id)}>
              <i className="glyph"><TabGlyph id={id} /></i>
              <span>{t(label)}</span>
            </button>
          ))}
          <label className="rail-lang">{t('Sprache')}
            <select value={lang} onChange={event => setLang(event.target.value as Lang)}>
              {LANGS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}
            </select>
          </label>
        </nav>
      )}
      <main className="stage">
        {screen.id === 'match' && <MatchView match={screen.match} onExit={() => setScreen({ id: 'home' })} />}
        {screen.id === 'search' && (
          <div className="page"><div className="panel"><h2>{t('Suche einen Gegner …')}</h2><button className="chunky blue" onClick={() => setScreen({ id: 'home' })}>{t('Zurück')}</button></div></div>
        )}
        {screen.id === 'name' && (
          <form className="page" onSubmit={event => { event.preventDefault(); void submitName() }}>
            <div className="panel">
              <h2>{t('Spielername wählen')}</h2>
              <input value={name} minLength={2} maxLength={16} required onChange={event => setName(event.target.value)} placeholder={t('Spielername')} />
              {error && <p className="warn">{error}</p>}
              <button className="chunky" disabled={busy}>{t('Weiter')}</button>
              <button type="button" className="ghost" onClick={() => setScreen({ id: 'home' })}>{t('Zurück')}</button>
            </div>
          </form>
        )}
        {screen.id === 'home' && tab === 'play' && (
          <PlayHome
            arena={arena}
            error={error}
            onFight={() => { setError(''); setScreen({ id: 'search' }) }}
            onPractice={practice}
            onHotseat={hotseat}
            onDeck={() => setTab('deck')}
            onArena={() => setTab('path')}
          />
        )}
        {screen.id === 'home' && tab === 'deck' && <Deck onSaved={() => setTab('play')} />}
        {screen.id === 'home' && tab === 'profile' && <Account onError={message => setError(t(message))} />}
        {screen.id === 'home' && tab === 'path' && <Path trophies={account.trophies} />}
        {screen.id === 'home' && tab === 'puzzles' && <Puzzles />}
      </main>
    </div>
  )
}

function PlayHome({ arena, error, onFight, onPractice, onHotseat, onDeck, onArena }: {
  arena: number
  error: string
  onFight: () => void
  onPractice: () => void
  onHotseat: () => void
  onDeck: () => void
  onArena: () => void
}) {
  const account = useAccount()
  const { t } = useI18n()
  const accent = ARENA_COLORS[arena - 1]
  const painting = arenaImage(arena)
  const arenaName = ARENAS[arena - 1]?.[1] ?? 'Trainingsgelände'
  return (
    <div className="lobby">
      <div className="header-row">
        <div className="level-badge">1</div>
        <div>
          <div className="title">{t('Level {0}', 1)}</div>
          <div className="kicker">{t('noch {0} XP', 100)}</div>
        </div>
        <div className="grow" />
        <div className="pill" title={t('Flamme')}>🔥</div>
        <div className="pill">✦ 0</div>
        <button className="pill" onClick={onArena}>🏆 {account.trophies}</button>
      </div>
      {error && <p className="warn">{error}</p>}
      <div className="lobby-grid">
      <section className="hero-card" style={{ borderColor: accent, backgroundImage: painting ? `linear-gradient(180deg, rgba(12,22,40,.25), rgba(12,22,40,.62)), url(${painting})` : undefined }}>
        <button className="arena-chip" onClick={onArena}>
          <i style={{ background: accent }}>{arena}</i>
          <span>{t('ARENA {0} · {1}', arena, t(arenaName).toUpperCase())}</span>
        </button>
        <div className="podium">
          <div>
            {knightAvatar && <img className="avatar" src={knightAvatar} alt="" />}
            <div className="player-name">{account.name ?? t('Gast')}</div>
            <div className="rank">{t('Springer')}</div>
          </div>
          <button className="ghost" onClick={onDeck}>
            <div className="deck-label">{t('DEIN DECK')}</div>
            <div className="fan">
              <span className="slot">{cardArt(account.ultimate) && <img src={cardArt(account.ultimate)} alt="" />}</span>
              {account.deck.map(id => <span className="slot" key={id}>{cardArt(id) && <img src={cardArt(id)} alt="" />}</span>)}
            </div>
          </button>
        </div>
        <button className="chunky" disabled={!account.configured || account.deck.length !== 4} onClick={onFight}>{t('KAMPF!')}</button>
        {!account.configured && <p className="note">{t('Kein Server konfiguriert. Üben geht weiter.')}</p>}
        <div className="match-row">
          <span>{t('Gegner mit ähnlich vielen Trophäen')}</span>
          <span className="chip">5 | 0</span>
        </div>
      </section>
      <aside className="lobby-side">
        <button className="tile ladder" onClick={onPractice}>
          <div className="vs">VS</div>
          <div>
            <div className="deck-label">{t('BOT-LEITER')}</div>
            <strong>{botForTrophies(account.trophies).name}</strong>
            <div className="kicker">{t('Gegen den Computer')}</div>
          </div>
        </button>
        <button className="tile" onClick={onHotseat}>
          <strong>{t('Zu zweit')}</strong>
          <span>{t('Beide an diesem Gerät')}</span>
        </button>
      </aside>
      </div>
    </div>
  )
}

function Path({ trophies }: { trophies: number }) {
  const { t } = useI18n()
  return (
    <div className="lobby">
      <h2 className="title">{t('Pfad')}</h2>
      <div className="arena-grid">
        {ARENAS.map(([n, name, need]) => (
          <div key={n} className="arena-row" style={{ backgroundImage: `linear-gradient(90deg, rgba(0,0,0,.55), rgba(0,0,0,.15)), url(${arenaImage(n)})`, opacity: trophies >= need ? 1 : 0.55 }}>
            <span>{t(name)} · {need}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function Puzzles() {
  const { t } = useI18n()
  const groups = [
    ['Karten-Matts', 'Erst die Karte, dann das Matt', '#6E9BF0'],
    ['Leicht', 'Klassisch · 10 XP', '#FFF4DC'],
    ['Mittel', 'Klassisch · 20 XP', '#F2C14E'],
    ['Schwer', 'Klassisch · 35 XP', '#E0413A'],
  ] as const
  return (
    <div className="lobby puzzles">
      <h2 className="title">{t('Puzzles')}</h2>
      <div className="puzzle-grid">
        {groups.map(([title, subtitle, color]) => (
          <div key={title} className="tile" style={{ borderTop: `3px solid ${color}` }}>
            <strong>{t(title)}</strong>
            <span>{t(subtitle)}</span>
          </div>
        ))}
      </div>
    </div>
  )
}

function Deck({ onSaved }: { onSaved: () => void }) {
  const account = useAccount()
  const { t } = useI18n()
  const [deck, setDeck] = useState(account.deck)
  const [ultimate, setUltimate] = useState(account.ultimate)
  const ults = ownedUltimates(account.best || account.trophies)
  const owned = account.userId ? account.unlocked : [...STARTER_CARDS]

  function toggle(id: string) {
    setDeck(current => {
      if (current.includes(id)) return current.filter(card => card !== id)
      if (current.length >= 4) return current
      return [...current, id]
    })
  }

  return (
    <div className="page">
      <div className="header-row"><h2 className="title">{t('Deck')}</h2><div className="grow" /><strong>{deck.length}/4</strong></div>
      <p className="note">{account.userId ? t('Karten vom Konto') : t('Startkarten und die Ultimates deiner Arena.')}</p>
      <div className="deck-grid">
        {owned.map(id => (
          <button key={id} className={deck.includes(id) ? 'art-card picked' : 'art-card'} onClick={() => toggle(id)}>
            {cardArt(id) && <img src={cardArt(id)} alt="" />}
            <small>{t(CARD_NAME[id] ?? id)} · {E.COST[id]}</small>
          </button>
        ))}
      </div>
      <div className="hand">
        {ults.map(id => (
          <button key={id} className={ultimate === id ? 'ult on' : 'ult'} onClick={() => setUltimate(id)}>
            {cardArt(id) && <img src={cardArt(id)} alt="" />}
            <small>{t(CARD_NAME[id] ?? id)}</small>
          </button>
        ))}
      </div>
      <button className="chunky" disabled={deck.length !== 4} onClick={() => { void saveDeck(deck, ultimate); onSaved() }}>{t('Speichern')}</button>
    </div>
  )
}

function Account({ onError }: { onError: (message: string) => void }) {
  const account = useAccount()
  const { t } = useI18n()
  const [busy, setBusy] = useState(false)

  async function run(action: () => Promise<void>) {
    setBusy(true)
    try { await action() }
    catch (err) { onError(serverMessage(err)) }
    finally { setBusy(false) }
  }

  return (
    <div className="lobby">
      <h2 className="title">{t('Profil')}</h2>
      <div className="account-grid">
      <div className="panel">
        {knightAvatar && <img className="avatar" src={knightAvatar} alt="" />}
        <h2 className="title">{account.name ?? t('Gast')}</h2>
        <p>{account.apple ? t('Mit Apple gesichert') : t('Gast')}</p>
        <p>{t('Trophäen')}: {account.trophies}</p>
        {!appleClientId && <p className="note">{t('Anmeldung mit Apple braucht eine Services ID. Trag sie als VITE_APPLE_CLIENT_ID ein und hinterlege dieselbe ID bei Supabase neben der Bundle-ID.')}</p>}
        <button className="apple" disabled={busy || !appleClientId || !account.configured} onClick={() => { void run(signInWithApple) }}>
          <AppleMark /> {t('Mit Apple anmelden')}
        </button>
        {account.anonymous && account.userId && (
          <button className="chunky blue" disabled={busy || !appleClientId} onClick={() => { void run(linkApple) }}>{t('Mit Apple sichern')}</button>
        )}
        {account.userId && <button className="chunky blue" disabled={busy} onClick={() => { void run(signOut) }}>{t('Abmelden')}</button>}
        {account.userId && (
          <button className="ghost" disabled={busy} onClick={() => { if (confirm(t('Konto löschen'))) void run(deleteAccount) }}>{t('Konto löschen')}</button>
        )}
      </div>
      </div>
    </div>
  )
}

function TabGlyph({ id }: { id: Tab }) {
  const common = { fill: 'none', stroke: 'currentColor', strokeWidth: 1.8, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const }
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true">
      {id === 'path' && <path {...common} d="M7 20h10l-1.2-4.2a5 5 0 0 0-7.6 0L7 20zm5-6.2 1.2-3.3 1.6 1.1 2.2-2.6-1.1 4.2M8 8.5l1.4 1.2L12 6l2.4 3.6L16 8" />}
      {id === 'puzzles' && <path {...common} d="M8 4h4a2 2 0 1 1 0 4h1v3h3a2 2 0 1 1 0 4h-3v3H8v-3H5a2 2 0 1 1 0-4h3V8H8a2 2 0 1 1 0-4z" />}
      {id === 'play' && <path {...common} d="M13 2 4 14h7l-1 8 9-12h-7l1-8z" />}
      {id === 'deck' && <><rect {...common} x="7" y="6" width="12" height="14" rx="2" /><rect {...common} x="4" y="4" width="12" height="14" rx="2" /></>}
      {id === 'profile' && <><circle {...common} cx="12" cy="8" r="3" /><path {...common} d="M5 19c1.5-3 3.8-4.5 7-4.5S17.5 16 19 19" /></>}
    </svg>
  )
}

function AppleMark() {
  return (
    <svg width="16" height="18" viewBox="0 0 16 18" aria-hidden="true">
      <path fill="currentColor" d="M13.2 9.5c0-2.2 1.8-3.2 1.9-3.3-1-1.5-2.6-1.7-3.2-1.7-1.3-.1-2.6.8-3.3.8s-1.7-.8-2.8-.8c-1.5 0-2.8.9-3.6 2.2-1.5 2.7-.4 6.6 1.1 8.8.7 1.1 1.6 2.3 2.7 2.2 1.1 0 1.5-.7 2.8-.7s1.7.7 2.8.7 1.9-1.1 2.6-2.1c.8-1.2 1.1-2.3 1.2-2.4-.1 0-2.2-.9-2.2-3.7zM11 3.2c.6-.7 1-1.7.9-2.7-1 .1-2.1.6-2.7 1.4-.6.7-1.1 1.7-.9 2.6 1 .1 2.1-.5 2.7-1.3z" />
    </svg>
  )
}
