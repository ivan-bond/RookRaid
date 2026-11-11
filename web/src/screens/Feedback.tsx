// FeedbackView.swift: a note from Ivan and a short form. Sent through the edge function `send-feedback`.
import { useState } from 'react'
import { FEEDBACK_EMAIL, sendFeedback, type FeedbackCategory } from '../feedback'
import { haptic, sound } from '../game/feedback'
import { useI18n } from '../i18n'
import { closeSheet } from '../nav'
import { Icon } from '../ui/Icon'
import { Sheet } from '../ui/kit'

const CATEGORIES: { id: FeedbackCategory; label: string; icon: string }[] = [
  { id: 'bug', label: 'Bug', icon: 'burst' },
  { id: 'balance', label: 'Balance', icon: 'scale' },
  { id: 'idea', label: 'Idee', icon: 'sparkles' },
  { id: 'other', label: 'Sonstiges', icon: 'ellipsis' },
]

export function FeedbackSheet() {
  const { t } = useI18n()
  const [category, setCategory] = useState<FeedbackCategory>('bug')
  const [message, setMessage] = useState('')
  const [contact, setContact] = useState('')
  const [state, setState] = useState<'edit' | 'sending' | 'sent'>('edit')
  const [error, setError] = useState<string | null>(null)
  const valid = message.trim().length >= 3

  const submit = async () => {
    if (!valid || state === 'sending') return
    setState('sending'); setError(null)
    try {
      await sendFeedback(category, message, contact)
      haptic('victory'); sound('reward')
      setState('sent')
    } catch (e) {
      haptic('invalid')
      setError((e as Error).message === 'rate_limited'
        ? t('Zu viele Nachrichten – bitte versuch es in einer Stunde noch einmal.')
        : t('Senden hat nicht geklappt. Prüfe deine Verbindung oder schreib direkt an {0}.', FEEDBACK_EMAIL))
      setState('edit')
    }
  }

  return (
    <Sheet title={t('Feedback')} onClose={closeSheet}>
      {state === 'sent' ? (
        <div className="fb-done">
          <span className="fb-done-ico"><Icon name="checkCircle" size={44} /></span>
          <b>{t('Danke für dein Feedback!')}</b>
          <span className="dim">{t('Ich lese jede Nachricht und melde mich, wenn du eine E-Mail angegeben hast.')}</span>
          <button className="chunky" onClick={closeSheet}>{t('Fertig')}</button>
        </div>
      ) : (
        <form className="col" style={{ gap: 14 }} onSubmit={e => { e.preventDefault(); void submit() }}>
          <div className="fb-note">
            <span className="fb-note-ico"><Icon name="envelope" size={20} /></span>
            <div className="col" style={{ gap: 6 }}>
              <b>{t('Hi, ich bin Ivan!')}</b>
              <span>{t('Rook Raid ist gerade in der Beta. Ich freue mich riesig über dein Feedback: Bugs, unausgeglichene Karten, fehlende Funktionen – alles, was dir auffällt.')}</span>
              <span className="fb-sign">{t('Danke, dass du mitspielst! – Ivan')}</span>
            </div>
          </div>
          <div className="col" style={{ gap: 8 }}>
            <span className="fb-label">{t('Worum geht es?')}</span>
            <div className="fb-cats">
              {CATEGORIES.map(c => (
                <button type="button" key={c.id} className={`fb-cat press${category === c.id ? ' on' : ''}`} aria-pressed={category === c.id}
                  onClick={() => { haptic('select'); setCategory(c.id) }}>
                  <Icon name={c.icon} size={16} />{t(c.label)}
                </button>
              ))}
            </div>
          </div>
          <div className="col" style={{ gap: 8 }}>
            <span className="fb-label">{t('Deine Nachricht')}</span>
            <textarea className="field fb-text" value={message} maxLength={4000} rows={6} onChange={e => setMessage(e.target.value)}
              placeholder={t('Was ist passiert? Was würdest du ändern?')} />
          </div>
          <div className="col" style={{ gap: 8 }}>
            <span className="fb-label">{t('E-Mail für eine Antwort (optional)')}</span>
            <input className="field" type="email" value={contact} maxLength={200} autoComplete="email" onChange={e => setContact(e.target.value)} placeholder="name@example.com" />
          </div>
          <span className="muted" style={{ fontSize: 12 }}>{t('App-Version, Gerät und Sprache werden mitgeschickt.')}</span>
          {error && <div className="notice">{error}</div>}
          <button className="chunky" disabled={!valid || state === 'sending'}>{state === 'sending' ? t('Wird gesendet …') : t('Feedback senden')}</button>
        </form>
      )}
    </Sheet>
  )
}
