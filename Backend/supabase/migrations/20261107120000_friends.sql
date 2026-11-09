-- Rook Raid – Freunde (Phase 1).
--
-- Spieler finden sich über den exakten Spielernamen oder einen Freundescode (6 Zeichen, z. B. 7KQ2MX), den der
-- Einladungslink trägt. Anfragen muss der andere annehmen. Blockieren und Melden gibt es ab der ersten Anfrage.
-- Neue Anfragen und angenommene Anfragen landen in push_outbox; die Edge Function push-dispatch verschickt sie.
--
-- Grundsatz wie bisher: Die Tabellen sind für die App gesperrt, alles läuft über Server-Funktionen.
-- Dazu: Profile sind nicht mehr für alle lesbar (nur das eigene). Sonst ließe sich die Namenssuche umgehen,
-- indem man einfach alle Profile abfragt. Gegnerkarten stehen weiter in matches.white_card/black_card.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ───────────────────────── Profile: nur das eigene lesen ─────────────────────────
drop policy if exists "profiles_read" on public.profiles;
create policy "profiles_read" on public.profiles for select using ((select auth.uid()) = id);

-- ───────────────────────── Freundescode ─────────────────────────
-- Ohne 0/O und 1/I, damit man ihn vorlesen und abtippen kann. 32 Zeichen, 6 Stellen: rund eine Milliarde Codes.
create or replace function private.new_friend_code()
returns text language plpgsql volatile security definer set search_path = '' as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  b bytea;
  code text;
begin
  loop
    b := uuid_send(gen_random_uuid());
    code := '';
    for i in 0..5 loop
      code := code || substr(alphabet, (get_byte(b, i) % 32) + 1, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where friend_code = code);
  end loop;
  return code;
end $$;
revoke execute on function private.new_friend_code() from public, anon, authenticated;

alter table public.profiles add column if not exists friend_code text;
-- Bestehende Konten: einzeln, damit jede Prüfung die schon vergebenen Codes sieht (ein einziges UPDATE sieht sie nicht).
do $$
declare r record;
begin
  for r in select id from public.profiles where friend_code is null loop
    update public.profiles set friend_code = private.new_friend_code() where id = r.id;
  end loop;
end $$;
alter table public.profiles alter column friend_code set default private.new_friend_code();
alter table public.profiles alter column friend_code set not null;
create unique index if not exists profiles_friend_code on public.profiles (friend_code);

-- ───────────────────────── Tabellen ─────────────────────────
-- Eine Zeile je Paar (gleich, wer gefragt hat). pending → accepted, oder declined (der Absender erfährt es nicht).
create table if not exists public.friendships (
  requester    uuid not null references public.profiles(id) on delete cascade,
  addressee    uuid not null references public.profiles(id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  primary key (requester, addressee),
  check (requester <> addressee)
);
create unique index if not exists friendships_pair on public.friendships
  (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee on public.friendships (addressee);
alter table public.friendships enable row level security;
revoke all on public.friendships from anon, authenticated;

create table if not exists public.player_blocks (
  blocker    uuid not null references public.profiles(id) on delete cascade,
  blocked    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked),
  check (blocker <> blocked)
);
create index if not exists player_blocks_blocked on public.player_blocks (blocked);
alter table public.player_blocks enable row level security;
revoke all on public.player_blocks from anon, authenticated;

create table if not exists public.player_reports (
  id         bigint generated always as identity primary key,
  reporter   uuid references public.profiles(id) on delete set null,
  reported   uuid not null references public.profiles(id) on delete cascade,
  reason     text not null check (reason in ('name', 'cheating', 'abuse', 'other')),
  created_at timestamptz not null default now()
);
create index if not exists player_reports_reported on public.player_reports (reported);
create index if not exists player_reports_reporter on public.player_reports (reporter);
alter table public.player_reports enable row level security;
revoke all on public.player_reports from anon, authenticated;

-- Geräte für Push: iPhone (APNs-Token) und Browser (Web-Push-Abo). Ein Gerät gehört immer dem zuletzt
-- angemeldeten Konto.
create table if not exists public.push_tokens (
  token        text primary key check (char_length(token) between 16 and 1024),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  platform     text not null check (platform in ('ios', 'web')),
  environment  text check (environment in ('sandbox', 'production')),   -- nur iOS: welcher APNs-Server
  subscription jsonb,                                                   -- nur Web: {endpoint, keys: {p256dh, auth}}
  locale       text not null default 'en',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists push_tokens_user on public.push_tokens (user_id);
alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;

-- Was verschickt werden soll. Nur Server-Funktionen schreiben hier; push-dispatch liest mit der Service-Rolle.
create table if not exists public.push_outbox (
  id         bigint generated always as identity primary key,
  recipient  uuid not null references public.profiles(id) on delete cascade,
  actor      uuid references public.profiles(id) on delete cascade,
  kind       text not null check (kind in ('friend_request', 'friend_accepted')),
  actor_name text not null,
  created_at timestamptz not null default now(),
  sent_at    timestamptz
);
create index if not exists push_outbox_unsent on public.push_outbox (actor) where sent_at is null;
create index if not exists push_outbox_recipient on public.push_outbox (recipient);
alter table public.push_outbox enable row level security;
revoke all on public.push_outbox from anon, authenticated;

-- Zähler gegen Spam (Suchen, Anfragen, Meldungen)
create table if not exists private.rate_events (
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind    text not null,
  at      timestamptz not null default now()
);
create index if not exists rate_events_lookup on private.rate_events (user_id, kind, at);

-- ───────────────────────── Hilfen (nicht aufrufbar für die App) ─────────────────────────
create or replace function private.rate_ok(p_user uuid, p_kind text, p_max int, p_window interval)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  delete from private.rate_events where user_id = p_user and kind = p_kind and at < now() - p_window;
  if (select count(*) from private.rate_events where user_id = p_user and kind = p_kind) >= p_max then
    return false;
  end if;
  insert into private.rate_events (user_id, kind) values (p_user, p_kind);
  return true;
end $$;

create or replace function private.blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.player_blocks
                  where (blocker = a and blocked = b) or (blocker = b and blocked = a))
$$;

-- Offene Anfragen verfallen nach 30 Tagen (sie zählen dann nicht mehr und dürfen neu gestellt werden).
create or replace function private.relation(me uuid, other uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case
    when me = other then 'self'
    else coalesce((
      select case
        when f.status = 'accepted' then 'friend'
        when f.status = 'pending' and f.created_at > now() - interval '30 days'
          then case when f.requester = me then 'outgoing' else 'incoming' end
        else 'none' end
      from public.friendships f
      where (f.requester = me and f.addressee = other) or (f.requester = other and f.addressee = me)), 'none')
  end
$$;

create or replace function private.lock_pair(a uuid, b uuid)
returns void language sql security definer set search_path = '' as $$
  select pg_advisory_xact_lock(hashtext('friends:' || least(a, b)::text || ':' || greatest(a, b)::text))
$$;

create or replace function private.friend_count(p_user uuid)
returns int language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.friendships where status = 'accepted' and p_user in (requester, addressee)
$$;

-- Anfrage von p_requester an p_addressee annehmen (beide höchstens 200 Freunde) und den Absender benachrichtigen.
create or replace function private.accept_friendship(p_requester uuid, p_addressee uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if private.friend_count(p_requester) >= 200 or private.friend_count(p_addressee) >= 200 then
    raise exception 'friend_limit';
  end if;
  update public.friendships set status = 'accepted', responded_at = now()
   where requester = p_requester and addressee = p_addressee;
  insert into public.push_outbox (recipient, actor, kind, actor_name)
  select p_requester, p_addressee, 'friend_accepted', p.display_name from public.profiles p where p.id = p_addressee;
end $$;

revoke execute on function private.rate_ok(uuid, text, int, interval) from public, anon, authenticated;
revoke execute on function private.blocked_between(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.relation(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.lock_pair(uuid, uuid) from public, anon, authenticated;
revoke execute on function private.friend_count(uuid) from public, anon, authenticated;
revoke execute on function private.accept_friendship(uuid, uuid) from public, anon, authenticated;

-- Nur wer ein Konto (Profil) hat, darf Freunde haben.
create or replace function private.me_with_account()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.profiles where id = me) then raise exception 'no_account'; end if;
  return me;
end $$;
revoke execute on function private.me_with_account() from public, anon, authenticated;

-- ───────────────────────── Für die App ─────────────────────────
create or replace function public.my_friend_code()
returns text language sql stable security definer set search_path = public as $$
  select friend_code from profiles where id = private.me_with_account()
$$;

-- Exakter Name (Groß-/Kleinschreibung egal) oder Freundescode. Kein Stöbern: nur genaue Treffer, höchstens 60 je Stunde.
-- Blockierte (in beide Richtungen) werden nicht gefunden.
create or replace function public.find_player(p_query text)
returns table (user_id uuid, display_name text, avatar text, frame text, title text, level int, trophies int, relation text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  q text := btrim(coalesce(p_query, ''));
  code text := upper(regexp_replace(btrim(coalesce(p_query, '')), '[[:space:]#-]', '', 'g'));
begin
  if char_length(q) < 2 or char_length(q) > 24 then return; end if;
  if not private.rate_ok(me, 'find_player', 60, interval '1 hour') then raise exception 'too_many_requests'; end if;
  return query
    select p.id, p.display_name, p.avatar, p.frame, p.title, p.level, coalesce(g.trophies, 0), private.relation(me, p.id)
      from profiles p left join progress g on g.user_id = p.id
     where (lower(p.display_name) = lower(q) or p.friend_code = code)
       and not private.blocked_between(me, p.id)
     order by (p.id = me), p.display_name
     limit 2;
end $$;

-- Antwort: 'sent' (auch wenn still nichts passiert, z. B. bei einer Blockade), 'accepted' (der andere hatte schon
-- gefragt) oder 'already_friends'. Fehler: not_found, not_allowed, friend_limit, too_many_requests.
create or replace function public.send_friend_request(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  f friendships;
begin
  if p_user is null or p_user = me then raise exception 'not_allowed'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'not_found'; end if;
  perform private.lock_pair(me, p_user);
  if private.blocked_between(me, p_user) then return 'sent'; end if;
  select * into f from friendships
   where (requester = me and addressee = p_user) or (requester = p_user and addressee = me);
  if f.status = 'accepted' then return 'already_friends'; end if;
  if f.status = 'pending' and f.requester = p_user and f.created_at > now() - interval '30 days' then
    perform private.accept_friendship(p_user, me);
    return 'accepted';
  end if;
  if f.requester = me and f.status = 'pending' and f.created_at > now() - interval '30 days' then return 'sent'; end if;
  -- Abgelehnt: 30 Tage lang keine neue Anfrage an dieselbe Person (der Absender sieht weiter „gesendet“).
  if f.requester = me and f.status = 'declined' and f.responded_at > now() - interval '30 days' then return 'sent'; end if;
  if private.friend_count(me) >= 200 then raise exception 'friend_limit'; end if;
  if (select count(*) from friendships
       where requester = me and status = 'pending' and created_at > now() - interval '30 days') >= 50 then
    raise exception 'too_many_requests';
  end if;
  if not private.rate_ok(me, 'friend_request', 30, interval '1 day') then raise exception 'too_many_requests'; end if;
  delete from friendships where (requester = me and addressee = p_user) or (requester = p_user and addressee = me);
  insert into friendships (requester, addressee) values (me, p_user);
  insert into push_outbox (recipient, actor, kind, actor_name)
  select p_user, me, 'friend_request', p.display_name from profiles p where p.id = me;
  return 'sent';
end $$;

create or replace function public.respond_friend_request(p_user uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  perform private.lock_pair(me, p_user);
  if not exists (select 1 from friendships
                  where requester = p_user and addressee = me and status = 'pending'
                    and created_at > now() - interval '30 days') then
    raise exception 'no_request';
  end if;
  if p_accept then
    perform private.accept_friendship(p_user, me);
    return 'accepted';
  end if;
  update friendships set status = 'declined', responded_at = now() where requester = p_user and addressee = me;
  return 'declined';
end $$;

create or replace function public.cancel_friend_request(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  delete from friendships where requester = me and addressee = p_user and status = 'pending';
end $$;

create or replace function public.remove_friend(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  delete from friendships
   where status = 'accepted' and ((requester = me and addressee = p_user) or (requester = p_user and addressee = me));
end $$;

-- Blockieren beendet die Freundschaft und alle offenen Anfragen; der andere erfährt es nicht.
create or replace function public.block_player(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  if p_user is null or p_user = me then raise exception 'not_allowed'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'not_found'; end if;
  perform private.lock_pair(me, p_user);
  insert into player_blocks (blocker, blocked) values (me, p_user) on conflict do nothing;
  delete from friendships where (requester = me and addressee = p_user) or (requester = p_user and addressee = me);
  delete from push_outbox where sent_at is null and ((actor = p_user and recipient = me) or (actor = me and recipient = p_user));
end $$;

create or replace function public.unblock_player(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  delete from player_blocks where blocker = me and blocked = p_user;
end $$;

create or replace function public.blocked_players()
returns table (user_id uuid, display_name text, avatar text, frame text)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  return query
    select p.id, p.display_name, p.avatar, p.frame
      from player_blocks b join profiles p on p.id = b.blocked
     where b.blocker = me
     order by b.created_at desc;
end $$;

create or replace function public.report_player(p_user uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  if p_user is null or p_user = me then raise exception 'not_allowed'; end if;
  if p_reason is null or p_reason not in ('name', 'cheating', 'abuse', 'other') then raise exception 'bad_reason'; end if;
  if not exists (select 1 from profiles where id = p_user) then raise exception 'not_found'; end if;
  if not private.rate_ok(me, 'report', 10, interval '1 day') then raise exception 'too_many_requests'; end if;
  -- Dieselbe Person zählt nur einmal am Tag.
  if exists (select 1 from player_reports where reporter = me and reported = p_user and created_at > now() - interval '1 day') then
    return;
  end if;
  insert into player_reports (reporter, reported, reason) values (me, p_user, p_reason);
end $$;

-- Freunde und offene Anfragen (beide Richtungen), Freunde nach Trophäen.
create or replace function public.my_friends()
returns table (user_id uuid, display_name text, avatar text, frame text, title text, level int, trophies int,
               relation text, since timestamptz)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  return query
    select p.id, p.display_name, p.avatar, p.frame, p.title, p.level, coalesce(g.trophies, 0),
           case when f.status = 'accepted' then 'friend' when f.requester = me then 'outgoing' else 'incoming' end,
           coalesce(f.responded_at, f.created_at)
      from friendships f
      join profiles p on p.id = case when f.requester = me then f.addressee else f.requester end
      left join progress g on g.user_id = p.id
     where me in (f.requester, f.addressee)
       and (f.status = 'accepted' or (f.status = 'pending' and f.created_at > now() - interval '30 days'))
     order by case when f.status = 'accepted' then 1 when f.requester = me then 2 else 0 end,
              coalesce(g.trophies, 0) desc, p.display_name;
end $$;

-- Für den roten Punkt am Profil: offene Anfragen an mich.
create or replace function public.friend_request_count()
returns int language sql stable security definer set search_path = public as $$
  select count(*)::int from friendships
   where addressee = private.me_with_account() and status = 'pending' and created_at > now() - interval '30 days'
$$;

-- Profil-Übersicht: nur für Freunde und für offene Anfragen (man soll sehen, wer einen fragt).
create or replace function public.friend_profile(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  rel text := private.relation(me, p_user);
  out jsonb;
begin
  if rel not in ('friend', 'incoming', 'outgoing') then raise exception 'not_allowed'; end if;
  select jsonb_build_object(
           'user_id', p.id, 'display_name', p.display_name, 'avatar', p.avatar, 'frame', p.frame, 'title', p.title,
           'level', p.level, 'member_since', p.created_at, 'relation', rel,
           'trophies', coalesce(g.trophies, 0), 'best_trophies', coalesce(g.best_trophies, 0),
           'online_wins', coalesce(g.online_wins, 0), 'online_losses', coalesce(g.online_losses, 0),
           'online_draws', coalesce(g.online_draws, 0),
           'rank', (select count(*) + 1 from progress x where x.trophies > coalesce(g.trophies, 0)),
           'friends', private.friend_count(p.id),
           'since', (select coalesce(f.responded_at, f.created_at) from friendships f
                      where (f.requester = me and f.addressee = p.id) or (f.requester = p.id and f.addressee = me)))
    into out
    from profiles p left join progress g on g.user_id = p.id
   where p.id = p_user;
  -- Bilanz gegeneinander (gewertete Partien Mensch gegen Mensch)
  return out || (
    select jsonb_build_object(
             'vs_wins', count(*) filter (where (m.winner_color = 'white') = (m.white = me) and m.winner_color is not null),
             'vs_losses', count(*) filter (where (m.winner_color = 'white') = (m.white = p_user) and m.winner_color is not null),
             'vs_draws', count(*) filter (where m.winner_color is null))
      from matches m
     where m.status = 'finished' and not m.is_bot
       and ((m.white = me and m.black = p_user) or (m.white = p_user and m.black = me)));
end $$;

-- Push-Gerät anmelden (bei jedem Start; das Token kann sich ändern). Höchstens 10 Geräte je Konto.
-- Fehlende Werte dürfen weggelassen werden (die iPhone-App schickt kein p_subscription, der Browser kein p_token).
create or replace function public.register_push_token(p_platform text, p_token text default null, p_environment text default null,
                                                      p_subscription jsonb default null, p_locale text default 'en')
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  tok text := p_token;
  loc text := lower(left(coalesce(p_locale, 'en'), 2));
begin
  if p_platform = 'ios' then
    if tok is null or tok !~ '^[0-9a-fA-F]{64,200}$' then raise exception 'bad_token'; end if;
    if p_environment is null or p_environment not in ('sandbox', 'production') then raise exception 'bad_token'; end if;
  elsif p_platform = 'web' then
    tok := p_subscription->>'endpoint';
    if tok is null or tok !~ '^https://' or char_length(tok) > 1024
       or coalesce(p_subscription->'keys'->>'p256dh', '') = '' or coalesce(p_subscription->'keys'->>'auth', '') = ''
       or pg_column_size(p_subscription) > 4096 then
      raise exception 'bad_token';
    end if;
  else
    raise exception 'bad_token';
  end if;
  if loc not in ('de', 'en', 'fr', 'es', 'it', 'ru', 'zh') then loc := 'en'; end if;
  insert into push_tokens (token, user_id, platform, environment, subscription, locale)
  values (tok, me, p_platform, case when p_platform = 'ios' then p_environment end,
          case when p_platform = 'web' then p_subscription end, loc)
  on conflict (token) do update
    set user_id = excluded.user_id, environment = excluded.environment, subscription = excluded.subscription,
        locale = excluded.locale, updated_at = now();
  delete from push_tokens
   where user_id = me and token in (select token from push_tokens where user_id = me order by updated_at desc offset 10);
end $$;

create or replace function public.unregister_push_token(p_token text)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from push_tokens where token = p_token and user_id = auth.uid();
end $$;

-- ───────────────────────── Für push-dispatch (nur Service-Rolle) ─────────────────────────
-- Holt die noch nicht verschickten Nachrichten eines Absenders und markiert sie sofort als verschickt.
-- So verschickt auch ein doppelter Aufruf jede Nachricht nur einmal. Eine Zeile je Empfänger-Gerät.
create or replace function public.claim_push_outbox(p_actor uuid)
returns table (kind text, actor_name text, token text, platform text, environment text, subscription jsonb, locale text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  return query
    with picked as (
      select o.id from push_outbox o
       where o.actor = p_actor and o.sent_at is null and o.created_at > now() - interval '1 day'
       order by o.id limit 10
       for update skip locked),
    claimed as (
      update push_outbox o set sent_at = now() from picked where o.id = picked.id
      returning o.recipient, o.kind, o.actor_name)
    select c.kind, c.actor_name, t.token, t.platform, t.environment, t.subscription, t.locale
      from claimed c join push_tokens t on t.user_id = c.recipient;
end $$;

-- Geräte, die Apple oder der Browser-Dienst nicht mehr kennt (App gelöscht, Abo beendet).
create or replace function public.drop_push_tokens(p_tokens text[])
returns void language sql security definer set search_path = public as $$
  delete from push_tokens where token = any(p_tokens)
$$;

revoke execute on function public.claim_push_outbox(uuid) from public, anon, authenticated;
revoke execute on function public.drop_push_tokens(text[]) from public, anon, authenticated;
grant execute on function public.claim_push_outbox(uuid) to service_role;
grant execute on function public.drop_push_tokens(text[]) to service_role;

-- ───────────────────────── Aufräumen (stündlich) ─────────────────────────
create or replace function private.cleanup_social()
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  delete from public.push_outbox where created_at < now() - interval '2 days';
  delete from public.friendships where status = 'pending' and created_at < now() - interval '30 days';
  delete from public.friendships where status = 'declined' and responded_at < now() - interval '30 days';
  delete from private.rate_events where at < now() - interval '2 days';
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function private.cleanup_social() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'rookraid-cleanup-social';
select cron.schedule('rookraid-cleanup-social', '41 * * * *', $$select private.cleanup_social()$$);

-- ───────────────────────── Rechte ─────────────────────────
do $$
declare f text;
begin
  foreach f in array array[
    'my_friend_code()', 'find_player(text)', 'send_friend_request(uuid)', 'respond_friend_request(uuid, boolean)',
    'cancel_friend_request(uuid)', 'remove_friend(uuid)', 'block_player(uuid)', 'unblock_player(uuid)',
    'blocked_players()', 'report_player(uuid, text)', 'my_friends()', 'friend_request_count()', 'friend_profile(uuid)',
    'register_push_token(text, text, text, jsonb, text)', 'unregister_push_token(text)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
