// Rook Raid on social media (Socials.swift in the app): Settings › „Folge uns“ and the sidebar next to the legal links.
export type Social = { id: 'instagram' | 'x' | 'tiktok'; name: string; url: string; icon: string; color: string }

export const SOCIALS: Social[] = [
  { id: 'instagram', name: 'Instagram', url: 'https://www.instagram.com/rookraid/', icon: 'instagram', color: '#D62976' },
  { id: 'x', name: 'X', url: 'https://x.com/rookraidchess', icon: 'xLogo', color: '#2B2F36' },
  { id: 'tiktok', name: 'TikTok', url: 'https://www.tiktok.com/@rookraid', icon: 'tiktok', color: '#FE2C55' },
]

/** Opens a profile in a new tab (outside the installed web app). */
export function openSocial(s: Social) { window.open(s.url, '_blank', 'noopener,noreferrer') }
