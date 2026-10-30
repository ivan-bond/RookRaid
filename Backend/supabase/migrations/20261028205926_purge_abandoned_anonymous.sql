-- Rook Raid – anonyme Anmeldungen ohne Konto aufräumen
-- Die App prüft Spielernamen mit name_available; dafür muss man angemeldet sein. Wer den Dialog abbricht,
-- hinterlässt eine anonyme Auth-Zeile ohne Profil. Die App löscht sie sofort; dieser Job ist das Netz.
create or replace function public.purge_abandoned_anonymous()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare n int := 0;
begin
  delete from auth.users u
   where u.is_anonymous
     and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '1 hour'
     and not exists (select 1 from public.profiles p where p.id = u.id);
  get diagnostics n = row_count;
  return n;
end;
$$;

revoke execute on function public.purge_abandoned_anonymous() from public, anon, authenticated;
grant execute on function public.purge_abandoned_anonymous() to service_role;

select cron.unschedule(jobid) from cron.job where jobname = 'rookraid-purge-anon';
select cron.schedule('rookraid-purge-anon', '*/15 * * * *', $$select public.purge_abandoned_anonymous()$$);
