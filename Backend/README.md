# Rook Raid – Backend (Supabase)

**Vollständige Anleitung: [`ONLINE-IMPLEMENTIERUNG.md`](ONLINE-IMPLEMENTIERUNG.md)** – Entscheidungen, Einrichtung, App-Anbindung, Protokoll, Tests, Betrieb.

Stand v0.9.36 (Entscheidungen festgelegt, Abschnitt 1 der Anleitung): Server-Teil fertig und lokal getestet, **noch nicht eingespielt**; die App spielt weiter komplett lokal (`OnlineConfig.enabled = false`).

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
