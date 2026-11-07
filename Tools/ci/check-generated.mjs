// The rules live in RookRaid/Engine/rookraid-rules.json. Three files are generated from them and must be
// up to date, or the iPhone, the browser and the server play different games:
// - the server bundle the Edge Functions use to check moves (build-server.js),
// - the rules row the database seeds (seed-rules.js),
// - the expected results the app's rule tests compare against (make-golden.js; the date stamp is ignored).
import { execFileSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const tools = path.join(root, 'Tools/rules-js');
let fails = 0;

function regenerate(script, rel, normalize = (s) => s) {
  const file = path.join(root, rel);
  const before = fs.readFileSync(file, 'utf8');
  try {
    execFileSync('node', [path.join(tools, script)], { cwd: root, stdio: 'ignore' });
    const after = fs.readFileSync(file, 'utf8');
    if (normalize(before) !== normalize(after)) {
      fails++;
      console.log(`FAIL ${rel} is out of date. Run: node Tools/rules-js/${script}`);
    } else console.log(`ok   ${rel}`);
  } finally {
    fs.writeFileSync(file, before); // leave the checkout as it was
  }
}

regenerate('build-server.js', 'Backend/supabase/functions/_shared/rookraid-rules.mjs');
regenerate('seed-rules.js', 'Backend/supabase/seed/rules.sql');
regenerate('make-golden.js', 'RookRaid/Engine/rookraid-golden.json', (s) => {
  const { generated, ...rest } = JSON.parse(s);
  return JSON.stringify(rest);
});

if (fails) process.exit(1);
