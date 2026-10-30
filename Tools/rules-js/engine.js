// Rook Raid – 1:1-Port der Swift-Engine (Engine.swift, CardEngine.swift, Cards.swift) für Tests in Node.
'use strict';

const W = 'w', B = 'b';
const opp = c => (c === W ? B : W);
const fwd = c => (c === W ? -1 : 1);
const homeRow = c => (c === W ? 7 : 0);
const pawnStart = c => (c === W ? 6 : 1);
const promoRow = c => (c === W ? 0 : 7);
const rankOf = (c, idx) => (c === W ? 8 - (idx >> 3) : (idx >> 3) + 1);

const VALUE = { k: 0, q: 9, r: 5, b: 3.2, n: 3, p: 1 };
const CAPTURE_MANA = { p: 1, n: 2, b: 2, r: 3, q: 4, k: 0 };
const MAX_MANA = 10;

const KNIGHT = [[-2, -1], [-2, 1], [-1, -2], [-1, 2], [1, -2], [1, 2], [2, -1], [2, 1]];
const KING = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]];
const ROOK = [[-1, 0], [1, 0], [0, -1], [0, 1]];
const BISHOP = [[-1, -1], [-1, 1], [1, -1], [1, 1]];
const QUEEN = ROOK.concat(BISHOP);

const LEGACY_CARDS = ['shield', 'freeze', 'bulwark', 'sprint', 'lightning', 'knighting', 'reinforce', 'revive'];
const NEW_CARDS = ['advance', 'swap', 'recall', 'drain', 'focus', 'sacrifice', 'trap', 'chain', 'bishopize', 'haste', 'retreat'];
const CARDS = LEGACY_CARDS.concat(NEW_CARDS);
// Veränderbar für Balance-Tests
const COST = { sprint: 1, bulwark: 2, lightning: 2, shield: 3, freeze: 3, reinforce: 3, knighting: 4, revive: 7,
  advance: 3, swap: 2, recall: 2, drain: 2, focus: 0, sacrifice: 0, trap: 2, chain: 4, bishopize: 4, haste: 5, retreat: 1 };
const CFG = { cooldown: {}, trapMax: 2, focusGain: 3, drainAmount: 3, drainGain: 0, sacGain: 3, deckMode: false,
  keeps: { shield: true, freeze: true, sacrifice: true, haste: true }, trapAnywhere: false,
  ultKeeps: {}, coronationHalf: false, iceAgeTurns: 1, fortressTurns: 1, ultOnce: false,
  // v0.9.20: flatMana = +1 pro Zug, guter Zug (Schlag/Schach/Taktik) höchstens +1 extra
  flatMana: false, turnMana: 1, goodBonus: 1, maxMana: 10, ultCost: 0 };
const ultCost = (u) => (u && CFG.ultCosts && CFG.ultCosts[u]) || CFG.ultCost || CFG.maxMana;
const keepsTurn = c => !!CFG.keeps[c];
// Rückzug (v0.9.34): Ziel ist das Feld, auf das der Bauer zurückweicht – er bleibt im Bonuszug stehen.
const locksTarget = c => c === 'shield' || c === 'retreat';
const NO_TARGET = { bulwark: 1, advance: 1, drain: 1, focus: 1, haste: 1 };
const ULTS = ['meteor', 'iceAge', 'fortress', 'coronation', 'rebirth'];
const ultNeedsTarget = u => u === 'meteor' || u === 'coronation';

const E_rankOf = (c, idx) => (c === W ? 8 - (idx >> 3) : (idx >> 3) + 1);
const ok = (r, c) => r >= 0 && r < 8 && c >= 0 && c < 8;
const piece = (t, c, moved = false) => ({ t, c, moved, sh: -1, fr: -1 });

function shuffle(a, rng) {
  for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rng() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}

class State {
  constructor() {
    this.b = new Array(64).fill(null); this.ply = 0; this.ep = -1;
    this.captured = { w: [], b: [] }; this.mana = { w: 0, b: 0 };
    this.decks = {}; this.ults = {}; this.bonus = false; this.lock = -1;
    this.half = 0; this.hist = []; this.last = null;
    this.traps = { w: [], b: [] }; this.cd = { w: {}, b: {} }; this.extra = 0;
  }
  clone() {
    const s = new State();
    s.b = this.b.slice(); s.ply = this.ply; s.ep = this.ep;
    s.captured = { w: this.captured.w.slice(), b: this.captured.b.slice() };
    s.mana = { w: this.mana.w, b: this.mana.b };
    s.decks = {};
    for (const k of Object.keys(this.decks)) s.decks[k] = { hand: this.decks[k].hand.slice(), queue: this.decks[k].queue.slice() };
    s.ults = { ...this.ults }; s.bonus = this.bonus; s.lock = this.lock; s.half = this.half;
    s.hist = this.hist.slice(); s.last = this.last;
    s.traps = { w: this.traps.w.slice(), b: this.traps.b.slice() }; s.cd = { w: { ...this.cd.w }, b: { ...this.cd.b } }; s.extra = this.extra; s.ultUsed = this.ultUsed; s.noCap = this.noCap; s.peace = this.peace;
    return s;
  }
  // Schlanke Kopie für die Suche: ohne Verlauf (Wiederholungen werden in der Suche ignoriert).
  fastClone() {
    const s = new State();
    s.b = this.b.slice(); s.ply = this.ply; s.ep = this.ep;
    s.captured = this.captured; s.mana = { w: this.mana.w, b: this.mana.b };
    s.decks = this.decks; s.ults = this.ults; s.bonus = this.bonus; s.lock = this.lock; s.half = this.half;
    s.hist = null; s.last = this.last;
    s.traps = this.traps; s.cd = this.cd; s.extra = this.extra; s.ultUsed = this.ultUsed; s.noCap = this.noCap; s.peace = this.peace;
    return s;
  }
  get cur() { return this.ply % 2 === 0 ? W : B; }

  static initial(ults, rng = Math.random, decks = null) {
    const s = new State();
    const back = ['r', 'n', 'b', 'q', 'k', 'b', 'n', 'r'];
    for (let c = 0; c < 8; c++) {
      s.b[c] = piece(back[c], B); s.b[8 + c] = piece('p', B);
      s.b[48 + c] = piece('p', W); s.b[56 + c] = piece(back[c], W);
    }
    for (const col of [W, B]) {
      if (decks) { s.decks[col] = { hand: decks[col].slice(), queue: [] }; continue; }
      const sh = shuffle(LEGACY_CARDS.slice(), rng);
      s.decks[col] = { hand: sh.slice(0, 4), queue: sh.slice(4) };
    }
    s.ults = { ...ults };
    s.beginTurn();
    s.hist = [s.key()];
    return s;
  }

  static fromFEN(fen) {
    const parts = fen.split(' ');
    const rows = parts[0].split('/');
    const s = new State();
    rows.forEach((row, r) => {
      let c = 0;
      for (const ch of row) {
        if (/\d/.test(ch)) { c += +ch; continue; }
        const col = ch === ch.toUpperCase() ? W : B;
        const t = ch.toLowerCase();
        s.b[r * 8 + c] = piece(t, col, t === 'p' ? r !== pawnStart(col) : true);
        c++;
      }
    });
    const cs = parts[2] || '-';
    for (const col of [W, B]) {
      const r = homeRow(col), sh = col === W ? 'K' : 'k', lo = col === W ? 'Q' : 'q';
      const k = s.b[r * 8 + 4];
      if ((cs.includes(sh) || cs.includes(lo)) && k && k.t === 'k') s.b[r * 8 + 4] = { ...k, moved: false };
      if (cs.includes(sh) && s.b[r * 8 + 7] && s.b[r * 8 + 7].t === 'r') s.b[r * 8 + 7] = { ...s.b[r * 8 + 7], moved: false };
      if (cs.includes(lo) && s.b[r * 8] && s.b[r * 8].t === 'r') s.b[r * 8] = { ...s.b[r * 8], moved: false };
    }
    s.ply = parts[1] === 'b' ? 1 : 0;
    if (parts[3] && parts[3] !== '-') s.ep = (8 - +parts[3][1]) * 8 + (parts[3].charCodeAt(0) - 97);
    s.hist = [s.key()];
    return s;
  }

  isFree(i) { return i >= 0 && this.b[i] === null; }
  canBeCaptured(i) { const p = this.b[i]; return !!p && p.t !== 'k' && !(p.sh >= this.ply); }
  // „Ungeschützt“: nicht unter Schild und von keiner eigenen Figur gedeckt (wie GameState.isUnprotected)
  isUnprotected(i) { const p = this.b[i]; return !!p && this.canBeCaptured(i) && !this.attacked(i, p.c); }
  kingSquare(c) { for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.t === 'k' && p.c === c) return i; } return -1; }
  inCheck(c) { const k = this.kingSquare(c); return k >= 0 && this.attacked(k, opp(c)); }

  attacked(t, a) {
    const r = t >> 3, c = t & 7, b = this.b;
    const pr = r - fwd(a);
    for (const dc of [-1, 1]) { if (ok(pr, c + dc)) { const p = b[pr * 8 + c + dc]; if (p && p.c === a && p.t === 'p') return true; } }
    for (const [dr, dc] of KNIGHT) { if (ok(r + dr, c + dc)) { const p = b[(r + dr) * 8 + c + dc]; if (p && p.c === a && p.t === 'n') return true; } }
    for (const [dr, dc] of KING) { if (ok(r + dr, c + dc)) { const p = b[(r + dr) * 8 + c + dc]; if (p && p.c === a && p.t === 'k') return true; } }
    for (const [dr, dc] of ROOK) {
      let rr = r + dr, cc = c + dc;
      while (ok(rr, cc)) { const p = b[rr * 8 + cc]; if (p) { if (p.c === a && (p.t === 'r' || p.t === 'q')) return true; break; } rr += dr; cc += dc; }
    }
    for (const [dr, dc] of BISHOP) {
      let rr = r + dr, cc = c + dc;
      while (ok(rr, cc)) { const p = b[rr * 8 + cc]; if (p) { if (p.c === a && (p.t === 'b' || p.t === 'q')) return true; break; } rr += dr; cc += dc; }
    }
    return false;
  }

  attackSquares(i) {
    const p = this.b[i]; if (!p) return [];
    const r = i >> 3, c = i & 7, out = [];
    let dirs, slide;
    switch (p.t) {
      case 'p': dirs = [[fwd(p.c), -1], [fwd(p.c), 1]]; slide = false; break;
      case 'n': dirs = KNIGHT; slide = false; break;
      case 'b': dirs = BISHOP; slide = true; break;
      case 'r': dirs = ROOK; slide = true; break;
      case 'q': dirs = QUEEN; slide = true; break;
      default: dirs = KING; slide = false;
    }
    for (const [dr, dc] of dirs) {
      let rr = r + dr, cc = c + dc;
      while (ok(rr, cc)) { out.push(rr * 8 + cc); if (!slide || this.b[rr * 8 + cc]) break; rr += dr; cc += dc; }
    }
    return out;
  }

  controlMap() {
    const w = new Uint8Array(64), bl = new Uint8Array(64);
    for (let i = 0; i < 64; i++) {
      const p = this.b[i]; if (!p) continue;
      const r = i >> 3, c = i & 7, arr = p.c === W ? w : bl;
      for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) if (ok(r + dr, c + dc)) arr[(r + dr) * 8 + c + dc] = 1;
    }
    const m = new Array(64);
    for (let i = 0; i < 64; i++) m[i] = w[i] && !bl[i] ? W : (bl[i] && !w[i] ? B : null);
    return m;
  }
  territory(c, map) { map = map || this.controlMap(); let n = 0; for (const x of map) if (x === c) n++; return n; }
  static income(n) { return n >= 32 ? 3 : n >= 26 ? 2 : 1; }

  gainMana(c, a) { if (a > 0) { const b = this.mana[c]; this.mana[c] = Math.min(CFG.maxMana, b + a); if (this.gained) this.gained[c] += this.mana[c] - b; } }

  isBonusLocked(i) { return this.bonus && this.lock === i; }

  pseudoMoves(i) {
    const p = this.b[i];
    if (!p || p.fr >= this.ply || this.isBonusLocked(i)) return [];
    const col = p.c, r = i >> 3, c = i & 7, moves = [];
    const capturable = t => { const o = this.b[t]; return !!o && o.c !== col && this.canBeCaptured(t) && !(this.bonus && this.noCap === t); };
    const step = (rr, cc) => {
      if (!ok(rr, cc)) return false;
      const t = rr * 8 + cc;
      if (this.b[t]) { if (capturable(t)) moves.push({ f: i, t }); return false; }
      moves.push({ f: i, t }); return true;
    };
    const slide = dirs => { for (const [dr, dc] of dirs) { let rr = r + dr, cc = c + dc; while (step(rr, cc)) { rr += dr; cc += dc; } } };
    switch (p.t) {
      case 'p': {
        const f = fwd(col);
        if (ok(r + f, c) && !this.b[(r + f) * 8 + c]) {
          moves.push({ f: i, t: (r + f) * 8 + c });
          if (!p.moved && r === pawnStart(col) && ok(r + 2 * f, c) && !this.b[(r + 2 * f) * 8 + c]) moves.push({ f: i, t: (r + 2 * f) * 8 + c, dbl: true });
        }
        for (const dc of [-1, 1]) {
          if (!ok(r + f, c + dc)) continue;
          const t = (r + f) * 8 + c + dc;
          if (this.b[t]) { if (capturable(t)) moves.push({ f: i, t }); }
          else if (t === this.ep) {
            const v = r * 8 + c + dc, vp = this.b[v];
            if (vp && vp.t === 'p' && vp.c !== col && this.canBeCaptured(v)) moves.push({ f: i, t, epc: true });
          }
        }
        break;
      }
      case 'n': for (const [dr, dc] of KNIGHT) step(r + dr, c + dc); break;
      case 'b': slide(BISHOP); break;
      case 'r': slide(ROOK); break;
      case 'q': slide(QUEEN); break;
      case 'k':
        for (const [dr, dc] of KING) step(r + dr, c + dc);
        for (const m of this.castling(i, p)) moves.push(m);
        break;
    }
    return moves;
  }

  castling(i, k) {
    const col = k.c, e = opp(col), hr = homeRow(col);
    if (k.moved || i !== hr * 8 + 4 || this.attacked(i, e)) return [];
    const res = [];
    const rs = hr * 8 + 7, rook = this.b[rs];
    if (rook && rook.t === 'r' && rook.c === col && !rook.moved && !this.isBonusLocked(rs) &&
        this.isFree(i + 1) && this.isFree(i + 2) && !this.attacked(i + 1, e) && !this.attacked(i + 2, e))
      res.push({ f: i, t: i + 2, crf: rs, crt: i + 1 });
    const rl = hr * 8, rk2 = this.b[rl];
    if (rk2 && rk2.t === 'r' && rk2.c === col && !rk2.moved && !this.isBonusLocked(rl) &&
        this.isFree(i - 1) && this.isFree(i - 2) && this.isFree(i - 3) && !this.attacked(i - 1, e) && !this.attacked(i - 2, e))
      res.push({ f: i, t: i - 2, crf: rl, crt: i - 1 });
    return res;
  }

  legalMoves(i) {
    const p = this.b[i]; if (!p) return [];
    const peace = this.bonus && this.peace;
    return this.pseudoMoves(i).filter(m => { if (peace && (this.b[m.t] || m.epc)) return false; const c = this.fastClone(); c.applyBoardMove(m); return !c.inCheck(p.c) && !((this.extra > 0 || peace) && c.inCheck(opp(p.c))); });
  }
  allLegal(col) { let out = []; for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.c === col) out = out.concat(this.legalMoves(i)); } return out; }
  hasAnyLegal(col) { for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.c === col && this.legalMoves(i).length) return true; } return false; }

  applyBoardMove(m) {
    let p = this.b[m.f]; if (!p) return;
    const mover = p.c;
    let vs = -1;
    if (m.epc) vs = (m.f >> 3) * 8 + (m.t & 7); else if (this.b[m.t]) vs = m.t;
    this.b[m.f] = null;
    p = { ...p, moved: true };
    if (vs >= 0 && this.b[vs]) {
      const v = this.b[vs]; this.b[vs] = null;
      if (this.captured !== null) { this.captured = { ...this.captured }; this.captured[v.c] = this.captured[v.c].concat([v]); }
      this.gainMana(mover, CFG.flatMana ? CFG.goodBonus : CAPTURE_MANA[v.t]);
    }
    if (p.t === 'p' && (m.t >> 3) === promoRow(mover)) { p.t = m.promo || 'q'; p.sh = -1; } // neue Figur ohne Schild
    this.b[m.t] = p;
    this.triggerTrap(m.t);
    if (m.crf !== undefined) { const rk = this.b[m.crf]; this.b[m.crf] = null; this.b[m.crt] = { ...rk, moved: true }; }
    this.ep = m.dbl ? ((m.f >> 3) + (m.t >> 3)) / 2 * 8 + (m.f & 7) : -1;
    this.last = m;
  }

  // Gegnerische Falle auf dem Zielfeld: Figur (außer König) wird vernichtet, König entschärft sie.
  triggerTrap(i) {
    const p = this.b[i]; if (!p) return;
    const e = opp(p.c), list = this.traps[e];
    if (!list.length || !list.includes(i)) return;
    this.traps = { ...this.traps }; this.traps[e] = list.filter(x => x !== i);
    if (p.t === 'k') return;
    this.b[i] = null;
    if (this.captured !== null) { this.captured = { ...this.captured }; this.captured[p.c] = this.captured[p.c].concat([p]); }
  }
  hasTrap(i) { return this.traps.w.includes(i) || this.traps.b.includes(i); }

  makeMove(m) {
    const mover = this.cur;
    const isCap = !!this.b[m.t] || !!m.epc;
    const irr = (this.b[m.f] && this.b[m.f].t === 'p') || isCap || m.crf !== undefined;
    this.applyBoardMove(m);
    if (this.inCheck(opp(mover)) && !(CFG.flatMana && isCap)) this.gainMana(mover, CFG.flatMana ? CFG.goodBonus : 1);
    if (this.extra > 0) { this.extra--; this.lock = -1; this.ep = -1; if (irr) this.half = 0; else this.half++; return; }
    this.ply++; this.bonus = false; this.lock = -1; this.noCap = -1; this.peace = false;
    if (irr) { this.half = 0; if (this.hist) this.hist = []; } else this.half++;
    if (this.hist) this.hist.push(this.key());
    this.beginTurn();
  }

  passTurn() {
    this.ep = -1; this.ply++; this.bonus = false; this.lock = -1; this.noCap = -1; this.peace = false; this.half = 0;
    if (this.hist) this.hist = [this.key()];
    this.beginTurn();
  }

  key() {
    let s = '';
    for (let i = 0; i < 64; i++) { const p = this.b[i]; s += p ? (p.c === W ? p.t.toUpperCase() : p.t) + ((p.t === 'k' || p.t === 'r') && !p.moved ? '*' : '') : '.'; }
    return s + this.cur + this.ep + (this.traps.w.length || this.traps.b.length ? 'T' + this.traps.w.join(',') + '|' + this.traps.b.join(',') : '');
  }
  repetitions() { if (!this.hist || !this.hist.length) return 0; const l = this.hist[this.hist.length - 1]; return this.hist.filter(x => x === l).length; }
  beginTurn() {
    const c = this.cur; this.gainMana(c, CFG.flatMana ? CFG.turnMana : State.income(this.territory(c)));
    // Tauwetter: Kann ein Spieler nur wegen Frost nicht ziehen, tauen seine Figuren sofort auf (kein Patt durch Frost)
    if (CFG.thaw && this.b.some(p => p && p.c === c && p.fr >= this.ply) && !this.inCheck(c) && !this.hasAnyLegal(c)) {
      for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.c === c && p.fr >= this.ply) this.b[i] = { ...p, fr: -1 }; }
    }
  }

  status() {
    const c = this.cur, chk = this.inCheck(c);
    if (!this.hasAnyLegal(c)) return chk ? 'mate' : 'stalemate';
    if (this.half >= 100) return 'fifty';
    if (this.repetitions() >= 3) return 'repetition';
    return chk ? 'check' : 'ongoing';
  }

  material(col) { let s = 0; for (const p of this.b) if (p) s += p.c === col ? VALUE[p.t] : -VALUE[p.t]; return s; }

  // ---------- Karten ----------
  bestRevivable(col, queen) {
    const list = this.captured[col] || []; let best = -1;
    list.forEach((p, i) => {
      const allowed = p.t === 'r' || p.t === 'b' || p.t === 'n' || (queen && p.t === 'q');
      if (allowed && (best < 0 || VALUE[p.t] > VALUE[list[best].t])) best = i;
    });
    return best;
  }

  candidates(card, col) {
    const e = opp(col), out = [];
    for (let i = 0; i < 64; i++) {
      const p = this.b[i], r = i >> 3, c = i & 7;
      switch (card) {
        case 'shield': if (p && p.c === col && p.t !== 'k') out.push(i); break;
        case 'freeze': if (p && p.c === e && p.t !== 'k' && !(CFG.freezeNoQueen && p.t === 'q')) out.push(i); break;
        case 'lightning': if (CFG.lightningPieces ? (p && p.c === e && p.t !== 'k' && p.t !== 'q' && this.isUnprotected(i)) : (p && p.c === e && p.t === 'p' && (CFG.strictUnprotected ? this.isUnprotected(i) : this.canBeCaptured(i)) && (!CFG.lightningHalf || (col === 'w' ? r >= 4 : r <= 3)))) out.push(i); break;
        case 'knighting': if (p && p.c === col && p.t === 'p') out.push(i); break;
        case 'sprint': {
          if (p && p.c === col && p.t === 'p') {
            const f = fwd(col), one = r + f, two = r + 2 * f;
            if (ok(one, c) && ok(two, c) && !this.b[one * 8 + c] && !this.b[two * 8 + c] && two !== promoRow(col)) out.push(i);
          }
          break;
        }
        case 'reinforce': if (r === pawnStart(col) && !p && !this.hasTrap(i)) out.push(i); break;
        case 'revive': if (r === homeRow(col) && !p && !this.hasTrap(i) && this.bestRevivable(col, false) >= 0) out.push(i); break;
        case 'swap': if (p && p.c === col && p.t !== 'k' && (CFG.swapPawns || p.t !== 'p')) out.push(i); break;
        case 'recall': if (p && p.c === col && p.t !== 'k' && p.t !== 'p' && r !== homeRow(col) && this.recallSquare(col, i) >= 0) out.push(i); break;
        case 'sacrifice': if (p && p.c === col && p.t === 'p') out.push(i); break;
        case 'chain': if (p && p.c === e && p.t !== 'k') out.push(i); break;
        case 'bishopize': if (p && p.c === col && p.t === 'p') out.push(i); break;
        case 'retreat': if (!p && !this.hasTrap(i) && r !== homeRow(col) && this.retreatOrigin(col, i) >= 0) out.push(i); break;
        case 'trap': {
          if (p || this.hasTrap(i) || this.traps[col].length >= CFG.trapMax) break;
          if (CFG.trapAnywhere) { out.push(i); break; }
          if (!this._map) this._map = this.controlMap();
          if (this._map[i] === col) out.push(i);
          break;
        }
      }
    }
    this._map = null;
    return out;
  }

  /// Rückzug: Bauer, der auf das freie Feld `to` zurückweichen kann – 1 oder 2 Felder weiter vorn in derselben Linie,
  /// dazwischen frei. -1, wenn keiner. (Die Grundreihe ist kein Ziel.)
  retreatOrigin(col, to) {
    const f = fwd(col), r = to >> 3, c = to & 7;
    for (let k = 1; k <= 2; k++) {
      const rr = r + f * k; if (!ok(rr, c)) return -1;
      const p = this.b[rr * 8 + c];
      if (p) return p.c === col && p.t === 'p' ? rr * 8 + c : -1;
    }
    return -1;
  }

  recallSquare(col, from) {
    const fc = from & 7, hr = homeRow(col);
    let best = -1, bd = 99;
    for (let c = 0; c < 8; c++) { const i = hr * 8 + c; if (this.b[i] || this.hasTrap(i)) continue; const d = Math.abs(c - fc); if (d < bd) { bd = d; best = i; } }
    return best;
  }

  applyCard(card, col, t) {
    const until = this.ply + 1;
    switch (card) {
      case 'shield': if (t >= 0 && this.b[t]) this.b[t] = { ...this.b[t], sh: until }; break;
      case 'bulwark': for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.c === col && p.t === 'p') this.b[i] = { ...p, sh: until }; } break;
      case 'freeze': if (t >= 0 && this.b[t]) this.b[t] = { ...this.b[t], fr: Math.max(this.b[t].fr, until) }; break;
      case 'lightning': if (t >= 0 && this.b[t]) { const p = this.b[t]; this.b[t] = null; this.captured = { ...this.captured }; this.captured[p.c] = this.captured[p.c].concat([p]); } break;
      case 'knighting': if (t >= 0 && this.b[t]) this.b[t] = { ...this.b[t], t: 'n' }; break;
      case 'sprint': if (t >= 0 && this.b[t]) { const p = this.b[t]; this.b[t] = null; this.b[t + 16 * fwd(col)] = { ...p, moved: true }; } break;
      case 'reinforce': this.b[t] = piece('p', col); break;
      case 'revive': {
        const idx = this.bestRevivable(col, false);
        if (t >= 0 && idx >= 0) { const list = this.captured[col].slice(); const old = list.splice(idx, 1)[0]; this.captured = { ...this.captured }; this.captured[col] = list; this.b[t] = piece(old.t, col, true); }
        break;
      }
      case 'advance': {
        const f = fwd(col), order = [];
        for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.c === col && p.t === 'p') order.push(i); }
        // vorderste Bauern zuerst, damit hintere nachrücken können
        order.sort((a, b2) => col === W ? a - b2 : b2 - a);
        for (const i of order) { const d = i + 8 * f; if (d >= 0 && d < 64 && !this.b[d] && (d >> 3) !== promoRow(col)) { this.b[d] = { ...this.b[i], moved: true }; this.b[i] = null; this.triggerTrap(d); } }
        break;
      }
      case 'swap': { const k = this.kingSquare(col); if (t >= 0 && k >= 0) { const a = this.b[t], kp = this.b[k]; this.b[t] = { ...kp, moved: true }; this.b[k] = { ...a, moved: true }; } break; }
      case 'recall': { const d = this.recallSquare(col, t); if (t >= 0 && d >= 0) { this.b[d] = { ...this.b[t] }; this.b[t] = null; } break; }
      case 'drain': { const e = opp(col); this.mana = { ...this.mana }; this.mana[e] = CFG.drainHalf ? Math.ceil(this.mana[e] / 2) : Math.max(0, this.mana[e] - CFG.drainAmount); this.gainMana(col, CFG.drainGain); break; }
      case 'focus': this.mana = { ...this.mana }; this.gainMana(col, CFG.focusGain); break;
      case 'sacrifice': if (t >= 0 && this.b[t]) { const p = this.b[t]; this.b[t] = null; this.captured = { ...this.captured }; this.captured[p.c] = this.captured[p.c].concat([p]); this.mana = { ...this.mana }; this.gainMana(col, CFG.sacGain); } break;
      case 'chain': if (t >= 0 && this.b[t]) this.b[t] = { ...this.b[t], fr: Math.max(this.b[t].fr, until + 2) }; break;
      case 'bishopize': if (t >= 0 && this.b[t]) this.b[t] = { ...this.b[t], t: 'b' }; break;
      case 'retreat': { const o = t >= 0 ? this.retreatOrigin(col, t) : -1; if (o >= 0) { this.b[t] = { ...this.b[o], moved: true }; this.b[o] = null; } break; }
      case 'trap': if (t >= 0) { this.traps = { ...this.traps }; this.traps[col] = this.traps[col].concat([t]); } break;
      case 'haste': break;
    }
  }

  validAction(col, effect, t, keeps = false, lock = -1, peace = false) {
    const c = this.fastClone(); c.captured = { w: this.captured.w.slice(), b: this.captured.b.slice() };
    effect(c, t);
    if (c.inCheck(opp(col))) return false;
    if (keeps) {
      c.bonus = true; c.lock = lock; c.peace = peace;
      if (!c.hasAnyLegal(col)) return false;
      c.bonus = false; c.lock = -1; c.peace = false;
      return c.hasAnyLegal(opp(col));
    }
    if (c.inCheck(col)) return false;
    return c.hasAnyLegal(opp(col));
  }

  targets(card, col) {
    if (NO_TARGET[card]) return [];
    return this.candidates(card, col).filter(i => this.validAction(col, (s, t) => s.applyCard(card, col, t), i, keepsTurn(card), locksTarget(card) ? i : (card === 'sprint' ? i + 16 * fwd(col) : -1)));
  }

  cardReady(card, col) { const r = this.cd[col][card]; return r === undefined || this.ply >= r; }
  canPlay(card, col) {
    if (this.bonus || this.mana[col] < COST[card] || !this.cardReady(card, col)) return false;
    if (NO_TARGET[card]) {
      if (card === 'bulwark' && !this.b.some(p => p && p.c === col && p.t === 'p')) return false;
      if (card === 'advance') { const c = this.fastClone(); const before = c.b.slice(); c.applyCard('advance', col, -1); if (c.b.every((x, i) => x === before[i])) return false; }
      if (card === 'drain' && this.mana[opp(col)] <= (CFG.drainHalf ? 1 : 0)) return false;
      if (card === 'focus' && this.mana[col] >= CFG.maxMana) return false;
      if (card === 'haste') { const c = this.fastClone(); c.bonus = true; c.extra = 1; return c.hasAnyLegal(col); }
      return this.validAction(col, (s, t) => s.applyCard(card, col, t), -1);
    }
    return this.targets(card, col).length > 0;
  }

  playCard(card, hi, t) {
    const col = this.cur;
    this.mana = { ...this.mana }; this.mana[col] -= COST[card];
    const cdN = CFG.cooldown[card] !== undefined ? CFG.cooldown[card] : (CFG.cooldown.all || 0);
    if (cdN > 0) { this.cd = { ...this.cd }; this.cd[col] = { ...this.cd[col] }; this.cd[col][card] = this.ply + 2 * cdN + 2; }
    const d = this.decks[col];
    if (d && d.queue.length) { const nd = { hand: d.hand.slice(), queue: d.queue.slice() }; nd.hand[hi] = nd.queue.shift(); nd.queue.push(card); this.decks = { ...this.decks }; this.decks[col] = nd; }
    this.applyCard(card, col, t === undefined ? -1 : t);
    if (keepsTurn(card)) { this.bonus = true; this.lock = locksTarget(card) ? t : (card === 'sprint' ? t + 16 * fwd(col) : -1); if (card === 'haste') this.extra = 1; if (card === 'freeze' && CFG.freezeNoCapture) this.noCap = t; }
    else this.passTurn();
  }

  // ---------- Ultimates ----------
  ultTargets(col) {
    const u = this.ults[col]; if (!u || !ultNeedsTarget(u)) return [];
    const cand = [];
    for (let i = 0; i < 64; i++) {
      const p = this.b[i]; if (!p) continue;
      if (u === 'meteor' && p.c !== col && p.t !== 'k' && p.t !== 'q') cand.push(i);
      if (u === 'coronation' && p.c === col && p.t === 'p' && (!CFG.coronationHalf || E_rankOf(col, i) >= 5) && !(CFG.coronationNoQueen && this.b.some(q => q && q.c === col && q.t === 'q')) &&
          !(CFG.coronationHybrid && this.b.some(q => q && q.c === col && q.t === 'q') && E_rankOf(col, i) < 5)) cand.push(i);
    }
    return cand.filter(i => this.validAction(col, (s, t) => s.applyUlt(u, col, t), i, !!CFG.ultKeeps[u]));
  }
  rebirthSquare(col) { for (const c of [3, 4, 2, 5, 1, 6, 0, 7]) { const i = homeRow(col) * 8 + c; if (!this.b[i]) return i; } return -1; }
  canUseUlt(col) {
    const u = this.ults[col];
    if (this.bonus || !u || this.mana[col] < ultCost(u)) return false;
    if (CFG.ultOnce && this.ultUsed && this.ultUsed[col]) return false;
    if (ultNeedsTarget(u)) return this.ultTargets(col).length > 0;
    if (u === 'rebirth' && (this.bestRevivable(col, true) < 0 || this.rebirthSquare(col) < 0)) return false;
    return this.validAction(col, (s, t) => s.applyUlt(u, col, t), -1, !!CFG.ultKeeps[u], -1, u === 'fortress' && !!CFG.fortressPeace);
  }
  useUlt(t) {
    const col = this.cur, u = this.ults[col];
    this.mana = { ...this.mana }; this.mana[col] = (CFG.ultCost || (CFG.ultCosts && CFG.ultCosts[u])) ? Math.max(0, this.mana[col] - ultCost(u)) : 0;
    this.ultUsed = { ...(this.ultUsed || {}) }; this.ultUsed[col] = true;
    this.applyUlt(u, col, t === undefined ? -1 : t);
    if (CFG.ultKeeps[u]) { this.bonus = true; this.peace = u === 'fortress' && !!CFG.fortressPeace; } else this.passTurn();
  }
  applyUlt(u, col, t) {
    const until = this.ply + 1;
    switch (u) {
      case 'meteor': if (t >= 0 && this.b[t]) {
        const p = this.b[t]; this.b[t] = null; this.captured = { ...this.captured }; this.captured[p.c] = this.captured[p.c].concat([p]);
        if (CFG.meteorStun) { const r = t >> 3, c = t & 7; for (const [dr, dc] of KING) { if (!ok(r + dr, c + dc)) continue; const j = (r + dr) * 8 + c + dc, q = this.b[j]; if (q && q.c === p.c && q.t === 'p' && this.isUnprotected(j)) { this.b[j] = { ...q, fr: Math.max(q.fr, until + 2) }; } } }
        else if (CFG.meteorSplash) { const r = t >> 3, c = t & 7; for (const [dr, dc] of KING) { if (!ok(r + dr, c + dc)) continue; const j = (r + dr) * 8 + c + dc, q = this.b[j]; if (q && q.c === p.c && q.t === 'p' && this.canBeCaptured(j)) { this.b[j] = null; this.captured[q.c] = this.captured[q.c].concat([q]); } } }
      } break;
      case 'iceAge': for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.c !== col && p.t !== 'k') this.b[i] = { ...p, fr: Math.max(p.fr, until + 2 * (CFG.iceAgeTurns - 1)) }; } break;
      case 'fortress': for (let i = 0; i < 64; i++) { const p = this.b[i]; if (p && p.c === col && p.t !== 'k') this.b[i] = { ...p, sh: until + 2 * (CFG.fortressTurns - 1) }; } break;
      case 'coronation': if (t >= 0 && this.b[t]) this.b[t] = { ...this.b[t], t: 'q' }; break;
      case 'rebirth': {
        const idx = this.bestRevivable(col, true), sq = this.rebirthSquare(col);
        if (idx >= 0 && sq >= 0) { const list = this.captured[col].slice(); const old = list.splice(idx, 1)[0]; this.captured = { ...this.captured }; this.captured[col] = list; this.b[sq] = piece(old.t, col, true); }
        break;
      }
    }
  }
}

// ---------- Taktik-Erkennung (wie TacticDetector, +2 Mana) ----------
function detectTactic(s, m, mover) {
  const o = opp(mover), p = s.b[m.t]; if (!p) return null;
  const k = s.kingSquare(o);
  if (k >= 0) {
    const checkers = [];
    for (let i = 0; i < 64; i++) { const q = s.b[i]; if (q && q.c === mover && s.attackSquares(i).includes(k)) checkers.push(i); }
    if (checkers.length >= 2) return 'double';
    if (checkers.length === 1 && checkers[0] !== m.t) return 'discovered';
  }
  const tg = s.attackSquares(m.t).filter(t => {
    const q = s.b[t]; if (!q || q.c !== o) return false;
    if (q.t === 'k') return true;
    if (VALUE[q.t] > VALUE[p.t] + 0.5) return true;
    return VALUE[q.t] >= 3 && !s.attacked(t, o);
  });
  if (tg.length >= 2) return 'fork';
  const dirs = p.t === 'b' ? BISHOP : p.t === 'r' ? ROOK : p.t === 'q' ? QUEEN : [];
  for (const [dr, dc] of dirs) {
    let r = (m.t >> 3) + dr, c = (m.t & 7) + dc, first = null;
    while (ok(r, c)) {
      const q = s.b[r * 8 + c];
      if (q) {
        if (q.c !== o) break;
        if (first) {
          const frontBig = first.t === 'k' || first.t === 'q';
          const backWorth = q.t !== 'k' && VALUE[q.t] >= 3 && (first.t === 'k' || VALUE[q.t] < VALUE[first.t]);
          if (frontBig && backWorth) return 'skewer';
          if (first.t !== 'k' && (q.t === 'k' || VALUE[q.t] > VALUE[first.t] + 1)) return 'pin';
          break;
        }
        first = q;
      }
      r += dr; c += dc;
    }
  }
  return null;
}

const sqName = i => 'abcdefgh'[i & 7] + (8 - (i >> 3));
const uci = (s, m) => sqName(m.f) + sqName(m.t) + (s.b[m.f] && s.b[m.f].t === 'p' && (m.t >> 3) === promoRow(s.b[m.f].c) ? (m.promo || 'q') : '');

module.exports = { ultCost, State, W, B, opp, fwd, rankOf, VALUE, CARDS, LEGACY_CARDS, NEW_CARDS, CFG, NO_TARGET, COST, ULTS, keepsTurn, locksTarget, ultNeedsTarget, detectTactic, sqName, uci, MAX_MANA, piece, shuffle, homeRow };
