// Ablauf wie submit-action, aber mit direktem DB-Zugriff: echte Partie bis zum Matt, inkl. Ablehnungen.
import pg from 'pg';
import fs from 'fs';
import * as R from '../supabase/functions/_shared/rookraid-rules.mjs';
const c = new pg.Client({ connectionString: process.env.DB_URL }); await c.connect();
const A = '11111111-1111-1111-1111-111111111111', B = '22222222-2222-2222-2222-222222222222';
const deck = ['shield', 'freeze', 'sprint', 'lightning'];
const mid = (await c.query(`select create_match($1,$2,'{}','{}',$3,$3,'meteor','fortress',3,'blitz5',false,null) id`, [A, B, deck])).rows[0].id;
const rules = (await c.query(`select config from rules_config where version = 3`)).rows[0].config;
let bad = 0;
async function submit(uid, ply, code) {
  const m = (await c.query(`select * from matches where id = $1`, [mid])).rows[0];
  if (m.status !== 'active') return { error: 'not_active' };
  const color = m.white === uid ? 'white' : 'black';
  if (ply !== m.action_count) return { error: 'out_of_sync' };
  const rows = (await c.query(`select code from match_actions where match_id = $1 order by ply`, [mid])).rows;
  R.applyRules(rules);
  const s = R.initialFromRecord(m.setup);
  for (const r of rows) if (!R.apply(s, r.code)) return { error: 'corrupt' };
  if (R.side(s) !== color) return { error: 'not_your_turn' };
  if (!R.apply(s, code)) return { error: 'illegal_action' };
  const st = s.status();
  const end = st === 'mate' ? ['mate', R.side(s) === 'white' ? 'black' : 'white'] : ['stalemate', 'fifty', 'repetition'].includes(st) ? [st, null] : [null, null];
  return (await c.query(`select record_action($1,$2,$3,$4,$5,$6,$7) r`, [mid, ply, uid, code, R.side(s), end[0], end[1]])).rows[0].r;
}
const exp = (got, want, msg) => { const okk = JSON.stringify(got).includes(want); console.log((okk ? 'ok   ' : 'FAIL ') + msg, okk ? '' : JSON.stringify(got)); if (!okk) bad++; };
exp(await submit(B, 0, 'e7e5'), 'not_your_turn', 'Schwarz darf nicht zuerst ziehen');
exp(await submit(A, 0, 'e2e5'), 'illegal_action', 'unerlaubter Zug abgelehnt');
exp(await submit(A, 0, 'card:freeze@e7'), 'illegal_action', 'Karte ohne genug Mana abgelehnt');
exp(await submit(A, 0, 'f2f3'), '"ok":true', 'f2f3');
exp(await submit(B, 1, 'e7e5'), '"ok":true', 'e7e5');
exp(await submit(A, 2, 'g2g4'), '"ok":true', 'g2g4');
exp(await submit(B, 3, 'd8h4'), '"result":"mate"', 'Dh4 matt → Partie beendet');
exp(await submit(A, 4, 'e2e4'), 'not_active', 'nach Matt keine Züge mehr');
const m = (await c.query(`select status, result, winner_color, trophy_delta_white, trophy_delta_black from matches where id = $1`, [mid])).rows[0];
exp(m, '"winner_color":"black"', 'Schwarz gewinnt: ' + JSON.stringify(m));
console.log(bad ? bad + ' Fehler' : 'Ablauf bestanden'); await c.end(); process.exit(bad ? 1 : 0);
