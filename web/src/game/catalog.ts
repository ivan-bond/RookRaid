// Static game data, ported 1:1 from the iPhone app (Cards.swift, AI.swift, Persistence.swift,
// Chests.swift, TrophyRoad.swift, Streak.swift, Cosmetics.swift). Names are German keys that `t()` translates.
import { E } from '../engine'

export type CardId =
  | 'shield' | 'freeze' | 'bulwark' | 'sprint' | 'lightning' | 'knighting' | 'reinforce' | 'revive'
  | 'bishopize' | 'advance' | 'swap' | 'drain' | 'focus' | 'sacrifice' | 'retreat'
export type UltId = 'meteor' | 'iceAge' | 'fortress' | 'coronation' | 'rebirth'
export type Tier = 'starter' | 'common' | 'rare' | 'epic'
export type Role = 'attack' | 'control' | 'defense' | 'mana' | 'comeback'

export const CARD_IDS: CardId[] = [
  'shield', 'freeze', 'bulwark', 'sprint', 'lightning', 'knighting', 'reinforce', 'revive',
  'bishopize', 'advance', 'swap', 'drain', 'focus', 'sacrifice', 'retreat',
]
export const ULT_IDS: UltId[] = ['meteor', 'iceAge', 'fortress', 'coronation', 'rebirth']
export const DECK_SIZE = 4

type CardInfo = { name: string; short: string; text: string; prompt: string; role: Role; tier: Tier; icon: string }

export const CARDS: Record<CardId, CardInfo> = {
  shield: { name: 'Schild', short: 'Figur unschlagbar', role: 'defense', tier: 'starter', icon: 'shield',
    text: 'Eine eigene Figur kann bis zum Ende des nächsten gegnerischen Zuges nicht geschlagen werden. Danach machst du noch einen Figurzug – mit einer anderen Figur, die geschützte bleibt stehen.',
    prompt: 'Wähle eine eigene Figur.' },
  freeze: { name: 'Frost', short: 'Figur eingefroren', role: 'control', tier: 'starter', icon: 'snowflake',
    text: 'Eine gegnerische Figur – nicht König oder Dame – kann in ihrem nächsten Zug nicht ziehen (sie bedroht aber weiter Felder). Danach machst du noch einen Figurzug.',
    prompt: 'Wähle eine gegnerische Figur (nicht König oder Dame).' },
  bulwark: { name: 'Bollwerk', short: 'Bauern geschützt', role: 'defense', tier: 'common', icon: 'columns',
    text: 'Alle eigenen Bauern sind bis zum Ende des nächsten gegnerischen Zuges geschützt. Danach machst du noch einen Figurzug.',
    prompt: '' },
  sprint: { name: 'Sturmlauf', short: 'Bauer +2 Felder', role: 'attack', tier: 'starter', icon: 'hare',
    text: 'Ein eigener Bauer rückt sofort 2 Felder vor (beide Felder müssen frei sein). Danach machst du noch einen Figurzug mit einer anderen Figur.',
    prompt: 'Wähle einen eigenen Bauern.' },
  lightning: { name: 'Blitz', short: 'Bauer vernichten', role: 'control', tier: 'starter', icon: 'bolt',
    text: 'Vernichtet einen gegnerischen Bauern, der in deine Hälfte vorgerückt ist – nur Schild und Bollwerk schützen ihn. Lädt 3 Züge nach.',
    prompt: 'Wähle einen gegnerischen Bauern in deiner Hälfte.' },
  knighting: { name: 'Ritterschlag', short: 'Bauer → Springer', role: 'attack', tier: 'common', icon: 'star',
    text: 'Ein eigener Bauer wird zum Springer.', prompt: 'Wähle einen eigenen Bauern.' },
  reinforce: { name: 'Verstärkung', short: 'Neuer Bauer', role: 'defense', tier: 'common', icon: 'plusCircle',
    text: 'Ein neuer Bauer erscheint auf einem freien Feld deiner zweiten Reihe.', prompt: 'Wähle ein freies Feld auf deiner zweiten Reihe.' },
  revive: { name: 'Wiederkehr', short: 'Figur kehrt zurück', role: 'comeback', tier: 'rare', icon: 'heartCircle',
    text: 'Dein wertvollster geschlagener Turm, Läufer oder Springer kehrt auf deine Grundreihe zurück.', prompt: 'Wähle ein freies Feld auf deiner Grundreihe.' },
  bishopize: { name: 'Läuferweihe', short: 'Bauer → Läufer', role: 'attack', tier: 'epic', icon: 'diamond',
    text: 'Ein eigener Bauer wird zum Läufer.', prompt: 'Wähle einen eigenen Bauern.' },
  advance: { name: 'Vormarsch', short: 'Alle Bauern vor', role: 'attack', tier: 'common', icon: 'arrowUpSquare',
    text: 'Alle eigenen Bauern rücken ein Feld vor, sofern das Feld davor frei ist. Auf die letzte Reihe zieht so kein Bauer. Danach machst du noch einen Figurzug.',
    prompt: '' },
  swap: { name: 'Leibwache', short: 'König tauscht', role: 'defense', tier: 'rare', icon: 'swap',
    text: 'Dein König tauscht den Platz mit einer eigenen Figur (kein Bauer). Danach darf der König nicht mehr rochieren. Danach machst du noch einen Figurzug.',
    prompt: 'Wähle die Figur, mit der dein König tauscht.' },
  drain: { name: 'Manaraub', short: 'Halbes Gegner-Mana', role: 'control', tier: 'epic', icon: 'dropTriangle',
    text: 'Dein Gegner verliert die Hälfte seines Manas (abgerundet), du erhältst 2 Mana. Ideal, bevor er seine Ultimate zündet.',
    prompt: '' },
  focus: { name: 'Konzentration', short: '+4 Mana', role: 'mana', tier: 'epic', icon: 'brain',
    text: 'Du sammelst dich: +4 Mana.', prompt: '' },
  sacrifice: { name: 'Bauernopfer', short: 'Bauer für 3 Mana', role: 'mana', tier: 'rare', icon: 'heartSlash',
    text: 'Opfere einen eigenen Bauern und erhalte 3 Mana. Danach machst du noch einen Figurzug.', prompt: 'Wähle den Bauern, den du opferst.' },
  retreat: { name: 'Rückzug', short: 'Bauer bis 2 zurück', role: 'defense', tier: 'common', icon: 'arrowDownSquare',
    text: 'Ein eigener Bauer weicht 1 oder 2 Felder zurück (der Weg muss frei sein, nicht auf die Grundreihe). Danach machst du noch einen Figurzug mit einer anderen Figur.',
    prompt: 'Wähle das Feld, auf das dein Bauer zurückweicht.' },
}

export const KEEPS_TURN: Record<string, boolean> = {
  shield: true, freeze: true, bulwark: true, sprint: true, sacrifice: true, advance: true, swap: true, retreat: true,
}
export const LOCKS_TARGET = (c: string) => c === 'shield' || c === 'retreat'
export const cardCost = (c: string) => E.COST[c] ?? 0
export const isCard = (id: string): id is CardId => (CARD_IDS as string[]).includes(id)
export const isUlt = (id: string): id is UltId => (ULT_IDS as string[]).includes(id)

export const TIERS: Record<Tier, { name: string; color: string; price: number; gate: number; weight: number }> = {
  starter: { name: 'Start', color: '#A9B4C8', price: 0, gate: 1, weight: 0 },
  common: { name: 'Gewöhnlich', color: '#6FBF73', price: 500, gate: 1, weight: 3 },
  rare: { name: 'Selten', color: '#3FA9F5', price: 1500, gate: 5, weight: 2 },
  epic: { name: 'Episch', color: '#B06CFF', price: 3000, gate: 10, weight: 1 },
}

export const ROLES: Record<Role, { name: string; icon: string; color: string }> = {
  attack: { name: 'Angriff', icon: 'flame', color: '#E0613A' },
  control: { name: 'Kontrolle', icon: 'snowflake', color: '#5BB5D9' },
  defense: { name: 'Verteidigung', icon: 'shield', color: '#6FBF73' },
  mana: { name: 'Mana', icon: 'drop', color: '#8B5CF6' },
  comeback: { name: 'Comeback', icon: 'undo', color: '#F2C14E' },
}

type UltInfo = { name: string; icon: string; text: string; style: string; arena: number; prompt: string }
export const ULTS: Record<UltId, UltInfo> = {
  meteor: { name: 'Meteor', icon: 'flame', style: 'Angriff', arena: 1, prompt: 'Meteor: Wähle die gegnerische Figur.',
    text: 'Vernichtet eine gegnerische Figur – außer König und Dame. Ungeschützte gegnerische Bauern direkt daneben können zwei Züge lang nicht ziehen.' },
  iceAge: { name: 'Eiszeit', icon: 'windSnow', style: 'Tempo', arena: 2, prompt: '',
    text: 'Alle gegnerischen Figuren außer dem König können in den nächsten zwei Zügen nicht ziehen.' },
  fortress: { name: 'Festung', icon: 'shieldHalf', style: 'Verteidigung', arena: 1, prompt: '',
    text: 'Keine deiner Figuren kann bis zum Ende des nächsten gegnerischen Zuges geschlagen werden. Danach machst du noch einen Figurzug – der darf aber nicht schlagen und kein Schach geben.' },
  coronation: { name: 'Krönung', icon: 'crown', style: 'Angriff', arena: 2, prompt: 'Krönung: Wähle den Bauern, der zur Dame wird.',
    text: 'Ein eigener Bauer wird sofort zur Dame. Hast du noch eine Dame, muss der Bauer in der gegnerischen Hälfte stehen.' },
  rebirth: { name: 'Wiedergeburt', icon: 'undoCircle', style: 'Comeback', arena: 3, prompt: '',
    text: 'Deine wertvollste geschlagene Figur (auch die Dame) kehrt auf deine Grundreihe zurück.' },
}
export const ultCost = (u: string) => E.ultCost(u)

export function cardArtKey(id: string): string {
  return isUlt(id) ? `art-ult-${id}` : `art-card-${id}`
}

export type Preset = { id: string; name: string; strategy: string; icon: string; cards: CardId[]; ultimate: UltId }
export const PRESETS: Preset[] = [
  { id: 'sturm', name: 'Sturmangriff', icon: 'flame', cards: ['sprint', 'advance', 'knighting', 'lightning'], ultimate: 'coronation',
    strategy: 'Bauern nach vorn, Gebiet erobern, Figuren befördern. Krönung macht einen vorgestürmten Bauern zur zweiten Dame.' },
  { id: 'eis', name: 'Eiskönig', icon: 'snowflake', cards: ['freeze', 'drain', 'lightning', 'shield'], ultimate: 'iceAge',
    strategy: 'Wichtige Figuren einfrieren und dem Gegner das Mana stehlen. Eiszeit legt die ganze Armee lahm.' },
  { id: 'festung', name: 'Festung', icon: 'columns', cards: ['shield', 'bulwark', 'reinforce', 'knighting'], ultimate: 'fortress',
    strategy: 'Nichts hergeben: Schutz für Figuren und Bauern, Nachschub auf der zweiten Reihe – und aus Bauern werden Springer. Festung schützt alles und erlaubt noch einen Zug.' },
  { id: 'ritual', name: 'Ritual', icon: 'drop', cards: ['focus', 'sacrifice', 'drain', 'lightning'], ultimate: 'meteor',
    strategy: 'Mana sammeln, so schnell es geht – und mit dem Meteor früher und öfter zuschlagen als der Gegner.' },
  { id: 'phoenix', name: 'Phönix', icon: 'undoCircle', cards: ['revive', 'reinforce', 'sacrifice', 'bishopize'], ultimate: 'rebirth',
    strategy: 'Verluste zahlen sich aus: Geschlagene Figuren kehren zurück, Bauern werden zu Läufern. Wiedergeburt holt sogar die Dame.' },
  { id: 'taktik', name: 'Taktiker', icon: 'scope', cards: ['shield', 'freeze', 'swap', 'sprint'], ultimate: 'meteor',
    strategy: 'Bonusaktionen für Doppelschläge: einfrieren, schützen, vorstoßen – und dann zuschlagen.' },
]
export const STARTER_PRESET: Preset = { id: 'start', name: 'Grundausstattung', icon: 'stack', cards: ['lightning', 'shield', 'sprint', 'freeze'],
  ultimate: 'meteor', strategy: 'Ein ausgewogenes Deck für den Anfang.' }

// MARK: Bots

export type BotId = 'easy' | 'apprentice' | 'medium' | 'jester' | 'knight' | 'tactician' | 'shadow' | 'baron' | 'hard' | 'frost' | 'sphinx' | 'queen'
export type Bot = {
  id: BotId; tier: number; name: string; title: string; motto: string; icon: string; color: string; skin: string
  ult: UltId; deck: CardId[]; xpFirstWin: number
  search: { depth: number; deepProb: number; qDepth: number; qProb: number; noise: number; blunder: number; nodes: number; time: number; cardSkill: number; targetLimit: number; smart: boolean; v2: boolean; replies: boolean; v3: boolean; tt: boolean }
}
const BOT_ROWS: Array<[BotId, string, string, string, string, string, string, UltId, CardId[], number, Bot['search']]> = [
  ['easy', 'Bruno', 'der Bauer', 'Schiebt gern Bauern und vergisst dabei seine Figuren.', 'leaf', '#6FBF73', 'Grüner Hain', 'fortress', ['reinforce', 'bulwark', 'sprint', 'retreat'], 30,
    { depth: 1, deepProb: 1, qDepth: 2, noise: 0.75, blunder: 0.07, nodes: 12000, time: 0.4, qProb: 1, cardSkill: 0.65, targetLimit: 4, smart: false, v2: false, replies: false, v3: false, tt: false }],
  ['apprentice', 'Lotte', 'die Lehrling', 'Kennt die Regeln, aber noch nicht die Fallen.', 'book', '#5BB5D9', 'Bibliothek', 'meteor', ['lightning', 'shield', 'sprint', 'freeze'], 35,
    { depth: 2, deepProb: 0.6, qDepth: 3, noise: 0.4, blunder: 0.03, nodes: 30000, time: 0.5, qProb: 1, cardSkill: 0.8, targetLimit: 5, smart: false, v2: true, replies: false, v3: false, tt: false }],
  ['medium', 'Mila', 'die Magierin', 'Spielt Karten, wann immer sie kann.', 'wand', '#8B5CF6', 'Sternenzauber', 'iceAge', ['freeze', 'drain', 'focus', 'lightning'], 40,
    { depth: 2, deepProb: 1, qDepth: 3, noise: 0.26, blunder: 0.015, nodes: 60000, time: 0.6, qProb: 1, cardSkill: 0.9, targetLimit: 6, smart: false, v2: true, replies: true, v3: false, tt: false }],
  ['jester', 'Kasimir', 'der Gaukler', 'Liebt Tricks – und fällt manchmal auf seine eigenen herein.', 'masks', '#F06BA8', 'Harlekin', 'coronation', ['swap', 'sprint', 'sacrifice', 'knighting'], 50,
    { depth: 3, deepProb: 0.65, qDepth: 4, noise: 0.16, blunder: 0.008, nodes: 110000, time: 0.8, qProb: 1, cardSkill: 1, targetLimit: 8, smart: false, v2: true, replies: true, v3: false, tt: false }],
  ['knight', 'Sir Konrad', 'der Ritter', 'Liebt Springergabeln und Angriffe auf den König.', 'shieldHalf', '#2F6FE4', 'Silberwacht', 'coronation', ['knighting', 'sprint', 'shield', 'advance'], 60,
    { depth: 3, deepProb: 1, qDepth: 5, noise: 0.12, blunder: 0.004, nodes: 180000, time: 1, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
  ['tactician', 'Frieda Falk', 'die Taktikerin', 'Lauert auf Fesselungen und offene Figuren.', 'scope', '#E39B3A', 'Falkenauge', 'meteor', ['shield', 'freeze', 'swap', 'sprint'], 70,
    { depth: 4, deepProb: 1, qDepth: 5, noise: 0.05, blunder: 0.0015, nodes: 380000, time: 1.6, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
  ['shadow', 'Nox', 'der Schatten', 'Schleicht sich an – und schlägt zu, wenn du nicht hinsiehst.', 'moon', '#5A4E9C', 'Mitternacht', 'meteor', ['freeze', 'lightning', 'advance', 'sprint'], 80,
    { depth: 5, deepProb: 0.7, qDepth: 5, noise: 0.01, blunder: 0, nodes: 700000, time: 2.2, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
  ['baron', 'Baron Rabe', 'der Verteidiger', 'Verteidigt zäh und schlägt spät zurück.', 'columns', '#7E8AA3', 'Rabenfeste', 'fortress', ['freeze', 'advance', 'shield', 'focus'], 95,
    { depth: 5, deepProb: 0.8, qDepth: 6, noise: 0.01, blunder: 0, nodes: 800000, time: 2.4, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
  ['hard', 'Viktor', 'der Vernichter', 'Rechnet weit voraus und verzeiht keinen Fehler.', 'bolt', '#E0413A', 'Glutriss', 'rebirth', ['freeze', 'advance', 'shield', 'focus'], 110,
    { depth: 5, deepProb: 1, qDepth: 6, noise: 0, blunder: 0, nodes: 1200000, time: 3, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
  ['frost', 'Magnus Frost', 'der Eisherr', 'Friert dein Spiel ein, bis nichts mehr geht.', 'snowflake', '#7FD3F5', 'Ewiges Eis', 'iceAge', ['freeze', 'advance', 'shield', 'focus'], 130,
    { depth: 6, deepProb: 1, qDepth: 6, noise: 0, blunder: 0, nodes: 2000000, time: 4.5, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
  ['sphinx', 'Die Sphinx', 'die Allwissende', 'Kennt jede Antwort, bevor du die Frage stellst.', 'eye', '#C9A96E', 'Wüstenorakel', 'rebirth', ['freeze', 'advance', 'focus', 'sprint'], 150,
    { depth: 7, deepProb: 1, qDepth: 7, noise: 0, blunder: 0, nodes: 3000000, time: 6, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
  ['queen', 'Die Turmkönigin', 'Herrin der Arena', 'Der Endgegner von Rook Raid.', 'crown', '#F2C14E', 'Goldene Krone', 'iceAge', ['freeze', 'advance', 'swap', 'focus'], 200,
    { depth: 8, deepProb: 1, qDepth: 8, noise: 0, blunder: 0, nodes: 4500000, time: 8, qProb: 1, cardSkill: 1, targetLimit: 8, smart: true, v2: true, replies: true, v3: true, tt: true }],
]
export const BOTS: Bot[] = BOT_ROWS.map(([id, name, title, motto, icon, color, skin, ult, deck, xpFirstWin, search], i) => ({
  id, tier: i + 1, name, title, motto, icon, color, skin, ult, deck, xpFirstWin, search,
}))
export const TROPHIES_PER_TIER = 200
export const botById = (id: string) => BOTS.find(b => b.id === id) ?? BOTS[0]
export const botForTrophies = (t: number) => BOTS[Math.min(BOTS.length - 1, Math.max(0, Math.floor(t / TROPHIES_PER_TIER)))]
export const botTrophyStart = (b: Bot) => (b.tier - 1) * TROPHIES_PER_TIER
export const botRating = (b: Bot) => botTrophyStart(b) + TROPHIES_PER_TIER / 2
/** History key, kept in German like the app (`botName`). */
export const botRecordName = (b: Bot) => 'Bot ' + b.name
export function ladderChest(b: Bot): ChestRarity {
  if (b.tier <= 3) return 1
  if (b.tier <= 7) return 2
  if (b.tier <= 10) return 3
  return 4
}

// MARK: Arenas

export type Arena = { n: number; name: string; trophies: number; mechanic: string; icon: string }
export const ARENAS: Arena[] = [
  { n: 1, name: 'Trainingsgelände', trophies: 0, mechanic: 'Ultimates Meteor und Festung', icon: 'walk' },
  { n: 2, name: 'Kasernenhof', trophies: 90, mechanic: 'Eiszeit, Krönung + Magische Truhe', icon: 'shieldHalf' },
  { n: 3, name: 'Thronarena', trophies: 240, mechanic: 'Wiedergeburt + Legendäre Truhe', icon: 'crown' },
  { n: 4, name: 'Sturmfeste', trophies: 600, mechanic: 'Magische Truhe + Lava-Brett in Reichweite', icon: 'cloudBolt' },
  { n: 5, name: 'Drachenhort', trophies: 1200, mechanic: 'Legendäre Truhe + Mitternachts-Brett', icon: 'flame' },
  { n: 6, name: 'Königsgipfel', trophies: 2100, mechanic: 'Legendäre Truhe · Gegner: Sphinx und Turmkönigin', icon: 'mountain' },
]
export const arenaFor = (t: number) => [...ARENAS].reverse().find(a => t >= a.trophies) ?? ARENAS[0]
/** Arena colours (ArenaPalette): [glow, deep]. */
export const ARENA_PALETTE: Record<number, [string, string]> = {
  1: ['#2FAE8F', '#16584C'], 2: ['#5E86C9', '#27406E'], 3: ['#A066E0', '#4B2A7A'],
  4: ['#3BB8E0', '#1B4E72'], 5: ['#F0623E', '#7A1F1A'], 6: ['#F7C64A', '#8A5A10'],
}

// MARK: Boards

export type BoardTheme = 'green' | 'brown' | 'blue' | 'purple' | 'lava' | 'emerald' | 'midnight'
export const BOARD_THEMES: BoardTheme[] = ['green', 'brown', 'blue', 'purple', 'lava', 'emerald', 'midnight']
export const BOARD_NAMES: Record<BoardTheme, string> = {
  green: 'Rook Raid', brown: 'Holz', blue: 'Eis', purple: 'Arkan', lava: 'Lava', emerald: 'Smaragd', midnight: 'Mitternacht',
}
export const isCollectibleBoard = (b: BoardTheme) => b === 'lava' || b === 'emerald' || b === 'midnight'
export const BOARD_PRICE = 300

type BoardColors = { light: string; dark: string; lightMine: string; darkMine: string; lightTheirs: string; darkTheirs: string }
function mix(a: string, b: string, t: number): string {
  const pa = parseInt(a.slice(1), 16), pb = parseInt(b.slice(1), 16)
  const ch = (v: number, s: number) => (v >> s) & 255
  const out = [16, 8, 0].map(s => Math.round(ch(pa, s) + (ch(pb, s) - ch(pa, s)) * t))
  return '#' + out.map(v => v.toString(16).padStart(2, '0')).join('')
}
function derived(light: string, dark: string): BoardColors {
  return { light, dark, lightMine: mix(light, '#FFFFFF', 0.6), darkMine: mix(dark, '#FFFFFF', 0.2),
    lightTheirs: mix(light, '#8C2620', 0.12), darkTheirs: mix(dark, '#3A1A2A', 0.25) }
}
export const BOARD_COLORS: Record<BoardTheme, BoardColors> = {
  green: { light: '#F1E8D4', dark: '#6F87B0', lightMine: '#F8F3E8', darkMine: '#88A3CF', lightTheirs: '#E8D2C8', darkTheirs: '#76708F' },
  brown: derived('#F0D9B5', '#B58863'),
  blue: derived('#EAE9D2', '#4B7399'),
  purple: derived('#EFEFEF', '#8877B7'),
  lava: derived('#F6DCC8', '#B4513A'),
  emerald: derived('#E4F0DE', '#3E8A62'),
  midnight: derived('#C9D2E6', '#34406A'),
}

// MARK: Chests

/** 0 wood · 1 silver · 2 gold · 3 magic · 4 legendary */
export type ChestRarity = 0 | 1 | 2 | 3 | 4
export const CHEST: Array<{ name: string; short: string; shout: string; body: string; light: string; dark: string; glow: string; up: number; xp: number; shards: number; card: number; board: number }> = [
  { name: 'Holztruhe', short: 'Holz', shout: 'HOLZ', body: '#9A6A3C', light: '#C8955E', dark: '#5E3B1E', glow: '#E8B57A', up: 0.35, xp: 5, shards: 5, card: 0.015, board: 0 },
  { name: 'Silbertruhe', short: 'Silber', shout: 'SILBER!', body: '#9AA6B8', light: '#E3E9F2', dark: '#5B6577', glow: '#D9E6FF', up: 0.25, xp: 10, shards: 10, card: 0.03, board: 0 },
  { name: 'Goldtruhe', short: 'Gold', shout: 'GOLD!', body: '#E0A82E', light: '#FFE08A', dark: '#8F5F0C', glow: '#FFD45C', up: 0.15, xp: 20, shards: 20, card: 0.05, board: 0 },
  { name: 'Magische Truhe', short: 'Magisch', shout: 'MAGISCH!', body: '#8B4FE0', light: '#C9A2FF', dark: '#4B2391', glow: '#C28BFF', up: 0.08, xp: 40, shards: 40, card: 0.12, board: 0.1 },
  { name: 'Legendäre Truhe', short: 'Legendär', shout: 'LEGENDÄR!!', body: '#F2603A', light: '#FFD27A', dark: '#9C2A12', glow: '#FFB347', up: 0, xp: 80, shards: 100, card: 0.4, board: 0.4 },
]
export type ChestSource = 'tutorial' | 'win' | 'daily' | 'ladder' | 'puzzle' | 'level' | 'arena' | 'welcome' | 'road' | 'streak' | 'shop'
export const CHEST_SOURCE: Record<ChestSource, { title: string; icon: string }> = {
  tutorial: { title: 'Erste Truhe', icon: 'sparkles' }, win: { title: 'Siegtruhe', icon: 'trophy' },
  daily: { title: 'Tagestruhe', icon: 'calendar' }, ladder: { title: 'Leiter-Truhe', icon: 'stairs' },
  puzzle: { title: 'Rätseltruhe', icon: 'puzzle' }, level: { title: 'Level-Truhe', icon: 'arrowUpCircle' },
  arena: { title: 'Arena-Truhe', icon: 'flag' }, welcome: { title: 'Willkommensgeschenk', icon: 'gift' },
  road: { title: 'Trophäenpfad', icon: 'trophy' }, streak: { title: 'Flammentruhe', icon: 'flame' },
  shop: { title: 'Laden-Truhe', icon: 'bag' },
}
export const CHARGE_TAPS = 3
export const WIN_CHESTS_PER_DAY = 3
export const PUZZLES_PER_CHEST = 5
export const PITY_LIMIT = 18
export const JACKPOT_SHARDS = 150
export const COSMETIC_CHANCE = [0.03, 0.06, 0.12, 0.25, 0.5]

export type Guarantee = { card: CardId } | { tier: Tier }
export function levelStep(level: number): { level: number; rarity: ChestRarity; guarantee?: Guarantee } {
  const table: Record<number, [ChestRarity, Guarantee?]> = {
    2: [1, { card: 'knighting' }], 3: [1], 4: [2, { card: 'bulwark' }], 5: [2, { card: 'advance' }], 6: [2, { tier: 'rare' }],
    7: [2], 8: [3, { tier: 'rare' }], 9: [2], 10: [3, { tier: 'epic' }], 11: [2, { tier: 'rare' }], 12: [3, { tier: 'epic' }],
    13: [2], 14: [4, { tier: 'epic' }],
  }
  const row = table[level]
  if (row) return { level, rarity: row[0], guarantee: row[1] }
  return { level, rarity: level % 5 === 0 ? 4 : 2 }
}

// MARK: Trophy road

export type RoadReward = { kind: 'chest'; rarity: ChestRarity } | { kind: 'shards'; n: number } | { kind: 'board'; board: BoardTheme } | { kind: 'arena'; arena: number; rarity: ChestRarity }
export type RoadStep = { trophies: number; reward: RoadReward }
export const ROAD: RoadStep[] = [
  { trophies: 50, reward: { kind: 'chest', rarity: 1 } },
  { trophies: 90, reward: { kind: 'arena', arena: 2, rarity: 3 } },
  { trophies: 150, reward: { kind: 'shards', n: 100 } },
  { trophies: 200, reward: { kind: 'chest', rarity: 2 } },
  { trophies: 240, reward: { kind: 'arena', arena: 3, rarity: 4 } },
  { trophies: 300, reward: { kind: 'board', board: 'emerald' } },
  { trophies: 400, reward: { kind: 'chest', rarity: 2 } },
  { trophies: 500, reward: { kind: 'shards', n: 200 } },
  { trophies: 600, reward: { kind: 'arena', arena: 4, rarity: 3 } },
  { trophies: 700, reward: { kind: 'chest', rarity: 2 } },
  { trophies: 800, reward: { kind: 'board', board: 'lava' } },
  { trophies: 900, reward: { kind: 'chest', rarity: 3 } },
  { trophies: 1000, reward: { kind: 'shards', n: 300 } },
  { trophies: 1100, reward: { kind: 'chest', rarity: 2 } },
  { trophies: 1200, reward: { kind: 'arena', arena: 5, rarity: 4 } },
  { trophies: 1350, reward: { kind: 'chest', rarity: 3 } },
  { trophies: 1500, reward: { kind: 'board', board: 'midnight' } },
  { trophies: 1650, reward: { kind: 'chest', rarity: 2 } },
  { trophies: 1800, reward: { kind: 'chest', rarity: 3 } },
  { trophies: 1950, reward: { kind: 'shards', n: 500 } },
  { trophies: 2100, reward: { kind: 'arena', arena: 6, rarity: 4 } },
  { trophies: 2400, reward: { kind: 'chest', rarity: 4 } },
]

// MARK: Flame streak

export const MAX_FREEZES = 2
export const FREEZE_PRICE = 200
export const STREAK_MILESTONES: Array<{ days: number; chest?: ChestRarity; shards: number; freeze: boolean }> = [
  { days: 3, shards: 25, freeze: false },
  { days: 7, chest: 2, shards: 0, freeze: true },
  { days: 14, shards: 100, freeze: false },
  { days: 30, chest: 3, shards: 0, freeze: true },
  { days: 50, shards: 250, freeze: false },
  { days: 100, chest: 4, shards: 0, freeze: true },
  { days: 365, chest: 4, shards: 1000, freeze: true },
]
export const FLAME_TIERS: Array<{ days: number; name: string; colors: [string, string, string]; embers: number }> = [
  { days: 1, name: 'Funke', colors: ['#FF7A2F', '#FFB347', '#FFF1A8'], embers: 6 },
  { days: 7, name: 'Lagerfeuer', colors: ['#F0452E', '#FF9A3C', '#FFE27A'], embers: 10 },
  { days: 30, name: 'Blaue Flamme', colors: ['#2F6FE4', '#6CC8FF', '#E6F7FF'], embers: 12 },
  { days: 100, name: 'Inferno', colors: ['#8B3FD9', '#E15BD1', '#FFD1F4'], embers: 14 },
  { days: 365, name: 'Ewige Flamme', colors: ['#E0A82E', '#FFE08A', '#FFFFFF'], embers: 18 },
]
export const flameTier = (days: number) => [...FLAME_TIERS].reverse().find(f => days >= f.days) ?? FLAME_TIERS[0]

// MARK: Cosmetics

export type CosmeticRarity = 0 | 1 | 2 | 3
export const COSMETIC_RARITY = [
  { name: 'Gewöhnlich', color: '#6FBF73', weight: 3 },
  { name: 'Selten', color: '#3FA9F5', weight: 2 },
  { name: 'Episch', color: '#B06CFF', weight: 1 },
  { name: 'Legendär', color: '#FFB648', weight: 0.4 },
]
export type AvatarId = 'knight' | 'fox' | 'owl' | 'bear' | 'penguin' | 'frog' | 'wolf' | 'lion' | 'robot' | 'nachtross' | 'wizard' | 'dragon' | 'phoenix'
export const AVATARS: Array<{ id: AvatarId; name: string; rarity: CosmeticRarity }> = [
  { id: 'knight', name: 'Springer', rarity: 0 }, { id: 'fox', name: 'Fuchs', rarity: 0 }, { id: 'owl', name: 'Eule', rarity: 0 },
  { id: 'bear', name: 'Bär', rarity: 0 }, { id: 'penguin', name: 'Pinguin', rarity: 0 }, { id: 'frog', name: 'Frosch', rarity: 0 },
  { id: 'wolf', name: 'Wolf', rarity: 1 }, { id: 'lion', name: 'Löwe', rarity: 1 }, { id: 'robot', name: 'Roboter', rarity: 1 },
  { id: 'nachtross', name: 'Nachtross', rarity: 1 }, { id: 'wizard', name: 'Magier', rarity: 2 }, { id: 'dragon', name: 'Drache', rarity: 2 },
  { id: 'phoenix', name: 'Phönix', rarity: 3 },
]
export const AVATAR_PRICE = [250, 600, 1200, 2000]
export const avatarPrice = (id: AvatarId) => AVATAR_PRICE[AVATARS.find(a => a.id === id)?.rarity ?? 0]

export type FrameId = 'none' | 'silver' | 'gold' | 'flame' | 'crown' | 'puzzle' | 'legendary' | 'ruby' | 'nebula' | 'prism'
export const FRAMES: Record<FrameId, { name: string; colors: [string, string]; icon?: string; rarity: CosmeticRarity }> = {
  none: { name: 'Ohne', colors: ['#5B7FC7', '#3A5A9E'], rarity: 0 },
  silver: { name: 'Silber', colors: ['#F2F5FA', '#9AA6B8'], rarity: 0 },
  gold: { name: 'Gold', colors: ['#FFE27A', '#C98A1B'], rarity: 0 },
  flame: { name: 'Flamme', colors: ['#FFD25E', '#FF5A2B'], icon: 'flame', rarity: 0 },
  crown: { name: 'Krone', colors: ['#FFF0A8', '#B06CFF'], icon: 'crown', rarity: 0 },
  puzzle: { name: 'Rätsel', colors: ['#8CF0B0', '#2C9C8C'], icon: 'puzzle', rarity: 0 },
  legendary: { name: 'Legendär', colors: ['#FF7AD9', '#7A5CFF'], icon: 'sparkles', rarity: 0 },
  ruby: { name: 'Rubin', colors: ['#FF8A9A', '#C2183B'], icon: 'diamond', rarity: 1 },
  nebula: { name: 'Nebel', colors: ['#9AE6FF', '#5B3FD1'], icon: 'moon', rarity: 2 },
  prism: { name: 'Prisma', colors: ['#B8FFF3', '#FF9DE6'], icon: 'rays', rarity: 3 },
}
export const FRAME_IDS = Object.keys(FRAMES) as FrameId[]
export const SHOP_FRAMES: FrameId[] = ['ruby', 'nebula', 'prism']
export const SHOP_FRAME_PRICE = 500
export const CHEST_TITLES: Array<{ title: string; rarity: CosmeticRarity }> = [
  { title: 'Glückspilz', rarity: 0 }, { title: 'Bauernschreck', rarity: 0 }, { title: 'Springer-Ass', rarity: 0 },
  { title: 'Turmstürmer', rarity: 0 }, { title: 'Kartenhai', rarity: 1 }, { title: 'Frostfürst', rarity: 1 },
  { title: 'Blitzschläger', rarity: 1 }, { title: 'Gambit-Genie', rarity: 2 }, { title: 'Meteorbändiger', rarity: 2 },
  { title: 'Kronjuwel', rarity: 3 },
]
export const CHEST_PRICES: Record<number, number> = { 1: 60, 2: 220, 3: 600, 4: 900 }

export function rankFor(level: number): string {
  if (level < 3) return 'Bauer'
  if (level < 5) return 'Knappe'
  if (level < 8) return 'Ritter'
  if (level < 11) return 'Turmwächter'
  return 'Großmeister'
}

export type TimeControl = 'none' | 'blitz3' | 'rapid5' | 'rapid10' | 'blitz5'
export const TIME_CONTROLS: Record<TimeControl, { name: string; seconds: number; inc: number }> = {
  none: { name: 'Ohne Uhr', seconds: 0, inc: 0 },
  blitz3: { name: '3 | 2', seconds: 180, inc: 2 },
  rapid5: { name: '5 | 3', seconds: 300, inc: 3 },
  rapid10: { name: '10 | 5', seconds: 600, inc: 5 },
  blitz5: { name: '5 | 0', seconds: 300, inc: 0 },
}

export const FLAME = { lit: '#FF7A2F', glow: '#FFB347', off: '#5A6785', ice: '#6CC8FF', iceDark: '#2E7FB8' }
