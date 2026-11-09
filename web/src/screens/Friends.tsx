// FriendsViews.swift: the friends card on the profile, the friends list (invite, search, requests,
// friends ranking) and a friend's profile summary.
import { useEffect, useState } from 'react'
import { logoMark, rockyFace } from '../art'
import { arenaFor } from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import * as F from '../friends'
import * as FM from '../friendMatch'
import { useI18n } from '../i18n'
import { closeSheet, getNav, openChests, openSheet } from '../nav'
import * as Online from '../online'
import { enablePush, pushPermission } from '../push'
import { Icon } from '../ui/Icon'
import { ChestView, Dialog, PlayerAvatar, Sheet, useToast } from '../ui/kit'

type T = (key: string, ...args: Array<string | number>) => string

/** Invite: the system share sheet where there is one, otherwise copy the link. */
async function shareInvite(code: string, t: T, toast: (s: string) => void) {
  const url = F.inviteLink(code)
  const text = t('Spiel mit mir Rook Raid! Mein Freundescode: {0}', code)
  haptic('select')
  try {
    if (navigator.share) { await navigator.share({ title: 'Rook Raid', text, url }); return }
  } catch (e) { if ((e as Error).name === 'AbortError') return }
  try { await navigator.clipboard.writeText(`${text} ${url}`); toast(t('Link kopiert!')) } catch { toast(url) }
}

const fmtDate = (iso: string | null, lang: string) => (iso ? new Date(iso).toLocaleDateString(lang, { day: 'numeric', month: 'short', year: 'numeric' }) : '')

// MARK: Profile card

export function FriendsCard() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  const fr = F.useFriends()
  const [toast, showToast] = useToast()
  useEffect(() => { if (Online.hasAccount()) void F.refreshFriends() }, [acc.status])
  const friends = fr.players.filter(p => p.relation === 'friend')
  const requests = F.incomingCount(fr)
  if (acc.status === 'unavailable') return null
  return (
    <div className="card friends-card">
      <div className="row" style={{ gap: 8 }}>
        <span className="fc-ico"><Icon name="person2" size={18} /></span>
        <b className="r" style={{ fontSize: 19 }}>{t('Freunde')}</b>
        {friends.length > 0 && <span className="capsule chip num">{friends.length}</span>}
        <span className="spacer" />
        {requests > 0 && <button className="capsule fc-req" onClick={() => openSheet('friends')}>{requests === 1 ? t('1 Anfrage') : t('{0} Anfragen', requests)}</button>}
      </div>
      <button className="fc-faces press" onClick={() => openSheet('friends')} aria-label={t('Alle Freunde')}>
        {friends.length
          ? friends.slice(0, 6).map((f, i) => <span key={f.userId} className="fc-face" style={{ zIndex: 10 - i }}><PlayerAvatar avatar={f.avatar} frame={f.frame} size={46} /></span>)
          : [0, 1, 2].map(i => <span key={i} className="fc-face empty" style={{ animationDelay: `${i * 0.35}s` }}><Icon name="plus" size={18} /></span>)}
        <span className="fc-line">{friends.length
          ? (friends.length === 1 ? t('Du und {0}', friends[0].name) : t('Du, {0} und {1} weitere', friends[0].name, friends.length - 1))
          : t('Lade deine Freunde ein – zu zweit macht Rook Raid doppelt Spaß!')}</span>
      </button>
      <div className="row" style={{ gap: 8 }}>
        <button className="chunky gold sm" onClick={() => (fr.code ? shareInvite(fr.code, t, showToast) : openSheet('friends'))}><Icon name="share" size={16} />{t('Freund einladen')}</button>
        <button className="chunky gray sm" onClick={() => openSheet('friends')}>{t('Alle Freunde')}</button>
      </div>
      {toast}
    </div>
  )
}

// MARK: Friends sheet

function PlayerRow({ p, onOpen, children, rank, me }: { p: { name: string; avatar: string; frame: string | null; trophies: number; title?: string | null; isBot?: boolean; online?: boolean }; onOpen?: () => void; children?: React.ReactNode; rank?: number; me?: boolean }) {
  const { t } = useI18n()
  const Tag = onOpen ? 'button' : 'div'
  return (
    <div className={`li fr-row${me ? ' me' : ''}`}>
      {rank !== undefined && <b className={`fr-rank num${rank <= 3 ? ` r${rank}` : ''}`}>{rank}</b>}
      <Tag className="fr-who" onClick={onOpen}>
        <span className="ava-wrap"><PlayerAvatar avatar={p.avatar} frame={p.frame} size={38} />{p.online && <span className="online-dot" aria-label={t('Online')} />}</span>
        <span className="col" style={{ minWidth: 0 }}>
          <span className="row" style={{ gap: 6, minWidth: 0 }}>
            <b className="clip1">{p.name}{me ? ` · ${t('Du')}` : ''}</b>
            {p.isBot && <span className="training-tag">{t('Bot')}</span>}
          </span>
          <span className="muted row" style={{ gap: 4, fontSize: 12 }}><Icon name="trophy" size={10} color="var(--gold)" />{p.trophies}{p.title ? ` · ${t(p.title)}` : ''}</span>
        </span>
      </Tag>
      {children}
    </div>
  )
}

/** Challenge a friend right from the list (same as the button in the profile). Online friends get a highlighted button. */
function ChallengeButton({ f, onError }: { f: F.Player; onError: (msg: string) => void }) {
  const { t } = useI18n()
  const [busy, setBusy] = useState(false)
  return (
    <button className={`icon-btn fr-fight${f.online ? ' on' : ''}`} disabled={busy} aria-label={t('{0} herausfordern', f.name)} title={t('{0} herausfordern', f.name)}
      onClick={async e => {
        e.stopPropagation(); setBusy(true)
        try { await FM.invite(f) } catch (err) { onError(t(F.friendError(err))) } finally { setBusy(false) }
      }}>
      <Icon name="bolt" size={16} />
    </button>
  )
}

function RelationButton({ p, onDone }: { p: F.Player; onDone: (msg: string) => void }) {
  const { t } = useI18n()
  const [busy, setBusy] = useState(false)
  const act = async (fn: () => Promise<string | void>) => {
    setBusy(true)
    try {
      const r = await fn()
      onDone(r === 'accepted' ? t('Ihr seid jetzt Freunde!') : r === 'already_friends' ? t('Ihr seid schon Freunde.') : t('Anfrage gesendet!'))
      if (r === 'accepted') sound('reward_big')
    } catch (e) { onDone(t(F.friendError(e))) } finally { setBusy(false) }
  }
  switch (p.relation) {
    case 'none': return <button className="chunky xs fr-act" disabled={busy} onClick={() => act(() => F.sendRequest(p.userId))}><Icon name="plus" size={13} />{t('Hinzufügen')}</button>
    case 'incoming': return <button className="chunky xs gold fr-act" disabled={busy} onClick={() => act(async () => { await F.respond(p.userId, true); return 'accepted' })}>{t('Annehmen')}</button>
    case 'outgoing': return <span className="capsule chip">{t('Gesendet')}</span>
    case 'friend': return <span className="capsule chip gold"><Icon name="check" size={10} />{t('Befreundet')}</span>
    case 'self': return <span className="capsule chip">{t('Das bist du')}</span>
  }
}

export function FriendsSheet() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  const fr = F.useFriends()
  const p = S.useProfile()
  const [toast, showToast] = useToast()
  const [query, setQuery] = useState(() => (typeof getNav().sheetArg === 'string' ? String(getNav().sheetArg) : ''))
  const [results, setResults] = useState<F.Player[] | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [perm, setPerm] = useState(pushPermission())
  const [blocked, setBlocked] = useState<Awaited<ReturnType<typeof F.blockedPlayers>> | null>(null)
  const fm = FM.useFriendMatch()

  const search = async (q = query) => {
    if (q.trim().length < 2) return
    setBusy(true); setError(null)
    try {
      const found = await F.findPlayers(q)
      setResults(found)
      if (!found.length) setError(t('Niemand gefunden. Prüfe den Namen oder den Code.'))
    } catch (e) { setResults(null); setError(t(F.friendError(e))) } finally { setBusy(false) }
  }
  // Opened from an invite link: look the code up right away.
  useEffect(() => { void F.refreshFriends(); if (query && Online.hasAccount()) void search(query) }, [acc.status])
  const done = (msg: string) => { showToast(msg); if (query) void search() }

  if (!Online.hasAccount()) {
    return (
      <Sheet title={t('Freunde')} onClose={closeSheet}>
        <div className="fr-gate">
          <img src={rockyFace} alt="" className="rocky-face bob" />
          <b className="r" style={{ fontSize: 20 }}>{t('Freunde brauchen ein Online-Konto.')}</b>
          <span className="muted">{t('Mit Konto findest du Freunde über ihren Namen oder Code, siehst ihre Trophäen und bekommst ihre Anfragen.')}</span>
          {acc.status !== 'unavailable' && <button className="chunky gold sm" onClick={() => openSheet('onlineName', 'create')}>{t('Online-Konto erstellen')}</button>}
        </div>
      </Sheet>
    )
  }

  const friends = fr.players.filter(x => x.relation === 'friend')
  const incoming = fr.players.filter(x => x.relation === 'incoming')
  const outgoing = fr.players.filter(x => x.relation === 'outgoing')
  const myTrophies = acc.serverTrophies ?? p.trophies
  const ranking = [...friends.map(f => ({ ...f, me: false })), { userId: 'me', name: acc.name ?? p.name, avatar: S.activeAvatar(p), frame: S.activeFrame(p), trophies: myTrophies, title: S.activeTitle(p), me: true }]
    .sort((a, b) => b.trophies - a.trophies)
  const open = (id: string) => openSheet('friendProfile', id)

  return (
    <Sheet title={t('Freunde')} onClose={closeSheet} tall>
      {fm.incoming.length > 0 && <>
        <div className="list-h" style={{ marginTop: 0 }}>{t('Herausforderungen')}</div>
        <div className="list" style={{ marginBottom: 12 }}>
          {fm.incoming.map(inv => (
            <PlayerRow key={inv.id} p={{ name: inv.name, avatar: inv.avatar, frame: inv.frame, trophies: 0, title: null }}>
              <button className="chunky xs gold fr-act" onClick={async () => { try { await FM.accept(inv) } catch (e) { showToast(t(F.friendError(e))) } }}>{t('Annehmen')}</button>
              <button className="icon-btn" aria-label={t('Ablehnen')} onClick={() => FM.decline(inv)}><Icon name="xmark" size={16} /></button>
            </PlayerRow>
          ))}
        </div>
      </>}
      <div className="fr-invite">
        <span className="kicker" style={{ color: 'var(--gold-top)' }}>{t('Dein Freundescode').toUpperCase()}</span>
        <b className="fr-code mono">{fr.code ?? '······'}</b>
        <span className="fr-invite-t">{t('Schick den Link per Messenger. Wer ihn öffnet, landet direkt bei dir.')}</span>
        <div className="row" style={{ gap: 8, width: '100%' }}>
          <button className="chunky gold sm" disabled={!fr.code} onClick={() => fr.code && shareInvite(fr.code, t, showToast)}><Icon name="share" size={16} />{t('Link teilen')}</button>
          <button className="chunky gray sm" disabled={!fr.code} onClick={async () => { try { await navigator.clipboard.writeText(fr.code!); showToast(t('Kopiert!')) } catch { showToast(fr.code!) } }}>{t('Code kopieren')}</button>
        </div>
      </div>

      <div className="list-h">{t('Spieler suchen')}</div>
      <form className="row fr-search" style={{ gap: 8 }} onSubmit={e => { e.preventDefault(); void search() }}>
        <input className="field" value={query} maxLength={24} onChange={e => { setQuery(e.target.value); setResults(null); setError(null) }}
          placeholder={t('Name oder Freundescode')} autoCapitalize="off" autoCorrect="off" spellCheck={false} />
        <button className="chunky xs" style={{ width: 'auto', minWidth: 90 }} disabled={busy || query.trim().length < 2}>{t('Suchen')}</button>
      </form>
      {error && <p className="list-f">{error}</p>}
      {results && results.length > 0 && (
        <div className="list" style={{ marginTop: 8 }}>
          {results.map(r => (
            <PlayerRow key={r.userId} p={r} onOpen={r.relation === 'friend' || r.relation === 'incoming' || r.relation === 'outgoing' ? () => open(r.userId) : undefined}>
              <RelationButton p={r} onDone={done} />
            </PlayerRow>
          ))}
        </div>
      )}

      {perm === 'default' && (
        <button className="li fr-push" onClick={async () => { await enablePush(); setPerm(pushPermission()) }}>
          <span className="ico" style={{ background: '#E0413A' }}><Icon name="bolt" size={16} /></span>
          <span className="t">{t('Benachrichtigen, wenn dich jemand hinzufügt')}</span>
          <span className="capsule chip gold">{t('Aktivieren')}</span>
        </button>
      )}
      {perm === 'denied' && <p className="list-f">{t('Benachrichtigungen sind aus. Du kannst sie in den Einstellungen erlauben.')}</p>}

      {incoming.length > 0 && <>
        <div className="list-h">{t('Anfragen')} <span className="badge static">{incoming.length}</span></div>
        <div className="list">
          {incoming.map(r => (
            <PlayerRow key={r.userId} p={r} onOpen={() => open(r.userId)}>
              <button className="chunky xs gold fr-act" onClick={async () => { try { await F.respond(r.userId, true); sound('reward_big'); showToast(t('Ihr seid jetzt Freunde!')) } catch (e) { showToast(t(F.friendError(e))) } }}>{t('Annehmen')}</button>
              <button className="icon-btn" aria-label={t('Ablehnen')} onClick={async () => { try { await F.respond(r.userId, false) } catch (e) { showToast(t(F.friendError(e))) } }}><Icon name="xmark" size={16} /></button>
            </PlayerRow>
          ))}
        </div>
      </>}

      <div className="list-h">{t('Freundes-Rangliste')}</div>
      {friends.length === 0
        ? <div className="fr-empty"><Icon name="person2" size={30} color="var(--blue-light)" /><span>{t('Noch keine Freunde. Teile deinen Link oder suche nach einem Namen.')}</span>
            {!p.firstFriendChestGiven && <span className="fr-reward-hint"><ChestView rarity={2} size={30} />{t('Für deinen ersten Freund gibt es eine Goldtruhe!')}</span>}</div>
        : <div className="list">{ranking.map((r, i) => (
            <PlayerRow key={r.userId} p={r} rank={i + 1} me={r.me} onOpen={r.me ? undefined : () => open(r.userId)}>
              {!r.me && <ChallengeButton f={r as F.Player} onError={showToast} />}
            </PlayerRow>
          ))}</div>}

      {outgoing.length > 0 && <>
        <div className="list-h">{t('Gesendete Anfragen')}</div>
        <div className="list">
          {outgoing.map(r => (
            <PlayerRow key={r.userId} p={r} onOpen={() => open(r.userId)}>
              <button className="ghost" onClick={async () => { try { await F.cancelRequest(r.userId) } catch (e) { showToast(t(F.friendError(e))) } }}>{t('Zurückziehen')}</button>
            </PlayerRow>
          ))}
        </div>
      </>}

      {fr.showOnline !== null && (
        <label className="fr-toggle">
          <span className="col grow" style={{ minWidth: 0 }}>
            <b style={{ fontSize: 15 }}>{t('Online-Status zeigen')}</b>
            <span className="muted" style={{ fontSize: 12 }}>{t('Freunde sehen, wenn du gerade in Rook Raid bist, und können dich herausfordern.')}</span>
          </span>
          <input type="checkbox" role="switch" checked={fr.showOnline} onChange={async e => { try { await F.setShowOnline(e.target.checked) } catch (err) { showToast(t(F.friendError(err))) } }} />
        </label>
      )}

      <button className="ghost fr-blocked" onClick={async () => { try { setBlocked(await F.blockedPlayers()) } catch (e) { showToast(t(F.friendError(e))) } }}>{t('Blockierte Spieler')}</button>
      {blocked && (
        <Dialog title={t('Blockierte Spieler')} onClose={() => setBlocked(null)}
          message={blocked.length ? blocked.map(b => b.name).join('\n') : t('Niemand blockiert.')}
          actions={[...blocked.map(b => ({ label: t('{0} freigeben', b.name), onClick: () => { void F.unblock(b.userId) } })), { label: t('Fertig'), bold: true }]} />
      )}
      {toast}
    </Sheet>
  )
}

// MARK: Profile summary

export function FriendProfileSheet() {
  const { t, lang } = useI18n()
  const id = String(getNav().sheetArg ?? '')
  const [fp, setFp] = useState<F.FriendProfile | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [confirm, setConfirm] = useState<'remove' | 'block' | 'report' | null>(null)
  const [toast, showToast] = useToast()
  const [challenging, setChallenging] = useState(false)
  const load = () => F.profile(id).then(setFp).catch(e => setError(t(F.friendError(e))))
  useEffect(() => { void load() }, [id])
  const back = () => openSheet('friends')
  const act = async (fn: () => Promise<unknown>, after: () => void) => {
    try { await fn(); after() } catch (e) { showToast(t(F.friendError(e))) }
  }
  const arena = fp ? arenaFor(fp.trophies) : null
  const games = fp ? fp.wins + fp.losses + fp.draws : 0
  return (
    <Sheet title={fp?.name ?? t('Freunde')} onClose={closeSheet} left={<button className="ghost" onClick={back}><Icon name="chevronLeft" size={14} />{t('Freunde')}</button>}>
      {error && <p className="list-f">{error}</p>}
      {!fp && !error && <div className="fr-empty"><span className="muted">…</span></div>}
      {fp && arena && <>
        <div className="fp-hero">
          <span className="ava-wrap"><PlayerAvatar avatar={fp.avatar} frame={fp.frame} size={96} />{fp.online && <span className="online-dot lg" aria-label={t('Online')} />}</span>
          <span className="row" style={{ gap: 8 }}>
            <b className="r" style={{ fontSize: 24 }}>{fp.name}</b>
            {fp.isBot && <span className="training-tag lg" style={{ marginTop: 0 }}>{t('Bot')}</span>}
          </span>
          {fp.title && <span className="kicker" style={{ color: 'var(--blue-light)' }}>{t(fp.title).toUpperCase()}</span>}
          <span className="row" style={{ gap: 6, flexWrap: 'wrap', justifyContent: 'center' }}>
            <span className="capsule chip">{t('Level {0}', fp.level)}</span>
            <span className="capsule chip">{t('Arena {0}', arena.n)}</span>
            {fp.relation === 'friend' && fp.since && <span className="capsule chip gold"><Icon name="heart" size={10} />{t('Freunde seit {0}', fmtDate(fp.since, lang))}</span>}
          </span>
          {fp.relation === 'friend' && <span className={`fp-online${fp.online ? ' on' : ''}`}>{fp.online ? t('Online') : t('Offline')}</span>}
          {fp.isBot && <span className="fp-note">{t('Das ist ein Bot-Spieler, kein Mensch.')}</span>}
        </div>
        {fp.relation === 'friend' && <>
          <button className="chunky gold fp-challenge" disabled={challenging} onClick={async () => {
            setChallenging(true)
            try { await FM.invite(fp) } catch (e) { showToast(t(F.friendError(e))) } finally { setChallenging(false) }
          }}><Icon name="bolt" size={16} />{t('Freundschaftsspiel')}</button>
          <span className="fp-note">{t('5 | 0 · ohne Trophäen · zählt für eure Bilanz')}</span>
        </>}
        <div className="fp-grid">
          <div><Icon name="trophy" size={18} color="var(--gold)" /><b className="num">{fp.trophies}</b><span>{t('Rekord {0}', fp.bestTrophies)}</span></div>
          <div><Icon name="crown" size={18} color="var(--gold-top)" /><b className="num">#{fp.rank}</b><span>{t('Weltweit')}</span></div>
          <div><Icon name="bolt" size={18} color="var(--blue-light)" /><b className="num">{games ? Math.round(fp.wins / games * 100) : 0} %</b><span>{t('{0} S · {1} N · {2} R', fp.wins, fp.losses, fp.draws)}</span></div>
          <div><Icon name="person2" size={18} color="#6FBF73" /><b className="num">{fp.friends}</b><span>{fp.friends === 1 ? t('1 Freund') : t('{0} Freunde', fp.friends)}</span></div>
        </div>
        {fp.relation === 'friend' && (
          <div className="card fp-vs">
            <span className="section-h">{t('Ihr gegeneinander')}</span>
            <b className="num">{fp.vsWins} : {fp.vsLosses}</b>
            <span className="muted">{fp.vsDraws ? t('{0} Remis', fp.vsDraws) : fp.vsWins + fp.vsLosses ? '' : t('Noch keine Partie gegeneinander.')}</span>
          </div>
        )}
        {fp.relation === 'friend' && <FriendHistory userId={fp.userId} />}
        {fp.relation === 'incoming' && (
          <div className="row" style={{ gap: 8 }}>
            <button className="chunky gold sm" onClick={() => act(() => F.respond(fp.userId, true), () => { sound('reward_big'); void load() })}>{t('Annehmen')}</button>
            <button className="chunky gray sm" onClick={() => act(() => F.respond(fp.userId, false), back)}>{t('Ablehnen')}</button>
          </div>
        )}
        {fp.relation === 'outgoing' && <button className="chunky gray sm" onClick={() => act(() => F.cancelRequest(fp.userId), back)}>{t('Anfrage zurückziehen')}</button>}
        <div className="list" style={{ marginTop: 14 }}>
          {fp.relation === 'friend' && <button className="li" onClick={() => setConfirm('remove')}><span className="ico" style={{ background: '#7E8AA3' }}><Icon name="minus" size={16} /></span><span className="t">{t('Freund entfernen')}</span></button>}
          <button className="li" onClick={() => setConfirm('report')}><span className="ico" style={{ background: '#E39B3A' }}><Icon name="flag" size={16} /></span><span className="t">{t('Melden')}</span></button>
          <button className="li" onClick={() => setConfirm('block')}><span className="ico" style={{ background: '#E0413A' }}><Icon name="xShield" size={16} /></span><span className="t" style={{ color: 'var(--red-light)' }}>{t('Blockieren')}</span></button>
        </div>
        {confirm === 'remove' && <Dialog title={t('{0} als Freund entfernen?', fp.name)} onClose={() => setConfirm(null)}
          actions={[{ label: t('Entfernen'), destructive: true, onClick: () => act(() => F.removeFriend(fp.userId), back) }, { label: t('Abbrechen'), bold: true }]} />}
        {confirm === 'block' && <Dialog title={t('{0} blockieren?', fp.name)} message={t('Ihr seid dann keine Freunde mehr, und {0} kann dich nicht mehr finden oder anfragen.', fp.name)} onClose={() => setConfirm(null)}
          actions={[{ label: t('Blockieren'), destructive: true, onClick: () => act(() => F.block(fp.userId), back) }, { label: t('Abbrechen'), bold: true }]} />}
        {confirm === 'report' && <Dialog title={t('Warum meldest du {0}?', fp.name)} onClose={() => setConfirm(null)}
          actions={[
            ...(([['name', 'Anstößiger Name'], ['cheating', 'Schummeln'], ['abuse', 'Beleidigung'], ['other', 'Etwas anderes']] as const)
              .map(([reason, label]) => ({ label: t(label), onClick: () => act(() => F.report(fp.userId, reason), () => showToast(t('Danke! Wir sehen uns das an.'))) }))),
            { label: t('Abbrechen'), bold: true },
          ]} />}
      </>}
      {toast}
    </Sheet>
  )
}

// MARK: Games against a friend

function FriendHistory({ userId }: { userId: string }) {
  const { t, lang } = useI18n()
  const [games, setGames] = useState<F.FriendMatch[] | null>(null)
  const [all, setAll] = useState(false)
  useEffect(() => { F.friendMatches(userId).then(setGames).catch(() => setGames([])) }, [userId])
  if (!games || games.length === 0) return null
  const shown = all ? games : games.slice(0, 5)
  const label = { win: 'Sieg', loss: 'Niederlage', draw: 'Remis' } as const
  return (
    <div className="fp-history">
      <span className="section-h">{t('Letzte Partien')}</span>
      <div className="list">
        {shown.map(g => (
          <div key={g.matchId} className="li fh-row">
            <span className={`fh-res ${g.result}`}>{t(label[g.result])}</span>
            <span className="col grow" style={{ minWidth: 0 }}>
              <span className="clip1" style={{ fontSize: 14 }}>{g.reason ? t(Online.SERVER_REASON[g.reason] ?? g.reason) : ''}</span>
              <span className="muted" style={{ fontSize: 12 }}>{fmtDate(g.endedAt, lang)}</span>
            </span>
            {g.rated
              ? <span className={`capsule chip num${(g.trophyDelta ?? 0) >= 0 ? ' gold' : ''}`}><Icon name="trophy" size={10} />{(g.trophyDelta ?? 0) > 0 ? '+' : ''}{g.trophyDelta ?? 0}</span>
              : <span className="friendly-tag"><Icon name="heart" size={11} /> {t('Freundschaftsspiel')}</span>}
          </div>
        ))}
      </div>
      {games.length > 5 && !all && <button className="ghost" onClick={() => setAll(true)}>{t('Alle {0} Partien zeigen', games.length)}</button>}
    </div>
  )
}

// MARK: In-app notice

/** Opened from a friend link in an iPhone browser. Messengers (Telegram, Messenger, Instagram …) open links in their own
 *  browser, where iOS never hands them to the app – one tap here opens the invite in Rook Raid (rookraid://f/CODE). */
export function OpenInAppBar() {
  const { t } = useI18n()
  const [code, setCode] = useState<string | null>(() => (F.isIOSBrowser() ? F.launchCode() : null))
  if (!code) return null
  return (
    <div className="friend-banner open-app-bar slide-down" role="status">
      <img className="oab-logo" src={logoMark} alt="" />
      <span className="col grow" style={{ minWidth: 0 }}>
        <b>{t('Rook Raid installiert?')}</b>
        <span>{t('Öffne die Einladung direkt in der App.')}</span>
      </span>
      <a className="chunky xs gold" style={{ width: 'auto' }} href={F.appLink(code)} onClick={() => window.setTimeout(() => setCode(null), 800)}>{t('Öffnen')}</a>
      <button className="oab-x" aria-label={t('Schließen')} onClick={() => setCode(null)}><Icon name="xmark" size={16} /></button>
    </div>
  )
}

/** A new request (or an accepted one) while the browser is open – the in-app twin of the push notification. */
export function FriendBanner() {
  const { t } = useI18n()
  const fr = F.useFriends()
  const news = fr.news
  useEffect(() => {
    if (!news) return
    sound('notify'); haptic('select')
    const id = window.setTimeout(F.clearNews, 6000)
    return () => window.clearTimeout(id)
  }, [news])
  if (!news) return null
  if (news.kind === 'reward') {
    const chest = S.pendingChests().find(c => c.id === news.chestId)
    return (
      <div className="friend-banner slide-down" role="status">
        <ChestView rarity={2} size={34} />
        <span className="col grow" style={{ minWidth: 0 }}>
          <b>{t('Freundestruhe!')}</b>
          <span className="clip1">{t('Für deinen ersten Freund gibt es eine Goldtruhe.')}</span>
        </span>
        {chest && <button className="chunky xs gold" style={{ width: 'auto' }} onClick={() => { F.clearNews(); closeSheet(); openChests(chest, new Set([chest.id])) }}>{t('Öffnen')}</button>}
      </div>
    )
  }
  return (
    <div className="friend-banner slide-down" role="status">
      <span className="fb-ico"><Icon name={news.kind === 'request' ? 'person2' : 'heart'} size={18} /></span>
      <span className="col grow" style={{ minWidth: 0 }}>
        <b>{news.kind === 'request' ? t('Neue Freundschaftsanfrage') : t('Neuer Freund!')}</b>
        <span className="clip1">{news.kind === 'request' ? t('{0} möchte mit dir befreundet sein.', news.name) : t('{0} hat deine Freundschaftsanfrage angenommen.', news.name)}</span>
      </span>
      <button className="chunky xs gold" style={{ width: 'auto' }} onClick={() => { F.clearNews(); openSheet('friends') }}>{t('Ansehen')}</button>
    </div>
  )
}
