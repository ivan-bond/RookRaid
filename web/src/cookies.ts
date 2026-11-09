// Two small first-party cookies (technically necessary, no tracking):
//   rr_visited – this browser has opened Rook Raid before (first visit → first battle)
//   rr_auth    – how the player is signed in: guest, anonymous or secured (Apple/Google; shown before the server answers)
const YEAR = 60 * 60 * 24 * 365

export function getCookie(name: string): string | null {
  const m = document.cookie.match(new RegExp('(?:^|; )' + name + '=([^;]*)'))
  return m ? decodeURIComponent(m[1]) : null
}
export function setCookie(name: string, value: string, maxAge = YEAR) {
  const secure = location.protocol === 'https:' ? '; Secure' : ''
  document.cookie = `${name}=${encodeURIComponent(value)}; Max-Age=${maxAge}; Path=/; SameSite=Lax${secure}`
}

export const isFirstVisit = () => getCookie('rr_visited') !== '1'
export const markVisited = () => setCookie('rr_visited', '1')
export type AuthCookie = 'guest' | 'anonymous' | 'secured'
/** Older versions wrote „apple“ for a secured account. */
export const authCookie = (): AuthCookie => { const v = getCookie('rr_auth'); return v === 'apple' || v === 'secured' ? 'secured' : v === 'anonymous' ? 'anonymous' : 'guest' }
export const setAuthCookie = (v: AuthCookie) => setCookie('rr_auth', v)
