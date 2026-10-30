-- Rook Raid – Migration 3: Hinweise des Supabase-Advisors (Sicherheit, Leistung)

-- name_available nur für angemeldete Spieler (vorher per Standardrecht auch ohne Anmeldung aufrufbar)
revoke execute on function public.name_available(text) from public, anon;
grant execute on function public.name_available(text) to authenticated;

-- Fester Suchpfad für die Hilfsfunktionen ohne security definer
alter function public.valid_name(text) set search_path = '';
alter function public.arena_floor(int) set search_path = '';
alter function public.tc_base_ms(text) set search_path = '';
alter function public.tc_increment_ms(text) set search_path = '';
alter function public.bot_level_for(int) set search_path = '';
alter function public.remaining_ms(public.matches) set search_path = '';
alter function public.check_deck(text[], text) set search_path = '';
alter function public.my_color(public.matches) set search_path = '';

-- auth.uid() einmal pro Abfrage statt pro Zeile auswerten
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
drop policy if exists "progress_read_own" on public.progress;
create policy "progress_read_own" on public.progress for select using ((select auth.uid()) = user_id);
drop policy if exists "matches_read_participants" on public.matches;
create policy "matches_read_participants" on public.matches for select using ((select auth.uid()) in (white, black));
drop policy if exists "actions_read_participants" on public.match_actions;
create policy "actions_read_participants" on public.match_actions for select
  using (exists (select 1 from public.matches m where m.id = match_id and (select auth.uid()) in (m.white, m.black)));
drop policy if exists "queue_read_own" on public.matchmaking_queue;
create policy "queue_read_own" on public.matchmaking_queue for select using ((select auth.uid()) = user_id);

-- Konto löschen räumt match_presence per Kaskade über user_id auf
create index if not exists match_presence_user on public.match_presence (user_id);
