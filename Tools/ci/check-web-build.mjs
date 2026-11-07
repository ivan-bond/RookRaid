// Checks the built browser version (web/dist):
// - the legal pages App Store Connect links to exist as real files,
// - no secret got into the bundle. The anon (public) key may be there; a service-role key,
//   a Supabase secret key or a private key may never be.
import fs from 'fs';
import path from 'path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..');
const dist = path.join(root, 'web/dist');
let fails = 0;
const fail = (msg) => { fails++; console.log('FAIL', msg); };

if (!fs.existsSync(path.join(dist, 'index.html'))) {
  console.log('FAIL web/dist/index.html is missing – run npm run build first.');
  process.exit(1);
}

for (const page of ['privacy', 'imprint', 'terms', 'support']) {
  const file = path.join(dist, page, 'index.html');
  if (!fs.existsSync(file)) { fail(`/${page} is not built (web/dist/${page}/index.html)`); continue; }
  if (fs.statSync(file).size < 1000) fail(`/${page} looks empty`);
}

function walk(d, out = []) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) walk(p, out);
    else if (/\.(js|mjs|html|json|webmanifest|css|map)$/.test(e.name)) out.push(p);
  }
  return out;
}

const jwtRole = (token) => {
  try {
    const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(payload, 'base64').toString('utf8')).role ?? null;
  } catch { return null; }
};

for (const file of walk(dist)) {
  const text = fs.readFileSync(file, 'utf8');
  const rel = path.relative(root, file);
  if (/-----BEGIN (RSA |OPENSSH |EC |PGP )?PRIVATE KEY-----/.test(text)) fail(`${rel} contains a private key`);
  if (/sb_secret_[A-Za-z0-9_-]{10,}/.test(text)) fail(`${rel} contains a Supabase secret key`);
  for (const [token] of text.matchAll(/eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]+/g)) {
    if (jwtRole(token) === 'service_role') fail(`${rel} contains a service-role key`);
  }
}

if (fails) process.exit(1);
console.log('Legal pages built, no secrets in the browser bundle.');
