// RulesView and DetailSheet of the app: four tabs (basics, cards, battle, progress) with small visuals.
import { useRef, useState } from 'react'
import { pieceImage, cardArt } from '../art'
import { CARDS, CARD_IDS, ROLES, TIERS, ULTS, cardCost, isUlt, ultCost, KEEPS_TURN, type CardId, type Role, type UltId } from '../game/catalog'
import { E } from '../engine'
import { useI18n } from '../i18n'
import { Icon } from '../ui/Icon'
import { ChestView, ManaDrop, Sheet } from '../ui/kit'
import { openOverlay, closeSheet } from '../nav'

type Item = { icon?: string; title?: string; text: string; args?: Array<string | number> }
type Visual = 'turn' | 'mana' | 'deck' | 'ults' | 'trophies' | 'chests' | 'cards'
type Chapter = { id: string; title: string; targs?: Array<string | number>; tint: string; icon: string; items: Item[]; visual?: Visual; steps?: boolean }
type Tile = { icon: string; tint: string; title: string; text: string }
type TabId = 'basics' | 'cards' | 'battle' | 'progress'

const cooldownAll = (E.CFG.cooldown as Record<string, number>).all ?? 2
const cooldownBolt = (E.CFG.cooldown as Record<string, number>).lightning ?? 3

// Four calm tabs (RulesView in the app): the basics first, the card list on its own page, battles and progress as one-liners.
// Rarely needed rules sit folded under „Gut zu wissen“, so the first page shows only what a new player needs.
const TABS: Array<{ id: TabId; label: string; icon: string }> = [
  { id: 'basics', label: 'Grundlagen', icon: 'book' },
  { id: 'cards', label: 'Karten', icon: 'stack' },
  { id: 'battle', label: 'Kampf', icon: 'bolt' },
  { id: 'progress', label: 'Fortschritt', icon: 'trophy' },
]

const BASICS: Chapter[] = [
  { id: 'turn', title: 'Ablauf eines Zuges', tint: '#6E9BF0', icon: 'arrowCounter', visual: 'turn', steps: true, items: [
    { text: 'Zu Beginn deines Zuges bekommst du +1 Mana.' },
    { text: 'Dann wählst du eine Aktion: Schachzug, Karte oder Ultimate.' },
    { text: 'Bonuskarten und die Festung beenden deinen Zug nicht – danach folgt noch ein Figurzug.' },
  ] },
  { id: 'mana', title: 'Mana (maximal {0})', targs: [10], tint: '#B9A2FF', icon: 'drop', visual: 'mana', items: [
    { icon: 'arrowCounter', title: 'Jeder Zug', text: '+1 Mana zu Beginn deines Zuges' },
    { icon: 'star', title: 'Guter Zug', text: '+1 extra für Schlagen oder Schach – höchstens +1 pro Zug' },
  ] },
  { id: 'deck', title: 'Deck', tint: '#6E9BF0', icon: 'stack', visual: 'deck', items: [
    { icon: 'stack', title: '4 Karten + 1 Ultimate', text: 'Bleiben die ganze Partie auf der Hand – es wird nicht nachgezogen.' },
    { icon: 'hourglass', title: 'Abklingzeit', text: 'Nach dem Ausspielen lädt eine Karte {0} eigene Züge nach (Blitz {1}), bevor du sie wieder spielen kannst.', args: [cooldownAll, cooldownBolt] },
  ] },
]

const MORE: Chapter[] = [
  { id: 'territory', title: 'Gebiet', tint: '#4FBF8A', icon: 'grid', items: [
    { text: 'Jede Figur beherrscht ihr Feld und die 8 Nachbarfelder. Dein Gebiet ist heller getönt – Mana bringt es nicht.' },
  ] },
  { id: 'safety', title: 'Schutzregeln', tint: '#6E9BF0', icon: 'shield', items: [
    { text: 'Der König ist immun gegen Karten und Ultimates. Die Dame ist immun gegen Frost und Meteor.' },
    { text: 'Karten und Ultimates geben kein Schach.' },
    { text: 'Frost erzwingt nie ein Patt.' },
  ] },
  { id: 'draw', title: 'Remis', tint: '#8DA0C4', icon: 'equal', items: [
    { text: 'Durch Patt, dreifache Wiederholung, die 50-Züge-Regel oder ein angenommenes Angebot.' },
  ] },
]

const BATTLE: Tile[] = [
  { icon: 'person2', tint: '#F07A72', title: 'Kampf', text: 'Ein Online-Gegner mit ähnlich vielen Trophäen. 5 Minuten pro Spieler.' },
  { icon: 'trophy', tint: '#F2C14E', title: 'Trophäen', text: 'Gegen Stärkere gewinnst du mehr, gegen Schwächere weniger.' },
  { icon: 'stairs', tint: '#C084FC', title: 'Bot-Leiter', text: 'Zwölf Bots der Reihe nach besiegen – für XP und Truhen.' },
]
const PROGRESS: Tile[] = [
  { icon: 'box', tint: '#C084FC', title: 'Truhen', text: 'Aus Siegen, Tageszielen, Levels und dem Trophäenpfad. Jeder Tap kann sie aufwerten.' },
  { icon: 'puzzle', tint: '#F2C14E', title: 'Puzzles & XP', text: 'Jedes gelöste Puzzle bringt XP, das Tagespuzzle einen Bonus.' },
  { icon: 'flame', tint: '#FF8A3D', title: 'Tägliche Flammen', text: 'Ein Puzzle oder eine Partie pro Tag hält deine Serie am Leben.' },
  { icon: 'diamond', tint: '#7FE3FF', title: 'Splitter & Laden', text: 'Sammeln und im Laden gegen Karten, Avatare und Truhen tauschen.' },
]

export function RulesSheet({ onClose }: { onClose: () => void }) {
  const { t } = useI18n()
  const [detail, setDetail] = useState<string | null>(null)
  const [tab, setTab] = useState<TabId>('basics')
  const [open, setOpen] = useState<string | null>(null)
  const pageRef = useRef<HTMLDivElement>(null)
  const pick = (id: TabId) => {
    setTab(id)
    pageRef.current?.closest('.sheet')?.scrollTo({ top: 0 })
  }
  const tabs = (
    <div className="rules3-tabs" role="tablist">
      {TABS.map(x => (
        <button key={x.id} role="tab" aria-selected={tab === x.id} className={tab === x.id ? 'on' : ''} onClick={() => pick(x.id)}>
          <Icon name={x.icon} size={14} /><span>{t(x.label)}</span>
        </button>
      ))}
    </div>
  )
  return (
    <Sheet title={t('Regeln')} onClose={onClose} tall wide sub={tabs}>
      <div className="rules3" key={tab} ref={pageRef}>
        {tab === 'basics' && <>
          <header className="rules3-goal">
            <MateBoard />
            <div className="rules3-goal-text">
              <span className="rules3-kicker">{t('Ziel')}</span>
              <b>{t('Setze den gegnerischen König matt.')}</b>
              <span>{t('Schach mit Karten, Mana und Ultimates.')}</span>
            </div>
          </header>
          {BASICS.map(ch => <ChapterCard key={ch.id} ch={ch} onCard={setDetail} />)}
          <section className="rules3-card" style={{ ['--tint' as string]: '#F2C14E' }}>
            <ChapterHead icon="sparkles" title={t('Ultimate')} />
            <p className="rules3-text">{t('Lädt sich mit Mana auf und ersetzt deinen Zug. Neue Ultimates gibt es in neuen Arenen.')}</p>
            <button className="rules3-link" onClick={() => pick('cards')}>{t('Alle Karten ansehen')}<Icon name="chevronRight" size={14} /></button>
          </section>
          <h3 className="rules3-section">{t('Gut zu wissen')}</h3>
          <div className="rules3-list">
            {MORE.map(ch => {
              const on = open === ch.id
              return (
                <div key={ch.id} className={`rules3-fold${on ? ' on' : ''}`} style={{ ['--tint' as string]: ch.tint }}>
                  <button className="rules3-fold-head" aria-expanded={on} onClick={() => setOpen(on ? null : ch.id)}>
                    <span className="rules3-ico"><Icon name={ch.icon} size={15} /></span>
                    <b>{t(ch.title)}</b>
                    <Icon name="chevronDown" size={14} />
                  </button>
                  {on && <div className="rules3-fold-body">{ch.items.map((it, i) => <p key={i} className="rules3-bullet">{t(it.text)}</p>)}</div>}
                </div>
              )
            })}
          </div>
        </>}

        {tab === 'cards' && <>
          <div className="rules3-info">
            <span><Icon name="handPoint" size={13} />{t('Tippe auf eine Karte für alle Details.')}</span>
            <span><span className="rules-card-bonus"><Icon name="walk" size={11} /></span>{t('Danach noch ein Zug')}</span>
          </div>
          <RulesVisual kind="cards" onCard={setDetail} />
          <h3 className="rules3-section">{t('Ultimates')}</h3>
          <section className="rules3-card" style={{ ['--tint' as string]: '#F2C14E' }}>
            <p className="rules3-text">{t('Lädt sich mit Mana auf und ersetzt deinen Zug. Neue Ultimates gibt es in neuen Arenen.')}</p>
            <RulesVisual kind="ults" onCard={setDetail} />
          </section>
        </>}

        {tab === 'battle' && <>
          <div className="rules3-banner"><RulesVisual kind="trophies" onCard={setDetail} /></div>
          <TileList tiles={BATTLE} />
        </>}

        {tab === 'progress' && <>
          <div className="rules3-banner"><RulesVisual kind="chests" onCard={setDetail} /></div>
          <TileList tiles={PROGRESS} />
        </>}
      </div>
      {detail && <CardDetail id={detail} onClose={() => setDetail(null)} />}
    </Sheet>
  )
}

/** Small mate picture: queen and king trap the black king in the corner. */
function MateBoard() {
  const mate: Array<[number, number, 'w' | 'b', string]> = [[0, 3, 'b', 'k'], [1, 1, 'w', 'q'], [2, 3, 'w', 'k']]
  return (
    <div className="rules-board" aria-hidden="true">
      {Array.from({ length: 16 }, (_, i) => {
        const row = Math.floor(i / 4), col = i % 4
        const p = mate.find(([r, c]) => r === row && c === col)
        return <div key={i} className={(row + col) % 2 ? 'd' : 'l'}>{p && <img src={pieceImage(p[2], p[3])} alt="" className={p[3] === 'k' && p[2] === 'b' ? 'mated' : ''} />}</div>
      })}
    </div>
  )
}

function ChapterHead({ icon, title }: { icon: string; title: string }) {
  return <div className="rules3-head"><span className="rules3-ico"><Icon name={icon} size={15} /></span><h4>{title}</h4></div>
}

function ChapterCard({ ch, onCard }: { ch: Chapter; onCard: (id: string) => void }) {
  const { t } = useI18n()
  return (
    <section className="rules3-card" style={{ ['--tint' as string]: ch.tint }}>
      <ChapterHead icon={ch.icon} title={t(ch.title, ...(ch.targs ?? []))} />
      {ch.visual && <div className="rules3-visual"><RulesVisual kind={ch.visual} onCard={onCard} /></div>}
      {ch.steps
        ? <ol className="rules3-steps">{ch.items.map((it, i) => <li key={i}><span>{i + 1}</span><p>{t(it.text, ...(it.args ?? []))}</p></li>)}</ol>
        : ch.items.map((it, i) => (
          <div key={i} className="rules3-line">
            <b>{t(it.title ?? '')}</b>
            <span>{t(it.text, ...(it.args ?? []))}</span>
          </div>
        ))}
    </section>
  )
}

function TileList({ tiles }: { tiles: Tile[] }) {
  const { t } = useI18n()
  return (
    <div className="rules3-list">
      {tiles.map(x => (
        <div key={x.title} className="rules3-row" style={{ ['--tint' as string]: x.tint }}>
          <span className="rules3-ico big"><Icon name={x.icon} size={18} /></span>
          <div><b>{t(x.title)}</b><span>{t(x.text)}</span></div>
        </div>
      ))}
    </div>
  )
}

const ROLE_ORDER: Role[] = ['attack', 'control', 'defense', 'mana', 'comeback']

function RulesVisual({ kind, onCard }: { kind: Visual; onCard: (id: string) => void }) {
  const { t } = useI18n()
  switch (kind) {
    case 'turn':
      return (
        <div className="rv-turn">
          {[['crown', 'Schachzug'], ['stack', 'Karte'], ['sparkles', 'Ultimate']].map(([icon, label], i) => (
            <span key={icon} className={`rv-choice c${i}`}><Icon name={icon} size={24} /><b>{t(label)}</b></span>
          ))}
        </div>
      )
    case 'mana':
      return (
        <div className="rv-mana" aria-hidden="true">
          {Array.from({ length: 10 }, (_, i) => <i key={i} className={i < 4 ? 'on' : i === 4 ? 'next' : ''} style={{ animationDelay: `${i * 0.06}s` }} />)}
        </div>
      )
    case 'deck':
      return (
        <div className="rv-deck">
          {(['lightning', 'shield', 'sprint', 'freeze'] as CardId[]).map((c, i) => (
            <img key={c} src={cardArt(`art-card-${c}`)} alt={t(CARDS[c].name)} style={{ ['--r' as string]: `${(i - 1.5) * 7}deg`, borderColor: TIERS[CARDS[c].tier].color }} />
          ))}
          <img className="ult" src={cardArt('art-ult-meteor')} alt={t('Meteor')} />
        </div>
      )
    case 'ults':
      return (
        <div className="rules-ults">
          {(Object.keys(ULTS) as UltId[]).sort((a, b) => ULTS[a].arena - ULTS[b].arena).map(u => (
            <button key={u} className="rules-ult" onClick={() => onCard(u)} title={t(ULTS[u].name)}>
              <img src={cardArt(`art-ult-${u}`)} alt={t(ULTS[u].name)} />
              <span className="rules-ult-arena">{t('Arena {0}', ULTS[u].arena)}</span>
            </button>
          ))}
        </div>
      )
    case 'trophies':
      return (
        <div className="rv-trophies">
          <div className="win"><Icon name="trophy" size={18} /><b>+20</b><span>{t('Sieg')}</span></div>
          <div className="draw"><Icon name="equal" size={18} /><b>±0</b><span>{t('Remis')}</span></div>
          <div className="loss"><Icon name="heartSlash" size={18} /><b>−20</b><span>{t('Niederlage')}</span></div>
        </div>
      )
    case 'chests':
      return (
        <div className="rv-chests">
          {([0, 1, 2, 3, 4] as const).map(r => <ChestView key={r} rarity={r} size={38 + r * 7} glow={r >= 3 ? 0.5 : 0} className="bob" style={{ animationDelay: `${r * 0.2}s` }} />)}
        </div>
      )
    case 'cards':
      return (
        <div className="rules-roles">
            {ROLE_ORDER.map(role => {
              const ids = CARD_IDS.filter(c => CARDS[c].role === role)
              if (!ids.length) return null
              const info = ROLES[role]
              return (
                <div key={role} className="rules-role" style={{ ['--role' as string]: info.color }}>
                  <span className="rules-role-h"><Icon name={info.icon} size={12} />{t(info.name)}</span>
                  <div className="rules-role-cards">
                    {ids.map(c => (
                      <button key={c} className="rules-card" onClick={() => onCard(c)} style={{ ['--tier' as string]: TIERS[CARDS[c].tier].color }}>
                        <span className="rules-card-art"><img src={cardArt(`art-card-${c}`)} alt="" /><ManaDrop text={cardCost(c)} size={18} style={{ position: 'absolute', left: -6, top: -6 }} /></span>
                        <b className="clip1">{t(CARDS[c].name)}</b>
                        {KEEPS_TURN[c] && <span className="rules-card-bonus" title={t('Danach noch ein Zug')}><Icon name="walk" size={11} /></span>}
                      </button>
                    ))}
                  </div>
                </div>
              )
            })}
        </div>
      )
  }
}

/** Big card with all details (long press on a card, or a tap in the collection). */
export function CardDetail({ id, onClose, allowLab = false, footer }: { id: string; onClose: () => void; allowLab?: boolean; footer?: React.ReactNode }) {
  const { t } = useI18n()
  const ult = isUlt(id)
  const info = ult ? ULTS[id as UltId] : CARDS[id as CardId]
  const card = !ult ? CARDS[id as CardId] : null
  const cost = ult ? ultCost(id) : cardCost(id)
  const cd = card ? ((E.CFG.cooldown as Record<string, number>)[id] ?? cooldownAll) : 0
  return (
    <Sheet title={t(info.name)} onClose={onClose}>
      <div className="detail">
        <div className={`detail-card${ult ? ' ult' : ''}`} style={{ ['--tier' as string]: card ? TIERS[card.tier].color : 'var(--gold)' }}>
          <img src={cardArt(ult ? `art-ult-${id}` : `art-card-${id}`)} alt="" />
          <ManaDrop text={cost} size={34} style={{ left: -8, top: -10 }} />
        </div>
        <div className="detail-tags">
          {card && <span className="capsule chip" style={{ color: ROLES[card.role].color, borderColor: ROLES[card.role].color + '80' }}><Icon name={ROLES[card.role].icon} size={10} />{t(ROLES[card.role].name)}</span>}
          {card && <span className="capsule chip" style={{ color: TIERS[card.tier].color, borderColor: TIERS[card.tier].color + '80' }}>{t(TIERS[card.tier].name)}</span>}
          {ult && <span className="capsule chip gold"><Icon name="sparkles" size={10} />{t('Ultimate')} · {t((info as typeof ULTS.meteor).style)}</span>}
          {ult && <span className="capsule chip">{t('Arena {0}', (info as typeof ULTS.meteor).arena)}</span>}
          <span className="capsule chip"><Icon name="drop" size={10} />{t('{0} Mana', cost)}</span>
          {card && <span className="capsule chip"><Icon name="hourglass" size={10} />{t('Abklingzeit')} {cd}</span>}
          {(KEEPS_TURN[id] || id === 'fortress') && <span className="capsule chip" style={{ color: 'var(--blue-light)' }}><Icon name="walk" size={10} />{t('Danach noch ein Zug')}</span>}
        </div>
        <p className="detail-text">{t(info.text)}</p>
        {allowLab && (
          <button className="chunky gold sm" onClick={() => { onClose(); closeSheet(); openOverlay({ kind: 'lab', key: (ult ? 'u-' : 'c-') + id }) }}>
            <Icon name="graduation" size={16} />{t('Ausprobieren')}
          </button>
        )}
        {footer}
      </div>
    </Sheet>
  )
}
