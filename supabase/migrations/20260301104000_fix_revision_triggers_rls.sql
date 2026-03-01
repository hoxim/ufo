-- Fix RLS errors when triggers write to *_revisions tables.
-- Error example: "new row violates row-level security policy for table mission_revisions"
--
-- We keep RLS enabled on revision tables, but trigger functions run as SECURITY DEFINER,
-- so inserts from triggers are allowed.

alter function public.capture_mission_revision() security definer;
alter function public.capture_mission_revision() set search_path = public;

alter function public.capture_incident_revision() security definer;
alter function public.capture_incident_revision() set search_path = public;

-- Optional: if link/assignment revision triggers exist, harden them too.
do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'capture_link_revision'
  ) then
    execute 'alter function public.capture_link_revision() security definer';
    execute 'alter function public.capture_link_revision() set search_path = public';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'capture_assignment_revision'
  ) then
    execute 'alter function public.capture_assignment_revision() security definer';
    execute 'alter function public.capture_assignment_revision() set search_path = public';
  end if;
end $$;

