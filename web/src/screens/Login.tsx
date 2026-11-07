// Sign in with Apple for the browser: a highlighted button for guests (Play tab, side rail) and the anonymous → Apple link.
import { useState } from 'react'
import { useI18n } from '../i18n'
import * as Online from '../online'
import { Icon } from '../ui/Icon'
import { Dialog } from '../ui/kit'

export function AppleLoginButton({ compact = false, highlighted = true }: { compact?: boolean; highlighted?: boolean }) {
  const { t } = useI18n()
  const acc = Online.useAccount()
  const [error, setError] = useState<string | null>(null)
  if (acc.status === 'unavailable' || acc.status === 'apple') return null
  const anonymous = acc.status === 'anonymous'
  const go = async () => {
    try { await (anonymous ? Online.linkApple() : Online.signInWithApple()) } catch (e) { setError(t(Online.serverMessage(e))) }
  }
  return (
    <>
      <button className={`apple-login${compact ? ' compact' : ''}${highlighted ? ' highlight' : ''}`} disabled={acc.busy} onClick={() => void go()}>
        <Icon name="apple" size={compact ? 16 : 19} />
        <span>{anonymous ? t('Mit Apple sichern') : t('Mit Apple anmelden')}</span>
      </button>
      {error && <Dialog title={t('Mit Apple anmelden')} message={error} onClose={() => setError(null)} actions={[{ label: t('Fertig'), bold: true }]} />}
    </>
  )
}

/** Under the Play-tab header for guests and anonymous accounts. */
export function LoginCard() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  if (acc.status === 'unavailable' || acc.status === 'apple') return null
  const anonymous = acc.status === 'anonymous'
  return (
    <div className="login-card">
      <span className="login-ico"><Icon name="person" size={22} /></span>
      <div className="grow col" style={{ gap: 2 }}>
        <b className="r" style={{ fontSize: 15 }}>{anonymous ? t('Nicht gesichert – geht verloren, wenn du die Browserdaten löschst.') : t('Spielst du als Gast?')}</b>
        <span className="dim" style={{ fontSize: 12 }}>{t('Mit Apple kannst du dich jederzeit wieder anmelden und deinen Fortschritt laden.')}</span>
      </div>
      <AppleLoginButton />
    </div>
  )
}

export function AppleErrorDialog() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  if (!acc.appleError) return null
  return <Dialog title={t('Mit Apple anmelden')} message={acc.appleErrorDetail ? `${t(acc.appleError)}\n\n(${acc.appleErrorDetail})` : t(acc.appleError)} onClose={Online.clearAppleError} actions={[{ label: t('Fertig'), bold: true }]} />
}
