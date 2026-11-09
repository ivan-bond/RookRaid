// npm run upload-zip: build, then pack dist/ into upload/rookraid-web.zip for Hostinger (File Manager → public_html → Extract).
// Stops if the build is missing values it needs online, so a broken offline build never goes live.
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync } from 'node:fs'
import { join } from 'node:path'
import { loadEnv } from 'vite'

const root = new URL('..', import.meta.url).pathname
const env = loadEnv('production', root, 'VITE_')
const missing = ['VITE_SUPABASE_URL', 'VITE_SUPABASE_ANON_KEY', 'VITE_VAPID_PUBLIC_KEY'].filter(k => !env[k])
if (missing.length) {
  console.error(`Missing in web/.env.local: ${missing.join(', ')} – the site would not reach the server.`)
  process.exit(1)
}

execFileSync('npm', ['run', 'build'], { cwd: root, stdio: 'inherit' })

const dist = join(root, 'dist')
for (const f of ['.htaccess', '.well-known/apple-app-site-association', 'index.html', 'sw.js']) {
  if (!existsSync(join(dist, f))) { console.error(`dist/${f} is missing.`); process.exit(1) }
}
JSON.parse(readFileSync(join(dist, '.well-known/apple-app-site-association'), 'utf8'))
const bundle = readdirSync(join(dist, 'assets')).filter(f => f.endsWith('.js'))
  .some(f => readFileSync(join(dist, 'assets', f), 'utf8').includes(env.VITE_VAPID_PUBLIC_KEY))
if (!bundle) { console.error('The push key is not in the bundle.'); process.exit(1) }

const out = join(root, 'upload')
mkdirSync(out, { recursive: true })
const zip = join(out, 'rookraid-web.zip')
rmSync(zip, { force: true })
// _headers/_redirects are for Cloudflare/Netlify; Hostinger uses .htaccess.
execFileSync('zip', ['-qr', '-X', zip, '.', '-x', '*.DS_Store', '_headers', '_redirects'], { cwd: dist, stdio: 'inherit' })
console.log(`\nReady: web/upload/rookraid-web.zip – upload it to public_html in Hostinger's File Manager and extract it there.`)
