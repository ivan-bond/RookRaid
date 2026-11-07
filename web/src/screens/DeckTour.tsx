// DeckTour.swift: Rocky's deck workshop – pick cards, deck check with stars, the swap trick, the ultimate and all five ultimates.
import { useEffect, useRef, useState } from 'react'
import { rockyFace } from '../art'
import { CARDS, DECK_SIZE, KEEPS_TURN, ROLES, ULTS, ULT_IDS, cardCost, type CardId, type Role, type UltId } from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { Icon } from '../ui/Icon'
import { UltimateCard } from '../ui/kit'

export const TOUR_REWARD = 20
export type TourStep = 'hello' | 'pick' | 'fill' | 'check' | 'swapOut' | 'swapIn' | 'recheck' | 'ultimate' | 'ultimates' | 'done'
const PROGRESS: Record<TourStep, number> = { hello: 0, pick: 1, fill: 1, check: 2, swapOut: 3, swapIn: 3, recheck: 3, ultimate: 4, ultimates: 4, done: 5 }
type T = (k: string, ...a: Array<string | number>) => string

// MARK: Deck check

const CORE: Role[] = ['attack', 'control', 'defense']
const cheaper = (a: CardId, b: CardId) => (cardCost(a) - cardCost(b)) || (a < b ? -1 : a > b ? 1 : 0)
const minBy = (list: CardId[]) => (list.length ? [...list].sort(cheaper)[0] : undefined)
const maxBy = (list: CardId[]) => (list.length ? [...list].sort(cheaper)[list.length - 1] : undefined)

export class DeckCheck {
  constructor(public deck: CardId[]) {}
  get average() { return this.deck.reduce((s, c) => s + cardCost(c), 0) / Math.max(1, this.deck.length) }
  get averageText() { return this.average.toFixed(1) }
  get missingRoles() { return CORE.filter(r => !this.deck.some(c => CARDS[c].role === r)) }
  get cheapest() { return minBy(this.deck) }
  get priciest() { return maxBy(this.deck) }
  get bonusCount() { return this.deck.filter(c => KEEPS_TURN[c]).length }
  get manaOK() { return this.average <= 3 }
  get mixOK() { return this.missingRoles.length === 0 }
  get startOK() { return this.deck.some(c => cardCost(c) <= 2) }
  get stars() { return Math.max(1, [this.manaOK, this.mixOK, this.startOK].filter(Boolean).length) }
  verdict(t: T) {
    return this.stars === 3 ? t('Wow – ein Profi-Deck! Da zittern sogar die Bots.')
      : this.stars === 2 ? t("Starkes Deck! Mit einem kleinen Tausch wird's perfekt.") : t("Mutig … sehr mutig! Sollen wir's noch etwas verbessern?")
  }
  manaText(t: T) { return this.manaOK ? t('Ø {0} Mana – schnell spielbar.', this.averageText) : t('Ø {0} Mana – ganz schön teuer. Du wartest oft aufs Mana.', this.averageText) }
  mixText(t: T) { return this.mixOK ? t('Angriff, Kontrolle und Verteidigung – alles dabei!') : t('Es fehlt: {0}.', this.missingRoles.map(r => t(ROLES[r].name)).join(', ')) }
  startText(t: T) {
    const c = this.cheapest
    return this.startOK && c ? t('{0} kostet nur {1} Mana – damit legst du früh los.', t(CARDS[c].name), cardCost(c)) : t('Keine Karte für 2 Mana oder weniger – am Anfang ist Mana knapp.')
  }
  bonusText(t: T) {
    const n = this.bonusCount
    return n === 0 ? t('Keine Bonusaktion – jede Karte kostet dich deinen Zug.') : n === 1 ? t('1 Bonusaktion: Danach ziehst du noch eine Figur.') : t('{0} Bonusaktionen: Danach ziehst du noch eine Figur.', n)
  }
  suggestion(available: CardId[], t: T): { out?: CardId; into?: CardId; text: string } | null {
    const pool = available.filter(c => !this.deck.includes(c))
    const role = this.missingRoles[0]
    if (role) {
      const doubled = this.deck.filter(c => this.deck.filter(x => CARDS[x].role === CARDS[c].role).length > 1)
      const out = maxBy(doubled) ?? this.priciest
      const into = minBy(pool.filter(c => CARDS[c].role === role))
      if (into && out) return { out, into, text: t('Dir fehlt noch {0}. Nimm {1} raus und hol dir {2}!', t(ROLES[role].name), t(CARDS[out].name), t(CARDS[into].name)) }
      return { text: t('Dir fehlt noch {0} – solche Karten findest du bald in Truhen.', t(ROLES[role].name)) }
    }
    const out = this.priciest
    if (!this.manaOK && out) {
      const into = minBy(pool.filter(c => cardCost(c) < cardCost(out) && CARDS[c].role === CARDS[out].role)) ?? minBy(pool.filter(c => cardCost(c) < cardCost(out)))
      if (into) return { out, into, text: t('{0} ist ganz schön teuer. Tausch sie doch gegen {1}!', t(CARDS[out].name), t(CARDS[into].name)) }
      return { out, text: t('{0} ist ganz schön teuer – tausch sie gegen etwas Günstigeres.', t(CARDS[out].name)) }
    }
    if (!this.startOK && out) {
      const into = minBy(pool.filter(c => cardCost(c) <= 2))
      if (into) return { out, into, text: t("Für den Anfang fehlt dir eine günstige Karte. Wie wär's mit {0} statt {1}?", t(CARDS[into].name), t(CARDS[out].name)) }
    }
    return null
  }
  bestAddition(candidates: CardId[], avoiding?: CardId): CardId | undefined {
    const pool = candidates.filter(c => !this.deck.includes(c) && c !== avoiding)
    const role = this.missingRoles[0]
    if (role) { const c = minBy(pool.filter(x => CARDS[x].role === role)); if (c) return c }
    if (!this.startOK) return minBy(pool.filter(x => cardCost(x) <= 2))
    return undefined
  }
}

const QUIPS: Record<CardId, string> = {
  shield: 'Schild! Sehr vernünftig – so verlierst du keine wichtige Figur.',
  freeze: 'Frost! Brrr … damit legst du die gefährlichste Figur auf Eis.',
  bulwark: 'Bollwerk! Deine Bauern bauen sich eine Mauer. Gemütlich!',
  sprint: 'Sturmlauf! Deine Bauern bekommen Raketenschuhe.',
  lightning: 'Blitz! Zack – vorwitzige Bauern in deiner Hälfte sind Geschichte.',
  knighting: 'Ritterschlag! Aus einem Bauern wird ein Springer – das sieht kein Gegner kommen.',
  reinforce: 'Verstärkung! Frischer Bauer, frisches Glück – Löcher in der Reihe, ade!',
  revive: 'Wiederkehr! Totgesagte leben länger – deine beste Figur kommt zurück.',
  bishopize: "Läuferweihe! Ein Bauer wird zum Läufer – ab jetzt geht's diagonal.",
  advance: 'Vormarsch! Alle Bauern – marsch! Ich hör schon die Trommeln.',
  swap: 'Leibwache! Dein König hat jetzt einen Bodyguard.',
  drain: 'Manaraub! Fies … aber genial. Der Gegner wird ganz blass.',
  focus: 'Konzentration! Tief durchatmen – und +4 Mana.',
  sacrifice: 'Bauernopfer! Mutig – ein Bauer für 3 Mana.',
  retreat: 'Rückzug! Kluger Schachzug – ein Schritt zurück, und der Bauer ist in Sicherheit.',
}
const ULT_TAKES: Record<UltId, string> = {
  meteor: 'Meteor: Rumms! Vernichtet eine gegnerische Figur – nur König und Dame nicht. Ideal gegen den Turm, der dir im Weg steht.',
  iceAge: 'Eiszeit: Alles friert ein! Zwei Züge lang kann der Gegner nur mit dem König ziehen – Zeit für deinen Großangriff.',
  fortress: 'Festung: Mauern hoch! Bis nach dem nächsten Gegnerzug ist keine deiner Figuren schlagbar, danach ziehst du noch. Schon ab 6 Mana – deine Rettung in der Not.',
  coronation: 'Krönung: Ein Bauer wird sofort zur Dame! Hast du schon eine, muss er dafür in der gegnerischen Hälfte stehen.',
  rebirth: 'Wiedergeburt: Deine wertvollste geschlagene Figur kehrt zurück – sogar die Dame! Der perfekte Comeback-Trick.',
}

// MARK: State (DeckTour ObservableObject)

export type Tour = ReturnType<typeof useDeckTour>

export function useDeckTour(deck: CardId[]) {
  const { t } = useI18n()
  const [step, setStep] = useState<TourStep | null>(null)
  const [reaction, setReaction] = useState<string | null>(null)
  const [suggestedIn, setIn] = useState<CardId | undefined>()
  const [suggestedOut, setOut] = useState<CardId | undefined>()
  const [removed, setRemoved] = useState<CardId | undefined>()
  const [starsBefore, setStarsBefore] = useState(0)
  const [focusUlt, setFocusUlt] = useState<UltId | null>(null)
  const [seen, setSeen] = useState<UltId[]>([])
  const [burst, setBurst] = useState(0)
  const [firstRun, setFirstRun] = useState(false)
  const known = useRef<CardId[]>(deck)
  const token = useRef(0)
  const stepRef = useRef(step)
  stepRef.current = step
  const available = () => S.unlockedCards()

  const later = (next: TourStep, ms: number) => {
    const tk = token.current
    window.setTimeout(() => { if (token.current === tk && stepRef.current) { setStep(next); haptic('select') } }, ms)
  }
  const start = (first: boolean) => {
    setFirstRun(first); known.current = deck; setReaction(null); setIn(undefined); setOut(undefined); setRemoved(undefined)
    token.current++; setStep('hello'); sound('notify'); haptic('summon')
  }
  const finish = () => { token.current++; setStep(null); setReaction(null); setIn(undefined); setOut(undefined) }
  const next = () => {
    if (!step) return
    token.current++
    known.current = deck
    if (step === 'hello') { setReaction(null); setStep(deck.length >= DECK_SIZE ? 'check' : deck.length === 0 ? 'pick' : 'fill') }
    else if (step === 'check') {
      const check = new DeckCheck(deck)
      setStarsBefore(check.stars)
      const s = check.suggestion(available(), t)
      setOut(s?.out); setIn(s?.into); setRemoved(undefined)
      setStep('swapOut')
    } else if (step === 'recheck') setStep('ultimate')
    else if (step === 'ultimate') { setFocusUlt(null); setSeen([]); setStep('ultimates') }
    else if (step === 'ultimates') setStep('done')
    else return
    haptic('select')
  }
  const skipToUltimate = () => { token.current++; setIn(undefined); setOut(undefined); setStep('ultimate'); haptic('select') }
  const explain = (u: UltId) => {
    if (step !== 'ultimates') return
    setFocusUlt(u)
    if (!seen.includes(u)) { setSeen([...seen, u]); setBurst(b => b + 1) }
    sound('card_flip')
  }

  // The deck changed (tap, preset, swap) – Rocky reacts.
  useEffect(() => {
    const old = known.current
    known.current = deck
    if (!step || old.join() === deck.join()) return
    const added = deck.find(c => !old.includes(c))
    const gone = old.find(c => !deck.includes(c))
    token.current++
    if (step === 'hello' || step === 'pick' || step === 'fill') {
      if (added) { setReaction(t(QUIPS[added])); setBurst(b => b + 1) }
      else if (gone) setReaction(t('{0} ist wieder raus – auch okay! Ausprobieren ist erlaubt.', t(CARDS[gone].name)))
      if (deck.length >= DECK_SIZE) { setStep('fill'); later('check', 1900) } else setStep(deck.length === 0 && !added ? 'pick' : 'fill')
    } else if (step === 'swapOut') {
      if (gone && deck.length < old.length) {
        setRemoved(gone); setOut(undefined)
        setIn(new DeckCheck(deck).bestAddition(available(), gone))
        setStep('swapIn')
      } else if (deck.length >= DECK_SIZE && added) {
        setRemoved(gone); setReaction(t(QUIPS[added])); setBurst(b => b + 1); setOut(undefined); setIn(undefined)
        setStep('swapIn'); later('recheck', 1700)
      }
    } else if (step === 'swapIn') {
      if (deck.length >= DECK_SIZE && added) { setReaction(t(QUIPS[added])); setBurst(b => b + 1); setIn(undefined); later('recheck', 1700) }
      else if (gone) { setRemoved(gone); setIn(new DeckCheck(deck).bestAddition(available(), gone)); setReaction(null) }
    }
  }, [deck.join()])

  const message = (): string => {
    if (!step) return ''
    const left = DECK_SIZE - deck.length
    const lead = reaction ? reaction + '\n' : ''
    switch (step) {
      case 'hello': return deck.length >= DECK_SIZE
        ? t('Willkommen in meiner Deck-Werkstatt. Deine 4 Deckkarten hast du in jeder Partie auf der Hand – lass uns dein Deck mal durchchecken!')
        : t('Willkommen in meiner Deck-Werkstatt. Oben liegen deine 4 Deckplätze – genau diese Karten hast du in jeder Partie auf der Hand.')
      case 'pick': return lead + t('Tippe unten eine Karte an – schwupps, liegt sie auf Platz 1! Lange drücken zeigt dir vorher alle Details.')
      case 'fill': {
        if (left <= 0) return lead + t("Deck voll! Moment, ich schau's mir mal genauer an …")
        const rest = left === 1 ? t('Noch 1 Platz frei!') : t('Noch {0} Plätze frei.', left)
        const tip = new DeckCheck(deck).missingRoles.length ? ' ' + t('Mein Tipp: Misch Angriff, Kontrolle und Verteidigung.') : ''
        return lead + rest + tip
      }
      case 'check': return new DeckCheck(deck).verdict(t)
      case 'swapOut': {
        const s = new DeckCheck(deck).suggestion(available(), t)
        return s ? s.text + ' ' + t('Tippe dazu oben eine Karte im Deck an – zack, ist sie raus.')
          : t('Profi-Trick: Tippe oben eine Karte in deinem Deck an – zack, ist sie raus. Keine Sorge, du holst sie gleich wieder rein!')
      }
      case 'swapIn':
        if (left <= 0) return lead + t('Und? Mal sehen, was die Wertung jetzt sagt …')
        if (!removed) return t('Jetzt tippe unten die Karte an, die rein soll.')
        return suggestedIn ? t('{0} ist raus! Jetzt tippe unten {1} an – die Karte leuchtet schon.', t(CARDS[removed].name), t(CARDS[suggestedIn].name))
          : t('{0} ist raus! Jetzt tippe unten die Karte an, die rein soll – oder hol {0} zurück.', t(CARDS[removed].name))
      case 'recheck': {
        const now = new DeckCheck(deck).stars
        if (now > starsBefore) return t('Besser! Von {0} auf {1} Sterne – genau so geht Deckbau.', starsBefore, now)
        if (now < starsBefore) return t('Hoppla, ein Stern weniger. Kein Problem – du kannst jederzeit zurücktauschen.')
        return t('Gleich viele Sterne – auch gut! Probier ruhig verschiedene Mischungen aus.')
      }
      case 'ultimate': return t('Rechts liegt deine Ultimate – deine Superkraft! Jeder Zug lädt Mana. Ab 8 Mana (Festung schon ab 6) zündest du sie statt eines Zugs. Und: Dein Gegner sieht, welche du dabeihast.')
      case 'ultimates': {
        if (!focusUlt) return t('Fünf Ultimates gibt es. Tippe eine an – ich erzähl dir, wofür sie gut ist!')
        const status = !S.isUltUnlocked(focusUlt) ? t('Freigeschaltet ab Arena {0}.', ULTS[focusUlt].arena)
          : S.activeUltimate() === focusUlt ? t('Die hast du gerade dabei.') : t('Lust drauf? Tippe auf „Ausrüsten“.')
        const all = seen.length === ULT_IDS.length ? ' ' + t('Jetzt kennst du alle fünf – ausprobieren kannst du sie in der Schule!') : ''
        return t(ULT_TAKES[focusUlt]) + ' ' + status + all
      }
      case 'done': return t('Starke Arbeit! Denk dran: Ein gutes Deck mischt Angriff, Kontrolle und Verteidigung – mit ein, zwei günstigen Karten für den Start.')
    }
  }

  return { step, active: step !== null, start, finish, next, skipToUltimate, explain, message, suggestedIn, suggestedOut, focusUlt, seen, burst, firstRun }
}

// MARK: Rocky's bubble

export function RockyTourPanel({ tour, deck, onEquip, onBattle }: { tour: Tour; deck: CardId[]; onEquip: (u: UltId) => void; onBattle: () => void }) {
  const { t } = useI18n()
  const step = tour.step!
  const full = deck.length >= DECK_SIZE
  const check = new DeckCheck(deck)
  const typed = useTypewriter(tour.message())
  const canEquip = tour.focusUlt && S.isUltUnlocked(tour.focusUlt) && S.activeUltimate() !== tour.focusUlt
  let primary: { title: string; icon?: string; run: () => void } | null = null
  let secondary: { title: string; run: () => void } | null = null
  if (step === 'hello') primary = { title: full ? t("Los geht's!") : t('Zeig her!'), icon: 'arrowRight', run: tour.next }
  if (step === 'check' || step === 'recheck') {
    primary = { title: step === 'check' ? t('Profi-Trick zeigen') : t('Weiter'), icon: 'arrowRight', run: tour.next }
    if (step === 'check') secondary = { title: t('Passt so'), run: tour.skipToUltimate }
  }
  if ((step === 'swapOut' || step === 'swapIn') && full) secondary = { title: t('Überspringen'), run: tour.skipToUltimate }
  if (step === 'ultimate') primary = { title: t("Welche gibt's?"), icon: 'sparkles', run: tour.next }
  if (step === 'ultimates') {
    primary = { title: t('Verstanden!'), icon: 'check', run: tour.next }
    if (canEquip) secondary = { title: t('Ausrüsten'), run: () => onEquip(tour.focusUlt!) }
  }
  if (step === 'done') primary = { title: t('Ab in den Kampf!'), icon: 'bolt', run: onBattle }
  return (
    <div className="rocky-panel slide-up">
      <img key={step + tour.burst} className="rocky-img rocky-face rocky-hop" src={rockyFace} alt="" />
      {tour.burst > 0 && <span key={'b' + tour.burst} className="rocky-sparks">{Array.from({ length: 8 }, (_, i) => <i key={i} style={{ ['--a' as string]: `${i * 45}deg` }} />)}</span>}
      <div className="rocky-bubble">
        <div className="row" style={{ gap: 6 }}>
          <span className="tour-dots">{[0, 1, 2, 3, 4, 5].map(i => <i key={i} className={i < PROGRESS[step] ? 'on' : i === PROGRESS[step] ? 'cur' : ''} />)}</span>
          <span className="spacer" />
          <button className="rocky-close" onClick={tour.finish} aria-label={t('Schließen')}><Icon name="xmark" size={12} /></button>
        </div>
        <p style={{ whiteSpace: 'pre-line' }}>{typed}</p>
        {(step === 'pick' || step === 'fill') && (
          <div className="role-tracker">
            {CORE.map(r => (
              <span key={r} className={deck.some(c => CARDS[c].role === r) ? 'on' : ''} style={{ ['--tint' as string]: ROLES[r].color }}><Icon name={ROLES[r].icon} size={11} />{t(ROLES[r].name)}</span>
            ))}
          </div>
        )}
        {(step === 'check' || step === 'recheck') && (
          <div className="deck-check">
            <div className="stars">{[0, 1, 2].map(i => <span key={i + step} className={i < check.stars ? 'on pop-in' : ''} style={{ animationDelay: `${i * 0.25}s` }}><Icon name="star" size={28} /></span>)}</div>
            <div className="check-rows">
              <span className={check.manaOK ? 'ok' : ''}><Icon name={check.manaOK ? 'checkCircle' : 'xCircle'} size={13} />{check.manaText(t)}</span>
              <span className={check.mixOK ? 'ok' : ''}><Icon name={check.mixOK ? 'checkCircle' : 'xCircle'} size={13} />{check.mixText(t)}</span>
              <span className={check.startOK ? 'ok' : ''}><Icon name={check.startOK ? 'checkCircle' : 'xCircle'} size={13} />{check.startText(t)}</span>
              <span><Icon name="walk" size={13} />{check.bonusText(t)}</span>
            </div>
          </div>
        )}
        {step === 'ultimates' && (
          <div className="ult-gallery">
            {ULT_IDS.map(u => (
              <button key={u} className={`ug${tour.focusUlt === u ? ' on' : ''}${tour.seen.includes(u) ? ' seen' : ''}${S.isUltUnlocked(u) ? '' : ' locked'}`} onClick={() => tour.explain(u)}>
                <UltimateCard ult={u} mana={S.isUltUnlocked(u) ? 99 : 0} compact />
                {!S.isUltUnlocked(u) && <span className="ug-lock"><Icon name="lock" size={10} /></span>}
              </button>
            ))}
          </div>
        )}
        {(primary || secondary) && (
          <div className="row" style={{ gap: 6, justifyContent: 'flex-end' }}>
            {secondary && <button className="ghost" onClick={secondary.run}>{secondary.title}</button>}
            {primary && <button className="chunky xs gold" style={{ width: 'auto', padding: '0 14px' }} onClick={primary.run}>{primary.icon && <Icon name={primary.icon} size={13} />}{primary.title}</button>}
          </div>
        )}
      </div>
    </div>
  )
}

function useTypewriter(text: string) {
  const [n, setN] = useState(0)
  useEffect(() => {
    setN(0)
    const id = window.setInterval(() => setN(x => { if (x >= text.length) { window.clearInterval(id); return x } return x + 2 }), 16)
    return () => window.clearInterval(id)
  }, [text])
  return text.slice(0, n)
}
