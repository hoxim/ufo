-- New collaboration modules:
-- budgets, shared lists, location pings, simple messenger

create table if not exists public.budget_entries (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  title text not null,
  kind text not null check (kind in ('income', 'expense')),
  amount numeric(12,2) not null check (amount >= 0),
  category text not null default 'General',
  notes text,
  entry_date timestamptz not null default now(),
  is_recurring boolean not null default false,
  recurring_interval text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create table if not exists public.budget_goals (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  title text not null,
  target_amount numeric(12,2) not null check (target_amount >= 0),
  current_amount numeric(12,2) not null default 0 check (current_amount >= 0),
  due_date timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create table if not exists public.shared_lists (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  name text not null,
  type text not null default 'shopping' check (type in ('shopping', 'goals')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create table if not exists public.shared_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.shared_lists(id) on delete cascade,
  title text not null,
  is_completed boolean not null default false,
  position int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create table if not exists public.location_pings (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  user_display_name text not null,
  latitude double precision not null,
  longitude double precision not null,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create table if not exists public.space_messages (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null,
  body text not null,
  sent_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version int not null default 1,
  updated_by uuid references auth.users(id) on delete set null,
  deleted_at timestamptz
);

create index if not exists budget_entries_space_id_idx on public.budget_entries(space_id, entry_date desc);
create index if not exists budget_goals_space_id_idx on public.budget_goals(space_id, updated_at desc);
create index if not exists shared_lists_space_id_idx on public.shared_lists(space_id, updated_at desc);
create index if not exists shared_list_items_list_id_idx on public.shared_list_items(list_id, position asc);
create index if not exists location_pings_space_id_idx on public.location_pings(space_id, recorded_at desc);
create index if not exists location_pings_user_id_idx on public.location_pings(user_id, recorded_at desc);
create index if not exists space_messages_space_id_idx on public.space_messages(space_id, sent_at desc);

-- Generic updated_at trigger reuse

drop trigger if exists set_budget_entries_updated_at on public.budget_entries;
create trigger set_budget_entries_updated_at
before update on public.budget_entries
for each row execute function public.set_updated_at();

drop trigger if exists set_budget_goals_updated_at on public.budget_goals;
create trigger set_budget_goals_updated_at
before update on public.budget_goals
for each row execute function public.set_updated_at();

drop trigger if exists set_shared_lists_updated_at on public.shared_lists;
create trigger set_shared_lists_updated_at
before update on public.shared_lists
for each row execute function public.set_updated_at();

drop trigger if exists set_shared_list_items_updated_at on public.shared_list_items;
create trigger set_shared_list_items_updated_at
before update on public.shared_list_items
for each row execute function public.set_updated_at();

drop trigger if exists set_location_pings_updated_at on public.location_pings;
create trigger set_location_pings_updated_at
before update on public.location_pings
for each row execute function public.set_updated_at();

drop trigger if exists set_space_messages_updated_at on public.space_messages;
create trigger set_space_messages_updated_at
before update on public.space_messages
for each row execute function public.set_updated_at();

alter table public.budget_entries enable row level security;
alter table public.budget_goals enable row level security;
alter table public.shared_lists enable row level security;
alter table public.shared_list_items enable row level security;
alter table public.location_pings enable row level security;
alter table public.space_messages enable row level security;

-- budget_entries

drop policy if exists "budget_entries_member_select" on public.budget_entries;
create policy "budget_entries_member_select"
on public.budget_entries for select
using (public.is_space_member(space_id, auth.uid()));

drop policy if exists "budget_entries_member_insert" on public.budget_entries;
create policy "budget_entries_member_insert"
on public.budget_entries for insert
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "budget_entries_member_update" on public.budget_entries;
create policy "budget_entries_member_update"
on public.budget_entries for update
using (public.is_space_member(space_id, auth.uid()))
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "budget_entries_member_delete" on public.budget_entries;
create policy "budget_entries_member_delete"
on public.budget_entries for delete
using (public.is_space_member(space_id, auth.uid()));

-- budget_goals

drop policy if exists "budget_goals_member_select" on public.budget_goals;
create policy "budget_goals_member_select"
on public.budget_goals for select
using (public.is_space_member(space_id, auth.uid()));

drop policy if exists "budget_goals_member_insert" on public.budget_goals;
create policy "budget_goals_member_insert"
on public.budget_goals for insert
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "budget_goals_member_update" on public.budget_goals;
create policy "budget_goals_member_update"
on public.budget_goals for update
using (public.is_space_member(space_id, auth.uid()))
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "budget_goals_member_delete" on public.budget_goals;
create policy "budget_goals_member_delete"
on public.budget_goals for delete
using (public.is_space_member(space_id, auth.uid()));

-- shared_lists

drop policy if exists "shared_lists_member_select" on public.shared_lists;
create policy "shared_lists_member_select"
on public.shared_lists for select
using (public.is_space_member(space_id, auth.uid()));

drop policy if exists "shared_lists_member_insert" on public.shared_lists;
create policy "shared_lists_member_insert"
on public.shared_lists for insert
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "shared_lists_member_update" on public.shared_lists;
create policy "shared_lists_member_update"
on public.shared_lists for update
using (public.is_space_member(space_id, auth.uid()))
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "shared_lists_member_delete" on public.shared_lists;
create policy "shared_lists_member_delete"
on public.shared_lists for delete
using (public.is_space_member(space_id, auth.uid()));

-- shared_list_items

drop policy if exists "shared_list_items_member_select" on public.shared_list_items;
create policy "shared_list_items_member_select"
on public.shared_list_items for select
using (
  exists (
    select 1
    from public.shared_lists l
    where l.id = shared_list_items.list_id
      and public.is_space_member(l.space_id, auth.uid())
  )
);

drop policy if exists "shared_list_items_member_insert" on public.shared_list_items;
create policy "shared_list_items_member_insert"
on public.shared_list_items for insert
with check (
  exists (
    select 1
    from public.shared_lists l
    where l.id = shared_list_items.list_id
      and public.is_space_member(l.space_id, auth.uid())
  )
);

drop policy if exists "shared_list_items_member_update" on public.shared_list_items;
create policy "shared_list_items_member_update"
on public.shared_list_items for update
using (
  exists (
    select 1
    from public.shared_lists l
    where l.id = shared_list_items.list_id
      and public.is_space_member(l.space_id, auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.shared_lists l
    where l.id = shared_list_items.list_id
      and public.is_space_member(l.space_id, auth.uid())
  )
);

drop policy if exists "shared_list_items_member_delete" on public.shared_list_items;
create policy "shared_list_items_member_delete"
on public.shared_list_items for delete
using (
  exists (
    select 1
    from public.shared_lists l
    where l.id = shared_list_items.list_id
      and public.is_space_member(l.space_id, auth.uid())
  )
);

-- location_pings

drop policy if exists "location_pings_member_select" on public.location_pings;
create policy "location_pings_member_select"
on public.location_pings for select
using (public.is_space_member(space_id, auth.uid()));

drop policy if exists "location_pings_member_insert" on public.location_pings;
create policy "location_pings_member_insert"
on public.location_pings for insert
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "location_pings_member_update" on public.location_pings;
create policy "location_pings_member_update"
on public.location_pings for update
using (public.is_space_member(space_id, auth.uid()))
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "location_pings_member_delete" on public.location_pings;
create policy "location_pings_member_delete"
on public.location_pings for delete
using (public.is_space_member(space_id, auth.uid()));

-- space_messages

drop policy if exists "space_messages_member_select" on public.space_messages;
create policy "space_messages_member_select"
on public.space_messages for select
using (public.is_space_member(space_id, auth.uid()));

drop policy if exists "space_messages_member_insert" on public.space_messages;
create policy "space_messages_member_insert"
on public.space_messages for insert
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "space_messages_member_update" on public.space_messages;
create policy "space_messages_member_update"
on public.space_messages for update
using (public.is_space_member(space_id, auth.uid()))
with check (public.is_space_member(space_id, auth.uid()));

drop policy if exists "space_messages_member_delete" on public.space_messages;
create policy "space_messages_member_delete"
on public.space_messages for delete
using (public.is_space_member(space_id, auth.uid()));
