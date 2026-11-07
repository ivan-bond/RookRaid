-- Rook Raid – der Spielstand liegt auf dem Server, App und Browser zeigen immer denselben Stand.
--
-- Bisher hat jedes Gerät seine Sicherung blind über die des Servers geschrieben. Ein iPhone mit einem alten Stand
-- (z. B. nach Abmelden und erneutem Anmelden) konnte so neuere Fortschritte aus dem Browser überschreiben.
--
-- Jetzt trägt jede Sicherung eine Nummer (snapshot_rev). Ein Gerät schreibt nur, wenn es den neuesten Stand kennt
-- (sync_progress mit p_base_rev). Sonst bekommt es den Server-Stand zurück und übernimmt ihn.
-- Sicherungen dürfen jetzt 128 KB groß sein (der Partie-Verlauf geht mit).

alter table public.progress add column if not exists snapshot_rev bigint not null default 0;

-- Ältere App-Fassungen: schreiben weiter ohne Prüfung, zählen aber die Nummer hoch – neuere Geräte merken es.
create or replace function public.backup_progress(p_snapshot jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if pg_column_size(p_snapshot) > 131072 then raise exception 'snapshot_too_large'; end if;
  update progress
     set snapshot = p_snapshot, snapshot_at = now(), snapshot_rev = snapshot_rev + 1, updated_at = now()
   where user_id = auth.uid();
end $$;

-- Sichern mit Versionsprüfung.
-- Antwort: { status: 'saved', rev }  oder  { status: 'stale', progress: {…} } (anderes Gerät war schneller).
-- p_base_rev = null schreibt ohne Prüfung (nur direkt nach dem Anlegen eines Kontos).
create or replace function public.sync_progress(p_snapshot jsonb, p_base_rev bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  cur bigint;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if p_snapshot is null or jsonb_typeof(p_snapshot) <> 'object' then raise exception 'bad_snapshot'; end if;
  if pg_column_size(p_snapshot) > 131072 then raise exception 'snapshot_too_large'; end if;
  select snapshot_rev into cur from progress where user_id = uid for update;
  if cur is null then raise exception 'no_account'; end if;
  if p_base_rev is not null and p_base_rev <> cur then
    return jsonb_build_object('status', 'stale',
      'progress', (select to_jsonb(p) - 'user_id' from progress p where p.user_id = uid));
  end if;
  update progress
     set snapshot = p_snapshot, snapshot_at = now(), snapshot_rev = cur + 1, updated_at = now()
   where user_id = uid;
  return jsonb_build_object('status', 'saved', 'rev', cur + 1);
end $$;

revoke execute on function public.backup_progress(jsonb) from public, anon;
grant execute on function public.backup_progress(jsonb) to authenticated;
revoke execute on function public.sync_progress(jsonb, bigint) from public, anon;
grant execute on function public.sync_progress(jsonb, bigint) to authenticated;
