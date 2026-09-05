-- Add missing columns to watch_history for full TV <-> phone sync
-- Run this in Supabase Dashboard -> SQL Editor

-- Add is_watched, episode_name, backdrop_path columns (safe to re-run)
ALTER TABLE public.watch_history ADD COLUMN IF NOT EXISTS is_watched boolean not null default false;
ALTER TABLE public.watch_history ADD COLUMN IF NOT EXISTS episode_name text;
ALTER TABLE public.watch_history ADD COLUMN IF NOT EXISTS backdrop_path text;
