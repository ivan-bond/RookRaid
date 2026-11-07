// MatchmakingSheet (MatchmakingViews.swift): arena backdrop, radar with sweep and opponent echoes, "you vs ???" with an
// avatar slot machine, search range growing from ±100 to ±400 trophies, the deck's cards as tips while waiting – and a
// golden flash with the opponent's card when someone is found. Large screens: radar on the left, the rest on the right.
import { useEffect, useState, type ReactNode } from 'react'
import { arenaImage, avatarImage, cardArt } from '../art'
import { ARENA_PALETTE, AVATARS, BOTS, CARDS, TIME_CONTROLS, botForTrophies } from '../game/catalog'
import { GameController } from '../game/controller'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeOverlay, getNav, openOverlay } from '../nav'
import * as Online from '../online'
import type { OnlineStart } from '../online'
import { Icon } from '../ui/Icon'
import { Confetti, PlayerAvatar, Stars, tierColor } from '../ui/kit'

/** Same as the server: after 10 s a stand-in takes over. */
const TIMEOUT = 10
/** Opponent echoes on the radar (angle from the right, clockwise; distance from the centre 0…1). */
const BLIPS: Array<[number, number, string]> = [[20, 0.78, 'fox'], [95, 0.55, 'owl'], [150, 0.86, 'wolf'], [215, 0.66, 'bear'], [280, 0.82, 'lion'], [330, 0.5, 'robot']]
const SWEEP_S = 3

export function Matchmaking() {
  const { t } = useI18n()
  const p = S.useProfile()
  const arena = S.arena(p)
  const colors = ARENA_PALETTE[arena.n]
  const [seconds, setSeconds] = useState(0)
  const [found, setFound] = useState<OnlineStart | null>(null)

  // The clock runs on its own (the search only reports every 2 s).
  useEffect(() => {
    if (found) return
    const started = Date.now()
    const id = window.setInterval(() => {
      const s = Math.min(TIMEOUT, Math.floor((Date.now() - started) / 1000))
      setSeconds(prev => { if (s > prev) haptic('select'); return s })
    }, 250)
    return () => window.clearInterval(id)
  }, [found])

  useEffect(() => {
    let alive = true
    sound('summon', 0.5)
    void (async () => {
      try {
        const match = await Online.findOnlineMatch()
        if (!alive) return
        // First "Opponent found!" with the card, then the battle (like the app: 1.4 s).
        setFound(match)
        sound('reward_big'); haptic('chestBig')
        await new Promise(r => setTimeout(r, 1400))
        if (!alive || getNav().overlay?.kind !== 'matchmaking') return
        const bot = match.bot ? BOTS.find(b => b.id === match.botId) ?? botForTrophies(S.getProfile().trophies) : null
        const mode: S.GameMode = match.bot ? { kind: 'bot', bot: bot!.id } : { kind: 'online', matchId: match.matchId }
        S.clearGame()
        openOverlay({ kind: 'game', game: new GameController({ mode, online: match }) })
      } catch (err) {
        if (!alive || getNav().overlay?.kind !== 'matchmaking') return
        const msg = Online.serverMessage(err)
        closeOverlay()
        if (msg !== 'Abgebrochen.') sessionStorage.setItem('rookraid.matchError', msg)
      }
    })()
    return () => { alive = false }
  }, [])

  const cancel = () => { if (found) return; void Online.cancelSearch(); closeOverlay() }
  const progress = Math.min(1, seconds / TIMEOUT)
  const range = 100 + Math.round(300 * progress)
  const opp = found?.opponent

  return (
    <div className={`full mm${found ? ' found' : ''}`}>
      <div className="mm-bg" style={{ backgroundImage: `url(${arenaImage(arena.n)})` }} />
      <div className="mm-vignette" />
      <Stars n={18} />
      {found && <div className="mm-flash" aria-hidden="true"><Confetti count={70} /></div>}

      <div className="mm-top">
        <span className="mm-arena">
          <span className="mm-arena-ico" style={{ background: `linear-gradient(${colors[0]}, ${colors[1] ?? colors[0]})` }}><Icon name={arena.icon} size={12} /></span>
          <b>{t('ARENA {0} · {1}', arena.n, t(arena.name).toUpperCase())}</b>
        </span>
        <span className="capsule chip gold"><Icon name="timer" size={11} />{t(TIME_CONTROLS.blitz5.name)}</span>
      </div>

      <div className="mm-body">
        <div className="mm-left">
          <div className="mm-title">
            {found
              ? <><b className="mm-found-t">{t('Gegner gefunden!')}</b><span className="mm-found-n">{opp?.name}</span></>
              : <><b>{t('Gegner wird gesucht')}</b><span>{seconds < 4 ? t('Spieler mit ähnlich vielen Trophäen …') : t('Noch ein Moment …')}</span></>}
          </div>
          <Radar found={!!found} accent={colors[0]} avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} />
        </div>

        <div className="mm-right">
          <div className="mm-duel">
            <Fighter name={S.shownName(p.name, t)} trophies={p.trophies}><PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={74} /></Fighter>
            <div className="mm-vs"><span className="mm-bolt"><Icon name="bolt" size={30} /></span><span className="mm-vs-tag">VS</span></div>
            {opp
              ? <Fighter name={opp.name} trophies={opp.trophies} pop><PlayerAvatar avatar={opp.avatar} frame={opp.frame ?? 'none'} size={74} /></Fighter>
              : <Fighter name="???" trophies={null}><Roulette size={74} /></Fighter>}
          </div>

          <div className={`mm-hide${found ? ' gone' : ''}`}>
            <div className="mm-search">
              <svg className="mm-ring" viewBox="0 0 58 58" width="58" height="58" aria-hidden="true">
                <defs><linearGradient id="mmRing" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#F2C14E" /><stop offset="1" stopColor="#FFA000" /></linearGradient></defs>
                <circle cx="29" cy="29" r="25" fill="none" stroke="rgba(255,255,255,.15)" strokeWidth="5" />
                <circle cx="29" cy="29" r="25" fill="none" stroke="url(#mmRing)" strokeWidth="5" strokeLinecap="round"
                  strokeDasharray={`${2 * Math.PI * 25}`} strokeDashoffset={`${2 * Math.PI * 25 * (1 - progress)}`} transform="rotate(-90 29 29)" />
                <text x="29" y="34" textAnchor="middle">{`0:${String(seconds).padStart(2, '0')}`}</text>
              </svg>
              <div className="col grow" style={{ gap: 7 }}>
                <b className="num">{t('Suchbereich ±{0} Trophäen', range)}</b>
                <div className="mm-range"><i style={{ width: `${(0.25 + 0.75 * progress) * 100}%` }} /></div>
              </div>
            </div>
            <TipTicker />
          </div>

          <button className={`chunky gray mm-cancel${found ? ' gone' : ''}`} disabled={!!found} onClick={cancel}>{t('Abbrechen')}</button>
        </div>
      </div>
    </div>
  )
}

function Fighter({ name, trophies, pop, children }: { name: string; trophies: number | null; pop?: boolean; children: ReactNode }) {
  return (
    <div className={`mm-fighter${pop ? ' pop' : ''}`}>
      <div className="mm-portrait">{children}</div>
      <b className="clip1">{name}</b>
      <span className="gold num"><Icon name="trophy" size={10} />{trophies ?? '–'}</span>
    </div>
  )
}

function Radar({ found, accent, avatar, frame }: { found: boolean; accent: string; avatar: string; frame: string }) {
  return (
    <div className="mm-radar2" style={{ ['--accent' as string]: found ? '#F2C14E' : accent, ['--sweep' as string]: `${found ? 1.4 : SWEEP_S}s` }}>
      <i className="g1" /><i className="g2" /><i className="g3" /><i className="cross" />
      <i className="pulse" /><i className="pulse" style={{ animationDelay: '-.8s' }} /><i className="pulse" style={{ animationDelay: '-1.6s' }} />
      <i className="sweep" />
      {BLIPS.map(([a, r, id]) => {
        const rad = (a * Math.PI) / 180
        return (
          <img key={id} className="blip" src={avatarImage(id)} alt=""
            style={{ left: `${50 + Math.cos(rad) * r * 50}%`, top: `${50 + Math.sin(rad) * r * 50}%`, animationDelay: `${(a / 360 - 1) * SWEEP_S}s` }} />
        )
      })}
      <div className="me"><PlayerAvatar avatar={avatar} frame={frame} size={96} /></div>
    </div>
  )
}

/** The opponent's place while searching: avatars spin like a slot machine. */
function Roulette({ size }: { size: number }) {
  const [i, setI] = useState(0)
  useEffect(() => { const id = window.setInterval(() => setI(n => n + 1), 110); return () => window.clearInterval(id) }, [])
  return (
    <span className="mm-roulette" style={{ width: size, height: size }}>
      <img src={avatarImage(AVATARS[i % AVATARS.length].id)} alt="" />
      <Icon name="question" size={size * 0.42} />
    </span>
  )
}

/** The cards of your deck with their effect – the wait becomes a little refresher. */
function TipTicker() {
  const { t } = useI18n()
  const deck = S.activeDeck()
  const [i, setI] = useState(0)
  useEffect(() => { const id = window.setInterval(() => setI(n => n + 1), 3200); return () => window.clearInterval(id) }, [])
  if (!deck.length) return null
  const card = deck[i % deck.length]
  return (
    <div className="mm-tip" key={i}>
      <img src={cardArt(`art-card-${card}`)} alt="" style={{ borderColor: tierColor(card) }} />
      <div className="col" style={{ gap: 2, minWidth: 0 }}>
        <b>{t(CARDS[card].name)}</b>
        <span>{t(CARDS[card].text)}</span>
      </div>
    </div>
  )
}
