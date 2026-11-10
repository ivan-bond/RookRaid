// CollectionViews.swift (tab "Deck") with Rocky's deck workshop (DeckTour.swift), presets and the ultimate picker.
import { useEffect, useState } from 'react'
import { rockyFace } from '../art'
import { ARENAS, CARDS, CARD_IDS, DECK_SIZE, PRESETS, ROLES, TIERS, ULTS, ULT_IDS, cardCost, ultCost, type CardId, type Role } from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeSheet, openOverlay, openSheet, run } from '../nav'
import { Icon } from '../ui/Icon'
import { CardThumb, CardView, Confetti, Dialog, ManaDrop, Sheet, ShardIcon, UltimateCard, tierColor, useToast } from '../ui/kit'
import { CardDetail } from './Rules'
import { ShardPill } from './Home'
import { LAB_ITEMS } from './Lab'
import { DeckCheck, RockyTourPanel, TOUR_REWARD, useDeckTour } from './DeckTour'

export function deckCheck(deck: CardId[]) {
  const c = new DeckCheck(deck)
  return { avg: c.average, mix: c.mixOK, cheap: c.startOK, stars: c.stars, bonus: c.bonusCount }
}

export function DeckScreen() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [toast, showToast] = useToast()
  const [filter, setFilter] = useState<Role | null>(null)
  const [incoming, setIncoming] = useState<CardId | null>(null)
  const [detail, setDetail] = useState<string | null>(null)
  const [buy, setBuy] = useState<CardId | null>(null)
  const [nudged, setNudged] = useState<CardId | null>(null)
  const deck = S.activeDeck(p)
  const ult = S.activeUltimate(p)
  const check = deckCheck(deck)
  const tour = useDeckTour(deck)
  const step = tour.step
  const labDone = LAB_ITEMS.filter(i => p.labDone.includes(i.key)).length

  useEffect(() => () => S.markAllSeen(), [])
  useEffect(() => { if (S.needsDeckTour(p) && !tour.active) tour.start(true) }, [])
  useEffect(() => {
    if (step !== 'done' || !tour.firstRun || S.getProfile().deckTourDone) return
    S.earnShards(TOUR_REWARD)
    S.update(x => { x.deckTourDone = true })
  }, [step])

  const tapCollection = (c: CardId) => {
    if (!S.isCardUnlocked(c)) {
      if (S.level() < TIERS[CARDS[c].tier].gate) { showToast(t('Karten der Stufe „{0}“ gibt es ab Level {1}.', t(TIERS[CARDS[c].tier].name), TIERS[CARDS[c].tier].gate)); return }
      setBuy(c); return
    }
    if (deck.includes(c)) {
      haptic('invalid'); setNudged(c); window.setTimeout(() => setNudged(null), 600)
      showToast(t('{0} ist schon in deinem Deck.', t(CARDS[c].name))); return
    }
    if (deck.length < DECK_SIZE) {
      S.addToDeck(c); sound('card_whoosh'); haptic('card')
      const left = DECK_SIZE - deck.length - 1
      if (!tour.active) showToast(left === 0 ? t('Dein Deck ist komplett!') : left === 1 ? t('{0} ist im Deck – noch 1 Platz frei.', t(CARDS[c].name)) : t('{0} ist im Deck – noch {1} Plätze frei.', t(CARDS[c].name), left))
      return
    }
    setIncoming(incoming === c ? null : c)
    showToast(t('Dein Deck ist voll – welche Karte soll raus? Tippe sie oben an.'))
  }
  const tapSlot = (i: number) => {
    const c = deck[i]
    if (incoming) {
      const next = [...deck]
      next[i] = incoming
      S.setDeck(next)
      if (!tour.active) showToast(t('{0} statt {1}.', t(CARDS[incoming].name), t(CARDS[c].name)))
      setIncoming(null); sound('card_whoosh')
      return
    }
    if (c) { S.removeFromDeck(c); if (!tour.active) showToast(t('{0} aus dem Deck genommen.', t(CARDS[c].name))); sound('select') }
  }
  const test = () => {
    if (!S.deckIsFull()) { showToast(t('Zum Spielen braucht dein Deck 4 Karten.')); return }
    run('startPractice')
  }

  const cards = CARD_IDS.filter(c => !filter || CARDS[c].role === filter)
    .sort((a, b) => (S.isCardUnlocked(b) ? 1 : 0) - (S.isCardUnlocked(a) ? 1 : 0) || cardCost(a) - cardCost(b))

  return (
    <div className="page">
      <div className="page-glow" style={{ background: 'linear-gradient(#1C3F8680, transparent)' }} />
      <div className={`page-inner deck-page${tour.active ? ' touring' : ''}`}>
        <div className="hdr">
          <span style={{ transform: 'rotate(-10deg)', display: 'inline-flex' }}><Icon name="stack" size={24} color="var(--blue-light)" /></span>
          <h1 className="title-xl">{t('Deck')}</h1>
          <button className="rocky-btn press" onClick={() => tour.start(false)} aria-label={t('Rocky erklärt dir das Deck')}><img src={rockyFace} alt="" /></button>
          <span className="spacer" />
          <ShardPill />
        </div>
        <div className="deck-layout">
          <div className="deck-sticky">
            <div className="deck-box">
              <div className="row" style={{ gap: 8 }}>
                <span className="kicker" style={{ color: 'var(--gold)' }}>{t('DEIN KAMPFDECK')}</span>
                <span className="spacer" />
                <span className="capsule chip num">{t('Ø {0} Mana', check.avg.toFixed(1))}</span>
                <span className="capsule chip">{deck.length}/{DECK_SIZE}</span>
              </div>
              <div className="deck-slots">
                <div style={{ width: '17%', flex: 'none' }} className={step === 'ultimate' || step === 'ultimates' ? 'tour-spot' : ''} onClick={() => openSheet('ultimates')}>
                  <UltimateCard ult={ult} mana={99} />
                </div>
                <i className="vsep tall" />
                {Array.from({ length: DECK_SIZE }, (_, i) => {
                  const c = deck[i]
                  return (
                    <div key={i} className={`deck-slot${incoming ? ' swap' : ''}${c && nudged === c ? ' jiggle' : ''}${step === 'hello' || step === 'check' || step === 'recheck' ? ' tour-spot' : ''}${c && c === tour.suggestedOut ? ' tour-out' : ''}`} onClick={() => tapSlot(i)}>
                      {c ? <CardView card={c} /> : <div className="empty-slot plus"><Icon name="plus" size={18} /><span>{t('Platz {0}', i + 1)}</span></div>}
                      {c && incoming && <span className="swap-badge"><Icon name="swap" size={12} /></span>}
                    </div>
                  )
                })}
              </div>
              {deck.length < DECK_SIZE && (
                <div className="deck-banner">{deck.length === 0 ? t('Stell dein erstes Deck zusammen: Tippe unten 4 Karten an – erst dann kannst du kämpfen.')
                  : DECK_SIZE - deck.length === 1 ? t('Noch 1 Karte – dann kannst du kämpfen.') : t('Noch {0} Karten – dann kannst du kämpfen.', DECK_SIZE - deck.length)}</div>
              )}
              {incoming && <div className="deck-banner gold">{t('Jetzt unten die Karte antippen, die an diesen Platz soll.').replace(t('unten'), t('oben'))} <button className="ghost" onClick={() => setIncoming(null)}>{t('Abbrechen')}</button></div>}
              <div className="deck-buttons">
                <button className="deck-btn" onClick={() => openSheet('presets')}><Icon name="stack3d" size={13} />{t('Vorlagen')}</button>
                <button className="deck-btn school" onClick={() => openOverlay({ kind: 'lab', key: LAB_ITEMS.find(i => !p.labDone.includes(i.key))?.key ?? LAB_ITEMS[0].key })}>
                  <Icon name="graduation" size={13} />{t('Schule')}<span className="num" style={{ opacity: 0.7, fontSize: 10 }}>{labDone}/{LAB_ITEMS.length}</span>
                </button>
                <button className="deck-btn" onClick={test}><Icon name="play" size={13} />{t('Testen')}</button>
              </div>
            </div>
          </div>
          <div className="collection">
            <div className="row" style={{ gap: 8 }}>
              <span className="section-h">{t('Sammlung')}</span>
              <span className="muted num" style={{ fontSize: 12 }}>{S.unlockedCards(p).length}/{CARD_IDS.length}</span>
            </div>
            <div className="role-filter">
              <button className={filter === null ? 'on' : ''} onClick={() => setFilter(null)}>{t('Alle')}</button>
              {(Object.keys(ROLES) as Role[]).map(r => (
                <button key={r} className={filter === r ? 'on' : ''} onClick={() => setFilter(r)} style={{ ['--tint' as string]: ROLES[r].color }}>
                  <Icon name={ROLES[r].icon} size={11} color={ROLES[r].color} />{t(ROLES[r].name)}
                </button>
              ))}
            </div>
            <div className="coll-grid">
              {cards.map(c => {
                const unlocked = S.isCardUnlocked(c, p)
                const inDeck = deck.includes(c)
                const price = TIERS[CARDS[c].tier].price
                return (
                  <div key={c} className={`coll-card${inDeck ? ' in' : ''}${!unlocked ? ' locked' : ''}${incoming === c ? ' incoming' : ''}${(step === 'pick' || step === 'fill') && unlocked && !inDeck ? ' glow' : ''}${tour.suggestedIn === c ? ' tour-in' : ''}`}>
                    <div onClick={() => tapCollection(c)} onContextMenu={e => { e.preventDefault(); setDetail(c) }}>
                      <CardView card={c} showName={false} />
                    </div>
                    <button className="coll-info" onClick={() => setDetail(c)}>
                      <b className="clip1">{t(CARDS[c].name)}</b>
                      <span className="clip1">{t(CARDS[c].short)}</span>
                    </button>
                    {tour.suggestedIn === c && <span className="tour-hand"><Icon name="handDown" size={22} /></span>}
                    {inDeck && <span className="in-deck">{t('IM DECK')}</span>}
                    {S.isNewCard(c, p) && <span className="new-sticker">{t('NEU')}</span>}
                    {!unlocked && (
                      <span className="lock-tag">
                        <Icon name="lock" size={11} />
                        {S.level() >= TIERS[CARDS[c].tier].gate ? <><ShardIcon size={11} />{price}</> : t('ab Level {0}', TIERS[CARDS[c].tier].gate)}
                      </span>
                    )}
                  </div>
                )
              })}
            </div>
            <p className="muted" style={{ fontSize: 12, textAlign: 'center' }}>{t('Lange drücken zeigt eine Karte groß mit allen Details.')}</p>
          </div>
        </div>
      </div>
      {toast}
      {detail && <CardDetail id={detail} onClose={() => setDetail(null)} allowLab />}
      {buy && (
        <Dialog title={t('{0} freischalten?', t(CARDS[buy].name))} message={`${t(TIERS[CARDS[buy].tier].name)} · ${t(CARDS[buy].text)}`} onClose={() => setBuy(null)}
          actions={S.getProfile().shards >= TIERS[CARDS[buy].tier].price
            ? [{ label: t('Für {0} Splitter freischalten', TIERS[CARDS[buy].tier].price), bold: true, onClick: () => { if (S.buyCard(buy)) { sound('reward_big'); haptic('chestBig'); showToast(t('{0} ist freigeschaltet!', t(CARDS[buy].name))) } } }, { label: t('Abbrechen') }]
            : [{ label: t('Dir fehlen noch {0} Splitter.', TIERS[CARDS[buy].tier].price - S.getProfile().shards) }, { label: t('Splitter-Laden'), onClick: () => openSheet('shop') }]} />
      )}
      {tour.active && step !== 'done' && (
        <RockyTourPanel tour={tour} deck={deck} onBattle={() => { tour.finish(); run('quickBattle') }}
          onEquip={u => { S.setSettings(x => { x.ultimate = u }); sound('select') }} />
      )}
      {step === 'done' && <TourCelebration first={tour.firstRun} deck={deck} onClose={() => tour.finish()} />}
    </div>
  )
}

function TourCelebration({ first, deck, onClose }: { first: boolean; deck: CardId[]; onClose: () => void }) {
  const { t } = useI18n()
  return (
    <div className="overlay-center fade-in">
      <Confetti />
      <div className="tut-done pop-in">
        <img src={rockyFace} alt="" style={{ width: 110, height: 110, margin: '0 auto' }} className="rocky-face bob" />
        <b className="title-l">{t('Dein Deck ist kampfbereit!')}</b>
        <div className="fan" style={{ justifyContent: 'center' }}>
          {[`art-ult-${S.activeUltimate()}`, ...deck.map(c => `art-card-${c}`)].map((art, i, all) => {
            const k = i - (all.length - 1) / 2
            return <span key={art} className="fan-card fan-in" style={{ transform: `translateY(${k * k * 3}px) rotate(${k * 9}deg)`, animationDelay: `${i * 0.08}s` }}><CardThumb art={art} width={58} border={i === 0 ? 'var(--gold)' : tierColor(deck[i - 1])} /></span>
          })}
        </div>
        <p className="dim" style={{ margin: 0 }}>{t('Starke Arbeit! Denk dran: Ein gutes Deck mischt Angriff, Kontrolle und Verteidigung – mit ein, zwei günstigen Karten für den Start.')}</p>
        {first && <span className="capsule chip gold" style={{ alignSelf: 'center' }}><ShardIcon size={12} />{t('+{0} Splitter', TOUR_REWARD)}</span>}
        <button className="chunky gold" onClick={() => { onClose(); run('quickBattle') }}>{t('Ab in den Kampf!')}</button>
        <button className="ghost" onClick={onClose}>{t('Fertig')}</button>
      </div>
    </div>
  )
}

// MARK: Sheets

export function PresetSheet() {
  const { t } = useI18n()
  const p = S.useProfile()
  const [toast, showToast] = useToast()
  return (
    <Sheet title={t('Vorlagen')} onClose={closeSheet} wide>
      <p className="dim" style={{ marginTop: 0 }}>{t('Ein Tipp übernimmt Karten und Ultimate. Danach kannst du jede Karte einzeln tauschen.')}</p>
      <div className="preset-grid">
        {PRESETS.map(pr => {
          const ok = S.isPresetUnlocked(pr)
          const active = pr.cards.every(c => S.activeDeck(p).includes(c)) && S.activeUltimate(p) === pr.ultimate
          const missing = [...pr.cards.filter(c => !S.isCardUnlocked(c)).map(c => t(CARDS[c].name)), ...(S.isUltUnlocked(pr.ultimate) ? [] : [t(ULTS[pr.ultimate].name)])]
          return (
            <button key={pr.id} className={`preset${active ? ' active' : ''}${ok ? '' : ' locked'}`}
              onClick={() => { if (ok) { S.applyPreset(pr); sound('card_whoosh'); showToast(t('{0} übernommen.', t(pr.name))) } else showToast(t('Fehlt noch: ') + missing.join(', ')) }}>
              <div className="row"><Icon name={pr.icon} size={18} color="var(--gold)" /><b className="r grow" style={{ fontSize: 16 }}>{t(pr.name)}</b>{active ? <span className="capsule chip gold">{t('Aktiv')}</span> : !ok && <Icon name="lock" size={14} />}</div>
              <div className="preset-cards">
                <div style={{ width: 46 }}><UltimateCard ult={pr.ultimate} mana={99} compact /></div>
                {pr.cards.map(c => <div key={c} style={{ width: 42, opacity: S.isCardUnlocked(c) ? 1 : 0.4 }}><CardView card={c} compact showName={false} /></div>)}
              </div>
              <span className="dim" style={{ fontSize: 12, textAlign: 'left' }}>{t(pr.strategy)}</span>
            </button>
          )
        })}
      </div>
      {toast}
    </Sheet>
  )
}

export function UltimateSheet() {
  const { t } = useI18n()
  const p = S.useProfile()
  const [toast, showToast] = useToast()
  return (
    <Sheet title={t('Ultimate')} onClose={closeSheet} wide>
      <p className="dim" style={{ marginTop: 0 }}>{t('Einsetzbar ab {0} Mana (Festung schon ab {1}). Dein Gegner sieht deine Wahl.', 8, 6)}</p>
      <div className="ult-grid">
        {ULT_IDS.map(u => {
          const ok = S.isUltUnlocked(u, p)
          const on = S.activeUltimate(p) === u
          return (
            <div key={u} className={`ult-pick${on ? ' on' : ''}${ok ? '' : ' locked'}`}>
              <div style={{ width: 96 }}><UltimateCard ult={u} mana={ok ? 99 : 0} /></div>
              <div className="col grow" style={{ gap: 4 }}>
                <div className="row"><b className="r" style={{ fontSize: 17 }}>{t(ULTS[u].name)}</b><span className="capsule chip gold"><ManaDrop text={ultCost(u)} size={14} style={{ position: 'relative', left: 0, top: 0 }} />{t(ULTS[u].style)}</span></div>
                <span className="dim" style={{ fontSize: 13 }}>{t(ULTS[u].text)}</span>
                <div className="ult-facts">
                  <span><Icon name={u === 'fortress' ? 'walk' : 'hourglass'} size={12} />{u === 'fortress' ? t('Danach noch ein Zug') : t('Ersetzt deinen Zug')}</span>
                  <span><Icon name={u === 'meteor' || u === 'coronation' ? 'scope' : 'sparkles'} size={12} />{u === 'meteor' || u === 'coronation' ? t('Mit Ziel') : t('Ohne Ziel')}</span>
                </div>
                {ok ? (
                  <button className={`chunky xs ${on ? 'gray' : 'gold'}`} style={{ width: 'auto', alignSelf: 'flex-start', padding: '0 16px' }} disabled={on}
                    onClick={() => { S.setSettings(s => { s.ultimate = u }); sound('select'); showToast(t('{0} übernommen.', t(ULTS[u].name))) }}>{on ? t('Ausgerüstet') : t('Ausrüsten')}</button>
                ) : <span className="capsule chip"><Icon name="lock" size={10} />{t('Arena {0} · ab {1} Trophäen', ULTS[u].arena, ARENAS[ULTS[u].arena - 1].trophies)}</span>}
              </div>
            </div>
          )
        })}
      </div>
      {toast}
    </Sheet>
  )
}

