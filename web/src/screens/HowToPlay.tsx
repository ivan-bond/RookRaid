// Public „How to play“ page at /how-to-play – the page search engines find for „chess with cards“.
// English only for now (SEO plan, step 1). Card and ultimate names and texts come from the catalog and its English
// translation, the numbers from rookraid-rules.json, so the page never drifts from the game.
// Rendered to static HTML at build time (scripts/prerender.mjs); the browser then renders the same page again.
import rules from '../../../RookRaid/Engine/rookraid-rules.json'
import { cardArt } from '../art'
import { ARENAS, CARD_IDS, CARDS, ROLES, TIERS, ULTS, cardCost, ultCost, KEEPS_TURN, type UltId } from '../game/catalog'
import { translateIn } from '../i18n'
import { Icon } from '../ui/Icon'
import { PublicShell } from './Legal'

const en = (key: string, ...args: Array<string | number>) => translateIn('en', key, args)
const cooldown = rules.cardCooldown
const boltCooldown = rules.cardCooldowns.lightning

export const HOW_TO_PLAY_TITLE = 'How to Play Rook Raid – Chess with Cards, Mana & Ultimates'
export const HOW_TO_PLAY_DESCRIPTION =
  'Learn Rook Raid in five minutes: chess where every turn charges mana, 15 spell cards change the board and five ultimates turn the game. All rules, cards and tips.'

/** Questions people search for. Also used for the FAQPage structured data in scripts/prerender.mjs. */
export const FAQ: Array<[string, string]> = [
  ['Is Rook Raid free?', 'Yes. Rook Raid is free to play in your browser and on iPhone, with no ads and no purchases for real money.'],
  ['Do I need an account?', 'No. You can play right away as a guest. Your first online game creates an anonymous account; secure it with Apple or Google to keep your progress on every device.'],
  ['Do I need to know chess?', 'It helps, but it is not required. Rocky, the in-game guide, explains the basics, and the first battles are against friendly bots.'],
  ['How long is an online game?', `Online games use a ${5}-minute clock per player with no increment, so a game takes at most about ten minutes.`],
  ['Can I play on iPhone and in the browser with the same progress?', 'Yes. Once your account is secured with Apple or Google, trophies, cards, chests and history sync between the iPhone app and the browser.'],
  ['What happens if I lose my connection?', 'You have 45 seconds to come back. After that the game counts as lost on time. If both players are gone, the game is cancelled without changing trophies.'],
]

const ROLE_ORDER = ['attack', 'control', 'defense', 'mana', 'comeback'] as const

export function HowToPlay() {
  const ults = (Object.keys(ULTS) as UltId[]).sort((a, b) => ULTS[a].arena - ULTS[b].arena || ultCost(b) - ultCost(a))
  return (
    <PublicShell current="how-to-play" title={HOW_TO_PLAY_TITLE} fixedLang="en">
      <article className="htp" lang="en">
        <header className="htp-hero">
          <h1>How to play Rook Raid</h1>
          <p className="htp-lead">
            Rook Raid is <strong>chess with cards</strong>. You play on a normal chessboard with the normal moves, but every
            turn charges <strong>mana</strong>. Spend it on spell cards that shield, freeze or promote your pieces, or save up
            for an <strong>ultimate</strong> that can turn the whole game around. Checkmate still wins.
          </p>
          <div className="htp-cta">
            <a className="chunky gold" href="/"><Icon name="bolt" size={18} />Play free in your browser</a>
          </div>
        </header>

        <nav className="htp-toc" aria-label="On this page">
          <a href="#goal">Goal</a><a href="#turn">Your turn</a><a href="#mana">Mana</a><a href="#deck">Deck</a>
          <a href="#cards">All cards</a><a href="#ultimates">Ultimates</a><a href="#special">Special rules</a>
          <a href="#online">Online &amp; trophies</a><a href="#faq">FAQ</a>
        </nav>

        <section id="goal">
          <h2>Goal of the game</h2>
          <p>
            Checkmate the enemy king, or win when your opponent’s clock runs out. All normal chess rules apply: castling,
            en passant and promotion (you choose queen, rook, bishop or knight).
          </p>
        </section>

        <section id="turn">
          <h2>Your turn</h2>
          <ol className="htp-steps">
            <li>At the start of your turn you get <strong>+{rules.manaPerTurn} mana</strong>.</li>
            <li>Then you choose <strong>one action</strong>: a chess move, a card or your ultimate.</li>
            <li>
              Some cards are <strong>bonus actions</strong>: they don’t end your turn, so a piece move follows. You can’t play
              a second card or your ultimate in the same turn.
            </li>
          </ol>
        </section>

        <section id="mana">
          <h2>Mana</h2>
          <table className="htp-table">
            <tbody>
              <tr><th scope="row">Maximum</th><td>{rules.maxMana} mana</td></tr>
              <tr><th scope="row">Every turn</th><td>+{rules.manaPerTurn} at the start of your turn</td></tr>
              <tr><th scope="row">Good move</th><td>+{rules.goodMoveBonus} extra for a capture or a check (at most +{rules.goodMoveBonus} per turn)</td></tr>
              <tr><th scope="row">Mana cards</th><td>{en(CARDS.focus.name)}, {en(CARDS.sacrifice.name)} and {en(CARDS.drain.name)} give extra mana</td></tr>
            </tbody>
          </table>
          <p>Tactics such as forks, pins and skewers are announced on screen and count for achievements, but give no extra mana.</p>
        </section>

        <section id="deck">
          <h2>Your deck</h2>
          <p>
            Before each game you pick <strong>4 cards and 1 ultimate</strong>. Both decks are visible to both players. Your
            cards stay in your hand the whole game – nothing is drawn. After you play a card it recharges for{' '}
            <strong>{cooldown} of your turns</strong> ({en(CARDS.lightning.name)}: {boltCooldown}) before you can play it again.
          </p>
          <p>You start with four cards. The other eleven come from chests or can be bought with shards in the shop.</p>
        </section>

        <section id="cards">
          <h2>All {CARD_IDS.length} cards</h2>
          <p>Cards marked <span className="htp-bonus">Bonus</span> don’t end your turn – a piece move follows.</p>
          {ROLE_ORDER.map(role => {
            const ids = CARD_IDS.filter(c => CARDS[c].role === role).sort((a, b) => cardCost(a) - cardCost(b))
            if (!ids.length) return null
            return (
              <div key={role} className="htp-role">
                <h3 style={{ color: ROLES[role].color }}>{en(ROLES[role].name)}</h3>
                <ul className="htp-cards">
                  {ids.map(c => (
                    <li key={c}>
                      <img src={cardArt(`art-card-${c}`)} alt={`${en(CARDS[c].name)} card art`} width={56} height={72} loading="lazy" decoding="async"
                        style={{ borderColor: TIERS[CARDS[c].tier].color }} />
                      <div>
                        <h4>
                          {en(CARDS[c].name)} <span className="htp-cost">{cardCost(c)} mana</span>
                          {KEEPS_TURN[c] && <span className="htp-bonus">Bonus</span>}
                        </h4>
                        <p>{en(CARDS[c].text)}</p>
                      </div>
                    </li>
                  ))}
                </ul>
              </div>
            )
          })}
        </section>

        <section id="ultimates">
          <h2>Ultimates</h2>
          <p>
            Your ultimate charges with mana and replaces your turn. It costs {rules.ultimateCost} mana (Fortress:{' '}
            {rules.ultimateCosts.fortress}); the rest of your mana stays. New ultimates unlock in new arenas.
          </p>
          <ul className="htp-cards">
            {ults.map(u => (
              <li key={u}>
                <img src={cardArt(`art-ult-${u}`)} alt={`${en(ULTS[u].name)} ultimate art`} width={56} height={72} loading="lazy" decoding="async" className="ult" />
                <div>
                  <h3 className="htp-item">{en(ULTS[u].name)} <span className="htp-cost">{ultCost(u)} mana</span><span className="htp-arena">Arena {ULTS[u].arena}</span></h3>
                  <p>{en(ULTS[u].text)}</p>
                </div>
              </li>
            ))}
          </ul>
        </section>

        <section id="special">
          <h2>Special rules</h2>
          <ul className="htp-list">
            <li>The <strong>king</strong> is immune to cards and ultimates. The <strong>queen</strong> is immune to Freeze and Meteor.</li>
            <li>Cards and ultimates never give check.</li>
            <li><strong>Thaw:</strong> if a player who is not in check can’t move only because of Freeze, their pieces thaw – Freeze never forces a stalemate.</li>
            <li><strong>Territory:</strong> every piece controls its square and the eight around it. Your territory is tinted on the board; it shows control but gives no mana.</li>
            <li><strong>Draws:</strong> stalemate, threefold repetition, the 50-move rule (card plays reset it like pawn moves) or an accepted draw offer.</li>
          </ul>
        </section>

        <section id="online">
          <h2>Online battles, trophies and arenas</h2>
          <p>
            In <strong>Battle</strong> you meet an online opponent with a similar number of trophies; every game has a
            5-minute clock per player. A win against an equal opponent gives about +20 trophies, a loss about −20 – beating
            stronger players gives more. If nobody is found within a few seconds, a clearly labelled bot player steps in.
          </p>
          <p>Trophies take you through six arenas, each unlocking new ultimates, chests or boards:</p>
          <ol className="htp-arenas">
            {ARENAS.map(a => <li key={a.n}><strong>{en(a.name)}</strong> – from {a.trophies} trophies</li>)}
          </ol>
          <p>
            Offline you can climb the <strong>bot ladder</strong> (twelve bots in a row), solve <strong>puzzles</strong> and the
            daily puzzle, keep your <strong>daily flame</strong> burning, open <strong>chests</strong> and trade shards for
            cards, avatars and boards in the shop. Add friends with a friend code and challenge them to friendly games.
          </p>
        </section>

        <section id="faq">
          <h2>Frequently asked questions</h2>
          {FAQ.map(([q, a]) => (
            <div key={q} className="htp-faq">
              <h3>{q}</h3>
              <p>{a}</p>
            </div>
          ))}
        </section>

        <div className="htp-cta end">
          <a className="chunky gold" href="/"><Icon name="bolt" size={18} />Play Rook Raid now</a>
        </div>
      </article>
    </PublicShell>
  )
}
