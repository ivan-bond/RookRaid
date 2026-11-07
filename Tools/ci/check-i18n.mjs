// iOS and web share one set of texts (RookRaid/Localization/*.json, the key is the German text).
// Fails when a language misses keys, when placeholders like {0} differ, or when the app or the web
// shows a text that has no English translation (it would appear in German for everyone).
import fs from 'fs';
import path from 'path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const dir = path.join(root, 'RookRaid/Localization');
const langs = ['en', 'fr', 'es', 'it', 'ru', 'zh'];
let fails = 0;
const fail = (msg) => { fails++; console.log('FAIL', msg); };

const packs = {};
for (const lang of langs) {
  try {
    packs[lang] = JSON.parse(fs.readFileSync(path.join(dir, `${lang}.json`), 'utf8'));
  } catch (e) {
    fail(`${lang}.json is not valid JSON: ${e.message}`);
    packs[lang] = {};
  }
}

// 1. Every language has the same keys as English.
const en = packs.en;
const keys = Object.keys(en);
for (const lang of langs.filter((l) => l !== 'en')) {
  const have = packs[lang];
  const missing = keys.filter((k) => !(k in have));
  const extra = Object.keys(have).filter((k) => !(k in en));
  for (const k of missing) fail(`${lang}.json misses "${k}"`);
  for (const k of extra) fail(`${lang}.json has "${k}", which en.json does not have`);
}

// 2. Placeholders: the translation needs exactly the {n} of the German key.
const holes = (s) => [...s.matchAll(/\{(\d+)\}/g)].map((m) => m[1]).sort().join(',');
for (const lang of langs) {
  for (const [k, v] of Object.entries(packs[lang])) {
    if (typeof v !== 'string') { fail(`${lang}.json: "${k}" is not a string`); continue; }
    if (holes(k) !== holes(v)) fail(`${lang}.json: placeholders differ for "${k}" ({${holes(k)}} vs {${holes(v)}})`);
  }
}

// 3. Texts the apps show must be translated. Only plain literals: L("…") in Swift, t('…') on the web.
function walk(d, ext, out = []) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p, ext, out);
    else if (ext.some((x) => e.name.endsWith(x))) out.push(p);
  }
  return out;
}
const unescape = (s) => s.replace(/\\n/g, '\n').replace(/\\"/g, '"').replace(/\\'/g, "'").replace(/\\\\/g, '\\');
const webOnly = fs.readFileSync(path.join(root, 'web/src/copy.ts'), 'utf8');
const inWebOnly = (k) => webOnly.includes(JSON.stringify(k).slice(1, -1)) || webOnly.includes(`'${k.replace(/'/g, "\\'")}'`);

const used = new Map();
for (const f of walk(path.join(root, 'RookRaid'), ['.swift'])) {
  const src = fs.readFileSync(f, 'utf8');
  for (const m of src.matchAll(/\bL\(\s*"((?:[^"\\\n]|\\.)*)"/g)) {
    if (m[1].includes('\\(')) continue; // interpolated, not a key
    used.set(unescape(m[1]), path.relative(root, f));
  }
}
for (const f of walk(path.join(root, 'web/src'), ['.ts', '.tsx'])) {
  if (f.endsWith('copy.ts')) continue;
  const src = fs.readFileSync(f, 'utf8');
  for (const m of src.matchAll(/\bt\(\s*'((?:[^'\\\n]|\\.)*)'/g)) used.set(unescape(m[1]), path.relative(root, f));
  for (const m of src.matchAll(/\bt\(\s*"((?:[^"\\\n]|\\.)*)"/g)) used.set(unescape(m[1]), path.relative(root, f));
}
const untranslated = [...used].filter(([k]) => !(k in en) && !inWebOnly(k));
for (const [k, f] of untranslated) fail(`"${k}" (${f}) has no translation`);

if (fails) {
  console.log(`${fails} problem(s) with the shared texts.`);
  process.exit(1);
}
console.log(`${keys.length} texts in ${langs.length + 1} languages, ${used.size} used by the app and the web – all consistent.`);
