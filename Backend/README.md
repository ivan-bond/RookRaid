# Rook Raid – Backend (Supabase)

**Vollständige Anleitung: [`ONLINE-IMPLEMENTIERUNG.md`](ONLINE-IMPLEMENTIERUNG.md)** – Entscheidungen, Einrichtung, App-Anbindung, Protokoll, Tests, Betrieb.

Stand v0.9.36: Datenbank, Regeln (Version 3), Wartungsjob und die drei Edge Functions liegen auf dem Projekt in Frankfurt. `OnlineConfig.enabled` ist an; ohne URL und Schlüssel in der App bleibt das Spiel lokal.

## Inhalt
- `supabase/migrations/` – Datenbank (Tabellen, Zugriffsregeln, Funktionen für Konto, Gegnersuche, Bot-Ersatz, Uhr, Remis, Aufgeben, Wartung, Bestenliste) und Wartungsjob.
- `supabase/seed/rules.sql` – aktuelle Regeln (generiert: `node Tools/rules-js/seed-rules.js`).
- `supabase/functions/` – Edge Functions `submit-action`, `finish-bot-match`, `delete-account`; Regeln in `_shared/rookraid-rules.mjs` (generiert: `node Tools/rules-js/build-server.js`).
- `tests/` – Datenbank- und Ablauf-Tests gegen ein lokales Postgres.

## Kurzbefehle
```bash
node Tools/rules-js/check-golden.js && node Tools/rules-js/build-server.js && node Tools/rules-js/check-server.mjs
node Tools/rules-js/seed-rules.js
cd Backend && supabase link --project-ref <ref> && supabase db push
supabase functions deploy submit-action && supabase functions deploy finish-bot-match && supabase functions deploy delete-account
```

Konto löschen widerruft „Sign in with Apple“ (Richtlinie 5.1.1(v)). Dafür braucht `delete-account` den „Sign in with Apple“-Schlüssel:
```bash
supabase secrets set APPLE_TEAM_ID=X2XXYAQYX6 APPLE_KEY_ID=<Key-ID> APPLE_PRIVATE_KEY="$(cat AuthKey_<Key-ID>.p8)"
```
(`APPLE_CLIENT_ID` nur setzen, wenn die Bundle-ID nicht `com.ivan.rookraid` ist.) Fehlen die Geheimnisse, wird trotzdem gelöscht – nur ohne Widerruf (steht im Log).
