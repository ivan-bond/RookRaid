-- Rook Raid – 100 Bot-Spieler, Online-Status und Freundschaftsspiele.
--
-- Bot-Spieler: echte Profile (eigenes Konto ohne Anmeldung, Freundescode, Trophäen), damit Suche, Anfragen,
-- Profil und Bilanz wie bei Menschen funktionieren. Sie sind offen als Bot gekennzeichnet (Spielerkarte "bot": true,
-- is_bot in find_player/my_friends/friend_profile). Ihr Verhalten steht in private.bot_players:
--   - Online-Zeiten (deutsche Zeit) für Mo–Fr und Sa/So; "bis" kleiner als "von" = über Mitternacht; null = nie.
--   - accepts_friends / accept_minutes: nimmt Anfragen nach so vielen Minuten an, aber nur, während er online ist.
--     Wer nicht annimmt, lässt die Anfrage liegen (sie verfällt nach 30 Tagen wie jede Anfrage).
--   - accepts_matches: nimmt Freundschaftsspiele an (nach wenigen Sekunden), wenn er online ist und nicht spielt.
-- Gewertete Partien: Findet die Gegnersuche nach 10 s keinen Menschen, spielt man gegen einen Bot-Spieler, der gerade
-- online ist und ähnlich viele Trophäen hat. Beide Seiten gewinnen oder verlieren Trophäen. Stündlich spielen
-- Bot-Spieler, die online sind, außerdem "im Hintergrund" (zufällig, zurück zu ihrem Startwert gezogen).
-- Gibt es keinen passenden, bleibt es beim bisherigen Trainingsgegner.
--
-- Online-Status: Die App meldet sich alle 15 s (touch_online), Freunde sehen "online", wenn das höchstens 2 Minuten
-- her ist – außer man hat es ausgeschaltet (set_show_online). Bot-Spieler folgen ihren Online-Zeiten.
--
-- Freundschaftsspiele: 5 | 0, ohne Trophäen, zählen für die Bilanz gegeneinander. Eine Einladung gilt 2 Minuten.

-- pg_net: damit der Wartungsjob push-dispatch aufrufen kann (siehe private.dispatch_bot_push).
create extension if not exists pg_net with schema extensions;

-- ───────────────────────── Bot-Spieler ─────────────────────────
create table if not exists private.bot_players (
  user_id        uuid primary key,
  name           text not null unique,
  avatar         text not null,
  frame          text,
  title          text,
  level          int not null,
  deck           text[] not null,
  ultimate       text not null,
  base_trophies  int not null,
  weekday_from   smallint,
  weekday_to     smallint,
  weekend_from   smallint,
  weekend_to     smallint,
  accepts_friends boolean not null,
  accept_minutes int,
  accepts_matches boolean not null,
  start_wins     int not null,
  start_losses   int not null
);
revoke all on private.bot_players from public, anon, authenticated;

insert into private.bot_players (user_id, name, avatar, frame, title, level, deck, ultimate, base_trophies,
  weekday_from, weekday_to, weekend_from, weekend_to, accepts_friends, accept_minutes, accepts_matches, start_wins, start_losses)
values
  ('b0700000-0000-4000-8000-000000000001', 'Turmfalke', 'frog', null, 'Bauer', 2, array['sprint','revive','drain','lightning'], 'meteor', 0, 12, 14, 12, 18, false, null, true, 15, 16),
  ('b0700000-0000-4000-8000-000000000002', 'Lena_K', 'owl', null, 'Bauer', 1, array['bulwark','sprint','swap','reinforce'], 'coronation', 0, 6, 9, 8, 13, true, 5, true, 5, 4),
  ('b0700000-0000-4000-8000-000000000003', 'Maximus77', 'fox', null, 'Bauer', 1, array['sacrifice','bulwark','advance','bishopize'], 'rebirth', 1, 3, 9, 4, 11, true, 3, false, 8, 6),
  ('b0700000-0000-4000-8000-000000000004', 'SchachMatze', 'penguin', null, 'Knappe', 3, array['reinforce','revive','knighting','advance'], 'iceAge', 0, 19, 1, 14, 2, true, 10, false, 4, 4),
  ('b0700000-0000-4000-8000-000000000005', 'Jonas.B', 'bear', null, 'Bauer', 1, array['focus','bulwark','freeze','swap'], 'rebirth', 23, 17, 23, 10, 23, true, 90, false, 14, 15),
  ('b0700000-0000-4000-8000-000000000006', 'Rochade_Rudi', 'penguin', null, 'Bauer', 1, array['bulwark','lightning','bishopize','revive'], 'meteor', 9, 7, 10, 7, 12, true, 60, false, 20, 16),
  ('b0700000-0000-4000-8000-000000000007', 'Emma Zugzwang', 'knight', null, 'Bauer', 2, array['revive','retreat','bulwark','drain'], 'fortress', 24, 16, 22, 9, 21, true, 120, true, 19, 16),
  ('b0700000-0000-4000-8000-000000000008', 'Kaiserbauer', 'bear', null, 'Bauer', 2, array['revive','bulwark','reinforce','freeze'], 'meteor', 64, 18, 24, 11, 24, true, 360, true, 21, 20),
  ('b0700000-0000-4000-8000-000000000009', 'Noah_17', 'bear', null, 'Bauer', 2, array['shield','advance','retreat','knighting'], 'coronation', 39, 6, 9, 8, 13, true, 8, false, 23, 21),
  ('b0700000-0000-4000-8000-000000000010', 'Mia.Springer', 'knight', null, 'Knappe', 3, array['knighting','retreat','sprint','shield'], 'rebirth', 55, 17, 22, 13, 19, true, 8, false, 12, 11),
  ('b0700000-0000-4000-8000-000000000011', 'Felix Fuchs', 'bear', null, 'Bauer', 1, array['retreat','reinforce','sprint','shield'], 'coronation', 76, 15, 21, 10, 22, true, 15, false, 17, 15),
  ('b0700000-0000-4000-8000-000000000012', 'Sophie_R', 'frog', null, 'Bauer', 2, array['drain','focus','reinforce','bulwark'], 'rebirth', 111, 7, 10, 7, 12, true, 2, true, 10, 9),
  ('b0700000-0000-4000-8000-000000000013', 'Leon der Läufer', 'fox', null, 'Bauer', 1, array['bulwark','reinforce','sacrifice','shield'], 'iceAge', 115, 1, 7, 2, 9, true, 90, true, 7, 8),
  ('b0700000-0000-4000-8000-000000000014', 'Hannah88', 'knight', null, 'Knappe', 4, array['reinforce','shield','focus','revive'], 'meteor', 107, 9, 17, 12, 20, false, null, true, 12, 9),
  ('b0700000-0000-4000-8000-000000000015', 'Finn_Opfer', 'fox', null, 'Bauer', 2, array['shield','freeze','revive','bulwark'], 'fortress', 110, 18, 24, 11, 24, true, 45, false, 26, 23),
  ('b0700000-0000-4000-8000-000000000016', 'Clara Gambit', 'knight', null, 'Bauer', 2, array['bulwark','freeze','swap','knighting'], 'rebirth', 137, 3, 9, 4, 11, true, 30, true, 12, 11),
  ('b0700000-0000-4000-8000-000000000017', 'Elias_M', 'penguin', null, 'Bauer', 1, array['sprint','bulwark','swap','knighting'], 'meteor', 167, 17, 23, 10, 23, true, 2, true, 17, 14),
  ('b0700000-0000-4000-8000-000000000018', 'Lina.Dame', 'bear', null, 'Bauer', 2, array['sprint','bishopize','drain','lightning'], 'iceAge', 211, null, null, 9, 22, true, 10, true, 15, 12),
  ('b0700000-0000-4000-8000-000000000019', 'Ben Blitz', 'penguin', null, 'Knappe', 3, array['sprint','swap','lightning','freeze'], 'coronation', 228, 9, 17, 12, 20, true, 8, true, 15, 12),
  ('b0700000-0000-4000-8000-000000000020', 'Ida_Turm', 'owl', null, 'Bauer', 2, array['lightning','shield','freeze','retreat'], 'coronation', 216, 17, 22, 13, 19, false, null, false, 21, 21),
  ('b0700000-0000-4000-8000-000000000021', 'Luca_Rossi', 'bear', null, 'Bauer', 2, array['bulwark','retreat','drain','bishopize'], 'meteor', 263, 9, 17, 12, 20, false, null, false, 30, 30),
  ('b0700000-0000-4000-8000-000000000022', 'Giulia.B', 'bear', null, 'Bauer', 2, array['advance','bulwark','freeze','lightning'], 'meteor', 236, 3, 9, 4, 11, true, 10, false, 29, 25),
  ('b0700000-0000-4000-8000-000000000023', 'Matteo99', 'frog', null, 'Bauer', 2, array['sprint','bulwark','advance','knighting'], 'rebirth', 290, 6, 9, 8, 13, true, 120, true, 23, 20),
  ('b0700000-0000-4000-8000-000000000024', 'Chiara_Re', 'owl', null, 'Knappe', 4, array['bishopize','sprint','reinforce','bulwark'], 'rebirth', 282, 12, 14, 12, 18, true, 90, true, 29, 32),
  ('b0700000-0000-4000-8000-000000000025', 'Lucas Martin', 'owl', null, 'Knappe', 4, array['shield','freeze','revive','advance'], 'meteor', 334, null, null, 9, 22, true, 180, true, 18, 19),
  ('b0700000-0000-4000-8000-000000000026', 'Chloé_P', 'penguin', null, 'Bauer', 2, array['freeze','sprint','focus','bishopize'], 'rebirth', 342, 15, 21, 10, 22, true, 240, true, 30, 25),
  ('b0700000-0000-4000-8000-000000000027', 'Hugo Fou', 'frog', null, 'Bauer', 2, array['sprint','reinforce','freeze','lightning'], 'coronation', 333, 23, 6, 23, 7, false, null, false, 25, 22),
  ('b0700000-0000-4000-8000-000000000028', 'Manon.L', 'fox', null, 'Ritter', 5, array['bulwark','revive','shield','reinforce'], 'meteor', 369, 6, 9, 8, 13, true, 3, true, 34, 35),
  ('b0700000-0000-4000-8000-000000000029', 'Pablo_Torre', 'fox', null, 'Ritter', 5, array['sprint','bulwark','freeze','sacrifice'], 'coronation', 390, 7, 10, 7, 12, false, null, false, 31, 32),
  ('b0700000-0000-4000-8000-000000000030', 'Lucía Reina', 'bear', null, 'Ritter', 5, array['bulwark','shield','sprint','focus'], 'fortress', 435, 20, 2, 20, 3, true, 10, false, 32, 27),
  ('b0700000-0000-4000-8000-000000000031', 'Diego_88', 'owl', null, 'Knappe', 3, array['swap','reinforce','knighting','lightning'], 'iceAge', 422, 7, 10, 7, 12, true, 15, false, 37, 33),
  ('b0700000-0000-4000-8000-000000000032', 'Carmen_M', 'penguin', null, 'Bauer', 2, array['knighting','lightning','sprint','swap'], 'meteor', 454, 7, 10, 7, 12, true, 45, false, 22, 22),
  ('b0700000-0000-4000-8000-000000000033', 'Oliver Knight', 'penguin', null, 'Knappe', 3, array['drain','sprint','lightning','knighting'], 'coronation', 461, 15, 21, 10, 22, true, 5, false, 29, 26),
  ('b0700000-0000-4000-8000-000000000034', 'Amelia_J', 'penguin', null, 'Knappe', 4, array['bulwark','retreat','sprint','drain'], 'iceAge', 497, 23, 6, 23, 7, true, 480, false, 29, 30),
  ('b0700000-0000-4000-8000-000000000035', 'Harry.B', 'owl', null, 'Ritter', 6, array['focus','advance','sprint','reinforce'], 'meteor', 518, 6, 9, 8, 13, true, 5, true, 32, 26),
  ('b0700000-0000-4000-8000-000000000036', 'Isla_Rook', 'penguin', null, 'Ritter', 5, array['sprint','bulwark','reinforce','focus'], 'rebirth', 528, 16, 22, 9, 21, true, 15, true, 27, 26),
  ('b0700000-0000-4000-8000-000000000037', 'Jack_Castle', 'penguin', null, 'Knappe', 3, array['knighting','shield','revive','bishopize'], 'fortress', 589, 1, 7, 2, 9, false, null, true, 44, 42),
  ('b0700000-0000-4000-8000-000000000038', 'Grace_W', 'knight', null, 'Ritter', 6, array['bulwark','knighting','shield','focus'], 'rebirth', 603, 17, 23, 10, 23, true, 480, true, 36, 32),
  ('b0700000-0000-4000-8000-000000000039', 'Ethan Pawn', 'fox', null, 'Ritter', 5, array['reinforce','revive','focus','shield'], 'fortress', 611, 17, 23, 10, 23, true, 30, true, 48, 39),
  ('b0700000-0000-4000-8000-000000000040', 'Ava.K', 'owl', null, 'Ritter', 6, array['knighting','advance','sprint','lightning'], 'coronation', 613, 12, 14, 12, 18, false, null, false, 34, 36),
  ('b0700000-0000-4000-8000-000000000041', 'Mateusz_W', 'penguin', null, 'Ritter', 5, array['shield','knighting','reinforce','sacrifice'], 'coronation', 684, 16, 22, 9, 21, false, null, true, 56, 46),
  ('b0700000-0000-4000-8000-000000000042', 'Zofia.K', 'lion', 'gold', 'Ritter', 6, array['bulwark','sprint','swap','advance'], 'coronation', 718, 17, 22, 13, 19, true, 120, false, 35, 30),
  ('b0700000-0000-4000-8000-000000000043', 'Jakub77', 'nachtross', 'silver', 'Ritter', 5, array['sprint','focus','retreat','swap'], 'fortress', 745, 10, 18, null, null, true, 480, true, 40, 35),
  ('b0700000-0000-4000-8000-000000000044', 'Anna_Nowak', 'lion', null, 'Ritter', 7, array['retreat','freeze','drain','advance'], 'meteor', 720, 17, 22, 13, 19, true, 120, true, 40, 40),
  ('b0700000-0000-4000-8000-000000000045', 'Daan_V', 'wolf', null, 'Ritter', 6, array['lightning','sprint','knighting','retreat'], 'coronation', 741, 1, 7, 2, 9, false, null, true, 53, 46),
  ('b0700000-0000-4000-8000-000000000046', 'Sanne.B', 'nachtross', null, 'Knappe', 4, array['sacrifice','knighting','lightning','drain'], 'rebirth', 808, 1, 7, 2, 9, true, 30, true, 50, 40),
  ('b0700000-0000-4000-8000-000000000047', 'Lars_Eriksen', 'nachtross', 'silver', 'Ritter', 7, array['shield','advance','knighting','bulwark'], 'iceAge', 847, 3, 9, 4, 11, true, 60, true, 46, 46),
  ('b0700000-0000-4000-8000-000000000048', 'Freja_N', 'fox', null, 'Ritter', 7, array['lightning','bishopize','drain','swap'], 'meteor', 858, 23, 6, 23, 7, false, null, true, 51, 48),
  ('b0700000-0000-4000-8000-000000000049', 'Mikko_K', 'wolf', null, 'Ritter', 6, array['revive','shield','drain','freeze'], 'iceAge', 854, 23, 6, 23, 7, true, 30, false, 48, 49),
  ('b0700000-0000-4000-8000-000000000050', 'Aino.L', 'knight', 'silver', 'Turmwächter', 8, array['sacrifice','focus','drain','advance'], 'iceAge', 925, 23, 6, 23, 7, false, null, true, 49, 53),
  ('b0700000-0000-4000-8000-000000000051', 'Emre_Y', 'knight', 'puzzle', 'Turmwächter', 8, array['shield','drain','freeze','retreat'], 'fortress', 918, 16, 22, 9, 21, true, 240, false, 57, 56),
  ('b0700000-0000-4000-8000-000000000052', 'Elif.K', 'frog', 'flame', 'Ritter', 6, array['freeze','reinforce','focus','lightning'], 'coronation', 984, 15, 21, 10, 22, true, 5, true, 57, 46),
  ('b0700000-0000-4000-8000-000000000053', 'Andrei_P', 'wolf', 'silver', 'Ritter', 6, array['knighting','sacrifice','revive','drain'], 'rebirth', 1020, 6, 9, 8, 13, true, 90, true, 55, 57),
  ('b0700000-0000-4000-8000-000000000054', 'Ioana_M', 'bear', null, 'Ritter', 6, array['reinforce','bulwark','swap','shield'], 'meteor', 1004, 1, 7, 2, 9, true, 8, false, 58, 60),
  ('b0700000-0000-4000-8000-000000000055', 'Dmitri_S', 'knight', null, 'Ritter', 7, array['sprint','reinforce','shield','lightning'], 'rebirth', 1053, 15, 21, 10, 22, true, 5, true, 62, 50),
  ('b0700000-0000-4000-8000-000000000056', 'Katya.V', 'nachtross', 'puzzle', 'Turmwächter', 8, array['bulwark','sprint','bishopize','drain'], 'iceAge', 1058, 10, 18, null, null, true, 45, false, 48, 51),
  ('b0700000-0000-4000-8000-000000000057', 'Wei_Chen', 'lion', null, 'Ritter', 7, array['reinforce','focus','swap','knighting'], 'rebirth', 1129, 12, 14, 12, 18, false, null, true, 63, 66),
  ('b0700000-0000-4000-8000-000000000058', 'LiNa_88', 'frog', 'puzzle', 'Turmwächter', 8, array['reinforce','shield','retreat','advance'], 'fortress', 1114, 12, 14, 12, 18, false, null, true, 67, 53),
  ('b0700000-0000-4000-8000-000000000059', 'Haruto_T', 'penguin', null, 'Turmwächter', 9, array['reinforce','bishopize','sprint','focus'], 'iceAge', 1179, 12, 14, 12, 18, true, 360, true, 75, 64),
  ('b0700000-0000-4000-8000-000000000060', 'Yuki.S', 'knight', 'silver', 'Ritter', 6, array['bulwark','sacrifice','retreat','drain'], 'fortress', 1173, 17, 22, 13, 19, true, 10, true, 69, 68),
  ('b0700000-0000-4000-8000-000000000061', 'Minjun_K', 'wolf', null, 'Ritter', 7, array['drain','knighting','revive','retreat'], 'coronation', 1197, 16, 22, 9, 21, true, 120, false, 69, 71),
  ('b0700000-0000-4000-8000-000000000062', 'Seo-yeon', 'bear', null, 'Turmwächter', 8, array['revive','bulwark','reinforce','advance'], 'coronation', 1264, 20, 2, 20, 3, false, null, false, 68, 70),
  ('b0700000-0000-4000-8000-000000000063', 'Arjun_P', 'owl', null, 'Ritter', 7, array['sacrifice','shield','bulwark','swap'], 'iceAge', 1277, 10, 18, null, null, true, 30, false, 57, 58),
  ('b0700000-0000-4000-8000-000000000064', 'Priya.S', 'owl', 'puzzle', 'Ritter', 7, array['shield','reinforce','sacrifice','freeze'], 'meteor', 1335, 9, 17, 12, 20, false, null, true, 70, 68),
  ('b0700000-0000-4000-8000-000000000065', 'Lucas_Silva', 'wolf', null, 'Turmwächter', 9, array['retreat','lightning','reinforce','drain'], 'iceAge', 1325, 7, 10, 7, 12, true, 480, true, 62, 60),
  ('b0700000-0000-4000-8000-000000000066', 'Beatriz.C', 'wolf', 'flame', 'Turmwächter', 9, array['shield','freeze','swap','sprint'], 'fortress', 1383, 12, 14, 12, 18, true, 60, true, 71, 69),
  ('b0700000-0000-4000-8000-000000000067', 'Mateo_G', 'owl', 'puzzle', 'Turmwächter', 8, array['bulwark','advance','knighting','revive'], 'rebirth', 1417, 17, 22, 13, 19, true, 5, true, 76, 69),
  ('b0700000-0000-4000-8000-000000000068', 'Valentina_R', 'bear', 'gold', 'Turmwächter', 9, array['sacrifice','bishopize','knighting','shield'], 'coronation', 1472, 9, 17, 12, 20, true, 2, true, 67, 69),
  ('b0700000-0000-4000-8000-000000000069', 'Omar_H', 'wolf', 'puzzle', 'Turmwächter', 9, array['revive','shield','advance','retreat'], 'iceAge', 1470, 17, 22, 13, 19, true, 30, true, 78, 78),
  ('b0700000-0000-4000-8000-000000000070', 'Layla.A', 'lion', null, 'Turmwächter', 10, array['retreat','swap','freeze','revive'], 'iceAge', 1488, null, null, 9, 22, true, 120, true, 70, 59),
  ('b0700000-0000-4000-8000-000000000071', 'Kofi_M', 'wizard', null, 'Großmeister', 11, array['knighting','lightning','drain','sprint'], 'iceAge', 1554, null, null, 9, 22, true, 180, true, 69, 67),
  ('b0700000-0000-4000-8000-000000000072', 'Amara_O', 'wolf', 'nebula', 'Turmwächter', 9, array['drain','lightning','reinforce','shield'], 'rebirth', 1559, 1, 7, 2, 9, true, 10, false, 76, 61),
  ('b0700000-0000-4000-8000-000000000073', 'NightRook', 'wizard', null, 'Turmwächter', 9, array['advance','knighting','freeze','reinforce'], 'coronation', 1605, 19, 1, 14, 2, false, null, false, 86, 82),
  ('b0700000-0000-4000-8000-000000000074', 'PawnStorm', 'dragon', null, 'Turmwächter', 9, array['shield','focus','lightning','reinforce'], 'meteor', 1623, 7, 10, 7, 12, true, 20, true, 89, 81),
  ('b0700000-0000-4000-8000-000000000075', 'Gambitqueen', 'dragon', 'crown', 'Großmeister', 11, array['freeze','lightning','advance','sacrifice'], 'rebirth', 1660, 23, 6, 23, 7, true, 2, false, 86, 69),
  ('b0700000-0000-4000-8000-000000000076', 'Mattsetzer', 'dragon', 'nebula', 'Turmwächter', 10, array['bishopize','focus','shield','freeze'], 'rebirth', 1740, 12, 14, 12, 18, true, 30, false, 96, 86),
  ('b0700000-0000-4000-8000-000000000077', 'RookieRaider', 'dragon', 'nebula', 'Großmeister', 11, array['reinforce','retreat','knighting','drain'], 'rebirth', 1752, 19, 1, 14, 2, false, null, true, 94, 80),
  ('b0700000-0000-4000-8000-000000000078', 'Zugzwang99', 'wizard', 'nebula', 'Großmeister', 12, array['shield','sacrifice','knighting','revive'], 'iceAge', 1807, 18, 24, 11, 24, true, 120, true, 85, 77),
  ('b0700000-0000-4000-8000-000000000079', 'EnPassant', 'nachtross', null, 'Großmeister', 11, array['revive','reinforce','shield','sprint'], 'meteor', 1789, 17, 23, 10, 23, true, 30, false, 82, 86),
  ('b0700000-0000-4000-8000-000000000080', 'Fianchetto', 'wizard', 'ruby', 'Turmwächter', 10, array['shield','knighting','bishopize','lightning'], 'meteor', 1850, 6, 9, 8, 13, true, 240, true, 88, 81),
  ('b0700000-0000-4000-8000-000000000081', 'Blitzkoenig', 'wizard', null, 'Großmeister', 12, array['shield','reinforce','freeze','drain'], 'rebirth', 1902, 3, 9, 4, 11, false, null, false, 96, 102),
  ('b0700000-0000-4000-8000-000000000082', 'Bauernsturm', 'wizard', 'ruby', 'Großmeister', 11, array['sacrifice','bulwark','shield','bishopize'], 'iceAge', 1951, 15, 21, 10, 22, true, 15, false, 103, 102),
  ('b0700000-0000-4000-8000-000000000083', 'Springerfee', 'nachtross', 'nebula', 'Großmeister', 11, array['swap','sprint','knighting','reinforce'], 'rebirth', 1939, 19, 1, 14, 2, false, null, false, 86, 83),
  ('b0700000-0000-4000-8000-000000000084', 'Läuferpaar', 'wizard', 'nebula', 'Turmwächter', 10, array['bulwark','drain','sacrifice','retreat'], 'fortress', 1968, 17, 22, 13, 19, true, 60, false, 94, 90),
  ('b0700000-0000-4000-8000-000000000085', 'Damenflügel', 'wizard', null, 'Großmeister', 12, array['sprint','advance','swap','retreat'], 'iceAge', 2057, 15, 21, 10, 22, true, 30, true, 103, 98),
  ('b0700000-0000-4000-8000-000000000086', 'TurmBau_42', 'nachtross', 'nebula', 'Großmeister', 11, array['sacrifice','focus','bulwark','shield'], 'iceAge', 2082, 15, 21, 10, 22, true, 45, false, 110, 102),
  ('b0700000-0000-4000-8000-000000000087', 'Schwarzfeld', 'dragon', 'crown', 'Großmeister', 12, array['lightning','revive','advance','reinforce'], 'iceAge', 2097, 10, 18, null, null, false, null, true, 107, 98),
  ('b0700000-0000-4000-8000-000000000088', 'Weißer Turm', 'wizard', 'crown', 'Großmeister', 13, array['shield','sacrifice','lightning','drain'], 'rebirth', 2132, 3, 9, 4, 11, true, 60, true, 106, 104),
  ('b0700000-0000-4000-8000-000000000089', 'Frostzug', 'phoenix', null, 'Großmeister', 14, array['retreat','sprint','reinforce','bulwark'], 'meteor', 2200, 19, 1, 14, 2, true, 15, true, 107, 90),
  ('b0700000-0000-4000-8000-000000000090', 'Kartenhai', 'dragon', null, 'Großmeister', 13, array['sprint','sacrifice','bulwark','focus'], 'coronation', 2230, 17, 23, 10, 23, true, 20, true, 109, 90),
  ('b0700000-0000-4000-8000-000000000091', 'Meteor_Max', 'phoenix', 'legendary', 'Großmeister', 13, array['revive','lightning','reinforce','bulwark'], 'fortress', 2258, 17, 22, 13, 19, true, 120, true, 117, 106),
  ('b0700000-0000-4000-8000-000000000092', 'Eiszeit_Ella', 'wizard', 'legendary', 'Großmeister', 14, array['shield','lightning','freeze','advance'], 'rebirth', 2297, null, null, 9, 22, false, null, true, 108, 102),
  ('b0700000-0000-4000-8000-000000000093', 'Festung_Fritz', 'dragon', 'legendary', 'Großmeister', 14, array['knighting','freeze','shield','revive'], 'meteor', 2332, 18, 24, 11, 24, true, 20, false, 107, 109),
  ('b0700000-0000-4000-8000-000000000094', 'Kronjuwel', 'phoenix', null, 'Großmeister', 12, array['freeze','shield','reinforce','sprint'], 'meteor', 2346, 17, 22, 13, 19, true, 8, true, 114, 100),
  ('b0700000-0000-4000-8000-000000000095', 'Phönixfeuer', 'phoenix', 'legendary', 'Großmeister', 12, array['freeze','bishopize','bulwark','advance'], 'iceAge', 2420, 17, 22, 13, 19, false, null, true, 114, 93),
  ('b0700000-0000-4000-8000-000000000096', 'Drachenzahn', 'wizard', 'legendary', 'Großmeister', 14, array['bishopize','sacrifice','swap','retreat'], 'meteor', 2474, 20, 2, 20, 3, false, null, true, 124, 122),
  ('b0700000-0000-4000-8000-000000000097', 'Nachtross_X', 'phoenix', null, 'Großmeister', 13, array['retreat','revive','drain','focus'], 'iceAge', 2460, 6, 9, 8, 13, true, 20, false, 131, 107),
  ('b0700000-0000-4000-8000-000000000098', 'Eulenauge', 'phoenix', 'prism', 'Großmeister', 13, array['shield','freeze','sacrifice','focus'], 'rebirth', 2515, 10, 18, null, null, false, null, true, 111, 117),
  ('b0700000-0000-4000-8000-000000000099', 'Wolfsrudel', 'wizard', 'prism', 'Großmeister', 14, array['advance','bulwark','swap','reinforce'], 'rebirth', 2564, 17, 22, 13, 19, true, 240, false, 112, 114),
  ('b0700000-0000-4000-8000-000000000100', 'Löwenherz', 'wizard', 'prism', 'Großmeister', 14, array['retreat','lightning','sprint','bulwark'], 'iceAge', 2572, 15, 21, 10, 22, true, 90, false, 122, 133)

on conflict (user_id) do update set
  name = excluded.name, avatar = excluded.avatar, frame = excluded.frame, title = excluded.title, level = excluded.level,
  deck = excluded.deck, ultimate = excluded.ultimate, base_trophies = excluded.base_trophies,
  weekday_from = excluded.weekday_from, weekday_to = excluded.weekday_to,
  weekend_from = excluded.weekend_from, weekend_to = excluded.weekend_to,
  accepts_friends = excluded.accepts_friends, accept_minutes = excluded.accept_minutes,
  accepts_matches = excluded.accepts_matches, start_wins = excluded.start_wins, start_losses = excluded.start_losses;

-- Konten, Profile und Fortschritt der Bot-Spieler anlegen (fehlende nachholen; bestehende behalten ihre Trophäen).
-- Ist ein Name schon an einen Menschen vergeben, bekommt der Bot zwei Ziffern dazu.
create or replace function private.seed_bot_players()
returns int language plpgsql security definer set search_path = '' as $$
declare b record; nm text; n int := 0;
begin
  for b in select * from private.bot_players order by user_id loop
    insert into auth.users (id) values (b.user_id) on conflict do nothing;
    nm := b.name;
    if exists (select 1 from public.profiles where lower(display_name) = lower(nm) and id <> b.user_id) then
      nm := left(b.name, 14) || right(b.user_id::text, 2);
    end if;
    insert into public.profiles (id, display_name, avatar, frame, title, level, created_at)
    values (b.user_id, nm, b.avatar, b.frame, b.title, b.level,
            now() - make_interval(days => 20 + (('x' || right(b.user_id::text, 4))::bit(16)::int * 7) % 340))
    on conflict (id) do update set avatar = excluded.avatar, frame = excluded.frame, title = excluded.title,
                                   level = excluded.level;
    insert into public.progress (user_id, trophies, best_trophies, online_wins, online_losses)
    values (b.user_id, b.base_trophies, b.base_trophies + 40, b.start_wins, b.start_losses)
    on conflict (user_id) do nothing;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke execute on function private.seed_bot_players() from public, anon, authenticated;
select private.seed_bot_players();

create or replace function private.is_bot(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.bot_players where user_id = p_user)
$$;

-- Ist der Bot-Spieler laut seinen Online-Zeiten gerade da? (deutsche Zeit)
create or replace function private.bot_online(p_user uuid, p_at timestamptz default now())
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  b private.bot_players;
  t timestamp := p_at at time zone 'Europe/Berlin';
  h numeric := extract(hour from t) + extract(minute from t) / 60.0;
  weekend boolean := extract(isodow from t) >= 6;
  f int; e int;
begin
  select * into b from private.bot_players where user_id = p_user;
  if b.user_id is null then return false; end if;
  f := case when weekend then b.weekend_from else b.weekday_from end;
  e := case when weekend then b.weekend_to else b.weekday_to end;
  if f is null or e is null then return false; end if;
  if f < e then return h >= f and h < e; end if;
  return h >= f or h < e;
end $$;

-- ───────────────────────── Online-Status ─────────────────────────
alter table public.profiles add column if not exists last_seen_at timestamptz;
alter table public.profiles add column if not exists show_online boolean not null default true;

create or replace function private.online(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case when private.is_bot(p_user) then private.bot_online(p_user)
              else coalesce((select p.show_online and p.last_seen_at > now() - interval '2 minutes'
                               from public.profiles p where p.id = p_user), false) end
$$;

revoke execute on function private.is_bot(uuid) from public, anon, authenticated;
revoke execute on function private.bot_online(uuid, timestamptz) from public, anon, authenticated;
revoke execute on function private.online(uuid) from public, anon, authenticated;

create or replace function public.set_show_online(p_show boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me uuid := private.me_with_account();
begin
  update profiles set show_online = coalesce(p_show, true) where id = me;
end $$;

-- ───────────────────────── Partien: Bot-Spieler und ungewertete Partien ─────────────────────────
-- Die Bot-Seite bleibt in white/black leer (wie beim Trainingsgegner: die Partie läuft auf dem Gerät).
-- bot_player sagt, welcher Bot-Spieler es ist; rated = false bei Freundschaftsspielen (keine Trophäen).
alter table public.matches add column if not exists bot_player uuid references public.profiles(id) on delete set null;
alter table public.matches add column if not exists rated boolean not null default true;
create index if not exists matches_active_bot_player on public.matches (bot_player) where status = 'active';
create index if not exists matches_bot_player on public.matches (bot_player) where bot_player is not null;

-- Spielerkarte eines Bot-Spielers (wie PlayerCard in der App, dazu "bot": true für die Kennzeichnung).
create or replace function private.bot_card(p_user uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('name', p.display_name, 'avatar', p.avatar, 'frame', p.frame, 'title', p.title,
                            'trophies', coalesce(g.trophies, 0), 'level', p.level, 'pieceSet', null, 'bot', true)
    from public.profiles p left join public.progress g on g.user_id = p.id
   where p.id = p_user
$$;

-- Bot-Partie (gewertet oder Freundschaftsspiel) gegen einen Bot-Spieler anlegen.
create or replace function private.create_bot_player_match(p_human uuid, p_bot uuid, p_card jsonb, p_deck text[],
                                                           p_ultimate text, p_rules_version int, p_human_white boolean,
                                                           p_rated boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  b private.bot_players;
  t int;
  card jsonb := private.bot_card(p_bot);
  mid uuid;
begin
  select * into b from private.bot_players where user_id = p_bot;
  select trophies into t from progress where user_id = p_bot;
  if p_human_white then
    mid := create_match(p_human, null, p_card, card, p_deck, b.deck, p_ultimate, b.ultimate,
                        p_rules_version, 'blitz5', true, bot_level_for(t));
    update matches set bot_player = p_bot, rated = p_rated, trophies_black = t where id = mid;
  else
    mid := create_match(null, p_human, card, p_card, b.deck, p_deck, b.ultimate, p_ultimate,
                        p_rules_version, 'blitz5', true, bot_level_for(t));
    update matches set bot_player = p_bot, rated = p_rated, trophies_white = t where id = mid;
  end if;
  return mid;
end $$;
revoke execute on function private.bot_card(uuid) from public, anon, authenticated;
revoke execute on function private.create_bot_player_match(uuid, uuid, jsonb, text[], text, int, boolean, boolean) from public, anon, authenticated;

-- Gegnersuche ohne Menschen: zuerst ein Bot-Spieler (online, ±300 Trophäen, gerade frei, nicht blockiert),
-- sonst der Trainingsgegner. Neu in der Antwort: bot_player, bot_card, bot_deck, bot_ultimate (die App spielt
-- damit; p_bot_card/p_bot_deck/p_bot_ultimate gelten nur noch für den Trainingsgegner).
drop function if exists public.start_bot_match(int, text, text[], text, jsonb, jsonb, text[], text, boolean);
create function public.start_bot_match(p_rules_version int, p_time_control text, p_deck text[], p_ultimate text,
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
  -- Doppelter Start: dieselbe, gerade angelegte Bot-Partie zurückgeben.
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

  select b.user_id into pick
    from private.bot_players b join progress g on g.user_id = b.user_id
   where abs(g.trophies - t) <= 300
     and private.bot_online(b.user_id)
     and not private.blocked_between(me, b.user_id)
     and not exists (select 1 from matches x where x.status = 'active' and x.bot_player = b.user_id)
   order by abs(g.trophies - t) + random() * 200
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

-- Trophäen: auch der Bot-Spieler gewinnt oder verliert. Ungewertete Partien (Freundschaftsspiele) ändern nichts.
create or replace function public.finish_match(p_match uuid, p_result text, p_winner text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  m matches;
  dw int;
  db int;
  white_faces int;
  black_faces int;
  white_who uuid;
  black_who uuid;
begin
  select * into m from matches where id = p_match for update;
  if m.id is null then raise exception 'match_not_found'; end if;
  if m.status <> 'active' then return jsonb_build_object('status', m.status, 'already', true); end if;
  if p_result = 'aborted' then
    update matches set status = 'aborted', result = 'aborted', ended_at = now() where id = p_match;
    return jsonb_build_object('status', 'aborted');
  end if;
  if m.rated then
    -- Wert des Gegners zum Partiebeginn. Der Trainingsgegner hat keinen Fortschritt: seine Stufenmitte.
    white_faces := coalesce(m.trophies_black,
      case when m.black is null then bot_rating(m.bot_level)
           else (select trophies from progress where user_id = m.black) end);
    black_faces := coalesce(m.trophies_white,
      case when m.white is null then bot_rating(m.bot_level)
           else (select trophies from progress where user_id = m.white) end);
    white_who := coalesce(m.white, case when m.is_bot then m.bot_player end);
    black_who := coalesce(m.black, case when m.is_bot then m.bot_player end);
    if white_who is not null then
      dw := apply_result(white_who, case when p_winner is null then 'draw' when p_winner = 'white' then 'win' else 'loss' end, white_faces);
    end if;
    if black_who is not null then
      db := apply_result(black_who, case when p_winner is null then 'draw' when p_winner = 'black' then 'win' else 'loss' end, black_faces);
    end if;
  end if;
  update matches set status = 'finished', result = p_result, winner_color = p_winner, draw_offer_by = null,
                     trophy_delta_white = dw, trophy_delta_black = db, ended_at = now()
  where id = p_match;
  return jsonb_build_object('status', 'finished', 'result', p_result, 'winner', p_winner,
                            'trophy_delta_white', dw, 'trophy_delta_black', db);
end $$;
revoke execute on function public.finish_match(uuid, text, text) from public, anon, authenticated;
grant execute on function public.finish_match(uuid, text, text) to service_role;

-- ───────────────────────── Freunde: Bot-Kennzeichen und Online-Status ─────────────────────────
drop function if exists public.find_player(text);
create function public.find_player(p_query text)
returns table (user_id uuid, display_name text, avatar text, frame text, title text, level int, trophies int, relation text,
               is_bot boolean)
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
    select p.id, p.display_name, p.avatar, p.frame, p.title, p.level, coalesce(g.trophies, 0), private.relation(me, p.id),
           private.is_bot(p.id)
      from profiles p left join progress g on g.user_id = p.id
     where (lower(p.display_name) = lower(q) or p.friend_code = code)
       and not private.blocked_between(me, p.id)
     order by (p.id = me), p.display_name
     limit 2;
end $$;

drop function if exists public.my_friends();
create function public.my_friends()
returns table (user_id uuid, display_name text, avatar text, frame text, title text, level int, trophies int,
               relation text, since timestamptz, is_bot boolean, online boolean)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  return query
    select p.id, p.display_name, p.avatar, p.frame, p.title, p.level, coalesce(g.trophies, 0),
           case when f.status = 'accepted' then 'friend' when f.requester = me then 'outgoing' else 'incoming' end,
           coalesce(f.responded_at, f.created_at),
           private.is_bot(p.id),
           f.status = 'accepted' and private.online(p.id)
      from friendships f
      join profiles p on p.id = case when f.requester = me then f.addressee else f.requester end
      left join progress g on g.user_id = p.id
     where me in (f.requester, f.addressee)
       and (f.status = 'accepted' or (f.status = 'pending' and f.created_at > now() - interval '30 days'))
     order by case when f.status = 'accepted' then 1 when f.requester = me then 2 else 0 end,
              (f.status = 'accepted' and private.online(p.id)) desc,
              coalesce(g.trophies, 0) desc, p.display_name;
end $$;

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
           'is_bot', private.is_bot(p.id),
           'online', rel = 'friend' and private.online(p.id),
           'since', (select coalesce(f.responded_at, f.created_at) from friendships f
                      where (f.requester = me and f.addressee = p.id) or (f.requester = p.id and f.addressee = me)))
    into out
    from profiles p left join progress g on g.user_id = p.id
   where p.id = p_user;
  -- Bilanz gegeneinander: Partien Mensch gegen Mensch (gewertet und Freundschaftsspiele) und gegen diesen Bot-Spieler.
  return out || (
    select jsonb_build_object(
             'vs_wins', count(*) filter (where m.winner_color is not null and m.winner_color = (case when m.white = me then 'white' else 'black' end)),
             'vs_losses', count(*) filter (where m.winner_color is not null and m.winner_color <> (case when m.white = me then 'white' else 'black' end)),
             'vs_draws', count(*) filter (where m.winner_color is null))
      from matches m
     where m.status = 'finished'
       and (((m.white = me and m.black = p_user) or (m.white = p_user and m.black = me))
            or (m.is_bot and m.bot_player = p_user and me in (m.white, m.black))));
end $$;

-- ───────────────────────── Push: neue Art "match_invite" ─────────────────────────
alter table public.push_outbox drop constraint if exists push_outbox_kind_check;
alter table public.push_outbox add constraint push_outbox_kind_check
  check (kind in ('friend_request', 'friend_accepted', 'match_invite'));

-- Für push-dispatch, vom Wartungsjob ausgelöst: Nachrichten, die Bot-Spieler ausgelöst haben (angenommene Anfragen).
create or replace function public.claim_bot_push_outbox()
returns table (kind text, actor_name text, token text, platform text, environment text, subscription jsonb, locale text)
language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
begin
  return query
    with picked as (
      select o.id from push_outbox o
       where o.sent_at is null and o.created_at > now() - interval '1 day'
         and exists (select 1 from private.bot_players b where b.user_id = o.actor)
       order by o.id limit 100
       for update skip locked),
    claimed as (
      update push_outbox o set sent_at = now() from picked where o.id = picked.id
      returning o.recipient, o.kind, o.actor_name)
    select c.kind, c.actor_name, t.token, t.platform, t.environment, t.subscription, t.locale
      from claimed c join push_tokens t on t.user_id = c.recipient;
end $$;
revoke execute on function public.claim_bot_push_outbox() from public, anon, authenticated;
grant execute on function public.claim_bot_push_outbox() to service_role;

-- Ruft push-dispatch auf, wenn Bot-Spieler etwas ausgelöst haben. Braucht pg_net und zwei Einträge im Vault:
-- rookraid_project_url (https://<ref>.supabase.co) und rookraid_cron_secret (gleich dem Function-Secret CRON_SECRET).
-- Fehlt etwas, passiert nichts (die Anfrage ist trotzdem angenommen, nur ohne Push).
create or replace function private.dispatch_bot_push()
returns void language plpgsql security definer set search_path = '' as $$
declare url text; secret text;
begin
  if not exists (select 1 from public.push_outbox o join private.bot_players b on b.user_id = o.actor
                  where o.sent_at is null and o.created_at > now() - interval '1 day') then
    return;
  end if;
  if to_regclass('vault.decrypted_secrets') is null
     or not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'net' and p.proname = 'http_post') then
    return;
  end if;
  execute $q$select (select decrypted_secret from vault.decrypted_secrets where name = 'rookraid_project_url'),
                    (select decrypted_secret from vault.decrypted_secrets where name = 'rookraid_cron_secret')$q$
     into url, secret;
  if url is null or secret is null then return; end if;
  execute 'select net.http_post(url := $1, body := $2, headers := $3)'
    using rtrim(url, '/') || '/functions/v1/push-dispatch', '{}'::jsonb,
          jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', secret);
end $$;
revoke execute on function private.dispatch_bot_push() from public, anon, authenticated;

-- ───────────────────────── Bot-Spieler: Anfragen annehmen (jede Minute) ─────────────────────────
create or replace function private.run_bot_players()
returns int language plpgsql security definer set search_path = '' as $$
declare r record; n int := 0;
begin
  for r in
    select f.requester, f.addressee
      from public.friendships f join private.bot_players b on b.user_id = f.addressee
     where f.status = 'pending' and f.created_at > now() - interval '30 days'
       and b.accepts_friends and f.created_at + make_interval(mins => b.accept_minutes) <= now()
       and private.bot_online(b.user_id)
  loop
    begin
      perform private.lock_pair(r.requester, r.addressee);
      perform private.accept_friendship(r.requester, r.addressee);
      n := n + 1;
    exception when others then
      null;   -- z. B. friend_limit: die Anfrage bleibt liegen
    end;
  end loop;
  perform private.dispatch_bot_push();
  return n;
end $$;
revoke execute on function private.run_bot_players() from public, anon, authenticated;

-- Stündlich: Bot-Spieler, die online und frei sind, spielen mit 30 % Wahrscheinlichkeit eine Partie "im Hintergrund".
-- Die Siegchance zieht sie zu ihrem Startwert zurück, damit sie nicht alle nach oben oder unten wandern.
create or replace function private.drift_bot_trophies()
returns int language plpgsql security definer set search_path = '' as $$
declare r record; p numeric; outcome text; n int := 0;
begin
  for r in
    select b.user_id, b.base_trophies, g.trophies
      from private.bot_players b join public.progress g on g.user_id = b.user_id
     where private.bot_online(b.user_id)
       and not exists (select 1 from public.matches x where x.status = 'active' and x.bot_player = b.user_id)
  loop
    if random() < 0.3 then
      p := least(0.85, greatest(0.15, 0.5 + (r.base_trophies - r.trophies) / 800.0));
      outcome := case when random() < 0.06 then 'draw' when random() < p then 'win' else 'loss' end;
      perform public.apply_result(r.user_id, outcome, greatest(0, r.trophies + (random() * 200 - 100)::int));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
revoke execute on function private.drift_bot_trophies() from public, anon, authenticated;

-- ───────────────────────── Freundschaftsspiele ─────────────────────────
create table if not exists public.match_invites (
  id            uuid primary key default gen_random_uuid(),
  inviter       uuid not null references public.profiles(id) on delete cascade,
  invitee       uuid not null references public.profiles(id) on delete cascade,
  rules_version int not null,
  deck          text[] not null,
  ultimate      text not null,
  card          jsonb not null,
  status        text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  match_id      uuid references public.matches(id) on delete set null,
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  check (inviter <> invitee)
);
create index if not exists match_invites_invitee on public.match_invites (invitee) where status = 'pending';
create index if not exists match_invites_inviter on public.match_invites (inviter);
alter table public.match_invites enable row level security;
revoke all on public.match_invites from anon, authenticated;

-- Einladen (nur Freunde). Eine offene Einladung je Spieler: eine neue ersetzt die alte. Der Eingeladene bekommt
-- einen Push (die App ruft danach push-dispatch auf). Bot-Spieler antworten in friend_match_status.
create or replace function public.invite_friend_match(p_user uuid, p_rules_version int, p_deck text[], p_ultimate text, p_card jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  new_id uuid;
begin
  perform check_deck(p_deck, p_ultimate);
  if not exists (select 1 from rules_config where version = p_rules_version and active) then raise exception 'rules_outdated'; end if;
  if p_user is null or private.relation(me, p_user) <> 'friend' or private.blocked_between(me, p_user) then
    raise exception 'not_friends';
  end if;
  if not private.rate_ok(me, 'match_invite', 30, interval '1 hour') then raise exception 'too_many_requests'; end if;
  update match_invites set status = 'cancelled', responded_at = now() where inviter = me and status = 'pending';
  insert into match_invites (inviter, invitee, rules_version, deck, ultimate, card)
  values (me, p_user, p_rules_version, p_deck, p_ultimate, p_card)
  returning match_invites.id into new_id;
  if not private.is_bot(p_user) then
    insert into push_outbox (recipient, actor, kind, actor_name)
    select p_user, me, 'match_invite', p.display_name from profiles p where p.id = me;
  end if;
  return new_id;
end $$;

-- Stand einer Einladung (für beide Seiten). Abgelaufen nach 2 Minuten. Ein Bot-Spieler antwortet nach 3–8 Sekunden:
-- Er nimmt an, wenn er Freundschaftsspiele mag, online ist und gerade nicht spielt – dann steht die Partie schon bereit.
-- Antwort: { status, match_id }
create or replace function public.friend_match_status(p_invite uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare
  me uuid := private.me_with_account();
  inv match_invites;
  b private.bot_players;
  mid uuid;
begin
  select * into inv from match_invites where id = p_invite and me in (inviter, invitee) for update;
  if inv.id is null then raise exception 'not_found'; end if;
  if inv.status = 'pending' and inv.created_at < now() - interval '2 minutes' then
    update match_invites set status = 'expired', responded_at = now() where id = inv.id;
    inv.status := 'expired';
  end if;
  if inv.status = 'pending' and private.is_bot(inv.invitee)
     and now() >= inv.created_at + make_interval(secs => 3 + abs(hashtext(inv.id::text)) % 6) then
    select * into b from private.bot_players where user_id = inv.invitee;
    if b.accepts_matches and private.bot_online(b.user_id)
       and not exists (select 1 from matches x where x.status = 'active' and x.bot_player = b.user_id) then
      mid := private.create_bot_player_match(inv.inviter, inv.invitee, inv.card, inv.deck, inv.ultimate,
                                             inv.rules_version, random() < 0.5, false);
      update match_invites set status = 'accepted', match_id = mid, responded_at = now() where id = inv.id;
      inv.status := 'accepted'; inv.match_id := mid;
    else
      update match_invites set status = 'declined', responded_at = now() where id = inv.id;
      inv.status := 'declined';
    end if;
  end if;
  return jsonb_build_object('status', inv.status, 'match_id', inv.match_id);
end $$;

-- Antworten (Eingeladener). Annehmen legt die Partie an (Farben zufällig) und gibt ihre ID zurück.
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
                        inv.rules_version, 'blitz5', false, null);
  else
    mid := create_match(me, inv.inviter, p_card, inv.card, p_deck, inv.deck, p_ultimate, inv.ultimate,
                        inv.rules_version, 'blitz5', false, null);
  end if;
  update matches set rated = false where id = mid;
  update match_invites set status = 'accepted', match_id = mid, responded_at = now() where id = inv.id;
  return mid;
end $$;

create or replace function public.cancel_friend_match(p_invite uuid)
returns void language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  update match_invites set status = 'cancelled', responded_at = now()
   where id = p_invite and inviter = me and status = 'pending';
end $$;

-- Lebenszeichen der App (alle 15 s im Vordergrund) und offene Einladungen an mich.
create or replace function public.touch_online()
returns jsonb language plpgsql security definer set search_path = public as $$
#variable_conflict use_column
declare me uuid := private.me_with_account();
begin
  update profiles set last_seen_at = now()
   where id = me and (last_seen_at is null or last_seen_at < now() - interval '10 seconds');
  return jsonb_build_object('invites', coalesce((
    select jsonb_agg(jsonb_build_object('id', i.id, 'user_id', p.id, 'display_name', p.display_name, 'avatar', p.avatar,
                                        'frame', p.frame, 'created_at', i.created_at) order by i.created_at desc)
      from match_invites i join profiles p on p.id = i.inviter
     where i.invitee = me and i.status = 'pending' and i.created_at > now() - interval '2 minutes'
       and not private.blocked_between(me, i.inviter)), '[]'::jsonb));
end $$;

-- ───────────────────────── Aufräumen und Jobs ─────────────────────────
create or replace function private.cleanup_social()
returns int language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  delete from public.push_outbox where created_at < now() - interval '2 days';
  delete from public.friendships where status = 'pending' and created_at < now() - interval '30 days';
  delete from public.friendships where status = 'declined' and responded_at < now() - interval '30 days';
  delete from public.player_reports where created_at < now() - interval '1 year';
  delete from public.match_invites where created_at < now() - interval '1 day';
  delete from private.rate_events where at < now() - interval '2 days';
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function private.cleanup_social() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'rookraid-bot-players';
select cron.schedule('rookraid-bot-players', '* * * * *', $$select private.run_bot_players()$$);
select cron.unschedule(jobid) from cron.job where jobname = 'rookraid-bot-drift';
select cron.schedule('rookraid-bot-drift', '23 * * * *', $$select private.drift_bot_trophies()$$);

-- ───────────────────────── Rechte ─────────────────────────
do $$
declare f text;
begin
  foreach f in array array[
    'find_player(text)', 'my_friends()', 'set_show_online(boolean)', 'touch_online()',
    'invite_friend_match(uuid, int, text[], text, jsonb)', 'friend_match_status(uuid)',
    'answer_friend_match(uuid, boolean, int, text[], text, jsonb)', 'cancel_friend_match(uuid)']
  loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
