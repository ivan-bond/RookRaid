-- pg_cron exists only on the Supabase database. Tests stand in a scheduler that records nothing,
-- so the maintenance migrations can be applied and their functions still created.
create schema if not exists cron;
create table if not exists cron.job (
  jobid bigint generated always as identity primary key,
  jobname text
);
create or replace function cron.schedule(job_name text, schedule text, command text)
returns bigint language sql as $$ select 1::bigint $$;
create or replace function cron.unschedule(jobid bigint)
returns boolean language sql as $$ select true $$;
