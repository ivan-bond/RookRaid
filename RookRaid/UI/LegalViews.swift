import SwiftUI

/// Impressum, Datenschutz und Nutzungsbedingungen. Name und Anschrift sind fest;
/// die erklärenden Sätze laufen über `L()`, damit sie mit der Sprache wechseln.
enum LegalPage: String, Identifiable {
    case privacy, imprint, terms
    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return L("Datenschutz")
        case .imprint: return L("Impressum")
        case .terms: return L("Nutzungsbedingungen")
        }
    }
}

enum LegalPublisher {
    static let name = "Ivan Bondarenko"
    static let street = "Frommannstr. 16"
    static let city = "04317 Leipzig"
    static let email = "ivan-bondarenko@web.de"
    static var mailURL: URL { URL(string: "mailto:\(email)")! }
}

struct LegalDocumentView: View {
    let page: LegalPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch page {
                        case .imprint: imprint
                        case .privacy: privacy
                        case .terms: terms
                        }
                        Text(L("Stand: 1. November 2026"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .frame(width: geo.size.width, alignment: .leading)
                    .textSelection(.enabled)
                }
            }
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
        }
        .background(
            ZStack {
                Theme.background.ignoresSafeArea()
                RadialGradient(colors: [Color(hex: 0x6B4FD8).opacity(0.28), .clear], center: .top, startRadius: 10, endRadius: 480)
                    .ignoresSafeArea()
            }
        )
        .preferredColorScheme(.dark)
    }

    private var imprint: some View {
        VStack(alignment: .leading, spacing: 14) {
            card(L("Angaben gemäß § 5 DDG")) {
                identity
            }
            card(L("Kontakt")) {
                Link(destination: LegalPublisher.mailURL) {
                    Text(LegalPublisher.email)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.blueLight)
                }
            }
            card(L("Impressum")) {
                paragraph(L("Dieses Spiel ist ein privates Angebot. Es gibt keine Käufe für echtes Geld."))
            }
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 14) {
            card(L("Verantwortlich")) {
                paragraph(L("Verantwortlich für dieses Spiel ist:"))
                identity
                    .padding(.top, 6)
            }
            card(L("Welche Daten")) {
                paragraph(L("Spielst du nur auf diesem Gerät, bleiben Profil, Fortschritt, Verlauf und die laufende Partie auf dem iPhone. Sie werden nicht an uns gesendet."))
                paragraph(L("Sobald du online spielst, kommen auf dem Server dazu:"))
                bullet(L("eine zufällige Konto-ID; bis du das Konto mit Apple sicherst, ist es als anonym gekennzeichnet"))
                bullet(L("eine Gast-ID, die die App einmal auf diesem Gerät erzeugt"))
                bullet(L("Spielername, Avatar, Rahmen, Titel und Figurenset"))
                bullet(L("Trophäen, Bestwert und die Online-Bilanz (Siege, Niederlagen, Remis)"))
                bullet(L("eine Sicherung des Spielstands, unter anderem Karten, XP, Splitter, Truhen, Puzzles und Flammen"))
                bullet(L("Partien mit Decks, Ultimates, Zügen, Uhr, Ergebnis und der Spielerkarte, die der Gegner sieht"))
                bullet(L("beim Sichern mit Apple die E-Mail-Adresse, die Apple übermittelt, oder eine Weiterleitungsadresse, falls du sie teilst. Die App zeigt sie nicht an und verschickt keine Werbung."))
                paragraph(L("Technische Protokolle des Serverbetriebs können Konto-ID und Zeitpunkt eines Fehlers enthalten."))
            }
            card(L("Zwecke")) {
                paragraph(L("Die Daten braucht das Spiel: Konto, Gegnersuche, Partie, Uhr, Ergebnis und Trophäen. Rechtsgrundlage ist Art. 6 Abs. 1 Buchstabe b DSGVO (Nutzung des Spiels)."))
                paragraph(L("Protokolle und das Löschen ungenutzter anonymer Anmeldungen dienen dem sicheren Betrieb. Rechtsgrundlage ist Art. 6 Abs. 1 Buchstabe f DSGVO."))
                paragraph(L("Es gibt keine Werbung, kein Tracking über andere Apps oder Websites hinweg und keinen Verkauf von Daten."))
            }
            card(L("Empfänger")) {
                paragraph(L("Auftragsverarbeiter ist Supabase, Inc. Das Projekt steht in Frankfurt in der EU. Datenbank und Anmeldung dieses Projekts werden dort betrieben. Protokolle, Sicherungen und der Ablauf der Spielfunktionen können nach dem Auftragsverarbeitungsvertrag von Supabase auch außerhalb dieser Region verarbeitet werden."))
                paragraph(L("Die Anmeldung mit Apple läuft über Apple. Es gilt die Datenschutzerklärung von Apple."))
                paragraph(L("Eine öffentliche Bestenliste gibt es in dieser Fassung nicht. Andere Spieler sehen deinen Namen und deine Spielerkarte in einer gemeinsamen Partie."))
            }
            card(L("Speicherdauer")) {
                paragraph(L("Konto, Trophäen, Bilanz und Sicherung bleiben, bis du das Konto unter Einstellungen löschst. Dabei werden das Konto, der Name im Profil, die Trophäen, die Bilanz und die Sicherung entfernt."))
                paragraph(L("Abgeschlossene Partien bleiben gespeichert, damit das Ergebnis für den Gegner erhalten bleibt. Dein Konto ist danach nicht mehr damit verknüpft. In der Partie bleiben die Züge und die Spielerkarte mit dem Namen, den du dort gezeigt hast."))
                paragraph(L("Eine anonyme Anmeldung, mit der kein Konto eingerichtet wird, wird innerhalb etwa einer Stunde gelöscht."))
                paragraph(L("Der Spielstand auf dem iPhone bleibt beim Löschen des Kontos erhalten. Fortschritt zurücksetzen in den Einstellungen löscht ihn auf diesem Gerät."))
            }
            card(L("Deine Rechte")) {
                paragraph(L("Du hast das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch gegen Verarbeitungen nach Art. 6 Abs. 1 Buchstabe f DSGVO. Schreib dafür an die E-Mail-Adresse im Impressum. Das Konto kannst du in der App selbst löschen."))
                paragraph(L("Du kannst dich bei einer Aufsichtsbehörde beschweren. Für Sachsen ist das die Sächsische Datenschutz- und Transparenzbeauftragte, Maternistraße 17, 01067 Dresden, datenschutz.sachsen.de."))
            }
            card(L("Ohne Online-Konto")) {
                paragraph(L("Einen Spielernamen brauchst du nur zum Online-Spiel. Ohne Konto kannst du weiter auf dem Gerät gegen den Computer spielen."))
            }
        }
    }

    private var terms: some View {
        VStack(alignment: .leading, spacing: 14) {
            card(L("Nutzungsbedingungen")) {
                paragraph(L("Mit der Nutzung von Rook Raid gelten diese Bedingungen."))
                paragraph(L("Rook Raid ist ein kostenloses Schachspiel mit Karten. In dieser Fassung gibt es keine Käufe für echtes Geld."))
                paragraph(L("Gegner können Menschen oder computergesteuert sein. Ein computergesteuerter Gegner muss im Spiel nicht als solcher gekennzeichnet sein."))
                paragraph(L("Online gilt eine Bedenkzeit von 5 Minuten ohne Zeitgutschrift pro Zug. Trophäen, Uhr und Ergebnis einer Online-Partie bestimmt der Server."))
                paragraph(L("Der Spielername hat 2 bis 16 Zeichen und darf nur einmal vergeben sein. Du bist für den Namen verantwortlich, den du wählst."))
                paragraph(L("Du kannst anonym spielen und das Konto später mit Apple sichern. In den Einstellungen kannst du es löschen. Der Spielstand auf dem Gerät bleibt dabei erhalten, bis du ihn dort zurücksetzt."))
                paragraph(L("Züge, Trophäen oder die Verbindung zu manipulieren ist nicht erlaubt. Betroffene Online-Werte dürfen korrigiert und das Konto geschlossen werden."))
                paragraph(L("Für Vorsatz, grobe Fahrlässigkeit und Schäden an Leben, Körper oder Gesundheit ist die Haftung unbeschränkt. Bei leichter Fahrlässigkeit wird nur für die Verletzung wesentlicher Pflichten und nur für den vorhersehbaren Schaden gehaftet. Die Haftung nach dem Produkthaftungsgesetz bleibt unberührt."))
                paragraph(L("Es gilt das Recht der Bundesrepublik Deutschland. Zwingende Verbraucherschutzregeln deines Wohnsitzstaates bleiben unberührt."))
            }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LegalPublisher.name)
            Text(LegalPublisher.street)
            Text(LegalPublisher.city)
            Text(L("Deutschland"))
            Link(destination: LegalPublisher.mailURL) {
                Text(LegalPublisher.email)
                    .foregroundColor(Theme.blueLight)
            }
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(Theme.gold)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
