'use strict';
// Prüft den JS-Port gegen die gespeicherten Erwartungen: node check-golden.js (Exit-Code 1 bei Abweichung)
const fs = require('fs');
const path = require('path');
const R = require('./rules');
R.loadRules();
const g = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'RookRaid', 'Engine', 'rookraid-golden.json'), 'utf8'));
let bad = 0;
for (const c of g.cases) {
  const got = R.run(c);
  if (JSON.stringify(got) !== JSON.stringify(c.expect)) { bad++; console.log('ABWEICHUNG', c.name, '\n  erwartet', JSON.stringify(c.expect), '\n  erhalten', JSON.stringify(got)); }
}
console.log(`${g.cases.length - bad}/${g.cases.length} Fälle stimmen`);
process.exit(bad ? 1 : 0);
