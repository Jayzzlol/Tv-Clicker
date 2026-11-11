# TvClicker — Supabase setup

## What this update adds
- Supabase server-side detection for the `ADMIN_CODE` Edge Function secret (the browser sees only whether it is configured).
- Global top-10 leaderboards: most played time, most total TV, most TV per second, and most TV per click.
- Shared live chat using Supabase Realtime; messages are limited to 300 characters and protected by row-level security.
- Large-value checks no longer stop at JavaScript’s safe-integer threshold; the game can continue past 9 quadrillion, though JavaScript Number precision becomes approximate at extremely high balances.
- Ten built-in promo codes.
- `TVONEMORENOLESS`: first 10 distinct signed-in players receive 10T TV and the Mega Pack (x2 permanent multiplier, +1,000 TV per click, +1,000 TV per second). Supabase atomically limits the reward to ten players and prevents the same player redeeming twice.

## 1. Supabase setup
1. Open https://supabase.com/dashboard and select your project.
2. Enable **Authentication → Sign In / Providers → Anonymous Sign-Ins**.
3. Open **SQL Editor** and run the complete `supabase/schema.sql` file. This creates the leaderboard, limited-code, live-chat tables/functions, and shared game state. It also enables Realtime for chat and leaderboard updates.

## 2. Website configuration
Edit `supabase-config.js` and set:
- `url`: your Supabase Project URL.
- `anonKey`: your Supabase publishable key (or legacy anon key).

These are public browser configuration values. Never use the service-role key in the website.

## 3. Admin secret and Edge Function
1. In Supabase, open **Edge Functions → Secrets**.
2. Add `ADMIN_CODE` with your private admin code.
3. Deploy the `admin` Edge Function from `supabase/functions/admin/index.ts` (Dashboard → Edge Functions → Deploy a new function / editor).
4. The Admin tab will call the server's `status` action and show whether the secret exists. It never receives the secret value.

GitHub Pages does not need GitHub secrets to host this static website. `SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` are only for the optional GitHub Actions function-deployment workflow; they are not required for GitHub Pages itself.

## 4. Publish with GitHub Pages
Upload the contents of this folder to your repository root, preserving `supabase/`. Commit to the branch configured in **Settings → Pages**.

## Leaderboard notes
Player identity is an anonymous Supabase user ID. Public leaderboard names are generated as `Player-xxxxxx`. Stats are submitted by the browser, so they are useful for community rankings but are not cheat-proof. They show top ten players.

## Promo codes
`TVONEMORENOLESS` is globally limited to the first ten distinct Supabase players. The other nine built-in codes are local promo codes and each can be redeemed once per browser save. To make those nine globally limited too, they would need their own server-side campaign entries.

## Usernames, server-side chat moderation, and anti-cheat checks
- Deploy `supabase/functions/player-api/index.ts` as the `player-api` Edge Function with JWT verification enabled.
- The migration creates private `player_profiles`, makes usernames unique, removes public-client write access to chat and leaderboard tables, and routes chat, username changes, and leaderboard writes through the server function.
- The function reads the private `chat_moderation_terms` table on the server. The existing database has ordinary profanity terms configured; add your approved severe-language terms with severity `slur` before chat moderation can be enabled. Keep the table private; the browser never receives the dictionary. If there are no enabled `slur` terms, chat fails closed until the owner configures them. Ordinary profanity triggers a 10-minute timeout.
- A configured severe-term match permanently bans that Supabase player ID from online features. The owner can add a term in SQL Editor using `insert into public.chat_moderation_terms(term,severity,enabled) values ('YOUR_TERM_HERE','slur',true);` (replace the placeholder with a term from your moderation policy). Because the game currently uses anonymous sign-in, clearing browser data can create a new anonymous identity; durable identity-based bans require a persistent sign-in method. A simple word list can also make mistakes, so the owner should review reports and be able to reverse an incorrect ban.
- The server validates stat shapes, prevents backwards leaderboard values and rejects implausibly large jumps. This is an additional barrier, not a fully authoritative game economy: a static browser game cannot guarantee that every local click, upgrade, or save is genuine. Full economy anti-cheat requires moving purchases, click credit, and balances into server-authoritative operations.
- Save JSON exports omit the code definitions and redeemed code names. Importing a code-free save conservatively locks the built-in local promo codes to avoid repeat redemptions; the globally limited campaign is also checked by Supabase.

## Usernames, server-side chat moderation, and anti-cheat checks
- Deploy `supabase/functions/player-api/index.ts` as the `player-api` Edge Function with JWT verification enabled.
- The schema creates private `player_profiles`, makes usernames unique, removes public-client write access to chat and leaderboard tables, and routes chat, username changes, and leaderboard writes through the server function.
- The function reads the private `chat_moderation_terms` table on the server. The existing database has ordinary profanity terms configured; add your approved severe-language terms with severity `slur` before chat moderation can be enabled. Keep the table private; the browser never receives the dictionary. If there are no enabled `slur` terms, chat fails closed until the owner configures them. Ordinary profanity triggers a 10-minute timeout.
- A configured severe-term match permanently bans that Supabase player ID from online features. The owner can add a term in SQL Editor using `insert into public.chat_moderation_terms(term,severity,enabled) values ('YOUR_TERM_HERE','slur',true);` (replace the placeholder with a term from your moderation policy). Because the game currently uses anonymous sign-in, clearing browser data can create a new anonymous identity; durable identity-based bans require a persistent sign-in method. A simple word list can also make mistakes, so the owner should review reports and be able to reverse an incorrect ban.
- The server validates stat shapes, prevents backwards leaderboard values and rejects implausibly large jumps. This is an additional barrier, not a fully authoritative game economy: a static browser game cannot guarantee that every local click, upgrade, or save is genuine. Full economy anti-cheat requires moving purchases, click credit, and balances into server-authoritative operations.
- Save JSON exports omit the code definitions and redeemed code names. Importing a code-free save conservatively locks the built-in local promo codes to avoid repeat claims; the globally limited campaign is also checked by Supabase.
