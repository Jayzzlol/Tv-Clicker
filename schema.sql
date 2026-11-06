-- Run this once in Supabase Dashboard -> SQL Editor.
create table if not exists public.game_state (
  id integer primary key check (id = 1),
  announcement text not null default '',
  active_event jsonb,
  updated_at timestamptz not null default now()
);

insert into public.game_state (id, announcement, active_event)
values (1, '', null)
on conflict (id) do nothing;

alter table public.game_state enable row level security;
grant select on public.game_state to anon, authenticated;

drop policy if exists "Anyone can read shared game state" on public.game_state;
create policy "Anyone can read shared game state"
on public.game_state for select
to anon, authenticated
using (true);

-- The Edge Function uses the service-role key for writes. No browser write policy is created.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'game_state'
  ) then
    alter publication supabase_realtime add table public.game_state;
  end if;
end $$;
