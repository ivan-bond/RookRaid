-- Meldungen bleiben höchstens ein Jahr (steht so in der Datenschutzerklärung). Sonst wie in 20261107120000_friends.sql:
-- Push-Nachrichten nach 2 Tagen, offene und abgelehnte Anfragen nach 30 Tagen, Zähler für die Grenzen nach 2 Tagen.
create or replace function private.cleanup_social()
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  delete from public.push_outbox where created_at < now() - interval '2 days';
  delete from public.friendships where status = 'pending' and created_at < now() - interval '30 days';
  delete from public.friendships where status = 'declined' and responded_at < now() - interval '30 days';
  delete from public.player_reports where created_at < now() - interval '1 year';
  delete from private.rate_events where at < now() - interval '2 days';
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function private.cleanup_social() from public, anon, authenticated;
