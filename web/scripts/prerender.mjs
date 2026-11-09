// Build step 3: writes the public pages into dist/ as real HTML (dist/how-to-play/index.html, dist/privacy/index.html, …)
// with their own title, description, canonical, social tags and JSON-LD, and writes dist/sitemap.xml.
// The browser then starts the app on the same page (src/main.tsx) and renders it again.
import fs from 'node:fs'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const root = new URL('..', import.meta.url).pathname
const dist = path.join(root, 'dist')
const ssr = path.join(root, 'dist-ssr')
const { renderPages, SITE } = await import(pathToFileURL(path.join(ssr, 'prerender.js')).href)

const template = fs.readFileSync(path.join(dist, 'index.html'), 'utf8')
const esc = s => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
function swap(html, re, value, label) {
  if (!re.test(html)) throw new Error(`prerender: ${label} not found in dist/index.html`)
  return html.replace(re, value)
}

const pages = await renderPages()
for (const p of pages) {
  const url = `${SITE}${p.path}`
  let html = template
  html = swap(html, /<title>[\s\S]*?<\/title>/, `<title>${esc(p.title)}</title>`, 'title')
  html = swap(html, /<meta name="description" content="[^"]*" \/>/, `<meta name="description" content="${esc(p.description)}" />`, 'description')
  html = swap(html, /<link rel="canonical" href="[^"]*" \/>/, `<link rel="canonical" href="${url}" />`, 'canonical')
  html = swap(html, /<meta property="og:type" content="[^"]*" \/>/, '<meta property="og:type" content="article" />', 'og:type')
  html = swap(html, /<meta property="og:url" content="[^"]*" \/>/, `<meta property="og:url" content="${url}" />`, 'og:url')
  html = swap(html, /<meta property="og:title" content="[^"]*" \/>/, `<meta property="og:title" content="${esc(p.title)}" />`, 'og:title')
  html = swap(html, /<meta property="og:description" content="[^"]*" \/>/, `<meta property="og:description" content="${esc(p.description)}" />`, 'og:description')
  html = swap(html, /<meta name="twitter:title" content="[^"]*" \/>/, `<meta name="twitter:title" content="${esc(p.title)}" />`, 'twitter:title')
  html = swap(html, /<meta name="twitter:description" content="[^"]*" \/>/, `<meta name="twitter:description" content="${esc(p.description)}" />`, 'twitter:description')
  html = swap(html, /<script type="application\/ld\+json" id="ld-json">[\s\S]*?<\/script>/,
    `<script type="application/ld+json" id="ld-json">${JSON.stringify(p.jsonLd).replace(/</g, '\\u003c')}</script>`, 'JSON-LD')
  html = swap(html, /<!--prerender-start-->[\s\S]*?<!--prerender-end-->/, `<!--prerender-start-->${p.html}<!--prerender-end-->`, 'page body')
  html = html.replace('<body>', '<body class="legal-body">')
  const dir = path.join(dist, p.path)
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(path.join(dir, 'index.html'), html)
}

const today = new Date().toISOString().slice(0, 10)
const urls = [{ path: '/', priority: 1 }, ...pages]
const sitemap = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map(u => `  <url><loc>${SITE}${u.path}</loc><lastmod>${today}</lastmod><priority>${u.priority.toFixed(1)}</priority></url>`).join('\n')}
</urlset>
`
fs.writeFileSync(path.join(dist, 'sitemap.xml'), sitemap)
fs.rmSync(ssr, { recursive: true, force: true })
console.log(`Prerendered ${pages.length} public pages and the sitemap.`)
