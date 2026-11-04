import { botCard, botForTrophies } from './bot'
import { RULES_VERSION } from './engine'
import { playerCard, snapshot } from './profile'
import { appleIdToken, supabase } from './supabase'

export type PlayerCard = ReturnType<typeof playerCard>

export type OnlineStart = {
  matchId: string
  bot: boolean
  youWhite: boolean
  opponent: PlayerCard
  decks: { white: string[]; black: string[] }
  ultimates: { white: string; black: string }
  clockWhiteMs: number
  clockBlackMs: number
  startedAt: number
}

function client() {
  if (!supabase) throw new Error('offline')
  return supabase
}

export async function signInWithApple() {
  const db = client()
  const { token, nonce } = await appleIdToken()
  const { error } = await db.auth.signInWithIdToken({ provider: 'apple', token, nonce })
  if (error) throw error
}

export async function linkApple() {
  const db = client()
  const { token, nonce } = await appleIdToken()
  const { error } = await db.auth.linkIdentity({ provider: 'apple', token, nonce })
  if (error) throw error
}

export async function signOut() {
  await supabase?.auth.signOut()
}

export async function deleteAccount() {
  const db = client()
  const { error } = await db.functions.invoke('delete-account')
  if (error) throw error
  await db.auth.signOut()
}

export async function findOnlineMatch(deck: string[], ultimate: string): Promise<OnlineStart> {
  const db = client()
  const card = playerCard()
  const params = {
    p_rules_version: RULES_VERSION,
    p_time_control: 'blitz5',
    p_deck: deck,
    p_ultimate: ultimate,
    p_card: card,
  }
  const started = Date.now()
  while (Date.now() - started < 10_000) {
    const { data, error } = await db.rpc('find_match', params)
    if (error) throw error
    if (data) return loadMatch(String(data))
    await new Promise(resolve => setTimeout(resolve, 2000))
  }
  const level = botForTrophies(card.trophies)
  const humanWhite = Math.random() < 0.5
  const { data, error } = await db.rpc('start_bot_match', {
    ...params,
    p_bot_card: botCard(level, card.trophies),
    p_bot_deck: [...level.deck],
    p_bot_ultimate: level.ult,
    p_human_white: humanWhite,
  })
  if (error) throw error
  const row = Array.isArray(data) ? data[0] : data
  if (!row?.match_id) throw new Error('server')
  return loadMatch(row.match_id)
}

export async function cancelSearch() {
  await supabase?.rpc('cancel_matchmaking')
}

type MatchRow = {
  white: string | null
  black: string | null
  white_card: PlayerCard
  black_card: PlayerCard
  is_bot: boolean
  setup: { decks: { white: string[]; black: string[] }; ultimates: { white: string; black: string } }
  clock_white_ms: number
  clock_black_ms: number
  clock_started_at: string
}

export async function loadMatch(id: string): Promise<OnlineStart> {
  const db = client()
  const { data, error } = await db.from('matches')
    .select('white,black,white_card,black_card,is_bot,setup,clock_white_ms,clock_black_ms,clock_started_at')
    .eq('id', id).single()
  if (error) throw error
  const row = data as MatchRow
  const uid = (await db.auth.getUser()).data.user?.id
  const youWhite = row.white === uid
  return {
    matchId: id,
    bot: row.is_bot,
    youWhite,
    opponent: youWhite ? row.black_card : row.white_card,
    decks: row.setup.decks,
    ultimates: row.setup.ultimates,
    clockWhiteMs: row.clock_white_ms,
    clockBlackMs: row.clock_black_ms,
    startedAt: Date.parse(row.clock_started_at),
  }
}

export async function submitAction(matchId: string, ply: number, code: string) {
  const db = client()
  const { error } = await db.functions.invoke('submit-action', { body: { match_id: matchId, ply, code } })
  if (error) throw error
}

export async function fetchActions(matchId: string): Promise<string[]> {
  const db = client()
  const { data, error } = await db.from('match_actions').select('code').eq('match_id', matchId).order('ply')
  if (error) throw error
  return (data ?? []).map(row => row.code as string)
}

export async function heartbeat(matchId: string) {
  await supabase?.rpc('match_heartbeat', { p_match: matchId })
}

export async function resignMatch(matchId: string) {
  const { error } = await client().rpc('resign_match', { p_match: matchId })
  if (error) throw error
}

export async function offerDraw(matchId: string) {
  const { error } = await client().rpc('offer_draw', { p_match: matchId })
  if (error) throw error
}

export async function answerDraw(matchId: string, accept: boolean) {
  const { error } = await client().rpc('answer_draw', { p_match: matchId, p_accept: accept })
  if (error) throw error
}

export async function claimTimeout(matchId: string) {
  const { error } = await client().rpc('claim_timeout', { p_match: matchId })
  if (error) throw error
}

export async function finishBot(matchId: string, actions: string[], outcome: 'final' | 'resigned' | 'timeout') {
  const { data, error } = await client().functions.invoke('finish-bot-match', {
    body: { match_id: matchId, actions, outcome },
  })
  if (error) throw error
  return data as { trophy_delta_white?: number; trophy_delta_black?: number } | null
}

export async function matchStatus(matchId: string) {
  const { data, error } = await client().from('matches')
    .select('status,result,winner_color,draw_offer_by,trophy_delta_white,trophy_delta_black')
    .eq('id', matchId).single()
  if (error) throw error
  return data as {
    status: string
    result: string | null
    winner_color: string | null
    draw_offer_by: string | null
    trophy_delta_white: number | null
    trophy_delta_black: number | null
  }
}

export function serverMessage(error: unknown): string {
  const text = error instanceof Error ? error.message : String(error)
  if (text.includes('name_taken')) return 'Dieser Name ist schon vergeben.'
  if (text.includes('rules_outdated')) return 'Bitte aktualisiere Rook Raid, um online zu spielen.'
  if (text.includes('deck_incomplete') || text.includes('unknown_card') || text.includes('unknown_ultimate')) return 'Dein Deck braucht 4 verschiedene Karten.'
  if (text.includes('bad_time_control')) return 'Online gilt nur 5 | 0.'
  if (text.includes('no_account')) return 'Zuerst brauchst du ein Online-Konto.'
  if (text.includes('apple_not_configured')) return 'Anmeldung mit Apple braucht eine Services ID. Trag sie als VITE_APPLE_CLIENT_ID ein und hinterlege dieselbe ID bei Supabase neben der Bundle-ID.'
  if (text === 'offline') return 'Kein Server konfiguriert. Üben geht weiter.'
  return 'Keine Verbindung zum Server.'
}

export { snapshot }
