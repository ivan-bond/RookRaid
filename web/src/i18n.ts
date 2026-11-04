import { useSyncExternalStore } from 'react'
import en from '../../RookRaid/Localization/en.json'
import fr from '../../RookRaid/Localization/fr.json'
import es from '../../RookRaid/Localization/es.json'
import it from '../../RookRaid/Localization/it.json'
import zh from '../../RookRaid/Localization/zh.json'
import ru from '../../RookRaid/Localization/ru.json'
import { extra } from './copy'

export type Lang = 'de' | 'en' | 'fr' | 'es' | 'it' | 'zh' | 'ru'

const packs: Record<Exclude<Lang, 'de'>, Record<string, string>> = { en, fr, es, it, zh, ru }
const KEY = 'rookraid.lang'

function detect(): Lang {
  const saved = localStorage.getItem(KEY)
  if (saved && ['de', 'en', 'fr', 'es', 'it', 'zh', 'ru'].includes(saved)) return saved as Lang
  const code = navigator.language.toLowerCase()
  if (code.startsWith('de')) return 'de'
  if (code.startsWith('fr')) return 'fr'
  if (code.startsWith('es')) return 'es'
  if (code.startsWith('it')) return 'it'
  if (code.startsWith('zh')) return 'zh'
  if (code.startsWith('ru')) return 'ru'
  if (code.startsWith('en')) return 'en'
  return 'de'
}

let lang: Lang = detect()
const listeners = new Set<() => void>()

export function getLang(): Lang { return lang }

export function setLang(next: Lang) {
  lang = next
  localStorage.setItem(KEY, next)
  document.documentElement.lang = next
  listeners.forEach(fn => fn())
}

export function translate(key: string, args: Array<string | number> = []): string {
  const own = lang === 'de' ? undefined : extra[lang]?.[key]
  const shared = lang === 'de' ? undefined : packs[lang]?.[key]
  let text = own || shared || extra.de[key] || key
  args.forEach((value, i) => { text = text.replaceAll(`{${i}}`, String(value)) })
  return text
}

export function useI18n() {
  const current = useSyncExternalStore(
    fn => { listeners.add(fn); return () => listeners.delete(fn) },
    getLang,
  )
  return {
    lang: current,
    setLang,
    t: (key: string, ...args: Array<string | number>) => translate(key, args),
  }
}

document.documentElement.lang = lang
