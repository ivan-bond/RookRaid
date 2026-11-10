// SettingsSheet (ProfileViews.swift) and AccountViews.swift.
import { APP_STAGE, APP_VERSION } from '../version'
import { useState } from 'react'
import * as S from '../game/store'
import { useI18n, LANGS, deviceLang } from '../i18n'
import { closeSheet, getNav, openOverlay, openSheet, run, useNav } from '../nav'
import * as Online from '../online'
import { Icon } from '../ui/Icon'
import { Dialog, Sheet, Switch } from '../ui/kit'
import { GoogleG, securedText } from './Login'
import { LegalBody, LEGAL_TITLES, type LegalPage } from './Legal'
import { unlockAudio } from '../game/feedback'

function Row({ icon, color, title, value, onClick, children }: { icon: string; color: string; title: string; value?: string; onClick?: () => void; children?: React.ReactNode }) {
  const Tag = onClick ? 'button' : 'div'
  return (
    <Tag className="li" onClick={onClick}>
      <span className="ico" style={{ background: color }}><Icon name={icon} size={16} /></span>
      <span className="t">{title}</span>
      {value && <span className="v">{value}</span>}
      {children ?? (onClick ? <Icon name="chevronRight" size={13} color="var(--muted)" /> : null)}
    </Tag>
  )
}

export function SettingsSheet() {
  const p = S.useProfile()
  const { t, lang } = useI18n()
  const [reset, setReset] = useState(false)
  const set = (fn: (s: S.Settings) => void) => S.setSettings(fn)
  const later = (fn: () => void) => { closeSheet(); window.setTimeout(fn, 250) }
  return (
    <Sheet title={t('Einstellungen')} onClose={closeSheet}>
      <AccountSection />

      <div className="list-h">{t('Spiel')}</div>
      <div className="list">
        <Row icon="person" color="#2F6FE4" title={t('Spielername')} value={S.shownName(p.name, t)} onClick={() => openSheet(Online.hasAccount() ? 'onlineName' : 'name', 'rename')} />
        <Row icon="hand" color="#5B37C2" title={t('Haptik')}><Switch on={p.settings.haptics} onChange={v => set(s => { s.haptics = v })} label={t('Haptik')} /></Row>
        <Row icon="bolt" color="#E39B3A" title={t('Sound')}><Switch on={p.settings.sound} onChange={v => { set(s => { s.sound = v }); if (v) unlockAudio() }} label={t('Sound')} /></Row>
        <Row icon="person2" color="#6FBF73" title={t('Zu zweit an einem Gerät spielen')} value={t('Ohne Trophäen')} onClick={() => later(() => run('startHotSeat'))} />
      </div>

      <div className="list-h">{t('Anzeige')}</div>
      <div className="list">
        <Row icon="grid" color="#2F6FE4" title={t('Gebiet auf dem Brett zeigen')}><Switch on={p.settings.showTerritory} onChange={v => set(s => { s.showTerritory = v })} /></Row>
        <Row icon="cpu" color="#E0413A" title={t('Bots mit eigenem Figurenset')}><Switch on={p.settings.botSkins} onChange={v => set(s => { s.botSkins = v })} /></Row>
        <Row icon="checker" color="#7E8AA3" title={t('Koordinaten anzeigen')}><Switch on={p.settings.showCoordinates} onChange={v => set(s => { s.showCoordinates = v })} /></Row>
        <Row icon="flipBoard" color="#8B5CF6" title={t('Mit Weiß spielen')}><Switch on={p.settings.playAsWhite} onChange={v => set(s => { s.playAsWhite = v })} /></Row>
      </div>

      <div className="list-h">{t('Sprache')}</div>
      <div className="list">
        <Row icon="globe" color="#3FA9F5" title={t('Sprache')} value={LANGS.find(l => l[0] === lang)?.[1]} onClick={() => openSheet('language')} />
      </div>

      <div className="list-h">{t('Hilfe')}</div>
      <div className="list">
        <Row icon="book" color="#8B5CF6" title={t('Regeln & Karten erklärt')} onClick={() => openSheet('rules')} />
        <Row icon="crown" color="#F2C14E" title={t('Erste Schlacht erneut spielen')} onClick={() => later(() => run('startTutorial'))} />
        <Row icon="graduation" color="#B0720F" title={t('Kartenschule')} onClick={() => later(() => openOverlay({ kind: 'lab', key: 'c-shield' }))} />
        <Row icon="envelope" color="#2F6FE4" title={t('Hilfe & Kontakt')} onClick={() => openSheet('legal-support', 'settings')} />
      </div>

      <div className="list-h">{t('Rechtliches')}</div>
      <div className="list">
        <Row icon="shield" color="#2F6FE4" title={t('Datenschutz')} onClick={() => openSheet('legal-privacy', 'settings')} />
        <Row icon="doc" color="#7E8AA3" title={t('Impressum')} onClick={() => openSheet('legal-imprint', 'settings')} />
        <Row icon="bookOpen" color="#7E8AA3" title={t('Nutzungsbedingungen')} onClick={() => openSheet('legal-terms', 'settings')} />
      </div>

      <div className="list-h">{t('Daten')}</div>
      <div className="list">
        <button className="li" onClick={() => setReset(true)}><span className="ico" style={{ background: '#E0413A' }}><Icon name="trash" size={16} /></span><span className="t" style={{ color: 'var(--red-light)' }}>{t('Fortschritt zurücksetzen')}</span></button>
      </div>
      <p className="list-f">{t('Profil, Fortschritt, Verlauf und die laufende Partie liegen in diesem Browser. Online liegen Konto, Trophäen und Partien zusätzlich auf dem Server in Frankfurt. Mehr dazu im Datenschutz.')}</p>
      <p className="list-f" style={{ textAlign: 'center' }}>Rook Raid · Web · v{APP_VERSION} {APP_STAGE}</p>
      {reset && (
        <Dialog title={t('Gesamten Fortschritt löschen?')} message={t('Trophäen, Statistik, XP, gelöste Puzzles, Flammen und Verlauf werden zurückgesetzt. Einstellungen bleiben erhalten.')}
          onClose={() => setReset(false)} actions={[{ label: t('Zurücksetzen'), destructive: true, onClick: () => S.resetProgress() }, { label: t('Abbrechen'), bold: true }]} />
      )}
    </Sheet>
  )
}

function AccountSection() {
  const { t } = useI18n()
  const acc = Online.useAccount()
  const p = S.useProfile()
  const [error, setError] = useState<string | null>(null)
  const [confirm, setConfirm] = useState<'signout' | 'delete' | 'delete2' | null>(null)
  if (acc.status === 'unavailable') return null
  const act = async (fn: () => Promise<void>) => {
    try { await fn() } catch (e) { setError(t(Online.serverMessage(e))) }
  }
  const status = acc.status === 'secured' ? securedText(acc.provider, t) : acc.status === 'anonymous' ? t('Nicht gesichert – geht verloren, wenn du die Browserdaten löschst.') : t('Noch kein Online-Konto. Dein Fortschritt liegt nur auf diesem iPhone.')
  return (
    <>
      <div className="list-h">{t('Online-Konto')}</div>
      <div className="list">
        <div className="li">
          <span className="ico" style={{ background: acc.status === 'secured' ? (acc.provider === 'google' ? '#fff' : '#000') : '#2F6FE4' }}>{acc.status === 'secured' && acc.provider === 'google' ? <GoogleG size={16} /> : <Icon name={acc.status === 'secured' ? 'apple' : 'person'} size={16} />}</span>
          <span className="t">{acc.name ?? t('Gast')}<br /><span className="muted" style={{ fontSize: 12, fontWeight: 500 }}>{status.replace('iPhone', t('Gerät'))}</span></span>
          {acc.serverTrophies !== null && <span className="v row" style={{ gap: 3 }}><Icon name="trophy" size={12} color="var(--gold)" />{acc.serverTrophies}</span>}
        </div>
        {acc.record && <div className="li"><span className="t muted" style={{ fontSize: 13 }}>{t('{0} S · {1} N · {2} R', acc.record.wins, acc.record.losses, acc.record.draws)}</span></div>}
        {!Online.hasAccount() && <Row icon="plusCircle" color="#6FBF73" title={t('Online-Konto erstellen')} onClick={() => openSheet('onlineName', 'create')} />}
        {acc.status === 'anonymous' && <button className="li apple-row" disabled={acc.busy} onClick={() => act(Online.signInWithApple)}><Icon name="apple" size={18} /><span className="t">{t('Mit Apple sichern')}</span></button>}
        {acc.status === 'anonymous' && <button className="li google-row" disabled={acc.busy} onClick={() => act(Online.signInWithGoogle)}><GoogleG size={18} /><span className="t">{t('Mit Google sichern')}</span></button>}
        {acc.status === 'guest' && <button className="li apple-row" disabled={acc.busy} onClick={() => act(Online.signInWithApple)}><Icon name="apple" size={18} /><span className="t">{t('Schon ein Konto?')} {t('Mit Apple anmelden')}</span></button>}
        {acc.status === 'guest' && <button className="li google-row" disabled={acc.busy} onClick={() => act(Online.signInWithGoogle)}><GoogleG size={18} /><span className="t">{t('Schon ein Konto?')} {t('Mit Google anmelden')}</span></button>}
        {Online.hasAccount() && <Row icon="arrowRight" color="#7E8AA3" title={t('Abmelden')} onClick={() => setConfirm('signout')} />}
        {Online.hasAccount() && <button className="li" onClick={() => setConfirm('delete')}><span className="ico" style={{ background: '#E0413A' }}><Icon name="trash" size={16} /></span><span className="t" style={{ color: 'var(--red-light)' }}>{t('Konto löschen')}</span></button>}
      </div>
      {acc.status !== 'secured' && <p className="list-f">{t('Mit Apple oder Google kannst du dich jederzeit wieder anmelden und deinen Fortschritt laden.')}</p>}
      {error && <Dialog title={t('Keine Verbindung')} message={error} onClose={() => setError(null)} actions={[{ label: t('Fertig'), bold: true }]} />}
      {confirm === 'signout' && <Dialog title={t('Abmelden?')} message={acc.provider === 'google' ? t('Mit Google kannst du dich jederzeit wieder anmelden und deinen Fortschritt laden.') : t('Mit Apple kannst du dich jederzeit wieder anmelden und deinen Fortschritt laden.')} onClose={() => setConfirm(null)}
        actions={[{ label: t('Abmelden'), destructive: true, onClick: () => act(Online.signOut) }, { label: t('Abbrechen'), bold: true }]} />}
      {confirm === 'delete' && <Dialog title={t('Online-Konto löschen?')} message={t('Spielername, Online-Trophäen, Online-Bilanz und die Sicherung deines Fortschritts werden vom Server gelöscht. Dein Spielstand auf diesem iPhone bleibt erhalten.').replace('iPhone', t('Gerät'))}
        onClose={() => setConfirm(null)} actions={[{ label: t('Konto löschen'), destructive: true, onClick: () => setConfirm('delete2') }, { label: t('Abbrechen'), bold: true }]} />}
      {confirm === 'delete2' && <Dialog title={t('Wirklich endgültig löschen?')} message={t('Das lässt sich nicht rückgängig machen.')} onClose={() => setConfirm(null)}
        actions={[{ label: t('Endgültig löschen'), destructive: true, onClick: () => act(Online.deleteAccount) }, { label: t('Abbrechen'), bold: true }]} />}
      {void p}
    </>
  )
}

const NAME_RE = /^[\p{L}\p{N}_.\- ]{2,16}$/u
export function NameSheet({ online }: { online: boolean }) {
  const { t } = useI18n()
  const p = S.useProfile()
  const purpose = getNav().sheetArg as string | null
  const [name, setName] = useState(S.isDefaultName(p.name) ? '' : p.name)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const valid = NAME_RE.test(name) && name.trim() === name
  const submit = async () => {
    if (!valid) return
    if (!online) { S.update(x => { x.name = name }); closeSheet(); return }
    setBusy(true); setError(null)
    try {
      if (Online.hasAccount() && !Online.getAccount().needsName) await Online.renameAccount(name)
      else await Online.createAccount(name)
      closeSheet()
      if (purpose === 'battle') window.setTimeout(() => run('quickBattle'), 300)
    } catch (e) { setError(t(Online.serverMessage(e))) } finally { setBusy(false) }
  }
  return (
    <Sheet title={online ? (Online.hasAccount() && !Online.getAccount().needsName ? t('Spielername ändern') : t('Online-Konto')) : t('Spielername')} onClose={closeSheet}>
      <form className="col" style={{ gap: 12 }} onSubmit={e => { e.preventDefault(); void submit() }}>
        <p className="dim" style={{ margin: 0 }}>{online ? (Online.hasAccount() ? t('Dein neuer Name gilt sofort für alle Online-Partien.') : t('So sehen dich deine Gegner. Jeden Namen gibt es nur einmal.')) : t('Spielername')}</p>
        <input className="field" autoFocus value={name} maxLength={16} onChange={e => setName(e.target.value)} placeholder={t('Spielername')} />
        <span className="muted" style={{ fontSize: 12 }}>{t('2–16 Zeichen: Buchstaben, Ziffern, Leerzeichen, _ . - (kein Leerzeichen am Anfang oder Ende)')}</span>
        {online && !Online.hasAccount() && <span className="muted" style={{ fontSize: 12 }}>{t('Trophäen gibt es für gewertete Online-Partien – sie zählt der Server.')}</span>}
        {error && <div className="notice">{error}</div>}
        <button className="chunky" disabled={!valid || busy}>{online && !Online.hasAccount() ? t('Konto erstellen') : t('Speichern')}</button>
      </form>
    </Sheet>
  )
}

export function LanguageSheet() {
  const { t, lang, setLang, followsDevice } = useI18n()
  const device = LANGS.find(l => l[0] === deviceLang())
  return (
    <Sheet title={t('Sprache')} onClose={closeSheet}>
      <div className="list">
        <button className="li" onClick={() => setLang(null)}>
          <Icon name="globe" size={22} color="var(--blue-light)" />
          <span className="t">{t('Gerätesprache')}<small className="muted" style={{ display: 'block', fontSize: 12 }}>{device?.[2]} {device?.[1]}</small></span>
          {followsDevice && <Icon name="check" size={18} color="var(--blue-light)" />}
        </button>
        {LANGS.map(([id, label, flag]) => (
          <button key={id} className="li" onClick={() => setLang(id)}>
            <span style={{ fontSize: 22 }}>{flag}</span><span className="t">{label}</span>{!followsDevice && lang === id && <Icon name="check" size={18} color="var(--blue-light)" />}
          </button>
        ))}
      </div>
    </Sheet>
  )
}

/** Back to the settings only when it was opened from there (the side-rail links just close it). */
export function LegalSheet({ page }: { page: LegalPage }) {
  const { t } = useI18n()
  const { sheetArg } = useNav()
  return (
    <Sheet title={t(LEGAL_TITLES[page])} onClose={() => (sheetArg === 'settings' ? openSheet('settings') : closeSheet())} tall>
      <LegalBody page={page} />
      <p className="list-f" style={{ textAlign: 'center' }}><a href={`/${page}`} target="_blank" rel="noreferrer">{location.host}/{page}</a></p>
    </Sheet>
  )
}
