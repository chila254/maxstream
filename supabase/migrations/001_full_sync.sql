-- MaxStream FULL cloud sync (free Supabase)
-- Run this in Supabase Dashboard -> SQL Editor
-- Enables watch_history + watchlist + provider_preferences + media_downloads + settings

-- 1. watch_history (Continue Watching + progress)
create table if not exists public.watch_history (
  user_id text not null,
  tmdb_id text not null,
  is_movie boolean not null,
  season integer not null default 0,
  episode integer not null default 0,
  title text not null default '',
  series_title text,
  poster_url text,
  position_seconds double precision not null default 0,
  duration_seconds double precision not null default 0,
  updated_at timestamp with time zone not null default now(),
  primary key (user_id, tmdb_id, is_movie, season, episode)
);
alter table public.watch_history enable row level security;
create policy "Users manage own history" on public.watch_history for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);
-- For Firebase UID mode (no Supabase Auth), disable RLS or use service_role key:
-- alter table public.watch_history disable row level security;

-- 2. watchlist
create table if not exists public.watchlist (
  user_id text not null,
  id text not null,
  media_type text not null,
  title text,
  description text,
  thumbnail text,
  backdrop text,
  video_url text,
  trailer_url text,
  genres text,
  year text,
  rating double precision,
  country text,
  updated_at timestamp with time zone not null default now(),
  primary key (user_id, id, media_type)
);
alter table public.watchlist enable row level security;
create policy "Users manage own watchlist" on public.watchlist for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- 3. provider_preferences
create table if not exists public.provider_preferences (
  user_id text not null,
  provider_id integer not null,
  provider_name text,
  is_preferred boolean not null default false,
  added_date timestamp with time zone default now(),
  primary key (user_id, provider_id)
);
alter table public.provider_preferences enable row level security;
create policy "Users manage own prefs" on public.provider_preferences for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- 4. media_downloads (meta only, localPath is device-specific, not synced)
create table if not exists public.media_downloads (
  user_id text not null,
  download_key text not null,
  media_id text not null,
  media_type text not null,
  series_id text,
  season_number integer,
  episode_number integer,
  title text not null,
  thumbnail text,
  subtitles text not null default '[]',
  download_date timestamp with time zone default now(),
  primary key (user_id, download_key)
);
alter table public.media_downloads enable row level security;
create policy "Users manage own downloads" on public.media_downloads for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- 5. settings (theme, etc)
create table if not exists public.user_settings (
  user_id text primary key,
  theme text,
  onboarding_done boolean default false,
  updated_at timestamp with time zone default now()
);
alter table public.user_settings enable row level security;
create policy "Users manage own settings" on public.user_settings for all using (user_id = auth.uid()::text) with check (user_id = auth.uid()::text);

-- Enable Realtime for all tables (for TV instant sync)
-- Dashboard -> Database -> Realtime -> Enable for each table, or via SQL:
alter publication supabase_realtime add table public.watch_history;
alter publication supabase_realtime add table public.watchlist;
alter publication supabase_realtime add table public.provider_preferences;
alter publication supabase_realtime add table public.media_downloads;
alter publication supabase_realtime add table public.user_settings;
