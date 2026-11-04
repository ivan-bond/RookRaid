import { useEffect, useState } from 'react'
import { knightAvatar, pieceImage } from './art'
import { cardArt, CARD_NAME, E } from './engine'
import { useI18n } from './i18n'
import { Match } from './match'
import { currentAccount } from './profile'

function clockText(ms: number) {
  const total = Math.ceil(ms / 1000)
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`
}

export function MatchView({ match, onExit }: { match: Match; onExit: () => void }) {
  const { t } = useI18n()
  const version = useState(0)[0]
  const [, setTick] = useState(0)
  useEffect(() => {
    match.start()
    const unsub = match.subscribe(() => setTick(n => n + 1))
    const timer = window.setInterval(() => match.tick(), 250)
    return () => { unsub(); match.stop(); window.clearInterval(timer) }
  }, [match])
  void version

  const bottom = match.orientation()
  const top: 'w' | 'b' = bottom === 'w' ? 'b' : 'w'
  const files = bottom === 'w' ? [0, 1, 2, 3, 4, 5, 6, 7] : [7, 6, 5, 4, 3, 2, 1, 0]
  const ranks = bottom === 'w' ? [0, 1, 2, 3, 4, 5, 6, 7] : [7, 6, 5, 4, 3, 2, 1, 0]
  const zones = match.state.controlMap()
  const targets = new Set(match.targets())
  const last = match.state.last
  const ult = match.state.ults[bottom]
  const ultReady = match.myTurn() && match.state.canUseUlt(bottom) && !match.state.bonus
  const intro = match.introLeft()
  const status = match.state.status()

  function sideName(side: 'w' | 'b') {
    if (match.kind !== 'hotseat' && side !== match.human) return match.opponentName || t('Computer')
    if (match.kind !== 'hotseat') return currentAccount().name || t('Gast')
    return side === 'w' ? t('Weiß') : t('Schwarz')
  }

  function mana(side: 'w' | 'b') {
    const value = match.state.mana[side]
    const ready = match.state.ults[side] === 'fortress' ? 6 : 8
    return (
      <div className="mana" aria-label={`${value}`}>
        {Array.from({ length: 10 }, (_, i) => (
          <i key={i} className={i < value ? (value >= ready ? 'pip on ready' : 'pip on') : 'pip'} />
        ))}
      </div>
    )
  }

  function hand(side: 'w' | 'b', opponent: boolean) {
    return (
      <div className={opponent ? 'hand opp' : 'hand'}>
        {match.state.decks[side].hand.map(id => (
          <button key={id} className={match.card === id ? 'art-card picked' : 'art-card'} disabled={opponent || !match.myTurn() || match.state.bonus || !match.state.canPlay(id, side)}
            onClick={() => match.clickCard(id)}>
            {cardArt(id) && <img src={cardArt(id)} alt="" />}
            <small>{t(CARD_NAME[id] ?? id)} · {E.COST[id]}</small>
          </button>
        ))}
      </div>
    )
  }

  function bar(side: 'w' | 'b') {
    const mine = side === bottom
    const seconds = match.remaining(side)
    const active = match.state.cur === side && !match.overTitle
    const clockClass = !match.clocks ? '' : seconds < 20_000 ? 'clock low' : active ? 'clock live' : 'clock'
    return (
      <div className="bar">
        {mine && knightAvatar
          ? <img className="portrait" src={knightAvatar} alt="" />
          : <img className="portrait foe" src={pieceImage(side, 'k')} alt="" />}
        <div>
          <strong>{sideName(side)}</strong>
          {mana(side)}
        </div>
        {match.clocks && <span className={clockClass}>{clockText(seconds)}</span>}
      </div>
    )
  }

  const board = (
    <div className="board">
      {ranks.flatMap(rank => files.map(file => {
        const index = rank * 8 + file
        const piece = match.state.b[index]
        const light = (rank + file) % 2 === 1
        const zone = zones[index] === bottom ? 'mine' : zones[index] === top ? 'foe' : ''
        const classes = [
          'sq', light ? 'light' : 'dark', zone,
          targets.has(index) ? 'target' : '',
          match.selected === index ? 'selected' : '',
          last && (last.f === index || last.t === index) ? 'moved' : '',
          match.burst === index ? 'burst' : '',
        ].filter(Boolean).join(' ')
        return (
          <button key={index} className={classes} onClick={() => match.clickSquare(index)}>
            {piece && <img src={pieceImage(piece.c, piece.t)} alt="" />}
            {targets.has(index) && <i className={piece ? 'capture' : 'dot'} />}
          </button>
        )
      }))}
    </div>
  )

  const banner = (
    <div className="banner">
      {match.note || (intro > 0 ? t('Bereit in {0}', intro)
        : match.thinking ? t('Gegner ist am Zug')
        : match.state.bonus && match.myTurn() ? t('Bonuszug – jetzt ein Figurzug')
        : status === 'check' && match.myTurn() ? t('Schach')
        : match.myTurn() ? t('Dein Zug') : t('Gegner ist am Zug'))}
    </div>
  )

  return (
    <div className="match">
      <div className="play-top">
        <button className="ghost" onClick={onExit}>{t('Zurück')}</button>
        <strong>{t('Partie')}</strong>
        <button className="ghost" onClick={() => match.resign()}>{t('Aufgeben')}</button>
      </div>
      <div className="match-body">
        <div className="board-wrap">{board}</div>
        <div className="match-side">
          {bar(top)}
          {hand(top, true)}
          <div className="grow" />
          {banner}
          <div className="my-hand">
            <button className={match.aiming === 'ult' ? 'ult on' : 'ult'} disabled={!ultReady} onClick={() => match.clickUlt()}>
              {cardArt(ult) && <img src={cardArt(ult)} alt="" />}
              <small>{t(CARD_NAME[ult] ?? ult)} · {E.ultCost(ult)}</small>
            </button>
            {hand(bottom, false)}
          </div>
          {bar(bottom)}
          {match.kind === 'online' && !match.onlineBot && <button className="ghost" onClick={() => { void match.sendDraw() }}>{t('Remis anbieten')}</button>}
          {match.drawFrom && match.drawFrom !== match.human && (
            <div className="banner">
              {t('Remisangebot')}
              <div className="row">
                <button className="chunky" onClick={() => { void match.replyDraw(true) }}>{t('Annehmen')}</button>
                <button className="chunky blue" onClick={() => { void match.replyDraw(false) }}>{t('Ablehnen')}</button>
              </div>
            </div>
          )}
        </div>
      </div>
      {match.askResign && (
        <div className="overlay">
          <div className="sheet">
            <h2>{t('Wirklich aufgeben?')}</h2>
            <button className="chunky" onClick={() => match.resign()}>{t('Ja')}</button>
            <button className="chunky blue" onClick={() => match.dismissResign()}>{t('Nein')}</button>
          </div>
        </div>
      )}
      {match.promo && (
        <div className="overlay">
          <div className="sheet">
            <h2>{t('Zur Figur')}</h2>
            <div className="row">
              {[['q', 'Dame'], ['r', 'Turm'], ['b', 'Läufer'], ['n', 'Springer']].map(([id, name]) => (
                <button key={id} className="chunky blue" onClick={() => match.choosePromo(id)}>{t(name)}</button>
              ))}
            </div>
          </div>
        </div>
      )}
      {match.overTitle && (
        <div className="overlay">
          <div className="sheet">
            <h2>{match.overTitle}</h2>
            <p>{match.overDetail}</p>
            <button className="chunky" onClick={onExit}>{t('Weiter')}</button>
          </div>
        </div>
      )}
    </div>
  )
}
