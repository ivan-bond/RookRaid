import type { MatchState } from '../engine'
import { decide, type SearchProfile } from './ai'

let worker: Worker | null = null
let seq = 0
const waiting = new Map<number, (code: string | null) => void>()

function getWorker(): Worker | null {
  if (worker) return worker
  try {
    worker = new Worker(new URL('./ai.worker.ts', import.meta.url), { type: 'module' })
    worker.onmessage = (e: MessageEvent<{ id: number; code: string | null }>) => {
      waiting.get(e.data.id)?.(e.data.code)
      waiting.delete(e.data.id)
    }
    worker.onerror = () => { worker = null }
  } catch {
    worker = null
  }
  return worker
}

/** The bot's next action (AIPlayer.decide), computed off the main thread. */
export function askBot(state: MatchState, profile: SearchProfile, maxSeconds?: number): Promise<string | null> {
  const w = getWorker()
  if (!w) return new Promise(resolve => setTimeout(() => resolve(decide(state.clone(), profile, maxSeconds)), 30))
  const id = ++seq
  return new Promise(resolve => {
    waiting.set(id, resolve)
    w.postMessage({ id, state: JSON.parse(JSON.stringify(state)), profile, maxSeconds })
  })
}
