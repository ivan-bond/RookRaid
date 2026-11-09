# Rook Raid – Backend (Supabase)

**Vollständige Anleitung: [`ONLINE-IMPLEMENTIERUNG.md`](ONLINE-IMPLEMENTIERUNG.md)** – Entscheidungen, Einrichtung, App-Anbindung, Protokoll, Tests, Betrieb.

Stand v0.9.36: Datenbank, Regeln (Version 3), Wartungsjob und die drei Edge Functions liegen auf dem Projekt in Frankfurt. `OnlineConfig.enabled` ist an; ohne URL und Schlüssel in der App bleibt das Spiel lokal.

## Inhalt
- `supabase/migrations/` – Datenbank (Tabellen, Zugriffsregeln, Funktionen für Konto, Gegnersuche, Bot-Ersatz, Uhr, Remis, Aufgeben, Wartung, Bestenliste) und Wartungsjob.
- `supabase/seed/rules.sql` – aktuelle Regeln (generiert: `node Tools/rules-js/seed-rules.js`).
- `supabase/functions/` – Edge Functions `submit-action`, `finish-bot-match`, `delete-account`, `push-dispatch` (Push für Freundschaftsanfragen); Regeln in `_shared/rookraid-rules.mjs` (generiert: `node Tools/rules-js/build-server.js`).
- `tests/` – Datenbank- und Ablauf-Tests gegen ein lokales Postgres.

## Kurzbefehle
```bash
node Tools/rules-js/check-golden.js && node Tools/rules-js/build-server.js && node Tools/rules-js/check-server.mjs
node Tools/rules-js/seed-rules.js
cd Backend && supabase link --project-ref <ref> && supabase db push
supabase functions deploy submit-action && supabase functions deploy finish-bot-match && supabase functions deploy delete-account && supabase functions deploy push-dispatch
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
