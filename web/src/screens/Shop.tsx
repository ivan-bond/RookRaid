// ShopViews.swift (Splitter-Laden): the treasury with balance and savings goal on top, tabs instead of one long list.
// Every item is a tile with a preview on a coloured ground, a price button and – while shards are missing – a bar
// showing how far along you are. A purchase ends with a small celebration.
import { useState } from 'react'
import { avatarImage, cardArt } from '../art'
import {
  AVATARS, BOARD_COLORS, BOARD_NAMES, BOARD_THEMES, CARDS, CARD_IDS, CHEST, COSMETIC_RARITY, FRAMES, MAX_FREEZES,
  SHOP_FRAMES, TIERS, isCollectibleBoard,
} from '../game/catalog'
import { haptic, sound } from '../game/feedback'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeSheet, openChests } from '../nav'
import { Icon } from '../ui/Icon'
import { ChestView, Confetti, Dialog, PlayerAvatar, Rays, Sheet, ShardIcon } from '../ui/kit'
import { useMidnight } from './Chests'

type T = (k: string, ...a: Array<string | number>) => string
type Tab = 'offers' | 'cards' | 'chests' | 'style' | 'extras'
const TABS: Array<[Tab, string, string]> = [
  ['offers', 'Angebote', 'sparkles'], ['cards', 'Karten', 'stack'], ['chests', 'Truhen', 'box'], ['style', 'Style', 'wand'], ['extras', 'Extras', 'snowflake'],
]

function itemTitle(i: S.ShopItem, t: T) {
  switch (i.kind) {
    case 'chest': return t(CHEST[i.rarity].name)
    case 'card': return t(CARDS[i.card].name)
    case 'board': return t('Brett „{0}“', t(BOARD_NAMES[i.board]))
    case 'frame': return t('Rahmen „{0}“', t(FRAMES[i.frame].name))
    case 'avatar': return t('Avatar „{0}“', t(AVATARS.find(a => a.id === i.avatar)!.name))
    case 'freeze': return t('Flammenschutz')
  }
}
function shortTitle(i: S.ShopItem, t: T) {
  switch (i.kind) {
    case 'board': return t(BOARD_NAMES[i.board])
    case 'frame': return t(FRAMES[i.frame].name)
    case 'avatar': return t(AVATARS.find(a => a.id === i.avatar)!.name)
    default: return itemTitle(i, t)
  }
}
function accent(i: S.ShopItem): string {
  switch (i.kind) {
    case 'chest': return CHEST[i.rarity].glow
    case 'card': return TIERS[CARDS[i.card].tier].color
    case 'avatar': return COSMETIC_RARITY[AVATARS.find(a => a.id === i.avatar)!.rarity].color
    case 'frame': return COSMETIC_RARITY[FRAMES[i.frame].rarity].color
    case 'board': return '#C9A2FF'
    case 'freeze': return '#6CC8FF'
  }
}
function ItemArt({ i, size = 56 }: { i: S.ShopItem; size?: number }) {
  if (i.kind === 'chest') return <ChestView rarity={i.rarity} size={size * 1.05} glow={0.4} />
  if (i.kind === 'card') return <img src={cardArt(`art-card-${i.card}`)} alt="" style={{ width: size * 0.8, height: size, objectFit: 'cover', borderRadius: 8, border: `2px solid ${TIERS[CARDS[i.card].tier].color}` }} />
  if (i.kind === 'board') { const c = BOARD_COLORS[i.board]; return <span className="mini-check big" style={{ width: size * 0.85, height: size * 0.85 }}>{Array.from({ length: 16 }, (_, k) => <i key={k} style={{ background: (Math.floor(k / 4) + k) % 2 ? c.dark : c.light }} />)}</span> }
  if (i.kind === 'frame') return <PlayerAvatar avatar={S.activeAvatar()} frame={i.frame} size={size} />
  if (i.kind === 'avatar') return <img src={avatarImage(i.avatar)} alt="" style={{ width: size, height: size, borderRadius: '50%' }} />
  return <span className="shop-freeze" style={{ width: size * 0.85, height: size * 0.85 }}><Icon name="snowflake" size={size * 0.45} color="#fff" /></span>
}
function Bar({ value, color }: { value: number; color: string }) {
  return <span className="shop-bar"><i style={{ width: `${Math.max(4, Math.min(1, value) * 100)}%`, background: `linear-gradient(90deg, ${color}99, ${color})` }} /></span>
}

export function ShopSheet() {
  const p = S.useProfile()
  const { t } = useI18n()
  const [tab, setTab] = useState<Tab>('offers')
  const [confirm, setConfirm] = useState<{ item: S.ShopItem; price: number; offer?: string } | null>(null)
  const [owned, setOwned] = useState<S.ShopItem | null>(null)
  const midnight = useMidnight()
  const goal = S.shardGoalItem(p)
  const offers = S.dailyOffers()
  const level = S.levelFor(p.xp)

  const subtitle = (i: S.ShopItem): string => {
    switch (i.kind) {
      case 'card': { const tier = TIERS[CARDS[i.card].tier]; return level >= tier.gate ? t(tier.name) : t('ab Level {0}', tier.gate) }
      case 'chest': return i.rarity >= 3 ? t('Hohe Chance auf eine neue Karte') : t('Garantiert XP und Splitter, mit Glück eine Karte')
      case 'avatar': return t(COSMETIC_RARITY[AVATARS.find(a => a.id === i.avatar)!.rarity].name)
      case 'frame': return t(COSMETIC_RARITY[FRAMES[i.frame].rarity].name)
      case 'board': return t('Brett für alle Partien')
      case 'freeze': return t('Du hast {0} von {1}', p.streakFreezes, MAX_FREEZES)
    }
  }
  const tapBuy = (item: S.ShopItem, price: number, offer: string | undefined, blocked: boolean) => {
    if (blocked) return
    if (p.shards >= price) { haptic('select'); setConfirm({ item, price, offer }) } else { haptic('invalid') }
  }
  const buy = () => {
    if (!confirm) return
    const res = S.buyItem(confirm.item, confirm.price, confirm.offer)
    setConfirm(null)
    if (!res) { haptic('invalid'); return }
    sound('shard_shower'); haptic('chestBig')
    if (res.kind === 'chest') { closeSheet(); window.setTimeout(() => openChests(res.chest), 300) } else { sound('reward_big'); setOwned(confirm.item) }
  }

  const priceButton = (price: number, base: number, state: { bought: boolean; owned: boolean; gated: boolean; affordable: boolean; full?: boolean }) => {
    if (state.bought || state.owned) return <span className="shop-owned"><Icon name="checkCircle" size={14} />{state.full ? t('Voll') : state.bought ? t('Gekauft') : t('Im Besitz')}</span>
    if (state.gated) return <span className="shop-owned muted">{t('Noch gesperrt')}</span>
    return (
      <span className={`shop-price${state.affordable ? ' ok' : ''}`}>
        <Icon name="diamondFill" size={11} /><b className="num">{price}</b>{base > price && <s className="num">{base}</s>}
        {state.affordable && <span className="shine" />}
      </span>
    )
  }

  const tile = (item: S.ShopItem, opts: { price?: number; base?: number; offer?: string } = {}) => {
    const price = opts.price ?? S.basePrice(item)
    const base = opts.base ?? price
    const bought = opts.offer ? S.isOfferBought({ id: opts.offer, item, price, basePrice: base }, p) : false
    const isOwned = S.isItemOwned(item, p)
    const full = item.kind === 'freeze' && p.streakFreezes >= MAX_FREEZES
    const gated = item.kind === 'card' && level < TIERS[CARDS[item.card].tier].gate
    const affordable = p.shards >= price
    const isGoal = p.shardGoal === S.goalID(item)
    const color = accent(item)
    const discount = base > price ? Math.round((1 - price / base) * 100) : 0
    const off = isOwned || bought || gated || full
    return (
      <div key={S.goalID(item) + (opts.offer ?? '')} className={`shop-tile2${off ? ' off' : ''}${isGoal ? ' goal' : ''}`} style={{ ['--acc' as string]: color }}
        role="button" tabIndex={0} onClick={() => tapBuy(item, price, opts.offer, off)}>
        <div className="shop-tile-art">
          <ItemArt i={item} />
          {gated && <span className="shop-lock"><Icon name="lock" size={14} color="#fff" /></span>}
          {discount > 0 && !bought && <span className="shop-discount">−{discount} %</span>}
          {!off && (
            <button className={`shop-star${isGoal ? ' on' : ''}`} aria-label={isGoal ? t('Sparziel entfernen') : t('Als Sparziel setzen')}
              onClick={e => { e.stopPropagation(); haptic('select'); S.setShardGoal(isGoal ? null : item) }}>
              <Icon name={isGoal ? 'star' : 'star'} size={14} />
            </button>
          )}
        </div>
        <b className="shop-tile-name">{shortTitle(item, t)}</b>
        <span className="shop-tile-sub">{subtitle(item)}</span>
        {priceButton(price, base, { bought, owned: isOwned || full, gated, affordable, full })}
        {!off && !affordable && <Bar value={p.shards / price} color="#7FE3FF" />}
      </div>
    )
  }

  const hero = offers[0]
  const heroOffer = hero && (() => {
    const bought = S.isOfferBought(hero, p) || S.isItemOwned(hero.item, p)
    const affordable = p.shards >= hero.price
    const color = accent(hero.item)
    return (
      <div className={`shop-hero${bought ? ' off' : ''}`} style={{ ['--acc' as string]: color }} role="button" tabIndex={0}
        onClick={() => tapBuy(hero.item, hero.price, hero.id, bought)}>
        <div className="shop-hero-art">
          {!bought && <Rays size={170} />}
          <ItemArt i={hero.item} size={82} />
        </div>
        <div className="col grow" style={{ gap: 6, minWidth: 0 }}>
          <span className="shop-hero-kicker">{t('ANGEBOT DES TAGES')}</span>
          <b className="shop-hero-name">{itemTitle(hero.item, t)}</b>
          <span className="shop-hero-sub">{subtitle(hero.item)}</span>
          {priceButton(hero.price, hero.basePrice, { bought, owned: false, gated: false, affordable })}
        </div>
      </div>
    )
  })()

  const lockedCards = CARD_IDS.filter(c => !S.isCardUnlocked(c, p))
    .sort((a, b) => {
      const ta = TIERS[CARDS[a].tier], tb = TIERS[CARDS[b].tier]
      return (level >= ta.gate ? 0 : 1) - (level >= tb.gate ? 0 : 1) || ta.price - tb.price
    })

  return (
    <Sheet title={t('Splitter-Laden')} onClose={closeSheet} wide tall>
      <div className="shop2">
        <div className="shop-treasury">
          <div className="row" style={{ gap: 14, alignItems: 'center' }}>
            <span className="shop-crystal"><ShardIcon size={44} /><Icon name="sparkle" size={12} color="#fff" /></span>
            <div className="col" style={{ gap: 2 }}>
              <b className="shop-balance num">{p.shards}</b>
              <span className="muted" style={{ fontSize: 11, fontWeight: 600 }}>{t('Splitter · insgesamt {0} gesammelt', p.shardsEarned)}</span>
            </div>
          </div>
          {goal ? (
            <div className="shop-goal">
              <span className="shop-goal-art"><ItemArt i={goal.item} size={34} /></span>
              <div className="col grow" style={{ gap: 5, minWidth: 0 }}>
                <div className="row" style={{ gap: 4 }}>
                  <b className="grow shop-goal-title">{t('Sparziel: {0}', shortTitle(goal.item, t))}</b>
                  <button className="shop-goal-x" onClick={() => { S.setShardGoal(null); haptic('select') }} aria-label={t('Sparziel entfernen')}><Icon name="xCircle" size={16} /></button>
                </div>
                <Bar value={p.shards / goal.price} color="var(--gold)" />
                <span className={`num shop-goal-meta${p.shards >= goal.price ? ' ready' : ''}`}>
                  {p.shards >= goal.price ? t('Genug gesammelt – hol es dir!') : t('{0} / {1} · noch {2}', p.shards, goal.price, goal.price - p.shards)}
                </span>
              </div>
              {p.shards >= goal.price && !S.isItemOwned(goal.item, p) && (
                <button className="shop-goal-get" onClick={() => setConfirm({ item: goal.item, price: goal.price })}>{t('Holen')}<span className="shine" /></button>
              )}
            </div>
          ) : (
            <div className="row muted" style={{ gap: 8, fontSize: 11, fontWeight: 600 }}>
              <Icon name="starCircle" size={20} color="var(--gold)" />
              <span>{t('Tipp auf den Stern einer Kachel: Das wird dein Sparziel, der Fortschritt steht auf der Startseite.')}</span>
            </div>
          )}
        </div>

        <div className="shop-tabs">
          {TABS.map(([id, label, icon]) => (
            <button key={id} className={`shop-tab${tab === id ? ' on' : ''}`} onClick={() => { if (tab !== id) { haptic('select'); setTab(id) } }}>
              <Icon name={icon as 'sparkles'} size={13} />{t(label)}
            </button>
          ))}
        </div>

        <div className="shop-page" key={tab}>
          {tab === 'offers' && <>
            <div className="row"><b className="shop-h">{t('Heute im Laden')}</b><span className="spacer" /><span className="muted num" style={{ fontSize: 11, fontWeight: 700 }}><Icon name="clock" size={11} /> {t('Neu in {0}', midnight)}</span></div>
            {heroOffer}
            <div className="shop-grid2">{offers.slice(1).map(o => tile(o.item, { price: o.price, base: o.basePrice, offer: o.id }))}</div>
            <div className="shop-soon">
              <span className="shop-soon-ico"><Icon name="bag" size={20} /></span>
              <div className="col" style={{ gap: 2 }}>
                <b>{t('Bald: Splitter-Pakete')}</b>
                <span className="muted" style={{ fontSize: 11, fontWeight: 600 }}>{t('Mit der Online-Version kommen Pakete und Saison-Angebote. Bis dahin: sammeln, sparen, ausgeben!')}</span>
              </div>
            </div>
          </>}
          {tab === 'cards' && <>
            <span className="shop-intro">{t('Neue Karten für dein Deck – jede einmal kaufen, für immer behalten.')}</span>
            {lockedCards.length
              ? <div className="shop-grid2">{lockedCards.map(c => tile({ kind: 'card', card: c }))}</div>
              : <div className="shop-empty"><Icon name="seal" size={34} color="var(--blue-light)" /><b>{t('Du hast schon alle Karten. Stark!')}</b></div>}
          </>}
          {tab === 'chests' && <>
            <span className="shop-intro">{t('Truhen öffnen sich sofort – mit Chance auf Aufwertung beim Antippen.')}</span>
            <div className="shop-grid2">{tile({ kind: 'chest', rarity: 2 })}{tile({ kind: 'chest', rarity: 3 })}</div>
          </>}
          {tab === 'style' && <>
            <span className="shop-sec">{t('Avatare')}</span>
            <div className="shop-grid2">{AVATARS.filter(a => a.id !== 'knight').map(a => tile({ kind: 'avatar', avatar: a.id }))}</div>
            <span className="shop-sec">{t('Avatar-Rahmen')}</span>
            <div className="shop-grid2">{SHOP_FRAMES.map(f => tile({ kind: 'frame', frame: f }))}</div>
            <span className="shop-sec">{t('Sammelbretter')}</span>
            <div className="shop-grid2">{BOARD_THEMES.filter(isCollectibleBoard).map(b => tile({ kind: 'board', board: b }))}</div>
          </>}
          {tab === 'extras' && <>
            <span className="shop-intro">{t('Rettet deine Serie, wenn du einen Tag verpasst (max. {0})', MAX_FREEZES)}</span>
            <div className="shop-grid2">{tile({ kind: 'freeze' })}</div>
          </>}
        </div>
      </div>
      {confirm && (
        <Dialog title={t('{0} kaufen?', itemTitle(confirm.item, t))} onClose={() => setConfirm(null)}
          actions={[{ label: t('Für {0} Splitter kaufen', confirm.price), bold: true, onClick: buy }, { label: t('Abbrechen') }]} />
      )}
      {owned && (
        <div className="shop-celebrate fade-in" onClick={() => setOwned(null)} ref={el => { if (el) window.setTimeout(() => setOwned(o => (o === owned ? null : o)), 2600) }}>
          <span className="shop-celebrate-rays"><Rays size={700} /></span>
          <Confetti count={70} />
          <span className="shop-celebrate-art"><ItemArt i={owned} size={110} /></span>
          <b className="shop-celebrate-title">{t('GEHÖRT DIR!')}</b>
          <span className="shop-celebrate-name">{itemTitle(owned, t)}</span>
          <span className="muted" style={{ fontSize: 12, fontWeight: 700, marginTop: 10 }}>{t('Tippen zum Fortfahren')}</span>
        </div>
      )}
    </Sheet>
  )
}
