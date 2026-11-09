// First start: introduce the player before Rocky's intro and the first battle (WelcomeView.swift in the app).
// Three short screens, like the onboarding of most mobile games: 1 the world (what is Rook Raid?) ·
// 2 who are you (name + avatar, both can be changed later) · 3 how well do you know chess (Rocky adapts his lines).
// „Überspringen“ keeps everything as it is.
import { useEffect, useState } from 'react'
import { appLogo, pieceImage } from '../art'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import * as Online from '../online'
import { useI18n } from '../i18n'
import { Icon } from '../ui/Icon'
import { PlayerAvatar, Stars } from '../ui/kit'

export type ChessLevel = 'new' | 'rules' | 'pro'
/** What the welcome found out – Rocky uses it in his first lines. */
export type Hello = { level: ChessLevel | null; named: boolean }

/** The six free avatars (the knight is everyone's; the chosen one is added to the collection). */
const STARTER_AVATARS = ['knight', 'fox', 'owl', 'bear', 'penguin', 'frog'] as const
const NAME_RE = /^[\p{L}\p{N}_.\- ]{2,16}$/u
const FIRST = ['Rook', 'Knight', 'Pawn', 'Bishop', 'Queen', 'King', 'Storm', 'Frost', 'Blitz', 'Nova', 'Shadow', 'Iron']
const SECOND = ['Raider', 'Rider', 'Hero', 'Master', 'Fox', 'Wolf', 'Star', 'Ace', 'Hawk', 'Titan']
const pick = <T,>(list: readonly T[]) => list[Math.floor(Math.random() * list.length)]
/** A name suggestion such as „FrostRider42“ (at most 14 characters, the same in every language). */
export const suggestName = () => `${pick(FIRST)}${pick(SECOND)}${10 + Math.floor(Math.random() * 90)}`

/** Is the name still free on the server? (Player names are unique.) 'unknown' = no server or no connection. */
type NameCheck = 'available' | 'taken' | 'unknown'
async function checkName(name: string): Promise<NameCheck> {
  if (!Online.isConfigured()) return 'unknown'
  try { return (await Online.nameAvailable(name)) ? 'available' : 'taken' } catch { return 'unknown' }
}
/** A suggestion that is still free (up to 5 tries; offline the first one). */
async function freeSuggestion(): Promise<string> {
  let name = suggestName()
  for (let i = 0; i < 5; i++) {
    if ((await checkName(name)) !== 'taken') return name
    name = suggestName()
  }
  return name
}

const LEVELS: Array<{ id: ChessLevel; icon: 'leaf' | 'book' | 'crown'; title: string; text: string }> = [
  { id: 'new', icon: 'leaf', title: 'Ich bin neu', text: 'Ich lerne Schach gerade erst.' },
  { id: 'rules', icon: 'book', title: 'Ich kenne die Regeln', text: 'Ich weiß, wie die Figuren ziehen.' },
  { id: 'pro', icon: 'crown', title: 'Ich spiele oft', text: 'Schach ist mein Ding.' },
]

export function Welcome({ onDone }: { onDone: (hello: Hello) => void }) {
  const { t } = useI18n()
  const [page, setPage] = useState(0)
  const [named, setNamed] = useState(false)
  const [name, setName] = useState(() => { const n = S.getProfile().name; return S.isDefaultName(n) ? suggestName() : n })
  const [avatar, setAvatar] = useState<string>(() => S.getProfile().selectedAvatar ?? 'knight')
  const [suggested] = useState(() => S.isDefaultName(S.getProfile().name))
  const [check, setCheck] = useState<NameCheck | 'checking' | null>(null)
  const trimmed = name.trim()
  const valid = trimmed === '' || (NAME_RE.test(trimmed) && trimmed === name)
  // The first suggestion should be free already.
  useEffect(() => { if (suggested) void freeSuggestion().then(n => setName(cur => (cur === name ? n : cur))) }, [])
  // Live check while typing (like the app's name sheet): a moment after the last key.
  useEffect(() => {
    setCheck(null)
    if (!trimmed || !valid) return
    let live = true
    const id = window.setTimeout(() => {
      setCheck('checking')
      void checkName(trimmed).then(c => { if (live) setCheck(c) })
    }, 400)
    return () => { live = false; window.clearTimeout(id) }
  }, [trimmed, valid])
  const nameOk = valid && check !== 'taken' && check !== 'checking' && (trimmed === '' || check !== null)
  const go = (n: number) => { sound('select'); haptic('select'); setPage(n) }
  const saveIdentity = () => {
    if (!nameOk) return
    S.update(p => {
      if (trimmed) p.name = trimmed
      if (avatar !== 'knight' && !p.ownedAvatars.includes(avatar)) p.ownedAvatars.push(avatar)
      p.selectedAvatar = avatar === 'knight' ? null : avatar
    })
    setNamed(trimmed !== '')
    go(2)
  }
  const choose = (level: ChessLevel) => { sound('reward'); haptic('success'); onDone({ level, named }) }

  return (
    <div className="full intro welcome">
      <div className="intro-bg" />
      <Stars n={36} />
      <div className="intro-top">
        <div className="intro-dots">{[0, 1, 2].map(k => <i key={k} className={k < page ? 'past' : k === page ? 'now' : ''} />)}</div>
        <button className="intro-skip" onClick={() => onDone({ level: null, named })}>{t('Überspringen')}</button>
      </div>

      {page === 0 && <>
        <div className="intro-stage welcome-hero" key="w0">
          <div className="welcome-glow" />
          <img className="welcome-logo" src={appLogo} alt="Rook Raid" />
          <div className="welcome-pieces">
            {(['n', 'b', 'q', 'r'] as const).map((p, k) => (
              <img key={p} src={pieceImage(k % 2 ? 'b' : 'w', p)} alt="" style={{ animationDelay: `${300 + k * 140}ms` }} />
            ))}
          </div>
        </div>
        <div className="intro-card" key="c0">
          <span className="intro-kicker">{t('Willkommen')}</span>
          <b className="intro-title">{t('Willkommen in Rook Raid!')}</b>
          <p className="intro-text">{t('Auf dem Schachbrett ist Chaos ausgebrochen: Die Figuren haben Superkräfte entdeckt. Führe deine eigene Armee an, sammle Karten und steig in der Arena bis an die Spitze auf.')}</p>
          <button className="chunky gold pulse-gold intro-next" onClick={() => go(1)}>
            {t("Los geht's")}<Icon name="chevronRight" size={16} /><span className="shine" />
          </button>
        </div>
      </>}

      {page === 1 && <>
        <div className="intro-stage" key="w1">
          <div className="welcome-me">
            <div className="welcome-me-ava" key={avatar}><PlayerAvatar avatar={avatar} size={124} /></div>
            <b className="welcome-me-name">{trimmed || t('Du')}</b>
            <div className="welcome-avatars" role="radiogroup" aria-label={t('Avatar')}>
              {STARTER_AVATARS.map(a => (
                <button key={a} role="radio" aria-checked={avatar === a} className={`welcome-ava${avatar === a ? ' on' : ''}`}
                  onClick={() => { haptic('select'); sound('select'); setAvatar(a) }}>
                  <PlayerAvatar avatar={a} size={52} />
                </button>
              ))}
            </div>
          </div>
        </div>
        <form className="intro-card" key="c1" onSubmit={e => { e.preventDefault(); saveIdentity() }}>
          <span className="intro-kicker">{t('Dein Held')}</span>
          <b className="intro-title">{t('Wer bist du?')}</b>
          <p className="intro-text">{t('Such dir einen Namen und ein Bild aus. Beides kannst du später im Profil ändern.')}</p>
          <div className="welcome-name">
            <input className="field" value={name} maxLength={16} onChange={e => setName(e.target.value)} placeholder={t('Spielername')}
              autoComplete="off" autoCapitalize="off" spellCheck={false} />
            <button type="button" className="welcome-dice" aria-label={t('Anderer Vorschlag')} title={t('Anderer Vorschlag')}
              onClick={() => { haptic('select'); void freeSuggestion().then(setName) }}>
              <Icon name="sparkles" size={20} />
            </button>
          </div>
          {!valid && <span className="welcome-error">{t('2–16 Zeichen: Buchstaben, Ziffern, Leerzeichen, _ . - (kein Leerzeichen am Anfang oder Ende)')}</span>}
          {valid && check === 'available' && <span className="welcome-ok"><Icon name="checkCircle" size={14} />{t('Der Name ist frei.')}</span>}
          {valid && check === 'taken' && <span className="welcome-error">{t('Dieser Name ist schon vergeben.')}</span>}
          {valid && check === 'unknown' && <span className="welcome-note">{t('Ob der Name frei ist, prüfen wir, wenn du online spielst.')}</span>}
          <button className="chunky intro-next" disabled={!nameOk}>{t('Weiter')}<Icon name="chevronRight" size={16} /></button>
        </form>
      </>}

      {page === 2 && <>
        <div className="intro-stage" key="w2">
          <div className="welcome-levels">
            {LEVELS.map((l, k) => (
              <button key={l.id} className="welcome-level" style={{ animationDelay: `${k * 90}ms` }} onClick={() => choose(l.id)}>
                <span className={`welcome-level-icon ${l.id}`}><Icon name={l.icon} size={24} /></span>
                <span className="welcome-level-text"><b>{t(l.title)}</b><small>{t(l.text)}</small></span>
                <Icon name="chevronRight" size={16} />
              </button>
            ))}
          </div>
        </div>
        <div className="intro-card" key="c2">
          <span className="intro-kicker">{t('Fast geschafft')}</span>
          <b className="intro-title">{t('Wie gut kennst du Schach?')}</b>
          <p className="intro-text">{t('Dann weiß Rocky, wie viel er dir erklären soll.')}</p>
        </div>
      </>}
    </div>
  )
}
