# Rook Raid – release checklist (iOS and web)

Status as of 2026-11-06. Based on the code and project files; the Supabase dashboard and App Store Connect could not be checked from here.

## Must happen before publishing

### 1. Commit and test the latest changes
- [ ] Commit everything (68 files were uncommitted, including server sync, history sync, the phantom-game fix, the chest window and the profile).
- [ ] Test on a real iPhone and in the browser:
  - [ ] Sign in on the web, play a game, then open the iPhone app: trophies, cards, chests and history are the same.
  - [ ] Sign out and back in: nothing is lost.
  - [ ] Start a "Kampf!" game, then check in Supabase that exactly one match was created.

### 2. Put the web app online
- [ ] Pick a host (Cloudflare Pages, Netlify or Vercel) and a domain, then upload `web/dist`. The build already writes `/privacy`, `/imprint`, `/terms` and `/support` as separate pages.
- [ ] Set at the host: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_APPLE_CLIENT_ID`.
- [ ] Do this before the App Store submission: App Store Connect needs a live privacy policy URL and support URL.
- [ ] Name the host in the privacy policy on web and iOS. It currently says only "der Webhoster"; under GDPR it should name the provider.

### 3. Supabase settings
- [ ] Authentication → URL configuration: set the site URL to the real web domain and add it to the redirect URLs.
- [ ] Authentication → Apple: the client IDs contain both the bundle ID `com.ivan.rookraid` and the web Services ID.
- [ ] Edge function secrets: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`. Without them, deleting an account doesn't revoke Sign in with Apple, which Apple requires.
- [ ] Deploy `delete-account` again (it was changed).
- [ ] Database → Cron jobs: check that `rookraid-maintain` is running. The 45-second rule and timeouts depend on it.

### 4. Apple Developer portal
- [ ] Services ID for web sign-in: verify the real domain and add its return URL (`https://your-domain/`).

### 5. iPhone build
- [ ] Move Xcode back from `/Users/Shared/Previously Relocated Items 10/…` to `/Applications`, then run `sudo xcode-select -s /Applications/Xcode.app`.
- [ ] Version: still 0.9.36 (build 47). Change it to 1.0.0 for the store.
- [ ] Product → Archive → upload to App Store Connect.

### 6. App Store Connect listing
- [ ] Screenshots: at least the 6.9″ iPhone size (the app is iPhone-only, so no iPad).
- [ ] Description, keywords, subtitle and category (Games → Board) in each language you list.
- [ ] Privacy policy URL and support URL from step 2.
- [ ] Privacy labels: fill them in from `Legal/App-Store-Privacy.md`.
- [ ] Age rating questionnaire. It should come out at 4+: no purchases for real money, no chat.
- [ ] Review notes:
  - You can play without an account.
  - Online play creates an anonymous account automatically.
  - Sign in with Apple is optional.
  - Account deletion is under Settings → Account.

## Already in place
- Sign in with Apple: the entitlement is set, and the app can delete accounts itself.
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
