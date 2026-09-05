-- 45-day retention for watch_history (keeps 500MB free under 50k users)
-- Run once in Supabase Dashboard -> SQL Editor
-- Requires pg_cron (already enabled on Supabase) + pg_net if needed

-- Enable pg_cron if not already
create extension if not exists pg_cron;

-- Create function to delete old watch_history
create or replace function public.delete_old_watch_history()
returns void
language plpgsql
security definer
as $$
begin
  delete from public.watch_history where updated_at < now() - interval '45 days';
  -- Optional: keep watchlist forever, only history is pruned
end;
$$;

-- Schedule daily at 03:00 UTC (low traffic)
select cron.schedule(
  'delete-old-watch-history-45d',
  '0 3 * * *',
  $$ select public.delete_old_watch_history(); $$
);

-- One-time cleanup of already-old rows (run now)
select public.delete_old_watch_history();

-- Verify
-- select count(*) from public.watch_history where updated_at < now() - interval '45 days';
