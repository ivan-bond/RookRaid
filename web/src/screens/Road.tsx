// TrophyRoadView.swift (tab "Pfad") and LadderViews.swift (Bot-Leiter).
import { useEffect, useRef, useState } from 'react'
import { arenaImage, pieceImage } from '../art'
import { ARENAS, ARENA_PALETTE, BOARD_COLORS, BOARD_NAMES, BOTS, CHEST, ROAD, ULTS, botTrophyStart, ladderChest, type RoadStep, type UltId } from '../game/catalog'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeSheet, openChests, openSheet } from '../nav'
import { Icon } from '../ui/Icon'
import { sound } from '../game/feedback'
import { CardThumb, ChestView, Confetti, PlayerAvatar, Progress, ShardIcon, Sheet, Stars, tierColor, useToast } from '../ui/kit'
import { BotPortrait } from './Game'
import { HomeHeader, roadTitle, useStartGame, EmptyDeckDialog } from './Home'

export function RoadScreen() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [toast, showToast] = useToast()
  const [burst, setBurst] = useState(0)
  const focus = useRef<HTMLDivElement>(null)
  const arena = S.arena(p)
  const trophies = S.roadTrophies(p)
  const claimable = S.claimableRoadSteps(p)
  const next = S.nextRoadStep(p)

  useEffect(() => { focus.current?.scrollIntoView({ block: 'center' }) }, [])

  const claim = (s: RoadStep) => {
    const res = S.claimRoad(s)
    if (!res) return
    setBurst(b => b + 1)
    if (res.kind === 'chest') openChests(res.chest)
    else if (res.kind === 'shards') showToast(t('+{0} Splitter', res.n))
    else showToast(t('Neues Brett: {0}!', t(BOARD_NAMES[res.board])))
  }
  const claimAll = () => {
    let first: S.Chest | null = null
    const ids = new Set<string>()
    for (const s of S.claimableRoadSteps()) {
      const res = S.claimRoad(s)
      if (res?.kind === 'chest') { first ??= res.chest; ids.add(res.chest.id) }
    }
    setBurst(b => b + 1)
    if (first) openChests(first, ids)
  }

  return (
    <div className="page road-page" style={{ background: `linear-gradient(${ARENA_PALETTE[arena.n][1]}8c, var(--bg) 40%)` }}>
      <div className="road-head">
        <div className="page-inner" style={{ minHeight: 0, paddingBottom: 10 }}>
          <div className="row" style={{ gap: 10 }}>
            <Icon name="trophy" size={24} color="var(--gold)" />
            <h1 className="title-xl grow">{t('Pfad')}</h1>
            <button className="icon-btn" onClick={() => openSheet('roadGuide')} aria-label={t('So funktioniert der Pfad')}><Icon name="question" size={20} /></button>
            <span className="trophy-pill num"><Icon name="trophy" size={17} color="var(--gold)" />{p.trophies}</span>
          </div>
          <div className="road-summary">
            <span className="arena-medal" style={{ width: 44, height: 44, background: `linear-gradient(${ARENA_PALETTE[arena.n][0]}, ${ARENA_PALETTE[arena.n][1]})` }}><Icon name={arena.icon} size={20} color="#fff" /></span>
            <div className="grow col" style={{ gap: 4 }}>
              <span className="kicker" style={{ color: 'var(--gold)' }}>{t('ARENA {0} · {1}', arena.n, t(arena.name).toUpperCase())}</span>
              {next ? <span className="dim num" style={{ fontSize: 12, fontWeight: 700 }}>{t('Nächste Belohnung: {0}', roadTitle(next.reward, t))} · {t('noch {0}', next.trophies - trophies)}</span>
                : <span className="dim" style={{ fontSize: 12 }}>{t('Der Gipfel: {0} Trophäen', 2400)}</span>}
              <Progress value={next ? trophies / next.trophies : 1} />
            </div>
            {claimable.length > 1 && <button className="chunky gold xs pulse-gold" style={{ width: 'auto' }} onClick={claimAll}>{t('ALLE {0} ABHOLEN', claimable.length)}</button>}
          </div>
        </div>
      </div>
      <div className="road">
        <div className="road-summit">
          <Icon name="crown" size={42} color="var(--gold)" />
          <b className="r">{t('Der Gipfel: {0} Trophäen', 2400)}</b>
          <span className="dim" style={{ fontSize: 12 }}>{t('Hier oben thront die Turmkönigin. Schaffst du es bis zu ihr?')}</span>
        </div>
        {[...ARENAS].reverse().map(a => {
          const hi = a.n < 6 ? ARENAS[a.n].trophies : 2500
          const steps = ROAD.filter(s => s.trophies >= a.trophies && s.trophies < hi).filter(s => s.reward.kind !== 'arena' || s.reward.arena !== a.n)
          const arenaStep = ROAD.find(s => s.reward.kind === 'arena' && s.reward.arena === a.n)
          const bots = BOTS.filter(b => botTrophyStart(b) >= a.trophies && botTrophyStart(b) < hi && botTrophyStart(b) > 0)
          type Item = { kind: 'step'; s: RoadStep } | { kind: 'bot'; id: string; at: number } | { kind: 'you'; at: number }
          const items: Item[] = [...steps.map(s => ({ kind: 'step' as const, s })), ...bots.map(b => ({ kind: 'bot' as const, id: b.id, at: botTrophyStart(b) }))]
          if (arena.n === a.n) items.push({ kind: 'you', at: p.trophies })
          const at = (it: Item) => (it.kind === 'step' ? it.s.trophies : it.at)
          items.sort((x, y) => at(y) - at(x) || (x.kind === 'you' ? 1 : -1))
          const reached = trophies >= a.trophies
          const colors = ARENA_PALETTE[a.n]
          return (
            <section key={a.n} className={`road-arena${reached ? '' : ' locked'}`} style={{ ['--a0' as string]: colors[0], ['--a1' as string]: colors[1] }}>
              <div className="biome" style={{ backgroundImage: `url(${arenaImage(a.n)})` }} />
              <div className="road-trail">
                {items.map((it, i) => {
                  const side = i % 2 === 0 ? 'l' : 'r'
                  if (it.kind === 'you') return (
                    <div key="you" className="trail-you" ref={focus}>
                      <PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={52} />
                      <span className="capsule" style={{ background: 'var(--blue)', color: '#fff', fontWeight: 900 }}>{t('Du · {0}', p.trophies)}</span>
                    </div>
                  )
                  if (it.kind === 'bot') {
                    const b = BOTS.find(x => x.id === it.id)!
                    const known = S.isLadderBeaten(b, p) || trophies >= it.at
                    return (
                      <div key={'b' + it.id} className={`trail-bot ${side}`}>
                        {known ? <BotPortrait id={b.id} size={44} /> : <span className="bot-unknown"><Icon name="question" size={22} /></span>}
                        <span className="col" style={{ gap: 0 }}><b className="r">{known ? t(b.name) : t('Unbekannter Gegner')}</b><span className="muted num" style={{ fontSize: 11 }}>{t('ab {0}', it.at)}</span></span>
                      </div>
                    )
                  }
                  const s = it.s
                  const claimed = S.isRoadClaimed(s, p)
                  const can = S.canClaimRoad(s, p)
                  return (
                    <div key={s.trophies} className={`trail-step ${side}${claimed ? ' claimed' : can ? ' ready' : ''}`}>
                      <span className="trail-num num">{s.trophies}</span>
                      <button className={`trail-reward${can ? ' pulse-gold' : ''}`} disabled={!can} onClick={() => claim(s)}
                        aria-label={t('{0} Trophäen: {1}{2}', s.trophies, roadTitle(s.reward, t), claimed ? t(', abgeholt') : can ? t(', abholbar') : t(', gesperrt'))}>
                        <RoadRewardIcon s={s} />
                        {claimed && <span className="trail-check"><Icon name="check" size={12} /></span>}
                      </button>
                      <span className="trail-label">{roadTitle(s.reward, t)}</span>
                      {can && <span className="capsule" style={{ background: 'var(--gold)', color: 'var(--navy)', fontWeight: 900 }}>{t('ABHOLEN')}</span>}
                      {!claimed && !can && <span className="muted num" style={{ fontSize: 10 }}>{t('noch {0}', s.trophies - trophies)}</span>}
                    </div>
                  )
                })}
              </div>
              <div className="road-gate">
                <span className="arena-medal big" style={{ background: `linear-gradient(${colors[0]}, ${colors[1]})` }}><Icon name={a.icon} size={26} color="#fff" /></span>
                <div className="col" style={{ gap: 2 }}>
                  <span className="kicker" style={{ color: 'var(--gold)' }}>{t('ARENA {0}', a.n)} · {a.trophies}</span>
                  <b className="title-m">{t(a.name)}</b>
                  <span className="dim" style={{ fontSize: 12 }}>{t(a.mechanic)}</span>
                  <span className="row" style={{ gap: 4, marginTop: 4 }}>
                    {(Object.keys(ULTS) as UltId[]).filter(u => ULTS[u].arena === a.n).map(u => <CardThumb key={u} art={`art-ult-${u}`} width={26} border="var(--gold)" />)}
                    {(Object.keys(ULTS) as UltId[]).some(u => ULTS[u].arena === a.n) && <span className="muted" style={{ fontSize: 11 }}>{(Object.keys(ULTS) as UltId[]).filter(u => ULTS[u].arena === a.n).length > 1 ? t('Neue Ultimates') : t('Neue Ultimate')}</span>}
                  </span>
                </div>
                {arenaStep && (
                  <button className={`trail-reward gate${S.canClaimRoad(arenaStep, p) ? ' pulse-gold' : ''}`} disabled={!S.canClaimRoad(arenaStep, p)} onClick={() => claim(arenaStep)}>
                    <ChestView rarity={(arenaStep.reward as { rarity: 0 }).rarity} size={44} glow={S.canClaimRoad(arenaStep, p) ? 0.7 : 0} />
                    {S.isRoadClaimed(arenaStep, p) && <span className="trail-check"><Icon name="check" size={12} /></span>}
                  </button>
                )}
                {reached && a.n !== arena.n && <span className="capsule chip gold" style={{ marginLeft: 'auto' }}>{t('Erobert')}</span>}
              </div>
            </section>
          )
        })}
        <div className="road-start"><span className="kicker">{t('START')}</span></div>
      </div>
      {burst > 0 && <Confetti key={burst} count={50} />}
      <button className="road-jump" onClick={() => { sound('select'); focus.current?.scrollIntoView({ block: 'center', behavior: 'smooth' }) }}>
        <PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={28} />{t('Zu mir')}
      </button>
      {toast}
    </div>
  )
}

function RoadRewardIcon({ s }: { s: RoadStep }) {
  const r = s.reward
  if (r.kind === 'chest' || r.kind === 'arena') return <ChestView rarity={r.rarity} size={40} glow={0.3} />
  if (r.kind === 'shards') return <span className="col" style={{ alignItems: 'center', gap: 0 }}><ShardIcon size={28} /><b className="num" style={{ fontSize: 11 }}>{r.n}</b></span>
  const c = BOARD_COLORS[r.board]
  return <span className="mini-check">{Array.from({ length: 9 }, (_, i) => <i key={i} style={{ background: i % 2 ? c.dark : c.light }} />)}</span>
}

export function RoadGuide() {
  const { t } = useI18n()
  return (
    <Sheet title={t('So funktioniert der Pfad')} onClose={closeSheet}>
      <div className="col" style={{ gap: 14 }}>
        <div className="card col">
          <b className="title-m" style={{ color: 'var(--gold)' }}>{t('Trophäenpfad')}</b>
          <div className="row" style={{ justifyContent: 'space-between' }}>
            {ARENAS.map(a => <span key={a.n} className="col" style={{ alignItems: 'center', gap: 4 }}><span className="arena-medal" style={{ background: `linear-gradient(${ARENA_PALETTE[a.n][0]}, ${ARENA_PALETTE[a.n][1]})` }}><Icon name={a.icon} size={15} color="#fff" /></span><b className="muted">{a.n}</b></span>)}
          </div>
          <span className="dim">{t('Sechs Arenen führen nach oben. Tippe ein Wappen, um dorthin zu springen.')}</span>
        </div>
        <div className="card col">
          <b className="title-m" style={{ color: '#C084FC' }}>{t('Truhen')}</b>
          <div className="row" style={{ justifyContent: 'center' }}>{([1, 2, 3, 4] as const).map(r => <ChestView key={r} rarity={r} size={40} />)}</div>
          <span className="dim">{t('Alle 50 bis 150 Trophäen wartet eine Belohnung: Truhen, Splitter, Sammelbretter und an jeder neuen Arena eine Magische oder Legendäre Truhe. Abgerechnet wird nach deinem Rekord – wer abrutscht, behält seine Stufen.')}</span>
        </div>
        <div className="card col">
          <b className="title-m" style={{ color: 'var(--gold)' }}>{t('Rekord')}</b>
          <span className="dim">{t('Auf dem Trophäenpfad zählt dein Rekord – wer abrutscht, behält seine Belohnungen.')}</span>
        </div>
      </div>
    </Sheet>
  )
}

// MARK: Bot ladder (LadderView in the app)

/** Round portrait of a bot in its colour – the king of its own piece set (BotAvatar in the app). */
export function BotAvatar({ id, size = 56, locked = false }: { id: string; size?: number; locked?: boolean }) {
  const bot = BOTS.find(b => b.id === id) ?? BOTS[0]
  return (
    <span className={`bot-avatar${locked ? ' locked' : ''}`} style={{ width: size, height: size, ['--tint' as string]: bot.color }}>
      {locked ? <Icon name="lock" size={size * 0.38} color="var(--muted)" /> : <img src={pieceImage('w', 'k', bot.id)} alt="" />}
    </span>
  )
}

/** Twelve opponents upwards: header, a trail of twelve dots, the next opponent big, then every step (top = strongest). */
export function LadderSheet() {
  const { t } = useI18n()
  const p = S.useProfile()
  const { start, emptyDeck, setEmptyDeck } = useStartGame()
  const next = S.ladderNext(p)
  const full = S.deckIsFull(p)
  const challenge = (id: string) => {
    if (!S.deckIsFull()) { setEmptyDeck(true); return }
    closeSheet()
    window.setTimeout(() => start({ kind: 'ladder', bot: id }), 250)
  }
  return (
    <Sheet onClose={closeSheet} wide tall>
      <div className="ladder2" style={{ ['--tint' as string]: next?.color ?? 'var(--gold)' }}>
        <div className="l2-head">
          <span className="l2-stairs"><Icon name="stairs" size={26} /></span>
          <b className="l2-title">{t('BOT-LEITER')}</b>
          <span className="l2-count num">{p.ladderBeaten}/{BOTS.length}</span>
        </div>
        <p className="l2-sub">{t('Zwölf Gegner, eine Krone. Keine Trophäen – nur Ehre, XP und Truhen.')}</p>
        <div className="l2-trail">
          {BOTS.map(b => {
            const beaten = S.isLadderBeaten(b, p)
            const here = b.id === next?.id
            return (
              <span key={b.id} className="l2-trail-step">
                {b.tier > 1 && <i className={`l2-link${beaten ? ' on' : ''}`} />}
                <i className={`l2-dot${here ? ' here' : ''}`} style={{ background: beaten || here ? b.color : undefined }} title={t(b.name)} />
              </span>
            )
          })}
        </div>
        {next ? (
          <div className="l2-hero" style={{ ['--tint' as string]: next.color }}>
            <div className="row" style={{ gap: 12, alignItems: 'center' }}>
              <span className="bob"><BotAvatar id={next.id} size={76} /></span>
              <div className="col grow" style={{ gap: 3, minWidth: 0 }}>
                <span className="l2-kicker">{t('NÄCHSTER GEGNER · STUFE {0}', next.tier)}</span>
                <b className="l2-name">{t(next.name)}</b>
                <span className="l2-role">{t(next.title)}</span>
                <span className="l2-motto">„{t(next.motto)}“</span>
              </div>
            </div>
            <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
              <span className="l2-chip xp"><Icon name="sparkles" size={11} />{t('+{0} XP', next.xpFirstWin)}</span>
              <span className="l2-chip"><ChestView rarity={ladderChest(next)} size={18} />{t(CHEST[ladderChest(next)].name)}</span>
            </div>
            <div className="l2-pieces">
              {['k', 'q', 'r', 'b', 'n', 'p'].map(x => <img key={x} src={pieceImage('w', x, next.id)} alt="" />)}
              <b>{t(next.skin)}</b>
            </div>
            {full
              ? <button className="chunky gold pulse-gold" onClick={() => challenge(next.id)}><Icon name="bolt" size={18} />{t('HERAUSFORDERN')}<span className="shine" /></button>
              : <button className="chunky" onClick={() => setEmptyDeck(true)}><Icon name="stack" size={18} />{t('Deck fertig bauen ({0}/{1})', S.activeDeck(p).length, 4)}</button>}
          </div>
        ) : (
          <div className="l2-champion">
            <span className="bob"><Icon name="crown" size={42} color="var(--gold)" /></span>
            <b>{t('Du hast die Leiter bezwungen!')}</b>
            <span className="dim">{t('Jede Revanche bringt weiter 10 XP.')}</span>
          </div>
        )}
        <div className="l2-steps">
          {[...BOTS].reverse().map(b => {
            const beaten = S.isLadderBeaten(b, p)
            const unlocked = S.isLadderUnlocked(b, p)
            const current = unlocked && !beaten
            const status = beaten ? t('Besiegt · Revanche +10 XP')
              : current ? t('+{0} XP · {1}', b.xpFirstWin, t(CHEST[ladderChest(b)].name))
              : t('Besiege zuerst {0}', t(BOTS[Math.max(0, b.tier - 2)].name))
            return (
              <button key={b.id} className={`l2-step${current ? ' current' : ''}${unlocked ? '' : ' locked'}`} disabled={!unlocked}
                onClick={() => (full ? challenge(b.id) : setEmptyDeck(true))} style={{ ['--tint' as string]: b.color }}
                aria-label={beaten ? t('Revanche gegen {0}', t(b.name)) : t(b.name)}>
                <i className={`l2-bar${beaten ? ' beaten' : current ? ' current' : ''}`} />
                <BotAvatar id={b.id} size={44} locked={!unlocked} />
                <span className="col grow" style={{ gap: 1, minWidth: 0, textAlign: 'left' }}>
                  <span className="row" style={{ gap: 6 }}>
                    <span className="l2-tier">{t('STUFE {0}', b.tier)}</span>
                    {current && <span className="l2-here">{t('DU BIST HIER')}</span>}
                  </span>
                  <b className="l2-step-name">{t(b.name)}</b>
                  <span className={`l2-status${beaten ? ' beaten' : current ? ' current' : ''}`}>{status}</span>
                </span>
                {beaten ? <span className="l2-check"><Icon name="check" size={13} color="#fff" /></span>
                  : !unlocked ? <Icon name="lock" size={14} color="var(--muted)" /> : null}
              </button>
            )
          })}
        </div>
      </div>
      {emptyDeck && <EmptyDeckDialog onClose={() => setEmptyDeck(false)} />}
    </Sheet>
  )
}

export { HomeHeader }
