-- Rook Raid – keine Niederlagen mehr durch doppelt gestartete Bot-Partien.
--
-- Fehler: Startete ein Gerät die Suche zweimal gleichzeitig (Browser im Entwicklungsmodus, schnelles Doppeltippen,
-- Abbrechen während der Server die Partie schon anlegte), entstanden zwei Bot-Partien. Gespielt wurde nur eine,
-- die andere bekam nie ein Lebenszeichen und wurde nach 45 s als „abandoned“ gewertet: −20 Trophäen ohne Partie.
--
-- 1. start_bot_match gibt eine gerade erst angelegte, noch laufende Bot-Partie desselben Spielers zurück, statt eine
--    zweite anzulegen (mit Sperre je Spieler, damit zwei gleichzeitige Aufrufe nicht beide anlegen).
-- 2. maintain_matches: Eine Bot-Partie, zu der das Gerät nie ein Lebenszeichen geschickt hat, wurde nie gespielt –
--    Abbruch ohne Wertung (wie gegen Menschen ohne ersten Zug) statt Niederlage.
-- 3. Einmalige Korrektur: Solche Phantom-Partien der Vergangenheit (nie ein Lebenszeichen, binnen 30 s neben einer
--    anderen Bot-Partie desselben Spielers angelegt) werden zu „aborted“, der Verlust geht zurück aufs Konto.

create or replace function public.start_bot_match(p_rules_version int, p_time_control text, p_deck text[], p_ultimate text,
                                                  p_card jsonb, p_bot_card jsonb, p_bot_deck text[], p_bot_ultimate text,
                                                  p_human_white boolean)
returns table (match_id uuid, is_bot boolean, bot_level text, human_white boolean)
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  existing matches;
  t int;
  lvl text;
  mid uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  perform check_deck(p_deck, p_ultimate);
  perform check_deck(p_bot_deck, p_bot_ultimate);
  -- Ein Aufruf nach dem anderen je Spieler: der zweite sieht die Partie des ersten.
  perform pg_advisory_xact_lock(hashtext('start_bot_match:' || me::text));
  delete from matchmaking_queue where user_id = me;
  select * into existing from matches
   where status = 'active' and not matches.is_bot and (white = me or black = me) and created_at > now() - interval '2 minutes'
   order by created_at desc limit 1;
  if existing.id is not null then
    return query select existing.id, false, null::text, existing.white = me;
    return;
  end if;
  -- Doppelter Start: dieselbe, gerade angelegte Bot-Partie zurückgeben.
  select * into existing from matches
   where status = 'active' and matches.is_bot and (white = me or black = me) and created_at > now() - interval '30 seconds'
   order by created_at desc limit 1;
  if existing.id is not null then
    return query select existing.id, true, existing.bot_level, existing.white = me;
    return;
  end if;
  select trophies into t from progress where user_id = me;
  if t is null then raise exception 'no_account'; end if;
  lvl := bot_level_for(t);
  if p_human_white then
    mid := create_match(me, null, p_card, p_bot_card, p_deck, p_bot_deck, p_ultimate, p_bot_ultimate,
                        p_rules_version, p_time_control, true, lvl);
  else
    mid := create_match(null, me, p_bot_card, p_card, p_bot_deck, p_deck, p_bot_ultimate, p_ultimate,
                        p_rules_version, p_time_control, true, lvl);
  end if;
  return query select mid, true, lvl, p_human_white;
end $$;

-- Hat das Gerät zu dieser Bot-Partie je ein Lebenszeichen geschickt? (create_match legt den Eintrag mit now() an.)
create or replace function public.bot_match_started(p_match uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_presence pr join matches m on m.id = pr.match_id
     where pr.match_id = p_match and pr.user_id = coalesce(m.white, m.black) and pr.seen_at > m.created_at + interval '1 second')
$$;

create or replace function public.maintain_matches()
returns int language plpgsql security definer set search_path = public as $$
declare m matches; n int := 0;
begin
  delete from matchmaking_queue where last_seen_at < now() - interval '30 seconds';
  for m in select * from matches where status = 'active' loop
    if m.is_bot then
      -- Bot-Partie: Mensch 45 s ohne Lebenszeichen (App beendet, kein Netz) → Niederlage, wie gegen Menschen (E6).
      -- Nie ein Lebenszeichen: Die Partie wurde nie gespielt (doppelter Start) → Abbruch ohne Wertung.
      -- Rückfall ohne Presence-Eintrag: nach 3 Stunden.
      if coalesce(silent_seconds(m.id, coalesce(m.white, m.black)), 0) > 45 or m.created_at < now() - interval '3 hours' then
        if bot_match_started(m.id) then
          perform finish_match(m.id, 'abandoned', case when m.white is null then 'white' else 'black' end);
        else
          perform finish_match(m.id, 'aborted', null);
        end if;
        n := n + 1;
      end if;
    elsif coalesce(silent_seconds(m.id, m.white), 0) > 45 and coalesce(silent_seconds(m.id, m.black), 0) > 45 then
      perform finish_match(m.id, 'aborted', null); n := n + 1;       -- beide weg (z. B. Server-Störung): ohne Wertung
    elsif coalesce(silent_seconds(m.id, m.white), 0) > 45 then
      perform finish_match(m.id, 'abandoned', 'black'); n := n + 1;
    elsif coalesce(silent_seconds(m.id, m.black), 0) > 45 then
      perform finish_match(m.id, 'abandoned', 'white'); n := n + 1;
    elsif (m.action_count = 0 and now() > m.first_move_deadline)
       or (m.action_count = 1 and now() > m.last_action_at + interval '30 seconds') then
      perform finish_match(m.id, 'aborted', null); n := n + 1;
    elsif remaining_ms(m) <= 0 then
      perform finish_match(m.id, 'timeout', case when m.turn = 'white' then 'black' else 'white' end); n := n + 1;
    end if;
  end loop;
  return n;
end $$;

revoke execute on function public.bot_match_started(uuid) from public, anon, authenticated;

-- Einmalige Korrektur der Phantom-Partien.
do $$
declare r record;
begin
  for r in
    select m.id, coalesce(m.white, m.black) as human,
           case when m.white is not null then m.trophy_delta_white else m.trophy_delta_black end as delta
      from matches m
     where m.is_bot and m.status = 'finished' and m.result = 'abandoned'
       and not bot_match_started(m.id)
       and exists (select 1 from matches o
                    where o.id <> m.id and o.is_bot
                      and coalesce(o.white, o.black) = coalesce(m.white, m.black)
                      and abs(extract(epoch from o.created_at - m.created_at)) < 30)
  loop
    update progress
       set trophies = trophies - least(0, coalesce(r.delta, 0)),
           best_trophies = greatest(best_trophies, trophies - least(0, coalesce(r.delta, 0))),
           online_losses = greatest(0, online_losses - 1),
           updated_at = now()
     where user_id = r.human;
    update matches
       set status = 'aborted', result = 'aborted', winner_color = null, trophy_delta_white = null, trophy_delta_black = null
     where id = r.id;
  end loop;
end $$;
