-- Verlauf im Freundesprofil: die letzten Partien gegeneinander (neueste zuerst).
-- Dieselben Partien wie die Bilanz in friend_profile: Mensch gegen Mensch (gewertet und Freundschaftsspiele)
-- und Partien gegen diesen Bot-Spieler. Nur unter Freunden. Ergebnis aus meiner Sicht.

create or replace function public.friend_matches(p_user uuid, p_limit int default 20)
returns jsonb language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
begin
  if private.relation(me, p_user) <> 'friend' then raise exception 'not_friends'; end if;
  return coalesce((
    select jsonb_agg(s.item order by s.at desc)
      from (
        select coalesce(m.ended_at, m.created_at) as at,
               jsonb_build_object(
                 'match_id', m.id,
                 'ended_at', coalesce(m.ended_at, m.created_at),
                 'result', case when m.winner_color is null then 'draw'
                                when m.winner_color = c.mine then 'win' else 'loss' end,
                 'reason', m.result,
                 'rated', m.rated,
                 'trophy_delta', case when c.mine = 'white' then m.trophy_delta_white else m.trophy_delta_black end,
                 'time_control', m.time_control,
                 'color', c.mine) as item
          from matches m
          cross join lateral (select case when m.white = me then 'white' else 'black' end as mine) c
         where m.status = 'finished'
           and (((m.white = me and m.black = p_user) or (m.white = p_user and m.black = me))
                or (m.is_bot and m.bot_player = p_user and me in (m.white, m.black)))
         order by coalesce(m.ended_at, m.created_at) desc
         limit greatest(1, least(coalesce(p_limit, 20), 50))
      ) s), '[]'::jsonb);
end $$;

revoke execute on function public.friend_matches(uuid, int) from public, anon;
grant execute on function public.friend_matches(uuid, int) to authenticated;
