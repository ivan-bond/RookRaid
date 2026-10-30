-- Rook Raid – Wartungsjob (Migration 2): bricht Partien ohne ersten Zug ab, wertet abgelaufene Uhren,
-- räumt die Warteschlange und schließt nie gemeldete Bot-Partien. Die Geräte melden Zeitabläufe zusätzlich
-- sofort (claim_timeout) – der Job ist das Sicherheitsnetz, wenn beide offline sind.
-- Voraussetzung: Erweiterung pg_cron (Dashboard → Database → Extensions → pg_cron, oder diese Zeile).
create extension if not exists pg_cron with schema pg_catalog;

-- alle 30 Sekunden (pg_cron ≥ 1.5; bei älteren Fassungen '* * * * *' = jede Minute)
select cron.unschedule(jobid) from cron.job where jobname = 'rookraid-maintain';
select cron.schedule('rookraid-maintain', '30 seconds', $$select public.maintain_matches()$$);
