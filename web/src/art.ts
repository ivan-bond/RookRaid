// Pictures from the app's asset catalogue, picked up at build time and converted to WebP at the size the web shows them
// (vite-imagetools): card art 400 px wide (detail card is 190 px), avatars 320 px, the rest at full size. The originals stay
// untouched for the iPhone app.
import type { Side } from './engine'

const glob = (files: Record<string, string>) => {
  const out: Record<string, string> = {}
  for (const [path, url] of Object.entries(files)) out[path.split('/').pop()!.replace(/(@\dx)?\.(jpg|png)$/, '')] = url
  return out
}
const painted = glob(import.meta.glob('../../RookRaid/Assets.xcassets/CardArtPainted/**/*.jpg', { eager: true, import: 'default', query: '?w=400&format=webp&quality=78' }) as Record<string, string>)
const arenas = glob(import.meta.glob('../../RookRaid/Assets.xcassets/arena-*.imageset/*.jpg', { eager: true, import: 'default', query: '?format=webp&quality=72' }) as Record<string, string>)
const avatars = glob(import.meta.glob('../../RookRaid/Assets.xcassets/avatar-*.imageset/*.jpg', { eager: true, import: 'default', query: '?w=320&format=webp&quality=78' }) as Record<string, string>)
const brand = glob(import.meta.glob(['../../RookRaid/Assets.xcassets/AppLogo.imageset/*@2x.png', '../../RookRaid/Assets.xcassets/RockyFace.imageset/*@2x.png', '../../RookRaid/Assets.xcassets/Logo.imageset/*.png'], { eager: true, import: 'default', query: '?format=webp&quality=85' }) as Record<string, string>)

/** Card art: "art-card-shield" or "art-ult-meteor". */
export const cardArt = (key: string) => painted['painted-' + key]
export const arenaImage = (n: number) => arenas[`arena-${Math.min(6, Math.max(1, n))}`]
export const avatarImage = (id: string) => avatars[`avatar-${id}`] ?? avatars['avatar-knight']
/** Load and decode the big pictures (arenas, avatars, card art) in idle time after the start, like PreparedImages and
 *  CardArtImage.preload in the app: the first switch to the path, deck or profile then shows them at once instead of
 *  decoding them in the middle of the change. Kept in `warm` so the browser doesn't drop them again. */
const warm: HTMLImageElement[] = []
export function preloadArt() {
  if (typeof window === 'undefined' || warm.length) return
  // Respect „data saver“: then pictures load only when they are shown.
  if ((navigator as Navigator & { connection?: { saveData?: boolean } }).connection?.saveData) return
  const urls = [...Object.values(arenas), ...Object.values(avatars), ...Object.values(painted)]
  const idle = (fn: () => void) => { if (typeof requestIdleCallback === 'function') requestIdleCallback(fn, { timeout: 3000 }); else setTimeout(fn, 1500) }
  let i = 0
  const next = () => {
    // A few at a time, so the first screen and the game always have the connection first.
    for (const url of urls.slice(i, i + 4)) {
      const img = new Image()
      img.decoding = 'async'
      img.src = url
      img.decode?.().catch(() => {})
      warm.push(img)
    }
    i += 4
    if (i < urls.length) idle(next)
  }
  idle(next)
}
export const appLogo = brand['AppLogo']
export const rockyFace = brand['RockyFace']
export const logoMark = brand['Logo']

export function pieceImage(color: Side, type: string, skin?: string | null): string {
  const letter = type.toUpperCase()
  return skin ? `/skins/skin-${skin}-${color}${letter}.webp` : `/pieces/${color}${letter}.webp`
}

