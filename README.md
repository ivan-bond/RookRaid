# Rook Raid – Prototyp v0.9.36

Schach mit Karten: Jeder Zug lädt Mana, Mana bezahlt Karten, und ab 8 Mana lässt sich die Ultimate einsetzen (die Festung schon ab 6). Alle Daten werden **nur lokal auf dem iPhone** gespeichert.

## Starten
1. Ordner entpacken und `RookRaid.xcodeproj` mit Xcode 16 oder neuer öffnen.
2. Unter *Signing & Capabilities* das eigene Team wählen und den Bundle Identifier anpassen.
3. iPhone als Ziel wählen und mit ⌘R starten.

## Regeln (Stand v0.9.20)
- **Eine Aktion pro Runde:** ein Schachzug, eine Karte oder die Ultimate.
- **Sieg** durch Schachmatt oder wenn die Uhr des Gegners abläuft.
- **Gebiet:** Jede Figur besetzt ihr eigenes Feld und alle 8 Nachbarfelder, auch diagonal. Grenzt ein Feld an Figuren beider Seiten oder an gar keine Figur, ist es neutral.
  - Auf dem Brett ist dein Gebiet heller und frischer getönt, das gegnerische etwas gedeckter (Variante „Farbton“). Es zeigt nur, wo deine Figuren das Brett beherrschen – **Mana bringt es seit v0.9.20 nicht mehr**.
- **Mana (maximal 10, Start 1):**
  - Zu Beginn jedes eigenen Zugs: +1.
  - Guter Zug: +1 extra für Schlagen oder Schach – höchstens +1 pro Zug. Taktiken (Gabel, Fesselung, Spieß, Abzugs- oder Doppelschach) werden angesagt und zählen für Erfolge, bringen aber kein Mana (wie der Server).
  - Mana-Karten (Konzentration, Manaraub, Bauernopfer) bringen weiterhin zusätzlich Mana.
  - Jede Gutschrift erscheint kurz an der Mana-Leiste, zum Beispiel „+1 Gabel“.
- **Ultimate:** Wird vor der Partie gewählt und ist ab **8 Mana** einsetzbar, die Festung schon ab **6 Mana** (die gefüllten Felder der Mana-Leiste leuchten dann golden). Sie verbraucht so viel Mana, der Rest bleibt. Der Gegner sieht die Wahl und den Ladestand.
  - Meteor vernichtet eine Figur (nicht König oder Dame); ungeschützte gegnerische Bauern direkt daneben können zwei Züge lang nicht ziehen.
  - Festung (6 Mana): Bonuszug danach ohne Schlagen und ohne Schach.
  - Meteor und Festung sind ab Arena 1 verfügbar, Eiszeit und Krönung ab Arena 2 (90 Trophäen), Wiedergeburt ab Arena 3 (240).
- **Deck:** Vor der Partie wählt jeder 4 Karten und 1 Ultimate (Tab „Deck“). Die Karten bleiben die ganze Partie auf der Hand, es wird nicht nachgezogen. Nach dem Ausspielen lädt eine Karte **2 eigene Züge** nach. Beide Decks sind offen.
- **Karten:** 15 Zauber in fünf Rollen. 4 Startkarten gibt es sofort, die anderen 11 kommen aus Truhen oder werden mit Splittern gekauft.

  | Karte | Mana | Rolle | Wirkung | Seltenheit |
  |---|---|---|---|---|
  | Bauernopfer | 0 | Mana | Eigener Bauer wird geopfert, +3 Mana. **Bonusaktion.** | Selten |
  | Konzentration | 0 | Mana | +4 Mana. | Episch |
  | Manaraub | 0 | Kontrolle | Gegner verliert die Hälfte seines Manas, du erhältst 2. | Episch |
  | Vormarsch | 3 | Angriff | Alle eigenen Bauern rücken ein Feld vor (nicht auf die letzte Reihe). **Bonusaktion.** | Gewöhnlich |
  | Bollwerk | 2 | Verteidigung | Alle eigenen Bauern eine Runde geschützt. **Bonusaktion.** | Gewöhnlich |
  | Blitz | 2 | Kontrolle | Vernichtet einen gegnerischen Bauern, der in deine Hälfte vorgerückt ist (nur Schild oder Bollwerk schützen ihn). Lädt **3 Züge** nach. | Start |
  | Verstärkung | 1 | Verteidigung | Neuer Bauer auf deiner zweiten Reihe. | Gewöhnlich |
  | Rückzug | 1 | Verteidigung | Ein eigener Bauer weicht 1 oder 2 Felder zurück (Weg frei, nicht auf die Grundreihe). **Bonusaktion**, der Bauer bleibt danach stehen. | Gewöhnlich |
  | Schild | 2 | Verteidigung | Eigene Figur eine Runde unschlagbar. **Bonusaktion**, die geschützte Figur bleibt stehen. | Start |
  | Leibwache | 4 | Verteidigung | König tauscht den Platz mit einer eigenen Figur (kein Bauer). **Bonusaktion.** | Selten |
  | Ritterschlag | 3 | Angriff | Eigener Bauer wird zum Springer. | Gewöhnlich |
  | Läuferweihe | 3 | Angriff | Eigener Bauer wird zum Läufer. | Episch |
  | Sturmlauf | 3 | Angriff | Ein Bauer rückt 2 Felder vor. **Bonusaktion**, der Bauer bleibt danach stehen. | Start |
  | Frost | 4 | Kontrolle | Gegnerische Figur (nicht König oder Dame) kann im nächsten Zug nicht ziehen. **Bonusaktion.** | Start |
  | Wiederkehr | 6 | Comeback | Geschlagener Turm, Läufer oder Springer kehrt zurück. | Selten |

  Bonusaktionen ersetzen den Zug nicht: Danach folgt noch ein Figurzug. Eine zweite Karte oder die Ultimate geht in diesem Zug nicht mehr.
- **Tauwetter:** Kann ein Spieler, der nicht im Schach steht, nur wegen Frost nicht ziehen, tauen seine Figuren auf. Frost erzwingt also kein Patt.
- **Remis:** Patt, dreifache Stellungswiederholung und die 50-Züge-Regel. Karteneinsätze zählen wie Bauernzüge und Schläge, sie setzen den Zähler zurück.
- **Umwandlung:** Ein Bauer auf der letzten Reihe wird nach Wahl zu Dame, Turm, Läufer oder Springer.

## Neu in v0.9.36: Online-Entscheidungen festgelegt
Alle zwölf Entscheidungen stehen in `Backend/ONLINE-IMPLEMENTIERUNG.md` (Abschnitt 1) und sind im Server umgesetzt:
- **Online nur 5 | 0** (neue Zeitkontrolle `TimeControl.blitz5`; die Uhr-Auswahl in der App bleibt offline wie bisher).
- **45 s ohne Verbindung = verloren** (gegen Menschen und Bot-Ersatz): Lebenszeichen alle 10 s (`match_heartbeat`), Wertung durch `claim_timeout` und den Wartungsjob; sind beide weg, Abbruch ohne Wertung.
- **Eindeutige Spielernamen** (2–16 Zeichen, Groß-/Kleinschreibung egal): `name_available`, `set_display_name`, `setup_account` lehnt vergebene Namen ab.
- **Bestenliste erst in Phase 2** (Server-Funktionen bleiben vorbereitet).
- Wie empfohlen: Bot-Ersatz zählt für Trophäen, Server führt nur Trophäen und Online-Bilanz, neue Konten starten bei 0 Trophäen, Remis-Angebot, anonym spielen und später mit Apple sichern, Server in Frankfurt, Suche ±100 → ±400 mit Bot nach 10 s.
- Backend-Tests jetzt **50 Prüfungen** (vorher 38), alle bestanden.

## Neu in v0.9.35: Online-Implementierung vorbereitet (Supabase)
- **Anleitung:** `Backend/ONLINE-IMPLEMENTIERUNG.md` – Entscheidungen mit Empfehlung, Einrichtung Schritt für Schritt (Supabase, anonyme Anmeldung, Sign in with Apple, Functions, Wartungsjob), App-Anbindung mit Swift-Vorlagen, Protokoll, Sicherheit, Recht/App Store, Testplan, Betrieb.
- **Datenbank** (`Backend/supabase/migrations`): Konto einrichten mit Gast-Übernahme, Sicherung des Fortschritts, Gegnersuche mit wachsendem Trophäen-Fenster, Bot-Ersatz (Stufe vom Server), Uhr mit Inkrement auf dem Server, Remis-Angebot, Aufgeben, Zeitablauf, Abbruch ohne ersten Zug, Wartungsjob, Bestenliste. Die App kann nichts Wertvolles direkt schreiben.
- **Edge Functions:** `submit-action` (jede Aktion wird mit den Regeln nachgespielt und geprüft), `finish-bot-match`, `delete-account`. Deno-Typprüfung bestanden.
- **Regel-Port servertauglich:** Kern ohne Dateizugriff (`Tools/rules-js/core.js`), Bündel für Deno (`build-server.js`), Prüfung des Bündels (`check-server.mjs`), Regeln eintragen (`seed-rules.js`).
- **Regeltests 53** (vorher 49): vier ganze Partien aus der Grundstellung – so spielt der Server nach. Die App-Regeltests (Debug) können das jetzt auch.
- **Backend-Tests** (`Backend/tests`): 38 Prüfungen der Datenbank-Funktionen und ein Partie-Ablauf bis zum Matt gegen ein lokales Postgres 17 – alle bestanden.
- **App-Schnittstellen** in `Services/Online.swift`: `AccountService`, `OnlineMatchSession`, `BotMatchReporter`, `OnlineMatchInfo`/`Event`/`Error`, Supabase-Schlüssel aus der Info.plist. Online bleibt aus (`OnlineConfig.enabled = false`).

## Neu in v0.9.34: Neues Logo, neue Karte Rückzug, menschlichere Bots
- **Neues App-Logo** (Rocky mit Schild-, Blitz- und Schwertkarte, Meteor): App-Icon (hell, dunkel, getönt), Startbildschirm, Logo in der App, Spielen-Knopf, Rockys Gesicht und `Design/Logo`.
- **Kampf:**
  - Die gelbe Umrandung des Ultimate-Felds in der Mana-Leiste ist weg; ist die Ultimate bereit, leuchten die gefüllten Felder weiter golden.
  - Die Karten des Gegners oben sind größer (36 statt 28 pt breit).
- **Flammen-Anzeige** ohne das kleine Eis-Abzeichen (der Flammenschutz steht in der Flammen-Statistik).
- **Neue Karte „Rückzug“** (Verteidigung, Gewöhnlich, **1 Mana, Bonusaktion**): Ein eigener Bauer weicht 1 oder 2 Felder zurück. Man tippt das Zielfeld an; der Weg muss frei sein, die eigene Grundreihe ist tabu, und im Bonuszug bleibt der Bauer stehen. Kartenschule-Lektion, Rocky-Spruch, gemaltes Kartenbild im Stil der übrigen Karten (Prompt in `Design/Kartenbilder/PROMPTS.md`, gezeichnete Fassung als Rückfall).
  - Kosten per Simulation (gleich starke Bots, Zufallsdecks, je Partie bekommt eine Seite Rückzug): 1 Mana → Siegquote-Δ −0,04 ± 0,09, ungenutzt in 32 % der Partien; 2 Mana → −0,09 ± 0,10. Mit 1 Mana ist die Karte fair, mit 2 zu schwach.
  - Regel-Version 3; Regeltests 49/49 (acht neue Fälle).
- **Bruno (Stufe 1) ist leichter:** neues Deck Verstärkung, Bollwerk, Sturmlauf, Rückzug (vorher Sturmlauf, Vormarsch, Verstärkung, Blitz). Im Simulator gewinnt Bruno mit dem neuen Deck nur 9 % gegen Bruno mit dem alten.
- **Kampf gegen Bots:** zufällige Extra-Denkzeit von 0–7 Sekunden pro Zug (meist kurz, manchmal lang), damit sich der Gegner wie ein Mensch anfühlt. Nach einer Bonuskarte und in den ersten Zügen höchstens 1,5 bzw. 2 Sekunden; mit Uhr nie mehr als ein Zwölftel der Restzeit.
- **Bot-Leiter:** ohne Uhr und ohne künstliche Denkpause.

## Neu in v0.9.33: Deck-Tab aufgeräumt, Rocky erklärt die Ultimates
- **Kein Minus mehr auf den Deckkarten.** Herausnehmen geht weiter per Tipp auf die Karte im Deck; nur beim Tauschen erscheint das goldene Tausch-Zeichen.
- **Sammlung:** Eine Karte, die schon im Deck liegt, wird beim Antippen nicht mehr herausgenommen. Stattdessen gibt es eine kurze Vibration, die Karte oben im Deck wackelt, und eine Notiz sagt „Schild ist schon in deinem Deck.“ (während Rockys Tour oben im Bild).
- **Knöpfe unter dem Deck:** Vorlagen · **Schule** · Testen. Die Kartenschule heißt auf dem Knopf kurz „Schule“ (mit Fortschritt, z. B. 3/19) und ersetzt den Ultimate-Knopf – die Ultimate wechselt man mit einem Tipp auf die Ultimate-Karte. Der Kartenschul-Knopf oben im Kopf entfällt.
- **Rockys Tour erklärt die Ultimates:** Nach dem Spotlight auf die eigene Ultimate („Jeder Zug lädt Mana, ab 8 – Festung ab 6 – zündest du sie statt eines Zugs; der Gegner sieht, welche du dabeihast“) zeigt Rocky alle fünf Ultimates zum Antippen. Zu jeder erzählt er, was sie tut und wann sie glänzt; gesperrte zeigen, ab welcher Arena es sie gibt. Freigeschaltete lassen sich direkt „ausrüsten“. Wer alle fünf angetippt hat, bekommt den Hinweis auf die Schule.

## Neu in v0.9.32: Rockys Deck-Werkstatt
Nach der ersten Partie erklärt Rocky (der grinsende Turm aus dem Logo) zum Mitmachen, wie man ein Deck baut und worauf es ankommt.
- **Einladung:** Zurück auf der Startseite springt Rocky ins Bild und lädt in seine Werkstatt ein. Warten noch Truhen, schickt er dich zuerst dorthin („Truhen öffnen“) – dann gibt es mehr Karten zur Auswahl – und meldet sich wieder, sobald alle offen sind. „Später“ fragt in dieser Sitzung nicht mehr; im Deck-Tab startet die Tour trotzdem von selbst.
- **Die Tour im Deck-Tab** (Rocky unten links mit Sprechblase, Text tippt sich ein, Fortschrittspunkte, jederzeit beendbar):
  1. **Hallo:** Der Bildschirm wird dunkel, nur die vier Deckplätze leuchten – „genau diese Karten hast du in jeder Partie auf der Hand“.
  2. **Karten wählen:** Eine Hand zeigt auf die erste Karte, alle freien Karten leuchten. Zu jeder gelegten Karte hat Rocky einen eigenen Spruch („Sturmlauf! Deine Bauern bekommen Raketenschuhe.“), dazu ein kleiner Funkenregen. Ein Rollen-Zähler (Angriff · Kontrolle · Verteidigung) leuchtet auf, sobald eine Rolle abgedeckt ist.
  3. **Rockys Deck-Check:** bis zu drei Sterne, die nacheinander hereinspringen – für Ø-Mana (höchstens 3), Rollen-Mix (alle drei Rollen) und schnellen Start (mindestens eine Karte für 2 Mana oder weniger). Dazu die Zahl der Bonusaktionen und Rockys Urteil.
  4. **Profi-Trick Tauschen:** Rocky schlägt einen konkreten Tausch vor (z. B. „Dir fehlt noch Verteidigung. Nimm Sturmlauf raus und hol dir Schild!“). Die vorgeschlagene Karte im Deck pulsiert rot, die neue leuchtet unten mit Zeigehand. Nach dem Tausch kommt eine neue Wertung („Besser! Von 2 auf 3 Sterne“).
  5. **Ultimate:** Spotlight auf die Ultimate-Karte.
  6. **Feier:** Konfetti, Rocky jubelt, das Deck fächert auf, **+20 Splitter** (nur beim ersten Mal). „Ab in den Kampf!“ startet direkt eine Partie.
- **Wiederholen:** Der kleine Rocky neben „Dein Kampfdeck“ startet die Tour jederzeit neu (ohne Belohnung).
- **Bestehende Spielstände:** Wer schon ein volles Deck hat, bekommt die Tour nicht automatisch.
- Neues Bild `RockyFace` (Rockys Gesicht aus dem Logo); neue Datei `UI/DeckTour.swift`.

## Neu in v0.9.31: Eigenes Deck bauen, Vormarsch teurer, Umwandlung ohne Schild
- **Deck selbst zusammenstellen (wie bei Clash Royale):** Neue Spieler starten mit einem **leeren Deck**.
  - Im Deck-Tab: Karte unten antippen → sie kommt auf den nächsten freien Platz. Karte im Deck antippen → sie fliegt raus. Ist das Deck voll, startet das Antippen einen Tausch (dann den Platz wählen).
  - Leere Plätze erscheinen als gestrichelte „+ Platz n“-Felder, auch im Deck-Fächer auf dem Startbildschirm und in der Hand während der Partie.
  - Ein Banner sagt, wie viele Karten noch fehlen.
  - Bestehende Spieler behalten ihr Deck.
- **Spielen nur mit vollem Deck (4 Karten):**
  - Statt „KAMPF“ zeigt der Startbildschirm dann den blauen Knopf **„DECK BAUEN“** bzw. **„DECK FERTIG BAUEN“** mit vier Platz-Balken. Er führt direkt in den Deck-Tab.
  - Der Deck-Tab trägt einen Punkt, solange Karten fehlen.
  - Bot-Leiter: Statt „Herausfordern“ erscheint „Deck fertig bauen (n/4)“.
  - Jeder andere Startweg (Übungsspiel, „Testen“ im Deck) ist gesperrt und erklärt per Hinweis, was fehlt.
- **Vormarsch 2 → 3 Mana** (bleibt Bonusaktion). Simulation, je 270 bzw. 180 Partien gleich starker Bots mit Zufallsdecks:
  | Variante | gespielt pro Partie | Siegquote-Δ mit Karte |
  |---|---|---|
  | bisher (2 Mana, Bonus; v0.9.26) | 2,9 | +0,10 |
  | **3 Mana, Bonus (übernommen)** | 2,0 | +0,03 |
  | 2 Mana, keine Bonusaktion | 0,3 | −0,09 (Karte wird nutzlos) |
- **Umwandlung:** Ein Bauer mit Schild, Bollwerk oder Festung verliert den Schutz, sobald er sich umwandelt – die neue Figur ist ungeschützt.
- **Regel-Version 2** (Kosten und Umwandlung geändert); Regeltests 41/41 gleich in Swift-Fassung und JS-Port, zwei neue Fälle.

## Neu in v0.9.30: Schatzkammer und Bot-Leiter-Turm
- **Schatzkammer (Truhen-Fenster):** öffnet sich über den Truhen-Kopf, leere Siegplätze oder die Tagestruhe. Goldglühender Hintergrund mit Funkeln, oben eine Legendäre Truhe vor Strahlen.
  - *Siegtruhen heute:* drei Steinpodeste – wartende Truhen wackeln vor Lichtstrahlen und lassen sich direkt öffnen, der nächste Platz ist golden gestrichelt.
  - *Tagestruhe:* große Goldtruhe im wachsenden Zielring, Tagesziele mit goldenen Haken und „Los“-Knöpfen, Öffnen-Knopf mit Glanz.
  - *Im Lager:* alle wartenden Truhen im Raster, jede mit Leuchthof und direktem Öffnen.
  - *Truhenarten:* Holz bis Legendär nebeneinander, mit kurzer Erklärung.
- **Bot-Leiter-Fenster:** Nachthimmel mit Sternen, Fortschrittsring mit Krone. Oben das Duell „Du gegen den nächsten Bot“ – der Bot im Scheinwerfer mit Strahlen, dazwischen „VS“, darunter Sprechblase, Deck, Figurenset und Herausfordern-Knopf. Darunter ein **Turm aus Stein** mit Zinnen: zwölf Stockwerke, verbunden durch Leitern, die golden werden, sobald du hinaufgeklettert bist; besiegte Stockwerke tragen eine Fahne in der Bot-Farbe, das aktuelle leuchtet.
- **Behoben:** In v0.9.29 fehlte versehentlich das Tagestruhen-Fenster im Code (Build-Fehler). Es ist jetzt Teil der Schatzkammer.

## Neu in v0.9.29: Truhen und Bot-Leiter mit mehr Spaß
- **Truhen als Schatzkiste:** Holzmaserung, goldener Beschlag mit Nieten in den Ecken und funkelnder Goldstaub. Im Kopf wippt eine Goldtruhe, daneben drei kleine Pokale für die heutigen Siegtruhen.
  - Noch nicht gewonnene Siegtruhen sind Schatten-Truhen mit Schloss; der **nächste Platz** ist golden gestrichelt, leuchtet und heißt „Nächster Sieg“.
  - Gewonnene Truhen wackeln und hüpfen vor drehenden Lichtstrahlen, mit goldenem „Öffnen!“-Schild; geöffnete sind ausgegraut mit Haken.
  - Die Tagestruhe sitzt im goldenen Ring der Tagesziele; bereit mit Strahlen und Wackeln, danach Mond und Countdown.
  - „Weitere Truhen bereit“ mit wackelnder Truhe und glänzendem Öffnen-Knopf.
- **Bot-Leiter:** Banner-Streifen in der Farbe des nächsten Gegners, leuchtender Ring um den Bot mit „VS“-Abzeichen, Belohnung als Chip (XP und Truhe) und eine **Treppe aus zwölf Stufen**, die in den Farben der besiegten Bots hinaufwächst – die nächste Stufe golden umrandet, oben die Krone.

## Neu in v0.9.28: Spielen-Tab ohne Lücke, Animationen sofort beim Tab-Wechsel
- **Spielen-Tab:** Die Lücke zwischen Truhen und Kacheln ist weg. Übriger Platz geht jetzt in die Kampf-Bühne (Avatar und Deck stehen mittig darin). Auf großen iPhones sind Avatar (108 statt 86 Punkte), Deck-Karten und Kampf-Knopf größer.
- **Tab-Wechsel:** Der neue Tab animiert sofort, der alte läuft weiter, bis er hinausgeglitten ist, und wird erst danach angehalten. So läuft nie mehr als ein Tab dauerhaft – nur während des Wechsels kurz zwei.

## Neu in v0.9.27: Neues Logo
- **App-Symbol** (1024 × 1024) in drei Fassungen: normal, dunkel (für den dunklen Home-Bildschirm, etwas abgedunkelt mit kräftigerer Glut) und getönt (Graustufen, iOS färbt ein).
- **Startbildschirm des Systems** (`LaunchLogo`, 140 pt in 1×/2×/3×, abgerundet).
- **`AppLogo`** – das ganze Logo für Ladebildschirm und Abschluss der ersten Schlacht (abgerundetes Quadrat).
- **`Logo`** – Ausschnitt mit Turm und Karten für alle runden Stellen: Spielen-Knopf in der Tab-Leiste, Level-Abzeichen, Rockys Tipps, Kartenschule, Hinweise im Tutorial.
- Ladebildschirm farblich angepasst: Glut in Orange, Karten in Gold und Rot, Ladebalken Rot → Gold.
- Quelldateien unter `Design/Logo/` (Original 512 px, hochskaliert 1024 px, Übersicht aller Fassungen).

## Neu in v0.9.26: Kartenschule, Bollwerk 2, flüssigere Tabs, Online-Vorbereitung
- **Kartenschule (Deck-Tab, oben „Kartenschule“, oder „Ausprobieren“ im Kartenfenster):** Zu jeder der 14 Karten und 5 Ultimates gibt es eine kleine Stellung zum Selbstausprobieren – mit der echten Spiel-Engine.
  - Rocky erklärt den Auftrag, die Karte leuchtet; antippen, Ziel wählen (das empfohlene Feld pulsiert golden), Effekt wie im Spiel.
  - Bonusaktionen: danach noch ein Figurzug (Vorschlag als goldener Pfeil). Was die Karte verhindert, zeigt ein durchgestrichener roter Pfeil („Abgeprallt!“, „steckt im Eis fest“).
  - Schwarz antwortet, oft folgt ein Abschlusszug – bei Meteor, Eiszeit, Krönung und Wiederkehr ein echtes Matt.
  - Zum Schluss Konfetti, drei Merksätze, „Nochmal“ oder „Nächste Karte“. Fortschritt (geschafft/gesamt) oben und im Deck-Tab; gesperrte Karten lassen sich auch ausprobieren.
  - Alle 19 Stellungen sind mit dem Regel-Port geprüft (Ziele gültig, Antworten legal, Matts echt).
- **Bollwerk kostet 2 Mana** (vorher 1). Simulation (300 Zufallspartien): 2,1 statt 3,2 Einsätze pro Partie, Siegeinfluss −0,02 statt +0,08.
- **Tab-Leiste:** Spielen-Knopf kleiner (48 statt 56 Punkte). Aktiv: goldene Scheibe mit Strahlen, goldener Balken unter der Schrift; inaktiv: dunkler Knopf mit Goldring, gedämpfter Rocky, graue Schrift. Die anderen Tabs zeigen zusätzlich einen blauen Balken.
- **Flüssigere Tab-Wechsel:** Animationen eines Tabs starten und stoppen erst nach der Seitenbewegung; „neue Karten gesehen“ wird danach gespeichert statt mitten im Wischen; die Erfolge (für die Tab-Abzeichen) werden zwischengespeichert, statt bei jedem Wechsel den ganzen Partieverlauf durchzurechnen.
- **Online-Vorbereitung (ohne Server):**
  - **Regeln als Daten:** Alle Kosten, Abklingzeiten, Ultimate-Kosten und Mana-Werte kommen aus `Engine/rookraid-rules.json` (Regel-Version 1). Neuere Regeln vom Server lassen sich später ohne App-Update übernehmen.
  - **Aktionen im Draht-Format** (`e2e4`, `card:freeze@f6`, `ult:meteor@d8`) mit Regelprüfung, dazu das Partieprotokoll `MatchRecord` (Regel-Version, Decks, Ultimates, Aktionen) zum Nachspielen auf jedem Gerät oder Server.
  - **Regeltests:** 39 Fälle (Kartenschule, Kosten, Blitz-Hälfte, Abklingzeit, Festung, Rochade, en passant, Umwandlung, Matt, Patt). Erwartungen kommen aus dem JavaScript-Regel-Port in `Tools/rules-js`; die App prüft sie im Debug-Build unter Einstellungen → Entwickler.
  - **Testmodus „alle Karten frei“** nur noch in Debug-Builds.
  - **Gast-ID, Spielerkarte, Fortschritts-Abzug** für die Konto-Übernahme und die **Schnittstelle der Gegnersuche** (lokal: Bot-Ersatz) in `Services/Online.swift`.
  - **Backend-Entwurf** in `Backend/`: Datenbankschema mit Zugriffsregeln (Profile, Fortschritt, Gegnersuche, Partien, Aktionen, Regeln, Bestenliste) und Edge-Function-Gerüst zur Zugprüfung.

## Neu in v0.9.25: Leistung
Nichts am Spiel oder an den Animationen fällt weg – es wird nur weniger doppelt gerechnet und gezeichnet.
- **Schachuhr eigenständig:** Die Uhr tickt 10-mal pro Sekunde. Bisher hat jedes Ticken das ganze Spielfenster (Brett, Hand, Leisten) neu berechnet; jetzt aktualisieren sich nur die beiden Uhr-Anzeigen.
- **Keine Profil-Änderung pro Zug:** Karten-, Bonus-, Ultimate- und Taktik-Zähler sammelt die Partie und schreibt sie am Ende (oder beim Verlassen) in einem Rutsch ins Profil. „Partie gespeichert“ meldet sich nur noch bei einer echten Änderung. Vorher bauten sich nach jedem Zug alle fünf Tabs hinter dem Spiel neu auf.
- **Spielen-Tab:** statt drei gleichzeitig aufgebauter Fassungen (ViewThatFits) entscheidet die verfügbare Höhe über groß oder kompakt. Gescrollt wird nur, wenn es nicht passt; dann federt die Seite auch nur dann.
- **Kartenbilder:** Die gemalten Bilder werden nach dem Start im Hintergrund dekodiert; kleine Darstellungen (Deck-Fächer, Leisten, Leiter) nutzen eine verkleinerte Fassung (180 × 225 statt 600 × 750 Pixel). Der erste Blick auf Deck oder Truhen ruckelt nicht mehr.
- **Animationen gedrosselt, wo man es nicht sieht:** Wackeln läuft mit höchstens 30 bzw. 60 statt bis zu 120 Bildern pro Sekunde, das langsame Leuchten mit 20 statt 30.

## Neu in v0.9.24: Blitz als Konter, Spielen-Tab ohne Scrollen, Bretter in der Garderobe
- **Blitz überarbeitet:** trifft nur noch gegnerische Bauern, die **in deine Hälfte vorgerückt** sind (Weiß: Reihen 1–4, Schwarz: Reihen 5–8). Die Bauernkette des Gegners zu Hause bleibt sicher; Blitz wird zum Konter gegen Vormarsch, Sturmlauf und Freibauern. Kosten bleiben 2, die Abklingzeit steigt auf **3 eigene Züge** (alle anderen Karten 2).
  - Simulation (300 Zufallspartien): Blitz wird 0,44-mal pro Partie gespielt statt 2,19-mal, in 71 % der Partien gar nicht. Siegeinfluss −0,06 ± 0,10 (vorher −0,03) – im Rahmen.
  - Die drei Blitz-Puzzles mit Bauern in der gegnerischen Hälfte sind angepasst (Bauer jetzt auf a3, b4, c4); alle Rook-Raid-Puzzles sind wieder geprüft.
- **Spielen-Tab passt auf einen Bildschirm:** Kopfzeile, Arena-Bühne, Truhen und darunter zwei halbe Kacheln (Bot-Leiter und Rockys Tipp). Ist der Bildschirm knapp (z. B. iPhone SE oder mit „Partie fortsetzen“), schaltet die Seite automatisch in eine kompakte Fassung; nur wenn auch die nicht passt, wird gescrollt.
- **Kampf-Bühne bereit für Online:** kein „Du vs. Bot …“ mehr. Stattdessen stehst du mit deinem Avatar auf einem Podest in Arenafarbe, daneben dein Deck als Fächer mit Ultimate und Ø-Mana. Unter „KAMPF!“ steht „Gegner mit ähnlich vielen Trophäen“ und die Uhr/Farbe (Tippen öffnet die Einstellungen).
- **Brett-Designs in der Garderobe:** neuer Reiter „Bretter“ mit Vorschau (König aus deinem Figurenset auf dem Brett), Kauf der Sammelbretter mit Bestätigung. Die Bühne der Garderobe zeigt dein Figurenset jetzt auf einer Reihe deines Bretts. In den Einstellungen steht nur noch ein Hinweis; der Sammelring „Bretter“ im Profil öffnet direkt den neuen Reiter.

## Neu in v0.9.23: Festung ab 6 Mana, Leibwache 4, obere Bots neu abgestimmt
- **Festung:** schon ab **6 Mana** einsetzbar und verbraucht 6 (alle anderen Ultimates bleiben bei 8). Die goldene Marke in der Mana-Leiste rückt bei der Festung auf 6. Der Bonuszug danach bleibt ohne Schlagen und ohne Schach.
- **Leibwache:** kostet jetzt 4 Mana (vorher 3), bleibt eine Bonusaktion.
- **Bots 7–12 – mehr Rechenzeit und Stellungen pro Zug:**

  | Bot | Suchtiefe | Stellungen/Zug | Denkzeit max. | Deck | Ultimate |
  |---|---|---|---|---|---|
  | 7 Nox | 5 (70 %) | 700 000 (vorher 480 000) | 2,2 s (1,9) | Frost, Blitz, Vormarsch, Sturmlauf | Meteor |
  | 8 Baron Rabe | 5 (80 %) | 800 000 (600 000) | 2,4 s (2,2) | Frost, Vormarsch, Schild, Konzentration | Festung |
  | 9 Viktor | 5 | 1,2 Mio. (800 000) | 3 s (2,4) | Frost, Vormarsch, Schild, Konzentration | Wiedergeburt |
  | 10 Magnus Frost | 6 | 2 Mio. (1,1 Mio.) | 4,5 s (2,7) | Frost, Vormarsch, Schild, Konzentration | Eiszeit |
  | 11 Die Sphinx | 7 | 3 Mio. (1,8 Mio.) | 6 s (3,2) | Frost, Vormarsch, Konzentration, Sturmlauf | Wiedergeburt |
  | 12 Die Turmkönigin | 8 | 4,5 Mio. (2,4 Mio.) | 8 s (4) | Frost, Vormarsch, Leibwache, Konzentration | Eiszeit |

  Mit Schachuhr denkt ein Bot höchstens ein Zwanzigstel seiner Restzeit plus 80 % des Inkrements – er verliert also nicht auf Zeit.
- **Simulation** (Bericht: `Design/Simulation/v0.9.23-Bericht.md`): Leiter 6→12 mit den neuen Profilen und Decks, Deck-Turnier mit gleicher Suchstärke (10 Decks), Karten-Check mit 320 Zufallspartien.

## Neu in v0.9.22: Festung entschärft, Vormarsch und Leibwache teurer, große Simulation
- **Festung:** Der Bonuszug nach der Festung darf nicht schlagen und kein Schach oder Matt geben. Das Bonus-Banner sagt es an („Noch ein Zug – ohne Schlagen und ohne Schach“).
- **Kosten:** Vormarsch 1 → 2, Leibwache 2 → 3 (beide bleiben Bonusaktionen).
- **Simulation** (Bericht: `Design/Simulation/v0.9.22-Bericht.md`): 400 Partien mit Zufallsdecks für alle Karten und Ultimates, dazu alle zwölf Bots gegen den nächststärkeren mit ihren Decks (207 Partien) und Kontrollpartien mit gleichem Deck (38).
  - Keine Karte liegt deutlich außerhalb; alle werden gespielt (höchstens 19 % der Partien ungenutzt im Deck).
  - Bots 1–6 (Bruno bis Frieda Falk) werden sauber stärker. Ab Frieda Falk steigt die Stärke kaum noch – siehe Bericht.

## Neu in v0.9.21: Ultimate ab 8 Mana, neue Kosten, drei Karten überarbeitet
Grundlage: Simulator mit gut 1.900 Bot-Partien (gleich starke Bots, Zufallsdecks und -Ultimates).
- **Ultimate ab 8 Mana:** Der Balken hat weiter 10 Felder, das 8. trägt eine goldene Marke. Ab 8 Mana ist die Ultimate bereit (die gefüllten Felder leuchten golden); sie verbraucht 8 Mana, der Rest bleibt. Mit der neuen +1-Regel kamen Ultimates sonst zu spät (Median erst im 17. Zug, 40 % der Spieler zündeten nie eine).
- **Kosten:** Wiederkehr 8 → 6, Sturmlauf 4 → 3, Blitz 1 → 2.
- **Blitz:** trifft jetzt jeden gegnerischen Bauern, nicht nur ungedeckte – nur Schild und Bollwerk schützen ihn. Vorher lag Blitz in 53 % der Partien ungenutzt im Deck, jetzt in 12 %.
- **Vormarsch** und **Leibwache** sind jetzt Bonusaktionen (danach noch ein Figurzug). Vorher ungenutzt in 75 % bzw. 55 % der Partien, jetzt in 2 % bzw. 4 %.
- Regeln, Kartentexte, Hinweise, Tutorial-Tipp und Übersetzungen angepasst.
- Beobachten: Mit den drei neuen Bonusaktionen werden Partien kürzer (im Simulator Ø 56 statt 72 Halbzüge), dadurch gibt es wieder weniger Ultimates pro Partie. Leibwache und Vormarsch liegen in der Siegwirkung leicht vorn – noch innerhalb der Messunsicherheit.

## Neu in v0.9.20: Neue Mana-Regel, aufgeräumtes Deck, Figurensets zum Freischalten
- **Mana-Regel vereinfacht:** Jeder Zug bringt +1 Mana, ein guter Zug (Schlagen, Schach oder Taktik) nochmal +1 – höchstens +1 extra pro Zug. Gebiet bringt kein Mana mehr; die Tönung des Gebiets auf dem Brett bleibt (abschaltbar in den Einstellungen).
  - Der blaue Gebietsbalken unter der Mana-Leiste und die Gebietsanzeige in der Gegnerleiste sind weg. Die zehn Gebiets-Puzzles und die Puzzle-Gruppe „Gebiet“ sind entfernt; Regeln, Willkommensseiten, Rockys Tipps und die erste Schlacht sind angepasst.
  - Mit dem frei gewordenen Platz zeigt die Gegnerleiste die Karten des Gegners groß: echte Mini-Karten mit Bild, Kosten, Abklingzeit und Bonuszug-Zeichen, davor seine Ultimate, die sich mit seinem Mana füllt. Antippen zeigt die Karte groß.
  - Hinweis: Mana kommt jetzt langsamer – teure Karten und die Ultimate kommen später. Bitte beim Spielen darauf achten, ob sich das gut anfühlt.
- **Deck-Tab aufgeräumt:** oben angeheftet das Kampfdeck mit Steckbrief und drei Knöpfen (Vorlagen, Ultimate, Testen); darunter die Sammlung als ein Raster mit Filter nach Rolle; Hinweise erscheinen kurz als Blase unten; beim Tauschen steht die Anleitung direkt am Deck.
- **Figurensets freischalten:** Besiegst du einen Bot (Leiter oder Kampf), gehört dir sein Figurenset. Du wählst es im Profil und spielst dann mit diesen Figuren; nach dem Sieg meldet das Ergebnisfenster „Neues Figurenset“.
- **Garderobe statt „Avatar, Rahmen & Titel“:** im Stil des Splitter-Ladens – Bühne mit Avatar, Titelband und deinem Figurenset, Sammlungsfortschritt, Reiter für Avatare, Rahmen, Titel und Figuren mit großen Kacheln, die zeigen, wie man etwas bekommt.
- **Erste Schlacht:** Die Karte, die dran ist, bekommt ein umlaufendes Lichtband, hebt sich leicht an und leuchtet; darüber zeigt eine hüpfende Hand „Tippen“. Die anderen Karten treten zurück. Das gelbe, schwingende Rechteck ist weg.
- **Kleinigkeiten:** Spielen-Knopf in der Tab-Leiste kleiner (ragt weniger heraus); Trophäen im Pfad-Kopf werden nicht mehr abgeschnitten; Pfad und Profil haben Kopf-Symbole im Stil von Puzzles und Deck.
- **Flüssiger:**
  - Die Bots berechnen in ihrer Suche keine Gebietskarte mehr (die war in jeder bewerteten Stellung nötig) – sie denken spürbar schneller.
  - Versteckte Tabs und alle Tabs hinter einer laufenden Partie oder einem Puzzle zeichnen keine Animationen mehr.
  - Die Gebietskarte im Spiel wird nur noch berechnet, wenn die Tönung eingeschaltet ist.
  - Weitere Endlos-Animationen im Spiel (Schloss, Bonuszug-Banner, Aufgaben-Orden, Brett-Hinweise) laufen jetzt über Zeitleisten.

## Neu in v0.9.19: Tab-Leiste repariert, Pfad, Profil und Spielen neu
- **Tab-Leiste repariert:** Seit v0.9.16 stand die Leiste mitten auf dem Bildschirm und die Seiten waren abgeschnitten. Ursache war der unsichtbare Platzhalter für den Spielen-Knopf, der sich in die Höhe ausdehnte; er hat jetzt eine feste Höhe.
- **Neue Karten aus Truhen mit gemaltem Bild:** Die Karten-Enthüllung zeigt das gemalte Kartenbild randlos mit Namen und Rolle. Auch die letzten Symbol-Leisten (Vorlagen, Gegnerhand im Kampf, Duell-Intro) zeigen jetzt Kartenbilder.
- **Pfad-Tab:** sechs Landschaften (Hügel und Tannen, Wachtürme, Säulen mit Bannern, Gewitter mit Blitzlicht, Lava, Schneeberge), jede mit eigenen Teilchen (Glühwürmchen, Staub, Funkeln, Regen, Glut, Schnee).
  - Der goldene Weg funkelt in deiner Arena; Arena-Tore als Burgmauer mit Zinnen und flatternden Wimpeln.
  - Gegner am Weg als Königsfigur ihres Figurensets, noch nicht erreichte als Schatten mit Fragezeichen; ganz oben wartet die Turmkönigin.
  - Bereite Truhen wackeln und hüpfen, gesperrte Belohnungen zeigen beim Antippen „noch X Trophäen“.
  - Oben eine Weltkarte der sechs Arenen (antippen springt hin), unten rechts „Zu mir“.
- **Profil-Tab:**
  - Spielerkarte mit Lichtstrahlen, XP-Ring um den Avatar, Titel auf einem goldenen Band und funkelndem Hintergrund.
  - Ruhmeshalle mit hochzählenden Zahlen (Siege, Puzzles, Erfolge, aktive Tage).
  - Bot-Bezwinger: die zwölf Bots als Königsfiguren; bezwungene mit Krone, der nächste pulsiert, „Zur Leiter“ öffnet die Bot-Leiter.
  - Sammelringe für Karten, Ultimates, Avatare, Rahmen und Bretter; Erfolge in einer Vitrine; Statistik mit der Form der letzten Partien.
- **Spielen-Tab:**
  - Die Kampfkarte steht in der Landschaft deiner Arena.
  - Duell „Du gegen den nächsten Gegner“ mit seiner Königsfigur, seinem Motto und einem pulsierenden VS.
  - Dein Deck als aufgefächerte Hand, ein leuchtender Kampf-Knopf mit „+30 Trophäen“, neue Truhen- und Leiter-Karte.
  - Rockys Tipps zum Durchtippen.
- **Bot-Porträts:** Überall, wo ein Bot erscheint (Leiter, Duell-Intro, Ergebnis, Statistik), zeigt er den König seines Figurensets statt eines Symbols.
- **Ruhigere Animationen:** Auf den drei neuen Tabs, in den Truhen-Plätzen und beim Lichtstreifen der Knöpfe laufen Hüpfen, Wackeln und Pulsieren über Zeitleisten statt über Endlos-Animationen.

## Neu in v0.9.18: Gemalte Kartenbilder
- **Alle 19 Kartenbilder gemalt:** 14 Karten und 5 Ultimates zeigen jetzt die gemalten Cartoon-Bilder – in der Hand im Kampf, in der Ansage beim Ausspielen, im Deck, im Laden, in Vorlagen und in den Deck-Leisten. Die Ultimates laden weiter sichtbar (grau, füllen sich mit Mana).
- **Zuschnitt je Karte:** auf das Kartenformat 4:5, bei kleinen Motiven etwas enger (Frost, Blitz, Krönung, Bauernopfer …), damit sie auch in der Hand gut erkennbar sind; beim Meteor ist der gemalte Goldrahmen abgeschnitten. Festgelegt in `Design/Kartenbilder/zuschnitt.json`.
- **Ablage:** als JPEG im Asset-Katalog (`Assets.xcassets/CardArtPainted`, 600 × 750, zusammen rund 2 MB). Die gezeichneten Vektorbilder bleiben als Rückfall. `einbauen.py` schreibt jetzt dorthin; der Ordner `RookRaid/CardArt/` entfällt.

## Neu in v0.9.17: Platz für gemalte Kartenbilder
- **Gemalte Bilder einbauen:** Liegt ein gemaltes Bild `painted-art-card-<schlüssel>` (bzw. `painted-art-ult-<schlüssel>`) vor (ab v0.9.18 im Asset-Katalog), zeigt die App es statt des gezeichneten – überall, wo Kartenbilder erscheinen. Fehlende Bilder fallen auf das gezeichnete zurück, man kann also Karte für Karte austauschen. Bilder werden auf 4:5 zugeschnitten angezeigt.
- **Prompts und Skript:** `Design/Kartenbilder/PROMPTS.md` enthält Stil-Block und Szenen für alle 19 Bilder; `Design/Kartenbilder/einbauen.py <Ordner>` schneidet generierte Bilder zu, benennt sie und legt sie in die App.

## Neu in v0.9.16: Kartenbilder, neue Tab-Leiste, Flammen- und Puzzle-Bereich
- **Kartenbilder statt Symbole:** Alle 14 Karten und 5 Ultimates haben ein eigenes Bild (Vektor, `Assets.xcassets/CardArt`) – im Deck, in der Hand im Kampf, im Laden, in Vorlagen, in der Karten-Ansage beim Ausspielen und in den Deck-Leisten von Startseite und Leiter. Hintergrundfarbe nach Rolle, Rahmen nach Seltenheit.
  - Ultimates laden sichtbar: Das Bild ist grau und füllt sich mit dem Mana von unten mit Farbe; voll glänzt und pulsiert es.
  - Quelle: `Design/Kartenbilder/kartenbilder.py` erzeugt alle Bilder neu.
- **Tab-Leiste neu:** Pfad · Puzzles · **Spielen** · Deck · Profil. „Spielen“ ist ein großer goldener Rundknopf mit Rocky in der Mitte, ragt über die Leiste, pulsiert und bekommt einen Strahlenkranz, wenn er aktiv ist. Die App startet weiter auf „Spielen“; Wischen folgt derselben Reihenfolge.
- **Flammen-Fenster:**
  - Repariert: Der untere Teil schwang hin und her. Ursache war eine Endlos-Animation, die beim Öffnen das ganze Fenster erfasste; die Flamme flackert jetzt über ihre eigene Zeitleiste.
  - Neu: gezeichnete, flackernde Flamme mit aufsteigender Glut und der Serienzahl darin; Flammenstufen Funke (1) · Lagerfeuer (7) · Blaue Flamme (30) · Inferno (100) · Ewige Flamme (365) mit eigenen Farben; Wochenleiste mit sieben Fackeln; „Jetzt entzünden – Puzzle lösen“ springt direkt in den Puzzle-Tab.
- **Splitter-Laden:** Die Leuchtkapsel der Reiter blieb manchmal hängen oder sprang an die falsche Stelle (wanderndes Element). Jetzt leuchtet jede Kapsel für sich.
- **Puzzle-Tab neu:** großes „Nächstes Puzzle“ mit schwebendem Mini-Brett der echten Stellung, Sternen, XP und „LOS GEHT'S“; fünf Puzzleteile bis zur Rätseltruhe; Tagespuzzle (Gold, mit Mini-Brett) und Puzzle-Rausch (Blitz) als große Karten; Kategorien als farbige Abenteuer-Kacheln mit Krone, wenn alles gelöst ist.
- **Deck-Tab übersichtlicher:** Kampfdeck auf einer leuchtenden Matte mit Steckbrief (Ø Mana, Bonusaktionen, Rollen als Farbpunkte); Sammlung nach Rollen in farbigen Abschnitten mit Fortschritt; Karten im Deck tragen ein „IM DECK“-Band statt blass zu werden.

## Neu in v0.9.15: Figurensets der Bots, Rocky-Variationen
- **Jeder Bot spielt mit eigenem Figurenset** (Kampf, Leiter, Übung und Mila in der ersten Schlacht). Zwölf Sets mit je sechs Figuren in hell (Bot hat Weiß) und dunkel (Bot hat Schwarz), als Vektorgrafik (144 PDFs unter `Assets.xcassets/Skins`):
  - Bruno · Grüner Hain (Holz, Blätter, Keimling-Bauern) · Lotte · Bibliothek (Linienpapier, Bücher, Doktorhut) · Mila · Sternenzauber (Funkelsterne, Zauberhut) · Kasimir · Harlekin (Rauten, Narrenkappen) · Sir Konrad · Silberwacht (Stahl, Wappen, Visier, Federbusch) · Frieda Falk · Falkenauge (Federmuster, Fadenkreuz)
  - Nox · Mitternacht (Sternenhimmel, Kapuzen mit Glutaugen) · Baron Rabe · Rabenfeste (Mauerwerk, Rabenfedern) · Viktor · Glutriss (glühende Risse, Hörner) · Magnus Frost · Ewiges Eis (Eiszapfen, Schneekappen) · Die Sphinx · Wüstenorakel (Gold und Lapislazuli, Kopftuch) · Die Turmkönigin · Goldene Krone (Gold, Rubine, Krönchen)
  - Der König des Sets ersetzt in der Spielerleiste das CPU-Symbol; geschlagene Figuren erscheinen im Set des Bots.
  - Bot-Leiter: Unter dem Deck des nächsten Gegners steht sein Figurenset.
  - Einstellungen: „Bots mit eigenem Figurenset“ (an), zum Abschalten.
  - Quelle: `Design/Figurensets/figurensets.py` erzeugt alle Figuren neu (SVG → PDF).
- **Rocky-Variationen** (nur Design, im Ordner `Design/Rocky-Variationen`): Minimal, Emblem, Cool Rocky, Jubel-Rocky, Kriegsturm.

## Neu in v0.9.14: Neues Maskottchen „Rocky“
- **Neues App-Symbol und Logo:** Ein blauer Turm mit frechem Grinsen stemmt sich aus einer aufgerissenen Spielkarte, dahinter eine rote Karte, Hintergrund blau-rot geteilt wie bisher. Der lila Mana-Tropfen bleibt in der Kartenecke. Ersetzt das Springer-Kartenlogo in App-Symbol (hell, dunkel, getönt), Startbildschirm, Ladebildschirm und Abschluss der ersten Schlacht.
- **Ergebnisfenster:** Der Knopf „Öffnen“ bei den Truhen ist weg – die Truhen öffnen sich nach der Partie ohnehin von selbst.

## Neu in v0.9.13: Direkt weiter, Truhen sofort, neuer Laden
- **„Nächstes Spiel“ / „Gegen ‹Bot› kämpfen“ repariert:** Ursache war, dass die Startseite die laufende Partie ersetzte, während deren Vollbild noch offen war – SwiftUI schloss die alte Partie, öffnete die neue aber nicht. Jetzt tauscht ein Träger im Vollbild nur die Partie aus (sanfte Überblendung, kein Umweg über die Startseite).
- **Truhen öffnen sich direkt nach der Partie:** Sie fallen ins Ergebnisfenster und öffnen sich nach gut einer Sekunde von selbst – nur die Truhen dieser Partie, ältere bleiben im Lager.
  - Vor jeder Truhe ein Vorspann mit Grund: Abzeichen mit Symbol, „FÜR DEINEN SIEG!“, „ALLE TAGESZIELE GESCHAFFT!“, „SIR KONRAD BESIEGT!“, „LEVEL 5 ERREICHT!“, „NEUE ARENA: …“ – mit Strahlen, Funken, Beben und Klang. Ein Tipp überspringt.
  - Sind durch die Partie alle Tagesziele erfüllt, kommt die Tagestruhe gleich mit.
- **Ergebnisfenster ohne Scrollen:** etwas kompakter (Avatare, Band, Abstände) und es misst seine Höhe – passt es nicht, wird es passend verkleinert (iPhone SE bis Pro Max).
- **Splitter-Laden neu:**
  - Oben die Schatzkammer: schwebender Kristall, Stand, Sparziel mit Vorschau, Balken und „Holen“-Knopf, sobald es reicht.
  - Reiter statt langer Liste: Angebote · Karten · Truhen · Style · Extras.
  - „Angebot des Tages“ als große Karte mit Strahlen, darunter Kacheln: Vorschau auf Seltenheitsfarbe, Rabatt-Sticker, Stern fürs Sparziel, Preis-Knopf mit Glanz – und ein Balken, wie viele Splitter noch fehlen.
  - Karten, die du schon kaufen kannst, stehen vorn. Nach dem Kauf: „GEHÖRT DIR!“ mit Konfetti und Strahlen, Truhen öffnen sich sofort.
- **Flüssiger:** Beim Truhen-Öffnen zeichnen unsichtbare Lichtstrahlen und die Partikel-Ebene ohne Partikel nicht mehr in jedem Bild neu (bisher liefen dort drei Ebenen dauerhaft mit 60–120 Bildern pro Sekunde). Aussehen unverändert.

## Neu in v0.9.12: Ruhiges Deck, neue erste Schlacht, klares Ergebnisfenster
- **Deck-Tab:** Die Deckkarten hören nach dem Abwählen sofort auf zu wackeln. Das Wackeln wird jetzt aus der Uhrzeit berechnet und stoppt zuverlässig (vorher lief eine Endlos-Animation weiter).
- **Vorlagen-Fenster:** Die vier Karten stehen oben im Bogen, die Ultimate frei darunter – nichts überdeckt sich mehr.
- **Erste Schlacht neu – Mila spielt vernünftig:** Zweispringerspiel aus dem Lehrbuch (e4 e5, Sf3 Sc6, Lc4 Sf6, Sg5 d5, exd5 Sxd5), danach wählt Mila jeweils den besten Zug, den die Engine ohne Wissen über deine Karten findet. Sie verliert, weil sie die Karten nicht kommen sieht – nicht wegen sinnloser Züge.
  - Ablauf: Schlagen auf d5 · Schild auf den bedrohten Springer g5 + Bonuszug Dame f3 (Mila deckt f7 mit Le6) · Meteor auf den Turm h8 (der ungeschützte Bauer h7 friert ein, Mila greift die Dame mit Sd4 an) · Frost auf den Verteidiger e6 + Dame schlägt f7 matt.
  - Mit der Engine geprüft: jeder Zug legal, Matt am Ende, Milas Antworten sind Lehrbuch- bzw. Bestzüge.
  - Vor Meteor und Frost füllt das Tutorial die Mana-Leiste auf. Der Profi-Tipp am Ende erklärt jetzt den Blitz.
- **Ergebnisfenster vereinfacht:** höchstens drei Knöpfe.
  - Kampf: **Nächstes Spiel** (neuer Gegner passend zu den Trophäen), Revanche, Zum Menü.
  - Bot-Leiter nach einem Sieg: **Gegen ‹nächster Bot› kämpfen**, Revanche, Zum Menü. Nach einer Niederlage: Nochmal versuchen, Zum Menü.
  - „Brett ansehen“ und „Nachspielen“ sind weg – beides gibt es im Verlauf.

## Neu in v0.9.11: Zwölf stärkere Bots, neue Meteor-Regel
- **Kampf-Layout:** Die Hinweis-Blase hat einen festen Platz direkt unter den Karten und verdeckt nichts mehr. Das Brett richtet seine Größe danach, damit Karten und Blase auf jedem iPhone vollständig passen (SE bis Pro Max).
- **Ausgewählte Karte:** wird nicht mehr angehoben, sondern wächst leicht nach oben und leuchtet – die blaue Gebietsleiste bleibt frei.
- **Vorlagen-Fenster neu** im Stil des Ultimate-Fensters: Bühne mit aufgefächerten Karten und der Ultimate davor, Kurzinfos (Ø Mana, Bonusaktionen, Ultimate), „Übernehmen“ mit 3D-Dreh, Haptik und Klang, darunter alle Vorlagen zum Durchblättern.
- **Meteor neu:** vernichtet weiter eine Figur (nicht König oder Dame). Ungeschützte gegnerische Bauern direkt daneben werden nicht mehr vernichtet, sondern können **zwei Züge lang nicht ziehen** (Frost-Effekt auf dem Brett).
- **„Ungeschützt“ jetzt streng:** heißt überall „von keiner eigenen Figur gedeckt und nicht unter Schild oder Bollwerk“. Vorher zählte nur der Schild – deshalb hat der Meteor auch gedeckte Bauern erwischt. Gilt auch für **Blitz**. Die Regel steht unter *Regeln → Schutzregeln*.
  - Erste Schlacht angepasst und mit der Engine geprüft: Mila greift mit f6 an, Blitz auf den ungedeckten Bauern f6, Mila sperrt die f-Linie mit dem Springer, Meteor auf f5, Dame f7 matt. Mila kann zu keinem Zeitpunkt etwas schlagen.
  - Alle Rook-Raid-Puzzles mit dem Solver unter den neuen Regeln geprüft: alle weiter lösbar.
- **Zwölf Bots statt acht** – dieselben Charaktere in der Bot-Leiter und im Kampf:
  - Neu: **Kasimir** (der Gaukler, Stufe 4), **Nox** (der Schatten, 7), **Magnus Frost** (der Eisherr, 10), **die Sphinx** (die Allwissende, 11).
  - **Kampf:** alle 200 Trophäen ein stärkerer Charakter, mit seinem eigenen Deck (vorher eine zufällige Vorlage).
  - **Leiter:** 30 bis 200 XP für den ersten Sieg, Truhen von Silber bis Legendär, 63 Erfolge (vier neue Leiter-Erfolge). Bisheriger Fortschritt wird übernommen; neue Bots unterhalb deines Fortschritts zählen als geschafft.
- **Stärkere Engine** (ab Sir Konrad): Transpositionstabelle (Stellungsgedächtnis), Zugsortierung mit zwei Killerzügen und Verlaufs-Heuristik, kein Abbruch der Suche im Schach am Horizont, und bei Zeitablauf zählt die schon begonnene tiefere Rechnung. Ausprobiert und verworfen, weil im Simulator nicht stärker: Late Move Reductions und eine erweiterte Bauernstruktur-Bewertung (bleiben im Code abschaltbar).
- **Größere Abstände:** Denkzeit von 0,4 s (Bruno) bis 4 s (Turmkönigin), Suchtiefe von 1 bis 8 Halbzügen, Zufall und Patzer nur noch bei den unteren Stufen.
- **Ergebnisse im Simulator** (JavaScript-Nachbau, Punkte der schwächeren Stufe gegen die nächststärkere, 8–14 Partien je Paar, mit Karten und Ultimates):
  - Unten klare Abstände: Stufe 1 gegen 2 holt 6 %, 2 gegen 3 19 %, 3 gegen 4 18 %, 4 gegen 5 21–39 %.
  - Mitte (Stufen 5–9) knapp: 38–61 % je Paar. Im Simulator rechnen diese Stufen bei gleicher Denkzeit selten bis zur vollen Tiefe; auf dem iPhone (kompiliertes Swift, deutlich schneller) erreichen sie ihre Tiefe öfter, die Abstände sollten dort größer sein.
  - Oben wieder klar: Stufe 10 gegen 11 holt 31 %, 11 gegen 12 25 %.
  - Die neue Turmkönigin gegen die alte: 56 % – nur mäßig stärker. Bei kleinen Partiezahlen schwanken alle Werte um ±15 Punkte.
- **Speicherformat 13.**

## Neu in v0.9.10: Ruhiges Brett, epischer Sieg, neuer Pfad
- **Kein „Zoomen“ mehr nach einem Zug:** Ursache waren Mana-Gutschriften („+1 Gebiet“) und Hinweise, die kurz Platz unter dem Brett belegten – das Brett schrumpfte und wuchs wieder. Gutschriften und Hinweis-Blase schweben jetzt als Überlagerung, und das Brett hat eine feste Größe.
- **Erste Schlacht neu:** Nach dem Schild zieht die Dame nach f3 (statt h5). Mila deckt f7 mit dem Läufer e6, dein Meteor zerstört den Läufer und reißt den Bauern f7 gleich mit, dann Dame f7 matt. Mit der Engine geprüft: Deine Dame und deine Figuren sind zu keinem Zeitpunkt schlagbar (vorher konnte nach dem Meteor der Turm h8 die Dame nehmen).
- **Siegfenster mit Show:** Band „SIEG!“ knallt herein, Lichtstrahlen drehen sich, Konfetti in zwei Wellen. Dein Avatar mit wippender Krone, daneben der besiegte Bot mit Blitz-Riss. Trophäen, XP und Flamme klappen als Beute-Kacheln nacheinander auf (zählen hoch, mit Haptik und Klang), dann Truhen, Pfad-Belohnung und Knöpfe. Ein Tipp zeigt alles sofort. Niederlage und Remis bleiben freundlich („Kopf hoch …“).
- **Bot-Leiter:** lässt sich nicht mehr seitlich verschieben (Inhalt exakt bildschirmbreit).
- **Deck-Tab vereinfacht:**
  - Dein aktuelles Deck bleibt beim Scrollen oben angeheftet – Karten tauschen ohne Zurückscrollen. Hinweise erscheinen direkt am Deck, „Abbrechen“ beendet das Tauschen.
  - Vorlagen und Ultimate sind zwei große, leuchtende Kacheln ganz oben; darunter „Deck testen“.
  - Der Rollen-Filter der Sammlung bleibt.
- **Sprache:** jetzt weiter unten in den Einstellungen als Menüpunkt „Sprache“ mit eigener Liste. Die Einstellungen bleiben beim Sprachwechsel offen.
- **Pfad-Tab neu:** ein gewundener Weg nach oben – unten das Trainingsgelände, oben der Gipfel. Jede Arena ist ein großes Tor mit eigenem Wappen und eigener Farbe (die aktuelle mit drehenden Strahlen). Die Straße glüht golden, so weit du gekommen bist; dein Avatar steht auf deinem Punkt. Bereite Belohnungen hüpfen und leuchten, „ALLE ABHOLEN“ holt alles mit einem Tipp (Splitter mit Konfetti, Truhen öffnen sich nacheinander).
- **Mehr Flüssigkeit, gleiche Effekte:**
  - Speichern läuft jetzt im Hintergrund und wird gebündelt (vorher wurde bei jeder einzelnen Profiländerung das ganze Profil auf dem Hauptthread geschrieben). Beim Verlassen der App wird sofort gesichert.
  - Kleine Truhen und gezeichnete Avatare werden einmal als Bild gerendert und danach nur angezeigt – gleiche Optik, statt Dutzender Ebenen mit Weichzeichnern.
  - Konfetti als ein einziges gezeichnetes Bild (vorher 70 einzelne Ansichten) – flattert jetzt sogar.
  - Brett: die 64 Felder als eine Metal-Ebene, kein Neuaufbau bei Profiländerungen, Schatten nur beim Ziehen.
  - Das Wackeln im Deck läuft nur noch, während getauscht wird.

## Neu in v0.9.9: Sprachen, Avatare, stärkere Leiter
- **Sieben Sprachen:** Deutsch, Englisch, Französisch, Spanisch, Italienisch, Chinesisch (vereinfacht) und Russisch.
  - Beim ersten Start gilt die iOS-Systemsprache (wird sie nicht unterstützt: Englisch). Danach zählt nur die Wahl unter *Profil → Einstellungen → Sprache*; der Wechsel wirkt sofort.
  - Eigenes, schlankes System: Schlüssel ist der deutsche Text, die Übersetzungen liegen als `Localization/<sprache>.json` im Bundle (je 1.002 Einträge). Fehlt ein Eintrag, erscheint Deutsch.
  - Gespeicherte Daten bleiben sprachneutral (Bot-Namen, Titel, Truhen-Etiketten werden erst beim Anzeigen übersetzt), ein Sprachwechsel verändert also keine Spielstände.
  - Ein Prüfskript stellt sicher, dass in jeder Sprache alle Schlüssel vorhanden sind und Platzhalter, Formatangaben und Leerzeichen am Rand stimmen.
- **Startbildschirm:** ohne Untertitel, dafür 3,3 Sekunden mit Ladebalken, Prozentanzeige und Status („Verbinde mit der Arena …“) – vorbereitet für die Online-Version.
- **Ultimate-Auswahl neu:** große Bühne mit leuchtender Karte, Kurzinfos (Mana, Bonuszug, Ziel), „Ausrüsten“ mit 3D-Dreh, Haptik und Klang, gesperrte Ultimates mit Arena-Fortschritt, darunter alle Ultimates zum Durchblättern. Das Wackeln beim Öffnen ist behoben (Dauer-Animationen in Fenstern starten jetzt verzögert, in der ganzen App).
- **Avatare:** 11 neue, gezeichnete Avatare zusätzlich zum Springer – Fuchs, Eule, Bär, Pinguin, Frosch (gewöhnlich, 250), Wolf, Löwe, Roboter (selten, 600), Magier, Drache (episch, 1.200) und Phönix (legendär, 2.000 Splitter). Kaufbar im Laden und unter *Avatar, Rahmen & Titel*.
- **Kosmetik aus Truhen:** Truhen können jetzt Avatare, Rahmen (Rubin, Nebel, Prisma) und zehn neue Truhen-Titel enthalten (Glückspilz bis Kronjuwel). Chance: Holz 3 %, Silber 6 %, Gold 12 %, Magisch 25 %, Legendär 50 %; Legendäres nur aus Magischen und Legendären Truhen. Eigene Enthüllung „NEUER AVATAR/RAHMEN/TITEL!“.
- **Kartenpreise erhöht:** Gewöhnlich 500, Selten 1.500, Episch 3.000 Splitter (vorher 150/500/900). Laut Simulation kauft niemand mehr Karten „nebenbei“; Truhen bleiben der Hauptweg.
- **Splitter-Anzeige kompakt:** ab 1.000 als „1.2k“, ab 1 Mio. als „1.2M“ – alle Anzeigen passen nebeneinander.
- **Bot-Leiter neu gestaltet:**
  - Oben groß der aktuelle Gegner mit Stufen-Abzeichen, Motto in der Sprechblase, Deck und Herausfordern-Knopf – er ist also sofort sichtbar, ohne Scrollen.
  - Fortschrittsleiste aus acht Segmenten, darunter der Turm: besiegte Bots mit Haken und Revanche, „DU BIST HIER“ pulsierend, gesperrte Stufen mit Truhen-Vorschau; Siegerbild nach der Turmkönigin.
- **Stärkere Leiter-Bots:** Die Leiter hat jetzt eigene Profile (tiefer rechnen, weniger Zufall und Patzer, Denkzeit bis 1,8 s), per Turnier im Simulator abgestimmt. Die Kampf-Bots (Trophäen) bleiben unverändert.
  - Jeder Leiter-Bot schlägt den gleichnamigen Kampf-Bot: Stufen 1–5 mit 75–94 %, Stufe 7 mit 57 %.
  - Jede Stufe ist klar stärker als die vorige; der Vorgänger holt nur 13–31 %, gegen Viktor 42 %. Ein Plateau bei Stufe 4–6 wurde dabei beseitigt.
  - Bruno ist bewusst noch schlagbar für Einsteiger; ab Sir Konrad rechnet die Leiter teils drei Halbzüge tief, ab Baron Rabe teils vier.
- **Speicherformat 12:** alte Profile werden übernommen.

## Neu in v0.9.8: Truhen, Splitter, Flammen
- **Truhenöffnung neu:**
  - **Truhe:** neu gezeichnet als Vektorgrafik, mit Deckelwölbung, Beschlägen, Nieten, Schloss und eigenem Material je Seltenheit (Holz/Eisen, Stahl mit Saphir, Gold mit Rubin, violett mit Leuchtrunen, Obsidian mit Gold und Regenbogen-Edelstein). Beim Aufladen dringt Licht aus der Fuge, Schloss und Runen glühen. Offen klappt der Deckel nach hinten und Licht quillt heraus.
  - **Ablauf ohne Knöpfe:**
    - Die Truhe kracht mit Schockwelle und Staub herein, drei Taps laden sie auf.
    - Der vierte Tap lässt sie erst zittern (Grollen), dann explodiert sie: Lichtsäule, Strahlen, Konfetti.
    - Die Belohnungen fliegen heraus und schalten von selbst weiter, Tippen beschleunigt.
    - Danach folgt sofort die nächste Truhe, sonst schließt sich das Fenster.
  - **Neue Karte:** Sie fliegt verdeckt heraus, schwebt mit pulsierender Aura und Herzklopfen-Haptik und dreht sich dann in 3D um: Blitz in der Seltenheitsfarbe, Strahlen (episch: Regenbogen), große Schaukarte, „NEUE KARTE!“.
  - **Haptik und Klang:** fünf neue Haptik-Muster (Grollen, Whoosh, Herzklopfen, Umdrehen, Splitter-Regen) und vier neue Klänge.
- **Kampf-Widget:** nur noch dein Avatar mit Rahmen, Name und Titel; dein Deck in einer eigenen Zeile darunter (überdeckt nichts mehr).
- **Tagestruhe:** ruhiges Fenster mit Goldtruhe, Checkliste mit „Los“-Knöpfen und Countdown bis zu den neuen Zielen. Im Truhenfeld steht statt „Morgen wieder“ der Countdown.
- **Flammen:**
  - Ein Tipp auf die Flamme öffnet die Flammen-Statistik: Serie, Rekord, aktive und eingefrorene Tage, Monatskalender, Meilensteine (3 bis 365 Tage) mit Belohnungen.
  - **Flammenschutz** wie bei Duolingo: höchstens 2 auf Vorrat. Ein verpasster Tag wird automatisch eingefroren, mit Hinweis beim nächsten Öffnen.
  - Den Schutz gibt es für 200 Splitter oder gratis bei 7, 30, 100 und 365 Tagen; jedes Profil startet mit einem.
- **Splitter:**
  - **Anzeige:** neben Flamme und Trophäen auf der Startseite (auch im Deck und Profil). Der Stand zählt sichtbar hoch, „+N“ schwebt auf.
  - **Splitter-Laden** mit drei Tagesangeboten (Truhe, Karte −20 %, Rahmen oder Brett), dazu Flammenschutz, Karten (ab ihrer Levelgrenze), drei neue Laden-Rahmen (Rubin, Nebel, Prisma), Sammelbretter und Truhen.
  - **Sparziel:** Stern im Laden, Fortschritt auf der Startseite.
  - **Volle Sammlung:** Wer alle Karten hat, bekommt statt einer Karte einen Splitter-Fund (150).
  - **Preise:** per Simulation abgestimmt; ab Tag 30 verdient ein regelmäßiger Spieler etwa 50 Splitter am Tag.
- **Puzzles:** Level und XP-Balken im Puzzle-Tab, „+XP“ am Weiter-Knopf, XP-Chip im Puzzle (halbiert bei Fehler/Hinweis, „Gelöst“ wenn schon erledigt), XP-Zähler im Puzzle-Rausch.
- **Tab „Pfad“:** Die Trophäenstraße heißt jetzt Trophäenpfad.
- **Bot-Leiter:** neuer Herausfordern-Knopf (eine Zeile, Gesicht des Gegners, Lichtschimmer, Pulsieren) mit Belohnungs-Chips für XP und die echte Truhe.
- **59 Erfolge:**
  - in neun Bereichen (Kampf, Bot-Leiter, Trophäen, Karten & Ultimates, Puzzles, Flammen, Sammlung, Splitter, Level);
  - Medaillen in Bronze, Silber und Gold;
  - jeder Erfolg wird abgeholt und bringt Splitter, „Alle abholen“ in einem Tipp, Zähler am Profil-Tab.
  - Neue Zähler im Profil: Matt-Siege, Siegesserie, Karten pro Typ, Ultimates, Bonusaktionen, Taktik-Boni, gesammelte Splitter.
- **Speicherformat 11:** alte Profile werden übernommen. Bereits erreichte Erfolge lassen sich sofort abholen.

## Neu in v0.9.7: Einfacher, mehr Spaß
- **Tab-Leiste:** Spielen · Puzzles · Deck · Straße · Profil. Rote Zahlen zeigen, wo etwas wartet: Truhen und Tagestruhe, das Tagespuzzle (Punkt), neue Karten, abholbare Belohnungen der Trophäenstraße.
- **Startseite:** Unter „Kampf!“ liegen drei Siegtruhen-Plätze (leer / bereit / geöffnet) und die Tagestruhe mit Fortschrittsring; ein Tipp darauf öffnet die Tagesziele. „Zu zweit“ steckt jetzt im Einstellungsfenster des Kampf-Bereichs, Puzzle-Kachel und Versionszeile sind weg. Der Kampf-Knopf zeigt, ob es noch eine Siegtruhe gibt. Die Arena-Leiste zeigt den Weg zur nächsten Straßen-Belohnung.
- **Duell-Intro:** Vor jeder Bot-Partie knallen beide Seiten mit Avatar, Titel und offenem Deck ins Bild, „VS“ schlägt ein (Haptik + Klang). Tippen überspringt; Uhr und Bot starten erst danach.
- **Siegerbildschirm:** Verdiente Truhen fallen nacheinander von oben herein und landen mit einem Rumms. Ist eine neue Stufe der Trophäenstraße erreicht, führt ein goldener Knopf direkt dorthin.
- **Puzzles:** Großer „WEITER“-Knopf zum nächsten ungelösten Puzzle, darüber Puzzle-Serie und Fortschritt zur Rätseltruhe. Tagespuzzle und **Puzzle-Rausch** (3 Minuten, 3 Leben, erst leicht dann schwer, 3 XP pro Puzzle, Bestwert) als Kacheln. Fünf Kategorien mit Fortschrittsring; die Aufgaben einer Kategorie öffnen sich als Fenster. Saubere Lösungen in Folge zeigen eine wachsende „X in Folge!“-Plakette.
- **Deck:** „NEU“-Aufkleber auf frisch gezogenen Karten (verschwindet beim Antippen oder Verlassen des Tabs). „Deck testen“ startet eine Übungspartie gegen Bruno ohne Trophäen.
- **Trophäenstraße (ersetzt den Arena-Tab):** Von 0 bis 2400 Trophäen alle 50–150 Trophäen eine Belohnung – Truhen, Splitter, die Sammelbretter Smaragd (300), Lava (800) und Mitternacht (1500). Die Arenen sind große Abschnitte mit ihren Ultimates und einer Magischen bzw. Legendären Truhe; neu sind Arena 4 Sturmfeste (600), 5 Drachenhort (1200) und 6 Königsgipfel (2100). Dazwischen markiert die Straße, ab wann der Kampf-Gegner stärker wird. Abgerechnet wird nach dem Trophäen-Rekord; Arena-Truhen aus älteren Versionen zählen als abgeholt.
- **Profil:** Oben Avatar, Name, Titel und drei Kennzahlen. Darunter die Erfolge-Vitrine mit den drei nächsten Erfolgen samt Fortschrittsbalken. Statistik und Verlauf liegen auf einer eigenen Seite, Einstellungen (Schalter, Bretter, Regeln, Erste Schlacht, Zurücksetzen, Version) hinter dem Zahnrad.
- **Titel & Rahmen:** 17 Erfolge (neu u. a. Veteran, Unermüdlich, Rätselmeister, Fehlerlos, Blitzdenker, Sturmreiter) schalten Titel und Avatar-Rahmen frei (Silber, Gold, Flamme, Krone, Rätsel, Legendär). Auswahl per Tipp auf den Avatar; Titel und Rahmen erscheinen auch im Duell-Intro, der Rahmen zusätzlich auf der Startseite.
- **Spielbildschirm:** Die Gebietsanzeige ist als schmaler Balken in die Mana-Leiste gewandert – das Brett bekommt mehr Luft. Erklärungen erscheinen nur noch als Sprechblase, wenn eine Karte gewählt ist oder es einen echten Hinweis gibt, und verschwinden nach ein paar Sekunden.
- **Speicherformat** bleibt lokal auf dem iPhone; alte Profile werden übernommen.

## Neu in v0.9.6: Truhen
- **Karten aus Truhen:** 4 Startkarten (Blitz, Schild, Sturmlauf, Frost), 10 weitere in drei Seltenheiten (Gewöhnlich, Selten ab Level 5, Episch ab Level 10). Gesperrte Karten lassen sich im Deck-Tab auch mit Splittern kaufen (150 / 500 / 900).
- **Truhen öffnen wie bei Brawl Stars:** Die Truhe fällt mit Aufprall herein, drei Taps laden sie auf und können sie aufwerten (Holz → Silber → Gold → Magisch → Legendär), der vierte sprengt sie auf. Jede Belohnung wird einzeln enthüllt. Dazu eigene CoreHaptics-Muster, sechs neue Klänge, Partikel, Lichtstrahlen und Bildschirmbeben.
- **Quellen:** Erste Truhe nach der Einstiegspartie, die ersten 3 Kampf-Siege pro Tag, Tagestruhe (jetzt Gold statt XP), erster Sieg gegen jeden Leiter-Charakter, jedes 5. gelöste Puzzle, jeder Levelaufstieg, Arena 2 und 3.
- **Level-Pfad** im Deck-Tab: zeigt die nächsten sechs Level-Truhen und welche Karte sie garantieren.
- **Truhenlager** auf der Startseite mit Splitter-Stand, Siegtruhen des Tages und nächster Level-Station. Nach Partie, Puzzle und Einstiegspartie geht es mit einem Tipp direkt zur Öffnung.
- **Sammelbretter** Lava, Smaragd und Mitternacht: aus Magischen und Legendären Truhen oder für 300 Splitter.
- **Bestehende Profile** behalten alle bisher freigeschalteten Karten und bekommen eine Goldtruhe als Willkommensgeschenk.
- **Deck-Tab aufgeräumt (Build 17):** Oben nur das Deck (4 Karten + Ultimate) mit einer Zeile Kennzahlen bzw. Tausch-Hinweis. Tauschen: Karte unten antippen, dann die Karte im Deck – die Deckkarten wackeln, solange eine Karte wartet. Vorlagen und Ultimate-Wahl öffnen sich als eigenes Fenster. Die Sammlung lässt sich nach Rolle filtern, gesperrte Karten stehen getrennt darunter. Der Level-Pfad zeigt nur noch die nächsten vier Truhen, die lange Regelliste ist weg (steht unter Profil → Regeln).

## Neu in v0.9.5: Decks und Karten-Balance
- **Deck bauen statt Nachziehen:** 4 Karten + 1 Ultimate, die ganze Partie über verfügbar. Abklingzeit von 2 Zügen pro Karte (Sanduhr auf der Karte, auch in der Gegnerleiste).
- **Tab „Deck“** (ersetzt „Ultimate“): Deck-Plätze, Sammlung mit Rolle und Freischaltung, Kennzahlen (Ø Mana, Bonusaktionen, Rollen) und **sechs Vorlagen**: Sturmangriff, Eiskönig, Festung, Ritual, Phönix, Taktiker.
- **6 neue Karten:** Vormarsch, Bauernopfer, Leibwache, Konzentration, Manaraub, Läuferweihe – freigeschaltet mit Level 2 bis 7. Nach einem Levelaufstieg erscheint die neue Karte im Ergebnisfenster.
- **Balance nach Simulator-Tests** (über 3.000 Bot-Partien): Kosten fast aller Karten angepasst, Sturmlauf und Bollwerk sind jetzt Bonusaktionen, die Dame ist immun gegen Frost.
- **Ultimates überarbeitet:** Meteor reißt ungeschützte Bauern daneben mit. Eiszeit wirkt zwei Züge. Festung ist eine Bonusaktion. Krönung geht mit eigener Dame nur noch für Bauern in der gegnerischen Hälfte.
- **Bots spielen Decks:** Jeder Leiter-Charakter hat ein Deck passend zu seinem Stil, der Kampf-Bot spielt eine der Vorlagen. Starke Stufen rechnen gegnerische Karten mit ein.
- **Puzzles angepasst:** 7 Rook-Raid-Puzzles an die neuen Regeln angepasst (neue Frost-Matts, Sturmlauf-Matt in 1, korrigierte Meteor- und Krönungsaufgabe).

## Neu in v0.9.4
- **Acht Bot-Stufen:** Alle 300 Trophäen kommt ein stärkerer Bot, ab 2.100 Trophäen die stärkste Stufe. Jede Stufe gewinnt im Test etwa 60–80 % gegen die vorige. Die Denkzeit liegt je nach Stufe bei 0,3 bis höchstens 1,5 Sekunden.
- **Kampf! wählt den Gegner selbst:** Der Bot passt zu deinen Trophäen. Im Einstellungsfenster gibt es deshalb keine Gegner-Auswahl mehr, nur Bedenkzeit und Farbe.
- **Bot-Leiter (offline):** Acht Charaktere von Bruno bis zur Turmkönigin. Wer einen Bot besiegt, schaltet den nächsten frei. Der erste Sieg bringt 30 bis 150 XP, jede Revanche 10 XP. Keine Trophäen, zählt aber für die Statistik.
- **Puzzles überarbeitet (102 Aufgaben):** Zu einfache Matt-in-1-Aufgaben mit nur einem möglichen Schach wurden durch Stellungen mit mehreren verlockenden Schachs ersetzt. Neu sind sechs Matt-in-2-Aufgaben, die mit einem stillen Zug beginnen. Gleichwertige Lösungen werden als richtig gewertet, bei Matt in 2 auch Züge, die nicht in der Lösung stehen, wenn danach jedes Matt in 1 erzwingt.
- **Erfolg „Gipfelstürmer“:** für den Sieg über die Turmkönigin.

## Neu in v0.9.3
- **Startseite aufgeräumt:** Der Untertitel „Weiß“ und die schwebenden Kartensymbole sind weg. Unter dem Kampf-Knopf stehen die gewählten Einstellungen als kleine Chips: Gegner, Bedenkzeit und Farbe. Ein Tipp darauf öffnet die Einstellungen.
- **Einstellungsfenster speichert nur noch:** Der Knopf heißt jetzt „Speichern“. Gestartet wird mit „Kampf!“.
- **Einheitliches Flammen-Symbol** in den Tageszielen.
- **Neues Profil:** Ganz oben steht ein Banner mit Avatar, Level-Ring, Rang-Titel (Bauer bis Großmeister), dem Namen zum Bearbeiten, einem XP-Balken sowie Trophäen, Flammen und Arena. Darunter folgen diese Bereiche:
  - Bilanz-Ring mit Siegquote und der Form der letzten 10 Partien
  - Trophäen-Verlauf als Diagramm
  - 8 Kennzahlen zum Spielstil: Siegesserie, schnellster Sieg, Ø Aktionen, Siege durch Matt, gespielte Karten, Lieblingskarte, gezündete Ultimates und aktive Tage
  - Bilanz gegen Bruno, Mila und Viktor
  - Puzzle-Fortschritt
  - 8 Erfolge zum Freischalten

## Neu in v0.9.2
- **Neue Startseite „Spielen“:** Oben steht ein großes Arena-Banner mit Trophäen-Fortschritt. Darunter treten du (mit deiner Ultimate als goldenem Chip) und dein Gegner gegeneinander an, mit pulsierendem „VS“ und schwebenden Karten. Ein Tipp auf den goldenen **KAMPF!**-Knopf startet sofort mit deinen letzten Einstellungen. Der Regler daneben öffnet die Partie-Einstellungen, und ein Tipp auf den Gegner wechselt zwischen Bruno, Mila und Viktor.
- **Tagesziele mit Truhe:** Die drei Tagesziele sind Flamme entzünden, Tagespuzzle lösen und eine Partie gewinnen. Sind alle erfüllt, wackelt die Truhe und bringt +25 XP. Die Flammen-Serie und die Wochenleiste stehen in derselben Karte.
- **Wischen zwischen den Tabs:** Die Hauptseiten lassen sich mit dem Finger wechseln. Die eigene Tab-Leiste folgt mit einer blauen Kapsel.
- **Erste Schlacht zeigt Verteidigung:** Mila greift deinen Springer an. Du schützt ihn mit Schild, und weil Schild eine Bonusaktion ist, ziehst du gleich noch die Dame nach h5. Danach entfernt Blitz den Angreifer. Die erste Schlacht hat jetzt 8 Aufgaben.

## Neu in v0.9.1
- **Schild-Figur bleibt stehen:** Nach Schild ist die geschützte Figur im folgenden Figurzug gesperrt, auch als Rochade-Turm. Ein goldenes Schloss zeigt die Sperre auf dem Brett. Tippt man die Figur an, erklärt ein Hinweis den Grund. Schild ist nur spielbar, wenn danach noch eine andere Figur ziehen kann. Bei Frost gilt die Regel ohnehin, denn die eingefrorene Figur gehört dem Gegner und steht in seinem nächsten Zug still.
- **4 neue Schild-Puzzles** (rr-schild-6 bis 9) ersetzen die Puzzles, die nur mit der geschützten Figur selbst mattsetzten. Alle 42 Rook-Raid-Puzzles sind mit der neuen Regel geprüft.
- **Erste Schlacht ohne Pop-ups:** Die Aufgabe steht in einer Aufgabenleiste über dem Brett, dort, wo sonst der Gegner steht. Sie besteht aus einem Orden mit Fortschrittsring, dem Aufgabentitel und dem Ziel. Nach dem Erfüllen ploppt ein goldener Haken mit Funken auf, dazu ein Jubel wie „Treffer!“ und Belohnungs-Chips wie „+6 Felder“ oder „+1 Mana“. Nach Milas Antwort gleitet die nächste Aufgabe herein, ein Klick auf „Weiter“ ist nicht nötig. Bei einem falschen Zug wackelt die Leiste und zeigt einen Tipp. Die erste Schlacht hat jetzt 7 Aufgaben.

## Neu in v0.9
- **Karten neu ausbalanciert:** Schild und Frost kosten 3 Mana und sind jetzt Bonusaktionen, nach ihnen machst du noch einen Figurzug. Neue Preise: Sturmlauf 1, Blitz 2, Verstärkung 3, Ritterschlag 4, Wiederkehr 7. Der Bot nutzt die neuen Kombinationen aus Bonuskarte und Zug.
- **Remis-Regeln:** dreifache Stellungswiederholung und 50-Züge-Regel.
- **Umwandlung nach Wahl:** Beim Durchlaufen eines Bauern erscheint eine Auswahl mit vier Karten: Dame, Turm, Läufer, Springer.
- **Spielstände mit Versionsnummer:** Partien und Profil tragen eine Formatversion. Alte Spielstände (v5) werden beim Start automatisch übernommen und umgewandelt.
- **Eigenes Figurenset im Rook-Raid-Stil:** kräftige Marine-Kontur, Creme mit Gold beziehungsweise Marine mit Blau. Es ist als Vektorgrafik eingebunden und ersetzt das bisherige cburnett-Set.
- **Partie nachspielen:** Nach jeder Partie gibt es „Partie nachspielen“ mit Brett, Abspielen und vollständiger Zugliste inklusive Karten und Ultimates. Die letzten 10 Partien lassen sich auch im Profil über den Verlauf öffnen.
- **Startbildschirm:** Logo auf Marineblau beim Systemstart, danach eine kurze Animation mit zwei Karten in Blau und Rot.
- **Geführte erste Schlacht:** Beim ersten Start geht es direkt ins Spiel. In etwa zwei Minuten lernst du mit Coach-Hinweisen und leuchtenden Feldern Zug, Gebiet, Mana, Schlagen, eine Karte (Blitz), die Ultimate (Meteor) und das Schachmatt. Danach gibt es 50 XP und die erste Flamme. Wiederholbar im Profil.
- **Puzzles an die neuen Regeln angepasst:** Neu sind 10 Bonus-Puzzles, „Schild-Matt“ und „Frost-Matt“: Bonuskarte und dann ein Figurzug, der mattsetzt. Die Karten-Puzzles sind mit den neuen Kosten neu geprüft. Bonuskarten liegen dort nicht mehr nur zur Ablenkung auf der Hand.

## Neu in v0.8.1: Rook-Raid-Puzzles
Im Tab „Puzzles“ stehen jetzt oben zwei eigene Abschnitte im echten Rook-Raid-Format. Alle Lösungen sind mit einem Solver geprüft, der die Karten- und Ultimate-Regeln 1:1 nachbildet.
- **Karten & Ultimates (28):** Ein Schachzug allein reicht nicht. Erst bereitet eine Karte oder die Ultimate das Matt vor, dann folgt das Matt.
  - Frost (5) und Blitz (5): dem Gegner den letzten Wartezug nehmen (Zugzwang).
  - Sturmlauf (3), Ritterschlag (1), Schild (1), Krönung (4), Meteor (4) und Eiszeit (5).
  - Jedes Puzzle hat eine Hand mit 4 Karten und begrenztes Mana. Die passende Karte muss man selbst finden. Die Schutzregeln gelten wie im Spiel: kein Schach durch Karten, und der Gegner muss einen Zug behalten.
- **Gebiet (10):** Mit einer Aktion die nächste Mana-Stufe erreichen, also 26 oder 32 Felder. Das Brett zeigt das Gebiet als Farbton, der Stufenbalken den Fortschritt. Jede Aktion, die das Ziel erreicht, zählt.
- Die klassischen Puzzles stehen darunter unter „Klassisch“.

## Neu in v0.8
- **Neuer Name: Rook Raid.** Projekt, Target und App-Name sind umbenannt. Das App-Symbol ist das neue Logo, inklusive Varianten für den dunklen und den eingefärbten Modus ab iOS 18.
  - Der Bundle Identifier ist jetzt `com.example.rookraid`. Wer seinen bisherigen Identifier wieder einträgt, behält seinen Fortschritt auf dem iPhone.
- **Farben aus dem Logo:** Marineblau als Grund, Blau für dich und Primäraktionen, Rot für den Gegner, Kartencreme, Gold für die Ultimate, Violett für Mana.
  - Neues Standardbrett „Rook Raid“ in Creme und Taubenblau.
  - Dein Gebiet ist heller und blauer, das gegnerische gedeckter und rötlicher.
- **Brett bleibt stehen:** Der Hinweistext unter den Karten hat eine feste Höhe für zwei Zeilen. Eine lange Kartenbeschreibung verschiebt das Spielfeld nicht mehr.
- **Puzzles:** „Nächstes Puzzle“ öffnet direkt das nächste Puzzle, ohne Umweg über die Übersicht.

## Aus v0.7
- **Puzzles (neuer Tab):** 57 Aufgaben in drei Stufen (seit v0.9.4: 102).
  - Leicht: 14× Matt in 1, bekannte Mattbilder wie Grundreihe, Ersticktes Matt, Anastasia.
  - Mittel: Matt in 2 und Materialgewinn durch Gabel, Spieß oder Abzug.
  - Schwer: Matt in 2 mit stillem ersten Zug und Matt in 3.
  - Alle Lösungen wurden vorab mit einem Solver geprüft. Bei Matt-Aufgaben zählt jedes Matt, auch alternative Lösungswege werden erkannt.
  - Hinweis (markiert die richtige Figur) und Lösung vorspielen.
- **XP und Level:** Leicht 10, Mittel 20, Schwer 35 XP beim ersten Lösen. Mit Fehler oder Hinweis die Hälfte, nach „Lösung“ keine XP. Level-Schwellen: 50, 150, 300, 500 XP …
- **Tagespuzzle:** jeden Tag ein anderes, einmal pro Tag +15 XP Bonus.
- **Tägliche Flammen:** Ein gelöstes Puzzle oder eine abgeschlossene Partie (mindestens 10 Züge) entzündet die Flamme des Tages.
  - Die Serie zählt Tage in Folge. Ein ausgelassener Tag setzt sie auf 1 zurück.
  - Auf der Startseite: Serie, Wochenleiste Mo–So, Rekord. Zusätzlich gibt es eine Feier im Ergebnisfenster.
- **„Neue Partie“-Fenster:** lässt sich wieder nach unten wegwischen. Dazu gibt es einen Ziehgriff und einen Schließen-Knopf.

## Aus v0.6
- Gebiet über Nachbarfelder, Einkommensstufen bei 26 und 32 Feldern, Design „Turnier“, Gebiet als Farbton, Stufenbalken.

## Zum Testen
- Der Schalter **„Testmodus: alle Karten frei“** im Profil schaltet sofort alle Ultimates frei.
- Darauf achten:
  - Wie oft kommt die Ultimate zum Einsatz?
  - Ist das Gebiet auf dem Brett gut erkennbar, ohne zu stören?
  - Spürt man den Unterschied zwischen +1, +2 und +3 Mana? Sind 26 und 32 Felder gut erreichbar?
  - Lohnt es sich, Mana zu sparen, statt Karten zu spielen?
  - Sind die Puzzle-Stufen passend schwer? Motiviert die Flamme, täglich reinzuschauen?

## Bekannte Grenzen
- Der Bot „Schwer“ rechnet jetzt auch das Gebiet ein und kann im Debug-Build einige Sekunden pro Zug brauchen.

## Credits
Figurengrafiken: eigenes Rook-Raid-Figurenset (v0.9).
