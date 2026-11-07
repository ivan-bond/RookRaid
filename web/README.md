# Rook Raid – browser version

Same game as the iPhone app: same rules (`Tools/rules-js`), card art, arenas, avatars, bot piece sets, sounds and texts
(`RookRaid/Localization`). Progress is kept in the browser (local storage); online play uses the same Supabase project.

```
npm install
cp .env.example .env.local   # Supabase URL + anon key, optional Apple Services ID
npm run dev                  # http://localhost:5173
npm run build                # static site in dist/
```

Phones get the app layout (tab bar at the bottom). Windows wider than 900 px get a side rail and two-column screens;
the match puts the board on the left and the cards on the right.

## Sign in with Apple (browser)

The button uses Supabase's Apple sign-in (a redirect), so the player has the same Apple account as on the iPhone.
It needs Apple's web credentials in the Supabase project (the iPhone only needs the bundle ID):

1. Apple Developer → Identifiers → **Services IDs** → new ID (e.g. `com.ivan.rookraid.web`), enable *Sign in with Apple*,
   primary App ID `com.ivan.rookraid`, domain = the Supabase project host, return URL
   `https://<project>.supabase.co/auth/v1/callback`.
2. Apple Developer → Keys → new key with *Sign in with Apple* → download the `.p8` file, note the Key ID and your Team ID.
3. Supabase → Authentication → Sign In / Providers → **Apple**: Client IDs = the bundle ID **and** the Services ID
   (comma-separated), Secret Key = the JWT generated from the `.p8` (Supabase links the generator), save.
4. Supabase → Authentication → URL Configuration: add the site address (and `http://localhost:5173` for testing) to
   *Redirect URLs*.
5. For "secure an anonymous account with Apple": Authentication → Sign In / Providers → enable **Manual linking**.

Until step 3 is done, the button explains that Apple sign-in isn't set up yet (Supabase answers
`missing OAuth secret`).

## First visit, guests and cookies

No loading screen. Two first-party cookies: `rr_visited` (first visit → the first battle starts right away) and
`rr_auth` (guest, anonymous or Apple). Returning guests get a highlighted *Sign in with Apple* button on the Play tab
and in the side rail. The cookies are described in the privacy policy.

## Legal pages for App Store Connect

The build writes real files for these addresses, so any static host serves them without extra rules:

| App Store Connect field | Address |
|---|---|
| Privacy Policy URL | `https://<your-domain>/privacy` |
| Support URL | `https://<your-domain>/support` |
| (Legal notice / Impressum) | `https://<your-domain>/imprint` |
| (Terms of use) | `https://<your-domain>/terms` |

The pages carry the same wording as the app (`RookRaid/UI/LegalViews.swift`, as of 1 November 2026), switchable between
the seven app languages, plus a short section on the browser version and the web host.

## Same as the app

- **Bots:** `src/game/ai.ts` is a port of `AI.swift` (iterative deepening, alpha-beta, quiescence, killer/history ordering,
  transposition table, opponent card replies, v1/v2 evaluation) with the app's per-bot profiles. It runs in a Web Worker.
- **Replays:** Profile → recent games or Statistik → tap a game.
- **Rocky's deck workshop:** all ten steps of `DeckTour.swift`, including the swap trick and the ultimate gallery.
- **Tactics** are announced and count for achievements but give no mana, like the shared rules and the server.

Language files load on demand (one chunk per language), so the first load stays small.
