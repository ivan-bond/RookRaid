-- Rook Raid – Migration 4: leere anonyme Anmeldungen aufräumen.
-- Die App meldet sich schon zur Namensprüfung anonym an (name_available braucht eine Anmeldung). Wer danach
-- kein Konto anlegt (setup_account), hinterlässt einen Auth-Nutzer ohne Profil. Nach 24 Stunden wird er gelöscht.
-- Eigenes, nicht über die API erreichbares Schema – nur der Wartungsjob ruft die Funktion auf.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.cleanup_anonymous_users()
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  delete from auth.users u
   where u.is_anonymous
     and u.created_at < now() - interval '24 hours'
     and not exists (select 1 from public.profiles p where p.id = u.id);
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function private.cleanup_anonymous_users() from public, anon, authenticated;

-- stündlich (Minute 17)
select cron.unschedule(jobid) from cron.job where jobname = 'rookraid-cleanup-anonymous';
select cron.schedule('rookraid-cleanup-anonymous', '17 * * * *', $$select private.cleanup_anonymous_users()$$);
