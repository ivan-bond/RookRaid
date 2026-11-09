// Sign in with Apple or Google for the browser: highlighted buttons for guests (Play tab, side rail) and the
// anonymous → secured step. Both work the same way (an existing account is loaded, otherwise this browser's progress
// becomes a new one). Google's button follows Google's branding rules (white, the coloured „G“).
import { useState } from 'react'
import { useI18n } from '../i18n'
import * as Online from '../online'
import { Icon } from '../ui/Icon'
import { Dialog } from '../ui/kit'

/** Google's „G“ in its four colours (as Google's sign-in guidelines ask for). */
export function GoogleG({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
      <path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
      <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z" />
      <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
    </svg>
  )
}

export function SignInButtons({ compact = false, highlighted = true }: { compact?: boolean; highlighted?: boolean }) {
  const { t } = useI18n()
  const acc = Online.useAccount()
  const [error, setError] = useState<{ title: string; text: string } | null>(null)
  if (acc.status === 'unavailable' || acc.status === 'secured') return null
  const anonymous = acc.status === 'anonymous'
  const apple = async () => {
    try { await (anonymous ? Online.linkApple() : Online.signInWithApple()) } catch (e) { setError({ title: t('Mit Apple anmelden'), text: t(Online.serverMessage(e)) }) }
  }
  const google = async () => {
    try { await Online.signInWithGoogle() } catch (e) { setError({ title: t('Mit Google anmelden'), text: t(Online.serverMessage(e)) }) }
  }
  return (
    <div className={`signin-buttons${compact ? ' compact' : ''}`}>
      <button className={`apple-login${compact ? ' compact' : ''}${highlighted ? ' highlight' : ''}`} disabled={acc.busy} onClick={() => void apple()}>
        <Icon name="apple" size={compact ? 16 : 19} />
        <span>{anonymous ? t('Mit Apple sichern') : t('Mit Apple anmelden')}</span>
      </button>
      <button className={`google-login${compact ? ' compact' : ''}`} disabled={acc.busy} onClick={() => void google()}>
        <GoogleG size={compact ? 16 : 18} />
        <span>{anonymous ? t('Mit Google sichern') : t('Mit Google anmelden')}</span>
      </button>
      {error && <Dialog title={error.title} message={error.text} onClose={() => setError(null)} actions={[{ label: t('Fertig'), bold: true }]} />}
    </div>
  )
}
/** Older name, still used by the side rail. */
export const AppleLoginButton = SignInButtons

/** Under the Play-tab header for guests and anonymous accounts. */
export function LoginCard() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  if (acc.status === 'unavailable' || acc.status === 'secured') return null
  const anonymous = acc.status === 'anonymous'
  return (
    <div className="login-card">
      <span className="login-ico"><Icon name="person" size={22} /></span>
      <div className="grow col" style={{ gap: 2 }}>
        <b className="r" style={{ fontSize: 15 }}>{anonymous ? t('Nicht gesichert – geht verloren, wenn du die Browserdaten löschst.') : t('Spielst du als Gast?')}</b>
        <span className="dim" style={{ fontSize: 12 }}>{t('Mit Apple oder Google kannst du dich jederzeit wieder anmelden und deinen Fortschritt laden.')}</span>
      </div>
      <SignInButtons />
    </div>
  )
}

export function SignInErrorDialog() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  if (!acc.signInError) return null
  const title = acc.signInErrorProvider === 'google' ? t('Mit Google anmelden') : t('Mit Apple anmelden')
  return <Dialog title={title} message={acc.signInErrorDetail ? `${t(acc.signInError)}\n\n(${acc.signInErrorDetail})` : t(acc.signInError)} onClose={Online.clearSignInError} actions={[{ label: t('Fertig'), bold: true }]} />
}
export const AppleErrorDialog = SignInErrorDialog

/** „Mit Apple gesichert“ / „Mit Google gesichert“ */
export const securedText = (provider: Online.SignInProvider | null, t: (k: string) => string) =>
  provider === 'google' ? t('Mit Google gesichert') : t('Mit Apple gesichert')
