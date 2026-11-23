// ProfileViews.swift (redesign V2), ProfileExtras.swift: profile tab, achievements and the wardrobe.
import { useEffect, useState } from 'react'
import { avatarImage, pieceImage } from '../art'
import {
  AVATARS, BOARD_COLORS, BOARD_NAMES, BOARD_PRICE, BOARD_THEMES, BOTS, CARDS, COSMETIC_RARITY, FRAMES, FRAME_IDS,
  avatarPrice, botRecordName, isCollectibleBoard, type AvatarId, type BoardTheme, type FrameId,
} from '../game/catalog'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeSheet, openOverlay, openSheet, run, setTab } from '../nav'
import { Icon } from '../ui/Icon'
import { Dialog, PlayerAvatar, Progress, Sheet, ShardIcon, useToast } from '../ui/kit'
import { GoogleG, securedText } from './Login'
import { CHEST_TITLES, SHOP_FRAMES, SHOP_FRAME_PRICE, rankFor } from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import { BotPortrait } from './Game'
import * as Online from '../online'
import * as F from '../friends'
import { shareInvite } from './Friends'
import { DSProgress, IconTile, ListGroup, ListRow, PrimaryButton, PrimaryDock, ScreenHeader, SectionLabel } from '../ui/ds'

export function ProfileScreen() {
  const p = S.useProfile()
  const { t } = useI18n()
  const lp = S.levelProgress(p)
  const all = S.achievements(p)
  const done = all.filter(S.isUnlockedAchievement)
  const claimable = S.claimableAchievements(p)
  const games = p.wins + p.losses + p.draws
  const rate = games ? Math.round((p.wins / games) * 100) : 0
  const acc = Online.useAccount()
  const fr = F.useFriends()
  const [toast, showToast] = useToast()
  const friends = fr.players.filter(x => x.relation === 'friend')
  const requests = fr.players.filter(x => x.relation === 'incoming').length
  const friendsOn = Online.isConfigured()
  useEffect(() => { if (Online.hasAccount()) void F.refreshFriends() }, [acc.status])
  const stat = (title: string, icon: string, color: string, hint: string | null, value: number | string, onClick: () => void) => (
    <button className="pf-stat" onClick={onClick} aria-label={[title, String(value), hint].filter(Boolean).join(', ')}>
      <span className="ds-ico"><Icon name={icon} size={19} color={color} /></span>
      <span className="pf-stat-t">{title}</span>
      {hint && <span className="pf-stat-h">{hint}</span>}
      <b className="pf-stat-v num">{value}</b>
    </button>
  )
  return (
    <div className="page ds-page">
      <div className="ds-inner">
        <ScreenHeader title={t('Profil')} gear />
        <div className="pf-hero">
          <button className="pf-avatar press" onClick={() => openSheet('style')} aria-label={t('Avatar {0}. Tippen zum Ändern', t(AVATARS.find(a => a.id === S.activeAvatar(p))?.name ?? ''))}>
            <img src={avatarImage(S.activeAvatar(p))} alt="" />
          </button>
          <div className="grow col" style={{ gap: 4, minWidth: 0 }}>
            <b className="pf-name clip1">{S.shownName(p.name, t)}</b>
            <span className="pf-rank clip1">{t('{0} · Level {1}', t(S.activeTitle(p)), lp.level)}</span>
            <DSProgress value={lp.fraction} color="var(--ds-purple)" />
            <span className="num clip1" style={{ fontSize: 13, color: 'var(--ds-muted)', fontWeight: 600 }}>{t('noch {0} XP bis Level {1}', lp.remaining, lp.level + 1)}</span>
            {acc.status === 'secured' && <span className="row" style={{ gap: 5, fontSize: 12, color: 'var(--ds-muted)' }}>{acc.provider === 'google' ? <GoogleG size={11} /> : <Icon name="apple" size={11} />}{securedText(acc.provider, t)}</span>}
          </div>
        </div>
        {/* Order: friends · extras · stats */}
        {friendsOn && <>
          <SectionLabel text={friends.length ? t('Freunde · {0}', friends.length) : t('Freunde')} action={{ label: t('Alle'), onClick: () => openSheet('friends') }} />
          <button className="pf-friends" onClick={() => openSheet('friends')}>
            {friends.length === 0 ? <IconTile icon="person2" color="var(--ds-gem)" /> : (
              <span className="pf-faces">
                {friends.slice(0, 2).map(f => <span key={f.userId}><img src={avatarImage(f.avatar)} alt="" /></span>)}
                {friends.length > 2 && <span>+{friends.length - 2}</span>}
              </span>
            )}
            <span className="grow" style={{ fontSize: 15, fontWeight: 600 }}>
              {friends.length === 0 ? t('Lade deine Freunde ein – zu zweit macht Rook Raid doppelt Spaß!')
                : friends.length === 1 ? friends[0].name : t('{0} und {1} weitere', friends[0].name, friends.length - 1)}
            </span>
            {requests > 0 && <span className="pf-claim">{requests === 1 ? t('1 Anfrage') : t('{0} Anfragen', requests)}</span>}
          </button>
          <div style={{ height: 20 }} />
        </>}
        <SectionLabel text={t('Extras')} />
        <ListGroup>
          <ListRow icon={<IconTile icon="chart" color="var(--ds-gem)" />} title={t('Statistik & Verlauf')}
            sub={games === 0 ? t('Noch keine Partien') : t('Letzte Partien und Wiederholungen')} onClick={() => openSheet('stats')} />
          <ListRow icon={<IconTile icon="palette" color="var(--ds-purple)" />} title={t('Stil & Sammlung')} sub={t('Avatare, Rahmen, Bretter und Figuren')} onClick={() => openSheet('style')} />
          <ListRow icon={<IconTile icon="graduation" />} title={t('Erste Schlacht erneut spielen')} onClick={() => run('startTutorial')} />
          <ListRow icon={<IconTile icon="envelope" color="var(--ds-flame)" />} title={t('Feedback senden')} sub={t('Bugs, Balance, Ideen – Rook Raid ist in der Beta.')} onClick={() => openSheet('feedback')} />
        </ListGroup>
        <div style={{ height: 20 }} />
        <SectionLabel text={t('Statistik')} />
        <ListGroup>
          {stat(t('Trophäen'), 'trophy', 'var(--ds-gold)', t('Bestwert {0}', p.bestTrophies), p.trophies, () => openSheet('road'))}
          {stat(t('Arena'), 'columns', 'var(--ds-text)', t(S.arena(p).name), S.arena(p).n, () => openSheet('road'))}
          {stat(t('Siege'), 'crown', 'var(--ds-gold)', t('{0} % Siegquote', rate), p.wins, () => openSheet('stats'))}
          {stat(t('Gelöste Puzzles'), 'puzzle', 'var(--ds-purple)', p.rushBest > 0 ? t('Rausch-Bestwert {0}', p.rushBest) : null, p.solvedPuzzles.length, () => setTab('puzzles'))}
          {stat(t('Flamme'), 'flame', 'var(--ds-flame)', t('Rekord {0}', p.bestStreak), S.currentStreak(p), () => openSheet('flame'))}
          <button className="pf-stat" onClick={() => openSheet('achievements')}
            aria-label={t('Erfolge, {0} von {1}', done.length, all.length) + (claimable.length ? ', ' + t('{0} abholen', claimable.length) : '')}>
            <span className="ds-ico"><Icon name="medal" size={19} /></span>
            <span className="pf-stat-t">{t('Erfolge')}</span>
            {claimable.length > 0 && <span className="pf-claim">{claimable.length === 1 ? t('1 abholen') : t('{0} abholen', claimable.length)}</span>}
            <b className="pf-stat-v num">{done.length}<small style={{ fontSize: 14, color: 'var(--ds-muted)' }}>/{all.length}</small></b>
            <Icon name="chevronRight" size={14} color="var(--ds-chevron)" />
          </button>
        </ListGroup>
      </div>
      {friendsOn && (
        <PrimaryDock>
          <PrimaryButton title={t('Freund einladen')} icon="personPlus"
            onClick={() => { if (fr.code) void shareInvite(fr.code, t, showToast); else openSheet('friends') }} />
        </PrimaryDock>
      )}
      {toast}
    </div>
  )
}

function Ring({ value, max, label, color }: { value: number; max: number; label: string; color: string }) {
  const c = 2 * Math.PI * 22
  return (
    <span className="ring-stat">
      <svg width="56" height="56" viewBox="0 0 56 56"><circle cx="28" cy="28" r="22" fill="none" stroke="var(--hi)" strokeWidth="5" />
        <circle cx="28" cy="28" r="22" fill="none" stroke={color} strokeWidth="5" strokeLinecap="round" strokeDasharray={`${(Math.min(value, max) / max) * c} ${c}`} transform="rotate(-90 28 28)" /></svg>
      <b className="num">{value}/{max}</b>
      <span>{label}</span>
    </span>
  )
}

/** Statistics like StatisticsView in the app: record, trophy curve, play style, bots, puzzles and every game. */
export function StatisticsSheet() {
  const { t } = useI18n()
  const p = S.useProfile()
  const games = p.wins + p.losses + p.draws
  const rate = games ? Math.round((p.wins / games) * 100) : 0
  const rated = p.history.filter(h => h.opponent !== 'Zu zweit')
  const recent = rated.slice(0, 10).reverse()
  const avgMoves = p.history.length ? p.history.reduce((s, h) => s + h.moves, 0) / p.history.length : 0
  const wins = rated.filter(h => h.result === 'win' && h.moves > 0).map(h => h.moves)
  const historyCards = p.history.reduce((s, h) => s + h.cardsPlayed, 0)
  const totalCards = Math.max(Object.values(p.cardsByType).reduce((a, b) => a + b, 0), historyCards)
  const fav = Object.entries(p.cardsByType).filter(([c]) => c in CARDS).sort((a, b) => b[1] - a[1])[0]
  const rr = S.PUZZLES.filter(S.isRookRaidPuzzle), classic = S.PUZZLES.filter(x => !S.isRookRaidPuzzle(x))
  const solved = new Set(p.solvedPuzzles)
  const trend = rated.filter(h => h.trophyDelta !== 0).slice(0, 40).reverse()
  return (
    <Sheet title={t('Statistik')} onClose={closeSheet} wide tall>
      <div className="stats-sheet">
        <div className="card col">
          <span className="section-h">{t('Bilanz')}</span>
          <div className="balance">
            <div><b style={{ color: '#6FBF73' }}>{p.wins}</b><span>{t('Siege')}</span></div>
            <div><b style={{ color: 'var(--text2)' }}>{p.draws}</b><span>{t('Remis')}</span></div>
            <div><b style={{ color: 'var(--red-light)' }}>{p.losses}</b><span>{t('Niederlagen')}</span></div>
            <div><b style={{ color: 'var(--gold)' }}>{games ? `${rate}%` : '–'}</b><span>{t('Siegquote')}</span></div>
          </div>
          <div className="balance-bar"><i style={{ flex: p.wins || 0.001, background: '#6FBF73' }} /><i style={{ flex: p.draws || 0.001, background: '#7E8AA3' }} /><i style={{ flex: p.losses || 0.001, background: '#E0413A' }} /></div>
          <div className="row" style={{ gap: 6 }}>
            <span className="muted" style={{ fontSize: 12 }}>{t('Form (letzte 10)')}</span>
            <span className="form-dots">{recent.length ? recent.map(h => <i key={h.id} className={h.result} />) : <span className="muted" style={{ fontSize: 12 }}>{t('noch keine')}</span>}</span>
            <span className="spacer" />
            <span className="muted" style={{ fontSize: 12 }}>{t('{0} Partien insgesamt', games)}</span>
          </div>
          <span className="muted" style={{ fontSize: 12 }}>{t('Siegesserie {0} · Rekord {1}', p.winStreak, p.bestWinStreak)}</span>
        </div>

        <div className="card col">
          <span className="section-h">{t('Trophäen-Verlauf')}</span>
          {trend.length >= 2 ? <TrophyTrend history={trend} now={p.trophies} /> : <span className="muted" style={{ fontSize: 12 }}>{t('Spiele gegen einen Bot – hier wächst dann deine Trophäenkurve.')}</span>}
        </div>

        <div className="card col">
          <span className="section-h">{t('Spielstil')}</span>
          <div className="tile-grid">
            <Tile icon="flame" color="#FF7A2F" value={String(p.winStreak)} label={t('Siegesserie')} detail={t('Rekord {0}', p.bestWinStreak)} />
            <Tile icon="timer" color="var(--blue-light)" value={wins.length ? String(Math.min(...wins)) : '–'} label={t('Schnellster Sieg')} detail={t('Aktionen')} />
            <Tile icon="swap" color="var(--text2)" value={avgMoves > 0 ? String(Math.round(avgMoves)) : '–'} label={t('Ø Aktionen')} detail={t('pro Partie')} />
            <Tile icon="crown" color="var(--gold)" value={String(p.mateWins)} label={t('Siege durch Matt')} detail={t('gegen Bots')} />
            <Tile icon="stack" color="#8FB6FF" value={String(totalCards)} label={t('Karten gespielt')} detail={t('Ø %.1f pro Partie').replace('%.1f', (p.history.length ? historyCards / p.history.length : 0).toFixed(1))} />
            <Tile icon="heart" color="var(--red-light)" value={fav ? t(CARDS[fav[0] as keyof typeof CARDS].name) : '–'} label={t('Lieblingskarte')} detail={fav ? t('{0}× gespielt', fav[1]) : t('noch keine')} />
            <Tile icon="sparkles" color="var(--gold)" value={String(p.ultimatesUsed)} label={t('Ultimates gezündet')} detail={t('insgesamt')} />
            <Tile icon="calendar" color="#FF7A2F" value={String(p.activeDays.length)} label={t('Aktive Tage')} detail={t('mit Flamme')} />
          </div>
        </div>

        <div className="card col">
          <span className="section-h">{t('Gegen die Bots')}</span>
          {BOTS.map(b => {
            const rs = rated.filter(h => h.opponent === botRecordName(b))
            const w = rs.filter(h => h.result === 'win').length, l = rs.filter(h => h.result === 'loss').length, d = rs.length - w - l
            return (
              <div key={b.id} className="row" style={{ gap: 10 }}>
                <BotPortrait id={b.id} size={34} />
                <div className="col grow" style={{ gap: 4, minWidth: 0 }}>
                  <div className="row"><b className="grow clip1" style={{ fontSize: 13 }}>{t(b.name)}</b><span className="muted num" style={{ fontSize: 11 }}>{rs.length ? `${w} S · ${l} N · ${d} R` : t('noch nicht gespielt')}</span></div>
                  <div className="balance-bar thin">{rs.length ? <><i style={{ flex: w || 0.001, background: 'var(--blue)' }} /><i style={{ flex: d || 0.001, background: '#7E8AA3' }} /><i style={{ flex: l || 0.001, background: '#E0413A' }} /></> : <i style={{ flex: 1, background: 'var(--hi)' }} />}</div>
                </div>
              </div>
            )
          })}
        </div>

        <div className="card col">
          <span className="section-h">{t('Puzzles')}</span>
          {([['Rook Raid', rr, 'var(--gold)'], ['Klassisch', classic, '#8FB6FF']] as const).map(([name, list, color]) => {
            const n = list.filter(x => solved.has(x.id)).length
            return (
              <div key={name} className="col" style={{ gap: 4 }}>
                <div className="row"><b className="grow" style={{ fontSize: 13 }}>{t(name)}</b><span className="num" style={{ fontSize: 12, fontWeight: 900, color }}>{n}/{list.length}</span></div>
                <div className="balance-bar"><i style={{ flex: n || 0.02, background: color }} /><i style={{ flex: Math.max(0, list.length - n), background: 'var(--hi)' }} /></div>
              </div>
            )
          })}
        </div>

        <div className="card col">
          <div className="row"><span className="section-h">{t('Letzte Partien')}</span><span className="spacer" /><span className="dim num" style={{ fontSize: 12 }}>{p.history.length}</span></div>
          {p.history.length === 0 ? <p className="empty-hint">{t('Noch keine Partien gespielt.')}</p> : (
            <div className="list">
              {p.history.map(h => {
                const has = !!S.replayFor(h.replayID)
                const opponent = h.opponent === 'Zu zweit' ? t('Zu zweit') : h.opponent.startsWith('Bot ') ? t(h.opponent.slice(4)) : h.opponent
                return (
                  <button key={h.id} className="li" disabled={!has} onClick={() => { closeSheet(); openOverlay({ kind: 'replay', id: h.replayID! }) }}>
                    <span className={`res-tag ${h.result}`}>{t(h.result === 'win' ? 'Sieg' : h.result === 'loss' ? 'Niederlage' : 'Remis').toUpperCase()}</span>
                    <span className="t">
                      {t('vs. {0}', opponent)}<br />
                      <span className="muted" style={{ fontSize: 12, fontWeight: 500 }}>{t('{0} · {1} Züge · {2} Karten', t(S.reasonKey(h.reason)), h.moves, h.cardsPlayed)} · {new Date(h.date).toLocaleDateString()}</span>
                    </span>
                    {h.trophyDelta !== 0 && <span className={`num delta ${h.trophyDelta > 0 ? 'up' : 'down'}`}>{h.trophyDelta > 0 ? '+' : ''}{h.trophyDelta}</span>}
                    {has && <Icon name="replay" size={18} color="var(--blue-light)" />}
                  </button>
                )
              })}
            </div>
          )}
        </div>
      </div>
    </Sheet>
  )
}

function Tile({ icon, color, value, label, detail }: { icon: string; color: string; value: string; label: string; detail: string }) {
  return (
    <div className="tile" style={{ ['--c' as string]: color }}>
      <span className="tile-ico"><Icon name={icon} size={15} /></span>
      <span className="col" style={{ gap: 1, minWidth: 0 }}>
        <b className="r clip1">{value}</b>
        <span className="tile-l clip1">{label}</span>
        <span className="tile-d clip1">{detail}</span>
      </span>
    </div>
  )
}

function TrophyTrend({ history, now }: { history: S.GameRecord[]; now: number }) {
  let v = now - history.reduce((s, h) => s + h.trophyDelta, 0)
  const pts = [v, ...history.map(h => (v += h.trophyDelta))]
  const lo = Math.min(...pts), hi = Math.max(...pts, lo + 10)
  const d = pts.map((y, i) => `${(i / (pts.length - 1)) * 100},${40 - ((y - lo) / (hi - lo)) * 36 - 2}`).join(' ')
  return (
    <div className="col" style={{ gap: 4 }}>
      <svg viewBox="0 0 100 40" preserveAspectRatio="none" className="trend">
        <polyline points={`0,40 ${d} 100,40`} fill="#F2C14E22" stroke="none" />
        <polyline points={d} fill="none" stroke="var(--gold)" strokeWidth="1.4" vectorEffect="non-scaling-stroke" />
      </svg>
      <div className="row muted num" style={{ fontSize: 11 }}><span>{pts[0]}</span><span className="spacer" /><span>{now}</span></div>
    </div>
  )
}

function Medal({ a }: { a: S.Achievement }) {
  const { t } = useI18n()
  const colors = ['#C9A96E', '#CD7F32', '#C0C8D8', '#F2C14E']
  return (
    <span className="medal" title={t(a.title, ...(a.titleArgs ?? []).map(x => t(String(x))))} style={{ ['--m' as string]: colors[a.tier] }}>
      <Icon name={a.icon} size={18} />
    </span>
  )
}

export function AchievementsSheet() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [toast, showToast] = useToast()
  const all = S.achievements(p)
  return (
    <Sheet title={t('Erfolge')} onClose={closeSheet} wide tall>
      {(() => {
        const done = all.filter(S.isUnlockedAchievement).length
        return (
          <div className="ach-head">
            <Ring value={done} max={all.length} label="" color="var(--gold)" />
            <div className="col grow" style={{ gap: 2 }}>
              <b className="r" style={{ fontSize: 18 }}>{t('{0} von {1} Erfolgen', done, all.length)}</b>
              <span className="muted" style={{ fontSize: 11, fontWeight: 600 }}>{t('Jeder Erfolg bringt Splitter – manche auch Titel oder Rahmen.')}</span>
            </div>
          </div>
        )
      })()}
      {S.claimableAchievements(p).length > 0 && (() => {
        const claimable = S.claimableAchievements(p)
        const total = claimable.reduce((n, a) => n + a.shards, 0)
        return (
          <button className="chunky gold sm pulse-gold" style={{ marginBottom: 12, justifyContent: 'space-between' }}
            onClick={() => { let n = 0; for (const a of S.claimableAchievements()) n += S.claimAchievement(a); if (n > 0) { sound('reward_big'); haptic('chestBig') }; showToast(t('+{0} Splitter', n)) }}>
            <span className="row" style={{ gap: 8 }}><Icon name="gift" size={16} />{claimable.length === 1 ? t('Erfolg abholen') : t('{0} Erfolge abholen', claimable.length)}</span>
            <span className="row num" style={{ gap: 3 }}><ShardIcon size={13} />+{total}</span>
          </button>
        )
      })()}
      {S.ACHIEVEMENT_CATEGORIES.map(([id, name, icon]) => (
        <section key={id} className="col" style={{ gap: 8, marginBottom: 16 }}>
          <span className="row section-h" style={{ gap: 6 }}><Icon name={icon} size={13} />{t(name)}<span className="spacer" />
            <span className="num" style={{ color: 'var(--gold)' }}>{all.filter(a => a.category === id && S.isUnlockedAchievement(a)).length}/{all.filter(a => a.category === id).length}</span></span>
          <div className="ach-grid">
            {all.filter(a => a.category === id).map(a => {
              const done = S.isUnlockedAchievement(a)
              const claimed = S.isClaimedAchievement(a, p)
              const tArgs = (a.titleArgs ?? []).map(x => t(String(x)))
              const dArgs = (a.detailArgs ?? []).map(x => (typeof x === 'string' ? t(x) : x))
              const reward = [t('{0} Splitter', a.shards), a.rewardTitle ? t('Titel „{0}“', t(a.rewardTitle)) : '', a.rewardFrame ? t('Rahmen „{0}“', t(FRAMES[a.rewardFrame].name)) : ''].filter(Boolean).join(' + ')
              return (
                <div key={a.id} className={`ach${done ? ' done' : ''}`}>
                  <Medal a={a} />
                  <div className="grow col" style={{ gap: 2 }}>
                    <b>{t(a.title, ...tArgs)}</b>
                    <span className="muted" style={{ fontSize: 12 }}>{t(a.detail, ...dArgs)}</span>
                    {!done && <><Progress value={a.progress / a.goal} height={5} /><span className="muted num" style={{ fontSize: 10 }}>{Math.min(a.progress, a.goal)}/{a.goal}</span></>}
                    <span className="muted" style={{ fontSize: 11 }}>{reward}</span>
                  </div>
                  {done && !claimed && <button className="chunky xs gold" style={{ width: 'auto', padding: '0 12px' }} onClick={() => showToast(t('+{0} Splitter', S.claimAchievement(a)))}>{t('Abholen')}</button>}
                  {claimed && <Icon name="checkCircle" size={18} color="var(--gold)" />}
                </div>
              )
            })}
          </div>
        </section>
      ))}
      {toast}
    </Sheet>
  )
}

export function StyleSheet() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [tab, setTabState] = useState<'avatars' | 'frames' | 'titles' | 'boards' | 'pieces'>('avatars')
  const [buy, setBuy] = useState<{ kind: 'avatar'; id: AvatarId } | { kind: 'board'; id: BoardTheme } | null>(null)
  const frames = S.unlockedFrames(p)
  return (
    <Sheet title={t('Garderobe')} onClose={closeSheet} wide>
      <div className="style-preview">
        <PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={96} />
        <b className="r" style={{ fontSize: 20 }}>{S.shownName(p.name, t)}</b>
        <span className="kicker" style={{ color: 'var(--blue-light)' }}>{t(S.activeTitle(p)).toUpperCase()}</span>
        <button className="ghost" onClick={() => openSheet(Online.hasAccount() ? 'onlineName' : 'name', 'rename')}><Icon name="pencilCircle" size={14} /> {t('Spielername ändern')}</button>
      </div>
      <div className="seg" style={{ marginBottom: 12 }}>
        {(['avatars', 'frames', 'titles', 'boards', 'pieces'] as const).map(k => (
          <button key={k} className={tab === k ? 'on' : ''} onClick={() => setTabState(k)}>{t({ avatars: 'Avatare', frames: 'Rahmen', titles: 'Titel', boards: 'Bretter', pieces: 'Figuren' }[k])}</button>
        ))}
      </div>
      {tab === 'avatars' && (
        <div className="pick-grid">
          {AVATARS.map(a => {
            const own = S.isAvatarOwned(a.id, p)
            const on = S.activeAvatar(p) === a.id
            return (
              <button key={a.id} className={`pick${on ? ' on' : ''}${own ? '' : ' locked'}`} onClick={() => own ? S.update(x => { x.selectedAvatar = a.id }) : setBuy({ kind: 'avatar', id: a.id })}>
                <img src={avatarImage(a.id)} alt="" className="pick-avatar" />
                <b>{t(a.name)}</b>
                {own ? <span style={{ color: COSMETIC_RARITY[a.rarity].color, fontSize: 10 }}>{t(COSMETIC_RARITY[a.rarity].name)}</span>
                  : <span className="num" style={{ fontSize: 11, color: p.shards >= avatarPrice(a.id) ? 'var(--shard)' : 'var(--muted)' }}>{t('{0} Splitter', avatarPrice(a.id))}</span>}
              </button>
            )
          })}
        </div>
      )}
      {tab === 'frames' && (
        <div className="pick-grid">
          {FRAME_IDS.map(f => {
            const own = frames.includes(f)
            return (
              <button key={f} className={`pick${S.activeFrame(p) === f ? ' on' : ''}${own ? '' : ' locked'}`} disabled={!own} onClick={() => S.update(x => { x.selectedFrame = f === 'none' ? null : f })}>
                <PlayerAvatar avatar={S.activeAvatar(p)} frame={f as FrameId} size={56} />
                <b>{t(FRAMES[f].name)}</b>
                {(() => {
                  // Footer like framesTab in the app: unlocked, the shop price, or the achievement that brings it.
                  const source = S.achievements(p).find(a => a.rewardFrame === f)
                  const text = own ? t('Freigeschaltet') : SHOP_FRAMES.includes(f as FrameId) ? t('Laden · {0}', SHOP_FRAME_PRICE)
                    : source ? t(source.title, ...(source.titleArgs ?? []).map(x => t(String(x)))) : ''
                  return text ? <span className="muted" style={{ fontSize: 10, color: !own && SHOP_FRAMES.includes(f as FrameId) ? 'var(--shard)' : undefined }}>{text}</span> : null
                })()}
              </button>
            )
          })}
        </div>
      )}
      {tab === 'titles' && (() => {
        // Like titlesTab in the app: the rank, every achievement title (locked ones with their progress), the chest titles.
        const unlocked = S.unlockedTitles(p)
        const rankActive = !(p.selectedTitle && unlocked.includes(p.selectedTitle))
        const tiles: Array<{ key: string; title: string; hint: string; own: boolean; value: string | null }> = [
          { key: 'rank', title: rankFor(S.levelFor(p.xp)), hint: t('Rang nach Level'), own: true, value: null },
          ...S.achievements(p).filter(a => a.rewardTitle).map(a => {
            const done = S.isUnlockedAchievement(a)
            const dArgs = (a.detailArgs ?? []).map(x => (typeof x === 'string' ? t(x) : x))
            return { key: 'a-' + a.id, title: a.rewardTitle!, own: done, value: a.rewardTitle!,
              hint: done ? t(a.title, ...(a.titleArgs ?? []).map(x => t(String(x)))) : `${t(a.detail, ...dArgs)} (${Math.min(a.progress, a.goal)}/${a.goal})` }
          }),
          ...CHEST_TITLES.map(c => ({ key: 'c-' + c.title, title: c.title, hint: t('{0} · aus Truhen', t(COSMETIC_RARITY[c.rarity].name)), own: p.chestTitles.includes(c.title), value: c.title })),
        ]
        return (
          <div className="title-grid">
            {tiles.map(x => {
              const on = x.value === null ? rankActive : p.selectedTitle === x.value && x.own
              return (
                <button key={x.key} className={`title-tile${on ? ' on' : ''}${x.own ? '' : ' locked'}`}
                  onClick={() => { if (!x.own) { haptic('invalid'); return } S.update(y => { y.selectedTitle = x.value }) }}>
                  <span className="ribbon">{t(x.title).toUpperCase()}</span>
                  <b>{t(x.title)}</b>
                  <span className="muted">{x.hint}</span>
                </button>
              )
            })}
          </div>
        )
      })()}
      {tab === 'boards' && (<>
        <p className="dim" style={{ marginTop: 0, fontSize: 13 }}>{t('Sammelbretter (Lava, Smaragd, Mitternacht) kommen aus Magischen und Legendären Truhen oder kosten {0} Splitter.', BOARD_PRICE)}</p>
        <div className="pick-grid">
          {BOARD_THEMES.map(b => {
            const own = S.isBoardOwned(b, p)
            const c = BOARD_COLORS[b]
            return (
              <button key={b} className={`pick${p.settings.boardTheme === b ? ' on' : ''}${own ? '' : ' locked'}`} onClick={() => own ? S.setSettings(s => { s.boardTheme = b }) : setBuy({ kind: 'board', id: b })}>
                <span className="mini-check big">{Array.from({ length: 16 }, (_, i) => <i key={i} style={{ background: (Math.floor(i / 4) + i) % 2 ? c.dark : c.light }} />)}</span>
                <b>{t(BOARD_NAMES[b])}</b>
                {own ? <span className="muted" style={{ fontSize: 10 }}>{isCollectibleBoard(b) ? t('Sammelbrett') : t('Freigeschaltet')}</span>
                  : <span className="num" style={{ fontSize: 11, color: p.shards >= BOARD_PRICE ? 'var(--shard)' : 'var(--muted)' }}>{t('{0} Splitter', BOARD_PRICE)}</span>}
              </button>
            )
          })}
        </div>
      </>)}
      {tab === 'pieces' && (
        <>
          <p className="dim" style={{ marginTop: 0, fontSize: 13 }}>{t('Besiege einen Bot – in der Leiter oder im Kampf – und sein Figurenset gehört dir. Du spielst dann mit diesen Figuren.')}</p>
          <div className="pick-grid">
            <button className={`pick${!p.selectedSkin ? ' on' : ''}`} onClick={() => S.update(x => { x.selectedSkin = null })}>
              <span className="row" style={{ gap: 0 }}><img src={pieceImage('w', 'n')} alt="" style={{ width: 34 }} /><img src={pieceImage('b', 'q')} alt="" style={{ width: 34 }} /></span>
              <b>{t('Standard')}</b>
              <span className="muted" style={{ fontSize: 10 }}>{t('Die klassischen Figuren')}</span>
            </button>
            {BOTS.map(b => {
              const own = S.isSkinUnlocked(b, p)
              return (
                <button key={b.id} className={`pick${p.selectedSkin === b.id ? ' on' : ''}${own ? '' : ' locked'}`} disabled={!own} onClick={() => S.update(x => { x.selectedSkin = b.id })}>
                  <span className="row" style={{ gap: 0, filter: own ? undefined : 'brightness(0) opacity(.4)' }}><img src={pieceImage('w', 'n', b.id)} alt="" style={{ width: 34 }} /><img src={pieceImage('b', 'q', b.id)} alt="" style={{ width: 34 }} /></span>
                  <b>{t(b.skin)}</b>
                  <span className="muted" style={{ fontSize: 10, color: own ? b.color : undefined }}>{own ? t('von {0}', t(b.name)) : t('Besiege {0} (Stufe {1})', t(b.name), b.tier)}</span>
                </button>
              )
            })}
          </div>
        </>
      )}
      {buy && (() => {
        const price = buy.kind === 'avatar' ? avatarPrice(buy.id) : BOARD_PRICE
        const item: S.ShopItem = buy.kind === 'avatar' ? { kind: 'avatar', avatar: buy.id } : { kind: 'board', board: buy.id }
        const name = buy.kind === 'avatar' ? t(AVATARS.find(a => a.id === buy.id)!.name) : t(BOARD_NAMES[buy.id])
        const can = p.shards >= price
        return (
          <Dialog title={buy.kind === 'avatar' ? t('Avatar „{0}“ kaufen?', name) : t('Brett „{0}“ kaufen?', name)}
            message={!can ? t('Dir fehlen noch {0} Splitter.', price - p.shards)
              : buy.kind === 'avatar' ? t('{0} · auch aus Truhen ziehbar', t(COSMETIC_RARITY[AVATARS.find(a => a.id === buy.id)!.rarity].name)) : t('Auch aus Magischen und Legendären Truhen')} onClose={() => setBuy(null)}
            actions={can ? [{ label: t('Für {0} Splitter kaufen', price), bold: true, onClick: () => { S.buyItem(item, price); if (buy.kind === 'board') S.setSettings(s => { s.boardTheme = buy.id }) } }, { label: t('Abbrechen') }]
              : [{ label: t('Fertig') }]} />
        )
      })()}
    </Sheet>
  )
}
