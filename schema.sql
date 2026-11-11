-- TvClicker Supabase schema. Run in SQL Editor.
create table if not exists public.game_state (
  id integer primary key check (id = 1),
  announcement text not null default '',
  active_event jsonb,
  updated_at timestamptz not null default now()
);
insert into public.game_state (id, announcement, active_event)
values (1, '', null) on conflict (id) do nothing;
alter table public.game_state enable row level security;
grant select on public.game_state to anon, authenticated;
drop policy if exists "Anyone can read shared game state" on public.game_state;
create policy "Anyone can read shared game state" on public.game_state
for select to anon, authenticated using (true);

-- Public leaderboard rows. Each signed-in player can edit only their own row.
create table if not exists public.player_stats (
  player_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Player',
  played_seconds bigint not null default 0 check (played_seconds >= 0),
  total_tv numeric not null default 0 check (total_tv >= 0),
  tv_per_second numeric not null default 0 check (tv_per_second >= 0),
  tv_per_click numeric not null default 0 check (tv_per_click >= 0),
  updated_at timestamptz not null default now()
);
alter table public.player_stats enable row level security;
grant select on public.player_stats to anon, authenticated;
grant insert, update on public.player_stats to authenticated;
drop policy if exists "Leaderboard is public" on public.player_stats;
create policy "Leaderboard is public" on public.player_stats
for select to anon, authenticated using (true);
drop policy if exists "Players can insert their own stats" on public.player_stats;
create policy "Players can insert their own stats" on public.player_stats
for insert to authenticated with check (auth.uid() = player_id);
drop policy if exists "Players can update their own stats" on public.player_stats;
create policy "Players can update their own stats" on public.player_stats
for update to authenticated using (auth.uid() = player_id) with check (auth.uid() = player_id);

-- Limited one-time campaign: first ten distinct authenticated players only.
create table if not exists public.tv_code_campaigns (
  code text primary key,
  reward numeric not null,
  max_redemptions integer not null check (max_redemptions > 0),
  redeemed_count integer not null default 0 check (redeemed_count >= 0)
);
insert into public.tv_code_campaigns(code,reward,max_redemptions)
values ('TVONEMORENOLESS',10000000000000,10)
on conflict (code) do nothing;
create table if not exists public.tv_code_redemptions (
  code text not null references public.tv_code_campaigns(code),
  player_id uuid not null references auth.users(id) on delete cascade,
  redeemed_at timestamptz not null default now(),
  primary key (code, player_id)
);
alter table public.tv_code_campaigns enable row level security;
alter table public.tv_code_redemptions enable row level security;
revoke all on public.tv_code_campaigns from anon, authenticated;
revoke all on public.tv_code_redemptions from anon, authenticated;

create or replace function public.redeem_tv_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_reward numeric;
begin
  if v_user is null then
    return jsonb_build_object('success',false,'message','Sign in before redeeming this code.');
  end if;
  if upper(trim(p_code)) <> 'TVONEMORENOLESS' then
    return jsonb_build_object('success',false,'message','Invalid limited code.');
  end if;
  if exists(select 1 from public.tv_code_redemptions where code='TVONEMORENOLESS' and player_id=v_user) then
    return jsonb_build_object('success',false,'message','You have already redeemed this code.');
  end if;
  update public.tv_code_campaigns
    set redeemed_count = redeemed_count + 1
    where code='TVONEMORENOLESS' and redeemed_count < max_redemptions
    returning reward into v_reward;
  if v_reward is null then
    return jsonb_build_object('success',false,'message','All 10 rewards have already been claimed.');
  end if;
  insert into public.tv_code_redemptions(code,player_id)
    values ('TVONEMORENOLESS',v_user);
  return jsonb_build_object('success',true,'reward',v_reward,'message','Mega Pack redeemed!');
end;
$$;
revoke all on function public.redeem_tv_code(text) from public;
grant execute on function public.redeem_tv_code(text) to authenticated;

-- Realtime publication for shared global announcements/events.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'game_state'
  ) then
    alter publication supabase_realtime add table public.game_state;
  end if;
end $$;


-- Shared global chat. Anonymous Supabase-authenticated players can read and send messages.
create table if not exists public.chat_messages (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default 'Player',
  message text not null check (char_length(message) between 1 and 300),
  created_at timestamptz not null default now()
);
create index if not exists chat_messages_created_at_idx on public.chat_messages(created_at desc);
alter table public.chat_messages enable row level security;
grant select on public.chat_messages to anon, authenticated;
grant insert on public.chat_messages to authenticated;
drop policy if exists "Chat messages are readable" on public.chat_messages;
create policy "Chat messages are readable" on public.chat_messages
for select to anon, authenticated using (true);
drop policy if exists "Signed-in players can send chat messages" on public.chat_messages;
create policy "Signed-in players can send chat messages" on public.chat_messages
for insert to authenticated with check (
  auth.uid() = user_id and char_length(message) between 1 and 300
  and char_length(display_name) between 1 and 24
);

-- Enable live updates for chat and player ranking changes.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='chat_messages') then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='player_stats') then
    alter publication supabase_realtime add table public.player_stats;
  end if;
end $$;

-- Server-managed profiles and moderation. Public clients cannot change profiles,
-- chat rows, or leaderboard rows directly; writes go through player-api.
create table if not exists public.player_profiles (
  player_id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  is_banned boolean not null default false,
  ban_reason text,
  chat_timeout_until timestamptz,
  last_chat_at timestamptz,
  last_stats_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint player_profiles_username_length check (char_length(username) between 3 and 20),
  constraint player_profiles_username_chars check (username ~ '^[A-Za-z0-9_]+$')
);
create unique index if not exists player_profiles_username_lower_idx on public.player_profiles (lower(username));
alter table public.player_profiles enable row level security;
revoke all on public.player_profiles from anon, authenticated;

-- Remove direct client writes; the player-api Edge Function validates and writes these rows.
drop policy if exists "Players can insert their own stats" on public.player_stats;
drop policy if exists "Players can update their own stats" on public.player_stats;
revoke insert, update, delete on public.player_stats from anon, authenticated;
drop policy if exists "Signed-in players can send chat messages" on public.chat_messages;
revoke insert, update, delete on public.chat_messages from anon, authenticated;


-- Private server-side chat moderation dictionary and audit log.
create table if not exists public.chat_moderation_terms (
  id bigint generated by default as identity primary key,
  term text not null,
  severity text not null check (severity in ('profanity','slur')),
  enabled boolean not null default true
);
create table if not exists public.chat_moderation_log (
  id bigint generated by default as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  action text not null,
  created_at timestamptz not null default now()
);
alter table public.chat_moderation_terms enable row level security;
alter table public.chat_moderation_log enable row level security;
revoke all on public.chat_moderation_terms from anon, authenticated;
revoke all on public.chat_moderation_log from anon, authenticated;
