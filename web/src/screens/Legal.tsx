// LegalViews.swift: privacy policy, legal notice and terms (same wording as the app), plus a support page.
// Reachable inside the game (Settings → Legal) and as public pages: /privacy, /imprint, /terms, /support
// – those addresses go into App Store Connect (Privacy Policy URL, Support URL).
import type { ReactNode } from 'react'
import { appLogo } from '../art'
import { useI18n, LANGS, type Lang } from '../i18n'
import { Icon } from '../ui/Icon'

export type LegalPage = 'privacy' | 'imprint' | 'terms' | 'support'
export const LEGAL_PATHS: Record<LegalPage, string> = { privacy: '/privacy', imprint: '/imprint', terms: '/terms', support: '/support' }
export const LEGAL_TITLES: Record<LegalPage, string> = { privacy: 'Datenschutz', imprint: 'Impressum', terms: 'Nutzungsbedingungen', support: 'Hilfe & Kontakt' }

export const PUBLISHER = { name: 'Ivan Bondarenko', street: 'Frommannstr. 16', city: '04317 Leipzig', email: 'ivan-bondarenko@web.de' }

export function legalPageFromPath(path: string): LegalPage | null {
  const clean = path.replace(/\/+$/, '').toLowerCase()
  const map: Record<string, LegalPage> = {
    '/privacy': 'privacy', '/datenschutz': 'privacy', '/privacy-policy': 'privacy',
    '/imprint': 'imprint', '/impressum': 'imprint', '/legal-notice': 'imprint',
    '/terms': 'terms', '/nutzungsbedingungen': 'terms', '/terms-of-use': 'terms',
    '/support': 'support', '/hilfe': 'support', '/help': 'support',
  }
  return map[clean] ?? null
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  return <section className="legal-card"><h3>{title}</h3>{children}</section>
}
function P({ children }: { children: ReactNode }) { return <p className="legal-p">{children}</p> }
function B({ children }: { children: ReactNode }) { return <div className="legal-b"><span>•</span><p>{children}</p></div> }

function Identity() {
  const { t } = useI18n()
  return (
    <address className="legal-id">
      {PUBLISHER.name}<br />{PUBLISHER.street}<br />{PUBLISHER.city}<br />{t('Deutschland')}<br />
      <a href={`mailto:${PUBLISHER.email}`}>{PUBLISHER.email}</a>
    </address>
  )
}

export function LegalContent({ page }: { page: LegalPage }) {
  const { t } = useI18n()
  if (page === 'imprint') return (
    <>
      <Card title={t('Angaben gemäß § 5 DDG')}><Identity /></Card>
      <Card title={t('Kontakt')}><a className="legal-mail" href={`mailto:${PUBLISHER.email}`}>{PUBLISHER.email}</a></Card>
      <Card title={t('Impressum')}><P>{t('Dieses Spiel ist ein privates Angebot. Es gibt keine Käufe für echtes Geld.')}</P></Card>
    </>
  )
  if (page === 'terms') return (
    <Card title={t('Nutzungsbedingungen')}>
      <P>{t('Mit der Nutzung von Rook Raid gelten diese Bedingungen.')}</P>
      <P>{t('Rook Raid ist ein kostenloses Schachspiel mit Karten. In dieser Fassung gibt es keine Käufe für echtes Geld.')}</P>
      <P>{t('Gegner können Menschen oder computergesteuert sein. Ein computergesteuerter Gegner muss im Spiel nicht als solcher gekennzeichnet sein.')}</P>
      <P>{t('Online gilt eine Bedenkzeit von 5 Minuten ohne Zeitgutschrift pro Zug. Trophäen, Uhr und Ergebnis einer Online-Partie bestimmt der Server.')}</P>
      <P>{t('Der Spielername hat 2 bis 16 Zeichen und darf nur einmal vergeben sein. Du bist für den Namen verantwortlich, den du wählst.')}</P>
      <P>{t('Du kannst anonym spielen und das Konto später mit Apple sichern. In den Einstellungen kannst du es löschen. Der Spielstand auf dem Gerät bleibt dabei erhalten, bis du ihn dort zurücksetzt.')}</P>
      <P>{t('Züge, Trophäen oder die Verbindung zu manipulieren ist nicht erlaubt. Betroffene Online-Werte dürfen korrigiert und das Konto geschlossen werden.')}</P>
      <P>{t('Für Vorsatz, grobe Fahrlässigkeit und Schäden an Leben, Körper oder Gesundheit ist die Haftung unbeschränkt. Bei leichter Fahrlässigkeit wird nur für die Verletzung wesentlicher Pflichten und nur für den vorhersehbaren Schaden gehaftet. Die Haftung nach dem Produkthaftungsgesetz bleibt unberührt.')}</P>
      <P>{t('Es gilt das Recht der Bundesrepublik Deutschland. Zwingende Verbraucherschutzregeln deines Wohnsitzstaates bleiben unberührt.')}</P>
    </Card>
  )
  if (page === 'support') return (
    <>
      <Card title={t('Kontakt')}>
        <P>{t('Fragen, Fehler oder Wünsche zu Rook Raid? Schreib uns – wir antworten in der Regel innerhalb weniger Tage.')}</P>
        <a className="legal-mail" href={`mailto:${PUBLISHER.email}?subject=Rook%20Raid%20Support`}>{PUBLISHER.email}</a>
      </Card>
      <Card title={t('Häufige Fragen')}>
        <div className="faq"><b>{t('Wie lösche ich mein Online-Konto?')}</b><P>{t('In der App unter Profil → Einstellungen → Konto → Konto löschen. Spielername, Trophäen, Online-Bilanz und die Sicherung werden vom Server entfernt.')}</P></div>
        <div className="faq"><b>{t('Wie hole ich meinen Spielstand auf ein neues Gerät?')}</b><P>{t('Sichere dein Konto mit Apple. Auf dem neuen Gerät meldest du dich mit Apple an und lädst den gesicherten Spielstand.')}</P></div>
        <div className="faq"><b>{t('Kostet Rook Raid etwas?')}</b><P>{t('Nein. Rook Raid ist kostenlos, ohne Werbung und ohne Käufe für echtes Geld.')}</P></div>
        <div className="faq"><b>{t('Wo finde ich die Regeln?')}</b><P>{t('Im Spiel unter Profil → Einstellungen → Regeln & Karten erklärt, oder im Menü einer laufenden Partie.')}</P></div>
        <div className="faq"><b>{t('Ich habe einen Fehler gefunden.')}</b><P>{t('Schreib uns bitte, was passiert ist, auf welchem Gerät und mit welcher Version. Ein Bildschirmfoto hilft sehr.')}</P></div>
      </Card>
    </>
  )
  return (
    <>
      <Card title={t('Verantwortlich')}><P>{t('Verantwortlich für dieses Spiel ist:')}</P><Identity /></Card>
      <Card title={t('Welche Daten')}>
        <P>{t('Spielst du nur auf diesem Gerät, bleiben Profil, Fortschritt, Verlauf und die laufende Partie auf dem iPhone. Sie werden nicht an uns gesendet.')}</P>
        <P>{t('Sobald du online spielst, kommen auf dem Server dazu:')}</P>
        <B>{t('eine zufällige Konto-ID; bis du das Konto mit Apple sicherst, ist es als anonym gekennzeichnet')}</B>
        <B>{t('eine Gast-ID, die die App einmal auf diesem Gerät erzeugt')}</B>
        <B>{t('Spielername, Avatar, Rahmen, Titel und Figurenset')}</B>
        <B>{t('Trophäen, Bestwert und die Online-Bilanz (Siege, Niederlagen, Remis)')}</B>
        <B>{t('eine Sicherung des Spielstands, unter anderem Karten, XP, Splitter, Truhen, Puzzles und Flammen')}</B>
        <B>{t('Partien mit Decks, Ultimates, Zügen, Uhr, Ergebnis und der Spielerkarte, die der Gegner sieht')}</B>
        <B>{t('beim Sichern mit Apple die E-Mail-Adresse, die Apple übermittelt, oder eine Weiterleitungsadresse, falls du sie teilst. Die App zeigt sie nicht an und verschickt keine Werbung.')}</B>
        <B>{t('ein Freundescode, über den dich andere finden können')}</B>
        <B>{t('Freundschaften und Freundschaftsanfragen, Spieler, die du blockierst, und Meldungen, die du abschickst oder die über dich eingehen')}</B>
        <B>{t('wenn du Mitteilungen erlaubst: eine Push-Adresse deines Geräts oder Browsers und deine Spielsprache, damit die Mitteilung in deiner Sprache ankommt')}</B>
        <P>{t('Technische Protokolle des Serverbetriebs können Konto-ID und Zeitpunkt eines Fehlers enthalten.')}</P>
      </Card>
      <Card title={t('Browser-Fassung')}>
        <P>{t('In der Browser-Fassung liegt der Spielstand im lokalen Speicher deines Browsers (Local Storage). Er wird nicht an uns gesendet, solange du nicht online spielst. Es gibt keine Cookies für Werbung oder Analyse.')}</P>
        <P>{t('Cookies: Die Seite setzt zwei technisch notwendige Cookies. „rr_visited“ merkt sich, dass du Rook Raid schon einmal geöffnet hast (dann startet nicht wieder die erste Schlacht), „rr_auth“ merkt sich, ob du als Gast, anonym oder mit Apple angemeldet bist. Beide bleiben ein Jahr, enthalten keine Kennungen und dienen nicht der Werbung oder Analyse. Rechtsgrundlage ist § 25 Abs. 2 Nr. 2 TDDDG.')}</P>
        <P>{t('Die Seite liegt bei Hostinger International Ltd., 61 Lordou Vironos Street, 6023 Larnaca, Zypern, als Auftragsverarbeiter. Beim Aufruf der Seite verarbeitet Hostinger technisch notwendige Verbindungsdaten wie IP-Adresse, Zeitpunkt und abgerufene Datei, um die Seite auszuliefern und vor Missbrauch zu schützen. Rechtsgrundlage ist Art. 6 Abs. 1 Buchstabe f DSGVO.')}</P>
      </Card>
      <Card title={t('Zwecke')}>
        <P>{t('Die Daten braucht das Spiel: Konto, Gegnersuche, Partie, Uhr, Ergebnis und Trophäen. Rechtsgrundlage ist Art. 6 Abs. 1 Buchstabe b DSGVO (Nutzung des Spiels).')}</P>
        <P>{t('Protokolle und das Löschen ungenutzter anonymer Anmeldungen dienen dem sicheren Betrieb. Rechtsgrundlage ist Art. 6 Abs. 1 Buchstabe f DSGVO.')}</P>
        <P>{t('Freundesliste, Suche, Anfragen und Mitteilungen gehören zum Spiel (Art. 6 Abs. 1 Buchstabe b DSGVO). Blockieren und Meldungen schützen die Spieler und ein faires Spiel (Art. 6 Abs. 1 Buchstabe f DSGVO).')}</P>
        <P>{t('Es gibt keine Werbung, kein Tracking über andere Apps oder Websites hinweg und keinen Verkauf von Daten.')}</P>
      </Card>
      <Card title={t('Empfänger')}>
        <P>{t('Auftragsverarbeiter ist Supabase, Inc. Das Projekt steht in Frankfurt in der EU. Datenbank und Anmeldung dieses Projekts werden dort betrieben. Protokolle, Sicherungen und der Ablauf der Spielfunktionen können nach dem Auftragsverarbeitungsvertrag von Supabase auch außerhalb dieser Region verarbeitet werden.')}</P>
        <P>{t('Die Anmeldung mit Apple läuft über Apple. Es gilt die Datenschutzerklärung von Apple.')}</P>
        <P>{t('Mitteilungen stellt auf dem iPhone Apple zu (Apple Push Notification Service), im Browser der Push-Dienst des Browser-Herstellers, etwa Apple, Google oder Mozilla. Dabei werden die Push-Adresse und der Text der Mitteilung mit dem Namen des anderen Spielers übermittelt.')}</P>
        <P>{t('Eine öffentliche Bestenliste gibt es nicht. Andere Spieler sehen deinen Namen und deine Spielerkarte in einer gemeinsamen Partie.')}</P>
        <P>{t('Wer deinen genauen Spielernamen oder Freundescode eingibt, findet dich und sieht Name, Avatar, Rahmen, Titel, Level und Trophäen. Freunde und Spieler mit einer offenen Anfrage sehen außerdem Bestwert, Online-Bilanz, weltweiten Rang, die Zahl deiner Freunde und eure Partien gegeneinander. Wen du blockierst, findet dich nicht mehr.')}</P>
      </Card>
      <Card title={t('Speicherdauer')}>
        <P>{t('Konto, Trophäen, Bilanz und Sicherung bleiben, bis du das Konto unter Einstellungen löschst. Dabei werden das Konto, der Name im Profil, die Trophäen, die Bilanz und die Sicherung entfernt.')}</P>
        <P>{t('Abgeschlossene Partien bleiben gespeichert, damit das Ergebnis für den Gegner erhalten bleibt. Dein Konto ist danach nicht mehr damit verknüpft. In der Partie bleiben die Züge und die Spielerkarte mit dem Namen, den du dort gezeigt hast.')}</P>
        <P>{t('Eine anonyme Anmeldung, mit der kein Konto eingerichtet wird, wird innerhalb etwa einer Stunde gelöscht.')}</P>
        <P>{t('Freundschaften, Anfragen, Blockierungen und Push-Adressen werden mit dem Konto gelöscht. Offene und abgelehnte Anfragen verschwinden nach 30 Tagen, nicht zugestellte Mitteilungen nach 2 Tagen, Meldungen spätestens nach einem Jahr. Beim Abmelden entfernt das Gerät seine Push-Adresse.')}</P>
        <P>{t('Der Spielstand auf dem iPhone bleibt beim Löschen des Kontos erhalten. Fortschritt zurücksetzen in den Einstellungen löscht ihn auf diesem Gerät.')}</P>
      </Card>
      <Card title={t('Deine Rechte')}>
        <P>{t('Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch gegen Verarbeitungen nach Art. 6 Abs. 1 Buchstabe f DSGVO. Schreib dafür an die E-Mail-Adresse im Impressum. Das Konto kannst du in der App selbst löschen.')}</P>
        <P>{t('Du kannst dich bei einer Aufsichtsbehörde beschweren. Für Sachsen ist das die Sächsische Datenschutz- und Transparenzbeauftragte, Maternistraße 17, 01067 Dresden, datenschutz.sachsen.de.')}</P>
      </Card>
      <Card title={t('Ohne Online-Konto')}><P>{t('Einen Spielernamen brauchst du nur zum Online-Spiel. Ohne Konto kannst du weiter auf dem Gerät gegen den Computer spielen.')}</P></Card>
    </>
  )
}

export function LegalBody({ page }: { page: LegalPage }) {
  const { t } = useI18n()
  return (
    <div className="legal">
      <LegalContent page={page} />
      <span className="legal-date">{t('Stand: 7. November 2026')}</span>
    </div>
  )
}

/** Public page without the game around it (what App Review and visitors see). */
export function LegalStandalone({ page }: { page: LegalPage }) {
  const { t, lang, setLang } = useI18n()
  document.title = `${t(LEGAL_TITLES[page])} · Rook Raid`
  return (
    <div className="legal-site">
      <header className="legal-top">
        <a href="/" className="legal-brand"><img src={appLogo} alt="" /><b>Rook Raid</b></a>
        <nav className="legal-nav">
          {(Object.keys(LEGAL_PATHS) as LegalPage[]).map(p => (
            <a key={p} href={LEGAL_PATHS[p]} className={p === page ? 'on' : ''}>{t(LEGAL_TITLES[p])}</a>
          ))}
        </nav>
        <label className="legal-lang"><Icon name="globe" size={14} />
          <select className="select" value={lang} onChange={e => setLang(e.target.value as Lang)}>{LANGS.map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select>
        </label>
      </header>
      <main className="legal-main">
        <h1 className="title-xl">{t(LEGAL_TITLES[page])}</h1>
        <LegalBody page={page} />
        <a className="chunky gold" href="/" style={{ textDecoration: 'none', marginTop: 24 }}><Icon name="bolt" size={18} />{t('Rook Raid im Browser spielen')}</a>
      </main>
      <footer className="legal-foot">© 2026 {PUBLISHER.name} · <a href={`mailto:${PUBLISHER.email}`}>{PUBLISHER.email}</a></footer>
    </div>
  )
}
