-- Trophäen hängen am Gegner. Arenen sind keine Untergrenze mehr: nur 0 bleibt stehen.
-- Dieselbe Rechnung wie TrophyStake in der App.
-- Gleich stark: Sieg +20, Remis 0, Niederlage −20.
-- Je 100 Trophäen Vorsprung des Gegners +4 auf den Sieg und −4 auf den Verlust, begrenzt auf +8…+40 und −8…−40.

create or replace function public.trophy_delta(p_mine int, p_opponent int, p_outcome text)
returns int
language plpgsql
immutable
set search_path = ''
as $$
declare
  mine int := greatest(0, coalesce(p_mine, 0));
  opp int := greatest(0, coalesce(p_opponent, mine));
  gap int := least(800, greatest(-800, opp - mine));
  shift int := gap / 100;
  d int;
begin
  if p_outcome = 'win' then
    d := least(40, greatest(8, 20 + shift * 4));
  elsif p_outcome = 'draw' then
    d := least(12, greatest(-12, shift * 2));
  else
    d := least(-8, greatest(-40, -(20 - shift * 4)));
  end if;
  if mine + d < 0 then
    d := -mine;
  end if;
  return d;
end;
$$;

-- Mitte der Bot-Stufe, wie BotLevel.rating (trophyStart + 100).
create or replace function public.bot_rating(p_level text)
returns int
language sql
immutable
set search_path = ''
as $$
  select case p_level
    when 'easy' then 100
    when 'apprentice' then 300
    when 'medium' then 500
    when 'jester' then 700
    when 'knight' then 900
    when 'tactician' then 1100
    when 'shadow' then 1300
    when 'baron' then 1500
    when 'hard' then 1700
    when 'frost' then 1900
    when 'sphinx' then 2100
    when 'queen' then 2300
    else 100
  end
$$;

create or replace function public.apply_result(p_user uuid, p_outcome text, p_opponent int)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare cur int; d int;
begin
  select trophies into cur from progress where user_id = p_user for update;
  if cur is null then return 0; end if;
  d := trophy_delta(cur, coalesce(p_opponent, cur), p_outcome);
  update progress set
    trophies = cur + d,
    best_trophies = greatest(best_trophies, cur + d),
    online_wins = online_wins + (p_outcome = 'win')::int,
    online_losses = online_losses + (p_outcome = 'loss')::int,
    online_draws = online_draws + (p_outcome = 'draw')::int,
    updated_at = now()
  where user_id = p_user;
  return d;
end;
$$;

create or replace function public.finish_match(p_match uuid, p_result text, p_winner text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  m matches;
  dw int;
  db int;
  white_faces int;
  black_faces int;
begin
  select * into m from matches where id = p_match for update;
  if m.id is null then raise exception 'match_not_found'; end if;
  if m.status <> 'active' then return jsonb_build_object('status', m.status, 'already', true); end if;
  if p_result = 'aborted' then
    update matches set status = 'aborted', result = 'aborted', ended_at = now() where id = p_match;
    return jsonb_build_object('status', 'aborted');
  end if;
  -- Wert des Gegners zum Partiebeginn. Ein Bot hat keinen Fortschritt: seine Stufenmitte.
  white_faces := coalesce(m.trophies_black,
    case when m.black is null then bot_rating(m.bot_level)
         else (select trophies from progress where user_id = m.black) end);
  black_faces := coalesce(m.trophies_white,
    case when m.white is null then bot_rating(m.bot_level)
         else (select trophies from progress where user_id = m.white) end);
  if m.white is not null then
    dw := apply_result(m.white, case when p_winner is null then 'draw' when p_winner = 'white' then 'win' else 'loss' end, white_faces);
  end if;
  if m.black is not null then
    db := apply_result(m.black, case when p_winner is null then 'draw' when p_winner = 'black' then 'win' else 'loss' end, black_faces);
  end if;
  update matches set status = 'finished', result = p_result, winner_color = p_winner, draw_offer_by = null,
                     trophy_delta_white = dw, trophy_delta_black = db, ended_at = now()
  where id = p_match;
  return jsonb_build_object('status', 'finished', 'result', p_result, 'winner', p_winner,
                            'trophy_delta_white', dw, 'trophy_delta_black', db);
end;
$$;

drop function if exists public.apply_result(uuid, text);

revoke execute on function public.trophy_delta(int, int, text) from public, anon, authenticated;
revoke execute on function public.bot_rating(text) from public, anon, authenticated;
revoke execute on function public.apply_result(uuid, text, int) from public, anon, authenticated;
grant execute on function public.apply_result(uuid, text, int) to service_role;
grant execute on function public.finish_match(uuid, text, text) to service_role;
