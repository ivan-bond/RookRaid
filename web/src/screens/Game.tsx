// GameView.swift: the match screen. Phones: everything stacked. Wide windows: board left, cards and names right.
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { appLogo, avatarImage, pieceImage } from '../art'
import { ARENA_PALETTE, CARDS, TIME_CONTROLS, ULTS, botById, type CardId, type UltId } from '../game/catalog'
import { GameController, useController, type GameOverInfo } from '../game/controller'
import * as S from '../game/store'
import * as FM from '../friendMatch'
import { useI18n } from '../i18n'
import { closeOverlay, openChests, openOverlay, parkGame, run, setTab } from '../nav'
import { roadTitle } from './Home'
import { ROAD } from '../game/catalog'
import { Icon } from '../ui/Icon'
import { CardThumb, CardView, ChestView, Confetti, Dialog, ManaDrop, PlayerAvatar, Rays, UltimateCard, tierColor } from '../ui/kit'
import { Board } from './Board'
import { RulesSheet, CardDetail } from './Rules'
import { FlameLitRow } from './Flame'
import { arenaFor } from '../game/catalog'
import type { Side } from '../engine'

export function GameScreen({ game }: { game: GameController }) {
  const [c, setC] = useState(game)
  useController(c)
  const { t } = useI18n()
  const [menu, setMenu] = useState(false)
  const [confirmResign, setConfirmResign] = useState(false)
  const [rules, setRules] = useState(false)
  const [detail, setDetail] = useState<string | null>(null)
  const wrap = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState({ w: window.innerWidth, h: window.innerHeight })

  useEffect(() => {
    c.start()
    return () => { c.stop(); c.flushStats(); c.save(); if (c.canResumeOnline) parkGame(c) }
  }, [c])
  useEffect(() => { if (c.closeRequested) closeOverlay() }, [c.closeRequested, c.version])
  useLayoutEffect(() => {
    const el = wrap.current
    if (!el) return
    const ro = new ResizeObserver(() => setSize({ w: el.clientWidth, h: el.clientHeight }))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const top: Side = c.flipped ? 'w' : 'b'
  const bottom: Side = top === 'w' ? 'b' : 'w'
  const wide = size.w > size.h + 40 && size.w >= 700
  const tutorial = c.mode.kind === 'tutorial'

  const exit = () => { c.save(); closeOverlay() }
  const next = (mode: S.GameMode) => { c.stop(); c.flushStats(); S.clearGame(); setC(new GameController({ mode, timeControl: mode.kind === 'bot' ? 'blitz5' : 'none' })) }
  const rematch = () => setC(c.restart())

  const title = tutorial ? t('Erste Schlacht')
    : c.opponentCard ? t('Gegen ') + c.name(c.human === 'w' ? 'b' : 'w')
      : c.isBotMode ? (c.mode.kind === 'ladder' ? t('Leiter: ') : c.mode.kind === 'practice' ? t('Übung: ') : t('Gegen ')) + t(c.bot!.name)
        : t('Zu zweit')

  // Board side from the space left after the fixed rows (GameView.boardSide).
  const boardSide = (() => {
    if (wide) {
      const maxBoard = Math.max(160, size.h - 32 - 14)
      const column = Math.min(400, Math.max(260, size.w - maxBoard - 48))
      return { board: Math.max(160, Math.min(maxBoard, size.w - column - 28)), column }
    }
    const cardW = Math.max(40, (size.w - 20 - 66 - 1 - 30) / 4)
    const cardH = Math.max(cardW / 0.8 + 16, 66 / 0.8 + 15)
    const hand = 2 + 32 + 11 + cardH
    let reserved = 32 + (tutorial ? 84 : 80) + 46 + hand + 6 * 4 + 6
    if (!tutorial) reserved += 62 + 6
    return { board: Math.max(180, Math.min(size.w, size.h - reserved)), column: 0 }
  })()

  const topBar = (
    <div className="g-top">
      <button className="icon-btn" onClick={exit} aria-label={t('Zurück')}><Icon name="chevronLeft" size={20} /></button>
      <div className="g-title"><b>{title}</b>{TIME_CONTROLS[c.timeControl].seconds > 0 && <span>{t(TIME_CONTROLS[c.timeControl].name)}</span>}</div>
      <div style={{ position: 'relative' }}>
        <button className="icon-btn" onClick={() => setMenu(m => !m)} aria-label={t('Menü')}><Icon name="ellipsis" size={21} /></button>
        {menu && (
          <>
            <div className="menu-scrim" onClick={() => setMenu(false)} />
            <div className="menu">
              {tutorial && <button onClick={() => { setMenu(false); c.skipTutorial() }}><Icon name="chevronRight" size={16} />{t('Tutorial überspringen')}</button>}
              <button onClick={() => { setMenu(false); c.cancelPending() }}><Icon name="xCircle" size={16} />{t('Auswahl abbrechen')}</button>
              {c.canOfferDraw && <button onClick={() => { setMenu(false); void c.offerDraw() }}><Icon name="equal" size={16} />{t('Remis anbieten')}</button>}
              {!c.online && !tutorial && <button onClick={() => { setMenu(false); rematch() }}><Icon name="arrowCounter" size={16} />{t('Neue Partie')}</button>}
              <button onClick={() => { setMenu(false); setRules(true) }}><Icon name="book" size={16} />{t('Regeln')}</button>
              <button className="destructive" onClick={() => { setMenu(false); setConfirmResign(true) }}><Icon name="flag" size={16} />{t('Aufgeben')}</button>
            </div>
          </>
        )}
      </div>
    </div>
  )

  const board = (
    <div className={`board-box${c.shake % 2 ? ' shake-a' : c.shake ? ' shake-b' : ''}`} key={c.shake} style={{ width: boardSide.board, height: boardSide.board }}>
      <Board c={c} />
    </div>
  )

  return (
    <div className="full game" ref={wrap}>
      {wide ? (
        <div className="g-wide">
          {topBar}
          <div className="g-wide-body">
            <div className="g-wide-board">{board}</div>
            <div className="g-col" style={{ width: boardSide.column }}>
              {tutorial ? <QuestBar c={c} /> : <PlayerBar c={c} side={top} compact onDetail={setDetail} />}
              <div className="spacer" />
              <Hand c={c} onDetail={setDetail} />
              {!tutorial && <HintSlot c={c} />}
              <PlayerBar c={c} side={bottom} compact onDetail={setDetail} />
            </div>
          </div>
        </div>
      ) : (
        <div className="g-tall">
          {topBar}
          {tutorial ? <QuestBar c={c} /> : <div className="g-opp"><PlayerBar c={c} side={top} onDetail={setDetail} /></div>}
          <div className="g-board-row">{board}</div>
          <div className="g-me"><PlayerBar c={c} side={bottom} onDetail={setDetail} /></div>
          <div className="g-hand"><Hand c={c} onDetail={setDetail} /></div>
          {!tutorial && <div className="g-hand"><HintSlot c={c} /></div>}
        </div>
      )}

      {c.announcement && <Announcement key={c.announcement.id} a={c.announcement} />}
      {c.finisher && !c.gameOver && (() => {
        const won = c.isBotMode || c.online ? c.finisher.winner === c.human : true
        return <FinisherTitle look={won ? 'win' : 'loss'} sub={won ? t('Der König platzt!') : t('Dein König platzt!')}
          headline={t(c.finisher.kind === 'mate' ? 'SCHACHMATT' : c.finisher.kind === 'time' ? 'ZEIT UM!' : 'AUFGEGEBEN!')} />
      })()}
      {!c.finisher && c.drawFinish && !c.gameOver && <FinisherTitle look="draw" headline={t('REMIS')} sub={c.drawFinish} delay={0.1} />}
      {c.banner && <CastBanner key={c.banner.id} title={c.banner.title} art={c.banner.art} ult={c.banner.ult} caster={c.name(c.banner.caster)} />}
      {c.promotion && <PromotionPicker side={c.state.b[c.promotion.f]?.c as Side} skin={c.skin(c.state.cur)?.id} onPick={p => c.choosePromotion(p)} onCancel={() => c.cancelPromotion()} />}
      {c.onlineNotice && <div className="online-notice">{c.onlineNotice}</div>}
      {c.incomingDraw && (
        <div className="draw-offer slide-up">
          <b>{t('{0} bietet Remis an', c.name(c.human === 'w' ? 'b' : 'w'))}</b>
          <div className="row">
            <button className="chunky sm" onClick={() => void c.answerDraw(true)}>{t('Annehmen')}</button>
            <button className="chunky sm gray" onClick={() => void c.answerDraw(false)}>{t('Ablehnen')}</button>
          </div>
        </div>
      )}
      {c.introActive && <VersusIntro c={c} />}
      {c.tutorialComplete && <TutorialComplete xp={c.tutorialComplete.xp} streak={c.tutorialComplete.streak} />}
      {c.gameOver && (
        <GameOver info={c.gameOver} c={c} onExit={closeOverlay} onRematch={!c.online ? rematch : undefined}
          onNext={nextAction(c, next)} />
      )}
      {confirmResign && (
        <Dialog title={t('Partie aufgeben?')} onClose={() => setConfirmResign(false)}
          actions={[{ label: t('Aufgeben'), destructive: true, onClick: () => c.resign() }, { label: t('Weiterspielen'), bold: true }]} />
      )}
      {rules && <RulesSheet onClose={() => setRules(false)} />}
      {detail && <CardDetail id={detail} onClose={() => setDetail(null)} />}
    </div>
  )
}

function nextAction(c: GameController, next: (m: S.GameMode) => void): { title: string; icon: string; run: () => void } | null {
  const info = c.gameOver
  if (!info) return null
  // Friendly match: „Revanche“ challenges the same friend again (no ranked search).
  if (c.isFriendly) {
    if (!FM.getLastOpponent()) return null
    return { title: 'Revanche', icon: 'arrowCounter', run: () => { closeOverlay(); window.setTimeout(() => void FM.rematch(), 350) } }
  }
  if (c.online || c.mode.kind === 'bot') {
    if (c.online) return { title: 'Nächstes Spiel', icon: 'bolt', run: () => { closeOverlay(); window.setTimeout(() => run('quickBattle'), 350) } }
    return { title: 'Nächstes Spiel', icon: 'bolt', run: () => next({ kind: 'bot', bot: botById(S.getProfile().trophies >= 0 ? botIdFor() : 'easy').id }) }
  }
  if (c.mode.kind === 'ladder' && info.result === 'win') {
    const bot = c.bot!
    const nb = bot.tier < 12 ? botByTier(bot.tier + 1) : null
    if (!nb || !S.isLadderUnlocked(nb)) return null
    return { title: '__ladder__' + nb.name, icon: 'arrowRight', run: () => next({ kind: 'ladder', bot: nb.id }) }
  }
  return null
}
const botIdFor = () => {
  const t = S.getProfile().trophies
  const tiers = ['easy', 'apprentice', 'medium', 'jester', 'knight', 'tactician', 'shadow', 'baron', 'hard', 'frost', 'sphinx', 'queen']
  return tiers[Math.min(11, Math.max(0, Math.floor(t / 200)))]
}
const botByTier = (tier: number) => botById(['easy', 'apprentice', 'medium', 'jester', 'knight', 'tactician', 'shadow', 'baron', 'hard', 'frost', 'sphinx', 'queen'][tier - 1])

// MARK: Player bar

function PlayerBar({ c, side, compact = false, onDetail }: { c: GameController; side: Side; compact?: boolean; onDetail: (id: string) => void }) {
  const { t } = useI18n()
  const active = c.state.cur === side && !c.over
  const lost = c.capturedBy(side)
  const balance = c.materialBalance(side)
  const ring = side === c.perspective ? 'var(--blue)' : 'var(--red)'
  const p = S.getProfile()
  const deck = c.state.decks[side]
  const isHuman = side === c.human && (c.isBotMode || !!c.online)
  let portrait
  if (isHuman) {
    portrait = <span className="pb-ava" style={{ boxShadow: `0 0 0 ${active ? 2.5 : 1}px ${ring}` }}><PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={34} /></span>
  } else if (c.opponentCard && side !== c.human) {
    portrait = <span className="pb-ava" style={{ boxShadow: `0 0 0 ${active ? 2.5 : 1}px ${ring}` }}><PlayerAvatar avatar={c.opponentCard.avatar} frame={c.opponentCard.frame} size={34} /></span>
  } else {
    const skin = c.skin(side)?.id
    portrait = (
      <span className="pb-king" style={{ background: side === 'w' ? '#E8E6E3' : '#1B1A18', boxShadow: `0 0 0 ${active ? 2.5 : 1}px ${ring}` }}>
        {c.isBotMode && side !== c.human && !skin ? <Icon name="cpu" size={15} color={side === 'w' ? '#000' : '#fff'} />
          : <img src={pieceImage(side, c.isBotMode && side !== c.human ? 'k' : 'n', skin)} alt="" />}
      </span>
    )
  }
  const showStrip = side !== c.handOwner && deck
  const cardW = side === c.perspective ? 18 : compact ? 24 : 36
  return (
    <div className="pbar">
      {portrait}
      <div className="pb-main">
        <div className="row" style={{ gap: 6 }}>
          <b className="pb-name clip1">{c.name(side)}</b>
          {c.isOnlineBot && side !== c.human && <span className="training-tag">{c.botPlayerCard ? t('Bot') : t('Trainingsgegner')}</span>}
          {c.thinking && c.state.cur === side && <span className="thinking"><i /><i /><i /></span>}
          <span className="lost">{lost.map((pc, i) => <img key={i} src={pieceImage(pc.c as Side, pc.t, c.skin(pc.c as Side)?.id)} alt="" />)}</span>
          {balance > 0 && <span className="bal">+{balance}</span>}
        </div>
        {showStrip && (
          <div className="opp-strip">
            {c.state.ults[side] && (
              <>
                <UltimateCard ult={c.state.ults[side]} mana={c.state.mana[side]} compact usable={c.state.mana[side] >= ULTS_COST(c.state.ults[side])}
                  style={{ width: cardW }} onClick={() => onDetail(c.state.ults[side])} />
                <i className="vsep" style={{ height: cardW }} />
              </>
            )}
            {deck.hand.map((card, i) => {
              const cd = c.cooldown(card, side)
              const ready = cd === 0 && (CARDS[card as CardId] ? c.state.mana[side] >= costOf(card) : false)
              return (
                <button key={i} className="opp-card" onClick={() => onDetail(card)} style={{ width: cardW, filter: ready ? undefined : 'saturate(.35)', opacity: ready ? 1 : 0.7 }}>
                  <CardThumb art={`art-card-${card}`} width={cardW} border={tierColor(card)} />
                  <ManaDrop text={costOf(card)} size={15} style={{ left: -4, top: -5 }} />
                  {cd > 0 && <span className="cd"><Icon name="hourglass" size={8} /><b>{cd}</b></span>}
                </button>
              )
            })}
          </div>
        )}
      </div>
      {TIME_CONTROLS[c.timeControl].seconds > 0 && <Clock seconds={c.clocks[side]} active={active && !c.introActive} />}
      <span className="sr">{t('Mana')}: {c.state.mana[side]}</span>
    </div>
  )
}
import { cardCost, ultCost } from '../game/catalog'
const costOf = (card: string) => cardCost(card)
const ULTS_COST = (u: string) => ultCost(u)

function Clock({ seconds, active }: { seconds: number; active: boolean }) {
  const low = seconds < 20
  const text = seconds < 20
    ? `${Math.floor(seconds / 60)}:${(seconds % 60).toFixed(1).padStart(4, '0')}`
    : (() => { const s = Math.ceil(seconds); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}` })()
  return (
    <div className={`clock${active ? ' on' : ''}${active && low ? ' low' : ''}`}>
      {active && <Icon name="clock" size={12} />}
      <span className="mono">{text}</span>
    </div>
  )
}

// MARK: Hand

function Hand({ c, onDetail }: { c: GameController; onDetail: (id: string) => void }) {
  const { t } = useI18n()
  const owner = c.handOwner
  const mana = c.state.mana[owner]
  const ult = c.state.ults[owner]
  const deck = c.state.decks[owner]
  const bonusActive = c.state.bonus && c.state.cur === owner && !c.over
  const lastCard = [...c.entries].reverse().find(e => e.side === c.state.cur)?.card
  const peaceful = !!c.state.peace
  const anyTarget = !!c.tutorialCard || c.tutorialUlt
  const dimmed = (isTarget: boolean) => anyTarget && !isTarget && !c.pendingCard && !c.pendingUlt
  const press = (fn: () => void, id: string) => {
    let timer = 0
    let long = false
    return {
      onPointerDown: () => { long = false; timer = window.setTimeout(() => { long = true; onDetail(id) }, 380) },
      onPointerUp: () => window.clearTimeout(timer),
      onPointerLeave: () => window.clearTimeout(timer),
      onClick: () => { if (!long) fn() },
      onContextMenu: (e: React.MouseEvent) => { e.preventDefault(); onDetail(id) },
    }
  }
  return (
    <div className="hand">
      <ManaBar c={c} side={owner} mana={mana} highlight={c.tutorialHighlight} />
      <div className="hand-row" style={{ opacity: bonusActive ? 0.45 : 1 }}>
        {ult && (
          <>
            <div style={{ width: 66, flex: 'none', opacity: dimmed(c.tutorialUlt) ? 0.45 : 1 }} {...press(() => c.tapUltimate(), ult)}>
              <UltimateCard ult={ult} mana={mana} usable={c.canUseUlt(owner)} selected={c.pendingUlt && c.state.cur === owner}
                spotlight={c.tutorialUlt && !c.pendingUlt} />
            </div>
            <i className="vsep tall" />
          </>
        )}
        {deck?.hand.map((card, i) => (
          <div key={i} className="hand-slot" style={{ opacity: dimmed(c.tutorialCard === card) ? 0.45 : 1 }} {...press(() => c.tapCard(card), card)}>
            <CardView card={card} playable={c.isCardPlayable(card, owner)} selected={c.pendingCard === card && c.state.cur === owner}
              cooldown={c.cooldown(card, owner)} spotlight={c.tutorialCard === card && !c.pendingCard} />
          </div>
        ))}
        {Array.from({ length: Math.max(0, 4 - (deck?.hand.length ?? 0)) }, (_, i) => <div key={'e' + i} className="hand-slot"><div className="empty-slot" /></div>)}
      </div>
      {bonusActive && (
        <div className="bonus-banner pop-in">
          <Icon name={peaceful ? 'shieldHalf' : CARDS[lastCard as CardId]?.icon ?? 'sparkles'} size={14} />
          <div>
            <b>{t('{0} aktiv', peaceful ? t('Festung') : t(CARDS[lastCard as CardId]?.name ?? 'Bonus'))}</b>
            <span>{peaceful ? t('Noch ein Zug – ohne Schlagen und ohne Schach') : lastCard === 'shield' || lastCard === 'retreat' ? t('Noch ein Zug – mit einer anderen Figur') : t('Jetzt noch ein Figurzug')}</span>
          </div>
          <Icon name="walk" size={16} />
        </div>
      )}
    </div>
  )
}

function ManaBar({ c, side, mana, highlight }: { c: GameController; side: Side; mana: number; highlight: boolean }) {
  const { t } = useI18n()
  const ult = c.state.ults[side]
  const ready = !!ult && mana >= ultCost(ult)
  return (
    <div className={`manabar${highlight ? ' hl' : ''}`}>
      <ManaDrop text={mana} size={28} style={{ position: 'relative', left: 0, top: 0 }} />
      <div className="mana-cells">
        {Array.from({ length: 10 }, (_, i) => <i key={i} className={i < mana ? (ready ? 'on ready' : 'on') : ''} />)}
        <div className="mana-floats">
          {c.manaFloats.filter(f => f.side === side).map(f => <span key={f.id}>+{f.amount} {f.label}</span>)}
        </div>
      </div>
      <span className="income">{t('+{0}/Zug', c.income(side))}</span>
    </div>
  )
}

function HintSlot({ c }: { c: GameController }) {
  const { t } = useI18n()
  let bubble: { icon: string; text: string; tint: string } | null = null
  if (c.pendingUlt) {
    const u = c.state.ults[c.state.cur] as UltId
    bubble = { icon: ULTS[u].icon, text: ULTS[u].prompt ? t(ULTS[u].prompt) : `${t(ULTS[u].name)}: ${t(ULTS[u].text)}`, tint: 'var(--gold)' }
  } else if (c.pendingCard) {
    const info = CARDS[c.pendingCard as CardId]
    bubble = { icon: info.icon, text: `${t(info.name)}: ${info.prompt ? t(info.prompt) : t(info.text)}`, tint: 'var(--blue-light)' }
  } else if (c.hint) bubble = { icon: 'sparkles', text: c.hint, tint: 'var(--gold)' }
  return (
    <div className="hint-slot">
      {bubble && (
        <div className="hint-bubble pop-in" key={bubble.text} style={{ ['--tint' as string]: bubble.tint }}>
          <Icon name={bubble.icon} size={14} color={bubble.tint} />
          <span>{bubble.text}</span>
        </div>
      )}
    </div>
  )
}

// MARK: Tutorial quest bar

function QuestBar({ c }: { c: GameController }) {
  const { t } = useI18n()
  const coach = c.coach
  if (!coach) return <div className="quest" />
  return (
    <div className={`quest${coach.done ? ' done' : ''}${c.questNudgeText ? ' nudge' : ''}`} key={coach.step + (coach.done ? 'd' : '')}>
      <div className="quest-ico"><Icon name={coach.done ? 'check' : coach.icon} size={18} /></div>
      <div className="quest-main">
        <div className="row" style={{ gap: 6 }}>
          <span className="kicker" style={{ color: 'var(--gold)' }}>{coach.done ? t('AUFGABE ERFÜLLT') : t('AUFGABE {0} VON {1}', coach.step + 1, coach.total)}</span>
          <div className="quest-dots">{Array.from({ length: coach.total }, (_, i) => <i key={i} className={i < coach.step || (i === coach.step && coach.done) ? 'on' : i === coach.step ? 'cur' : ''} />)}</div>
          <div className="spacer" />
          {c.thinking && <span className="dim" style={{ fontSize: 11 }}>{t('{0} denkt …', t('Mila'))}</span>}
          <button className="ghost" style={{ padding: '2px 6px', fontSize: 11 }} onClick={() => c.skipTutorial()}>{t('Überspringen')}</button>
        </div>
        {coach.done ? (
          <div className="quest-praise pop-in">
            <b>{coach.praise}</b>
            {coach.rewards.map((r, i) => <span key={i} className={`reward-chip ${r.tint}`}><Icon name={r.icon} size={11} />{r.text}</span>)}
          </div>
        ) : (
          <>
            <b className="quest-title">{coach.title}</b>
            <span className="quest-text">{c.questNudgeText ?? coach.text}</span>
          </>
        )}
      </div>
    </div>
  )
}

function TutorialComplete({ xp, streak }: { xp: number; streak: number | null }) {
  // TutorialCompleteOverlay in the app: logo, what you learned, Rocky's pro tip, XP, flame, first chest.
  const { t } = useI18n()
  const chest = S.pendingChests()[0]
  return (
    <div className="overlay-center fade-in">
      <Confetti />
      <div className="tut-done pop-in">
        <div className="center" style={{ position: 'relative', height: 120 }}>
          <Rays size={260} />
          <img src={appLogo} alt="" className="tut-logo" />
        </div>
        <h2 className="title-l">{t('Erste Schlacht gewonnen!')}</h2>
        <p className="dim">{t('Du kennst jetzt Mana, Angriff, Verteidigung und Ultimates.')}</p>
        <div className="tut-tip"><Icon name="bolt" size={14} color="var(--gold)" /><span>{t('Profi-Tipp: Blitz kostet 2 Mana und vernichtet einen gegnerischen Bauern, der in deine Hälfte vorgerückt ist – auch einen gedeckten. Ideal gegen Vormarsch und Sturmlauf.')}</span></div>
        <b className="tut-xp num">{t('+{0} XP', xp)}</b>
        {streak !== null && <FlameLitRow streak={streak} />}
        {chest ? (<>
          <button className="chunky gold pulse-gold" onClick={() => { closeOverlay(); openChests(chest) }}><ChestView rarity={chest.rarity} size={30} />{t('Erste Truhe öffnen!')}</button>
          <button className="ghost" onClick={closeOverlay}>{t('Ab in die Arena')}</button>
        </>) : (
          <button className="chunky" onClick={closeOverlay}>{t('Ab in die Arena!')}</button>
        )}
      </div>
    </div>
  )
}

// MARK: Announcements

function Announcement({ a }: { a: { title: string; subtitle: string; icon: string; color: string } }) {
  return (
    <div className="announce">
      <div className="announce-in">
        <div className="announce-title" style={{ textShadow: `3px 3px 0 ${a.color}, 0 0 12px #0009` }}><Icon name={a.icon} size={26} />{a.title}</div>
        <span className="announce-sub" style={{ background: a.color }}>{a.subtitle}</span>
      </div>
    </div>
  )
}

/** The big moment in the middle of the screen (like FinisherTitle in the app): rays, a ribbon slamming in, sparks;
 *  a crown drops onto the ribbon for a win, the ribbon shakes for a loss. Mate/time/resign wait for the king to burst. */
function FinisherTitle({ look, headline, sub, delay = 0.78 }: { look: 'win' | 'loss' | 'draw'; headline: string; sub: string; delay?: number }) {
  return (
    <div className={`fin ${look}`} style={{ ['--d' as string]: `${delay}s` }} aria-live="polite">
      <i className="fin-dim" />
      <i className="fin-rays" />
      <i className="fin-wave" />
      {look !== 'loss' && <span className="fin-sparks" aria-hidden="true">
        {Array.from({ length: 16 }, (_, i) => {
          const a = (i / 16) * Math.PI * 2 + (i % 2) * 0.2, r = 110 + (i % 3) * 38
          return <i key={i} style={{ ['--tx' as string]: `${Math.cos(a) * r}px`, ['--ty' as string]: `${Math.sin(a) * r}px`, ['--rot' as string]: `${i * 47}deg` }}><Icon name="star" size={10 + (i % 3) * 3} /></i>
        })}
      </span>}
      <div className="fin-card">
        <div className="fin-ribbon">
          {look === 'win' && <span className="fin-crown"><Icon name="crown" size={34} /></span>}
          <div className={`ribbon ${look === 'loss' ? 'lose' : look}`}>{headline}</div>
        </div>
        <b className="finisher-sub">{sub}</b>
      </div>
    </div>
  )
}

function CastBanner({ title, art, ult, caster }: { title: string; art: string; ult: boolean; caster: string }) {
  return (
    <div className="cast">
      <div className={`cast-card${ult ? ' ult' : ''}`}><img src={cardArtUrl(art)} alt="" /></div>
      <span className="cast-label">{caster}: {title}</span>
    </div>
  )
}
import { cardArt as cardArtUrl } from '../art'

function PromotionPicker({ side, skin, onPick, onCancel }: { side: Side; skin?: string; onPick: (p: string) => void; onCancel: () => void }) {
  const { t } = useI18n()
  const options: Array<[string, string, string]> = [['q', 'Dame', 'Die Stärkste'], ['r', 'Turm', 'Linien'], ['b', 'Läufer', 'Diagonalen'], ['n', 'Springer', 'Sprünge']]
  return (
    <div className="overlay-center fade-in" onClick={onCancel}>
      <div className="promo pop-in" onClick={e => e.stopPropagation()}>
        <h3 className="title-m">{t('Umwandlung')}</h3>
        <span className="dim">{t('Wähle die neue Figur')}</span>
        <div className="promo-grid">
          {options.map(([id, name, sub]) => (
            <button key={id} className="promo-btn press" onClick={() => onPick(id)} aria-label={t('Umwandeln in {0}', t(name))}>
              <img src={pieceImage(side ?? 'w', id, skin)} alt="" />
              <b>{t(name)}</b>
              <span>{t(sub)}</span>
            </button>
          ))}
        </div>
        <button className="ghost" onClick={onCancel}>{t('Abbrechen')}</button>
      </div>
    </div>
  )
}

// MARK: Versus intro

function VersusIntro({ c }: { c: GameController }) {
  const { t } = useI18n()
  useEffect(() => { const id = window.setTimeout(() => c.finishIntro(), 2600); return () => window.clearTimeout(id) }, [c])
  const p = S.getProfile()
  const opp: Side = c.human === 'w' ? 'b' : 'w'
  const bot = c.bot
  const arena = arenaFor(p.trophies).n
  const card = c.opponentCard
  const oppDeck = c.state.decks[opp]?.hand ?? []
  const oppUlt = c.state.ults[opp]
  return (
    <div className="versus fade-in" onClick={() => c.finishIntro()} style={{ ['--arena' as string]: ARENA_PALETTE[arena][0] }}>
      <div className="vs-half top slide-in-top" style={{ ['--tint' as string]: bot?.color ?? 'var(--red)' }}>
        {card ? <PlayerAvatar avatar={card.avatar} frame={card.frame} size={96} /> : bot ? <BotPortrait id={bot.id} size={96} /> : null}
        <b className="vs-name">{card ? card.name : t(bot?.name ?? '')}</b>
        <span className="vs-sub">{card ? <><Icon name="trophy" size={12} color="var(--gold)" /> {card.trophies}</> : bot ? t(bot.title) : ''}</span>
        {c.isOnlineBot && <span className="training-tag lg">{c.botPlayerCard ? t('Bot') : t('Trainingsgegner')}</span>}
        {c.isFriendly && <span className="friendly-tag"><Icon name="heart" size={11} /> {t('Freundschaftsspiel')}</span>}
        <div className="vs-deck">
          {oppUlt && <CardThumb art={`art-ult-${oppUlt}`} width={34} border="var(--gold)" />}
          {oppDeck.map((card, i) => <CardThumb key={i} art={`art-card-${card}`} width={34} border={tierColor(card)} />)}
        </div>
      </div>
      <div className="vs-badge pop-in">{t('VS')}</div>
      <div className="vs-half bottom slide-in-bottom" style={{ ['--tint' as string]: 'var(--blue)' }}>
        <PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={96} />
        <b className="vs-name">{c.name(c.human)}</b>
        <span className="vs-sub"><Icon name="trophy" size={12} color="var(--gold)" /> {p.trophies}</span>
      </div>
      <span className="vs-skip">{t('Duell gegen {0}. Tippen zum Überspringen.', card ? card.name : t(bot?.name ?? ''))}</span>
    </div>
  )
}

export function BotPortrait({ id, size = 64, style }: { id: string; size?: number; style?: React.CSSProperties }) {
  const bot = botById(id)
  return (
    <span className="bot-portrait" style={{ width: size, height: size, background: `radial-gradient(circle at 50% 35%, ${bot.color}, ${bot.color}55 70%)`, boxShadow: `0 0 ${size * 0.25}px ${bot.color}88`, ...style }}>
      <img src={pieceImage('b', 'k', bot.id)} alt="" style={{ width: '72%', height: '72%' }} />
      <span className="bot-ico" style={{ background: bot.color }}><Icon name={bot.icon} size={size * 0.18} color="#fff" /></span>
    </span>
  )
}

// MARK: Game over

function GameOver({ info, c, onExit, onRematch, onNext }: { info: GameOverInfo; c: GameController; onExit: () => void; onRematch?: () => void; onNext: { title: string; icon: string; run: () => void } | null }) {
  const { t } = useI18n()
  const won = info.result === 'win' || (info.result === null && info.hasWinner)
  const lost = info.result === 'loss'
  const headline = info.result === 'win' ? t('SIEG!') : info.result === 'loss' ? t('NIEDERLAGE') : info.result === 'draw' ? t('REMIS') : info.hasWinner ? t('SIEG!') : t('PARTIE VORBEI')
  const [shown, setShown] = useState(0)
  useEffect(() => {
    if (!info.trophyDelta) return
    let raf = 0
    const start = performance.now()
    const step = (now: number) => {
      const k = Math.min(1, (now - start) / 900)
      setShown(Math.round(info.trophyDelta * (1 - Math.pow(1 - k, 3))))
      if (k < 1) raf = requestAnimationFrame(step)
    }
    raf = requestAnimationFrame(step)
    return () => cancelAnimationFrame(raf)
  }, [info.trophyDelta])
  const openEarned = () => {
    const ids = new Set(info.chests.map(ch => ch.id))
    const waiting = S.pendingChests().filter(ch => ids.has(ch.id))
    if (waiting[0]) openChests(waiting[0], ids)
  }
  const nextTitle = onNext?.title.startsWith('__ladder__') ? t('Gegen {0} kämpfen', t(onNext.title.slice(10))) : onNext ? t(onNext.title) : ''
  const p = S.getProfile()
  return (
    <div className="gameover fade-in">
      {won && <Confetti />}
      <div className={`go-card pop-in ${won ? 'win' : lost ? 'lose' : 'draw'}`}>
        <div className="go-head">
          {won && <Rays size={360} color="#F2C14E" style={{ top: -110 }} />}
          <div className={`ribbon big ${won ? 'win' : lost ? 'lose' : 'draw'}`}>{headline}</div>
          <div className="go-portraits">
            <PlayerAvatar avatar={S.activeAvatar(p)} frame={S.activeFrame(p)} size={64} />
            {info.opponent ? <BotPortrait id={info.opponent.id} size={64} style={{ filter: won ? 'grayscale(.6) brightness(.7)' : undefined }} />
              : info.disguise ? <PlayerAvatar avatar={info.disguise.avatar} frame={info.disguise.frame} size={64} /> : null}
          </div>
          <b className="go-title">{info.title}</b>
          <span className="dim">{info.subtitle}</span>
        </div>
        {info.rated && info.result && (
          <div className="go-trophies">
            <Icon name="trophy" size={26} color="var(--gold)" />
            <b className={`num ${info.trophyDelta > 0 ? 'up' : info.trophyDelta < 0 ? 'down' : ''}`}>{info.trophyDelta > 0 ? '+' : ''}{shown}</b>
            <span className="dim">{t('Trophäen')}</span>
          </div>
        )}
        <div className="go-stats">
          <div><b>{info.moveCount}</b><span>{t('Züge')}</span></div>
          <div><b>{info.cardsPlayed}</b><span>{t('Karten')}</span></div>
          {info.ladderXP !== null && <div><b>+{info.ladderXP}</b><span>{t('Erfahrung')}</span></div>}
        </div>
        {info.streakLit !== null && <FlameLitRow streak={info.streakLit} />}
        <div className="go-rewards">
          {info.ladderUnlocked && <div className="go-reward"><Icon name="stairs" size={16} color="var(--gold)" />{t('{0} ist freigeschaltet!', info.ladderUnlocked)}</div>}
          {info.skinUnlocked && <div className="go-reward"><img src={pieceImage('w', 'n', info.skinUnlocked.id)} alt="" style={{ width: 22, height: 22 }} />{t('Neues Figurenset: {0}!', t(info.skinUnlocked.skin))}</div>}
          {info.roadReady !== null && (() => {
            const step = ROAD.find(x => x.trophies === info.roadReady)
            return (
              <button className="go-road" onClick={() => { onExit(); setTab('arena') }}>
                <Icon name="trophy" size={16} />
                <span className="grow"><b>{t('Trophäenpfad: {0} erreicht!', info.roadReady)}</b>
                  {step && <small>{t('{0} wartet – abholen', roadTitle(step.reward, t))}</small>}</span>
                <Icon name="chevronRight" size={14} />
              </button>
            )
          })()}
          {info.winChestsUsedUp && <div className="go-reward dim"><Icon name="box" size={16} />{t('Die drei Siegtruhen für heute sind vergeben – morgen gibt es neue.')}</div>}
          {lost && <div className="go-reward dim">{t('Kopf hoch – jede Partie macht dich stärker.')}</div>}
        </div>
        {info.chests.length > 0 && S.pendingChests().some(ch => info.chests.some(x => x.id === ch.id)) && (
          <button className="chunky gold pulse-gold" onClick={openEarned}>
            <ChestView rarity={info.chests[0].rarity} size={30} />
            {info.chests.length === 1 ? t('{0} öffnen', t(CHEST_NAME(info.chests[0].rarity))) : t('{0} Truhen erhalten!', info.chests.length)}
          </button>
        )}
        <div className="go-buttons">
          {onNext && <button className="chunky" onClick={onNext.run}><Icon name={onNext.icon} size={18} />{nextTitle}</button>}
          <div className="row">
            {onRematch && <button className="chunky gray sm" onClick={onRematch}><Icon name="arrowCounter" size={16} />{lost ? t('Nochmal versuchen') : t('Revanche')}</button>}
            <button className="chunky gray sm" onClick={onExit}>{t('Zum Menü')}</button>
          </div>
        </div>
      </div>
    </div>
  )
}
import { CHEST } from '../game/catalog'
const CHEST_NAME = (r: number) => CHEST[r].name

export { avatarImage, openOverlay }
