import { E, type MatchState } from '../engine'
import { decide, type SearchProfile } from './ai'

self.onmessage = (event: MessageEvent<{ id: number; state: Record<string, unknown>; profile: SearchProfile; maxSeconds?: number }>) => {
  const { id, state, profile, maxSeconds } = event.data
  const s = Object.assign(new (E as unknown as { State: new () => MatchState }).State(), state) as MatchState
  let code: string | null = null
  try { code = decide(s, profile, maxSeconds) } catch (err) { console.error(err) }
  ;(self as unknown as Worker).postMessage({ id, code })
}
