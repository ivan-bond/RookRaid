-- Rook Raid – Trophäen nur noch aus gewerteten Partien.
--
-- 1. setup_account übernimmt keine Gast-Trophäen mehr. Ohne Konto gibt es keine gewerteten Partien
--    (Kampf! startet erst mit Konto), ein neues Konto beginnt also bei 0. Vorher durfte das Gerät bis zu 1 500 melden.
--
-- 2. adopt_device_trophies glaubt dem Gerät nicht mehr blind. Zurück gibt es nur, was der Server nachweislich
--    wegen des alten Taktik-Mana-Fehlers verloren hat: Eine abgelehnte Bot-Partie blieb offen und wurde nach 45 s
--    als „abandoned“ (Niederlage) gewertet. Je solcher Partie höchstens der Verlust zurück plus ein Sieg (+40).
--    Nur Partien, die vor diesem Fix endeten – neue Abbrüche bringen nichts mehr. Weiterhin einmal je Konto, nie nach unten.

create or replace function public.setup_account(p_snapshot jsonb, p_card jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  if exists (select 1 from progress where user_id = uid) then
    return jsonb_build_object('status', 'existing',
      'progress', (select to_jsonb(p) - 'user_id' from progress p where p.user_id = uid),
      'name', (select display_name from profiles where id = uid));
  end if;
  -- Der Name ist eindeutig (E8): Die App fragt ihn vorher ab und prüft ihn mit name_available.
  if not valid_name(p_card->>'name') then raise exception 'name_invalid'; end if;
  if not name_available(p_card->>'name') then raise exception 'name_taken'; end if;
  insert into profiles (id, guest_id, display_name, avatar, frame, title, piece_set, level)
  values (uid,
          nullif(p_snapshot->>'guestId', '')::uuid,
          p_card->>'name',
          coalesce(p_card->>'avatar', 'knight'), p_card->>'frame', p_card->>'title', p_card->>'pieceSet',
          greatest(1, least(500, coalesce((p_card->>'level')::int, 1))))
  on conflict (id) do nothing;
  -- Trophäen gibt es nur aus Partien, die der Server gewertet hat: Start bei 0.
  insert into progress (user_id, trophies, best_trophies, snapshot, snapshot_at)
  values (uid, 0, 0, p_snapshot, now());
  return jsonb_build_object('status', 'created',
    'progress', (select to_jsonb(p) - 'user_id' from progress p where p.user_id = uid));
end $$;

create or replace function public.adopt_device_trophies(p_trophies int)
returns int language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  cur int;
  owed int;
  t int;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  select trophies into cur from progress where user_id = uid for update;
  if cur is null then return 0; end if;
  -- Nachweisbar verlorene Bot-Partien vor dem Fix: eigener Verlust zurück + höchstens ein Sieg.
  select coalesce(sum(greatest(0, -coalesce(case when m.white = uid then m.trophy_delta_white else m.trophy_delta_black end, 0)) + 40), 0)
    into owed
    from matches m
   where m.is_bot and m.result = 'abandoned' and (m.white = uid or m.black = uid)
     and m.ended_at < timestamptz '2026-11-06 00:00:00+00';
  t := least(greatest(0, coalesce(p_trophies, 0)), cur + owed);
  update progress
     set trophies = greatest(trophies, t),
         best_trophies = greatest(best_trophies, t),
         device_trophies_adopted = true,
         updated_at = now()
   where user_id = uid and not device_trophies_adopted;
  select trophies into cur from progress where user_id = uid;
  return cur;
end $$;

revoke execute on function public.adopt_device_trophies(int) from public, anon;
grant execute on function public.adopt_device_trophies(int) to authenticated;
revoke execute on function public.setup_account(jsonb, jsonb) from public, anon;
grant execute on function public.setup_account(jsonb, jsonb) to authenticated;
