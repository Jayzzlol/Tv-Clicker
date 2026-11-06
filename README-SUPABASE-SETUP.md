# TvClicker — Supabase setup

This package uses Supabase anonymous sign-in when the game opens. Supabase shares global announcements and admin-started events.

## 1. Create a Supabase project
Create a project at https://supabase.com/dashboard. In **Authentication → Sign In / Providers**, enable **Anonymous Sign-Ins**.

## 2. Create the shared-state table
Open **SQL Editor → New query** in Supabase. Paste the full contents of `supabase/schema.sql` and click **Run**.

## 3. Configure the website
Open `supabase-config.js`. Replace `YOUR_SUPABASE_PROJECT_URL` and `YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY` with the Project URL and anon/publishable key from **Project Settings → API**. These values are designed for browser use. Never put the service-role key in this file.

## 4. Add these GitHub Actions secrets
In your GitHub repository, open **Settings → Secrets and variables → Actions → New repository secret**. Create all three:

| Secret name | What to enter |
|---|---|
| `ADMIN_CODE` | Your private admin code (example: `TVAdmin2026`) |
| `SUPABASE_ACCESS_TOKEN` | Your Supabase personal access token from your Supabase account settings |
| `SUPABASE_PROJECT_REF` | The project reference: the part before `.supabase.co` in your Supabase Project URL |

Keep these private. Do not paste them into chat or commit them to files. The workflow transfers `ADMIN_CODE` to the Supabase Edge Function as a server-side secret.

## 5. Upload and deploy
Upload the contents of this ZIP to the root of your GitHub repository, keeping the `.github` and `supabase` folders. Commit and push to the `main` branch. Then open **GitHub → Actions → Deploy Supabase admin function → Run workflow**. The workflow deploys the `admin` Edge Function and sets the `ADMIN_CODE` secret in Supabase. It also runs automatically when the Supabase function or workflow files change on `main`.

## 6. Unlock the owner tools
In TvClicker, open Admin and enter the same value you saved as GitHub's `ADMIN_CODE` secret. The Edge Function verifies this code on the server.

## Which Supabase secrets do I add manually?
Only one custom Edge Function secret is required: `ADMIN_CODE`. The included GitHub workflow sets it automatically from your GitHub repository secret. Supabase automatically provides its project URL, anon key, and service-role key to Edge Functions as platform environment variables. Do not expose the service-role key in the website.

## What is shared?
- Global announcements and admin-started events update for connected players.
- Anonymous sign-in starts automatically when the game loads.
- TV point balances, upgrades, rebirths, and achievements remain local to each player's browser.
- A shared leaderboard and live player directory are not included yet.
