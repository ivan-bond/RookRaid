'use strict';
// Erwartete Ergebnisse der Regeltests aus dem JS-Port erzeugen: node make-golden.js
// Ergebnis: RookRaid/Engine/rookraid-golden.json – die App prüft dieselben Fälle (Einstellungen → Regeltests, nur Debug).
const fs = require('fs');
const path = require('path');
const R = require('./rules');
const rules = R.loadRules();
const cases = JSON.parse(fs.readFileSync(path.join(__dirname, 'golden-cases.json'), 'utf8'));
const out = { rulesVersion: rules.version, generated: new Date().toISOString().slice(0, 10), cases: cases.map(c => ({ ...c, expect: R.run(c) })) };
const file = path.join(__dirname, '..', '..', 'RookRaid', 'Engine', 'rookraid-golden.json');
fs.writeFileSync(file, JSON.stringify(out, null, 1));
for (const c of out.cases) console.log((c.expect.rejectedAt === null ? 'ok   ' : 'rej@' + c.expect.rejectedAt + ' ') + c.name.padEnd(48) + ' ' + c.expect.status + ' ' + c.expect.side + ' ' + JSON.stringify(c.expect.mana));
console.log(out.cases.length + ' Fälle →', path.relative(process.cwd(), file));
