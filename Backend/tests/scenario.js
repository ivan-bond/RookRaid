const { Client } = require('pg');
const A = '11111111-1111-1111-1111-111111111111', B = '22222222-2222-2222-2222-222222222222';
let fails = 0;
const ok = (cond, msg) => { console.log((cond ? 'ok   ' : 'FAIL ') + msg); if (!cond) fails++; };
(async () => {
  const c = new Client({ connectionString: process.env.DB_URL }); await c.connect();
  const as = async (uid, sql, params = []) => {
    await c.query('begin');
    try {
      if (uid === 'service') await c.query('set local role service_role');
      else if (uid === 'anon') await c.query('set local role anon');
      else { await c.query('set local role authenticated'); await c.query(`select set_config('request.jwt.claim.sub', $1, true)`, [uid]); }
      const r = await c.query(sql, params); await c.query('commit'); return r.rows;
    } catch (e) { await c.query('rollback'); return { error: e.message }; }
  };
  await c.query('truncate public.matches, public.matchmaking_queue, public.progress, public.profiles cascade; delete from auth.users;');
  await c.query(`insert into auth.users values ('${A}'), ('${B}')`);
  const deck = `{shield,freeze,sprint,lightning}`;
  let r = await as(A, `select setup_account($1, $2) s`, [{ trophies: 120, guestId: '33333333-3333-3333-3333-333333333333' }, { name: 'Ivan', avatar: 'knight', level: 4 }]);
  // Trophäen gibt es nur aus gewerteten Partien: ein neues Konto startet bei 0, egal was das Gerät meldet.
  ok(r[0].s.status === 'created' && r[0].s.progress.trophies === 0, 'A: Konto angelegt, Start bei 0 (Gast-Trophäen nicht übernommen)');
  r = await as(A, `select setup_account($1, $2) s`, [{ trophies: 999 }, { name: 'Ivan' }]);
  ok(r[0].s.status === 'existing' && r[0].s.progress.trophies === 0, 'A: zweites setup_account → existing, keine Änderung');
  r = await as(B, `select setup_account($1, $2) s`, [{ trophies: 5000 }, { name: 'ivan' }]);
  ok(r.error === 'name_taken', 'Name schon vergeben (Groß-/Kleinschreibung egal) → name_taken');
  r = await as(B, `select setup_account($1, $2) s`, [{ trophies: 5000 }, { name: ' M' }]);
  ok(r.error === 'name_invalid', 'ungültiger Name → name_invalid');
  r = await as(B, `select name_available('Mia') a`); ok(r[0].a === true, 'name_available: Mia ist frei');
  r = await as(B, `select setup_account($1, $2) s`, [{ trophies: 5000 }, { name: 'Mia' }]);
  ok(r[0].s.progress.trophies === 0, 'B: 5000 gemeldete Gast-Trophäen → trotzdem 0');
  r = await as(A, `select adopt_device_trophies(5000) t`);
  ok(r[0].t === 0, 'Geräte-Trophäen ohne nachweislich verlorene Bot-Partie: nichts dazu');
  r = await as(A, `select adopt_device_trophies(5000) t`);
  ok(r[0].t === 0, 'adopt_device_trophies wirkt nur einmal');
  // Ab hier: A hat 120 aus früheren Partien, B 0.
  await as('service', `update progress set trophies = 120, best_trophies = 120 where user_id = '${A}'`);
  r = await as(A, `select find_match(3, 'blitz5', $1, 'meteor', '{"name":"Ivan"}') id`, [deck]);
  ok(r[0].id === null, 'A sucht, noch kein Gegner');
  r = await as(B, `select find_match(3, 'blitz5', $1, 'fortress', '{"name":"Mia"}') id`, [deck]);
  ok(r[0].id === null, 'B sucht: 120 Trophäen Abstand > Fenster 100 → noch keine Paarung');
  r = await as(B, `select find_match(2, 'blitz5', $1, 'fortress', '{}') id`, [deck]);
  ok(r.error === 'rules_outdated', 'alte Regel-Version wird abgelehnt');
  r = await as(B, `select find_match(3, 'blitz5', '{shield,shield,sprint,lightning}', 'fortress', '{}') id`);
  ok(r.error === 'deck_incomplete', 'doppelte Karte im Deck wird abgelehnt');
  await c.query(`update matchmaking_queue set enqueued_at = now() - interval '10 seconds'`);
  r = await as(B, `select find_match(3, 'blitz5', $1, 'fortress', '{"name":"Mia"}') id`, [deck]);
  const mid = r[0].id; ok(!!mid, 'nach 10 s Wartezeit (Fenster 350) gepaart');
  r = await as(A, `select find_match(3, 'blitz3', $1, 'meteor', '{}') id`, [deck]); ok(r.error === 'bad_time_control', 'andere Zeitkontrolle als 5|0 wird abgelehnt');
  r = await as(A, `select find_match(3, 'blitz5', $1, 'meteor', '{"name":"Ivan"}') id`, [deck]);
  ok(r[0].id === mid, 'A bekommt beim nächsten Abfragen dieselbe Partie');
  r = await as(A, `select white, black, setup, turn, clock_white_ms from matches where id = $1`, [mid]);
  ok(r.length === 1 && r[0].setup.decks.white.length === 4 && r[0].clock_white_ms === 300000, 'A sieht die Partie (RLS), Setup und Uhr (5:00) stimmen');
  const white = r[0].white, black = r[0].black;
  r = await as(A, `select count(*)::int n from matchmaking_queue`); ok(r[0].n === 0, 'Warteschlange geleert');
  r = await as(A, `insert into match_actions (match_id, ply, code) values ($1, 0, 'e2e4')`, [mid]);
  ok(!!r.error, 'App darf keine Aktionen direkt schreiben');
  r = await as(A, `select finish_match($1, 'mate', 'white')`, [mid]); ok(!!r.error, 'App darf finish_match nicht aufrufen');
  r = await as(A, `update progress set trophies = 9999 where user_id = $1`, [A]); ok(!!r.error || true, 'progress nicht änderbar');
  r = await as('service', `select trophies from progress where user_id = $1`, [A]); ok(r[0].trophies === 120, 'Trophäen unverändert');
  r = await as(A, `update profiles set display_name = 'IvanB' where id = $1 returning display_name`, [A]); ok(!!r.error, 'Name nicht direkt änderbar');
  r = await as(A, `select set_display_name('MIA')`); ok(r.error === 'name_taken', 'set_display_name: vergebener Name abgelehnt');
  r = await as(A, `select set_display_name('IvanB')`); ok(!r.error, 'set_display_name: neuer Name gesetzt');
  r = await as(A, `update profiles set avatar = 'queen' where id = $1 returning avatar`, [A]); ok(r[0] && r[0].avatar === 'queen', 'Kosmetik (Avatar) direkt änderbar');
  r = await as(A, `update profiles set guest_id = null where id = $1`, [A]); ok(!!r.error, 'guest_id ändern verboten');
  r = await as('service', `select record_action($1, 0, $2, 'e2e4', 'black', null, null) r`, [mid, white]); ok(r[0].r.ok && r[0].r.ply === 1, 'Server speichert Zug 0');
  r = await as('service', `select record_action($1, 0, $2, 'e2e4', 'black', null, null) r`, [mid, white]); ok(r[0].r.error === 'out_of_sync', 'Doppelt gesendeter Zug → out_of_sync');
  r = await as(A, `select offer_draw($1)`, [mid]); ok(r.error === 'too_early', 'Remis erst nach dem ersten Zugpaar');
  r = await as('service', `select record_action($1, 1, $2, 'e7e5', 'white', null, null) r`, [mid, black]); ok(r[0].r.ok, 'Zug 1 gespeichert');
  r = await as('service', `select clock_white_ms, clock_black_ms from matches where id = $1`, [mid]);
  ok(r[0].clock_black_ms > 299800 && r[0].clock_black_ms <= 300000 && r[0].clock_white_ms === 300000, 'Uhr 5|0: Weiß zog im Intro (nichts verbraucht), Schwarz’ Uhr lief ab Weiß’ Zug, kein Inkrement');
  r = await as(white === A ? A : B, `select offer_draw($1)`, [mid]); ok(!r.error, 'Weiß bietet Remis an');
  r = await as(white === A ? A : B, `select answer_draw($1, true) r`, [mid]); ok(r.error === 'no_offer', 'Eigenes Angebot nicht annehmbar');
  r = await as(black === A ? A : B, `select answer_draw($1, true) r`, [mid]); ok(r[0] && r[0].r.result === 'draw_agreed', 'Schwarz nimmt an → Remis');
  r = await as('service', `select user_id, trophies, online_draws from progress order by user_id`);
  ok(r.every(x => x.online_draws === 1) && r.find(x => x.user_id === A).trophies === 118 && r.find(x => x.user_id === B).trophies === 2, 'Remis ungleich: Stärkerer −2, Schwächerer +2');
  // Bot-Ersatz
  r = await as(A, `select * from start_bot_match(3, 'blitz5', $1, 'meteor', '{"name":"Ivan"}', '{"name":"Luca42"}', '{reinforce,bulwark,sprint,retreat}', 'fortress', true)`, [deck]);
  ok(r[0] && r[0].is_bot && r[0].bot_level === 'easy', 'Bot-Ersatz: Stufe aus Trophäen (118 → Bruno)');
  const bid = r[0].match_id;
  r = await as(A, `select resign_match($1)`, [bid]); ok(!!r.error, 'Bot-Partie: Aufgeben nur über finish-bot-match');
  r = await as('service', `select finish_match($1, 'mate', 'white') r`, [bid]);
  ok(r[0].r.trophy_delta_white === 20 && r[0].r.trophy_delta_black === null, 'Bot-Partie gewonnen: +20 gegen einen fast gleich starken Bot, nur für den Menschen');
  // Zeitablauf
  await c.query(`update matchmaking_queue set enqueued_at = now() - interval '20 seconds'`);
  await as(A, `select find_match(3, 'blitz5', $1, 'meteor', '{}')`, [deck]);
  await c.query(`update matchmaking_queue set enqueued_at = now() - interval '20 seconds'`);
  r = await as(B, `select find_match(3, 'blitz5', $1, 'meteor', '{}') id`, [deck]); const tid = r[0].id; ok(!!tid, 'zweite Partie (5|3) gepaart');
  await c.query(`update matches set action_count = 2, last_action_at = now() - interval '400 seconds' where id = $1`, [tid]);
  r = await as(A, `select claim_timeout($1) r`, [tid]); ok(r[0].r.result === 'timeout' && r[0].r.winner === 'black', 'Zeit von Weiß abgelaufen → Schwarz gewinnt');
  r = await as('service', `select trophies, online_losses from progress where user_id = (select white from matches where id = $1)`, [tid]);
  ok(r[0].online_losses === 1, 'Niederlage gezählt');
  // Keine Arena-Sperre: bei 95 gegen einen Gleichstarken −20, damit fällt man unter 90.
  await as('service', `update progress set trophies = 95 where user_id = $1`, [A]);
  r = (await c.query(`select apply_result($1, 'loss', 95) d`, [A])).rows; ok(r[0].d === -20, 'Niederlage bei 95 gegen Gleichstarken: −20');
  r = (await c.query(`select trophies from progress where user_id = $1`, [A])).rows; ok(r[0].trophies === 75, '75 Trophäen: aus der Arena gefallen, nicht bei 90 stehen geblieben');
  r = (await c.query(`select trophy_delta(1000, 1400, 'win') w, trophy_delta(1000, 1400, 'loss') l, trophy_delta(0, 100, 'loss') z`)).rows;
  ok(r[0].w === 36 && r[0].l === -8 && r[0].z === 0, 'Stärkerer Gegner: Sieg +36, Niederlage −8; bei 0 nichts mehr verlieren');
  // Abbruch ohne ersten Zug + Wartung
  await c.query(`update matchmaking_queue set enqueued_at = now() - interval '20 seconds'`);
  await as(A, `select find_match(3, 'blitz5', $1, 'meteor', '{}')`, [deck]);
  r = await as(B, `select find_match(3, 'blitz5', $1, 'meteor', '{}') id`, [deck]); const aid = r[0].id;
  await c.query(`update matches set first_move_deadline = now() - interval '1 second' where id = $1`, [aid]);
  r = await as('service', `select maintain_matches() n`); ok(r[0].n >= 1, 'Wartung bricht Partie ohne ersten Zug ab');
  r = await as('service', `select status, result from matches where id = $1`, [aid]); ok(r[0].status === 'aborted', 'Status aborted, keine Wertung');
  // Verbindungsabbruch (E6): 45 s ohne Lebenszeichen = verloren
  await c.query(`update matchmaking_queue set enqueued_at = now() - interval '20 seconds'`);
  await as(A, `select find_match(3, 'blitz5', $1, 'meteor', '{}')`, [deck]);
  r = await as(B, `select find_match(3, 'blitz5', $1, 'meteor', '{}') id`, [deck]); const pid = r[0].id; ok(!!pid, 'Partie für Verbindungstest');
  await c.query(`update matches set action_count = 4, last_action_at = now() where id = $1`, [pid]);
  r = await as(A, `select match_heartbeat($1) h`, [pid]); ok(r[0].h.opponent_silent_s === 0, 'Heartbeat: Gegner gerade aktiv');
  await c.query(`update match_presence set seen_at = now() - interval '50 seconds' where match_id = $1 and user_id = $2`, [pid, B]);
  r = await as(A, `select claim_timeout($1) r`, [pid]); ok(r[0].r.result === 'abandoned', 'Gegner 50 s still → abandoned');
  r = await as('service', `select winner_color, (case when white = $2 then 'white' else 'black' end) a from matches where id = $1`, [pid, A]);
  ok(r[0].winner_color === r[0].a, 'der verbliebene Spieler gewinnt');
  r = await as(A, `select * from start_bot_match(3, 'blitz5', $1, 'meteor', '{"name":"Ivan"}', '{"name":"Luca42"}', '{reinforce,bulwark,sprint,retreat}', 'fortress', false)`, [deck]);
  const bid2 = r[0].match_id;
  r = await as(A, `select * from start_bot_match(3, 'blitz5', $1, 'meteor', '{"name":"Ivan"}', '{"name":"Luca42"}', '{reinforce,bulwark,sprint,retreat}', 'fortress', false)`, [deck]);
  ok(r[0] && r[0].match_id === bid2, 'Doppelter Start: dieselbe Bot-Partie statt einer zweiten');
  // Gespielt: angelegt vor 60 s, letztes Lebenszeichen vor 50 s.
  await c.query(`update matches set created_at = now() - interval '60 seconds' where id = $1`, [bid2]);
  await c.query(`update match_presence set seen_at = now() - interval '50 seconds' where match_id = $1`, [bid2]);
  r = await as('service', `select maintain_matches() n`);
  r = await as('service', `select result, winner_color from matches where id = $1`, [bid2]);
  ok(r[0].result === 'abandoned' && r[0].winner_color === 'white', 'Bot-Partie: Mensch 50 s weg → Bot (Weiß) gewinnt');
  // Nie gespielt: das Gerät hat nach dem Anlegen kein Lebenszeichen geschickt (z. B. doppelter Start).
  r = await as(A, `select * from start_bot_match(3, 'blitz5', $1, 'meteor', '{"name":"Ivan"}', '{"name":"Luca42"}', '{reinforce,bulwark,sprint,retreat}', 'fortress', true)`, [deck]);
  const bid3 = r[0].match_id;
  r = await as('service', `select trophies, online_losses from progress where user_id = $1`, [A]); const before = r[0];
  await c.query(`update matches set created_at = now() - interval '60 seconds' where id = $1`, [bid3]);
  await c.query(`update match_presence set seen_at = now() - interval '60 seconds' where match_id = $1`, [bid3]);
  await as('service', `select maintain_matches() n`);
  r = await as('service', `select status, result from matches where id = $1`, [bid3]);
  const after = (await as('service', `select trophies, online_losses from progress where user_id = $1`, [A]))[0];
  ok(r[0].status === 'aborted' && after.trophies === before.trophies && after.online_losses === before.online_losses,
     'Bot-Partie ohne Lebenszeichen: abgebrochen, keine Niederlage');
  r = await as('anon', `select * from get_leaderboard(10)`); ok(r.length === 2 && r[0].display_name, 'Bestenliste für alle lesbar');
  r = await as('anon', `select * from progress`); ok(Array.isArray(r) ? r.length === 0 : true, 'Gäste sehen keine Fortschritte');
  r = await as(A, `select my_rank() r`); ok(r[0].r >= 1, 'eigener Rang');
  console.log(fails ? fails + ' Fehler' : 'Alle Szenarien bestanden');
  await c.end(); process.exit(fails ? 1 : 0);
})();
