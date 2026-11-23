-- Rook Raid – rated play stays 5 | 0.
--
-- 20261123120000_friend_match_time.sql taught tc_base_ms the friendly time controls (3 | 2, 5 | 3, 10 | 5). find_match and
-- start_bot_match only checked tc_base_ms, so rated matchmaking and rated bot games suddenly accepted those clocks too.
-- Both now accept only 'blitz5' again (the apps always send it); the bodies are otherwise unchanged.

create or replace function public.find_match(p_rules_version int, p_time_control text, p_deck text[],
                                             p_ultimate text, p_card jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  my_trophies int;
  mine matchmaking_queue;
  other matchmaking_queue;
  my_window int;
  existing uuid;
  me_white boolean;
  mid uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_time_control is distinct from 'blitz5' then raise exception 'bad_time_control'; end if;  -- rated: 5 | 0 only
  perform check_deck(p_deck, p_ultimate);
  if not exists (select 1 from rules_config where version = p_rules_version and active) then
    raise exception 'rules_outdated';
  end if;
  -- Hat uns schon jemand gefunden? (Der Gegner legt die Partie an und löscht beide Einträge.)
  select id into existing from matches
   where status = 'active' and not is_bot and (white = me or black = me) and created_at > now() - interval '2 minutes'
   order by created_at desc limit 1;
  if existing is not null then return existing; end if;

  select trophies into my_trophies from progress where user_id = me;
  if my_trophies is null then raise exception 'no_account'; end if;

  insert into matchmaking_queue as q (user_id, trophies, rules_version, time_control, deck, ultimate, card)
  values (me, my_trophies, p_rules_version, p_time_control, p_deck, p_ultimate, p_card)
  on conflict (user_id) do update set trophies = excluded.trophies, rules_version = excluded.rules_version,
    time_control = excluded.time_control, deck = excluded.deck, ultimate = excluded.ultimate,
    card = excluded.card, last_seen_at = now();

  select * into mine from matchmaking_queue where user_id = me for update;
  my_window := least(400, 100 + 50 * (extract(epoch from now() - mine.enqueued_at)::int / 2));

  select * into other from matchmaking_queue q
   where q.user_id <> me
     and q.rules_version = mine.rules_version
     and q.time_control = mine.time_control
     and q.last_seen_at > now() - interval '6 seconds'           -- nur Spieler, die gerade noch suchen
     and abs(q.trophies - mine.trophies) <=
         greatest(my_window, least(400, 100 + 50 * (extract(epoch from now() - q.enqueued_at)::int / 2)))
   order by q.enqueued_at
   limit 1
   for update skip locked;
  if other.user_id is null then return null; end if;

  me_white := random() < 0.5;
  if me_white then
    mid := create_match(me, other.user_id, mine.card, other.card, mine.deck, other.deck, mine.ultimate, other.ultimate,
                        mine.rules_version, mine.time_control, false, null);
  else
    mid := create_match(other.user_id, me, other.card, mine.card, other.deck, mine.deck, other.ultimate, mine.ultimate,
                        mine.rules_version, mine.time_control, false, null);
  end if;
  delete from matchmaking_queue where user_id in (me, other.user_id);
  return mid;
end $$;

create or replace function public.start_bot_match(p_rules_version int, p_time_control text, p_deck text[], p_ultimate text,
                                                  p_card jsonb, p_bot_card jsonb, p_bot_deck text[], p_bot_ultimate text,
                                                  p_human_white boolean)
returns table (match_id uuid, is_bot boolean, bot_level text, human_white boolean,
               bot_player uuid, bot_card jsonb, bot_deck text[], bot_ultimate text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := auth.uid();
  existing matches;
  t int;
  lvl text;
  mid uuid;
  pick uuid;
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if p_time_control is distinct from 'blitz5' then raise exception 'bad_time_control'; end if;  -- rated: 5 | 0 only
  perform check_deck(p_deck, p_ultimate);
  perform check_deck(p_bot_deck, p_bot_ultimate);
  perform pg_advisory_xact_lock(hashtext('start_bot_match:' || me::text));
  delete from matchmaking_queue where user_id = me;
  select * into existing from matches m
   where m.status = 'active' and not m.is_bot and (m.white = me or m.black = me) and m.created_at > now() - interval '2 minutes'
   order by m.created_at desc limit 1;
  if existing.id is not null then
    return query select existing.id, false, null::text, existing.white = me, null::uuid, null::jsonb, null::text[], null::text;
    return;
  end if;
  -- Double start: return the bot game that was just created.
  select * into existing from matches m
   where m.status = 'active' and m.is_bot and m.rated and (m.white = me or m.black = me) and m.created_at > now() - interval '30 seconds'
   order by m.created_at desc limit 1;
  if existing.id is not null then
    return query select existing.id, true, existing.bot_level, existing.white = me, existing.bot_player,
      case when existing.white = me then existing.black_card else existing.white_card end,
      array(select jsonb_array_elements_text(existing.setup->'decks'->(case when existing.white = me then 'black' else 'white' end))),
      existing.setup->'ultimates'->>(case when existing.white = me then 'black' else 'white' end);
    return;
  end if;
  select trophies into t from progress where user_id = me;
  if t is null then raise exception 'no_account'; end if;

  -- Recent opponents last; among the others mostly chance (a closer bot is only a little more likely).
  select b.user_id into pick
    from private.bot_players b join progress g on g.user_id = b.user_id
   where abs(g.trophies - t) <= 300
     and private.bot_online(b.user_id)
     and not private.blocked_between(me, b.user_id)
     and not exists (select 1 from matches x where x.status = 'active' and x.bot_player = b.user_id)
   order by (b.user_id in (select r.bot_player from matches r
                            where (r.white = me or r.black = me) and r.bot_player is not null
                            order by r.created_at desc limit 3)),
            abs(g.trophies - t) * 0.3 + random() * 250
   limit 1;
  if pick is not null then
    mid := private.create_bot_player_match(me, pick, p_card, p_deck, p_ultimate, p_rules_version, p_human_white, true);
    return query select m.id, true, m.bot_level, p_human_white, pick,
      case when p_human_white then m.black_card else m.white_card end,
      array(select jsonb_array_elements_text(m.setup->'decks'->(case when p_human_white then 'black' else 'white' end))),
      m.setup->'ultimates'->>(case when p_human_white then 'black' else 'white' end)
      from matches m where m.id = mid;
    return;
  end if;

  lvl := bot_level_for(t);
  if p_human_white then
    mid := create_match(me, null, p_card, p_bot_card, p_deck, p_bot_deck, p_ultimate, p_bot_ultimate,
                        p_rules_version, p_time_control, true, lvl);
  else
    mid := create_match(null, me, p_bot_card, p_card, p_bot_deck, p_deck, p_bot_ultimate, p_ultimate,
                        p_rules_version, p_time_control, true, lvl);
  end if;
  return query select mid, true, lvl, p_human_white, null::uuid, p_bot_card, p_bot_deck, p_bot_ultimate;
end $$;
revoke execute on function public.start_bot_match(int, text, text[], text, jsonb, jsonb, text[], text, boolean) from public, anon;
grant execute on function public.start_bot_match(int, text, text[], text, jsonb, jsonb, text[], text, boolean) to authenticated;
