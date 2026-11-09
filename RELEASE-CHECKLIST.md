# Rook Raid – release checklist (iOS and web)

Status as of 2026-11-09. Based on the code and project files; the Supabase dashboard and App Store Connect could not be checked from here.

## Must happen before publishing

### 1. Commit and test the latest changes
- [ ] Commit everything (68 files were uncommitted, including server sync, history sync, the phantom-game fix, the chest window and the profile).
- [ ] Test on a real iPhone and in the browser:
  - [ ] Sign in on the web, play a game, then open the iPhone app: trophies, cards, chests and history are the same.
  - [ ] Sign out and back in: nothing is lost.
  - [ ] Start a "Kampf!" game, then check in Supabase that exactly one match was created.

### 2. Put the web app online
- [ ] Pick a host (Cloudflare Pages, Netlify or Vercel) and a domain, then upload `web/dist`. The build already writes `/privacy`, `/imprint`, `/terms` and `/support` as separate pages.
- [ ] Set at the host: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_APPLE_CLIENT_ID`, `VITE_VAPID_PUBLIC_KEY`.
- [ ] Host: Hostinger, domain rookraid.com. Upload `web/dist` into `public_html` (it includes the hidden `.htaccess`, which does
  what `_redirects` and `_headers` do on Cloudflare/Netlify), and turn on Force HTTPS in hPanel. Check that `/f/ABCDEF` serves the
  app and that `/.well-known/apple-app-site-association` is served as `application/json`.
- [x] `RR_WEB_DOMAIN = rookraid.com` in `Config/RookRaid.xcconfig`. Invite links and the app's Universal Links use it.
- [ ] Friends: the first friend gives a gold chest (once); the lightning button in the friend ranking challenges a friend;
  the friend profile lists the last games; after a friendly match the result screen offers "Revanche".
- [ ] Test invite links on an iPhone with the app installed (fresh install, because iOS fetches the link file at install):
  tap a `https://rookraid.com/f/CODE` link in Messages or Notes → the app opens. WhatsApp also opens the app directly.
  Telegram, Messenger and Instagram use their own browser, so the page shows "Rook Raid installiert? Öffnen" there
  (`rookraid://f/CODE`). If Safari still opens, long-press the link → "In Rook Raid öffnen" (iOS remembers that choice).
- [ ] First start (fresh install / private browser window): welcome (world → name + avatar → chess level) → Rocky greets by
  name → five intro screens → battle against Mila. "Tutorial wiederholen" skips the welcome.
- [ ] Do this before the App Store submission: App Store Connect needs a live privacy policy URL and support URL.
- [x] The web privacy policy names Hostinger as the host.

### 3. Supabase settings
- [ ] Authentication → URL configuration: set the site URL to the real web domain and add it to the redirect URLs.
- [ ] Authentication → Apple: the client IDs contain both the bundle ID `com.ivan.rookraid` and the web Services ID.
- [x] Edge function secrets: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` (set 2026-11-09, key 8MCBW4F2BH, file in `~/RookRaid-Secrets/`). Without them, deleting an account doesn't revoke Sign in with Apple, which Apple requires.
- [x] Deploy the new `push-dispatch`.
- [x] Deploy `delete-account` again (version 8, 2026-11-09, with the Apple secrets).
- [ ] Test it: delete a test account secured with Apple → Rook Raid disappears from Settings → Apple ID → Sign in with Apple.
- [ ] Apply the migration `20261107120000_friends.sql` (`supabase db push`). Check that the cron job `rookraid-cleanup-social` exists.
- [x] Push secrets: `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`, `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (commands in `Backend/README.md`).
- [x] Apply `20261109120000_bot_players.sql` (bot players, online status, friendly matches). The cron jobs `rookraid-bot-players` and `rookraid-bot-drift` run.
- [x] Redeploy `push-dispatch` with `--no-verify-jwt`, set `CRON_SECRET`, and add the Vault secrets `rookraid_project_url` and `rookraid_cron_secret`.
- [x] Apply `20261110120000_friend_history.sql` (games against a friend in the friend profile): `supabase db push`.
- [ ] Sign in with Google (iPhone and web), see `Backend/README.md` → "Sign in with Google":
  - Google Cloud Console: OAuth consent screen (app name Rook Raid, support email, privacy URL `https://rookraid.com/privacy`),
    then an OAuth client of type **Web application** with the redirect URI `https://kjmlaxbpblndbybzvdbd.supabase.co/auth/v1/callback`.
  - Supabase → Authentication → Sign In / Providers → Google: turn it on, paste client ID and secret.
  - Supabase → Authentication → URL configuration → Redirect URLs: add `rookraid://auth-callback` (iPhone) and `https://rookraid.com/` (web).
  - Supabase → Authentication → Sign In / Providers: turn on **Allow manual linking**. "Mit Google sichern" and "Mit Apple sichern"
    on the iPhone link the sign-in to the existing anonymous account; without this setting linking fails.
  - Test: anonymous player → "Mit Google sichern" → the profile shows "Mit Google gesichert"; sign out, "Mit Google anmelden" → same account.
- [ ] Database → Cron jobs: check that `rookraid-maintain` is running. The 45-second rule and timeouts depend on it.

### 4. Apple Developer portal
- [ ] Services ID for web sign-in: verify the real domain and add its return URL (`https://your-domain/`).
- [ ] App ID `com.ivan.rookraid`: turn on the Push Notifications and Associated Domains capabilities, and create an APNs key.
- [ ] Before the store build, set `aps-environment` in `Config/RookRaid.entitlements` to `production` (or let Xcode's distribution signing do it).

### 5. iPhone build
- [ ] Move Xcode back from `/Users/Shared/Previously Relocated Items 10/…` to `/Applications`, then run `sudo xcode-select -s /Applications/Xcode.app`.
- [ ] Version: still 0.9.36 (build 47). Change it to 1.0.0 for the store.
- [ ] Product → Archive → upload to App Store Connect.

### 6. App Store Connect listing
- [ ] Screenshots: at least the 6.9″ iPhone size (the app is iPhone-only, so no iPad).
- [ ] Description, keywords, subtitle and category (Games → Board) in each language you list.
- [ ] Privacy policy URL and support URL from step 2.
- [ ] Privacy labels: fill them in from `Legal/App-Store-Privacy.md`.
- [x] Privacy policy (web and iOS) and `Legal/App-Store-Privacy.md` cover friends, online status, bot players and Sign in with Google.
- [ ] Privacy labels: Sign in with Google adds Contact Info → Name (see `Legal/App-Store-Privacy.md`).
- [ ] Age rating questionnaire. It should come out at 4+: no purchases for real money, no chat.
- [ ] Review notes:
  - You can play without an account.
  - Online play creates an anonymous account automatically.
  - Sign in with Apple or Google is optional.
  - Some opponents and friends are clearly marked bot players ("Bot"); they stand in when no human is searching.
  - Account deletion is under Settings → Account.

## Already in place
- Sign in with Apple and Google: the Apple entitlement is set, Google runs through Supabase (no extra SDK), and the app can delete accounts itself.
- The privacy manifest (`PrivacyInfo.xcprivacy`) is bundled into the app. The export compliance key is set (no special encryption).
- Six languages plus German, the app icon in light, dark and tinted variants, and a launch screen.
- No debug features in the store build: the developer screen and the "all cards unlocked" test mode only exist in debug builds. The web app has no test mode.
- Legal pages on both platforms:
  - imprint with name and address;
  - privacy policy, which names Supabase in Frankfurt as the data processor;
  - terms of use.
- Keys are kept out of git (`Secrets.xcconfig` and `.env.local` are ignored).
- Trophies are calculated only on the server, and stand-in games are checked by replaying their moves.

## Worth doing, but not blocking
- [ ] The 45-second rule triggers easily, for example when the app goes to the background. Consider making it gentler for stand-in games, such as no rating if the game had fewer than 3 moves.
- [ ] There's no crash reporting yet. A short TestFlight round with a few people before release shows any crashes.

## Your additions
- [ ] 
