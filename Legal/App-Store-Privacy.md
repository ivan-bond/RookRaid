# App Store privacy answers

Fill these in App Store Connect → App Privacy. The wording players read is in the app: Settings → Privacy, Legal notice, and Terms of use. Date of that text: 1 November 2026.

The privacy policy field in App Store Connect needs a public web address. The text is in the app. A private GitHub link is not enough for review.

## Tracking

Do you or your third-party partners use data for tracking? **No.**

There is no advertising, no advertising identifier, and no tracking across other companies’ apps or websites.

## Data collected and linked to the user

Purpose for every item below: **App Functionality** only.
Used for tracking: **No.**
Linked to the user’s identity: **Yes.**

| App Store type | What Rook Raid actually stores | When |
|---|---|---|
| Contact Info → Email Address | The address Apple sends when the player secures the account, including a Hide My Email relay address | Only after Sign in with Apple, and only if Apple provides one |
| Identifiers → User ID | The random account ID, and the guest ID the app creates once on the device | Online play |
| User Content → Gameplay Content | Player name, avatar, frame, title, piece set, trophies, online record, progress backup, decks, ultimates, moves, clock and result | Online play. The chosen player name is gameplay content, not the person’s legal name |
| Diagnostics → Other Diagnostic Data | Server error logs that can include the account ID and the time of the error | When a server function fails |

## Not collected

Do not declare these. The app does not collect them:

- Legal name, phone number, physical address of the player
- Precise location, coarse location
- Device ID used for advertising
- Payment info, purchases
- Contacts, photos, audio, browsing history, search history
- Health, fitness, sensitive information
- Crash reports or performance analytics from a separate analytics product
- Product interaction data used as analytics

Offline play stays on the device and is not sent to the server.

## Third parties

- **Supabase, Inc.** hosts the account, the database and sign-in in Frankfurt (EU). Logs, backups and function execution can also be processed outside that region under Supabase’s data processing agreement. Accept that agreement in the Supabase dashboard before release.
- **Apple** provides Sign in with Apple. Apple’s privacy policy applies to that sign-in.

## Account deletion

The app already deletes the online account from Settings → Account → Delete account. Say **Yes** to “account deletion” in App Store Connect once accounts are available.

For an account secured with Apple, the app first asks the player to confirm with Apple (Face ID). The server then revokes Sign in with Apple through Apple's REST API (`delete-account`, guideline 5.1.1(v)) and deletes the account. If Apple is unreachable, the account is still deleted.

Deleting the account removes the profile, the display name on the profile, trophies, the online record and the progress backup. Finished games stay so the opponent still has the result. Those games keep the moves and the player card, including the name shown in that game. The account is no longer linked to them. Progress stored on the iPhone stays until the player resets it in Settings.

## Age rating, from the same release notes

No chat. The only text a player publishes is a player name of 2–16 characters. No unrestricted web access, no real-money purchases, no loot boxes sold for money. Computer-controlled opponents are disclosed in the terms, not labelled inside a match.
