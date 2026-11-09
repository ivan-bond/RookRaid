// Same system as Localization.swift: the key is the German text, translations come from the app's JSON files.
// Browser-only lines live in copy.ts. A missing web line falls back to English, then to German.
import { useSyncExternalStore } from 'react'
import { extra } from './copy'

export type Lang = 'de' | 'en' | 'fr' | 'es' | 'it' | 'zh' | 'ru'
export const LANGS: Array<[Lang, string, string]> = [
  ['de', 'Deutsch', '🇩🇪'], ['en', 'English', '🇬🇧'], ['fr', 'Français', '🇫🇷'], ['es', 'Español', '🇪🇸'],
  ['it', 'Italiano', '🇮🇹'], ['zh', '中文', '🇨🇳'], ['ru', 'Русский', '🇷🇺'],
]
// Each language file is its own chunk and loads only when needed (German is built in: the keys are German).
const loaders = import.meta.glob('../../RookRaid/Localization/*.json', { import: 'default' }) as Record<string, () => Promise<Record<string, string>>>
const packs: Partial<Record<Exclude<Lang, 'de'>, Record<string, string>>> = {}
async function loadPack(l: Lang) {
  if (l === 'de' || packs[l]) return
  const load = Object.entries(loaders).find(([path]) => path.endsWith(`/${l}.json`))?.[1]
  if (load) packs[l] = await load()
}
/** Load the current language (and English, the fallback for browser-only lines) before the first render. */
export async function loadLanguage(l: Lang = lang) {
  await Promise.all([loadPack(l), l !== 'de' ? loadPack('en') : Promise.resolve()])
}
const KEY = 'rookraid.lang'
const IDS = LANGS.map(l => l[0]) as string[]

/** Explicitly chosen language, or null = follow the browser (like the app follows the device). */
function chosen(): Lang | null {
  try {
    const saved = localStorage.getItem(KEY)
    return saved && IDS.includes(saved) ? saved as Lang : null
  } catch { return null }
}
/** The browser's language, if supported – otherwise English. */
export function deviceLang(): Lang {
  if (typeof navigator === 'undefined') return 'en'
  for (const id of navigator.languages ?? [navigator.language]) {
    const code = id.slice(0, 2).toLowerCase()
    if (IDS.includes(code)) return code as Lang
  }
  return 'en'
}

function detect(): Lang { return chosen() ?? deviceLang() }

let lang: Lang = detect()
let follows = chosen() === null
const listeners = new Set<() => void>()
export function getLang(): Lang { return lang }

/** Pick a language, or null to follow the browser again. */
export function setLang(pick: Lang | null) {
  const next = pick ?? deviceLang()
  void loadLanguage(next).then(() => applyLang(next, pick))
}
function applyLang(next: Lang, pick: Lang | null) {
  lang = next
  follows = pick === null
  try { if (pick) localStorage.setItem(KEY, pick); else localStorage.removeItem(KEY) } catch { /* private mode */ }
  document.documentElement.lang = next === 'zh' ? 'zh-Hans' : next
  listeners.forEach(fn => fn())
}

export function translate(key: string, args: Array<string | number> = []): string {
  return translateIn(lang, key, args)
}
/** A text in a fixed language (the public „How to play“ page is English for now). Load the pack first. */
export function translateIn(l: Lang, key: string, args: Array<string | number> = []): string {
  let text: string
  if (l === 'de') text = extra.de?.[key] ?? key
  else text = extra[l]?.[key] ?? packs[l]?.[key] ?? extra.en?.[key] ?? packs.en?.[key] ?? key
  args.forEach((value, i) => { text = text.split(`{${i}}`).join(String(value)) })
  return text
}
export const t = (key: string, ...args: Array<string | number>) => translate(key, args)

function subscribe(fn: () => void) { listeners.add(fn); return () => { listeners.delete(fn) } }

export function useI18n() {
  const current = useSyncExternalStore(subscribe, getLang, getLang)
  const followsDevice = useSyncExternalStore(subscribe, () => follows, () => follows)
  return { lang: current, setLang, followsDevice, t: (key: string, ...args: Array<string | number>) => translate(key, args) }
}

// Guarded: the public pages are also rendered at build time in Node (scripts/prerender.mjs), without a DOM.
if (typeof document !== 'undefined') {
  document.documentElement.lang = lang === 'zh' ? 'zh-Hans' : lang
  // Following the browser: switch along when its language changes.
  window.addEventListener('languagechange', () => { if (follows && deviceLang() !== lang) setLang(null) })
}
