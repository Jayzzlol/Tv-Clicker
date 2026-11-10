TvClicker update notes
======================

Visual update
- Three-column desktop layout inspired by the supplied bakery/clicker screenshot.
- Large TV click target, live broadcast screen, activity feed, and upgrade shop.
- Animated event visuals in the broadcast screen.

Gameplay
- TV balance, total earned, click power, auto power, and multipliers now use JavaScript BigInt.
  This removes the old 9-quadrillion safe-integer ceiling for local game progress.
- Shop prices use integer arithmetic and increase with owned quantity.
- Rebirth is kept separate from the regular shop and remains more expensive than the next
  available shop upgrade. Its cost increases by 5x per rebirth and it also requires 5 more
  total owned upgrades per rebirth.
- Free prize wheel spins award in-game TV only; a spin recharges every five minutes.
- Random/global events are shown with visual broadcast effects and an activity feed.

Save data
- Autosaves in the browser.
- Save Data tab downloads a JSON backup, uploads/restores a backup, and resets local progress.
- Back up before resetting or replacing a save.

Security notes
- Save data is validated and arbitrary-precision values are stored as decimal strings.
- No website can reliably block every browser extension. This build does not scan installed
  extensions or fingerprint devices. Accessibility and privacy extensions should not be
  indiscriminately blocked.
- Client-side anti-cheat cannot make a public leaderboard cheat-proof. For strong enforcement,
  earnings, purchases, and leaderboard submissions need server-side validation.

Supabase
- Existing Supabase chat and leaderboard integration remains in place.
- Leaderboard numeric values are submitted as decimal strings so large totals can be stored
  in Postgres numeric columns. PostgreSQL numeric still has a finite maximum precision; local
  browser saves are not constrained by JavaScript's safe-integer limit.
- Keep Supabase service-role keys and admin secrets out of browser files.
