// Asks osv.dev about every locked npm and Swift package.
// The OSV GitHub Action (v2.3.2) has no reader for Package.resolved, so this script does that query itself.
import fs from 'fs';

const root = new URL('../../', import.meta.url);

// Advisories that are checked and accepted, with the reason. Each entry names the exact package
// version, so an update (or a new advisory) shows up again. Remove an entry once a fix exists.
const accepted = {
  // Prototype poisoning in mergeObject(). Only used at build time by the PWA plugin
  // (workbox-build -> @rollup/plugin-node-resolve) on our own config; never shipped to the browser.
  // No fixed version exists yet.
  'deepmerge@4.3.1': ['GHSA-gcqx-w48m-w2h4'],
};
const queries = [];

// The backend test client and the browser version (web/) each have a lockfile.
for (const file of ['Backend/tests/package-lock.json', 'web/package-lock.json']) {
  const lock = JSON.parse(fs.readFileSync(new URL(file, root), 'utf8'));
  for (const [path, meta] of Object.entries(lock.packages ?? {})) {
    if (!path.startsWith('node_modules/') || !meta.version) continue;
    const name = path.split('node_modules/').pop();
    queries.push({ key: `${name}@${meta.version}`, label: `${name}@${meta.version} (${file.split('/')[0]})`, query: { package: { name, ecosystem: 'npm' }, version: meta.version } });
  }
}

const resolved = JSON.parse(fs.readFileSync(new URL('RookRaid.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved', root), 'utf8'));
for (const pin of resolved.pins ?? []) {
  const name = pin.location.replace(/^https?:\/\//, '').replace(/\.git$/, '');
  const version = pin.state?.version;
  if (!version) continue;
  queries.push({
    label: `${name}@${version}`,
    query: { package: { name, ecosystem: 'SwiftURL' }, version },
  });
}

const response = await fetch('https://api.osv.dev/v1/querybatch', {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ queries: queries.map((item) => item.query) }),
});
if (!response.ok) {
  console.error('OSV query failed', response.status, await response.text());
  process.exit(1);
}
const data = await response.json();
let fails = 0;
for (let i = 0; i < queries.length; i++) {
  const ok = accepted[queries[i].key] ?? [];
  const all = data.results?.[i]?.vulns ?? [];
  for (const vuln of all.filter((v) => ok.includes(v.id))) console.log('ACCEPTED', queries[i].label, vuln.id);
  const vulns = all.filter((v) => !ok.includes(v.id));
  if (!vulns.length) continue;
  fails += vulns.length;
  console.log('FAIL', queries[i].label, vulns.map((vuln) => vuln.id).join(', '));
}
if (fails) process.exit(1);
console.log(`${queries.length} packages, no known vulnerabilities`);
