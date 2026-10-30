-- ════════════════════════════════════════════════════════════════════════════════════════════════
-- Rook Raid – Online-Datenbank, Migration 1 (Stand App v0.9.34, Regel-Version 3)
--
-- Entscheidungen (Backend/ONLINE-IMPLEMENTIERUNG.md, Abschnitt 1): online nur 5|0 (E3), 45 s ohne Lebenszeichen =
-- verloren (E6), eindeutige Spielernamen (E8), Bot-Ersatz zählt für Trophäen (E1), Server führt nur Trophäen und
-- Online-Bilanz (E2), Gast-Trophäen bis 1 500 (E4), Remis-Angebot (E7), Suche ±100 → ±400, Bot nach 10 s (E12).
--
-- Grundsatz: Die App LIEST frei (eigene Daten, eigene Partien), SCHREIBT aber nichts Wertvolles selbst.
-- Trophäen, Partien und Züge ändern nur Server-Funktionen (security definer) bzw. Edge Functions mit der
-- Service-Rolle – nach Prüfung mit dem Regel-Port. So kann niemand Trophäen oder Züge fälschen.
--
-- Einspielen: supabase db push   (oder im SQL-Editor des Dashboards ausführen)
-- Danach:      Regeln eintragen  (Backend/supabase/seed/rules.sql, erzeugt mit node Tools/rules-js/seed-rules.js)
--              Wartungsjob       (Migration 20261028000002_online_cron.sql)
-- ════════════════════════════════════════════════════════════════════════════════════════════════

-- ───────────────────────── Regeln ─────────────────────────
create table if not exists public.rules_config (
  version     int primary key,
  config      jsonb not null,               -- gleiche Struktur wie RookRaid/Engine/rookraid-rules.json
  active      boolean not null default false,
  created_at  timestamptz not null default now()
);
alter table public.rules_config enable row level security;
drop policy if exists "rules_read" on public.rules_config;
create policy "rules_read" on public.rules_config for select using (true);

-- Aktive Regel-Version (die App vergleicht sie mit RulesConfig.current.version)
create or replace function public.active_rules()
returns table (version int, config jsonb)
language sql stable security definer set search_path = public as $$
  select version, config from rules_config where active order by version desc limit 1
$$;

-- ───────────────────────── Spieler ─────────────────────────
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  guest_id      uuid unique,                -- Gast-ID des Geräts (DeviceIdentity), für die Übernahme
  display_name  text not null check (char_length(display_name) between 2 and 16),
  avatar        text not null default 'knight',
  frame         text,
  title         text,
  piece_set     text,
  level         int not null default 1 check (level between 1 and 500),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
-- Eindeutige Spielernamen (E8), Groß-/Kleinschreibung egal: „Ivan“ und „ivan“ gelten als gleich
create unique index if not exists profiles_name_unique on public.profiles (lower(display_name));
alter table public.profiles enable row level security;
drop policy if exists "profiles_read" on public.profiles;
create policy "profiles_read" on public.profiles for select using (true);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
-- Nur Kosmetik darf die App selbst ändern (nicht id, guest_id, created_at). Den Namen ändert set_display_name().
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (avatar, frame, title, piece_set, level, updated_at) on public.profiles to authenticated;

-- Erlaubte Namen: 2–16 Zeichen, Buchstaben (auch ä, é, …), Ziffern, Leerzeichen, _ . - ; kein Leerzeichen am Rand
create or replace function public.valid_name(p text)
returns boolean language sql immutable as $$
  select p is not null and p = btrim(p) and char_length(p) between 2 and 16 and p ~ '^[[:alnum:] _.\-]+$'
$$;

-- Live-Prüfung in der App beim Eintippen
create or replace function public.name_available(p_name text)
returns boolean language sql stable security definer set search_path = public as $$
  select valid_name(p_name) and not exists (
    select 1 from profiles where lower(display_name) = lower(p_name) and id is distinct from auth.uid())
$$;

create or replace function public.set_display_name(p_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not valid_name(p_name) then raise exception 'name_invalid'; end if;
  if not name_available(p_name) then raise exception 'name_taken'; end if;
  update profiles set display_name = p_name, updated_at = now() where id = auth.uid();
end $$;

create table if not exists public.progress (
  user_id        uuid primary key references public.profiles(id) on delete cascade,
  trophies       int not null default 0 check (trophies >= 0),
  best_trophies  int not null default 0,
  online_wins    int not null default 0,
  online_losses  int not null default 0,
  online_draws   int not null default 0,
  -- Letzte Sicherung des lokalen Fortschritts (ProgressSnapshot) – nur zum Wiederherstellen auf einem neuen
  -- Gerät, NICHT vertrauenswürdig (Phase 1: XP, Karten, Splitter, Truhen bleiben auf dem Gerät maßgeblich).
  snapshot       jsonb,
  snapshot_at    timestamptz,
  updated_at     timestamptz not null default now()
);
alter table public.progress enable row level security;
drop policy if exists "progress_read_own" on public.progress;
create policy "progress_read_own" on public.progress for select using (auth.uid() = user_id);
revoke insert, update, delete on public.progress from anon, authenticated;

-- Arena-Untergrenzen wie Arena.all in der App (Persistence.swift): unter die Grenze der aktuellen Arena fällt man nicht.
create or replace function public.arena_floor(p_trophies int)
returns int language sql immutable as $$
  select case when p_trophies >= 2100 then 2100 when p_trophies >= 1200 then 1200 when p_trophies >= 600 then 600
              when p_trophies >= 240 then 240 when p_trophies >= 90 then 90 else 0 end
$$;

-- Konto einrichten (erstes Anmelden) – legt Profil und Fortschritt an und übernimmt den Gast-Fortschritt.
-- Gibt 'created' zurück oder 'existing' (Konto gab es schon → App bietet „Fortschritt wiederherstellen“ an).
create or replace function public.setup_account(p_snapshot jsonb, p_card jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  t int;
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
  -- Gast-Trophäen übernehmen, aber gedeckelt (lokal sind sie nicht nachprüfbar)
  t := greatest(0, least(coalesce((p_snapshot->>'trophies')::int, 0), 1500));
  insert into progress (user_id, trophies, best_trophies, snapshot, snapshot_at)
  values (uid, t, t, p_snapshot, now());
  return jsonb_build_object('status', 'created',
    'progress', (select to_jsonb(p) - 'user_id' from progress p where p.user_id = uid));
end $$;

-- Lokalen Fortschritt sichern (nach jeder Partie / beim Schließen der App, höchstens 64 KB)
create or replace function public.backup_progress(p_snapshot jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if pg_column_size(p_snapshot) > 65536 then raise exception 'snapshot_too_large'; end if;
  update progress set snapshot = p_snapshot, snapshot_at = now(), updated_at = now() where user_id = auth.uid();
end $$;

-- Ergebnis für einen Spieler verbuchen – dieselbe Formel wie ProfileStore.record in der App:
-- Sieg +30, Remis +5, Niederlage −20 (nie unter die Arena-Untergrenze). Gibt die Änderung zurück.
create or replace function public.apply_result(p_user uuid, p_outcome text)
returns int language plpgsql security definer set search_path = public as $$
declare cur int; d int;
begin
  select trophies into cur from progress where user_id = p_user for update;
  if cur is null then return 0; end if;
  d := case p_outcome when 'win' then 30 when 'draw' then 5
                      else -least(20, greatest(0, cur - arena_floor(cur))) end;
  update progress set
    trophies = cur + d,
    best_trophies = greatest(best_trophies, cur + d),
    online_wins = online_wins + (p_outcome = 'win')::int,
    online_losses = online_losses + (p_outcome = 'loss')::int,
    online_draws = online_draws + (p_outcome = 'draw')::int,
    updated_at = now()
  where user_id = p_user;
  return d;
end $$;

-- ───────────────────────── Zeitkontrollen ─────────────────────────
-- Online gibt es genau eine Zeitkontrolle: 5 | 0 (E3, TimeControl.blitz5 in der App). Weitere hier ergänzen.
create or replace function public.tc_base_ms(p text) returns int language sql immutable as $$
  select case p when 'blitz5' then 300000 end
$$;
create or replace function public.tc_increment_ms(p text) returns int language sql immutable as $$
  select case p when 'blitz5' then 0 end
$$;

-- Bot-Stufe zu den Trophäen – wie BotLevel.forTrophies (alle 200 Trophäen eine Stufe)
create or replace function public.bot_level_for(p_trophies int) returns text language sql immutable as $$
  select (array['easy','apprentice','medium','jester','knight','tactician','shadow','baron','hard','frost','sphinx','queen'])
         [least(12, greatest(0, p_trophies) / 200 + 1)]
$$;

-- ───────────────────────── Partien ─────────────────────────
create table if not exists public.matches (
  id                  uuid primary key default gen_random_uuid(),
  white               uuid references public.profiles(id) on delete set null,
  black               uuid references public.profiles(id) on delete set null,   -- null = Bot
  white_card          jsonb not null,               -- PlayerCard (was der Gegner sieht)
  black_card          jsonb not null,
  is_bot              boolean not null default false,
  bot_level           text,
  rules_version       int not null references public.rules_config(version),
  time_control        text not null check (tc_base_ms(time_control) is not null),
  setup               jsonb not null,               -- {decks:{white,black}, ultimates:{white,black}} wie MatchRecord
  status              text not null default 'active' check (status in ('active', 'finished', 'aborted')),
  result              text,                         -- mate, stalemate, fifty, repetition, timeout, resigned, draw_agreed, abandoned, aborted
  winner_color        text check (winner_color in ('white', 'black')),
  turn                text not null default 'white' check (turn in ('white', 'black')),
  action_count        int not null default 0,       -- Anzahl gespeicherter Aktionen = nächste erwartete ply
  clock_white_ms      int not null,
  clock_black_ms      int not null,
  increment_ms        int not null,
  clock_started_at    timestamptz not null,         -- Uhr von Weiß läuft ab hier (nach dem Duell-Intro)
  last_action_at      timestamptz,
  first_move_deadline timestamptz not null,
  draw_offer_by       text check (draw_offer_by in ('white', 'black')),
  trophies_white      int,                          -- Trophäen beim Start (Anzeige)
  trophies_black      int,
  trophy_delta_white  int,
  trophy_delta_black  int,
  created_at          timestamptz not null default now(),
  ended_at            timestamptz
);
create index if not exists matches_active_white on public.matches (white) where status = 'active';
create index if not exists matches_active_black on public.matches (black) where status = 'active';
alter table public.matches enable row level security;
drop policy if exists "matches_read_participants" on public.matches;
create policy "matches_read_participants" on public.matches for select using (auth.uid() in (white, black));
revoke insert, update, delete on public.matches from anon, authenticated;

create table if not exists public.match_actions (
  match_id    uuid not null references public.matches(id) on delete cascade,
  ply         int not null,                 -- laufende Nummer der Aktion (Karten und Bonuszüge zählen einzeln)
  actor       uuid,                         -- null = Bot
  code        text not null,                -- Draht-Format: e2e4, e7e8q, card:freeze@f6, card:bulwark, ult:meteor@d8
  clock_ms    int,                          -- Restzeit des Ziehenden nach der Aktion
  created_at  timestamptz not null default now(),
  primary key (match_id, ply)
);
alter table public.match_actions enable row level security;
drop policy if exists "actions_read_participants" on public.match_actions;
create policy "actions_read_participants" on public.match_actions for select
  using (exists (select 1 from public.matches m where m.id = match_id and auth.uid() in (m.white, m.black)));
revoke insert, update, delete on public.match_actions from anon, authenticated;

-- Lebenszeichen (E6): Jedes Gerät meldet sich alle 10 s (match_heartbeat). Wer 45 s still ist, verliert.
-- Eigene Tabelle (nicht in der Realtime-Publikation), damit die Pings keine Update-Flut auf matches auslösen.
create table if not exists public.match_presence (
  match_id  uuid not null references public.matches(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  seen_at   timestamptz not null default now(),
  primary key (match_id, user_id)
);
alter table public.match_presence enable row level security;
revoke all on public.match_presence from anon, authenticated;

-- Wie lange ist ein Spieler schon still? (Sekunden; null = Bot oder kein Eintrag)
create or replace function public.silent_seconds(p_match uuid, p_user uuid)
returns int language sql stable security definer set search_path = public as $$
  select extract(epoch from now() - seen_at)::int from match_presence where match_id = p_match and user_id = p_user
$$;

-- Partie beenden und Trophäen verbuchen (nur Server). p_winner: 'white' | 'black' | null (Remis).
create or replace function public.finish_match(p_match uuid, p_result text, p_winner text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m matches; dw int; db int;
begin
  select * into m from matches where id = p_match for update;
  if m.id is null then raise exception 'match_not_found'; end if;
  if m.status <> 'active' then return jsonb_build_object('status', m.status, 'already', true); end if;
  if p_result = 'aborted' then
    update matches set status = 'aborted', result = 'aborted', ended_at = now() where id = p_match;
    return jsonb_build_object('status', 'aborted');
  end if;
  if m.white is not null then
    dw := apply_result(m.white, case when p_winner is null then 'draw' when p_winner = 'white' then 'win' else 'loss' end);
  end if;
  if m.black is not null then
    db := apply_result(m.black, case when p_winner is null then 'draw' when p_winner = 'black' then 'win' else 'loss' end);
  end if;
  update matches set status = 'finished', result = p_result, winner_color = p_winner, draw_offer_by = null,
                     trophy_delta_white = dw, trophy_delta_black = db, ended_at = now()
  where id = p_match;
  return jsonb_build_object('status', 'finished', 'result', p_result, 'winner', p_winner,
                            'trophy_delta_white', dw, 'trophy_delta_black', db);
end $$;

-- Restzeit der Seite am Zug in diesem Moment (ms)
create or replace function public.remaining_ms(m public.matches)
returns int language sql stable as $$
  select (case when m.turn = 'white' then m.clock_white_ms else m.clock_black_ms end)
         - greatest(0, (extract(epoch from (now() - coalesce(m.last_action_at, m.clock_started_at))) * 1000)::int)
$$;

-- Aktion speichern – nur von der Edge Function submit-action (Service-Rolle) NACH der Regelprüfung.
-- Führt die Uhr: zieht die verbrauchte Zeit ab und gibt das Inkrement, wenn der Zug weitergeht.
create or replace function public.record_action(p_match uuid, p_ply int, p_actor uuid, p_code text,
                                                p_turn_after text, p_result text, p_winner text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m matches;
  mover text;
  left_ms int;
  passed boolean;
begin
  select * into m from matches where id = p_match for update;
  if m.id is null or m.status <> 'active' then return jsonb_build_object('error', 'not_active'); end if;
  if m.action_count <> p_ply then return jsonb_build_object('error', 'out_of_sync', 'action_count', m.action_count); end if;
  mover := m.turn;
  left_ms := remaining_ms(m);
  if left_ms <= 0 then
    perform finish_match(p_match, 'timeout', case when mover = 'white' then 'black' else 'white' end);
    return jsonb_build_object('error', 'timeout');
  end if;
  passed := p_turn_after <> mover or p_result is not null;
  update match_presence set seen_at = now() where match_id = p_match and user_id = p_actor;
  if passed then left_ms := left_ms + m.increment_ms; end if;
  insert into match_actions (match_id, ply, actor, code, clock_ms) values (p_match, p_ply, p_actor, p_code, left_ms);
  update matches set
    action_count = p_ply + 1,
    turn = p_turn_after,
    last_action_at = now(),
    clock_white_ms = case when mover = 'white' then left_ms else clock_white_ms end,
    clock_black_ms = case when mover = 'black' then left_ms else clock_black_ms end,
    -- Wer zieht, lehnt ein offenes Remis-Angebot des Gegners ab
    draw_offer_by = case when draw_offer_by = mover then draw_offer_by else null end
  where id = p_match;
  if p_result is not null then
    return jsonb_build_object('ok', true, 'ply', p_ply + 1, 'finish', finish_match(p_match, p_result, p_winner));
  end if;
  return jsonb_build_object('ok', true, 'ply', p_ply + 1, 'clock_ms', left_ms, 'turn', p_turn_after);
end $$;

-- ───────────────────────── Gegnersuche ─────────────────────────
create table if not exists public.matchmaking_queue (
  user_id        uuid primary key references public.profiles(id) on delete cascade,
  trophies       int not null,                -- vom Server aus progress übernommen, nicht von der App
  rules_version  int not null,
  time_control   text not null,
  deck           text[] not null,
  ultimate       text not null,
  card           jsonb not null,              -- PlayerCard
  enqueued_at    timestamptz not null default now(),
  last_seen_at   timestamptz not null default now()
);
create index if not exists queue_pairing on public.matchmaking_queue (rules_version, time_control, trophies);
alter table public.matchmaking_queue enable row level security;
drop policy if exists "queue_read_own" on public.matchmaking_queue;
create policy "queue_read_own" on public.matchmaking_queue for select using (auth.uid() = user_id);
revoke insert, update, delete on public.matchmaking_queue from anon, authenticated;

-- Hilfsfunktion: Partie anlegen (Mensch gegen Mensch oder gegen Bot)
create or replace function public.create_match(p_white uuid, p_black uuid, p_white_card jsonb, p_black_card jsonb,
                                               p_white_deck text[], p_black_deck text[], p_white_ult text, p_black_ult text,
                                               p_rules_version int, p_tc text, p_is_bot boolean, p_bot_level text)
returns uuid language plpgsql security definer set search_path = public as $$
declare mid uuid;
begin
  insert into matches (white, black, white_card, black_card, is_bot, bot_level, rules_version, time_control, setup,
                       clock_white_ms, clock_black_ms, increment_ms, clock_started_at, first_move_deadline,
                       trophies_white, trophies_black)
  values (p_white, p_black, p_white_card, p_black_card, p_is_bot, p_bot_level, p_rules_version, p_tc,
          jsonb_build_object('decks', jsonb_build_object('white', to_jsonb(p_white_deck), 'black', to_jsonb(p_black_deck)),
                             'ultimates', jsonb_build_object('white', p_white_ult, 'black', p_black_ult)),
          tc_base_ms(p_tc), tc_base_ms(p_tc), tc_increment_ms(p_tc),
          now() + interval '5 seconds',            -- Duell-Intro: so lange läuft noch keine Uhr
          now() + interval '35 seconds',           -- ohne ersten Zug bis hier: Abbruch ohne Wertung
          (select trophies from progress where user_id = p_white),
          (select trophies from progress where user_id = p_black))
  returning id into mid;
  insert into match_presence (match_id, user_id)
  select mid, u from unnest(array[p_white, p_black]) u where u is not null;
  return mid;
end $$;

create or replace function public.check_deck(p_deck text[], p_ultimate text)
returns void language plpgsql immutable as $$
begin
  if coalesce(array_length(p_deck, 1), 0) <> 4 or (select count(distinct x) from unnest(p_deck) x) <> 4 then
    raise exception 'deck_incomplete';
  end if;
  if exists (select 1 from unnest(p_deck) x where x not in
      ('shield','freeze','bulwark','sprint','lightning','knighting','reinforce','revive',
       'bishopize','advance','swap','drain','focus','sacrifice','retreat')) then
    raise exception 'unknown_card';
  end if;
  if p_ultimate not in ('meteor','iceAge','fortress','coronation','rebirth') then raise exception 'unknown_ultimate'; end if;
end $$;

-- Gegner suchen. Die App ruft das alle ~2 s auf (Polling), bis eine Partie-ID kommt oder nach
-- OnlineConfig.matchmakingTimeout (10 s) start_bot_match übernimmt. Das Trophäen-Fenster wächst mit der Wartezeit:
-- ±100, alle 2 s +50, höchstens ±400. Gepaart wird nur bei gleicher Regel-Version und Zeitkontrolle.
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
  if tc_base_ms(p_time_control) is null then raise exception 'bad_time_control'; end if;
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

create or replace function public.cancel_matchmaking()
returns void language sql security definer set search_path = public as $$
  delete from matchmaking_queue where user_id = auth.uid()
$$;

-- Kein Mensch gefunden: Bot-Ersatz. Die Bot-Stufe bestimmt der Server aus den Trophäen; das Bot-Deck und die
-- Spielerkarte des Bots (Name, Avatar – BotCards in der App) schickt die App mit. Wurde inzwischen doch ein
-- Mensch gefunden, kommt dessen Partie zurück (is_bot = false).
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
  -- Eintrag zuerst löschen: Hält gerade ein Gegner unseren Eintrag gesperrt, wartet das, bis dessen Paarung fertig ist.
  delete from matchmaking_queue where user_id = me;
  select * into existing from matches
   where status = 'active' and not matches.is_bot and (white = me or black = me) and created_at > now() - interval '2 minutes'
   order by created_at desc limit 1;
  if existing.id is not null then
    return query select existing.id, false, null::text, existing.white = me;
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

-- ───────────────────────── Steuerung während der Partie ─────────────────────────
create or replace function public.my_color(m public.matches)
returns text language sql stable as $$
  select case when auth.uid() = m.white then 'white' when auth.uid() = m.black then 'black' end
$$;

create or replace function public.resign_match(p_match uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m matches; c text;
begin
  select * into m from matches where id = p_match;
  c := my_color(m);
  if c is null then raise exception 'not_participant'; end if;
  if m.is_bot then raise exception 'bot_match_use_finish_bot_match'; end if;
  return finish_match(p_match, 'resigned', case when c = 'white' then 'black' else 'white' end);
end $$;

create or replace function public.offer_draw(p_match uuid)
returns void language plpgsql security definer set search_path = public as $$
declare m matches; c text;
begin
  select * into m from matches where id = p_match for update;
  c := my_color(m);
  if c is null or m.status <> 'active' or m.is_bot then raise exception 'not_allowed'; end if;
  if m.action_count < 2 then raise exception 'too_early'; end if;
  update matches set draw_offer_by = c where id = p_match;
end $$;

create or replace function public.answer_draw(p_match uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m matches; c text;
begin
  select * into m from matches where id = p_match for update;
  c := my_color(m);
  if c is null or m.status <> 'active' then raise exception 'not_allowed'; end if;
  if m.draw_offer_by is null or m.draw_offer_by = c then raise exception 'no_offer'; end if;
  if p_accept then return finish_match(p_match, 'draw_agreed', null); end if;
  update matches set draw_offer_by = null where id = p_match;
  return jsonb_build_object('status', 'active');
end $$;

-- Lebenszeichen alle 10 s (auch in Bot-Partien). Antwort: Sekunden seit dem letzten Lebenszeichen des Gegners
-- (null bei Bot) – die App zeigt ab ~15 s „Gegner hat die Verbindung verloren …“.
create or replace function public.match_heartbeat(p_match uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m matches; opp uuid;
begin
  select * into m from matches where id = p_match;
  if my_color(m) is null then raise exception 'not_participant'; end if;
  update match_presence set seen_at = now() where match_id = p_match and user_id = auth.uid();
  opp := case when m.white = auth.uid() then m.black else m.white end;
  return jsonb_build_object('status', m.status, 'opponent_silent_s', silent_seconds(p_match, opp));
end $$;

-- Zeitablauf melden (beide Geräte rufen das auf, wenn ihre Anzeige 0:00 erreicht), Abbruch ohne ersten Zug
-- und Verbindungsabbruch des Gegners (> 45 s ohne Lebenszeichen → der Aufrufer gewinnt)
create or replace function public.claim_timeout(p_match uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m matches;
begin
  select * into m from matches where id = p_match for update;
  if my_color(m) is null then raise exception 'not_participant'; end if;
  if m.status <> 'active' or m.is_bot then return jsonb_build_object('status', m.status); end if;
  if m.action_count = 0 and now() > m.first_move_deadline then return finish_match(p_match, 'aborted', null); end if;
  if m.action_count = 1 and now() > m.last_action_at + interval '30 seconds' then return finish_match(p_match, 'aborted', null); end if;
  update match_presence set seen_at = now() where match_id = p_match and user_id = auth.uid();
  if coalesce(silent_seconds(p_match, case when m.white = auth.uid() then m.black else m.white end), 0) > 45 then
    return finish_match(p_match, 'abandoned', my_color(m));
  end if;
  if remaining_ms(m) <= 0 then
    return finish_match(p_match, 'timeout', case when m.turn = 'white' then 'black' else 'white' end);
  end if;
  return jsonb_build_object('status', 'active', 'remaining_ms', remaining_ms(m));
end $$;

-- ───────────────────────── Wartung (pg_cron, jede Minute) ─────────────────────────
create or replace function public.maintain_matches()
returns int language plpgsql security definer set search_path = public as $$
declare m matches; n int := 0;
begin
  delete from matchmaking_queue where last_seen_at < now() - interval '30 seconds';
  for m in select * from matches where status = 'active' loop
    if m.is_bot then
      -- Bot-Partie: Mensch 45 s ohne Lebenszeichen (App beendet, kein Netz) → Niederlage, wie gegen Menschen (E6).
      -- Rückfall ohne Presence-Eintrag: nach 3 Stunden.
      if coalesce(silent_seconds(m.id, coalesce(m.white, m.black)), 0) > 45 or m.created_at < now() - interval '3 hours' then
        perform finish_match(m.id, 'abandoned', case when m.white is null then 'white' else 'black' end);
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

-- ───────────────────────── Bestenliste ─────────────────────────
-- In der App erst in Phase 2 (E5) – die Funktionen sind schon da, damit man die Liste im Dashboard ansehen kann.
-- Als Funktion statt View: liest an den Zugriffsregeln vorbei, gibt aber nur öffentliche Spalten heraus.
create or replace function public.get_leaderboard(p_limit int default 100)
returns table (rank bigint, user_id uuid, display_name text, avatar text, frame text, trophies int)
language sql stable security definer set search_path = public as $$
  select rank() over (order by g.trophies desc), p.id, p.display_name, p.avatar, p.frame, g.trophies
  from progress g join profiles p on p.id = g.user_id
  order by g.trophies desc
  limit least(greatest(p_limit, 1), 200)
$$;

create or replace function public.my_rank()
returns bigint language sql stable security definer set search_path = public as $$
  select count(*) + 1 from progress where trophies > (select trophies from progress where user_id = auth.uid())
$$;

-- ───────────────────────── Rechte ─────────────────────────
-- Interne Funktionen: nur Server (Service-Rolle). Alles andere: angemeldete Spieler.
revoke execute on function public.finish_match(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.apply_result(uuid, text) from public, anon, authenticated;
revoke execute on function public.record_action(uuid, int, uuid, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.create_match(uuid, uuid, jsonb, jsonb, text[], text[], text, text, int, text, boolean, text) from public, anon, authenticated;
revoke execute on function public.maintain_matches() from public, anon, authenticated;
grant execute on function public.finish_match(uuid, text, text) to service_role;
grant execute on function public.record_action(uuid, int, uuid, text, text, text, text) to service_role;
grant execute on function public.maintain_matches() to service_role;

revoke execute on function public.setup_account(jsonb, jsonb) from public, anon;
revoke execute on function public.backup_progress(jsonb) from public, anon;
revoke execute on function public.find_match(int, text, text[], text, jsonb) from public, anon;
revoke execute on function public.cancel_matchmaking() from public, anon;
revoke execute on function public.start_bot_match(int, text, text[], text, jsonb, jsonb, text[], text, boolean) from public, anon;
revoke execute on function public.resign_match(uuid) from public, anon;
revoke execute on function public.offer_draw(uuid) from public, anon;
revoke execute on function public.answer_draw(uuid, boolean) from public, anon;
revoke execute on function public.claim_timeout(uuid) from public, anon;
revoke execute on function public.my_rank() from public, anon;
revoke execute on function public.match_heartbeat(uuid) from public, anon;
revoke execute on function public.set_display_name(text) from public, anon;
revoke execute on function public.silent_seconds(uuid, uuid) from public, anon, authenticated;
grant execute on function public.match_heartbeat(uuid) to authenticated;
grant execute on function public.set_display_name(text) to authenticated;
grant execute on function public.name_available(text) to authenticated;
grant execute on function public.setup_account(jsonb, jsonb) to authenticated;
grant execute on function public.backup_progress(jsonb) to authenticated;
grant execute on function public.find_match(int, text, text[], text, jsonb) to authenticated;
grant execute on function public.cancel_matchmaking() to authenticated;
grant execute on function public.start_bot_match(int, text, text[], text, jsonb, jsonb, text[], text, boolean) to authenticated;
grant execute on function public.resign_match(uuid) to authenticated;
grant execute on function public.offer_draw(uuid) to authenticated;
grant execute on function public.answer_draw(uuid, boolean) to authenticated;
grant execute on function public.claim_timeout(uuid) to authenticated;
grant execute on function public.my_rank() to authenticated;
grant execute on function public.get_leaderboard(int) to anon, authenticated;
grant execute on function public.active_rules() to anon, authenticated;

-- ───────────────────────── Echtzeit ─────────────────────────
-- Die App abonniert match_actions (neue Züge) und matches (Uhr, Remis-Angebot, Partieende) ihrer Partie.
do $$ begin
  begin alter publication supabase_realtime add table public.match_actions; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.matches; exception when duplicate_object then null; end;
end $$;
