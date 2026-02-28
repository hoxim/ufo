-- Domain schema + optimistic locking + revisions
-- Safe to run on an existing project (uses IF NOT EXISTS where possible).

create extension if not exists pgcrypto;

-- ============================================================================
-- Core domain tables
-- ============================================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique,
  category text not null default 'Personal',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null
);

create table if not exists public.space_members (
  user_id uuid not null references auth.users(id) on delete cascade,
  space_id uuid not null references public.spaces(id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, space_id)
);

create table if not exists public.space_invitations (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  inviter_id uuid not null references auth.users(id) on delete cascade,
  invitee_email text not null,
  invite_code text not null unique,
  status text not null default 'pending',
  sent_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.missions (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  title text not null,
  description text not null default '',
  difficulty int not null default 1,
  is_completed boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  last_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create table if not exists public.incidents (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  title text not null,
  description text not null default '',
  occurrence_date timestamptz not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  last_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

-- ============================================================================
-- Ensure columns exist on already-created tables
-- ============================================================================

alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists created_at timestamptz not null default now();
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

alter table public.spaces add column if not exists category text not null default 'Personal';
alter table public.spaces add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.spaces add column if not exists created_at timestamptz not null default now();
alter table public.spaces add column if not exists updated_at timestamptz not null default now();
alter table public.spaces add column if not exists version int not null default 1;
alter table public.spaces add column if not exists updated_by uuid references auth.users(id) on delete set null;

alter table public.space_members add column if not exists role text not null default 'member';
alter table public.space_members add column if not exists joined_at timestamptz not null default now();
alter table public.space_members add column if not exists created_at timestamptz not null default now();
alter table public.space_members add column if not exists updated_at timestamptz not null default now();

alter table public.space_invitations add column if not exists invite_code text;
alter table public.space_invitations add column if not exists status text not null default 'pending';
alter table public.space_invitations add column if not exists sent_at timestamptz not null default now();
alter table public.space_invitations add column if not exists expires_at timestamptz;
alter table public.space_invitations add column if not exists created_at timestamptz not null default now();
alter table public.space_invitations add column if not exists updated_at timestamptz not null default now();

alter table public.missions add column if not exists description text not null default '';
alter table public.missions add column if not exists difficulty int not null default 1;
alter table public.missions add column if not exists is_completed boolean not null default false;
alter table public.missions add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.missions add column if not exists created_at timestamptz not null default now();
alter table public.missions add column if not exists last_updated_at timestamptz not null default now();
alter table public.missions add column if not exists updated_at timestamptz not null default now();
alter table public.missions add column if not exists version int not null default 1;
alter table public.missions add column if not exists updated_by uuid references auth.users(id) on delete set null;
alter table public.missions add column if not exists deleted_at timestamptz;

alter table public.incidents add column if not exists description text not null default '';
alter table public.incidents add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.incidents add column if not exists created_at timestamptz not null default now();
alter table public.incidents add column if not exists last_updated_at timestamptz not null default now();
alter table public.incidents add column if not exists updated_at timestamptz not null default now();
alter table public.incidents add column if not exists version int not null default 1;
alter table public.incidents add column if not exists updated_by uuid references auth.users(id) on delete set null;
alter table public.incidents add column if not exists deleted_at timestamptz;

-- ============================================================================
-- Constraints
-- ============================================================================

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'missions_difficulty_check'
  ) then
    alter table public.missions
      add constraint missions_difficulty_check
      check (difficulty between 1 and 5);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'space_members_role_check'
  ) then
    alter table public.space_members
      add constraint space_members_role_check
      check (role in ('admin', 'member', 'parent', 'child'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'space_invitations_status_check'
  ) then
    alter table public.space_invitations
      add constraint space_invitations_status_check
      check (status in ('pending', 'accepted', 'rejected', 'expired', 'revoked'));
  end if;
end $$;

-- ============================================================================
-- Indexes
-- ============================================================================

create unique index if not exists spaces_invite_code_uq on public.spaces(invite_code);
create unique index if not exists space_invitations_invite_code_uq on public.space_invitations(invite_code);
create index if not exists space_members_space_id_idx on public.space_members(space_id);
create index if not exists space_members_user_id_idx on public.space_members(user_id);
create index if not exists missions_space_id_idx on public.missions(space_id);
create index if not exists missions_pending_idx on public.missions(space_id, deleted_at, last_updated_at desc);
create index if not exists incidents_space_id_idx on public.incidents(space_id);
create index if not exists incidents_pending_idx on public.incidents(space_id, deleted_at, last_updated_at desc);
create index if not exists space_invitations_email_status_idx on public.space_invitations(invitee_email, status);

-- ============================================================================
-- Revisions (audit history)
-- ============================================================================

create table if not exists public.mission_revisions (
  revision_id bigserial primary key,
  mission_id uuid not null references public.missions(id) on delete cascade,
  version int not null,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  snapshot jsonb not null,
  unique (mission_id, version)
);

create table if not exists public.incident_revisions (
  revision_id bigserial primary key,
  incident_id uuid not null references public.incidents(id) on delete cascade,
  version int not null,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  snapshot jsonb not null,
  unique (incident_id, version)
);

-- ============================================================================
-- Trigger helpers
-- ============================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.capture_mission_revision()
returns trigger
language plpgsql
as $$
begin
  insert into public.mission_revisions (mission_id, version, changed_by, snapshot)
  values (new.id, new.version, new.updated_by, to_jsonb(new))
  on conflict (mission_id, version) do nothing;
  return new;
end;
$$;

create or replace function public.capture_incident_revision()
returns trigger
language plpgsql
as $$
begin
  insert into public.incident_revisions (incident_id, version, changed_by, snapshot)
  values (new.id, new.version, new.updated_by, to_jsonb(new))
  on conflict (incident_id, version) do nothing;
  return new;
end;
$$;

-- Auto profile row after signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', null),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', null)
  )
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

-- ============================================================================
-- Triggers
-- ============================================================================

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_spaces_updated_at on public.spaces;
create trigger set_spaces_updated_at
before update on public.spaces
for each row execute function public.set_updated_at();

drop trigger if exists set_space_members_updated_at on public.space_members;
create trigger set_space_members_updated_at
before update on public.space_members
for each row execute function public.set_updated_at();

drop trigger if exists set_space_invitations_updated_at on public.space_invitations;
create trigger set_space_invitations_updated_at
before update on public.space_invitations
for each row execute function public.set_updated_at();

drop trigger if exists set_missions_updated_at on public.missions;
create trigger set_missions_updated_at
before update on public.missions
for each row execute function public.set_updated_at();

drop trigger if exists set_incidents_updated_at on public.incidents;
create trigger set_incidents_updated_at
before update on public.incidents
for each row execute function public.set_updated_at();

drop trigger if exists capture_mission_revision_trg on public.missions;
create trigger capture_mission_revision_trg
after insert or update on public.missions
for each row execute function public.capture_mission_revision();

drop trigger if exists capture_incident_revision_trg on public.incidents;
create trigger capture_incident_revision_trg
after insert or update on public.incidents
for each row execute function public.capture_incident_revision();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============================================================================
-- Optimistic-locking RPCs
-- ============================================================================

create or replace function public.update_mission_with_version(
  p_id uuid,
  p_expected_version int,
  p_title text default null,
  p_description text default null,
  p_difficulty int default null,
  p_is_completed boolean default null,
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
  update public.missions m
  set
    title = coalesce(p_title, m.title),
    description = coalesce(p_description, m.description),
    difficulty = coalesce(p_difficulty, m.difficulty),
    is_completed = coalesce(p_is_completed, m.is_completed),
    version = m.version + 1,
    last_updated_at = now(),
    updated_by = coalesce(p_actor, auth.uid())
  where m.id = p_id
    and m.version = p_expected_version
  returning m.version into v_current;

  if found then
    return query select true, v_current, null::int;
    return;
  end if;

  select version into v_current from public.missions where id = p_id;
  return query select false, null::int, v_current;
end;
$$;

create or replace function public.update_incident_with_version(
  p_id uuid,
  p_expected_version int,
  p_title text default null,
  p_description text default null,
  p_occurrence_date timestamptz default null,
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
  update public.incidents i
  set
    title = coalesce(p_title, i.title),
    description = coalesce(p_description, i.description),
    occurrence_date = coalesce(p_occurrence_date, i.occurrence_date),
    version = i.version + 1,
    last_updated_at = now(),
    updated_by = coalesce(p_actor, auth.uid())
  where i.id = p_id
    and i.version = p_expected_version
  returning i.version into v_current;

  if found then
    return query select true, v_current, null::int;
    return;
  end if;

  select version into v_current from public.incidents where id = p_id;
  return query select false, null::int, v_current;
end;
$$;

-- ============================================================================
-- Basic RLS
-- ============================================================================

alter table public.profiles enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.space_invitations enable row level security;
alter table public.missions enable row level security;
alter table public.incidents enable row level security;
alter table public.mission_revisions enable row level security;
alter table public.incident_revisions enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles for select
using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "members_select_own_spaces" on public.space_members;
create policy "members_select_own_spaces"
on public.space_members for select
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_members.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "spaces_select_member" on public.spaces;
create policy "spaces_select_member"
on public.spaces for select
using (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = spaces.id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "spaces_insert_authenticated" on public.spaces;
create policy "spaces_insert_authenticated"
on public.spaces for insert
with check (auth.uid() is not null);

drop policy if exists "spaces_update_admin" on public.spaces;
create policy "spaces_update_admin"
on public.spaces for update
using (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = spaces.id
      and sm.user_id = auth.uid()
      and sm.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = spaces.id
      and sm.user_id = auth.uid()
      and sm.role = 'admin'
  )
);

drop policy if exists "members_insert_authenticated" on public.space_members;
create policy "members_insert_authenticated"
on public.space_members for insert
with check (auth.uid() is not null);

drop policy if exists "members_update_admin_or_self" on public.space_members;
create policy "members_update_admin_or_self"
on public.space_members for update
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_members.space_id
      and sm.user_id = auth.uid()
      and sm.role = 'admin'
  )
)
with check (
  user_id = auth.uid()
  or exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_members.space_id
      and sm.user_id = auth.uid()
      and sm.role = 'admin'
  )
);

drop policy if exists "members_delete_admin_or_self" on public.space_members;
create policy "members_delete_admin_or_self"
on public.space_members for delete
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_members.space_id
      and sm.user_id = auth.uid()
      and sm.role = 'admin'
  )
);

drop policy if exists "missions_select_member" on public.missions;
create policy "missions_select_member"
on public.missions for select
using (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = missions.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "missions_insert_member" on public.missions;
create policy "missions_insert_member"
on public.missions for insert
with check (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = missions.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "missions_update_member" on public.missions;
create policy "missions_update_member"
on public.missions for update
using (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = missions.space_id
      and sm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = missions.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "incidents_select_member" on public.incidents;
create policy "incidents_select_member"
on public.incidents for select
using (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = incidents.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "incidents_insert_member" on public.incidents;
create policy "incidents_insert_member"
on public.incidents for insert
with check (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = incidents.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "incidents_update_member" on public.incidents;
create policy "incidents_update_member"
on public.incidents for update
using (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = incidents.space_id
      and sm.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = incidents.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "invitations_select_email_or_member" on public.space_invitations;
create policy "invitations_select_email_or_member"
on public.space_invitations for select
using (
  lower(invitee_email) = lower(coalesce((auth.jwt() ->> 'email')::text, ''))
  or exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_invitations.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "invitations_insert_member" on public.space_invitations;
create policy "invitations_insert_member"
on public.space_invitations for insert
with check (
  exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_invitations.space_id
      and sm.user_id = auth.uid()
  )
);

drop policy if exists "invitations_update_invitee_or_admin" on public.space_invitations;
create policy "invitations_update_invitee_or_admin"
on public.space_invitations for update
using (
  lower(invitee_email) = lower(coalesce((auth.jwt() ->> 'email')::text, ''))
  or exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_invitations.space_id
      and sm.user_id = auth.uid()
      and sm.role = 'admin'
  )
)
with check (
  lower(invitee_email) = lower(coalesce((auth.jwt() ->> 'email')::text, ''))
  or exists (
    select 1
    from public.space_members sm
    where sm.space_id = space_invitations.space_id
      and sm.user_id = auth.uid()
      and sm.role = 'admin'
  )
);

grant execute on function public.update_mission_with_version(uuid, int, text, text, int, boolean, uuid) to authenticated, service_role;
grant execute on function public.update_incident_with_version(uuid, int, text, text, timestamptz, uuid) to authenticated, service_role;
