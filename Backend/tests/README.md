# Backend-Tests

Prüfen die Datenbank-Funktionen (Migration 1) und das Zusammenspiel mit dem Regel-Bündel – **ohne** Supabase-Konto.

1. Ein leeres Postgres ≥ 15 bereitstellen (lokal oder `supabase start` → `postgresql://postgres:postgres@127.0.0.1:54322/postgres`).
   Achtung: `stub.sql` löscht die Schemas `public` und `auth` und baut die Supabase-Grundlagen nach – **nie gegen die echte Datenbank laufen lassen.**
2. Einmalig: `npm install` in diesem Ordner.
3. Ausführen:
   ```bash
   export DB_URL=postgresql://postgres:postgres@127.0.0.1:5432/rookraid_test
   node load-schema.js   # Stub, alle Migrationen, Regel-Seed
   node privileges.js    # RLS, search_path, Gäste dürfen keine Spielfunktionen
   node scenario.js      # Konto, eindeutige Namen, Gegnersuche, Rechte, Uhr 5|0, Remis, Bot-Ersatz, Zeitablauf, Verbindungsabbruch, Arena-Grenze, Wartung
   node flow.mjs         # echte Partie bis zum Matt über Regel-Bündel + record_action
   ```
