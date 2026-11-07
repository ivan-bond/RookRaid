// Sounds from the app (RookRaid/Sounds) and short vibrations where the browser supports them.
import { getProfile } from './store'

const files = import.meta.glob('../../../RookRaid/Sounds/*.wav', { eager: true, import: 'default', query: '?url' }) as Record<string, string>
const urls: Record<string, string> = {}
for (const [path, url] of Object.entries(files)) urls[path.split('/').pop()!.replace('.wav', '')] = url

export type SoundKind =
  | 'move' | 'capture' | 'check' | 'castle' | 'card' | 'card_flip' | 'card_whoosh' | 'shield' | 'frost' | 'lightning' | 'summon'
  | 'trap' | 'notify' | 'select' | 'victory' | 'defeat' | 'reward' | 'reward_big' | 'chest_open' | 'chest_tap' | 'chest_land'
  | 'chest_rumble' | 'chest_upgrade' | 'shard_shower'

let ctx: AudioContext | null = null
const buffers = new Map<string, AudioBuffer>()
const loading = new Map<string, Promise<AudioBuffer | null>>()

function audio(): AudioContext | null {
  if (ctx) return ctx
  const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
  if (!Ctor) return null
  ctx = new Ctor()
  return ctx
}

async function buffer(name: string): Promise<AudioBuffer | null> {
  if (buffers.has(name)) return buffers.get(name)!
  const url = urls[name]
  const c = audio()
  if (!url || !c) return null
  if (!loading.has(name)) {
    loading.set(name, fetch(url).then(r => r.arrayBuffer()).then(b => c.decodeAudioData(b)).then(buf => { buffers.set(name, buf); return buf }).catch(() => null))
  }
  return loading.get(name)!
}

/** Browsers start audio only after a user gesture. */
export function unlockAudio() {
  const c = audio()
  if (c && c.state === 'suspended') void c.resume()
  for (const n of ['move', 'capture', 'card', 'select']) void buffer(n)
}

export function sound(kind: SoundKind, volume = 0.8) {
  if (!getProfile().settings.sound) return
  const c = audio()
  if (!c || c.state !== 'running') return
  void buffer(kind).then(buf => {
    if (!buf) return
    const src = c.createBufferSource()
    const gain = c.createGain()
    gain.gain.value = volume
    src.buffer = buf
    src.connect(gain).connect(c.destination)
    src.start()
  })
}

const PATTERNS: Record<string, number | number[]> = {
  select: 6, tick: 4, move: 8, capture: 14, heavy: [18, 30, 18], check: [12, 40, 12], card: 10, mana: 5, invalid: [10, 40, 10],
  victory: [20, 60, 20, 60, 40], defeat: [60], shield: 10, frost: 12, lightning: 20, summon: 12, chest: 16, chestBig: [30, 40, 60],
}
export function haptic(kind: keyof typeof PATTERNS | string) {
  if (!getProfile().settings.haptics || !('vibrate' in navigator)) return
  try { navigator.vibrate(PATTERNS[kind] ?? 8) } catch { /* not allowed */ }
}
