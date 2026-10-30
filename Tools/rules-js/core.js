'use strict';
// Rook-Raid-Regeln in JavaScript: derselbe Regelstand wie die App (Werte aus RookRaid/Engine/rookraid-rules.json).
// Kern ohne Dateizugriff – läuft in Node und (gebündelt, build-server.js) in Supabase Edge Functions (Deno).
const E = require('./engine');

/// Regeln aus einem Objekt übernehmen (gleiche Struktur wie rookraid-rules.json bzw. rules_config.config).
/// Ändert die globalen Tabellen des Ports – vor jedem Nachspielen aufrufen, wenn mehrere Versionen im Umlauf sind.
function applyRules(r) {
  Object.assign(E.COST, r.cardCosts);
  Object.assign(E.CFG, {
    // feste Regeln des aktuellen Spielstands (v0.9.26)
    drainHalf: true, coronationNoQueen: false, coronationHybrid: true, ultKeeps: { fortress: true },
    fortressTurns: 1, fortressPeace: true, iceAgeTurns: 2, thaw: true, meteorSplash: false,
    freezeNoCapture: false, freezeNoQueen: true, meteorStun: true, strictUnprotected: false,
    flatMana: true, lightningHalf: true,
    // Werte aus der Regeldatei
    maxMana: r.maxMana, turnMana: r.manaPerTurn, goodBonus: r.goodMoveBonus,
    ultCost: r.ultimateCost, ultCosts: { ...r.ultimateCosts },
    cooldown: { all: r.cardCooldown, ...r.cardCooldowns },
    drainGain: r.drainGain, focusGain: r.focusGain, sacGain: r.sacrificeGain,
  });
  E.CFG.keeps = { shield: true, freeze: true, sacrifice: true, sprint: true, bulwark: true, advance: true, swap: true, retreat: true };
  return r;
}

const sq = n => (8 - +n[1]) * 8 + (n.charCodeAt(0) - 97);

/// Grundstellung einer echten Partie – wie GameState.initial(ultimates:decks:) in der App.
/// record = { decks: { white: [...], black: [...] }, ultimates: { white, black } } (MatchRecord bzw. matches.setup)
function initialFromRecord(record) {
  const d = record.decks || {}, u = record.ultimates || {};
  const decks = { w: (d.white || d.w || []).slice(), b: (d.black || d.b || []).slice() };
  const ults = {};
  if (u.white || u.w) ults.w = u.white || u.w;
  if (u.black || u.b) ults.b = u.black || u.b;
  return E.State.initial(ults, Math.random, decks);
}

/// Ganze Partie nachspielen. failedAt = Index der ersten ungültigen Aktion (null = alles gültig).
function replay(record, actions) {
  const s = initialFromRecord(record);
  for (let i = 0; i < actions.length; i++) if (!apply(s, actions[i])) return { state: s, failedAt: i };
  return { state: s, failedAt: null };
}

/// Stellung für einen Testfall: FEN plus Hände, Ultimates, Mana und geschlagene Figuren –
/// oder (start: "initial") die Grundstellung mit Decks und Ultimates wie in einer echten Partie.
function setup(c) {
  if (c.start === 'initial') return initialFromRecord({ decks: c.decks, ultimates: c.ults });
  const s = E.State.fromFEN(c.fen);
  s.mana = { w: (c.mana && c.mana.w) || 0, b: (c.mana && c.mana.b) || 0 };
  for (const col of ['w', 'b']) {
    s.decks[col] = { hand: ((c.hand && c.hand[col]) || []).slice(), queue: [] };
    if (c.ults && c.ults[col]) s.ults[col] = c.ults[col];
    if (c.captured && c.captured[col]) s.captured[col] = c.captured[col].map(t => ({ t, c: col }));
  }
  return s;
}

/// Aktion im Draht-Format anwenden (e2e4, e7e8q, card:freeze@f6, card:bulwark, ult:meteor@d8). false = nicht erlaubt.
function apply(s, code) {
  const me = s.cur;
  if (code.startsWith('card:')) {
    const [card, t] = code.slice(5).split('@');
    if (!s.decks[me] || !s.decks[me].hand.includes(card) || !s.canPlay(card, me)) return false;
    const target = t ? sq(t) : -1;
    const list = s.targets(card, me);
    if (E.NO_TARGET[card]) { if (t) return false; }
    else if (!t || !list.includes(target)) return false;
    s.playCard(card, s.decks[me].hand.indexOf(card), target);
    return true;
  }
  if (code.startsWith('ult:')) {
    const [u, t] = code.slice(4).split('@');
    if (s.ults[me] !== u || !s.canUseUlt(me)) return false;
    const target = t ? sq(t) : -1;
    if (E.ultNeedsTarget(u)) { if (!t || !s.ultTargets(me).includes(target)) return false; }
    else if (t) return false;
    s.useUlt(target);
    return true;
  }
  const m = s.allLegal(me).find(m => E.uci(s, m).slice(0, 4) === code.slice(0, 4));
  if (!m) return false;
  if (code.length === 5) m.promo = code[4];
  s.makeMove(m);
  return true;
}

function placement(s) {
  const rows = [];
  for (let r = 0; r < 8; r++) {
    let row = '', e = 0;
    for (let c = 0; c < 8; c++) {
      const p = s.b[r * 8 + c];
      if (!p) { e++; continue; }
      if (e) { row += e; e = 0; }
      row += p.c === 'w' ? p.t.toUpperCase() : p.t;
    }
    if (e) row += e;
    rows.push(row);
  }
  return rows.join('/');
}

/// Testfall durchspielen: Ergebnis wie es die App vergleicht.
function run(c) {
  const s = setup(c);
  let rejectedAt = null;
  for (let i = 0; i < c.actions.length; i++) {
    if (!apply(s, c.actions[i])) { rejectedAt = i; break; }
  }
  return { placement: placement(s), side: s.cur === 'w' ? 'white' : 'black', mana: { w: s.mana.w, b: s.mana.b },
           status: s.status(), rejectedAt };
}

function side(s) { return s.cur === 'w' ? 'white' : 'black'; }

module.exports = { E, applyRules, initialFromRecord, replay, setup, apply, placement, run, side };
