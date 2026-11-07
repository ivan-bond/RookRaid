// ReplayView.swift (watch a finished game again) and StatisticsView (all recent games, tap one to replay it).
import { useEffect, useMemo, useRef, useState } from 'react'
import { pieceImage } from '../art'
import { BOARD_COLORS, CARDS, isCard, type CardId } from '../game/catalog'
import { apply, initialFromRecord, isFrozen, isShielded, sqIndex, type MatchState, type Side } from '../engine'
import * as S from '../game/store'
import { useI18n } from '../i18n'
import { closeOverlay, closeSheet, openOverlay } from '../nav'
import { Icon } from '../ui/Icon'
import { ManaDrop, Sheet } from '../ui/kit'
import { cardArt } from '../art'

function timeline(r: S.Replay): MatchState[] {
  let s = initialFromRecord({ decks: { white: r.decks.w, black: r.decks.b }, ultimates: { white: r.ults.w ?? '', black: r.ults.b ?? '' } })
  const out = [s.clone()]
  r.actions.forEach((code, i) => {
    const next = s.clone()
    if (!apply(next, code)) return
    const m = r.mana[i]
    if (m) next.mana = { w: m[0], b: m[1] }
    s = next
    out.push(next.clone())
  })
  return out
}

function highlight(code: string | undefined): number[] {
  if (!code) return []
  if (code.includes('@')) return [sqIndex(code.split('@')[1])]
  if (code.includes(':')) return []
  return [sqIndex(code.slice(0, 2)), sqIndex(code.slice(2, 4))]
}

export function ReplayViewer({ id }: { id: string }) {
  const { t } = useI18n()
  const r = useMemo(() => S.replayFor(id), [id])
  const states = useMemo(() => (r ? timeline(r) : []), [r])
  const [index, setIndex] = useState(0)
  const [playing, setPlaying] = useState(false)
  const listRef = useRef<HTMLDivElement>(null)
  const last = states.length - 1
  const go = (i: number) => setIndex(Math.max(0, Math.min(last, i)))

  useEffect(() => {
    if (!playing) return
    if (index >= last) { setPlaying(false); return }
    const id = window.setTimeout(() => go(index + 1), 900)
    return () => window.clearTimeout(id)
  }, [playing, index, last])
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'ArrowLeft') go(index - 1)
      else if (e.key === 'ArrowRight') go(index + 1)
      else if (e.key === 'Home') go(0)
      else if (e.key === 'End') go(last)
      else if (e.key === ' ') { e.preventDefault(); setPlaying(p => !p) }
      else if (e.key === 'Escape') closeOverlay()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })
  useEffect(() => { listRef.current?.querySelector('.rp-move.on')?.scrollIntoView({ block: 'nearest' }) }, [index])

  if (!r) return null
  const s = states[index]
  const entry = index > 0 ? r.texts?.[index - 1] : undefined
  const code = index > 0 ? r.actions[index - 1] : undefined
  const flip = r.human === 'b'
  const colors = BOARD_COLORS[S.getProfile().settings.boardTheme] ?? BOARD_COLORS.green
  const marks = highlight(code)
  const mineSide = flip ? 'b' : 'w'
  const control = s.controlMap()

  const board = (
    <div className="board rp-board">
      <div className="board-zoom">
        {Array.from({ length: 64 }, (_, k) => {
          const i = flip ? 63 - k : k
          const light = ((i >> 3) + (i & 7)) % 2 === 0
          const owner = S.getProfile().settings.showTerritory ? control[i] : null
          const bg = owner === mineSide ? (light ? colors.lightMine : colors.darkMine) : owner ? (light ? colors.lightTheirs : colors.darkTheirs) : light ? colors.light : colors.dark
          const p = s.b[i]
          return (
            <div key={i} className="sq" style={{ left: `${(k & 7) * 12.5}%`, top: `${(k >> 3) * 12.5}%`, background: bg }}>
              {marks.includes(i) && <i className="sq-hi" />}
              {p && <div className="pc static">
                {isShielded(p, s.ply) && <i className="pc-shield" />}
                <img src={pieceImage(p.c as Side, p.t)} alt="" draggable={false} />
                {isFrozen(p, s.ply) && <i className="pc-frost" />}
              </div>}
              {(k & 7) === 0 && <span className="coord rank" style={{ color: light ? colors.dark : colors.light }}>{8 - (i >> 3)}</span>}
              {(k >> 3) === 7 && <span className="coord file" style={{ color: light ? colors.dark : colors.light }}>{'abcdefgh'[i & 7]}</span>}
            </div>
          )
        })}
      </div>
    </div>
  )

  const cardOf = (c?: string, text?: string) => (c && isCard(c) ? c : text?.startsWith('★') ? 'ult' : null)
  return (
    <div className="full replay">
      <div className="g-top">
        <button className="icon-btn" onClick={closeOverlay} aria-label={t('Schließen')}><Icon name="xmark" size={18} /></button>
        <div className="g-title" style={{ flexDirection: 'column', alignItems: 'center', gap: 0 }}>
          <b>{r.title}</b><span className="clip1" style={{ maxWidth: '70vw' }}>{r.subtitle}</span>
        </div>
        <span className="muted" style={{ fontSize: 12, minWidth: 40, textAlign: 'right', paddingRight: 8 }}>{new Date(r.date).toLocaleDateString()}</span>
      </div>
      <div className="rp-body">
        <div className="rp-left">
          {board}
          <div className="rp-status">
            {entry || code ? (
              <>
                <i className="rp-side" style={{ background: (entry?.side ?? (index % 2 ? 'w' : 'b')) === 'w' ? 'var(--cream)' : '#1B1A18' }} />
                {cardOf(entry?.card, entry?.text) === 'ult' ? <Icon name="sparkles" size={13} color="var(--gold)" />
                  : entry?.card && isCard(entry.card) ? <img src={cardArt(`art-card-${entry.card}`)} alt="" className="rp-card" /> : null}
                <b className="clip1">{entry?.text ?? code}</b>
              </>
            ) : <b>{t('Ausgangsstellung')}</b>}
            <span className="spacer" />
            <span className="rp-mana"><i style={{ background: 'var(--cream)' }} /><ManaDrop text={s.mana.w} size={16} style={{ position: 'relative', left: 0, top: 0 }} /></span>
            <span className="rp-mana"><i style={{ background: '#1B1A18' }} /><ManaDrop text={s.mana.b} size={16} style={{ position: 'relative', left: 0, top: 0 }} /></span>
          </div>
          <div className="rp-controls">
            <button onClick={() => go(0)} aria-label={t('Zum Anfang')}><Icon name="chevronLeft" size={14} /><Icon name="chevronLeft" size={14} style={{ marginLeft: -8 }} /></button>
            <button onClick={() => go(index - 1)} aria-label={t('Zurück')}><Icon name="chevronLeft" size={18} /></button>
            <button className="play" onClick={() => { if (index >= last) setIndex(0); setPlaying(p => !p) }} aria-label={playing ? t('Pause') : t('Abspielen')}>
              {playing ? <span className="pause-glyph"><i /><i /></span> : <Icon name="play" size={20} />}
            </button>
            <button onClick={() => go(index + 1)} aria-label={t('Weiter')}><Icon name="chevronRight" size={18} /></button>
            <button onClick={() => go(last)} aria-label={t('Zum Ende')}><Icon name="chevronRight" size={14} /><Icon name="chevronRight" size={14} style={{ marginLeft: -8 }} /></button>
          </div>
          <input className="rp-scrub" type="range" min={0} max={last} value={index} onChange={e => { setPlaying(false); go(Number(e.target.value)) }} aria-label={t('Zug')} />
        </div>
        <div className="rp-list" ref={listRef}>
          <button className={`rp-move${index === 0 ? ' on' : ''}`} onClick={() => go(0)}><span className="muted">0</span><b>{t('Ausgangsstellung')}</b></button>
          {r.actions.map((c, i) => {
            const e = r.texts?.[i]
            const kind = cardOf(e?.card, e?.text)
            return (
              <button key={i} className={`rp-move${index === i + 1 ? ' on' : ''}${kind ? ' special' : ''}`} onClick={() => { setPlaying(false); go(i + 1) }}>
                <span className="muted num">{i + 1}</span>
                <i className="rp-side" style={{ background: (e?.side ?? (i % 2 ? 'b' : 'w')) === 'w' ? 'var(--cream)' : '#1B1A18' }} />
                {kind === 'ult' && <Icon name="sparkles" size={12} color="var(--gold)" />}
                {kind && kind !== 'ult' && <Icon name={CARDS[kind as CardId].icon} size={12} color="var(--blue-light)" />}
                <b className="clip1">{e?.text ?? c}</b>
              </button>
            )
          })}
        </div>
      </div>
    </div>
  )
}
