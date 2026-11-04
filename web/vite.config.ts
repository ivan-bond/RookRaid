import { build } from 'esbuild'
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

export default defineConfig({
  plugins: [
    rulesEsm(),
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon-192.png', 'icon-512.png'],
      manifest: {
        name: 'Rook Raid',
        short_name: 'Rook Raid',
        description: 'Chess with cards',
        theme_color: '#0C1628',
        background_color: '#070d18',
        display: 'standalone',
        start_url: '/',
        lang: 'de',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,png,svg,jpg,webp,ico}'],
        maximumFileSizeToCacheInBytes: 4 * 1024 * 1024,
      },
    }),
  ],
  server: { fs: { allow: ['..'] } },
})
