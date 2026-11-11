# Rook Raid – Backend (Supabase)

**Vollständige Anleitung: [`ONLINE-IMPLEMENTIERUNG.md`](ONLINE-IMPLEMENTIERUNG.md)** – Entscheidungen, Einrichtung, App-Anbindung, Protokoll, Tests, Betrieb.

Stand v0.9.36: Datenbank, Regeln (Version 3), Wartungsjob und die drei Edge Functions liegen auf dem Projekt in Frankfurt. `OnlineConfig.enabled` ist an; ohne URL und Schlüssel in der App bleibt das Spiel lokal.

## Inhalt
- `supabase/migrations/` – Datenbank (Tabellen, Zugriffsregeln, Funktionen für Konto, Gegnersuche, Bot-Ersatz, Uhr, Remis, Aufgeben, Wartung, Bestenliste) und Wartungsjob.
- `supabase/seed/rules.sql` – aktuelle Regeln (generiert: `node Tools/rules-js/seed-rules.js`).
- `supabase/functions/` – Edge Functions `submit-action`, `finish-bot-match`, `delete-account`, `push-dispatch` (Push für Freundschaftsanfragen), `send-feedback` (Feedback aus der App per Mail); Regeln in `_shared/rookraid-rules.mjs` (generiert: `node Tools/rules-js/build-server.js`).
- `tests/` – Datenbank- und Ablauf-Tests gegen ein lokales Postgres.

## Kurzbefehle
```bash
node Tools/rules-js/check-golden.js && node Tools/rules-js/build-server.js && node Tools/rules-js/check-server.mjs
node Tools/rules-js/seed-rules.js
cd Backend && supabase link --project-ref <ref> && supabase db push
supabase functions deploy submit-action && supabase functions deploy finish-bot-match && supabase functions deploy delete-account && supabase functions deploy push-dispatch --no-verify-jwt && supabase functions deploy send-feedback --no-verify-jwt
```

Konto löschen widerruft „Sign in with Apple“ (Richtlinie 5.1.1(v)). Dafür braucht `delete-account` den „Sign in with Apple“-Schlüssel:
```bash
supabase secrets set APPLE_TEAM_ID=X2XXYAQYX6 APPLE_KEY_ID=<Key-ID> APPLE_PRIVATE_KEY="$(cat AuthKey_<Key-ID>.p8)"
```
(`APPLE_CLIENT_ID` nur setzen, wenn die Bundle-ID nicht `com.ivan.rookraid` ist.) Fehlen die Geheimnisse, wird trotzdem gelöscht – nur ohne Widerruf (steht im Log).

## Freunde und Push (Migration `20261107120000_friends.sql`)
Freundesliste, Anfragen, Freundescode, Blockieren und Melden laufen nur über Server-Funktionen; Profile sind nicht mehr
für alle lesbar. Die Datenbank legt Nachrichten in `push_outbox` ab, `push-dispatch` verschickt sie (iOS über APNs,
Browser über Web Push). Ohne die Geheimnisse bleibt alles nutzbar – nur ohne Push (die Apps sehen jede Minute nach).
```bash
# APNs-Schlüssel (Apple Developer → Keys → „Apple Push Notifications service“)
supabase secrets set APNS_TEAM_ID=X2XXYAQYX6 APNS_KEY_ID=<Key-ID> APNS_PRIVATE_KEY="$(cat AuthKey_<Key-ID>.p8)" APNS_TOPIC=com.ivan.rookraid
# Web Push: einmal ein VAPID-Schlüsselpaar erzeugen (z. B. npx web-push generate-vapid-keys)
supabase secrets set VAPID_PUBLIC_KEY=<öffentlich> VAPID_PRIVATE_KEY=<privat> VAPID_SUBJECT=mailto:<Kontaktadresse>
```
Den öffentlichen VAPID-Schlüssel bekommt die Browser-Fassung zusätzlich als `VITE_VAPID_PUBLIC_KEY`.

## Bot-Spieler, Online-Status und Freundschaftsspiele (Migration `20261109120000_bot_players.sql`)
100 Bot-Spieler mit echtem Profil (Konto ohne Anmeldung, Freundescode, Trophäen), offen als „Bot“ gekennzeichnet.
Ihr Verhalten steht in `private.bot_players` (in der Migration): Name, Avatar, Rahmen, Titel, Deck, Start-Trophäen,
Online-Zeiten (deutsche Zeit, Mo–Fr und Sa/So), ob und nach wie vielen Minuten sie Freundschaftsanfragen annehmen
(nur während sie online sind) und ob sie Freundschaftsspiele annehmen. Ändern: Zeile in der Migration anpassen und eine
neue Migration mit demselben `insert … on conflict do update` schreiben (der Generator liegt nicht im Repo; die Werte
sind fest). Die Konten tauchen unter Authentication → Users auf (ohne E-Mail); nicht löschen.

- Gegnersuche: nach 10 s ohne Menschen ein Bot-Spieler, der online, frei und nicht blockiert ist (±300 Trophäen);
  beide Seiten gewinnen oder verlieren Trophäen. Sonst wie bisher der Trainingsgegner.
- Jobs: `rookraid-bot-players` (jede Minute: Anfragen annehmen, Push auslösen), `rookraid-bot-drift` (stündlich:
  Trophäen im Hintergrund, zum Startwert zurückgezogen).
- Online-Status: Die Apps rufen alle 15 s `touch_online` auf; Freunde sehen „online“ bis 2 Minuten danach, außer der
  Spieler hat ihn mit `set_show_online(false)` ausgeschaltet.
- Freundschaftsspiele: `invite_friend_match` → `friend_match_status` (Einladender, alle 2 s) / `answer_friend_match`
  (Eingeladener). 5 | 0, `matches.rated = false` (keine Trophäen), zählt für die Bilanz. Einladung gilt 2 Minuten.

Push für angenommene Anfragen von Bot-Spielern schickt die Datenbank selbst (pg_net → `push-dispatch` mit dem Header
`x-cron-secret`). Dafür einmal:
```bash
supabase secrets set CRON_SECRET=<mindestens 32 zufällige Zeichen>
# im SQL-Editor (Vault):
select vault.create_secret('https://<ref>.supabase.co', 'rookraid_project_url');
select vault.create_secret('<derselbe CRON_SECRET>', 'rookraid_cron_secret');
```
`push-dispatch` muss mit `--no-verify-jwt` deployt werden (der Aufruf aus der Datenbank hat kein Nutzer-Token; die
Function prüft Token bzw. Geheimnis selbst). Fehlt etwas, werden Anfragen trotzdem angenommen – nur ohne Push.

## Feedback (Migration `20261111130000_feedback.sql`, Function `send-feedback`)

Profil → Feedback schickt Kategorie, Text, optional eine Kontaktadresse und Geräteinfos an `send-feedback`. Die Function
speichert jede Nachricht in `public.feedback` (höchstens 5 pro Stunde je Gerät oder Konto, 300 am Tag) und mailt sie
über [Resend](https://resend.com) an rookraidchess@gmail.com (Antworten gehen an die angegebene Kontaktadresse).
Einmalig: Resend-Konto **mit rookraidchess@gmail.com** anlegen (ohne eigene Domain stellt Resend nur an die eigene
Adresse zu), API-Schlüssel erzeugen, dann:
```bash
supabase secrets set RESEND_API_KEY=<Schlüssel>          # optional: FEEDBACK_TO, FEEDBACK_FROM
supabase functions deploy send-feedback --no-verify-jwt  # Gäste ohne Konto dürfen auch Feedback senden
```
Ohne Schlüssel wird nur gespeichert (Dashboard → Table Editor → feedback). Tests: `Backend/tests/feedback.js`.

## Verlauf gegeneinander (Migration `20261110120000_friend_history.sql`)

`friend_matches(p_user, p_limit)` liefert die letzten Partien gegen einen Freund (neueste zuerst, aus eigener Sicht:
win/loss/draw, Spielende, gewertet oder Freundschaftsspiel, Trophäen). Nur unter Freunden. Tests: `Backend/tests/bots.js`.

## Sign in with Google

Läuft ganz über Supabase (kein Google-SDK in der App): iPhone öffnet das Anmeldefenster von iOS und springt über
`rookraid://auth-callback` zurück, der Browser leitet über Supabase zu Google und zurück auf `https://rookraid.com/`.

1. Google Cloud Console → APIs & Services → OAuth consent screen: App-Name „Rook Raid“, Support-E-Mail,
   Datenschutz-URL `https://rookraid.com/privacy`, Scopes nur `email`, `profile`, `openid`.
2. Credentials → Create credentials → OAuth client ID → **Web application**.
   Authorized redirect URI: `https://kjmlaxbpblndbybzvdbd.supabase.co/auth/v1/callback`.
3. Supabase → Authentication → Sign In / Providers → Google: einschalten, Client-ID und Client-Secret eintragen.
4. Supabase → Authentication → URL configuration → Redirect URLs: `rookraid://auth-callback` und `https://rookraid.com/`.
5. Supabase → Authentication → Sign In / Providers: **Allow manual linking** einschalten. Damit hängt „Mit Google sichern“
   (und „Mit Apple sichern“) auf dem iPhone die Anmeldung an das bestehende anonyme Konto – ID, Freunde und Trophäen bleiben.

Im Browser ist „sichern“ eine Anmeldung wie bei Apple: Gibt es zum Google-Konto schon ein Rook-Raid-Konto, wird es geladen,
sonst entsteht eines aus dem Spielstand dieses Browsers. Konto löschen braucht bei Google keinen Widerruf.
