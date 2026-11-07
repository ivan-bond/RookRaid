// Pictures from the app's asset catalogue, picked up at build time.
import type { Side } from './engine'

const glob = (files: Record<string, string>) => {
  const out: Record<string, string> = {}
  for (const [path, url] of Object.entries(files)) out[path.split('/').pop()!.replace(/(@\dx)?\.(jpg|png)$/, '')] = url
  return out
}
const painted = glob(import.meta.glob('../../RookRaid/Assets.xcassets/CardArtPainted/**/*.jpg', { eager: true, import: 'default', query: '?url' }) as Record<string, string>)
const arenas = glob(import.meta.glob('../../RookRaid/Assets.xcassets/arena-*.imageset/*.jpg', { eager: true, import: 'default', query: '?url' }) as Record<string, string>)
const avatars = glob(import.meta.glob('../../RookRaid/Assets.xcassets/avatar-*.imageset/*.jpg', { eager: true, import: 'default', query: '?url' }) as Record<string, string>)
const brand = glob(import.meta.glob(['../../RookRaid/Assets.xcassets/AppLogo.imageset/*@2x.png', '../../RookRaid/Assets.xcassets/RockyFace.imageset/*@2x.png', '../../RookRaid/Assets.xcassets/Logo.imageset/*.png'], { eager: true, import: 'default', query: '?url' }) as Record<string, string>)

/** Card art: "art-card-shield" or "art-ult-meteor". */
export const cardArt = (key: string) => painted['painted-' + key]
export const arenaImage = (n: number) => arenas[`arena-${Math.min(6, Math.max(1, n))}`]
export const avatarImage = (id: string) => avatars[`avatar-${id}`] ?? avatars['avatar-knight']
export const appLogo = brand['AppLogo']
export const rockyFace = brand['RockyFace']
export const logoMark = brand['Logo']

export function pieceImage(color: Side, type: string, skin?: string | null): string {
  const letter = type.toUpperCase()
  return skin ? `/skins/skin-${skin}-${color}${letter}.png` : `/pieces/${color}${letter}.png`
}

export const ALL_CARD_ART = Object.values(painted)
