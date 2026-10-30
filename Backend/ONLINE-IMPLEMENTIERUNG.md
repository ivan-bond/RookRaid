# Rook Raid – Online-Implementierung (Supabase)

**Stand:** App v0.9.36, Regel-Version 3, 28.10.2026 – alle Entscheidungen getroffen (Abschnitt 1)
**Ziel:** Spieler-Konto, schnelle weltweite Gegnersuche gegen echte Menschen, Bot-Ersatz nach 10 Sekunden, Trophäen auf dem Server (Bestenliste in Phase 2) – ohne dass jemand Züge oder Trophäen fälschen kann.

Diese Datei ist die vollständige Arbeitsanleitung. Abschnitt 1 hält die getroffenen Entscheidungen fest, Abschnitt 2 zeigt, was schon gebaut und getestet ist.

---

## Inhalt

1. Entscheidungen
2. Was schon fertig ist
3. Architektur in einem Bild
4. Schritt 1 – Supabase-Projekt anlegen
5. Schritt 2 – Datenbank einspielen
6. Schritt 3 – Anmeldung einrichten (anonym + Sign in with Apple)
7. Schritt 4 – Edge Functions bündeln und deployen
8. Schritt 5 – Wartungsjob
9. Schritt 6 – App: Supabase einbinden
10. Schritt 7 – App: Konto
11. Schritt 8 – App: Gegnersuche und Bot-Ersatz
12. Schritt 9 – App: Online-Partie
13. Schritt 10 – App: Wiederverbinden, Regel-Updates, Bestenliste
14. Protokoll-Referenz
15. Sicherheit und Anti-Cheat
16. Recht und App Store
17. Testplan
18. Betrieb, Regeländerungen, Kosten
19. Phase 2 (bewusst noch nicht enthalten)
20. Datei-Übersicht

---

## 1. Entscheidungen (getroffen am 28.10.2026)

Alle zwölf Fragen sind beantwortet; Datenbank, Tests und App-Schnittstellen setzen genau diese Antworten um.

| # | Frage | Entscheidung | Umsetzung |
|---|---|---|---|
| E1 | Zählen Bot-Ersatz-Partien für Trophäen? | **Ja, wie echte Partien.** Der Bot-Ersatz bleibt unerkennbar. | `finish_match` bucht für den Menschen wie gegen Menschen (+30 / +5 / −20). |
| E2 | Was führt der Server in Phase 1? | **Nur Trophäen, Bestwert und Online-Bilanz.** Karten, XP, Splitter, Truhen, Puzzles und Flammen bleiben auf dem Gerät; der Server sichert sie nur (`progress.snapshot`). | Tabelle `progress`, `backup_progress()`. |
| E3 | Zeitkontrollen online | **Genau eine: 5 \| 0** (5 Minuten, kein Inkrement). Die Uhr-Einstellung der App gilt nur offline. | App: neue Zeitkontrolle `TimeControl.blitz5`, `OnlineConfig.timeControl`; Server: `tc_base_ms('blitz5')` = 300 000, Inkrement 0, andere werden mit `bad_time_control` abgelehnt. |
| E4 | Gast-Trophäen beim ersten Anmelden | **Übernehmen, gedeckelt auf 1 500.** | `setup_account()`. |
| E5 | Bestenliste | **Erst in Phase 2.** | Server-Funktionen `get_leaderboard()`/`my_rank()` existieren schon (fürs Dashboard), in der App kommt noch keine Liste. |
| E6 | Partie verlassen / Verbindung weg | **Nach 45 s ohne Verbindung ist die Partie verloren** – gegen Menschen und gegen den Bot-Ersatz. Sind beide 45 s weg (z. B. Störung), wird ohne Wertung abgebrochen. Ohne ersten Zug innerhalb von 30 s: Abbruch ohne Wertung. | App: alle 10 s `match_heartbeat()`; Server: Tabelle `match_presence`, `claim_timeout()` und Wartungsjob werten (`result = abandoned`). |
| E7 | Remis-Angebot online | **Ja**, ab dem ersten Zugpaar; ein Zug des Gegners lehnt es automatisch ab. | `offer_draw()`, `answer_draw()`. |
| E8 | Spielernamen | **2–16 Zeichen, eindeutig** (Groß-/Kleinschreibung egal: „Ivan“ = „ivan“). Erlaubt: Buchstaben (auch ä, é …), Ziffern, Leerzeichen, `_ . -`, kein Leerzeichen am Rand. | Eindeutiger Index, `valid_name()`, `name_available()`, `set_display_name()`; `setup_account()` lehnt vergebene Namen mit `name_taken` ab. |
| E9 + E11 | Anmeldung | **Anonym sofort online spielen, später mit Apple sichern.** Kein Pflicht-Login vor dem ersten Kampf; nach einigen Partien bittet die App, das Konto mit Apple zu sichern. | Supabase Anonymous Sign-Ins + Sign in with Apple (Schritt 3), `AccountService.signInAnonymously()`. |
| E10 | Server-Region | **EU (Frankfurt).** | Projekt-Einstellung (Schritt 1). |
| E12 | Gegnersuche | **±100 Trophäen, alle 2 s +50, höchstens ±400; Bot nach 10 s.** | `find_match()`, `OnlineConfig.matchmakingTimeout`. |

---

## 2. Was schon fertig ist

**In der App (getestet nur über Regeltests, noch ohne Server):**
- `RookRaid/Engine/rookraid-rules.json` – alle Regelwerte, Regel-Version 3. `RulesConfig.adopt()` übernimmt neuere Server-Fassungen.
- Draht-Format für Aktionen (`GameState.validate/apply`, `ReplayAction.wire`) und Partieprotokoll `MatchRecord` (Decks, Ultimates, Aktionen; `replay()`); `GameViewModel.matchRecord` liefert es für jede laufende Partie.
- `Services/Online.swift`: `OnlineConfig` (Supabase-Schlüssel aus der Info.plist, Endpunkt-Namen, Online-Zeitkontrolle 5|0, Heartbeat 10 s, Schonfrist 45 s), `DeviceIdentity` (Gast-ID), `PlayerCard`, `ProgressSnapshot`, `MatchService` + `LocalMatchService`, `BotCards`, **neu:** `AccountService`, `ServerProgress`, `OnlineMatchSession`, `OnlineMatchInfo`, `OnlineMatchEvent`, `OnlineMatchError`, `BotMatchReporter`.
- Bots fühlen sich menschlich an: im Kampf 0–7 s zufällige Denkpause (`GameViewModel.humanLikePause`).
- Regeltests in der App (Debug-Build → Einstellungen → Entwickler → Regeltests): **53 Fälle**, darunter 4 ganze Partien aus der Grundstellung – genau so spielt der Server nach.

**Server (`Backend/supabase`, lokal getestet, noch nicht eingespielt):**
- `migrations/20261028000001_online_init.sql` – Tabellen, Zugriffsregeln, alle Server-Funktionen (Konto mit eindeutigen Namen, Gegnersuche, Bot-Ersatz, Uhr 5|0, Lebenszeichen, Remis, Aufgeben, Zeitablauf, Verbindungsabbruch, Wartung, Bestenliste für später).
- `migrations/20261028000002_online_cron.sql` – Wartungsjob alle 30 s.
- `seed/rules.sql` – Regel-Version 3 (erzeugt aus der App-Datei).
- Edge Functions: `submit-action` (Zug prüfen und speichern), `finish-bot-match` (Bot-Partie nachprüfen und werten), `delete-account`; gemeinsamer Code in `_shared/common.ts`; Regeln in `_shared/rookraid-rules.mjs` (**generiert**).
- Typprüfung der Functions mit Deno bestanden.

**Regel-Port (`Tools/rules-js`):**
- `core.js` (ohne Dateizugriff, für den Server), `rules.js` (Node-Hülle), `engine.js` (Regeln).
- `node make-golden.js` / `node check-golden.js` – 53/53.
- `node build-server.js` – bündelt den Kern für Deno; `node check-server.mjs` – prüft das Bündel (53/53 + Partie bis zum Matt).
- `node seed-rules.js` – erzeugt `Backend/supabase/seed/rules.sql`.

**Backend-Tests (`Backend/tests`):** 50 Prüfungen der Datenbank-Funktionen und ein kompletter Partie-Ablauf (Regel-Bündel + Datenbank) gegen ein lokales Postgres 17 – alle bestanden.

---

## 3. Architektur in einem Bild

```
  iPhone A                                   Supabase (EU)                                  iPhone B
 ┌──────────────┐  RPC find_match (alle 2 s) ┌───────────────────────────┐  RPC find_match ┌──────────────┐
 │ SupabaseMatch │ ─────────────────────────▶ │ matchmaking_queue         │ ◀────────────── │ SupabaseMatch │
 │ Service       │ ◀──── match_id ─────────── │  → create_match → matches │ ──── match_id ─▶│ Service       │
 └──────┬───────┘                             │                           │                 └──────┬───────┘
        │ eigener Zug (optimistisch lokal)    │  Edge Function            │                        │
        │ POST submit-action {ply, code} ───▶ │  submit-action:           │                        │
        │                                     │   Partie nachspielen      │                        │
        │                                     │   (rookraid-rules.mjs)    │                        │
        │                                     │   → record_action (Uhr,   │                        │
        │                                     │     Ende, Trophäen)       │  Realtime INSERT        │
        │ ◀──────── Realtime: match_actions / matches (Uhr, Remis, Ende) ─┴──────────────────────▶ │
        │                                                                                         │
   kein Mensch nach 10 s: RPC start_bot_match → Partie mit is_bot, Bot rechnet LOKAL;
   am Ende POST finish-bot-match {actions, outcome} → Server spielt nach und wertet.
   in jeder Partie: alle 10 s RPC match_heartbeat – 45 s still = verloren (E6).
```

Grundsätze:
- **Der Server ist maßgeblich** für Züge, Uhr, Partieende und Trophäen. Die App zeigt optimistisch an und gleicht ab.
- **Dieselben Regeln überall:** Swift-Engine (App) und JS-Port (Server) werden mit denselben 53 Fällen geprüft.
- **Nichts Wertvolles schreibt die App direkt:** Tabellen sind für die App nur lesbar; geschrieben wird über Funktionen (`security definer`) bzw. mit der Service-Rolle in Edge Functions.

---

## 4. Schritt 1 – Supabase-Projekt anlegen

1. [supabase.com](https://supabase.com) → **New project**, Region **Central EU (Frankfurt)**, starkes Datenbank-Passwort (in den Passwort-Manager).
2. Notieren (Dashboard → Project Settings → API): **Project URL**, **anon public key**, **Project ref**. Der **service_role key** bleibt geheim und gehört nie in die App.
3. Supabase-Kommandozeile installieren und verbinden:
   ```bash
   brew install supabase/tap/supabase      # macOS
   cd RookRaid/Backend
   supabase init                           # legt supabase/config.toml an; vorhandene Ordner bleiben
   supabase login
   supabase link --project-ref <PROJECT_REF>
   ```
4. Für die Entwicklung lohnt sich die lokale Umgebung (Docker nötig): `supabase start` startet Datenbank, Auth, Realtime und Functions auf dem Mac; `supabase status` zeigt URL und Schlüssel.

---

## 5. Schritt 2 – Datenbank einspielen

```bash
cd RookRaid
node Tools/rules-js/seed-rules.js               # erzeugt Backend/supabase/seed/rules.sql (Regel-Version 3)
cd Backend
supabase db push                                # spielt migrations/ ein (Init + Cron)
```
Dann `supabase/seed/rules.sql` im Dashboard → **SQL Editor** ausführen (oder `psql "<DB-URL>" -f supabase/seed/rules.sql`).

Prüfen im SQL Editor:
```sql
select version, active from rules_config;          -- 3 | true
select * from active_rules();
select jobname, schedule from cron.job;            -- rookraid-maintain | 30 seconds
```

Wichtig zu wissen:
- Die Migration ist wiederholbar (`if not exists`, Policies werden neu gesetzt).
- Die alte Datei `schema.sql` (Entwurf v0.9.26) ist ersetzt und gelöscht.
- Tabellen: `rules_config`, `profiles`, `progress`, `matchmaking_queue`, `matches`, `match_actions`. Details und alle Funktionen: Abschnitt 14.

---

## 6. Schritt 3 – Anmeldung einrichten

### 6.1 Anonyme Anmeldung (E11)
Dashboard → **Authentication → Sign In / Providers → Allow anonymous sign-ins** einschalten. Unter **Rate Limits** die Anzahl anonymer Anmeldungen pro IP begrenzen (z. B. 30 pro Stunde); optional Captcha (Cloudflare Turnstile) – bei einer nativen App meist nicht nötig.

### 6.2 Sign in with Apple
1. **Apple Developer → Identifiers →** App-ID der App → Capability **Sign in with Apple** aktivieren.
2. **Xcode → Target → Signing & Capabilities → + Capability → Sign in with Apple.**
3. **Supabase → Authentication → Providers → Apple** einschalten und unter **Client IDs** die **Bundle ID** der App eintragen. Für die native Anmeldung (Identity-Token) reicht das; Services-ID und Secret-Key braucht man erst für eine Web-Anmeldung (Browser-Version).
4. Ablauf in der App: zufälligen `nonce` erzeugen → SHA-256-Hash als `request.nonce` an Apple → aus der Antwort `identityToken` lesen → mit dem **ungehashten** `nonce` an Supabase (`signInWithIdToken`).
5. Anonymes Konto später mit Apple verknüpfen (E11): Supabase unterstützt „Identity Linking“; **in der aktuellen supabase-swift-Fassung prüfen**, ob das Verknüpfen per Identity-Token (`linkIdentityWithIdToken` o. ä.) angeboten wird. Falls nicht: Apple-Anmeldung durchführen und den Fortschritt per `setup_account` mit dem aktuellen `ProgressSnapshot` übernehmen (Trophäen gedeckelt), danach das anonyme Konto löschen. Die Server-Seite funktioniert für beide Wege.

---

## 7. Schritt 4 – Edge Functions bündeln und deployen

```bash
cd RookRaid
node Tools/rules-js/build-server.js     # → Backend/supabase/functions/_shared/rookraid-rules.mjs
node Tools/rules-js/check-server.mjs    # muss „53/53 … replay mate“ melden
cd Backend
supabase functions deploy submit-action
supabase functions deploy finish-bot-match
supabase functions deploy delete-account
```
- `SUPABASE_URL` und `SUPABASE_SERVICE_ROLE_KEY` stellt Supabase den Functions automatisch bereit – keine eigenen Secrets nötig.
- JWT-Prüfung bleibt **an** (Standard): nur angemeldete Spieler erreichen die Functions.
- Lokal testen: `supabase functions serve` (mit `supabase start`).
- **Nach jeder Regeländerung** neu bündeln und alle drei Functions neu deployen (Abschnitt 18).

Was die Functions tun:

| Function | Aufgabe |
|---|---|
| `submit-action` | Partie laden, alle bisherigen Aktionen mit dem Regel-Port nachspielen, prüfen: Absender am Zug, `ply` stimmt, Aktion erlaubt. Dann `record_action` – zieht die Zeit ab, gibt das Inkrement, erkennt Matt/Patt/Remis und bucht Trophäen, alles in einer Transaktion. |
| `finish-bot-match` | Bot-Ersatz-Partie am Ende nachspielen; Matt/Patt/Remis aus der Stellung, „resigned“/„timeout“ nur als Niederlage des Menschen. Speichert die Aktionen und bucht Trophäen. |
| `delete-account` | Löscht den Auth-Nutzer; Profil, Fortschritt und Warteschlange verschwinden per Kaskade. |

Alles andere (Namen, Gegnersuche, Lebenszeichen, Remis, Aufgeben, Zeitablauf) sind Datenbank-Funktionen, die die App per RPC aufruft.

---

## 8. Schritt 5 – Wartungsjob

Die Migration `20261028000002_online_cron.sql` legt mit **pg_cron** den Job `rookraid-maintain` an (alle 30 s, `maintain_matches()`):
- verwaiste Warteschlangen-Einträge (> 30 s ohne Abfrage) löschen,
- Partien ohne ersten Zug abbrechen (ohne Wertung),
- abgelaufene Uhren werten (falls beide Geräte offline sind),
- Spieler, die 45 s kein Lebenszeichen geschickt haben, verlieren (`abandoned`, E6) – auch im Bot-Ersatz; sind beide weg, Abbruch ohne Wertung,
- als letzte Absicherung: nie gemeldete Bot-Partien nach 3 Stunden als Niederlage werten.

Falls `cron.schedule('… ', '30 seconds', …)` abgelehnt wird (ältere pg_cron-Fassung): `'* * * * *'` (jede Minute) verwenden.

---

## 9. Schritt 6 – App: Supabase einbinden

1. **Paket:** Xcode → File → Add Package Dependencies → `https://github.com/supabase/supabase-swift` (Version 2.x, Produkt `Supabase`).
2. **Schlüssel nicht in den Code:** Datei `RookRaid/Config/Secrets.xcconfig` (in `.gitignore`):
   ```
   RR_SUPABASE_URL = https:/$()/<PROJECT_REF>.supabase.co
   RR_SUPABASE_ANON_KEY = <anon public key>
   ```
   (Das `$()` verhindert, dass xcconfig `//` als Kommentar liest.) Im Target unter **Build Settings → Based on Configuration File** eintragen bzw. per `#include "Secrets.xcconfig"` einbinden. In der `Info.plist`: `RRSupabaseURL = $(RR_SUPABASE_URL)` und `RRSupabaseAnonKey = $(RR_SUPABASE_ANON_KEY)`. `OnlineConfig.supabaseURL` / `supabaseAnonKey` lesen genau diese Schlüssel.
3. **Ein gemeinsamer Client** (neue Datei `Services/SupabaseClient.swift`):
   ```swift
   import Supabase

   enum Backend {
       static let client: SupabaseClient? = {
           guard let url = OnlineConfig.supabaseURL, let key = OnlineConfig.supabaseAnonKey else { return nil }
           return SupabaseClient(supabaseURL: url, supabaseKey: key)
       }()
       static var isAvailable: Bool { client != nil && OnlineConfig.enabled }
   }
   ```
4. `OnlineConfig.enabled` erst auf `true` setzen, wenn Konto, Suche und Partie (Schritte 7–9) fertig sind; vorher bleibt alles wie heute lokal.

> Die Swift-Beispiele unten folgen supabase-swift 2.x. Methodennamen bei Realtime haben sich zwischen Unterversionen geändert – beim Einbau gegen die aktuelle Doku des Pakets prüfen.

---

## 10. Schritt 7 – App: Konto

Neue Datei `Services/SupabaseAccountService.swift`, implementiert `AccountService` (`Services/Online.swift`).

```swift
import Supabase

final class SupabaseAccountService: AccountService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    var state: AccountState {
        guard let user = client.auth.currentUser else { return .guest }
        return .signedIn(userId: user.id.uuidString, anonymous: user.isAnonymous)
    }

    func signInAnonymously() async throws -> AccountSetup {
        if client.auth.currentUser == nil { _ = try await client.auth.signInAnonymously() }
        return try await setup()
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AccountSetup {
        _ = try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        return try await setup()
    }

    /// setup_account legt Profil + Fortschritt an (Gast-Fortschritt übernehmen) oder meldet „existing“.
    @MainActor private func setup() async throws -> AccountSetup {
        let store = ProfileStore.shared
        struct Params: Encodable { let p_snapshot: ProgressSnapshot; let p_card: PlayerCard }
        struct Reply: Decodable { let status: String; let progress: ServerProgress }
        // Fehler name_taken / name_invalid (E8) kommen als PostgrestError mit dieser Meldung → Namen-Dialog erneut zeigen
        let reply: Reply = try await client.rpc(OnlineConfig.Endpoint.setupAccount,
                                                params: Params(p_snapshot: store.progressSnapshot(), p_card: store.playerCard))
                                           .execute().value
        DeviceIdentity.link(accountId: client.auth.currentUser?.id.uuidString ?? "")
        return reply.status == "created" ? .created(reply.progress) : .existing(reply.progress)
    }

    func backup(_ snapshot: ProgressSnapshot) async throws {
        try await client.rpc(OnlineConfig.Endpoint.backupProgress, params: ["p_snapshot": snapshot]).execute()
    }

    func fetchProgress() async throws -> ServerProgress {
        try await client.from("progress").select().single().execute().value
    }

    func signOut() async throws { try await client.auth.signOut() }

    func deleteAccount() async throws {
        try await client.functions.invoke(OnlineConfig.Endpoint.deleteAccount)
        try? await client.auth.signOut()
    }
}
```

**In der App ergänzen:**
- **Spielername (E8, eindeutig):** Vor dem ersten Online-Kampf einen Namen-Dialog zeigen (vorbelegt mit dem lokalen Namen, falls er nicht „Du“ ist). Beim Tippen `name_available(p_name)` prüfen (grün „frei“ / rot „vergeben“ / „ungültig“), erst dann `setup_account` (der Name steht in `p_card.name`). Fehler `name_taken` (jemand war schneller) → Dialog erneut. Später ändern: `set_display_name(p_name)` im Profil – direkt in `profiles` schreiben darf die App den Namen nicht.
- **Erster Online-Kampf:** vor der Gegnersuche `signInAnonymously()` (E11). Ergebnis `.created` → Server-Trophäen in `profile.trophies` übernehmen. Ergebnis `.existing` (passiert nur nach Apple-Anmeldung auf neuem Gerät) → Dialog „Fortschritt von deinem Konto laden?“ → aus `progress.snapshot` wiederherstellen (neue Funktion `ProfileStore.restore(from: ProgressSnapshot)` – Karten, XP, Splitter, Avatare usw. übernehmen; Trophäen immer vom Server).
- **Nach jeder Partie und beim Wechsel in den Hintergrund:** `backup(store.progressSnapshot())` (leise, Fehler ignorieren).
- **Trophäen:** Online kommen sie nur noch vom Server (Antwort von `submit-action`/`finish-bot-match` bzw. `fetchProgress()`); `ProfileStore.record(...)` darf für Online-Partien **keine** Trophäen mehr verrechnen, XP/Truhen/Flamme lokal wie bisher.
- **Profil-Tab → neuer Abschnitt „Konto“:** Status („Gast“, „Nicht gesichert“, „Mit Apple gesichert“), Knopf „Mit Apple sichern“ (`SignInWithAppleButton`), „Abmelden“, **„Konto löschen“** (zweistufige Bestätigung → `deleteAccount()` → lokales Profil behalten, Konto-ID entfernen).
- **Erinnerung:** Nach 3 Online-Partien mit anonymem Konto einmal freundlich fragen, ob das Konto mit Apple gesichert werden soll (Rocky kann das sagen).
- `ProgressSnapshot.schema` bei Formatänderungen hochzählen.

---

## 11. Schritt 8 – App: Gegnersuche und Bot-Ersatz

Neue Datei `Services/SupabaseMatchService.swift`, implementiert `MatchService`. Ablauf (genau so erwartet ihn der Server):

1. `find_match(p_rules_version, p_time_control, p_deck, p_ultimate, p_card)` sofort und dann **alle 2 s** (`OnlineConfig.matchmakingPoll`) aufrufen. Der Server führt die Warteschlange selbst; wer länger als 6 s nicht fragt, gilt als weg.
2. Kommt eine `uuid` zurück → Mensch gefunden → Partie laden (`matches` + Gegnerkarte) → Online-Partie starten (Schritt 9).
3. Nach **10 s** (`OnlineConfig.matchmakingTimeout`) ohne Treffer → `start_bot_match(...)`. Die App schickt die Spielerkarte des Bots (`BotCards.card(for:near:)`), das Bot-Deck (`BotLevel.deck`) und die Bot-Ultimate; die **Stufe** bestimmt der Server aus den Trophäen (`bot_level_for`, wie `BotLevel.forTrophies`). Antwort `is_bot = false` → in letzter Sekunde doch ein Mensch → wie 2.
4. Abbrechen (Knopf „Abbrechen“ im Such-Bildschirm): `cancel_matchmaking()`.
5. Fehler `rules_outdated` → Hinweis „Bitte aktualisiere Rook Raid, um online zu spielen“; `deck_incomplete` kann nicht vorkommen (Deck muss voll sein, v0.9.31).
6. Zeitkontrolle ist online immer **5 | 0** (`OnlineConfig.timeControl`, E3) – unabhängig von der Uhr-Einstellung, die nur offline gilt. Im Such-Bildschirm „5 | 0“ anzeigen.

```swift
final class SupabaseMatchService: MatchService {
    private let client: SupabaseClient
    private var cancelled = false
    init(client: SupabaseClient) { self.client = client }

    func findMatch(_ request: MatchRequest) async throws -> MatchFound {
        cancelled = false
        struct Find: Encodable { let p_rules_version: Int; let p_time_control: String; let p_deck: [String]; let p_ultimate: String; let p_card: PlayerCard }
        // request.timeControl ist online immer OnlineConfig.timeControl.rawValue ("blitz5", E3)
        let params = Find(p_rules_version: request.rulesVersion, p_time_control: request.timeControl,
                          p_deck: request.deck, p_ultimate: request.ultimate, p_card: request.player)
        let start = Date()
        while Date().timeIntervalSince(start) < OnlineConfig.matchmakingTimeout {
            try Task.checkCancellation()
            if cancelled { throw CancellationError() }
            let id: UUID? = try await client.rpc(OnlineConfig.Endpoint.findMatch, params: params).execute().value
            if let id { return try await humanMatch(id) }
            try await Task.sleep(nanoseconds: UInt64(OnlineConfig.matchmakingPoll * 1_000_000_000))
        }
        return try await botMatch(request)
    }

    func cancel() {
        cancelled = true
        Task { try? await client.rpc(OnlineConfig.Endpoint.cancelMatchmaking).execute() }
    }

    // humanMatch(id): matches-Zeile laden, Farbe bestimmen (white == eigene ID), Gegnerkarte = white_card/black_card,
    //                 MatchFound(kind: .human, opponent:, botLevel: nil, youAreWhite:, matchId: id)
    // botMatch(request): Level = BotLevel.forTrophies(Server-Trophäen), Karte = BotCards.card(for:near:),
    //                 start_bot_match(...) aufrufen; bei is_bot == false → humanMatch(match_id);
    //                 sonst MatchFound(kind: .bot, opponent: Karte, botLevel: BotLevel(rawValue: bot_level), youAreWhite: human_white, matchId:)
}
```

**Such-Bildschirm:** Statt sofort ins Duell-Intro: kurzer Bildschirm „Gegner wird gesucht …“ mit Rocky, laufender Sekundenanzeige und „Abbrechen“. Er darf bei Bot-Ersatz **genauso** aussehen wie bei Menschen (E1) – das Duell-Intro zeigt dann die Spielerkarte des Gegners.

**Bot-Ersatz-Partie spielen:** lokal wie heute im Modus `.bot(level)` (Bot rechnet auf dem Gerät, inklusive der 0–7-s-Pausen), aber mit gemerkter `matchId`, Zeitkontrolle 5 | 0 und – wie gegen Menschen – **alle 10 s `match_heartbeat`** (E6). Bricht die Verbindung länger als 45 s ab oder liegt die App so lange im Hintergrund, wertet der Server die Partie als verloren (`abandoned`); die App fragt beim Zurückkommen den Status der Partie ab und zeigt dann das Ergebnis statt weiterzuspielen. Am Ende: `BotMatchReporter.finish(matchId:actions: matchRecord.actions, outcome:)` → Edge Function `finish-bot-match`. `outcome`: `.completed` (Matt/Patt/Remis), `.resigned` (Spieler gab auf), `.timeout` (Spieler-Uhr abgelaufen). Die Antwort enthält die Trophäen-Änderung → im Ergebnis-Fenster anzeigen. Ohne Netz am Ende: Meldung speichern und nachreichen, sobald das Netz zurück ist – war die Verbindung länger als 45 s weg, hat der Server die Partie aber schon als Niederlage gewertet.

---

## 12. Schritt 9 – App: Online-Partie

### 12.1 Neuer Spielmodus
`GameMode` (Persistence.swift) um `case online(UUID)` erweitern (Codable, Equatable). `isBot` = false, eigener Titel „Gegen <Name>“, `isRated` = true. `GameViewModel` bekommt einen zweiten Initialisierer `init(online: OnlineMatchInfo, session: OnlineMatchSession)`:
- `state = info.record.replay().state` (Grundstellung + ggf. schon gespielte Aktionen),
- `humanColor = info.myColor`, Gegnername/-avatar aus `info.opponent`,
- `timeControl = info.timeControl`, `aiColor` = nil (kein Bot),
- `introActive = true` (Duell-Intro; der Server startet die Uhr erst nach 5 s).

### 12.2 Eigene Aktionen senden
Alle eigenen Aktionen laufen schon durch `finishAction(entry:)` (Zug, Karte, Ultimate). Dort für Online-Partien:
```swift
if case .online = mode, entry.color == humanColor, let code = entry.action?.wire(ultimate: state.ultimates[entry.color]) {
    let ply = moves.count - 1                       // Index dieser Aktion = Anzahl der Aktionen davor
    Task { await sendOnline(code, ply: ply) }
}
```
`sendOnline` ruft `session.submit(code, ply:)`:
- Erfolg → nichts weiter (die Aktion steht schon lokal; die Realtime-Bestätigung wird an `ply` erkannt und übersprungen).
- `.outOfSync` → **neu aufbauen:** `fetchActions()`, Stellung aus `record.replay()`, Anzeige ohne Animation aktualisieren.
- `.illegalAction` → sollte nie passieren (gleiche Regeln); trotzdem neu aufbauen und Hinweis zeigen.
- `.timeout`/`.notActive` → auf das `finished`-Ereignis warten.
- `.network` → Wiederholen mit gleichem `ply` (der Server lehnt Doppelte als `out_of_sync` ab – also sicher).

### 12.3 Aktionen des Gegners anwenden
`session.events` abonnieren (`for await event in session.events` in einer `Task`, beim Schließen abbrechen):
- `.action(ply, code, _)`: Ist `ply < moves.count` → eigene oder schon bekannte Aktion, überspringen. Ist `ply == moves.count` → `state.validate(code)` liefert eine `ReplayAction`; diese durch **dieselben** Wege wie bei Bot-Zügen schicken (`applyAI` macht das heute schon: `.move` → `perform`, `.card` → `play`, `.ultimate` → `performUltimate`) – so laufen Animationen, Töne und Mana-Anzeige. Dafür `applyAI` in eine allgemeine Funktion `applyOpponent(_ action: ReplayAction)` umbenennen und von beiden Stellen nutzen. Ist `ply > moves.count` → Lücke → neu aufbauen.
- `.clocks(white, black, turn)`: `clocks` setzen (Server ist maßgeblich), lokal nur die Anzeige herunterzählen. Erreicht die Anzeige 0:00 → `session.claimTimeout()`. Bei 5 | 0 gibt es kein Inkrement – die Bot-Denkpausen sind durch die Restzeit gedeckelt (`humanLikePause`).
- `.drawOffered(by:)` / `.drawOfferCleared`: Banner „<Name> bietet Remis an – Annehmen / Ablehnen“ (`answerDraw`). Eigenes Angebot über das Menü (`offerDraw`, erst ab dem ersten Zugpaar).
- `.finished(result, winner, myTrophyDelta)`: Ergebnis-Fenster mit dem Server-Ergebnis; `store.record(...)` nur für XP/Truhen/Flamme und Verlauf, Trophäen = `myTrophyDelta` (danach `fetchProgress()`).
- **Lebenszeichen (E6):** Während der ganzen Partie alle 10 s `match_heartbeat(p_match)` (`OnlineConfig.heartbeatInterval`). Die Antwort enthält `opponent_silent_s`: ab 15 s Anzeige „Verbindung zum Gegner unterbrochen …“ mit Countdown bis 45 s; danach `claim_timeout()` aufrufen – der Server wertet die Partie für dich (`abandoned`). Die eigene Uhr läuft in dieser Zeit weiter.
- `.opponentConnected(_)`: optional zusätzlich über Realtime Presence (schneller als der 10-s-Takt), maßgeblich bleibt der Server.
- **Eigene Verbindung weg:** Banner „Verbindung verloren – noch X s, um zurückzukommen“ (45 s ab dem letzten erfolgreichen Heartbeat). Die App läuft im Hintergrund nicht weiter – wer die App länger als 45 s verlässt, verliert; das beim ersten Online-Spiel einmal erklären.
- „Aufgeben“ im Menü → `session.resign()`.

### 12.4 Die Supabase-Sitzung (`Services/SupabaseMatchSession.swift`)
```swift
final class SupabaseMatchSession: OnlineMatchSession {
    let info: OnlineMatchInfo
    let events: AsyncStream<OnlineMatchEvent>
    private let continuation: AsyncStream<OnlineMatchEvent>.Continuation
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?

    init(info: OnlineMatchInfo, client: SupabaseClient) {
        self.info = info; self.client = client
        (events, continuation) = AsyncStream.makeStream()
        Task { await connect() }
    }

    private func connect() async {
        let ch = client.channel("match-\(info.matchId.uuidString)")
        let inserts = ch.postgresChange(InsertAction.self, schema: "public", table: "match_actions",
                                        filter: "match_id=eq.\(info.matchId.uuidString)")
        let updates = ch.postgresChange(UpdateAction.self, schema: "public", table: "matches",
                                        filter: "id=eq.\(info.matchId.uuidString)")
        await ch.subscribe()
        channel = ch
        Task { for await row in inserts { /* ActionRow(ply, code, clock_ms) dekodieren → continuation.yield(.action(...)) */ } }
        Task { for await row in updates { /* MatchRow: Uhren, draw_offer_by, status/result/winner_color/trophy_delta_* → yield */ } }
        // Presence: try await ch.track(["user": <eigene ID>]); ch.presenceChange() → .opponentConnected(...)
    }

    func submit(_ code: String, ply: Int) async throws {
        struct Body: Encodable { let match_id: UUID; let ply: Int; let code: String }
        // client.functions.invoke(OnlineConfig.Endpoint.submitAction, options: .init(body: Body(...)))
        // HTTP 409 {error: out_of_sync, action_count} → throw .outOfSync(actionCount:); 409 not_your_turn → .notYourTurn;
        // 409 timeout → .timeout; 409 not_active → .notActive; 422 → .illegalAction; sonst Netzwerkfehler → .network
    }
    func resign() async throws { try await client.rpc(OnlineConfig.Endpoint.resign, params: ["p_match": info.matchId]).execute() }
    func offerDraw() async throws { try await client.rpc(OnlineConfig.Endpoint.offerDraw, params: ["p_match": info.matchId]).execute() }
    func answerDraw(accept: Bool) async throws { /* answer_draw(p_match, p_accept) */ }
    func claimTimeout() async throws { try await client.rpc(OnlineConfig.Endpoint.claimTimeout, params: ["p_match": info.matchId]).execute() }
    func fetchActions() async throws -> [String] {
        struct Row: Decodable { let code: String }
        let rows: [Row] = try await client.from("match_actions").select("code")
            .eq("match_id", value: info.matchId).order("ply").execute().value
        return rows.map(\.code)
    }
    func close() { continuation.finish(); Task { await channel?.unsubscribe() } }
}
```
**Realtime-Lücken:** Nach jedem (Wieder-)Verbinden des Kanals einmal `fetchActions()` und mit `moves.count` vergleichen – Realtime garantiert keine Zustellung während einer Unterbrechung.

---

## 13. Schritt 10 – Wiederverbinden, Regel-Updates, Bestenliste

- **App-Start / Rückkehr aus dem Hintergrund:** laufende Online-Partie suchen
  `from("matches").select().eq("status", "active").or("white.eq.<id>,black.eq.<id>")` → falls vorhanden und `is_bot == false`: Sitzung öffnen, `fetchActions()`, Partie fortsetzen (Banner „Zurück in deiner Partie“). Bot-Partien setzt die App wie heute aus dem lokalen Spielstand fort und meldet am Ende.
- **Regel-Version:** beim Start `active_rules()` abfragen. Ist die Server-Version **höher** und kennt die App alle Karten → `RulesConfig.adopt(...)`. Kennt sie eine Karte nicht (neue Karte = App-Update nötig) → online gesperrt mit Hinweis „Update verfügbar“. Ist die App-Version **höher** als die aktive Server-Version → online gesperrt, bis der Server nachgezogen hat (siehe 18).
- **Bestenliste: erst Phase 2 (E5).** Die Server-Funktionen `get_leaderboard(p_limit)` und `my_rank()` gibt es schon; in Phase 1 keine Anzeige in der App.

---

## 14. Protokoll-Referenz

### 14.1 Aktionen (Draht-Format, identisch in App und Server)
| Aktion | Beispiel |
|---|---|
| Zug | `e2e4`, Umwandlung `e7e8q` (q, r, b, n; ohne Buchstabe = Dame) |
| Rochade | als Königszug `e1g1` / `e1c1` |
| Karte mit Ziel | `card:freeze@f6`, `card:retreat@e3` (Rückzug: Zielfeld) |
| Karte ohne Ziel | `card:bulwark`, `card:advance`, `card:focus`, `card:drain` |
| Ultimate | `ult:meteor@d8`, `ult:iceAge`, `ult:fortress`, `ult:coronation@e6`, `ult:rebirth` |

**`ply`** = laufende Nummer der Aktion ab 0. Karten, Ultimates und der Figurzug nach einer Bonuskarte zählen **jeweils einzeln** (Bonuskarte = 2 Aktionen derselben Seite hintereinander). Die App nutzt dafür `moves.count`, der Server `matches.action_count`.

### 14.2 Uhr (Server ist maßgeblich)
- Online gilt nur **5 | 0**: 300 s pro Spieler, **kein Inkrement** (E3). Weitere Zeitkontrollen ließen sich später in `tc_base_ms`/`tc_increment_ms` ergänzen.
- Die Uhr von Weiß startet 5 s nach Partiebeginn (`clock_started_at`, Duell-Intro).
- Verbrauchte Zeit = jetzt − `last_action_at` (vor dem ersten Zug: − `clock_started_at`).
- Inkrement-Logik (für spätere Zeitkontrollen mit Inkrement schon eingebaut): gutgeschrieben, sobald der Zug an den Gegner geht – nach einem Figurzug (auch dem Bonuszug), einer Karte ohne Bonus, einer Ultimate ohne Bonus; nach einer Bonuskarte noch nicht.
- **Verbindung (E6):** Jedes Gerät meldet sich alle 10 s (`match_heartbeat`). Wer 45 s still ist, verliert (`abandoned`); sind beide still, Abbruch ohne Wertung.
- Zeit abgelaufen: Wer zuerst merkt (Gerät per `claim_timeout` oder Wartungsjob), beendet die Partie; der Gegner gewinnt.

### 14.3 Ergebnisse (`matches.result`)
`mate`, `stalemate`, `fifty`, `repetition`, `timeout`, `resigned`, `draw_agreed`, `aborted` (ohne Wertung), `abandoned` (Spieler 45 s ohne Verbindung – gegen Menschen und Bot-Ersatz). `winner_color` = `white`/`black` oder leer (Remis/Abbruch).

### 14.4 Trophäen (`apply_result`, gleiche Formel wie `ProfileStore.record`)
Sieg **+30**, Remis **+5**, Niederlage **−20**, aber nie unter die Untergrenze der aktuellen Arena (0 · 90 · 240 · 600 · 1 200 · 2 100). Beispiel: 95 Trophäen, Niederlage → −5.

### 14.5 Datenbank-Funktionen (RPC, für angemeldete Spieler)
| Funktion | Zweck | Wichtige Fehler |
|---|---|---|
| `name_available(p_name)` → `bool` | Name gültig und frei? (E8) | – |
| `setup_account(p_snapshot, p_card)` | Konto einrichten / Bestand melden; Name aus `p_card.name` | `not_authenticated`, `name_invalid`, `name_taken` |
| `set_display_name(p_name)` | Namen ändern | `name_invalid`, `name_taken` |
| `backup_progress(p_snapshot)` | Sicherung (≤ 64 KB) | `snapshot_too_large` |
| `find_match(p_rules_version, p_time_control, p_deck, p_ultimate, p_card)` → `uuid?` | Suchen (alle 2 s) | `rules_outdated`, `deck_incomplete`, `unknown_card`, `bad_time_control`, `no_account` |
| `cancel_matchmaking()` | Suche abbrechen | – |
| `start_bot_match(…, p_bot_card, p_bot_deck, p_bot_ultimate, p_human_white)` → `(match_id, is_bot, bot_level, human_white)` | Bot-Ersatz | wie oben |
| `resign_match(p_match)` | Aufgeben (Mensch gegen Mensch) | `not_participant` |
| `offer_draw(p_match)` / `answer_draw(p_match, p_accept)` | Remis | `too_early`, `no_offer` |
| `match_heartbeat(p_match)` → `{status, opponent_silent_s}` | Lebenszeichen alle 10 s (E6) | `not_participant` |
| `claim_timeout(p_match)` | Zeitablauf, Verbindungsabbruch des Gegners (> 45 s), Abbruch ohne ersten Zug prüfen | – |
| `active_rules()` | Aktive Regel-Version | – |
| `get_leaderboard(p_limit)`, `my_rank()` | Bestenliste (in der App erst Phase 2) | – |

Nur für den Server (Service-Rolle): `record_action`, `finish_match`, `apply_result`, `create_match`, `maintain_matches`.

### 14.6 Edge Functions (HTTP POST, JSON, `Authorization: Bearer <JWT>` setzt supabase-swift automatisch)
- `submit-action` `{match_id, ply, code}` → `200 {ok, ply, clock_ms, turn}` oder `{ok, ply, finish}`; `409 {error: out_of_sync | not_your_turn | timeout | not_active}`; `422 {error: illegal_action}`.
- `finish-bot-match` `{match_id, actions: [...], outcome: "final" | "resigned" | "timeout"}` → `200 {status, result, winner, trophy_delta_white, trophy_delta_black}`; `422 illegal_action | not_finished`.
- `delete-account` `{}` → `200 {ok: true}`.

---

## 15. Sicherheit und Anti-Cheat

**Schon abgedeckt:**
- Tabellen für die App nur lesbar (RLS); keine direkten Schreibrechte auf `progress`, `matches`, `match_actions`, `matchmaking_queue`. Profile: nur Kosmetik-Spalten.
- Jede Online-Aktion wird auf dem Server mit denselben Regeln nachgespielt und geprüft (Zug am Zug, erlaubt, richtige Nummer) – doppelte oder veraltete Sendungen scheitern an `ply`.
- Uhr, Ergebnis und Trophäen rechnet nur der Server; Trophäen aus Gast-Spielständen gedeckelt.
- Bot-Stufe bestimmt der Server; Bot-Partien werden vollständig nachgespielt.

**Bekannte Restrisiken (Phase 1 bewusst akzeptiert):**
- **Freigeschaltete Karten** liegen auf dem Gerät – ein manipuliertes Gerät könnte ungekaufte Karten ins Deck nehmen. Abhilfe Phase 2: Freischaltungen serverseitig (E2).
- **Bot-Partien:** Der Bot rechnet auf dem Gerät; ein manipulierter Client könnte den Bot absichtlich schlecht ziehen lassen und so Trophäen sammeln. Abhilfe Phase 2: auffällige Statistiken (z. B. > 90 % Siege gegen Bots über viele Partien) markieren; Bot-Züge stichprobenartig auf dem Server mit dem JS-Bot (`rrjs/ai.js` aus dem Simulator) bewerten; Bot-Ersatz ab hohen Trophäen erst nach längerer Wartezeit.
- **Anonyme Konten in Massen:** Rate-Limit in Supabase Auth (6.1). Eindeutige Namen machen Massen-Konten zusätzlich mühsam.
- **Namen:** Phase 1 prüft nur Länge und Zeichen, keinen Wortfilter – anstößige Namen per SQL umbenennen; Filter und Melden in Phase 2.
- Bei Verdacht: Trophäen in `progress` per SQL zurücksetzen; Sperrliste als Spalte `profiles.banned` (Phase 2).

---

## 16. Recht und App Store

- **Datenschutzerklärung (DSGVO)** – in der App verlinkt und im App Store: welche Daten (Konto-ID, bei Apple ggf. weitergeleitete E-Mail-Adresse, Spielername, Avatar, Trophäen, Partien mit Zügen, Gast-ID des Geräts, technische Protokolle), Zweck (Spielbetrieb, Gegnersuche, Bestenliste), Rechtsgrundlage (Vertragserfüllung), Auftragsverarbeiter **Supabase** (Vertrag zur Auftragsverarbeitung/DPA im Dashboard abschließen), Speicherort EU, Speicherdauer, Rechte (Auskunft, Löschung – Knopf in der App).
- **Konto löschen in der App** ist bei Apple Pflicht, sobald man Konten anlegen kann → `delete-account` + Knopf im Profil (Schritt 7).
- **App Store Connect → App-Datenschutz:** „Kennungen (Nutzer-ID)“, „Gameplay-Inhalte“, ggf. „E-Mail“ – mit dem Nutzer verknüpft, **kein Tracking**.
- **Sign in with Apple** ist die einzige Social-Anmeldung → Apple-Richtlinie 4.8 erfüllt. Kommt Google dazu, muss Apple angeboten bleiben.
- **Altersfreigabe:** kein Chat, keine nutzergenerierten Inhalte außer Spielernamen → niedrige Einstufung; ein Wortfilter für Namen ist vor dem Store-Start ratsam (Phase 2, siehe oben).
- **Impressum** (Anbieterkennzeichnung, § 5 DDG) auf der Website und in der App verlinkt; **Nutzungsbedingungen** – ein Satz wie „Gegner können auch computergesteuert sein“ ist rechtlich sauberer, ohne Bots im Spiel kenntlich zu machen (bitte rechtlich prüfen lassen).
- Keine Echtgeld-Käufe in Phase 1 → keine Zahlungsfragen.

---

## 17. Testplan

1. **Regeln gleich auf App und Server**
   - `node Tools/rules-js/check-golden.js` → 53/53
   - `node Tools/rules-js/check-server.mjs` → 53/53 + Partie bis zum Matt
   - **Auf dem iPhone (Debug-Build): Einstellungen → Entwickler → Regeltests → 53/53.** Noch nie auf einem Gerät gelaufen – vor allem anderen erledigen. Jede Abweichung heißt: App und Server rechnen verschieden.
2. **Datenbank** – `Backend/tests` (README dort): 50 Prüfungen + Partie-Ablauf gegen ein leeres Postgres oder `supabase start`.
3. **Functions lokal** – `supabase start` + `supabase functions serve`; mit zwei Simulatoren (oder Simulator + iPhone) eine Partie bis zum Matt, eine Aufgabe, ein Remis, ein Zeitablauf.
4. **Gegnersuche** – zwei Geräte gleichzeitig suchen lassen (Paarung), ein Gerät allein (Bot nach 10 s), Abbrechen, Suche während schlechter Verbindung.
5. **Robustheit** – Flugmodus mitten in der Partie: unter 45 s weiterspielen (nach Rückkehr `fetchActions`), über 45 s verloren – bei beiden Spielern richtig angezeigt; App beenden und neu starten (Partie fortsetzen), gleichzeitige Züge (nur einer gewinnt), Bot-Partie ohne Netz beenden (Meldung nachreichen).
6. **Konto** – anonym spielen, mit Apple sichern, auf zweitem Gerät mit Apple anmelden (Wiederherstellen-Dialog), Konto löschen (Daten weg, App läuft lokal weiter).
7. **TestFlight** mit 5–10 Spielern, Supabase-Logs (Functions, Postgres) beobachten.

---

## 18. Betrieb, Regeländerungen, Kosten

**Regeln ändern (Kosten, neue Karte, …) – immer in dieser Reihenfolge:**
1. `RookRaid/Engine/rookraid-rules.json` ändern, `version` hochzählen; bei neuen Karten Swift-Engine **und** `Tools/rules-js/engine.js` anpassen.
2. Tests: `golden-cases.json` ergänzen → `node make-golden.js` → `node check-golden.js` → App-Regeltests.
3. `node build-server.js` → `node check-server.mjs` → alle Functions deployen.
4. `KEEP_OLD=1 node seed-rules.js` → `seed/rules.sql` einspielen: neue Version aktiv, **alte bleibt aktiv**, solange die alte App-Version noch im Umlauf ist (gepaart wird immer nur innerhalb derselben Version).
5. App-Update veröffentlichen. Wenn die meisten aktualisiert haben: `node seed-rules.js` (ohne KEEP_OLD) einspielen → alte Version aus.
6. Laufende Partien behalten ihre Version (`matches.rules_version`) – der Server spielt sie mit ihren eigenen Regeln nach.

**Überwachung:** Dashboard → Logs (Edge Functions, Postgres); Function-Fehler erscheinen als `server_error` mit Konsolen-Ausgabe. Abfragen für den Alltag:
```sql
select count(*) from matches where status = 'active';
select result, count(*) from matches where ended_at > now() - interval '1 day' group by 1;
select count(*) filter (where is_bot) * 100.0 / count(*) as bot_anteil from matches where created_at > now() - interval '1 day';
```

**Kosten:** Der kostenlose Plan genügt für Entwicklung und TestFlight, pausiert aber inaktive Projekte. Für den Start im Store den kostenpflichtigen Plan nehmen (aktuelle Preise auf der Supabase-Preisseite prüfen). Lasttreiber sind Realtime-Verbindungen und Function-Aufrufe (ein Aufruf pro Aktion, ca. 60–120 pro Partie).

---

## 19. Phase 2 (bewusst noch nicht enthalten)

- **Revanche** online (beide tippen „Revanche“ → neue Partie, Farben getauscht; Spalte `matches.rematch_of`).
- **Freunde** mit Spielersuche (Tabellen `friendships`, `friend_requests`, Herausforderungen ohne Warteschlange).
- **Turniere** und **Clubs** (in der App weiter „bald verfügbar“).
- **Serverseitige Wirtschaft** (E2): Freischaltungen, Truhen, Splitter, Tagesziele als Server-Funktionen; danach Anti-Cheat für Decks.
- **Push-Mitteilungen** („Dein Gegner hat gezogen“ – erst bei längeren Zeitkontrollen sinnvoll).
- **Android und Browser:** Der JS-Regel-Port ist schon da; Anmeldung dort mit Google/E-Mail (Apple zusätzlich anbieten).
- **Bestenliste in der App** (E5) – Server-Funktionen sind schon da.
- Wortfilter und Melden von Namen, Sperren, Moderation.

---

## 20. Datei-Übersicht

| Datei | Inhalt |
|---|---|
| `Backend/ONLINE-IMPLEMENTIERUNG.md` | diese Anleitung |
| `Backend/README.md` | Kurzüberblick und Befehle |
| `Backend/supabase/migrations/20261028000001_online_init.sql` | Datenbank: Tabellen, RLS, Funktionen |
| `Backend/supabase/migrations/20261028000002_online_cron.sql` | Wartungsjob |
| `Backend/supabase/seed/rules.sql` | Regeln (generiert) |
| `Backend/supabase/functions/_shared/common.ts` | gemeinsamer Function-Code |
| `Backend/supabase/functions/_shared/rookraid-rules.mjs` | Regeln für den Server (generiert) |
| `Backend/supabase/functions/submit-action/index.ts` | Zug prüfen und speichern |
| `Backend/supabase/functions/finish-bot-match/index.ts` | Bot-Partie werten |
| `Backend/supabase/functions/delete-account/index.ts` | Konto löschen |
| `Backend/tests/` | Datenbank- und Ablauf-Tests |
| `Tools/rules-js/core.js`, `rules.js`, `engine.js` | Regel-Port |
| `Tools/rules-js/build-server.js`, `check-server.mjs`, `seed-rules.js` | Bündeln, Prüfen, Regeln eintragen |
| `RookRaid/Services/Online.swift` | App-Schnittstellen für Konto, Suche, Partie |
| `RookRaid/Engine/GameAction.swift` | Draht-Format, `MatchRecord` |
| `RookRaid/Engine/RulesSelfTest.swift` | Regeltests in der App (FEN und ganze Partien) |
