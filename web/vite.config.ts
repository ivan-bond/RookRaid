import { build } from 'esbuild'
import fs from 'node:fs'
import path from 'node:path'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

const rulesEntry = path.resolve(__dirname, '../Tools/rules-js/core.js')

/** The rules port is CommonJS. Bundle it to ESM so the browser and the production build share one import. */
function rulesEsm(): Plugin {
  const id = '\0rookraid-rules'
  return {
    name: 'rookraid-rules',
    resolveId(source) {
      if (source === 'rookraid-rules') return id
    },
    async load(source) {
      if (source !== id) return
      const result = await build({
        entryPoints: [rulesEntry],
        bundle: true,
        format: 'esm',
        platform: 'browser',
        write: false,
      })
      return result.outputFiles[0].text
    },
  }
}

/** Public legal pages as real files (/privacy/index.html …) so every static host serves them, for App Store Connect. */
function legalPages(): Plugin {
  const pages: Record<string, string> = {
    privacy: 'Privacy Policy · Datenschutz', imprint: 'Legal Notice · Impressum', terms: 'Terms of Use · Nutzungsbedingungen', support: 'Support · Hilfe & Kontakt',
  }
  return {
    name: 'rookraid-legal-pages',
    apply: 'build',
    writeBundle(options) {
      const dir = options.dir ?? path.resolve(__dirname, 'dist')
      const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8')
      for (const [slug, title] of Object.entries(pages)) {
        fs.mkdirSync(path.join(dir, slug), { recursive: true })
        fs.writeFileSync(path.join(dir, slug, 'index.html'), html.replace(/<title>.*?<\/title>/, `<title>${title} · Rook Raid</title>`))
      }
    },
  }
}

export default defineConfig({
  worker: { format: 'es', plugins: () => [rulesEsm()] },
  plugins: [
    rulesEsm(),
    legalPages(),
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon-192.png', 'icon-512.png'],
      manifest: {
        name: 'Rook Raid',
        short_name: 'Rook Raid',
        description: 'Chess with cards – cards, mana and ultimates on a real chessboard.',
        theme_color: '#0C1628',
        background_color: '#070d18',
        display: 'standalone',
        start_url: '/',
        lang: 'en',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,png,svg,jpg,webp,ico,wav}'],
        navigateFallbackDenylist: [/^\/(privacy|imprint|terms|support)/, /^\/\.well-known\//],
        // Push notifications (friend requests): handlers live in public/push-sw.js.
        importScripts: ['push-sw.js'],
        maximumFileSizeToCacheInBytes: 4 * 1024 * 1024,
      },
    }),
  ],
  server: { fs: { allow: ['..'] } },
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules/@supabase')) return 'supabase'
          if (id.includes('node_modules/react')) return 'react'
        },
      },
    },
  },
})
