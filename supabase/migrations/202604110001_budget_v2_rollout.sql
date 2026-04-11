-- Budget v2 rollout for the Supabase backend.
-- Fixes schema-cache errors for new budget entry fields, recurring rules,
-- and per-space budget settings.

create extension if not exists pgcrypto;

alter table if exists public.budget_entries
    add column if not exists subcategory text,
    add column if not exists merchant_name text,
    add column if not exists merchant_url text,
    add column if not exists is_fixed boolean not null default false;

create table if not exists public.budget_recurring_rules (
    id uuid primary key default gen_random_uuid(),
    space_id uuid not null references public.spaces(id) on delete cascade,
    title text not null,
    kind text not null check (kind in ('income', 'expense')),
    amount numeric not null check (amount >= 0),
    category text not null,
    subcategory text,
    merchant_name text,
    merchant_url text,
    notes text,
    cadence text not null check (cadence in ('daily', 'weekly', 'monthly', 'yearly')),
    anchor_date timestamptz not null,
    is_fixed boolean not null default true,
    icon_name text,
    icon_color_hex text,
    is_active boolean not null default true,
    created_by uuid references auth.users(id) on delete set null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version integer not null default 1,
    updated_by uuid references auth.users(id) on delete set null,
    deleted_at timestamptz
);

create index if not exists budget_recurring_rules_space_active_idx
    on public.budget_recurring_rules(space_id, is_active)
    where deleted_at is null;

create index if not exists budget_recurring_rules_space_anchor_idx
    on public.budget_recurring_rules(space_id, anchor_date)
    where deleted_at is null;

create table if not exists public.budget_space_settings (
    id uuid primary key default gen_random_uuid(),
    space_id uuid not null unique references public.spaces(id) on delete cascade,
    opening_balance numeric not null default 0,
    currency_code text not null default 'PLN',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    version integer not null default 1,
    updated_by uuid references auth.users(id) on delete set null
);

create index if not exists budget_space_settings_space_idx
    on public.budget_space_settings(space_id);

alter table public.budget_recurring_rules enable row level security;
alter table public.budget_space_settings enable row level security;

drop policy if exists "budget_recurring_rules_select_space_members" on public.budget_recurring_rules;
create policy "budget_recurring_rules_select_space_members"
    on public.budget_recurring_rules
    for select
    using (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_recurring_rules.space_id
              and sm.user_id = auth.uid()
        )
    );

drop policy if exists "budget_recurring_rules_insert_space_members" on public.budget_recurring_rules;
create policy "budget_recurring_rules_insert_space_members"
    on public.budget_recurring_rules
    for insert
    with check (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_recurring_rules.space_id
              and sm.user_id = auth.uid()
        )
    );

drop policy if exists "budget_recurring_rules_update_space_members" on public.budget_recurring_rules;
create policy "budget_recurring_rules_update_space_members"
    on public.budget_recurring_rules
    for update
    using (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_recurring_rules.space_id
              and sm.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_recurring_rules.space_id
              and sm.user_id = auth.uid()
        )
    );

drop policy if exists "budget_recurring_rules_delete_space_members" on public.budget_recurring_rules;
create policy "budget_recurring_rules_delete_space_members"
    on public.budget_recurring_rules
    for delete
    using (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_recurring_rules.space_id
              and sm.user_id = auth.uid()
        )
    );

drop policy if exists "budget_space_settings_select_space_members" on public.budget_space_settings;
create policy "budget_space_settings_select_space_members"
    on public.budget_space_settings
    for select
    using (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_space_settings.space_id
              and sm.user_id = auth.uid()
        )
    );

drop policy if exists "budget_space_settings_insert_space_members" on public.budget_space_settings;
create policy "budget_space_settings_insert_space_members"
    on public.budget_space_settings
    for insert
    with check (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_space_settings.space_id
              and sm.user_id = auth.uid()
        )
    );

drop policy if exists "budget_space_settings_update_space_members" on public.budget_space_settings;
create policy "budget_space_settings_update_space_members"
    on public.budget_space_settings
    for update
    using (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_space_settings.space_id
              and sm.user_id = auth.uid()
        )
    )
    with check (
        exists (
            select 1
            from public.space_members sm
            where sm.space_id = budget_space_settings.space_id
              and sm.user_id = auth.uid()
        )
    );

notify pgrst, 'reload schema';
