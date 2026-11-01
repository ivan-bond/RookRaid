// Rechte nach allen Migrationen. Eine Zeile hier ist ein Loch: die App könnte schreiben,
// eine Funktion ohne festen Suchpfad aufrufen, oder ein Gast eine Spielfunktion nutzen.
const { Client } = require('pg');

const checks = [
  {
    name: 'RLS fehlt auf einer Online-Tabelle',
    sql: `select c.relname as detail
          from pg_class c
          join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relkind = 'r'
            and c.relname in ('profiles','progress','matches','match_actions','match_presence','matchmaking_queue','rules_config')
            and not c.relrowsecurity`,
  },
  {
    name: 'security definer ohne search_path, aufrufbar von anon oder authenticated',
    sql: `select n.nspname || '.' || p.proname as detail
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where p.prosecdef and n.nspname in ('public', 'private')
            and (has_function_privilege('anon', p.oid, 'execute')
              or has_function_privilege('authenticated', p.oid, 'execute'))
            and not exists (
              select 1 from unnest(coalesce(p.proconfig, array[]::text[])) cfg
              where cfg like 'search_path=%')`,
  },
  {
    name: 'Gast darf eine Spielfunktion aufrufen',
    sql: `select p.proname as detail
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public'
            and has_function_privilege('anon', p.oid, 'execute')
            and p.proname in (
              'find_match','name_available','record_action','finish_match','setup_account',
              'set_display_name','backup_progress','create_match','apply_result','start_bot_match',
              'resign_match','offer_draw','answer_draw','claim_timeout','maintain_matches',
              'purge_abandoned_anonymous')`,
  },
  {
    name: 'App darf eine Tabelle schreiben, die nur der Server schreiben darf',
    sql: `select g.role || ' ' || p.priv || ' ' || c.relname as detail
          from pg_class c
          join pg_namespace n on n.oid = c.relnamespace
          cross join (values ('anon'), ('authenticated')) as g(role)
          cross join (values ('INSERT'), ('UPDATE'), ('DELETE')) as p(priv)
          where n.nspname = 'public' and c.relkind = 'r'
            and has_table_privilege(g.role, c.oid, p.priv)
            and not (g.role = 'authenticated' and c.relname = 'profiles' and p.priv = 'UPDATE')`,
  },
  {
    name: 'Profil-Update geht über die Kosmetik hinaus',
    sql: `select column_name as detail
          from information_schema.column_privileges
          where table_schema = 'public' and table_name = 'profiles'
            and grantee = 'authenticated' and privilege_type = 'UPDATE'
            and column_name not in ('avatar','frame','title','piece_set','level','updated_at')`,
  },
];

(async () => {
  const c = new Client({ connectionString: process.env.DB_URL });
  await c.connect();
  let fails = 0;
  for (const check of checks) {
    const rows = (await c.query(check.sql)).rows;
    if (rows.length) {
      fails += rows.length;
      console.log('FAIL', check.name, rows.map((row) => row.detail).join(', '));
    } else {
      console.log('ok  ', check.name);
    }
  }
  await c.query('begin');
  try {
    await c.query('set local role anon');
    await c.query(`select name_available('Mia')`);
    fails++;
    console.log('FAIL anon konnte name_available aufrufen');
  } catch (e) {
    if (e.code === '42501') console.log('ok   anon name_available abgelehnt');
    else { fails++; console.log('FAIL anon name_available:', e.message); }
  }
  await c.query('rollback');
  await c.end();
  process.exit(fails ? 1 : 0);
})();
