// ProfileViews.swift, ProfileExtras.swift, ProfileFun.swift: profile tab, achievements and the wardrobe.
import { useState } from 'react'
import { avatarImage, pieceImage } from '../art'
import {
  AVATARS, BOARD_COLORS, BOARD_NAMES, BOARD_PRICE, BOARD_THEMES, BOTS, CARDS, CARD_IDS, COSMETIC_RARITY, FRAMES, FRAME_IDS, ULT_IDS,
  avatarPrice, botRecordName, isCollectibleBoard, type AvatarId, type BoardTheme, type FrameId,
} from '../game/catalog'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeSheet, openOverlay, openSheet, setTab } from '../nav'
import { Icon } from '../ui/Icon'
import { Dialog, PlayerAvatar, Progress, Sheet, ShardIcon, useToast } from '../ui/kit'
import { CHEST_TITLES, SHOP_FRAMES, SHOP_FRAME_PRICE, rankFor } from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import { BotPortrait } from './Game'
import * as Online from '../online'
import { FriendsCard } from './Friends'

export function ProfileScreen() {
  const p = S.useProfile()
  const { t } = useI18n()
  const lp = S.levelProgress(p)
  const all = S.achievements(p)
  const done = all.filter(S.isUnlockedAchievement)
  const claimable = S.claimableAchievements(p)
  const next = all.filter(a => !S.isUnlockedAchievement(a)).sort((a, b) => b.progress / b.goal - a.progress / a.goal).slice(0, 3)
  const games = p.wins + p.losses + p.draws
  const rate = games ? Math.round((p.wins / games) * 100) : 0
  const acc = Online.useAccount()
  const form = p.history.filter(h => h.opponent !== 'Zu zweit').slice(0, 8).reverse()
  const frames = S.unlockedFrames(p)
  return (
    <div className="page">
      <div className="page-glow" style={{ background: 'linear-gradient(#6B4FD855, transparent)' }} />
      <div className="page-inner">
        <div className="hdr">
          <Icon name="person" size={24} color="var(--blue-light)" />
          <h1 className="title-xl grow">{t('Profil')}</h1>
          <span className="capsule chip num"><ShardIcon size={13} />{p.shards}</span>
          <button className="icon-btn" onClick={() => openSheet('settings')} aria-label={t('Einstellungen')}><Icon name="gear" size={22} /></button>
        </div>
        <div className="profile-grid">
          <div className="col" style={{ gap: 14 }}>
            <button className="card hero-profile press" onClick={() => openSheet('style')} aria-label={t('Avatar, Rahmen und Titel ändern')}>
              <PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={92} />
              <div className="col grow" style={{ gap: 4, textAlign: 'left' }}>
                <b className="r" style={{ fontSize: 24 }}>{S.shownName(p.name, t)}</b>
                <span className="kicker" style={{ color: 'var(--blue-light)' }}>{t(S.activeTitle(p)).toUpperCase()}</span>
                <span className="dim" style={{ fontSize: 12 }}>{t('Level {0} · noch {1} XP bis Level {2}', lp.level, lp.remaining, lp.level + 1)}</span>
                <Progress value={lp.fraction} kind="mana" />
                <span className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
                  <span className="capsule chip gold"><Icon name="trophy" size={10} />{p.trophies} · {t('Rekord {0}', p.bestTrophies)}</span>
                  <span className="capsule chip"><Icon name="flame" size={10} color="#FF7A2F" />{S.currentStreak(p)} · {t('Rekord {0}', p.bestStreak)}</span>
                  <span className="capsule chip">{t('Arena {0}', S.arena(p).n)}</span>
                  {acc.status === 'apple' && <span className="capsule chip"><Icon name="apple" size={10} />{t('Mit Apple gesichert')}</span>}
                </span>
              </div>
              <Icon name="pencilCircle" size={22} color="var(--blue-light)" />
            </button>

            <FriendsCard />

            <div className="card col">
              <span className="row section-h" style={{ gap: 6 }}><Icon name="columns" size={13} />{t('Ruhmeshalle')}</span>
              <div className="fame-grid">
                <Fame icon="crown" color="var(--gold)" value={p.wins} label={t('Siege')} sub={games ? t('{0} % Siegquote', rate) : t('Noch keine Partien')} />
                <Fame icon="puzzle" color="var(--mana-light, #8FB6FF)" value={p.solvedPuzzles.length} label={t('Puzzles gelöst')} sub={t('Zum Puzzle-Tab')} onClick={() => setTab('puzzles')} />
                <Fame icon="medal" color="#F0B07A" value={done.length} label={t('Erfolge')} sub={t('von {0}', all.length)} onClick={() => openSheet('achievements')} />
                <Fame icon="calendar" color="#FF7A2F" value={p.activeDays.length} label={t('Aktive Tage')} sub={t('Rekordflamme {0}', p.bestStreak)} onClick={() => openSheet('flame')} />
              </div>
            </div>

            <div className="card col">
              <div className="row"><span className="section-h">{t('Bot-Bezwinger')}</span><span className="spacer" /><span className="dim num" style={{ fontSize: 12 }}>{p.ladderBeaten}/12</span></div>
              <div className="bot-wall">
                {BOTS.map(b => {
                  const beat = S.isLadderBeaten(b, p) || p.history.some(h => h.opponent === botRecordName(b) && h.result === 'win')
                  return <span key={b.id} className={beat ? '' : 'dimmed'} title={t(b.name)}>{beat ? <BotPortrait id={b.id} size={40} /> : <span className="bot-unknown"><Icon name="question" size={16} /></span>}</span>
                })}
              </div>
              <span className="muted" style={{ fontSize: 12 }}>{p.ladderBeaten >= 12 ? t('Alle zwölf bezwungen – du bist eine Legende!') : t('Nächster Gegner: {0}, {1}', t(BOTS[p.ladderBeaten].name), t(BOTS[p.ladderBeaten].title))}</span>
              <button className="ghost" onClick={() => openSheet('ladder')}>{t('Zur Leiter')}</button>
            </div>
          </div>

          <div className="col" style={{ gap: 14 }}>
            <div className="card col">
              {(() => {
                const rings = [
                  [CARD_IDS.filter(c => S.isCardUnlocked(c, p)).length, CARD_IDS.length, 'Karten', 'var(--blue-light)'],
                  [ULT_IDS.filter(u => S.isUltUnlocked(u, p)).length, ULT_IDS.length, 'Ultimates', 'var(--gold)'],
                  [AVATARS.filter(a => S.isAvatarOwned(a.id, p)).length, AVATARS.length, 'Avatare', 'var(--red-light)'],
                  [frames.length, FRAME_IDS.length, 'Rahmen', '#8FB6FF'],
                  [BOARD_THEMES.filter(b => S.isBoardOwned(b, p)).length, BOARD_THEMES.length, 'Bretter', '#7FE3FF'],
                  [BOTS.filter(b => S.isSkinUnlocked(b, p)).length + 1, BOTS.length + 1, 'Figuren', '#F0B07A'],
                ] as const
                const have = rings.reduce((s, r) => s + r[0], 0), total = rings.reduce((s, r) => s + r[1], 0)
                return <>
                  <div className="row"><span className="section-h">{t('Sammlung')}</span><span className="spacer" /><span className="dim" style={{ fontSize: 12 }}>{t('{0} % gesammelt', Math.round((have / Math.max(1, total)) * 100))}</span></div>
                  <div className="rings six">{rings.map(([v, m, l, c]) => <Ring key={l} value={v} max={m} label={t(l)} color={c} />)}</div>
                </>
              })()}
            </div>

            <div className="card col">
              <div className="row">
                <span className="section-h">{t('Erfolge')}</span>
                <span className="dim num" style={{ fontSize: 12, marginLeft: 8 }}>{done.length}/{all.length}</span>
                <span className="spacer" />
                <button className="ghost" style={{ width: 'auto' }} onClick={() => openSheet('achievements')}>{t('Alle')} <Icon name="chevronRight" size={12} /></button>
              </div>
              {claimable.length > 0 && (
                <button className="chunky gold sm pulse-gold" onClick={() => { for (const a of S.claimableAchievements()) S.claimAchievement(a) }}>
                  <ShardIcon size={16} />{t('Erfolg abholen')} ({claimable.length})
                </button>
              )}
              {done.length > 0 && <div className="medals shelf">{done.map(a => <Medal key={a.id} a={a} />)}</div>}
              {next.length === 0 && <span className="muted" style={{ fontSize: 12 }}>{t('Alle Erfolge geschafft – Respekt!')}</span>}
              {next.map(a => {
                const tArgs = (a.titleArgs ?? []).map(x => t(String(x)))
                const dArgs = (a.detailArgs ?? []).map(x => (typeof x === 'string' ? t(x) : x))
                return (
                  <div key={a.id} className="row" style={{ gap: 10, alignItems: 'flex-start' }}>
                    <Medal a={a} />
                    <div className="col grow" style={{ gap: 3, minWidth: 0 }}>
                      <div className="row"><b className="grow clip1" style={{ fontSize: 13 }}>{t(a.title, ...tArgs)}</b><span className="muted num" style={{ fontSize: 11 }}>{Math.min(a.progress, a.goal)}/{a.goal}</span></div>
                      <Progress value={a.progress / a.goal} height={6} />
                      <span className="muted" style={{ fontSize: 11 }}>{t(a.detail, ...dArgs)} · {t('{0} Splitter', a.shards)}</span>
                    </div>
                  </div>
                )
              })}
            </div>

            <button className="card row press stats-link" onClick={() => openSheet('stats')}>
              <span className="stats-ico"><Icon name="chart" size={18} /></span>
              <span className="col grow" style={{ gap: 4, textAlign: 'left' }}>
                <b>{t('Statistik & Verlauf')}</b>
                <span className="dim" style={{ fontSize: 12 }}>{games === 0 ? t('Noch keine Partien') : t('{0} S · {1} N · {2} R · {3} % Siege', p.wins, p.losses, p.draws, rate)}</span>
                {form.length > 0 && <span className="form-dots">{form.map(h => <i key={h.id} className={h.result} />)}</span>}
              </span>
              <Icon name="chevronRight" size={14} color="var(--muted)" />
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

function Fame({ icon, color, value, label, sub, onClick }: { icon: string; color: string; value: number; label: string; sub: string; onClick?: () => void }) {
  return (
    <button className="fame press" onClick={onClick} disabled={!onClick} style={{ ['--c' as string]: color }}>
      <span className="fame-ico"><Icon name={icon} size={16} /></span>
      <b className="r num">{value}</b>
      <span className="fame-l">{label}</span>
      <span className="fame-s">{sub}</span>
    </button>
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
