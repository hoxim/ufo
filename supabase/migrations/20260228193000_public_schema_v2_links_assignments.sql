-- v2: align migration with reduced public schema (adds links + assignments)
-- This migration is additive and safe on partially existing schemas.

create extension if not exists pgcrypto;

-- ============================================================================
-- Ensure LINKS and ASSIGNMENTS tables exist in public schema
-- ============================================================================

create table if not exists public.links (
  id uuid primary key default gen_random_uuid(),
  thing_id uuid,
  parent_id uuid,
  child_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  thing_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

-- If tables already existed without these columns, add them.
alter table public.links add column if not exists thing_id uuid;
alter table public.links add column if not exists parent_id uuid;
alter table public.links add column if not exists child_id uuid;
alter table public.links add column if not exists created_at timestamptz not null default now();
alter table public.links add column if not exists updated_at timestamptz not null default now();
alter table public.links add column if not exists version int not null default 1;
alter table public.links add column if not exists updated_by uuid references auth.users(id) on delete set null;
alter table public.links add column if not exists deleted_at timestamptz;

alter table public.assignments add column if not exists thing_id uuid;
alter table public.assignments add column if not exists user_id uuid;
alter table public.assignments add column if not exists role text not null default 'member';
alter table public.assignments add column if not exists created_at timestamptz not null default now();
alter table public.assignments add column if not exists updated_at timestamptz not null default now();
alter table public.assignments add column if not exists version int not null default 1;
alter table public.assignments add column if not exists updated_by uuid references auth.users(id) on delete set null;
alter table public.assignments add column if not exists deleted_at timestamptz;

-- ============================================================================
-- Indexes
-- ============================================================================

create index if not exists links_thing_id_idx on public.links(thing_id);
create index if not exists links_parent_id_idx on public.links(parent_id);
create index if not exists links_child_id_idx on public.links(child_id);
create index if not exists assignments_thing_id_idx on public.assignments(thing_id);
create index if not exists assignments_user_id_idx on public.assignments(user_id);

-- Prevent duplicate assignment of the same user to the same thing.
create unique index if not exists assignments_thing_user_uq
  on public.assignments(thing_id, user_id)
  where deleted_at is null;

-- ============================================================================
-- Revision tables for new entities
-- ============================================================================

create table if not exists public.link_revisions (
  revision_id bigserial primary key,
  link_id uuid not null references public.links(id) on delete cascade,
  version int not null,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  snapshot jsonb not null,
  unique (link_id, version)
);

create table if not exists public.assignment_revisions (
  revision_id bigserial primary key,
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  version int not null,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  snapshot jsonb not null,
  unique (assignment_id, version)
);

-- ============================================================================
-- Trigger helpers
-- ============================================================================

create or replace function public.set_updated_at_generic()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.capture_link_revision()
returns trigger
language plpgsql
as $$
begin
  insert into public.link_revisions (link_id, version, changed_by, snapshot)
  values (new.id, new.version, new.updated_by, to_jsonb(new))
  on conflict (link_id, version) do nothing;
  return new;
end;
$$;

create or replace function public.capture_assignment_revision()
returns trigger
language plpgsql
as $$
begin
  insert into public.assignment_revisions (assignment_id, version, changed_by, snapshot)
  values (new.id, new.version, new.updated_by, to_jsonb(new))
  on conflict (assignment_id, version) do nothing;
  return new;
end;
$$;

drop trigger if exists set_links_updated_at on public.links;
create trigger set_links_updated_at
before update on public.links
for each row execute function public.set_updated_at_generic();

drop trigger if exists set_assignments_updated_at on public.assignments;
create trigger set_assignments_updated_at
before update on public.assignments
for each row execute function public.set_updated_at_generic();

drop trigger if exists capture_link_revision_trg on public.links;
create trigger capture_link_revision_trg
after insert or update on public.links
for each row execute function public.capture_link_revision();

drop trigger if exists capture_assignment_revision_trg on public.assignments;
create trigger capture_assignment_revision_trg
after insert or update on public.assignments
for each row execute function public.capture_assignment_revision();

-- ============================================================================
-- Optimistic-locking RPCs for LINKS and ASSIGNMENTS
-- ============================================================================

create or replace function public.update_link_with_version(
  p_id uuid,
  p_expected_version int,
  p_thing_id uuid default null,
  p_parent_id uuid default null,
  p_child_id uuid default null,
  p_actor uuid default null
)
returns table (
  updated boolean,
  new_version int,
  conflict_version int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current int;
begin
  update public.links l
  set
    thing_id = coalesce(p_thing_id, l.thing_id),
    parent_id = coalesce(p_parent_id, l.parent_id),
    child_id = coalesce(p_child_id, l.child_id),
    version = l.version + 1,
    updated_at = now(),
    updated_by = coalesce(p_actor, auth.uid())
  where l.id = p_id
    and l.version = p_expected_version
  returning l.version into v_current;

  if found then
    return query select true, v_current, null::int;
    return;
  end if;

  select version into v_current from public.links where id = p_id;
  return query select false, null::int, v_current;
end;
$$;

create or replace function public.update_assignment_with_version(
  p_id uuid,
  p_expected_version int,
  p_role text default null,
  p_actor uuid default null
)
returns table (
  updated boolean,
  new_version int,
  conflict_version int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current int;
begin
  update public.assignments a
  set
    role = coalesce(p_role, a.role),
    version = a.version + 1,
    updated_at = now(),
    updated_by = coalesce(p_actor, auth.uid())
  where a.id = p_id
    and a.version = p_expected_version
  returning a.version into v_current;

  if found then
    return query select true, v_current, null::int;
    return;
  end if;

  select version into v_current from public.assignments where id = p_id;
  return query select false, null::int, v_current;
end;
$$;

grant execute on function public.update_link_with_version(uuid, int, uuid, uuid, uuid, uuid) to authenticated, service_role;
grant execute on function public.update_assignment_with_version(uuid, int, text, uuid) to authenticated, service_role;

-- ============================================================================
-- RLS for new tables
-- ============================================================================

alter table public.links enable row level security;
alter table public.assignments enable row level security;
alter table public.link_revisions enable row level security;
alter table public.assignment_revisions enable row level security;

drop policy if exists "links_select_authenticated" on public.links;
create policy "links_select_authenticated"
on public.links for select
using (auth.uid() is not null);

drop policy if exists "links_write_authenticated" on public.links;
create policy "links_write_authenticated"
on public.links for all
using (auth.uid() is not null)
with check (auth.uid() is not null);

drop policy if exists "assignments_select_own_or_authenticated" on public.assignments;
create policy "assignments_select_own_or_authenticated"
on public.assignments for select
using (user_id = auth.uid() or auth.uid() is not null);

drop policy if exists "assignments_insert_authenticated" on public.assignments;
create policy "assignments_insert_authenticated"
on public.assignments for insert
with check (auth.uid() is not null);

drop policy if exists "assignments_update_own_or_authenticated" on public.assignments;
create policy "assignments_update_own_or_authenticated"
on public.assignments for update
using (user_id = auth.uid() or auth.uid() is not null)
with check (user_id = auth.uid() or auth.uid() is not null);

drop policy if exists "assignments_delete_own_or_authenticated" on public.assignments;
create policy "assignments_delete_own_or_authenticated"
on public.assignments for delete
using (user_id = auth.uid() or auth.uid() is not null);

