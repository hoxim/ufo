-- Fix: infinite recursion in RLS policies on public.space_members
-- Root cause: policy queried public.space_members directly in USING/WITH CHECK.
-- This migration replaces recursive policies with SECURITY DEFINER helper functions.

create or replace function public.is_space_member(p_space_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.space_members sm
    where sm.space_id = p_space_id
      and sm.user_id = p_user_id
  );
$$;

create or replace function public.is_space_admin(p_space_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.space_members sm
    where sm.space_id = p_space_id
      and sm.user_id = p_user_id
      and sm.role = 'admin'
  );
$$;

grant execute on function public.is_space_member(uuid, uuid) to authenticated, service_role;
grant execute on function public.is_space_admin(uuid, uuid) to authenticated, service_role;

drop policy if exists "members_select_own_spaces" on public.space_members;
drop policy if exists "members_insert_authenticated" on public.space_members;
drop policy if exists "members_update_admin_or_self" on public.space_members;
drop policy if exists "members_delete_admin_or_self" on public.space_members;

-- Read:
-- - own membership rows
-- - membership rows in spaces where user is a member
drop policy if exists "space_members_select_member_or_same_space" on public.space_members;
create policy "space_members_select_member_or_same_space"
on public.space_members for select
using (
  user_id = auth.uid()
  or public.is_space_member(space_id, auth.uid())
);

-- Insert:
-- - self join
-- - admin can add anyone to their space
drop policy if exists "space_members_insert_self_or_admin" on public.space_members;
create policy "space_members_insert_self_or_admin"
on public.space_members for insert
with check (
  user_id = auth.uid()
  or public.is_space_admin(space_id, auth.uid())
);

-- Update:
-- - self row
-- - admin in the same space
drop policy if exists "space_members_update_self_or_admin" on public.space_members;
create policy "space_members_update_self_or_admin"
on public.space_members for update
using (
  user_id = auth.uid()
  or public.is_space_admin(space_id, auth.uid())
)
with check (
  user_id = auth.uid()
  or public.is_space_admin(space_id, auth.uid())
);

-- Delete:
-- - self row
-- - admin in the same space
drop policy if exists "space_members_delete_self_or_admin" on public.space_members;
create policy "space_members_delete_self_or_admin"
on public.space_members for delete
using (
  user_id = auth.uid()
  or public.is_space_admin(space_id, auth.uid())
);

