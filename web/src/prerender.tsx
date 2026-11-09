// Build step 2 (see package.json "build"): renders the public pages to static HTML so search engines and link previews
// see real content without JavaScript. Bundled by `vite build --ssr`, run by scripts/prerender.mjs.
// English only for now: in Node the language detection falls back to English.
import { renderToString } from 'react-dom/server'
import { getLang, loadLanguage } from './i18n'
import { FAQ, HOW_TO_PLAY_DESCRIPTION, HOW_TO_PLAY_TITLE, HowToPlay } from './screens/HowToPlay'
import { LEGAL_PATHS, LegalStandalone, type LegalPage } from './screens/Legal'

export const SITE = 'https://rookraid.com'

export type PublicPage = {
  path: string // with trailing slash: the canonical address (Hostinger redirects /privacy → /privacy/)
  title: string
  description: string
  priority: number
  html: string
  jsonLd: object
}

const LEGAL_DESCRIPTIONS: Record<LegalPage, string> = {
  privacy: 'Privacy policy of Rook Raid, the free chess card game: which data is stored, why, for how long, and your rights.',
  imprint: 'Legal notice (Impressum) of Rook Raid – publisher and contact details.',
  terms: 'Terms of use of Rook Raid, the free chess card game for the browser and iPhone.',
  support: 'Help and contact for Rook Raid: answers to common questions and how to reach the developer.',
}

/** Fuller names for search results than the short in-game titles. */
const LEGAL_SEO_NAMES: Record<LegalPage, string> = {
  privacy: 'Privacy Policy', imprint: 'Legal Notice (Impressum)', terms: 'Terms of Use', support: 'Help & Support',
}

const crumbs = (name: string, path: string) => ({
  '@type': 'BreadcrumbList',
  itemListElement: [
    { '@type': 'ListItem', position: 1, name: 'Rook Raid', item: `${SITE}/` },
    { '@type': 'ListItem', position: 2, name, item: `${SITE}${path}` },
  ],
})

export async function renderPages(): Promise<PublicPage[]> {
  await loadLanguage('en')
  if (getLang() !== 'en') throw new Error(`prerender expects English, got ${getLang()}`)
  const pages: PublicPage[] = [{
    path: '/how-to-play/',
    title: HOW_TO_PLAY_TITLE,
    description: HOW_TO_PLAY_DESCRIPTION,
    priority: 0.9,
    html: renderToString(<HowToPlay />),
    jsonLd: {
      '@context': 'https://schema.org',
      '@graph': [
        { '@type': 'WebPage', '@id': `${SITE}/how-to-play/#page`, url: `${SITE}/how-to-play/`, name: HOW_TO_PLAY_TITLE, description: HOW_TO_PLAY_DESCRIPTION, inLanguage: 'en', isPartOf: { '@id': `${SITE}/#website` }, about: { '@id': `${SITE}/#game` } },
        crumbs('How to play', '/how-to-play/'),
        { '@type': 'FAQPage', mainEntity: FAQ.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })) },
      ],
    },
  }]
  for (const page of Object.keys(LEGAL_PATHS) as LegalPage[]) {
    const name = LEGAL_SEO_NAMES[page]
    pages.push({
      path: LEGAL_PATHS[page],
      title: `${name} · Rook Raid`,
      description: LEGAL_DESCRIPTIONS[page],
      priority: page === 'support' ? 0.5 : 0.3,
      html: renderToString(<LegalStandalone page={page} />),
      jsonLd: {
        '@context': 'https://schema.org',
        '@graph': [
          { '@type': 'WebPage', url: `${SITE}${LEGAL_PATHS[page]}`, name, description: LEGAL_DESCRIPTIONS[page], inLanguage: 'en', isPartOf: { '@id': `${SITE}/#website` } },
          crumbs(name, LEGAL_PATHS[page]),
        ],
      },
    })
  }
  return pages
}
