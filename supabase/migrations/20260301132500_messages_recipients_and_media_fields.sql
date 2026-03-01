-- Recipients for messenger + media fields for missions/incidents

alter table public.space_messages
  add column if not exists recipient_ids uuid[] not null default '{}';

alter table public.missions
  add column if not exists icon_name text,
  add column if not exists image_data bytea;

alter table public.incidents
  add column if not exists icon_name text,
  add column if not exists image_data bytea;
