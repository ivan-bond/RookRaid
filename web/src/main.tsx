import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { registerSW } from 'virtual:pwa-register'
import { loadLanguage } from './i18n'
import { legalPageFromPath } from './screens/Legal'
import './styles.css'
import './screens.css'

registerSW({ immediate: true })
// Public pages (also prerendered as static HTML at build time): legal pages and „How to play“ (English only for now).
const legal = legalPageFromPath(location.pathname)
const howToPlay = /^\/how-to-play\/?$/i.test(location.pathname)
document.body.classList.toggle('legal-body', !!legal || howToPlay)
// Each kind of page loads only its own code: the public pages don't download the game.
async function view() {
  if (howToPlay) { const { HowToPlay } = await import('./screens/HowToPlay'); return <HowToPlay /> }
  if (legal) { const { LegalStandalone } = await import('./screens/Legal'); return <LegalStandalone page={legal} /> }
  const { App } = await import('./App'); return <App />
}
void Promise.all([loadLanguage(), howToPlay ? loadLanguage('en') : null, view()]).then(([, , page]) => {
  createRoot(document.getElementById('root')!).render(<StrictMode>{page}</StrictMode>)
  // The loading sign in index.html only appears after half a second; once the page is there it goes away at once.
  document.getElementById('boot')?.remove()
})
