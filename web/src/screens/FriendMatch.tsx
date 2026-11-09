// FriendMatchViews.swift: "X challenges you" at the top, and waiting for the friend's answer (at most 2 minutes).
import { useEffect, useState } from 'react'
import { BOTS, botForTrophies } from '../game/catalog'
import { GameController } from '../game/controller'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import * as F from '../friends'
import * as FM from '../friendMatch'
import { useI18n } from '../i18n'
import { closeSheet, getNav, openOverlay, setTab } from '../nav'
import * as Online from '../online'
import { Icon } from '../ui/Icon'
import { PlayerAvatar } from '../ui/kit'

/** A friendly match is ready: against a person like an online match, against a bot player like the stand-in (local bot, no trophies). */
export function installFriendMatchStart() {
  FM.setReadyHandler(async matchId => {
    if (getNav().overlay?.kind === 'game') return
    try {
      const found = await Online.loadMatch(matchId)
      closeSheet()
      setTab('play')
      S.clearGame()
      if (found.bot) {
        const bot = BOTS.find(b => b.id === found.botId) ?? botForTrophies(found.opponent.trophies)
        openOverlay({ kind: 'game', game: new GameController({ mode: { kind: 'bot', bot: bot.id }, online: { ...found, opponent: { ...found.opponent, bot: true } } }) })
      } else {
        openOverlay({ kind: 'game', game: new GameController({ mode: { kind: 'online', matchId }, online: found }) })
      }
    } catch { /* offline: the invite simply lapses */ }
  })
}

const left = (from: number, now: number) => Math.max(0, Math.ceil((FM.LIFETIME_MS - (now - from)) / 1000))
const mmss = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
function useNow() {
  const [now, setNow] = useState(Date.now())
  useEffect(() => { const id = window.setInterval(() => setNow(Date.now()), 1000); return () => window.clearInterval(id) }, [])
  return now
}

export function FriendMatchInviteBanner() {
  const { t } = useI18n()
  const { incoming, outgoing } = FM.useFriendMatch()
  const inv = incoming[0]
  const now = useNow()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  useEffect(() => { if (inv) { sound('notify'); haptic('select') } }, [inv?.id])
  const secs = inv ? left(inv.createdAt, now) : 0
  useEffect(() => { if (inv && secs === 0) FM.decline(inv) }, [secs, inv?.id])
  if (!inv || outgoing) return null
  return (
    <div className="friend-banner fm-banner slide-down" role="alertdialog" aria-label={t('Freundschaftsspiel')}>
      <div className="row" style={{ gap: 10 }}>
        <PlayerAvatar avatar={inv.avatar} frame={inv.frame} size={40} />
        <span className="col grow" style={{ minWidth: 0 }}>
          <b>{t('Freundschaftsspiel')}</b>
          <span className="fm-line">{t('{0} fordert dich zu einem Freundschaftsspiel heraus.', inv.name)}</span>
        </span>
        <b className="num fm-time">{mmss(secs)}</b>
      </div>
      {error && <span className="fm-error">{t(error)}</span>}
      <div className="row" style={{ gap: 8 }}>
        <button className="chunky xs gold" disabled={busy} onClick={async () => {
          setBusy(true); setError(null)
          try { await FM.accept(inv) } catch (e) { setError(F.friendError(e)) } finally { setBusy(false) }
        }}>{t('Annehmen')}</button>
        <button className="chunky xs gray" style={{ maxWidth: 130 }} onClick={() => FM.decline(inv)}>{t('Ablehnen')}</button>
      </div>
      <span className="fm-note">{t('5 | 0 · ohne Trophäen')}</span>
    </div>
  )
}

export function FriendMatchWaiting() {
  const { t } = useI18n()
  const { outgoing: out } = FM.useFriendMatch()
  const now = useNow()
  if (!out) return null
  return (
    <div className="dialog fm-wait">
      <div className="fm-card pop-in" role="dialog" aria-label={t('Freundschaftsspiel')}>
        <PlayerAvatar avatar={out.avatar} frame={out.frame} size={88} />
        <b className="r" style={{ fontSize: 22 }}>{out.name}</b>
        <span className="friendly-tag"><Icon name="heart" size={11} /> {t('Freundschaftsspiel')}</span>
        {out.state === 'waiting' ? <>
          <span className="fm-spin" aria-hidden="true" />
          <span className="muted">{t('Warte auf {0} …', out.name)}</span>
          <b className="num fm-time">{mmss(left(out.startedAt, now))}</b>
          <button className="chunky gray sm" onClick={FM.cancelOutgoing}>{t('Abbrechen')}</button>
        </> : <>
          <span className="muted" style={{ textAlign: 'center' }}>{out.state === 'failed' ? (out.error ? t(out.error) : '') : out.state === 'declined' ? t('{0} kann gerade nicht spielen.', out.name) : t('{0} hat nicht geantwortet.', out.name)}</span>
          <button className="chunky gold sm" onClick={FM.cancelOutgoing}>{t('OK')}</button>
        </>}
      </div>
    </div>
  )
}
