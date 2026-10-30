# Regel-Port (JavaScript)

Dieselben Spielregeln wie die Swift-Engine der App – für Regeltests und zur Zugprüfung auf dem Server.

- `engine.js` – Regeln (aus dem Balance-Simulator).
- `core.js` – Kern ohne Dateizugriff: Regeln aus einem Objekt (`applyRules`), Aktionen im Draht-Format (`apply`), ganze Partien aus der Grundstellung (`initialFromRecord`, `replay`).
- `rules.js` – Node-Hülle: lädt `RookRaid/Engine/rookraid-rules.json` (`loadRules`).
- `golden-cases.json` – Testfälle (Stellung als FEN oder `start: "initial"` mit Decks und Ultimates).
- `node make-golden.js` – erzeugt `RookRaid/Engine/rookraid-golden.json` mit den erwarteten Ergebnissen.
- `node check-golden.js` – prüft den Port gegen die Erwartungen.
- `node build-server.js` – bündelt `engine.js` + `core.js` als ES-Modul für Supabase Edge Functions (`Backend/supabase/functions/_shared/rookraid-rules.mjs`).
- `node check-server.mjs` – prüft das Bündel gegen dieselben Fälle.
- `node seed-rules.js` – schreibt `Backend/supabase/seed/rules.sql` (`KEEP_OLD=1`: ältere Versionen bleiben aktiv).

Die App führt dieselben Fälle im Debug-Build aus (Einstellungen → Entwickler → Regeltests).
