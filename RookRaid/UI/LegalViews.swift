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
    static let email = "rookraidchess@gmail.com"
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
                        Text(L("Stand: 9. November 2026"))
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
                bullet(L("eine zufällige Konto-ID; bis du das Konto mit Apple oder Google sicherst, ist es als anonym gekennzeichnet"))
                bullet(L("eine Gast-ID, die die App einmal auf diesem Gerät erzeugt"))
                bullet(L("Spielername, Avatar, Rahmen, Titel und Figurenset"))
                bullet(L("Trophäen, Bestwert und die Online-Bilanz (Siege, Niederlagen, Remis)"))
                bullet(L("eine Sicherung des Spielstands, unter anderem Karten, XP, Splitter, Truhen, Puzzles und Flammen"))
                bullet(L("Partien mit Decks, Ultimates, Zügen, Uhr, Ergebnis und der Spielerkarte, die der Gegner sieht"))
                bullet(L("beim Sichern mit Apple oder Google die E-Mail-Adresse, die der Anbieter übermittelt (bei Apple auf Wunsch eine Weiterleitungsadresse). Google übermittelt außerdem deinen Namen und die Adresse deines Profilbilds; sie werden beim Konto gespeichert, aber nicht angezeigt. Die App verschickt keine Werbung."))
                bullet(L("ein Freundescode, über den dich andere finden können"))
                bullet(L("Freundschaften und Freundschaftsanfragen, Spieler, die du blockierst, und Meldungen, die du abschickst oder die über dich eingehen"))
                bullet(L("wenn du Mitteilungen erlaubst: eine Push-Adresse deines Geräts oder Browsers und deine Spielsprache, damit die Mitteilung in deiner Sprache ankommt"))
                bullet(L("wann du zuletzt in der App warst und ob Freunde deinen Online-Status sehen dürfen, außerdem Einladungen zu Freundschaftsspielen"))
                paragraph(L("Technische Protokolle des Serverbetriebs können Konto-ID und Zeitpunkt eines Fehlers enthalten."))
            }
            card(L("Zwecke")) {
                paragraph(L("Die Daten braucht das Spiel: Konto, Gegnersuche, Partie, Uhr, Ergebnis und Trophäen. Rechtsgrundlage ist Art. 6 Abs. 1 Buchstabe b DSGVO (Nutzung des Spiels)."))
                paragraph(L("Protokolle und das Löschen ungenutzter anonymer Anmeldungen dienen dem sicheren Betrieb. Rechtsgrundlage ist Art. 6 Abs. 1 Buchstabe f DSGVO."))
                paragraph(L("Freundesliste, Suche, Anfragen und Mitteilungen gehören zum Spiel (Art. 6 Abs. 1 Buchstabe b DSGVO). Blockieren und Meldungen schützen die Spieler und ein faires Spiel (Art. 6 Abs. 1 Buchstabe f DSGVO)."))
                paragraph(L("Es gibt keine Werbung, kein Tracking über andere Apps oder Websites hinweg und keinen Verkauf von Daten."))
            }
            card(L("Empfänger")) {
                paragraph(L("Auftragsverarbeiter ist Supabase, Inc. Das Projekt steht in Frankfurt in der EU. Datenbank und Anmeldung dieses Projekts werden dort betrieben. Protokolle, Sicherungen und der Ablauf der Spielfunktionen können nach dem Auftragsverarbeitungsvertrag von Supabase auch außerhalb dieser Region verarbeitet werden."))
                paragraph(L("Die Anmeldung mit Apple läuft über Apple, die Anmeldung mit Google über Google. Es gelten die Datenschutzerklärungen von Apple und Google."))
                paragraph(L("Mitteilungen stellt auf dem iPhone Apple zu (Apple Push Notification Service), im Browser der Push-Dienst des Browser-Herstellers, etwa Apple, Google oder Mozilla. Dabei werden die Push-Adresse und der Text der Mitteilung mit dem Namen des anderen Spielers übermittelt."))
                paragraph(L("Eine öffentliche Bestenliste gibt es nicht. Andere Spieler sehen deinen Namen und deine Spielerkarte in einer gemeinsamen Partie."))
                paragraph(L("Wer deinen genauen Spielernamen oder Freundescode eingibt, findet dich und sieht Name, Avatar, Rahmen, Titel, Level und Trophäen. Freunde und Spieler mit einer offenen Anfrage sehen außerdem Bestwert, Online-Bilanz, weltweiten Rang, die Zahl deiner Freunde und eure Partien gegeneinander. Wen du blockierst, findet dich nicht mehr."))
                paragraph(L("Freunde sehen, ob du gerade online bist (in den letzten 2 Minuten in Rook Raid), solange du den Online-Status in der Freundesliste nicht ausschaltest. Freundschaftsspiele bringen keine Trophäen, zählen aber für eure Partien gegeneinander."))
                paragraph(L("Manche Gegner und Spieler sind Bot-Spieler. Sie sind mit „Bot“ gekennzeichnet, hinter ihnen steht kein Mensch, und deine Anfragen und Partien mit ihnen bleiben auf unserem Server."))
            }
            card(L("Speicherdauer")) {
                paragraph(L("Konto, Trophäen, Bilanz und Sicherung bleiben, bis du das Konto unter Einstellungen löschst. Dabei werden das Konto, der Name im Profil, die Trophäen, die Bilanz und die Sicherung entfernt."))
                paragraph(L("Abgeschlossene Partien bleiben gespeichert, damit das Ergebnis für den Gegner erhalten bleibt. Dein Konto ist danach nicht mehr damit verknüpft. In der Partie bleiben die Züge und die Spielerkarte mit dem Namen, den du dort gezeigt hast."))
                paragraph(L("Eine anonyme Anmeldung, mit der kein Konto eingerichtet wird, wird innerhalb etwa einer Stunde gelöscht."))
                paragraph(L("Freundschaften, Anfragen, Blockierungen und Push-Adressen werden mit dem Konto gelöscht. Offene und abgelehnte Anfragen verschwinden nach 30 Tagen, nicht zugestellte Mitteilungen nach 2 Tagen, Meldungen spätestens nach einem Jahr. Beim Abmelden entfernt das Gerät seine Push-Adresse."))
                paragraph(L("Der Zeitpunkt deines letzten Besuchs wird bei jedem Besuch überschrieben und mit dem Konto gelöscht. Einladungen zu Freundschaftsspielen werden nach einem Tag gelöscht."))
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
                paragraph(L("Du kannst anonym spielen und das Konto später mit Apple oder Google sichern. In den Einstellungen kannst du es löschen. Der Spielstand auf dem Gerät bleibt dabei erhalten, bis du ihn dort zurücksetzt."))
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
