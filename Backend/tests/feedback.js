// Feedback aus der App (Migration 20261111130000_feedback.sql): nur die Edge Function (Service-Rolle) speichert,
// höchstens 5 pro Stunde je Gerät oder Konto, Spieler lesen nichts.
const { Client } = require('pg');
const A = 'aaaaaaaa-1111-1111-1111-111111111111';
let fails = 0;
const ok = (cond, msg, got) => { console.log((cond ? 'ok   ' : 'FAIL ') + msg + (cond || got === undefined ? '' : ' → ' + JSON.stringify(got))); if (!cond) fails++; };
(async () => {
  const c = new Client({ connectionString: process.env.DB_URL }); await c.connect();
  const as = async (role, sql, params = []) => {
    await c.query('begin');
    try {
      await c.query(`set local role ${role}`);
      if (role === 'authenticated') await c.query(`select set_config('request.jwt.claim.sub', $1, true)`, [A]);
      const r = await c.query(sql, params); await c.query('commit'); return r.rows;
    } catch (e) { await c.query('rollback'); return { error: e.message }; }
  };
  const save = (role, user, ip, cat, msg, contact = null) =>
    as(role, `select save_feedback($1, $2, $3, $4, $5, $6) id`, [user, ip, cat, msg, contact, { platform: 'test' }]);
  const q = async (sql, params) => (await c.query(sql, params)).rows;

  await q('truncate public.feedback; truncate public.matches, public.matchmaking_queue, public.progress, public.profiles cascade; delete from auth.users;');
  await q(`insert into auth.users values ('${A}')`);

  let r = await save('service_role', null, 'ip-1', 'bug', '  Der König verschwindet.  ', 'me@example.com');
  ok(!r.error && r[0].id, 'Gast-Feedback wird gespeichert', r);
  r = await q(`select message, contact, emailed, meta->>'platform' p from feedback`);
  ok(r[0].message === 'Der König verschwindet.' && r[0].contact === 'me@example.com' && !r[0].emailed && r[0].p === 'test', 'Text getrimmt, Kontakt und Meta gespeichert', r[0]);
  const id = (await q(`select id from feedback`))[0].id;
  r = await as('service_role', `select mark_feedback_emailed($1)`, [id]);
  ok(!r.error && (await q(`select emailed from feedback where id = $1`, [id]))[0].emailed, 'nach dem Versand als gemailt markiert', r);

  ok((await save('service_role', null, 'ip-1', 'spam', 'Hallo')).error?.includes('invalid'), 'unbekannte Kategorie abgelehnt');
  ok((await save('service_role', null, 'ip-1', 'idea', '  x ')).error?.includes('invalid'), 'zu kurzer Text abgelehnt');
  ok((await save('service_role', null, 'ip-1', 'idea', 'y'.repeat(4001))).error?.includes('invalid'), 'zu langer Text abgelehnt');

  for (let i = 0; i < 4; i++) await save('service_role', null, 'ip-1', 'idea', `Idee ${i}`);
  ok((await save('service_role', null, 'ip-1', 'idea', 'Noch eine')).error?.includes('rate_limited'), 'sechstes Feedback in einer Stunde vom selben Gerät abgelehnt');
  ok(!(await save('service_role', null, 'ip-2', 'idea', 'Anderes Gerät')).error, 'ein anderes Gerät darf weiter senden');
  for (let i = 0; i < 5; i++) await save('service_role', A, `ip-a${i}`, 'balance', `Karte ${i} ist zu stark`);
  ok((await save('service_role', A, 'ip-a9', 'balance', 'Und noch was')).error?.includes('rate_limited'), 'dasselbe Konto über viele Geräte ebenfalls begrenzt');
  await q(`update feedback set created_at = now() - interval '2 hours'`);
  ok(!(await save('service_role', null, 'ip-1', 'other', 'Eine Stunde später')).error, 'nach einer Stunde geht es wieder');

  ok((await save('authenticated', A, 'ip-x', 'bug', 'Direkt gespeichert')).error?.includes('permission denied'), 'Spieler können save_feedback nicht direkt aufrufen');
  ok((await save('anon', null, 'ip-x', 'bug', 'Direkt gespeichert')).error?.includes('permission denied'), 'Gäste ebenso nicht');
  ok((await as('authenticated', `select * from feedback`)).error?.includes('permission denied'), 'Spieler lesen kein Feedback');
  ok((await as('anon', `insert into feedback (ip_hash, category, message) values ('x', 'bug', 'abc')`)).error?.includes('permission denied'), 'niemand schreibt direkt in die Tabelle');

  await q('truncate public.feedback');
  await c.end();
  console.log(fails ? `\n${fails} FEHLER` : '\nalle Feedback-Tests bestanden');
  process.exit(fails ? 1 : 0);
})();
