-- Rook Raid – einmalige Übernahme von Geräte-Trophäen.
-- Bis v0.9.36 gab die App für Taktiken +1 Mana, das der Regel-Port auf dem Server nicht kennt. Bot-Partien, in denen
-- dieses Mana eine Karte bezahlt hat, lehnte finish-bot-match als „illegal_action“ ab; die App hat die Trophäen dann
-- nur lokal gutgeschrieben. Damit App und Browser denselben Stand zeigen, darf jedes Konto seinen Gerätestand
-- genau einmal übernehmen – gedeckelt wie die Gast-Trophäen in setup_account (1 500), nie nach unten.
alter table public.progress add column if not exists device_trophies_adopted boolean not null default false;

create or replace function public.adopt_device_trophies(p_trophies int)
returns int language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); t int; cur int;
begin
  if uid is null then raise exception 'not_authenticated'; end if;
  t := greatest(0, least(coalesce(p_trophies, 0), 1500));
  update progress
     set trophies = greatest(trophies, t),
         best_trophies = greatest(best_trophies, t),
         device_trophies_adopted = true,
         updated_at = now()
   where user_id = uid and not device_trophies_adopted;
  select trophies into cur from progress where user_id = uid;
  return coalesce(cur, 0);
end $$;

revoke execute on function public.adopt_device_trophies(int) from public, anon;
grant execute on function public.adopt_device_trophies(int) to authenticated;
