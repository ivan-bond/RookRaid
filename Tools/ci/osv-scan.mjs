// Asks osv.dev about every locked npm and Swift package.
// The OSV GitHub Action (v2.3.2) has no reader for Package.resolved, so this script does that query itself.
import fs from 'fs';

const root = new URL('../../', import.meta.url);
const queries = [];

const lock = JSON.parse(fs.readFileSync(new URL('Backend/tests/package-lock.json', root), 'utf8'));
for (const [path, meta] of Object.entries(lock.packages ?? {})) {
  if (!path.startsWith('node_modules/') || !meta.version) continue;
  const name = path.split('node_modules/').pop();
  queries.push({ label: `${name}@${meta.version}`, query: { package: { name, ecosystem: 'npm' }, version: meta.version } });
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
  const vulns = data.results?.[i]?.vulns ?? [];
  if (!vulns.length) continue;
  fails += vulns.length;
  console.log('FAIL', queries[i].label, vulns.map((vuln) => vuln.id).join(', '));
}
if (fails) process.exit(1);
console.log(`${queries.length} packages, no known vulnerabilities`);
