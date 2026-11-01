// Lädt Stub, alle Migrationen und den Regel-Seed. pg_cron gibt es im Test-Postgres nicht;
// die Zeile „create extension pg_cron“ wird übersprungen, cron_stub.sql liefert die beiden Aufrufe.
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', 'supabase');

function sqlOf(file) {
  return fs.readFileSync(file, 'utf8')
    .replace(/create extension if not exists pg_cron with schema pg_catalog;\s*/gi, '-- pg_cron: see cron_stub.sql\n');
}

(async () => {
  const migrations = fs.readdirSync(path.join(root, 'migrations'))
    .filter((name) => name.endsWith('.sql'))
    .sort()
    .map((name) => path.join(root, 'migrations', name));
  const files = [
    path.join(__dirname, 'stub.sql'),
    path.join(__dirname, 'cron_stub.sql'),
    ...migrations,
    path.join(root, 'seed', 'rules.sql'),
  ];
  const c = new Client({ connectionString: process.env.DB_URL });
  await c.connect();
  for (const file of files) {
    try {
      await c.query(sqlOf(file));
      console.log('OK', path.relative(path.join(__dirname, '..'), file));
    } catch (e) {
      console.log('FEHLER', file, e.message, e.where || '', e.position || '');
      process.exitCode = 1;
      break;
    }
  }
  await c.end();
})();
