import { build } from 'esbuild'
import fs from 'node:fs'
import path from 'node:path'
import { defineConfig, loadEnv, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'
import { imagetools } from 'vite-imagetools'

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

/** Smart App Banner on iPhone Safari once the app is in the App Store: set VITE_APP_STORE_ID (numeric id) in .env.local. */
function appStoreBanner(id: string | undefined): Plugin {
  return {
    name: 'rookraid-app-store-banner',
    transformIndexHtml(html) {
      return id ? html.replace('</head>', `    <meta name="apple-itunes-app" content="app-id=${id}" />\n  </head>`) : html
    },
  }
}

// The second build (`vite build --ssr src/prerender.tsx`) only renders the public pages to HTML in Node
// (scripts/prerender.mjs), so it skips the service worker and the HTML plugins.
export default defineConfig(({ isSsrBuild, mode }) => ({
  worker: { format: 'es' as const, plugins: () => [rulesEsm()] },
  plugins: isSsrBuild ? [rulesEsm(), imagetools(), react()] : [
    rulesEsm(),
    imagetools(),
    appStoreBanner(loadEnv(mode, __dirname, 'VITE_').VITE_APP_STORE_ID),
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
        navigateFallbackDenylist: [/^\/(privacy|imprint|terms|support|how-to-play)/, /^\/(robots\.txt|sitemap\.xml)$/, /^\/\.well-known\//],
        // Push notifications (friend requests): handlers live in public/push-sw.js.
        importScripts: ['push-sw.js'],
        maximumFileSizeToCacheInBytes: 4 * 1024 * 1024,
      },
    }),
  ],
  server: { fs: { allow: ['..'] } },
  build: isSsrBuild ? {} : {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules/@supabase')) return 'supabase'
          if (id.includes('node_modules/react')) return 'react'
        },
      },
    },
  },
}))
