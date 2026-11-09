// Bot-Spieler, Online-Status und Freundschaftsspiele (Migration 20261109120000_bot_players.sql).
const { Client } = require('pg');
const A = 'aaaaaaaa-1111-1111-1111-111111111111', B = 'bbbbbbbb-2222-2222-2222-222222222222';
const C = 'cccccccc-3333-3333-3333-333333333333';
const DECK = ['shield', 'freeze', 'sprint', 'lightning'];
let fails = 0;
const ok = (cond, msg, got) => { console.log((cond ? 'ok   ' : 'FAIL ') + msg + (cond || got === undefined ? '' : ' → ' + JSON.stringify(got))); if (!cond) fails++; };
(async () => {
  const c = new Client({ connectionString: process.env.DB_URL }); await c.connect();
  const as = async (uid, sql, params = []) => {
    await c.query('begin');
    try {
      if (uid === 'service') await c.query('set local role service_role');
      else { await c.query('set local role authenticated'); await c.query(`select set_config('request.jwt.claim.sub', $1, true)`, [uid]); }
      const r = await c.query(sql, params); await c.query('commit'); return r.rows;
    } catch (e) { await c.query('rollback'); return { error: e.message }; }
  };
  const one = async (uid, sql, params) => { const r = await as(uid, sql, params); return r.error ? r : r[0]; };
  const q = async (sql, params) => (await c.query(sql, params)).rows;
  const card = (name, trophies) => ({ name, avatar: 'knight', frame: null, title: null, trophies, level: 3, pieceSet: null });
  const allOnline = () => q(`update private.bot_players set weekday_from = 0, weekday_to = 24, weekend_from = 0, weekend_to = 24`);
  const allOffline = () => q(`update private.bot_players set weekday_from = null, weekday_to = null, weekend_from = null, weekend_to = null`);
  const startBot = (uid, trophies) => one(uid, `select * from start_bot_match(3, 'blitz5', $1, 'meteor', $2, $3, $1, 'meteor', true)`,
    [DECK, card('x', trophies), { name: 'Bot Mila', avatar: 'robot', frame: null, title: 'Trainingsgegner', trophies: 500, level: 3, pieceSet: null }]);

  await q('truncate public.matches, public.matchmaking_queue, public.progress, public.profiles, public.match_invites cascade; delete from auth.users;');
  await q(`insert into auth.users values ('${A}'), ('${B}'), ('${C}')`);
  for (const [u, name] of [[A, 'Ivan'], [B, 'Mia'], [C, 'Noah']]) await as(u, `select setup_account($1, $2)`, [{}, { name }]);
  await q(`update progress set trophies = 600 where user_id in ('${A}', '${B}', '${C}')`);
  await q(`select private.seed_bot_players()`);
  // Originalwerte der Online-Zeiten sichern (die Tests überschreiben sie)
  await q(`create temp table saved_schedules as select user_id, weekday_from, weekday_to, weekend_from, weekend_to from private.bot_players`);

  // ── Anlage ──
  let r = await q(`select count(*)::int n, count(distinct lower(p.display_name))::int names, count(distinct p.friend_code)::int codes,
                          min(g.trophies) lo, max(g.trophies) hi
                     from private.bot_players b join profiles p on p.id = b.user_id join progress g on g.user_id = b.user_id`);
  ok(r[0].n === 100 && r[0].names === 100 && r[0].codes === 100, '100 Bot-Spieler mit Profil, eindeutigem Namen und Freundescode', r[0]);
  ok(r[0].lo >= 0 && r[0].hi >= 2400, 'Trophäen über alle Arenen verteilt', r[0]);
  r = await q(`select name from private.bot_players b where (select count(distinct x) from unnest(b.deck) x) <> 4
                 or exists (select 1 from unnest(b.deck) x where x not in ('shield','freeze','bulwark','sprint','lightning','knighting','reinforce','revive','bishopize','advance','swap','drain','focus','sacrifice','retreat'))
                 or b.ultimate not in ('meteor','iceAge','fortress','coronation','rebirth')`);
  ok(r.length === 0, 'alle Decks gültig (4 verschiedene Karten, bekanntes Ultimate)', r);
  r = await q(`select count(*) filter (where accepts_friends)::int f, count(*) filter (where accepts_matches)::int m,
                      count(*) filter (where accepts_friends and accept_minutes is null)::int bad from private.bot_players`);
  ok(r[0].f > 50 && r[0].f < 90 && r[0].m > 40 && r[0].m < 80 && r[0].bad === 0, 'Verhalten gemischt: manche nehmen an, manche nicht', r[0]);
  await q(`select private.seed_bot_players()`);
  r = await q(`select count(*)::int n from profiles`); ok(r[0].n === 103, 'zweimal anlegen: keine Doppelten', r[0]);
  r = await as(A, `select * from private.bot_players`); ok(!!r.error, 'Bot-Verhalten nicht lesbar für die App');
  r = await as(A, `select private.run_bot_players()`); ok(!!r.error, 'Bot-Job nicht aufrufbar für die App');

  // ── Online-Zeiten ──
  await q(`update private.bot_players set weekday_from = 17, weekday_to = 23, weekend_from = 20, weekend_to = 2 where name = 'Turmfalke'`);
  const bot = (await q(`select user_id from private.bot_players where name = 'Turmfalke'`))[0].user_id;
  const at = async (ts) => (await q(`select private.bot_online($1, $2::timestamptz) o`, [bot, ts]))[0].o;
  ok(await at('2026-11-10 18:30 Europe/Berlin') === true, 'Dienstag 18:30: online');
  ok(await at('2026-11-10 12:00 Europe/Berlin') === false, 'Dienstag 12:00: offline');
  ok(await at('2026-11-14 23:30 Europe/Berlin') === true && await at('2026-11-15 01:30 Europe/Berlin') === true, 'Wochenende über Mitternacht: online');
  ok(await at('2026-11-14 03:00 Europe/Berlin') === false, 'Samstag 3:00: offline');

  // ── Suche: als Bot gekennzeichnet ──
  r = await as(A, `select * from find_player('turmfalke')`);
  ok(r.length === 1 && r[0].is_bot === true && r[0].user_id === bot, 'Suche findet den Bot-Spieler, gekennzeichnet', r);
  r = await as(A, `select * from find_player('Mia')`); ok(r.length === 1 && r[0].is_bot === false, 'Menschen: is_bot false');

  // ── Gewertete Partie gegen einen Bot-Spieler ──
  await allOnline();
  r = await startBot(A, 600);
  ok(r.bot_player && r.bot_card && r.bot_card.bot === true && r.bot_deck.length === 4, 'keine Menschen: Bot-Spieler statt Trainingsgegner', r);
  const m1 = r.match_id, b1 = r.bot_player;
  let row = (await q(`select m.*, g.trophies bt, b.deck pdeck from matches m join progress g on g.user_id = m.bot_player
                        join private.bot_players b on b.user_id = m.bot_player where m.id = $1`, [m1]))[0];
  ok(row.is_bot && row.rated && row.white === A && row.black === null && row.trophies_black === row.bt, 'Partie: Bot-Seite leer, bot_player und seine Trophäen gesetzt', row);
  ok(JSON.stringify(row.setup.decks.black) === JSON.stringify(row.pdeck) && JSON.stringify(r.bot_deck) === JSON.stringify(row.pdeck), 'gespielt wird mit dem Deck des Bot-Spielers');
  ok(Math.abs(row.bt - 600) <= 300, 'Bot-Spieler mit ähnlich vielen Trophäen', row.bt);
  ok(row.bot_level === (await q(`select bot_level_for($1) l`, [row.bt]))[0].l, 'Spielstärke nach seinen Trophäen');
  r = await startBot(A, 600); ok(r.match_id === m1, 'doppelter Start: dieselbe Partie', r);
  r = await startBot(B, 600); ok(r.bot_player && r.bot_player !== b1, 'ein Bot-Spieler spielt nur eine Partie gleichzeitig', r);
  await as('service', `select finish_match($1, 'aborted', null)`, [r.match_id]);
  const before = (await q(`select (select trophies from progress where user_id = $1) a, (select trophies from progress where user_id = $2) b`, [A, b1]))[0];
  r = await one('service', `select finish_match($1, 'mate', 'white') f`, [m1]);
  const after = (await q(`select (select trophies from progress where user_id = $1) a, (select trophies from progress where user_id = $2) b,
                                 (select online_losses from progress where user_id = $2) bl`, [A, b1]))[0];
  ok(after.a > before.a && after.b < before.b && r.f.trophy_delta_black < 0, 'Sieg: Mensch gewinnt, Bot-Spieler verliert Trophäen', { before, after, f: r.f });
  r = await one(A, `select friend_profile($1) p`, [b1]); ok(r.error === 'not_allowed', 'Profil-Übersicht erst nach Anfrage');

  // blockiert / offline
  await as(A, `select block_player($1)`, [b1]);
  for (let i = 0; i < 5; i++) {
    r = await startBot(A, 600);
    if (r.bot_player === b1) break;
    await as('service', `select finish_match($1, 'aborted', null)`, [r.match_id]);
  }
  ok(r.bot_player !== b1, 'blockierte Bot-Spieler kommen nicht', r);
  if (r.match_id) await as('service', `select finish_match($1, 'aborted', null)`, [r.match_id]);
  await as(A, `select unblock_player($1)`, [b1]);
  await allOffline();
  r = await startBot(A, 600);
  ok(r.bot_player === null && r.bot_card.title === 'Trainingsgegner', 'niemand online: Trainingsgegner wie bisher', r);
  await as('service', `select finish_match($1, 'aborted', null)`, [r.match_id]);

  // ── Freundschaftsanfragen an Bot-Spieler ──
  const yes = (await q(`select user_id, accept_minutes m from private.bot_players where accepts_friends order by accept_minutes desc limit 1`))[0];
  const no = (await q(`select user_id from private.bot_players where not accepts_friends limit 1`))[0].user_id;
  await as(A, `select send_friend_request($1)`, [yes.user_id]);
  await as(A, `select send_friend_request($1)`, [no]);
  await allOnline();
  await q(`select private.run_bot_players()`);
  r = await as(A, `select * from my_friends()`);
  ok(r.every(x => x.relation === 'outgoing'), 'vor der Wartezeit: noch nicht angenommen', r);
  await q(`update friendships set created_at = now() - make_interval(mins => $2) where addressee = $1`, [yes.user_id, yes.m + 1]);
  await q(`update friendships set created_at = now() - interval '29 days' where addressee = $1`, [no]);
  await allOffline();
  await q(`select private.run_bot_players()`);
  r = await as(A, `select * from my_friends()`); ok(r.every(x => x.relation === 'outgoing'), 'offline: nimmt nicht an');
  await allOnline();
  r = await q(`select private.run_bot_players() n`);
  r = await as(A, `select * from my_friends()`);
  const fy = r.find(x => x.user_id === yes.user_id), fn = r.find(x => x.user_id === no);
  ok(fy && fy.relation === 'friend' && fy.is_bot && fy.online === true, 'nach der Wartezeit und online: angenommen, als Bot und online gezeigt', fy);
  ok(fn && fn.relation === 'outgoing' && fn.online === false, 'Bot, der nie annimmt: Anfrage bleibt liegen', fn);
  r = await q(`select recipient, kind from push_outbox where actor = $1`, [yes.user_id]);
  ok(r.length === 1 && r[0].recipient === A && r[0].kind === 'friend_accepted', 'Push für den Anfragenden vorgemerkt', r);
  await q(`insert into push_tokens (token, user_id, platform, environment) values ('${'ab'.repeat(32)}', '${A}', 'ios', 'sandbox')`);
  r = await as('service', `select * from claim_bot_push_outbox()`);
  ok(r.length === 1 && r[0].kind === 'friend_accepted', 'push-dispatch (Job) holt die Nachricht des Bots ab', r);
  r = await as('service', `select * from claim_bot_push_outbox()`); ok(r.length === 0, 'nur einmal');
  r = await as(A, `select * from claim_bot_push_outbox()`); ok(!!r.error, 'App darf Bot-Nachrichten nicht abholen');
  r = await one(A, `select friend_profile($1) p`, [yes.user_id]);
  ok(r.p && r.p.is_bot === true && r.p.online === true && r.p.trophies >= 0, 'Profil eines befreundeten Bot-Spielers', r.p);

  // ── Online-Status von Menschen ──
  await as(A, `select send_friend_request($1)`, [B]); await as(B, `select respond_friend_request($1, true)`, [A]);
  r = await as(A, `select * from my_friends()`); ok(r.find(x => x.user_id === B).online === false, 'Freund ohne Lebenszeichen: offline');
  r = await one(B, `select touch_online() t`); ok(r.t && Array.isArray(r.t.invites), 'Lebenszeichen', r);
  r = await as(A, `select * from my_friends()`); ok(r.find(x => x.user_id === B).online === true, 'nach Lebenszeichen: online');
  await as(B, `select set_show_online(false)`);
  r = await as(A, `select * from my_friends()`); ok(r.find(x => x.user_id === B).online === false, 'Online-Status ausgeschaltet: nie online');
  await as(B, `select set_show_online(true)`);
  await q(`update profiles set last_seen_at = now() - interval '3 minutes' where id = $1`, [B]);
  r = await as(A, `select * from my_friends()`); ok(r.find(x => x.user_id === B).online === false, 'nach 3 Minuten still: offline');
  r = await as(A, `select * from find_player('Noah')`); ok(!('online' in r[0]), 'Fremde sehen keinen Online-Status');

  // ── Freundschaftsspiel Mensch gegen Mensch ──
  const inviteParams = [3, DECK, 'meteor', card('Ivan', 600)];
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [C, ...inviteParams]); ok(r.error === 'not_friends', 'nur Freunde einladen', r);
  await q(`delete from push_outbox`);
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [B, ...inviteParams]); const inv1 = r.id;
  ok(!!inv1, 'Einladung verschickt', r);
  r = await q(`select recipient, kind, actor_name from push_outbox`);
  ok(r.length === 1 && r[0].recipient === B && r[0].kind === 'match_invite' && r[0].actor_name === 'Ivan', 'Push an den Eingeladenen', r);
  r = await one(B, `select touch_online() t`); ok(r.t.invites.length === 1 && r.t.invites[0].id === inv1 && r.t.invites[0].display_name === 'Ivan', 'Eingeladener sieht die Einladung', r.t);
  r = await one(C, `select friend_match_status($1) s`, [inv1]); ok(r.error === 'not_found', 'Fremde sehen die Einladung nicht');
  r = await one(A, `select friend_match_status($1) s`, [inv1]); ok(r.s.status === 'pending', 'wartet', r);
  r = await one(B, `select answer_friend_match($1, true, $2, $3, $4, $5) m`, [inv1, 3, ['bulwark', 'revive', 'swap', 'focus'], 'fortress', card('Mia', 600)]);
  const fm = r.m; ok(!!fm, 'angenommen: Partie angelegt', r);
  r = await one(A, `select friend_match_status($1) s`, [inv1]); ok(r.s.status === 'accepted' && r.s.match_id === fm, 'Einladender bekommt die Partie', r);
  row = (await q(`select * from matches where id = $1`, [fm]))[0];
  ok(!row.is_bot && !row.rated && [row.white, row.black].sort().join() === [A, B].sort().join(), 'Freundschaftsspiel: ungewertet, beide Menschen', row);
  r = await one(B, `select answer_friend_match($1, true, $2, $3, $4, $5) m`, [inv1, 3, DECK, 'meteor', card('Mia', 600)]); ok(r.error === 'invite_gone', 'nur einmal annehmen');
  const tro = await q(`select user_id, trophies, online_wins + online_losses + online_draws g from progress where user_id in ($1, $2) order by user_id`, [A, B]);
  await as('service', `select finish_match($1, 'resigned', $2)`, [fm, row.white === A ? 'white' : 'black']);
  const tro2 = await q(`select user_id, trophies, online_wins + online_losses + online_draws g from progress where user_id in ($1, $2) order by user_id`, [A, B]);
  ok(JSON.stringify(tro) === JSON.stringify(tro2), 'keine Trophäen und keine Online-Bilanz', { tro, tro2 });
  r = await one(A, `select friend_profile($1) p`, [B]); ok(r.p.vs_wins === 1 && r.p.vs_losses === 0, 'zählt für die Bilanz gegeneinander', r.p);
  r = await one(B, `select friend_profile($1) p`, [A]); ok(r.p.vs_losses === 1, 'auch aus Sicht des anderen', r.p);

  // ablehnen, abbrechen, verfallen, ersetzen
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [B, ...inviteParams]); const inv2 = r.id;
  r = await one(B, `select answer_friend_match($1, false, $2, $3, $4, $5) m`, [inv2, 3, DECK, 'meteor', card('Mia', 600)]);
  r = await one(A, `select friend_match_status($1) s`, [inv2]); ok(r.s.status === 'declined', 'abgelehnt', r);
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [B, ...inviteParams]); const inv3 = r.id;
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [B, ...inviteParams]); const inv4 = r.id;
  r = await one(A, `select friend_match_status($1) s`, [inv3]); ok(r.s.status === 'cancelled', 'neue Einladung ersetzt die alte', r);
  await as(A, `select cancel_friend_match($1)`, [inv4]);
  r = await one(B, `select touch_online() t`); ok(r.t.invites.length === 0, 'abgebrochen: verschwindet beim Eingeladenen', r.t);
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [B, ...inviteParams]); const inv5 = r.id;
  await q(`update match_invites set created_at = now() - interval '3 minutes' where id = $1`, [inv5]);
  r = await one(B, `select touch_online() t`); ok(r.t.invites.length === 0, 'nach 2 Minuten nicht mehr sichtbar');
  r = await one(A, `select friend_match_status($1) s`, [inv5]); ok(r.s.status === 'expired', 'verfallen', r);
  r = await one(B, `select answer_friend_match($1, true, $2, $3, $4, $5) m`, [inv5, 3, DECK, 'meteor', card('Mia', 600)]); ok(r.error === 'invite_gone', 'verfallen: nicht mehr annehmbar');

  // ── Freundschaftsspiel gegen Bot-Spieler ──
  const lover = (await q(`select user_id from private.bot_players where accepts_matches and user_id <> $1 limit 1`, [yes.user_id]))[0].user_id;
  const hater = (await q(`select user_id from private.bot_players where not accepts_matches limit 1`))[0].user_id;
  for (const u of [lover, hater]) {
    await q(`insert into friendships (requester, addressee, status, responded_at) values ($1, $2, 'accepted', now()) on conflict do nothing`, [A, u]);
  }
  await q(`delete from push_outbox`);
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [lover, ...inviteParams]); const bi = r.id;
  ok((await q(`select * from push_outbox`)).length === 0, 'an Bot-Spieler kein Push');
  r = await one(A, `select friend_match_status($1) s`, [bi]); ok(r.s.status === 'pending', 'Bot überlegt noch ein paar Sekunden', r);
  await q(`update match_invites set created_at = now() - interval '10 seconds' where id = $1`, [bi]);
  r = await one(A, `select friend_match_status($1) s`, [bi]);
  ok(r.s.status === 'accepted' && r.s.match_id, 'Bot-Spieler, der gern spielt: nimmt an', r);
  row = (await q(`select * from matches where id = $1`, [r.s.match_id]))[0];
  ok(row.is_bot && !row.rated && row.bot_player === lover && (row.white === A || row.black === A), 'Partie gegen den Bot-Spieler, ungewertet', row);
  const bt0 = (await q(`select trophies from progress where user_id = $1`, [lover]))[0].trophies;
  await as('service', `select finish_match($1, 'resigned', $2)`, [row.id, row.white === A ? 'black' : 'white']);
  ok((await q(`select trophies from progress where user_id = $1`, [lover]))[0].trophies === bt0, 'Freundschaftsspiel gegen Bot: keine Trophäen');
  r = await one(A, `select friend_profile($1) p`, [lover]); ok(r.p.vs_losses === 1, 'Bilanz gegen den Bot-Spieler', r.p);

  // ── Verlauf gegeneinander (Migration 20261110120000_friend_history.sql) ──
  r = await one(A, `select friend_matches($1) h`, [B]);
  ok(Array.isArray(r.h) && r.h.length === 1 && r.h[0].result === 'win' && r.h[0].rated === false && r.h[0].reason === 'resigned',
    'Verlauf: das Freundschaftsspiel gegen Mia, aus meiner Sicht gewonnen', r.h);
  r = await one(B, `select friend_matches($1) h`, [A]); ok(r.h.length === 1 && r.h[0].result === 'loss', 'Verlauf aus Sicht des anderen', r.h);
  r = await one(A, `select friend_matches($1) h`, [lover]); ok(r.h.length === 1 && r.h[0].result === 'loss', 'Verlauf gegen den Bot-Spieler', r.h);
  r = await one(A, `select friend_matches($1) h`, [C]); ok(r.error === 'not_friends', 'Verlauf nur unter Freunden', r);
  r = await one(A, `select friend_matches($1, 1) h`, [B]); ok(r.h.length === 1, 'Grenze für die Anzahl', r.h);
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [hater, ...inviteParams]);
  await q(`update match_invites set created_at = now() - interval '10 seconds' where id = $1`, [r.id]);
  r = await one(A, `select friend_match_status($1) s`, [r.id]); ok(r.s.status === 'declined', 'Bot-Spieler ohne Lust: lehnt ab', r);
  await allOffline();
  r = await one(A, `select invite_friend_match($1, $2, $3, $4, $5) id`, [lover, ...inviteParams]);
  await q(`update match_invites set created_at = now() - interval '10 seconds' where id = $1`, [r.id]);
  r = await one(A, `select friend_match_status($1) s`, [r.id]); ok(r.s.status === 'declined', 'Bot-Spieler offline: lehnt ab', r);

  // ── Trophäen im Hintergrund ──
  await allOnline();
  const sum0 = (await q(`select sum(online_wins + online_losses + online_draws)::int n from progress where user_id in (select user_id from private.bot_players)`))[0].n;
  await q(`select private.drift_bot_trophies()`);
  const s1 = (await q(`select sum(online_wins + online_losses + online_draws)::int n, min(trophies) lo from progress where user_id in (select user_id from private.bot_players)`))[0];
  ok(s1.n > sum0 && s1.n < sum0 + 60 && s1.lo >= 0, 'stündlich: ein Teil der Bot-Spieler spielt im Hintergrund', { sum0, s1 });

  r = await as(A, `select * from match_invites`); ok(!!r.error, 'Einladungen nicht direkt lesbar');

  // Online-Zeiten zurück
  await q(`update private.bot_players b set weekday_from = s.weekday_from, weekday_to = s.weekday_to, weekend_from = s.weekend_from, weekend_to = s.weekend_to
             from saved_schedules s where s.user_id = b.user_id`);
  await c.end();
  console.log(fails ? `${fails} Fehler` : 'Bot-Spieler bestanden');
  process.exit(fails ? 1 : 0);
})();
