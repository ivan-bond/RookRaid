-- Rook Raid – friendly matches with a chosen time control.
--
-- Until now every friendly match was 5 | 0 (blitz5). The inviter now picks 3 | 2, 5 | 0, 5 | 3 or 10 | 5 before
-- sending the challenge; the invite stores it, the invitee sees it, and the match starts with that clock.
-- Rated matches (matchmaking and stand-in bots) stay 5 | 0. Older apps keep working: without a time control
-- the invite is 5 | 0 as before.

-- 1. Time controls: base time and increment per move (same names and values as TimeControl in the apps).
create or replace function public.tc_base_ms(p text) returns int language sql immutable set search_path = '' as $$
  select case p when 'blitz5' then 300000 when 'blitz3' then 180000 when 'rapid5' then 300000 when 'rapid10' then 600000 end
$$;
create or replace function public.tc_increment_ms(p text) returns int language sql immutable set search_path = '' as $$
  select case p when 'blitz5' then 0 when 'blitz3' then 2000 when 'rapid5' then 3000 when 'rapid10' then 5000 end
$$;

-- 2. The invite remembers the time control.
alter table public.match_invites add column if not exists time_control text not null default 'blitz5';
alter table public.match_invites drop constraint if exists match_invites_time_control_check;
alter table public.match_invites add constraint match_invites_time_control_check check (public.tc_base_ms(time_control) is not null);

-- Gives a just-created match the invite's clock (create_match / create_bot_player_match start with 5 | 0).
create or replace function private.set_match_clock(p_match uuid, p_tc text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_tc is null or p_tc = 'blitz5' then return; end if;
  update public.matches
     set time_control = p_tc, clock_white_ms = public.tc_base_ms(p_tc), clock_black_ms = public.tc_base_ms(p_tc),
         increment_ms = public.tc_increment_ms(p_tc)
   where id = p_match and action_count = 0;
end $$;
revoke execute on function private.set_match_clock(uuid, text) from public, anon, authenticated;

-- 3. Invite with a time control (new last parameter, default 5 | 0 for older apps).
drop function if exists public.invite_friend_match(uuid, int, text[], text, jsonb);
create function public.invite_friend_match(p_user uuid, p_rules_version int, p_deck text[], p_ultimate text, p_card jsonb,
                                           p_time_control text default 'blitz5')
returns uuid language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  tc text := coalesce(p_time_control, 'blitz5');
  new_id uuid;
begin
  perform check_deck(p_deck, p_ultimate);
  if tc_base_ms(tc) is null then raise exception 'bad_time_control'; end if;
  if not exists (select 1 from rules_config where version = p_rules_version and active) then raise exception 'rules_outdated'; end if;
  if p_user is null or private.relation(me, p_user) <> 'friend' or private.blocked_between(me, p_user) then
    raise exception 'not_friends';
  end if;
  if not private.rate_ok(me, 'match_invite', 30, interval '1 hour') then raise exception 'too_many_requests'; end if;
  update match_invites set status = 'cancelled', responded_at = now() where inviter = me and status = 'pending';
  insert into match_invites (inviter, invitee, rules_version, deck, ultimate, card, time_control)
  values (me, p_user, p_rules_version, p_deck, p_ultimate, p_card, tc)
  returning match_invites.id into new_id;
  if not private.is_bot(p_user) then
    insert into push_outbox (recipient, actor, kind, actor_name)
    select p_user, me, 'match_invite', p.display_name from profiles p where p.id = me;
  end if;
  return new_id;
end $$;

-- 4. State of an invite (bot players accept after 3 seconds) – now with the invite's clock. Reply: { status, match_id, time_control }
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
    perform private.set_match_clock(mid, inv.time_control);
    update match_invites set status = 'accepted', match_id = mid, responded_at = now() where id = inv.id;
    inv.status := 'accepted'; inv.match_id := mid;
  end if;
  return jsonb_build_object('status', inv.status, 'match_id', inv.match_id, 'time_control', inv.time_control);
end $$;

-- 5. Accepting starts the match with the invite's clock.
create or replace function public.answer_friend_match(p_invite uuid, p_accept boolean, p_rules_version int,
                                                      p_deck text[], p_ultimate text, p_card jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  inv match_invites;
  mid uuid;
begin
  select * into inv from match_invites where id = p_invite and invitee = me for update;
  if inv.id is null then raise exception 'not_found'; end if;
  if inv.status <> 'pending' or inv.created_at < now() - interval '2 minutes' then raise exception 'invite_gone'; end if;
  if not coalesce(p_accept, false) then
    update match_invites set status = 'declined', responded_at = now() where id = inv.id;
    return null;
  end if;
  perform check_deck(p_deck, p_ultimate);
  if p_rules_version <> inv.rules_version then raise exception 'rules_outdated'; end if;
  if private.blocked_between(me, inv.inviter) then raise exception 'invite_gone'; end if;
  if random() < 0.5 then
    mid := create_match(inv.inviter, me, inv.card, p_card, inv.deck, p_deck, inv.ultimate, p_ultimate,
                        inv.rules_version, inv.time_control, false, null);
  else
    mid := create_match(me, inv.inviter, p_card, inv.card, p_deck, inv.deck, p_ultimate, inv.ultimate,
                        inv.rules_version, inv.time_control, false, null);
  end if;
  update matches set rated = false where id = mid;
  update match_invites set status = 'accepted', match_id = mid, responded_at = now() where id = inv.id;
  return mid;
end $$;

-- 6. Open invites to me now say which clock they are for.
create or replace function public.touch_online()
returns jsonb language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  update profiles set last_seen_at = now()
   where id = me and (last_seen_at is null or last_seen_at < now() - interval '10 seconds');
  return jsonb_build_object('invites', coalesce((
    select jsonb_agg(jsonb_build_object('id', i.id, 'user_id', p.id, 'display_name', p.display_name, 'avatar', p.avatar,
                                        'frame', p.frame, 'created_at', i.created_at, 'time_control', i.time_control)
                     order by i.created_at desc)
      from match_invites i join profiles p on p.id = i.inviter
     where i.invitee = me and i.status = 'pending' and i.created_at > now() - interval '2 minutes'
       and not private.blocked_between(me, i.inviter)), '[]'::jsonb));
end $$;

-- ───────────────────────── Rights ─────────────────────────
do $$
declare f text;
begin
  foreach f in array array[
    'touch_online()', 'invite_friend_match(uuid, int, text[], text, jsonb, text)', 'friend_match_status(uuid)',
    'answer_friend_match(uuid, boolean, int, text[], text, jsonb)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
