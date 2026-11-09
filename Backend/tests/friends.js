// Freunde (Migration 20261107120000_friends.sql): finden, anfragen, annehmen, blockieren, melden, Push-Geräte.
const { Client } = require('pg');
const A = 'aaaaaaaa-1111-1111-1111-111111111111', B = 'bbbbbbbb-2222-2222-2222-222222222222';
const C = 'cccccccc-3333-3333-3333-333333333333', D = 'dddddddd-4444-4444-4444-444444444444';
let fails = 0;
const ok = (cond, msg, got) => { console.log((cond ? 'ok   ' : 'FAIL ') + msg + (cond || got === undefined ? '' : ' → ' + JSON.stringify(got))); if (!cond) fails++; };
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
  const one = async (uid, sql, params) => { const r = await as(uid, sql, params); return r.error ? r : r[0]; };
  const outbox = async () => (await c.query(`select recipient, actor, kind, actor_name from push_outbox order by id`)).rows;

  await c.query('truncate public.matches, public.matchmaking_queue, public.progress, public.profiles cascade; delete from auth.users;');
  await c.query(`insert into auth.users values ('${A}'), ('${B}'), ('${C}'), ('${D}')`);
  for (const [u, name] of [[A, 'Ivan'], [B, 'Mia'], [C, 'Noah']]) {
    await as(u, `select setup_account($1, $2)`, [{}, { name }]);
  }
  await c.query(`update progress set trophies = 420 where user_id = '${B}'`);

  // Freundescode
  const codeA = (await one(A, `select my_friend_code() c`)).c;
  const codeB = (await one(B, `select my_friend_code() c`)).c;
  ok(/^[2-9A-HJ-NP-Z]{6}$/.test(codeA) && codeA !== codeB, 'Freundescode: 6 Zeichen ohne 0/O/1/I, je Konto verschieden', [codeA, codeB]);

  // Zugriff
  let r = await as(D, `select * from find_player('Mia')`); ok(r.error === 'no_account', 'ohne Konto keine Freunde', r);
  r = await as('anon', `select * from find_player('Mia')`); ok(!!r.error, 'Gast darf nicht suchen');
  r = await as(A, `select * from friendships`); ok(!!r.error, 'Freundschaften nicht direkt lesbar');
  r = await as(A, `select * from push_tokens`); ok(!!r.error, 'Push-Geräte nicht direkt lesbar');
  r = await as(A, `insert into push_outbox (recipient, kind, actor_name) values ('${B}', 'friend_request', 'x')`); ok(!!r.error, 'App darf keine Push-Nachricht anlegen');
  r = await as(A, `select id, display_name from profiles`); ok(r.length === 1 && r[0].id === A, 'Profile: nur das eigene lesbar (keine Namensliste)', r);
  r = await as(A, `select friend_code from profiles where id = $1`, [B]); ok(r.length === 0, 'fremder Freundescode nicht lesbar');

  // Finden
  r = await as(A, `select * from find_player('mia')`); ok(r.length === 1 && r[0].user_id === B && r[0].relation === 'none' && r[0].trophies === 420, 'Name gefunden (Groß-/Kleinschreibung egal)', r);
  r = await as(A, `select * from find_player($1)`, [codeB.slice(0, 3).toLowerCase() + '-' + codeB.slice(3)]); ok(r.length === 1 && r[0].user_id === B, 'Freundescode gefunden (klein, mit Bindestrich)', r);
  r = await as(A, `select * from find_player('Mi')`); ok(r.length === 0, 'kein Teiltreffer (kein Stöbern)');
  r = await as(A, `select * from find_player('Ivan')`); ok(r.length === 1 && r[0].relation === 'self', 'sich selbst: relation self');

  // Anfrage A → B
  r = await one(A, `select send_friend_request($1) s`, [B]); ok(r.s === 'sent', 'Anfrage gesendet', r);
  ok(JSON.stringify(await outbox()) === JSON.stringify([{ recipient: B, actor: A, kind: 'friend_request', actor_name: 'Ivan' }]), 'Push für B vorgemerkt', await outbox());
  r = await one(A, `select send_friend_request($1) s`, [B]); ok(r.s === 'sent' && (await outbox()).length === 1, 'doppelte Anfrage: keine zweite Nachricht');
  r = await one(B, `select friend_request_count() n`); ok(r.n === 1, 'B: 1 offene Anfrage');
  r = await as(B, `select * from my_friends()`); ok(r.length === 1 && r[0].user_id === A && r[0].relation === 'incoming', 'B sieht die Anfrage', r);
  r = await as(A, `select * from my_friends()`); ok(r.length === 1 && r[0].relation === 'outgoing', 'A sieht sie als gesendet');
  r = await one(A, `select friend_profile($1) p`, [C]); ok(r.error === 'not_allowed', 'Profil-Übersicht nur für Freunde und Anfragen');
  r = await one(B, `select friend_profile($1) p`, [A]); ok(r.p && r.p.display_name === 'Ivan' && r.p.relation === 'incoming', 'B darf das Profil des Anfragenden sehen', r);
  r = await one(A, `select send_friend_request($1) s`, [A]); ok(r.error === 'not_allowed', 'sich selbst anfragen verboten');
  r = await one(A, `select send_friend_request('eeeeeeee-0000-0000-0000-000000000000') s`); ok(r.error === 'not_found', 'unbekannter Spieler');

  // Annehmen
  r = await one(B, `select respond_friend_request($1, true) s`, [A]); ok(r.s === 'accepted', 'B nimmt an', r);
  ok((await outbox()).some(x => x.kind === 'friend_accepted' && x.recipient === A && x.actor_name === 'Mia'), 'Push für A: angenommen');
  r = await as(A, `select * from my_friends()`); ok(r.length === 1 && r[0].relation === 'friend', 'jetzt Freunde');
  r = await one(B, `select friend_request_count() n`); ok(r.n === 0, 'B: keine offene Anfrage mehr');
  r = await one(A, `select send_friend_request($1) s`, [B]); ok(r.s === 'already_friends', 'schon befreundet');
  r = await one(B, `select respond_friend_request($1, true) s`, [A]); ok(r.error === 'no_request', 'nichts mehr anzunehmen');
  r = await one(A, `select friend_profile($1) p`, [B]);
  ok(r.p && r.p.trophies === 420 && r.p.friends === 1 && r.p.vs_wins === 0 && r.p.rank === 1 && r.p.relation === 'friend', 'Profil-Übersicht eines Freundes', r);

  // Gegenseitig: C fragt A, A fragt C → sofort Freunde
  await one(C, `select send_friend_request($1) s`, [A]);
  r = await one(A, `select send_friend_request($1) s`, [C]); ok(r.s === 'accepted', 'beide fragen sich: gleich Freunde', r);
  await as(A, `select remove_friend($1)`, [C]);
  r = await as(A, `select * from my_friends()`); ok(r.length === 1 && r[0].user_id === B, 'Freund entfernt');

  // Ablehnen: still, keine neue Anfrage für 30 Tage
  await one(C, `select send_friend_request($1) s`, [B]);
  r = await one(B, `select respond_friend_request($1, false) s`, [C]); ok(r.s === 'declined', 'B lehnt ab');
  const before = (await outbox()).length;
  r = await one(C, `select send_friend_request($1) s`, [B]); ok(r.s === 'sent' && (await outbox()).length === before, 'nach Ablehnung: sieht gesendet aus, aber keine Nachricht');
  r = await one(B, `select friend_request_count() n`); ok(r.n === 0, 'B wird nicht erneut gefragt');

  // Blockieren
  await one(A, `select send_friend_request($1) s`, [C]);
  await as(C, `select block_player($1)`, [A]);
  r = await as(C, `select * from my_friends()`); ok(r.length === 0, 'Blockieren entfernt die Anfrage');
  r = await as(A, `select * from find_player('Noah')`); ok(r.length === 0, 'blockiert: nicht mehr zu finden');
  r = await one(A, `select send_friend_request($1) s`, [C]); ok(r.s === 'sent', 'blockiert: Anfrage sieht gesendet aus');
  r = await one(C, `select friend_request_count() n`); ok(r.n === 0, '…kommt aber nicht an');
  r = await as(C, `select * from blocked_players()`); ok(r.length === 1 && r[0].display_name === 'Ivan', 'Liste der Blockierten');
  await as(C, `select unblock_player($1)`, [A]);
  r = await as(A, `select * from find_player('Noah')`); ok(r.length === 1, 'nach Aufheben wieder zu finden');

  // Melden
  r = await as(A, `select report_player($1, 'name')`, [B]); ok(!r.error, 'Spieler melden');
  await as(A, `select report_player($1, 'cheating')`, [B]);
  r = await c.query(`select count(*)::int n from player_reports`); ok(r.rows[0].n === 1, 'dieselbe Person nur einmal am Tag');
  r = await as(A, `select report_player($1, 'spam')`, [B]); ok(r.error === 'bad_reason', 'unbekannter Grund');

  // Spam-Bremse beim Suchen: 60 je Stunde
  await c.query(`delete from private.rate_events`);
  for (let i = 0; i < 60; i++) await as(B, `select * from find_player('Ivan')`);
  r = await as(B, `select * from find_player('Ivan')`); ok(r.error === 'too_many_requests', 'Suche: höchstens 60 je Stunde', r);

  // Push-Geräte
  const tok = 'ab'.repeat(32);
  r = await as(A, `select register_push_token('ios', 'xyz', 'production', null, 'de')`); ok(r.error === 'bad_token', 'ungültiges iOS-Token abgelehnt');
  r = await as(A, `select register_push_token('ios', $1, 'sandbox', null, 'de-DE')`, [tok]); ok(!r.error, 'iOS-Gerät angemeldet', r);
  const sub = { endpoint: 'https://push.example.com/abc123456789', keys: { p256dh: 'BPk', auth: 'xyz' } };
  r = await as(A, `select register_push_token('web', null, null, $1, 'fr')`, [sub]); ok(!r.error, 'Browser angemeldet', r);
  r = await as(A, `select register_push_token('web', null, null, $1, 'fr')`, [{ endpoint: 'http://insecure.example.com/x', keys: { p256dh: 'a', auth: 'b' } }]);
  ok(r.error === 'bad_token', 'Web-Push nur über https');
  r = (await c.query(`select platform, locale, environment from push_tokens where user_id = $1 order by platform`, [A])).rows;
  ok(r.length === 2 && r[0].locale === 'de' && r[0].environment === 'sandbox' && r[1].locale === 'fr', 'Sprache und Server je Gerät', r);
  await as(B, `select register_push_token('ios', $1, 'sandbox', null, 'en')`, [tok]);
  r = (await c.query(`select user_id from push_tokens where token = $1`, [tok])).rows; ok(r[0].user_id === B, 'Gerät gehört dem zuletzt angemeldeten Konto');
  await as(A, `select unregister_push_token($1)`, [tok]);
  r = (await c.query(`select count(*)::int n from push_tokens where token = $1`, [tok])).rows; ok(r[0].n === 1, 'fremdes Gerät nicht abmeldbar');

  // push-dispatch: holt die Nachrichten eines Absenders genau einmal
  r = await as(A, `select * from claim_push_outbox($1)`, [C]); ok(!!r.error, 'App darf keine Nachrichten abholen');
  await c.query(`delete from push_outbox`);
  await as(C, `select register_push_token('web', null, null, $1, 'it')`, [{ endpoint: 'https://push.example.com/noah-device-1', keys: { p256dh: 'BPk', auth: 'xyz' } }]);
  r = await one(A, `select send_friend_request($1) s`, [C]); ok(r.s === 'sent', 'neue Anfrage an C', r);
  r = await as('service', `select * from claim_push_outbox($1)`, [A]);
  ok(r.length === 1 && r[0].kind === 'friend_request' && r[0].actor_name === 'Ivan' && r[0].locale === 'it' && r[0].platform === 'web', 'Anfrage von A an C: ein Gerät von C', r);
  r = await as('service', `select * from claim_push_outbox($1)`, [A]); ok(r.length === 0, 'zweiter Abruf: nichts mehr (kein doppelter Push)');
  await as('service', `select drop_push_tokens($1)`, [['https://push.example.com/noah-device-1']]);
  r = (await c.query(`select count(*)::int n from push_tokens where user_id = $1`, [C])).rows; ok(r[0].n === 0, 'abgemeldetes Gerät entfernt');

  // Konto löschen räumt alles ab
  await c.query(`delete from auth.users where id = $1`, [B]);
  r = (await c.query(`select (select count(*) from friendships where $1 in (requester, addressee))::int f,
                             (select count(*) from push_tokens where user_id = $1)::int t,
                             (select count(*) from push_outbox where recipient = $1 or actor = $1)::int o`, [B])).rows[0];
  ok(r.f === 0 && r.t === 0 && r.o === 0, 'Konto gelöscht: Freundschaften, Geräte, Nachrichten weg', r);
  r = (await c.query(`select private.cleanup_social() n`)).rows; ok(r[0].n >= 0, 'Aufräum-Job läuft');
  // Meldungen bleiben höchstens ein Jahr
  await c.query(`insert into player_reports (reporter, reported, reason, created_at) values ($1, $2, 'other', now() - interval '13 months'), ($1, $2, 'other', now() - interval '11 months')`, [A, C]);
  await c.query(`select private.cleanup_social()`);
  r = (await c.query(`select count(*) filter (where created_at < now() - interval '1 year')::int old, count(*) filter (where created_at < now() - interval '10 months')::int recent from player_reports`)).rows[0];
  ok(r.old === 0 && r.recent === 1, 'Meldungen älter als ein Jahr gelöscht, jüngere bleiben', r);

  console.log(fails ? fails + ' Fehler' : 'Freunde bestanden');
  await c.end(); process.exit(fails ? 1 : 0);
})();
