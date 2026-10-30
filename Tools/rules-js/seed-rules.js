'use strict';
// Erzeugt das SQL, das die aktuellen Regeln (RookRaid/Engine/rookraid-rules.json) in rules_config einträgt und
// als einzige aktive Version setzt:  node seed-rules.js  →  Backend/supabase/seed/rules.sql
// KEEP_OLD=1 node seed-rules.js lässt ältere Versionen aktiv (Übergang: alte App-Versionen finden weiter Gegner untereinander).
// Einspielen: im SQL-Editor ausführen oder  psql "$DB_URL" -f Backend/supabase/seed/rules.sql
const fs = require('fs');
const path = require('path');
const file = path.join(__dirname, '..', '..', 'RookRaid', 'Engine', 'rookraid-rules.json');
const rules = JSON.parse(fs.readFileSync(file, 'utf8'));
const json = JSON.stringify(rules).replace(/'/g, "''");
const sql = `-- GENERIERT von Tools/rules-js/seed-rules.js aus RookRaid/Engine/rookraid-rules.json – Regel-Version ${rules.version}
insert into public.rules_config (version, config, active)
values (${rules.version}, '${json}'::jsonb, true)
on conflict (version) do update set config = excluded.config, active = true;
${process.env.KEEP_OLD ? '-- KEEP_OLD: ältere Versionen bleiben aktiv (Übergangszeit, bis alle Spieler aktualisiert haben)\n' : `update public.rules_config set active = false where version <> ${rules.version};\n`}`;
const out = path.join(__dirname, '..', '..', 'Backend', 'supabase', 'seed', 'rules.sql');
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, sql);
console.log('geschrieben:', path.relative(process.cwd(), out), '– Regel-Version', rules.version);
