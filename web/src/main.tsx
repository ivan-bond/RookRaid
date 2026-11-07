import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { registerSW } from 'virtual:pwa-register'
import { App } from './App'
import { loadLanguage } from './i18n'
import { LegalStandalone, legalPageFromPath } from './screens/Legal'
import './styles.css'
import './screens.css'

registerSW({ immediate: true })
const legal = legalPageFromPath(location.pathname)
document.body.classList.toggle('legal-body', !!legal)
void loadLanguage().finally(() => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>{legal ? <LegalStandalone page={legal} /> : <App />}</StrictMode>,
  )
})
