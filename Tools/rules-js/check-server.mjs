// Prüft das Server-Bündel gegen die Regeltests: node check-server.mjs (Exit-Code 1 bei Abweichung)
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import * as R from '../../Backend/supabase/functions/_shared/rookraid-rules.mjs';
const here = path.dirname(fileURLToPath(import.meta.url));
const rules = JSON.parse(fs.readFileSync(path.join(here, '..', '..', 'RookRaid', 'Engine', 'rookraid-rules.json'), 'utf8'));
const g = JSON.parse(fs.readFileSync(path.join(here, '..', '..', 'RookRaid', 'Engine', 'rookraid-golden.json'), 'utf8'));
R.applyRules(rules);
let bad = 0;
for (const c of g.cases) {
  const got = R.run(c);
  if (JSON.stringify(got) !== JSON.stringify(c.expect)) { bad++; console.log('ABWEICHUNG', c.name, JSON.stringify(got)); }
}
// Ganze Partie wie auf dem Server: replay(setup, actions)
const r = R.replay({ decks: { white: ['shield', 'freeze', 'sprint', 'lightning'], black: ['shield', 'freeze', 'sprint', 'lightning'] },
  ultimates: { white: 'meteor', black: 'meteor' } }, ['f2f3', 'e7e5', 'g2g4', 'd8h4']);
if (r.failedAt !== null || r.state.status() !== 'mate') { bad++; console.log('ABWEICHUNG replay', r.failedAt, r.state.status()); }
console.log(`Server-Bündel: ${g.cases.length - bad}/${g.cases.length} Fälle stimmen, replay ${r.state.status()}`);
process.exit(bad ? 1 : 0);
