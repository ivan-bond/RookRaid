# App Store privacy answers

Fill these in App Store Connect → App Privacy. The wording players read is in the app: Settings → Privacy, Legal notice, and Terms of use. Date of that text: 9 November 2026.

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
| Contact Info → Email Address | The address Apple or Google sends when the player secures the account, including an Apple Hide My Email relay address | Only after Sign in with Apple or Google, and only if the provider sends one |
| Contact Info → Name | The name Google sends with the sign-in (and the address of the Google profile picture). Stored with the sign-in, never shown in the game | Only after Sign in with Google |
| Identifiers → User ID | The random account ID, and the guest ID the app creates once on the device | Online play |
| User Content → Gameplay Content | Player name, avatar, frame, title, piece set, trophies, online record, progress backup, decks, ultimates, moves, clock and result | Online play. The chosen player name is gameplay content, not the person’s legal name |
| Identifiers → Device ID | The push address of the device or browser (APNs token or Web Push subscription), with the game language | Only after the player allows notifications for friend requests. Removed on sign-out |
| User Content → Gameplay Content (friends) | Friend code, friendships and friend requests, blocked players, invitations to friendly matches | Online play with the friends feature |
| Usage Data → Product Interaction | Time of the last visit (overwritten every visit) and whether friends may see the online status | Only so friends see who is online. Not analytics; players can hide it in the friends list |
| User Content → Other User Content | Reports a player sends about another player (reason only, no free text) | Only when a player reports someone. Deleted after one year at the latest |
| Diagnostics → Other Diagnostic Data | Server error logs that can include the account ID and the time of the error | When a server function fails |

## Not collected

Do not declare these. The app does not collect them:

- Phone number and physical address of the player. The legal name is only stored when Google sends it with Sign in with Google (declared above)
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
- **Google** provides Sign in with Google (iPhone and browser). Google’s privacy policy applies to that sign-in. Apple's guideline 4.8 is met because Sign in with Apple is offered next to it.
- **Apple Push Notification service** delivers friend notifications on iPhone; in browsers, the browser maker's push service (for example Apple, Google or Mozilla) does. They receive the push address and the notification text with the other player's name.
- **Hostinger International Ltd.** (Larnaca, Cyprus) hosts the website rookraid.com, including the privacy page and invite links. Check the address against Hostinger's data processing agreement, and choose an EU data centre if the plan offers one.

## Account deletion

The app already deletes the online account from Settings → Account → Delete account. Say **Yes** to “account deletion” in App Store Connect once accounts are available.

For an account secured with Google, the server deletes the account; Google needs no revocation. For an account secured with Apple, the app first asks the player to confirm with Apple (Face ID). The server then revokes Sign in with Apple through Apple's REST API (`delete-account`, guideline 5.1.1(v)) and deletes the account. If Apple is unreachable, the account is still deleted.

Deleting the account removes the profile, friendships, requests, blocks, invitations, the last-visit time, push addresses, the display name on the profile, trophies, the online record and the progress backup. Finished games stay so the opponent still has the result. Those games keep the moves and the player card, including the name shown in that game. The account is no longer linked to them. Progress stored on the iPhone stays until the player resets it in Settings.

## Age rating, from the same release notes

No chat. The only text a player publishes is a player name of 2–16 characters. Players can find each other by exact name or friend code and become friends; they can block and report each other. No unrestricted web access, no real-money purchases, no loot boxes sold for money. Computer-controlled opponents are always labelled: the stand-in as a training opponent, and the 100 bot players (profiles, friend requests, friendly matches) with a “Bot” tag in matchmaking, inside the match, in search, the friends list and the profile.
