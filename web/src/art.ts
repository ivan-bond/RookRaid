const arenas = import.meta.glob('../../RookRaid/Assets.xcassets/arena-*.imageset/*.jpg', {
  eager: true, import: 'default', query: '?url',
}) as Record<string, string>

const avatars = import.meta.glob('../../RookRaid/Assets.xcassets/avatar-knight.imageset/*.jpg', {
  eager: true, import: 'default', query: '?url',
}) as Record<string, string>

export function arenaImage(n: number): string | undefined {
  const file = `arena-${Math.min(6, Math.max(1, n))}.jpg`
  return Object.entries(arenas).find(([path]) => path.endsWith('/' + file))?.[1]
}

export const knightAvatar = Object.values(avatars)[0]

export function pieceImage(color: 'w' | 'b', type: string): string {
  return `/pieces/${color}${type.toUpperCase()}.png`
}

export const ARENA_COLORS = ['#2FAE8F', '#5E86C9', '#A066E0', '#3BB8E0', '#F0623E', '#F7C64A']
