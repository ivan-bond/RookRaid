-- Rook Raid – bot players: more variety in rated games, and they always answer.
--
-- 1. Rated games without a human: the bot player is now picked much more at random within ±300 trophies
--    (before, the closest one almost always won, so the same bot came up again and again). The bot players of
--    your last three games are only used when nobody else is available.
-- 2. Friend requests to a bot player are always accepted after about a minute (the job runs every minute),
--    also outside his online hours.
-- 3. Friendly-match challenges to a bot player are always accepted after 3 seconds, also when he is offline
--    or already playing (the game runs on the challenger's device).

-- ───────────────────────── 2. Friend requests ─────────────────────────
update private.bot_players set accepts_friends = true, accept_minutes = 1, accepts_matches = true;

create or replace function private.run_bot_players()
returns int language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  for r in
    select f.requester, f.addressee
      from public.friendships f join private.bot_players b on b.user_id = f.addressee
     where f.status = 'pending' and f.created_at > now() - interval '30 days'
       and f.created_at + interval '1 minute' <= now()
  loop
    begin
      perform private.lock_pair(r.requester, r.addressee);
      perform private.accept_friendship(r.requester, r.addressee);
      n := n + 1;
    exception when others then
      null;   -- e.g. friend_limit: the request stays
    end;
  end loop;
  perform private.dispatch_bot_push();
  return n;
end $$;
revoke execute on function private.run_bot_players() from public, anon, authenticated;

-- ───────────────────────── 3. Friendly-match challenges ─────────────────────────
-- State of an invite (for both sides). Expires after 2 minutes. A bot player accepts after 3 seconds – always.
-- Reply: { status, match_id }
create or replace function public.friend_match_status(p_invite uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  inv match_invites;
  mid uuid;
begin
  select * into inv from match_invites where id = p_invite and me in (inviter, invitee) for update;
  if inv.id is null then raise exception 'not_found'; end if;
  if inv.status = 'pending' and inv.created_at < now() - interval '2 minutes' then
    update match_invites set status = 'expired', responded_at = now() where id = inv.id;
    inv.status := 'expired';
  end if;
  if inv.status = 'pending' and private.is_bot(inv.invitee) and now() >= inv.created_at + interval '3 seconds' then
    mid := private.create_bot_player_match(inv.inviter, inv.invitee, inv.card, inv.deck, inv.ultimate,
                                           inv.rules_version, random() < 0.5, false);
    update match_invites set status = 'accepted', match_id = mid, responded_at = now() where id = inv.id;
    inv.status := 'accepted'; inv.match_id := mid;
  end if;
  return jsonb_build_object('status', inv.status, 'match_id', inv.match_id);
end $$;

-- ───────────────────────── 1. Variety in rated bot games ─────────────────────────
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
