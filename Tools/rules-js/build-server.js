'use strict';
// Bündelt den Regel-Kern (engine.js + core.js) als ES-Modul für Supabase Edge Functions (Deno):
//   node build-server.js  →  Backend/supabase/functions/_shared/rookraid-rules.mjs
// Danach: node check-server.mjs prüft das Bündel gegen dieselben Regeltests wie App und Node-Port.
// Nach jeder Regeländerung neu bündeln und die Functions neu deployen (supabase functions deploy).
const fs = require('fs');
const path = require('path');

const mods = ['engine', 'core'];
const out = path.join(__dirname, '..', '..', 'Backend', 'supabase', 'functions', '_shared', 'rookraid-rules.mjs');
let code = `// GENERIERT von Tools/rules-js/build-server.js – nicht von Hand ändern.\n` +
  `// Rook-Raid-Regeln (derselbe Stand wie die App) als ES-Modul für Deno/Supabase Edge Functions.\n` +
  `const __defs = {}, __cache = {};\n` +
  `function __require(name) {\n  const key = name.replace(/^\\.\\//, '').replace(/\\.js$/, '');\n` +
  `  if (__cache[key]) return __cache[key].exports;\n  const module = { exports: {} };\n  __cache[key] = module;\n` +
  `  __defs[key](module, module.exports, __require);\n  return module.exports;\n}\n`;
for (const m of mods) {
  const src = fs.readFileSync(path.join(__dirname, m + '.js'), 'utf8');
  if (/require\((?!'\.\/(engine|core)')/.test(src)) throw new Error(m + '.js nutzt ein Node-Modul – im Server-Bündel nicht erlaubt');
  code += `\n__defs[${JSON.stringify(m)}] = function (module, exports, require) {\n${src}\n};\n`;
}
code += `\nconst core = __require('core');\n` +
  `export const { E, applyRules, initialFromRecord, replay, setup, apply, placement, run, side } = core;\nexport default core;\n`;
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, code);
console.log('geschrieben:', path.relative(process.cwd(), out), (code.length / 1024).toFixed(0) + ' KB');
