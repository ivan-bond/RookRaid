# Rook Raid

**Chess with cards, mana and ultimates.** Every turn charges mana, mana pays for spell cards, and a full bar unlocks an
ultimate. Play the bots offline, or ranked 5-minute games online against people and bot players.

- **Version:** 1.0.0 Beta (iOS build 48)
- **Platforms:** iPhone app (SwiftUI, iOS 16+) and browser version (React PWA) at **https://rookraid.com**
- **Backend:** Supabase (Postgres, Auth, Edge Functions, pg_cron), region Frankfurt
- **Languages:** German (source), English, Spanish, French, Italian, Russian, Chinese
- **Contact:** rookraidchess@gmail.com

> **Parity rule:** the iPhone app and the browser version have the same data, design and features. Every change goes into
> both. Only layout and device-only features (haptics, App Store, push permission flow) differ.

---

## Contents

1. [Game rules](#1-game-rules)
2. [Progression](#2-progression)
3. [Repository layout](#3-repository-layout)
4. [Architecture](#4-architecture)
5. [Supabase backend](#5-supabase-backend)
6. [Building and running](#6-building-and-running)
7. [Tests and CI](#7-tests-and-ci)
8. [Translations](#8-translations)
9. [Conventions](#9-conventions)

---

## 1. Game rules

The numbers below come from `RookRaid/Engine/rookraid-rules.json` (**rules version 3**). The same file drives the Swift
engine, the JavaScript engine (web) and the server. Change a number there, never in code.

### Goal and turn

- **Win** by checkmate, or when the opponent's clock runs out. Online games are always **5 | 0** (5 minutes, no increment).
- **One action per turn:** a chess move **or** a card **or** the ultimate.
- **Bonus actions:** some cards (and the Fortress ultimate) don't end the turn. A piece move follows, but no second card or ultimate.
- Normal chess rules apply: castling, en passant, promotion (choose queen, rook, bishop or knight).

### Mana

| Rule | Value |
|---|---|
| Maximum | 10 |
| Start of each own turn | +1 |
| Good move (capture or check) | +1 extra, at most +1 per turn |
| Tactics (fork, pin, skewer, discovered/double check) | Announced and count for achievements, but give **no** mana |

### Deck

- Before a game each player picks **4 cards + 1 ultimate**. Both decks are visible to both players.
- Cards stay in hand all game. Nothing is drawn.
- **Cooldown:** after use, a card recharges for **2 own turns** (Lightning: 3).

### Cards (15 in five roles)

English names as shown in the game, German source names in brackets. "Bonus" means the card doesn't end your turn.

| Card (German name) | Mana | Role | Tier | Effect |
|---|---|---|---|---|
| Pawn Sacrifice (Bauernopfer) | 0 | Mana | Rare | Sacrifice an own pawn, +3 mana. **Bonus** |
| Focus (Konzentration) | 0 | Mana | Epic | +4 mana |
| Mana Drain (Manaraub) | 0 | Control | Epic | Opponent loses half their mana, you gain 2 |
| Advance (Vormarsch) | 3 | Attack | Common | All own pawns step forward (not onto the last rank). **Bonus** |
| Bulwark (Bollwerk) | 2 | Defense | Common | All own pawns protected for one round. **Bonus** |
| Lightning (Blitz) | 2 | Control | Starter | Destroy an enemy pawn that has advanced into your half. Cooldown 3 |
| Reinforcement (Verstärkung) | 1 | Defense | Common | New pawn on your second rank |
| Retreat (Rückzug) | 1 | Defense | Common | Own pawn moves 1–2 squares back. **Bonus** (that pawn then stays) |
| Shield (Schild) | 2 | Defense | Starter | Own piece can't be captured for one round. **Bonus** (that piece then stays) |
| Bodyguard (Leibwache) | 4 | Defense | Rare | King swaps places with an own non-pawn piece. **Bonus** |
| Knighting (Ritterschlag) | 3 | Attack | Common | Own pawn becomes a knight |
| Bishop's Blessing (Läuferweihe) | 3 | Attack | Epic | Own pawn becomes a bishop |
| Rush (Sturmlauf) | 3 | Attack | Starter | A pawn moves 2 squares forward. **Bonus** (that pawn then stays) |
| Freeze (Frost) | 4 | Control | Starter | Enemy piece (not king or queen) can't move next turn. **Bonus** |
| Return (Wiederkehr) | 6 | Comeback | Rare | A captured rook, bishop or knight returns |

### Ultimates

Ultimates charge with mana and replace your turn. They cost **8 mana** (Fortress: 6), and the rest of your mana stays.

| Ultimate | Cost | Unlocked | Effect |
|---|---|---|---|
| Meteor | 8 | Arena 1 | Destroy an enemy piece (not king or queen). Unprotected enemy pawns next to it can't move for 2 turns |
| Fortress (Festung) | 6 | Arena 1 | None of your pieces can be captured until the end of the opponent's next turn. Then one more piece move without capture or check |
| Ice Age (Eiszeit) | 8 | Arena 2 | All enemy pieces except the king can't move for the next 2 turns |
| Coronation (Krönung) | 8 | Arena 2 | An own pawn becomes a queen (if you still have a queen, the pawn must stand in the enemy half) |
| Rebirth (Wiedergeburt) | 8 | Arena 3 | Your most valuable captured piece (queen included) returns to your back rank |

### Protection rules and edge cases

- The **king** is immune to cards and ultimates. The **queen** is immune to Freeze and Meteor.
- Cards and ultimates never give check.
- **Thaw:** if a player who is not in check can't move *only* because of Freeze, their pieces thaw. Freeze never forces stalemate.
- **Territory:** each piece controls its square and the 8 neighbours. It is shown as a tint on the board and gives no mana.
- **Draws:** stalemate, threefold repetition, 50-move rule (card plays reset the counter like pawn moves), or an accepted offer.
- **Online disconnect:** 45 s without a heartbeat loses the game. If both players are gone, the game is aborted without rating.

---

## 2. Progression

| System | Summary |
|---|---|
| **Trophies** | Ranked online games. A win against an equal opponent gives +20 and a loss −20. Stronger opponents give more (up to ±40), weaker ones less (at least ±8). A draw gives up to ±12. Server function `trophy_delta`. |
| **Arenas** | 1 Training Grounds (0) · 2 Barracks Yard (90) · 3 Throne Arena (240) · 4 Storm Keep (600) · 5 Dragon's Lair (1200) · 6 King's Summit (2100). New arenas unlock ultimates, chests and board skins. |
| **Trophy road** | Rewards at trophy milestones: chests, shards, boards and arena chests. |
| **Bot ladder** | Offline AI opponents fought in order for XP and chests. The AI is an alpha-beta search with a transposition table that also considers card replies (`RookRaid/Engine/AI.swift`, `web/src/game/ai.ts`, which runs in a web worker). |
| **Chests** | Wood, Silver, Gold, Magic, Legendary. Earned from wins, daily goals, levels, the trophy road and the first friend (gold). Every tap can upgrade a chest. |
| **Shards and shop** | Chests give shards. In the shop, shards buy cards, avatars, boards and chests. Nothing costs real money. |
| **XP and levels** | From games and puzzles. Levels gate rarer cards (rare from level 5, epic from level 10). |
| **Puzzles** | A puzzle collection plus a daily puzzle with a bonus, and Puzzle Rush. |
| **Daily flame** | Streak: one puzzle or game per day. Flame looks change at 1, 7, 30, 100 and 365 days. Optional local reminders. |
| **Friends** | Friend codes and invite links (`https://rookraid.com/f/CODE`), requests, online status, friendly matches (unrated 5 \| 0), rematch, match history per friend, block/report, and push for requests and invites. |
| **Accounts** | Play as a guest (local only) → an anonymous online account (created when you first play online; it needs a unique name) → *secured* with Sign in with Apple or Google. Progress syncs between iPhone and web. |
| **First start** | A welcome flow (world → name and avatar, with a live name availability check → chess level), then Rocky's intro and a first battle. |

---

## 3. Repository layout

```
RookRaid/                    iPhone app (SwiftUI)
  Engine/                    Rules engine, AI, puzzles, rules JSON + golden test cases
  Services/                  Persistence, chests, shop, streak, friends, online (Supabase), sign-in, push
  UI/                        All screens (Home, Game, Deck, Profile, Rules, Welcome, Intro, Friends, ...)
  Localization/              en/es/fr/it/ru/zh.json – shared with the web (key = German text)
  Assets.xcassets, Sounds/   Art, avatars, card art, skins, sounds
RookRaid.xcodeproj           Xcode project (one target, iPhone only; Swift package: supabase-swift 2.x)
Config/                      Info.plist, entitlements, RookRaid.xcconfig (+ optional Secrets.xcconfig, git-ignored)
web/                         Browser version (React 19 + Vite + vite-plugin-pwa, TypeScript)
  src/game/                  Game controller, local store (localStorage), catalog, AI (+ web worker)
  src/screens/               Screens, 1:1 with the app's UI files
  src/ui/                    Shared components (Sheet, Dialog, Icon, ...)
  src/online.ts, friends.ts, friendMatch.ts, push.ts, supabase.ts   Online layer
  src/i18n.ts, copy.ts       Translations (shared JSON + web-only lines)
  public/                    Static files, .htaccess, apple-app-site-association, push service worker
  src/prerender.tsx, scripts/prerender.mjs   Build-time HTML for the public pages + sitemap (SEO)
  src/screens/HowToPlay.tsx  Public /how-to-play/ page (English)
  scripts/upload-zip.mjs     Builds web/upload/rookraid-web.zip for Hostinger
Backend/                     Supabase project
  supabase/migrations/       Full schema, RPCs, policies, cron jobs (apply in order)
  supabase/functions/        Edge Functions (Deno) + _shared/rookraid-rules.mjs (generated)
  supabase/seed/rules.sql    Active rules row (generated)
  tests/                     Database tests against a local Postgres
  README.md                  Backend setup (secrets, push, Google/Apple sign-in, bot players)
Tools/rules-js/              JavaScript port of the rules + generators and checks
Tools/ci/                    CI checks (secrets, i18n, generated files, web build, device layouts, OSV scan)
Legal/                       App Store privacy answers
RELEASE-CHECKLIST.md         What is left before release
```

---

## 4. Architecture

```
                   rookraid-rules.json  (rules version 3: all numbers)
                  /          |              \
     Swift engine      Tools/rules-js        build-server.js
  (RookRaid/Engine)    (engine.js+core.js)        |
         |                   |            _shared/rookraid-rules.mjs
     iPhone app          web (Vite alias     (Supabase Edge Functions)
                         'rookraid-rules')
          \                  |                  /
           \_____ golden-cases.json → rookraid-golden.json _____/
                 (all three engines must give the same results)
```

**One ruleset, three engines.** The Swift engine runs the app. The JavaScript port runs the browser *and* the server,
where `submit-action` replays each online move to reject illegal ones. Golden test cases keep all three identical, and
CI fails if they drift or if generated files are stale.

**Local first.** Both clients keep the full profile locally (iOS: `Persistence.swift`; web: `localStorage` in
`web/src/game/store.ts`). Offline play (bots, ladder, puzzles, hot seat, card lab) never needs the server. Once an
account exists, progress is backed up and merged through `sync_progress` / `backup_progress`, so the iPhone and the
browser share one profile.

**Online games.** Matchmaking (`find_match`) searches ±100 → ±400 trophies. After 10 s without a human, it picks an online
bot player within ±300, otherwise the training opponent. Both clients send actions in a compact wire format through the
`submit-action` Edge Function, which validates them with the shared rules and stores them in `match_actions`. The app
follows the game via Supabase Realtime and reloads all actions when a game starts or the app returns to the
foreground. The browser asks the server every 2 s instead. Clocks, heartbeats (`match_heartbeat`, every 10 s), draw offers,
resignation and timeouts are server-side. `maintain_matches` runs every 30 s via pg_cron and enforces the 45-second
disconnect rule. Results and trophies are written only by the server (`finish_match`, `apply_result`).

**State and navigation.**
- iOS: SwiftUI with `ObservableObject` singletons (`ProfileStore.shared`, `OnlineAccount.shared`, `FriendMatchCenter`, ...).
- Web: `useSyncExternalStore` stores (`S.useProfile()`, `Online.useAccount()`) and a small navigation store (`web/src/nav.ts`: tab, overlay, sheet).
- Web file names mirror the Swift files (for example `screens/Rules.tsx` ↔ `RulesView` in `UI/ProfileViews.swift`).

**Hosting (web).** Static build on Hostinger at `rookraid.com`. `.htaccess` handles the www redirect, invite links,
caching and compression.

**SEO (English for now).** `npm run build` has three steps: the client build, an SSR build of `src/prerender.tsx`, and
`scripts/prerender.mjs`. Together they write the public pages `/how-to-play/`, `/privacy/`, `/imprint/`, `/terms/` and
`/support/` as real HTML. Each page has its own title, description, canonical URL, Open Graph/Twitter tags and JSON-LD
(the homepage describes the game as a `VideoGame`; How to play adds an FAQ). The step also writes `sitemap.xml`;
`robots.txt` keeps invite links out of search. The How to play page takes card texts and numbers from the catalog and
the rules JSON, so it can't drift from the game. The share image is `public/og-image.jpg`. Setting `VITE_APP_STORE_ID`
adds the Smart App Banner on iPhone. `/.well-known/apple-app-site-association`
enables Universal Links for invite links. It's a PWA with an offline service worker; web push uses VAPID.

---

## 5. Supabase backend

Project ref `kjmlaxbpblndbybzvdbd` (Frankfurt). The schema lives entirely in `Backend/supabase/migrations/`. The
dashboard is only used for auth providers, secrets and checking cron jobs. Details and setup commands are in
[`Backend/README.md`](Backend/README.md).

### Auth
Anonymous sign-in (first online game), **Sign in with Apple** (native on iOS, Services ID on the web), and **Sign in with
Google** (OAuth through Supabase: `rookraid://auth-callback` on iOS, `https://rookraid.com/` on the web). With manual
linking turned on, "secure with Apple/Google" attaches the identity to the existing anonymous account.

### Tables (`public` unless noted)
| Table | Purpose |
|---|---|
| `profiles` | Display name (unique, 2–16 chars, case-insensitive), trophies, online record, friend code, avatar, show-online flag |
| `progress` | Synced profile snapshot (cards, chests, XP, history, ...) |
| `rules_config` | Active rules versions (seeded from the rules JSON) |
| `matches`, `match_actions`, `match_presence` | Online games, their actions, heartbeats |
| `matchmaking_queue` | Players searching |
| `match_invites` | Friendly match invites (valid 2 minutes) |
| `friendships`, `player_blocks`, `player_reports` | Social graph and moderation |
| `push_tokens`, `push_outbox` | APNs / Web Push targets and the queue for `push-dispatch` |
| `private.bot_players`, `private.rate_events` | 100 bot players (clearly labelled "Bot") with online hours and behaviour; rate limiting |

Row-level security is on everywhere. Clients mostly call **RPCs** instead of writing tables directly.

### Main RPCs
- **Account:** `setup_account`, `name_available`, `set_display_name`, `sync_progress`, `backup_progress`, `adopt_device_trophies`
- **Matches:** `find_match`, `cancel_matchmaking`, `create_match`, `start_bot_match`, `match_heartbeat`, `offer_draw`, `answer_draw`, `resign_match`, `claim_timeout`
- **Friends:** `my_friend_code`, `find_player`, `send_friend_request`, `respond_friend_request`, `cancel_friend_request`, `remove_friend`, `my_friends`, `friend_profile`, `friend_matches`, `friend_request_count`, `touch_online`, `set_show_online`, `block_player`, `unblock_player`, `blocked_players`, `report_player`
- **Friendly matches:** `invite_friend_match`, `friend_match_status`, `answer_friend_match`, `cancel_friend_match`
- **Push:** `register_push_token`, `unregister_push_token`
- **Server only:** `finish_match`, `apply_result`, `trophy_delta`, `maintain_matches`, `claim_push_outbox`

### Edge Functions (`Backend/supabase/functions/`)
| Function | Job |
|---|---|
| `submit-action` | Validates and records an online move with the shared rules |
| `finish-bot-match` | Scores a game against the training opponent |
| `delete-account` | Deletes the account and revokes Sign in with Apple (App Store guideline 5.1.1(v)) |
| `push-dispatch` | Sends queued pushes (APNs and Web Push). Deployed with `--no-verify-jwt`; it checks the token or `x-cron-secret` itself |

### Cron jobs (pg_cron)
| Job | Schedule | Job |
|---|---|---|
| `rookraid-maintain` | every 30 s | Timeouts, 45-second disconnect rule, stale queue entries |
| `rookraid-bot-players` | every minute | Bot players accept friend requests while online and trigger push |
| `rookraid-bot-drift` | hourly | Bot trophies drift in the background, pulled back to their starting value |
| `rookraid-cleanup-anonymous`, `rookraid-purge-anon` | hourly / 15 min | Remove abandoned anonymous users |
| `rookraid-cleanup-social` | hourly | Old requests, invites and reports |

### Secrets (set with `supabase secrets set`, never in git)
`APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (account deletion), `APNS_*` (iOS push), `VAPID_*` (web push),
`CRON_SECRET` (plus the Vault secrets `rookraid_project_url` and `rookraid_cron_secret`).

### Deploying
Always run the CLI with an absolute workdir:
```bash
supabase db push --workdir "$PWD/Backend" --remote=kjmlaxbpblndbybzvdbd
supabase functions deploy submit-action finish-bot-match delete-account --workdir "$PWD/Backend"
supabase functions deploy push-dispatch --no-verify-jwt --workdir "$PWD/Backend"
```

---

## 6. Building and running

### iPhone app
1. Open `RookRaid.xcodeproj` in Xcode 16 or newer.
2. Create `Config/Secrets.xcconfig` (git-ignored) with `RR_SUPABASE_URL` and `RR_SUPABASE_ANON_KEY`. Without it, the app runs fully offline.
3. Choose your team under *Signing & Capabilities*, pick an iPhone, and press ⌘R.

The version is set in the project (`MARKETING_VERSION` 1.0.0, `CURRENT_PROJECT_VERSION` 48). The stage label "Beta" is
`SettingsSheet.stage` in `UI/ProfileViews.swift`.

### Browser version
```bash
cd web
cp .env.example .env.local   # VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY, VITE_APPLE_CLIENT_ID, VITE_VAPID_PUBLIC_KEY
npm ci
npm run dev                  # local dev server
npm run build                # type-check + production build to web/dist
npm run upload-zip           # web/upload/rookraid-web.zip → extract into public_html on Hostinger
```
The version shown in Settings is in `web/src/version.ts`.

### Rules changes
```bash
# 1. edit RookRaid/Engine/rookraid-rules.json (and bump "version" for a breaking change)
node Tools/rules-js/make-golden.js       # regenerate expected results
node Tools/rules-js/check-golden.js      # JS engine vs. golden cases
node Tools/rules-js/build-server.js      # regenerate the Edge Function bundle
node Tools/rules-js/check-server.mjs
node Tools/rules-js/seed-rules.js        # regenerate Backend/supabase/seed/rules.sql
```
The app runs the same golden cases in debug builds (Settings → Developer → Rule tests).

---

## 7. Tests and CI

GitHub Actions (`.github/workflows/ci.yml`) runs on pull requests and pushes to `main`:

| Job | Checks |
|---|---|
| Secrets | `Tools/ci/check-secrets.sh` + Gitleaks |
| Game rules | Golden cases, server bundle, generated files up to date |
| Shared texts | All 7 languages complete, placeholders match, every shown text translated (`Tools/ci/check-i18n.mjs`) |
| iPhone layout | Window size decides the layout (`check-devices.sh`) |
| Browser version | `npm ci`, type-check, build, legal pages exist, no secrets in the bundle |
| Online database | Deno type-check and tests of the Edge Functions; every migration loaded into Postgres and checked (`Backend/tests`: privileges, scenario, flow, friends, bots) |
| Dependencies | `npm audit` and an OSV scan of npm and Swift packages |
| iOS build | Xcode build of the app |

Run the database tests locally against Postgres with `DB_URL=postgresql://…`, in order: `load-schema.js`,
`privileges.js`, `scenario.js`, `flow.mjs`, `friends.js`, `bots.js` (see `Backend/tests/README.md`).

---

## 8. Translations

- The **German text is the key**, for example `L("Weiter")` in Swift and `t('Weiter')` on the web. Translations live in `RookRaid/Localization/{en,es,fr,it,ru,zh}.json` and are shared by both clients.
- Placeholders are `{0}`, `{1}`, …
- Web-only lines (browser hints, legal page extras) live in `web/src/copy.ts`.
- `node Tools/ci/check-i18n.mjs` must pass before a commit.

---

## 9. Conventions

- **Parity:** implement every feature on iOS *and* web, with the same texts, numbers and flow.
- **Numbers live in data:** rules in `rookraid-rules.json`; cards, arenas, chests and the trophy road in the catalogs (`web/src/game/catalog.ts` ↔ Swift models). Server-side values are tested.
- **The server is the authority online:** clients never write trophies or results. All writes go through RPCs or Edge Functions.
- **No secrets in git:** `Config/Secrets.xcconfig` and `web/.env.local` are ignored; CI blocks leaks.
- **Comments and UI copy** are mostly in German. Code identifiers are in English.
