// node q.js file.sql  – führt SQL-Dateien nacheinander aus (lokaler Test-Postgres)
const { Client } = require('pg'); const fs = require('fs');
(async () => {
  const c = new Client({ connectionString: process.env.DB_URL });
  await c.connect();
  for (const f of process.argv.slice(2)) {
    try { const r = await c.query(fs.readFileSync(f, 'utf8')); const rows = [].concat(r).filter(x => x.rows && x.rows.length).map(x => x.rows); console.log('OK', f, rows.length ? JSON.stringify(rows.slice(-1)[0]).slice(0, 2000) : ''); }
    catch (e) { console.log('FEHLER', f, e.message, e.where || '', e.position || ''); process.exitCode = 1; break; }
  }
  await c.end();
})();
