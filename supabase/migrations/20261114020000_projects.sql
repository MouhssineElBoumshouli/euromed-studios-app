-- Projects (§4.2, R-21 to R-27), part 1: projects, preparation files,
-- moving through the stages, and linking bookings to a project.
-- Same pattern as bookings: clients read through RLS, every write goes
-- through a function that checks the rules again.

create table public.projects (
  id text primary key default 'p' || substr(md5(gen_random_uuid()::text), 1, 10),
  title text not null check (char_length(title) between 3 and 80),
  description text check (char_length(description) <= 600),
  type text not null check (type in ('teaching','research','culture','communication')),
  stage text not null default 'preProduction'
    check (stage in ('preProduction','production','postProduction','archived')),
  owner_id uuid not null references public.profiles (id),
  owner_slug text not null,
  member_slugs text[] not null default '{}',
  created_at timestamptz not null default now(),
  history jsonb not null default '[]'
);

create table public.project_files (
  id uuid primary key default gen_random_uuid(),
  project_id text not null references public.projects (id) on delete cascade,
  kind text not null check (kind in ('script','rundown','storyboard','other')),
  name text not null check (char_length(name) between 1 and 120),
  path text not null unique,
  size_bytes int not null check (size_bytes between 1 and 20971520),
  uploaded_by text not null,
  uploaded_at timestamptz not null default now()
);
create index project_files_project on public.project_files (project_id);
create index bookings_project on public.bookings (project_id);

-- ------------------------------------------------------------------ helpers
create or replace function public.involved_in(p public.profiles, pr public.projects) returns boolean
language sql immutable as $$
  select p.id is not null and (pr.owner_id = p.id or p.slug = any (pr.member_slugs))
$$;

create or replace function public.can_see_project(pid text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects pr
    where pr.id = pid and (public.involved_in(public.me(), pr) or public.is_staff(public.me()))
  )
$$;

create or replace function public.can_work_on_project(pid text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects pr
    where pr.id = pid and pr.stage <> 'archived' and public.involved_in(public.me(), pr)
  )
$$;
revoke execute on function public.can_see_project(text) from public, anon;
revoke execute on function public.can_work_on_project(text) from public, anon;
grant execute on function public.can_see_project(text) to authenticated;
grant execute on function public.can_work_on_project(text) to authenticated;

-- ---------------------------------------------------------------- read rules
alter table public.projects enable row level security;
alter table public.project_files enable row level security;
create policy "involved or staff" on public.projects for select to authenticated
  using (public.involved_in(public.me(), projects) or public.is_staff(public.me()));
create policy "involved or staff" on public.project_files for select to authenticated
  using (public.can_see_project(project_id));

create trigger projects_bump after insert or update or delete on public.projects
  for each statement execute function public.bump_world();
create trigger project_files_bump after insert or update or delete on public.project_files
  for each statement execute function public.bump_world();

-- ------------------------------------------------- bookings for a project
-- A booking may only be linked to a project its requester works on.
create or replace function public.check_booking_project() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.project_id is null then return new; end if;
  if not exists (
    select 1 from public.projects pr
    where pr.id = new.project_id and pr.stage <> 'archived'
      and (pr.owner_id = new.requester_id or new.requester_slug = any (pr.member_slugs))
  ) then
    raise exception 'project_not_allowed';
  end if;
  return new;
end $$;
create trigger bookings_project_check before insert or update of project_id on public.bookings
  for each row execute function public.check_booking_project();

-- ----------------------------------------------------------------- actions
create or replace function public.create_project(p_title text, p_type text, p_description text default null)
returns public.projects
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  row public.projects;
begin
  if me.id is null or not (me.roles && array['student','professor','communication','clubRepresentative','externalClient']) then
    raise exception 'not_a_requester';
  end if;
  insert into public.projects (title, description, type, owner_id, owner_slug, history)
  values (trim(p_title), nullif(trim(p_description), ''), p_type, me.id, me.slug,
    jsonb_build_array(jsonb_build_object('type','created','at',now(),'actor',me.slug)))
  returning * into row;
  return row;
end $$;

create or replace function public.advance_project(p_id text) returns public.projects
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  pr public.projects;
  nxt text;
begin
  select * into pr from public.projects where id = p_id for update;
  if pr.id is null then raise exception 'not_found'; end if;
  if not (pr.owner_id = me.id or public.has_role(me,'studioManager') or public.has_role(me,'admin')) then
    raise exception 'not_allowed';
  end if;
  if pr.stage = 'preProduction' then
    if not exists (select 1 from public.project_files f
                   where f.project_id = pr.id and f.kind in ('script','rundown','storyboard')) then
      raise exception 'needs_preparation_file';
    end if;
    nxt := 'production';
  elsif pr.stage = 'production' then
    if not exists (select 1 from public.bookings b
                   where b.project_id = pr.id and b.status in ('approved','completed')) then
      raise exception 'needs_validated_session';
    end if;
    nxt := 'postProduction';
  elsif pr.stage = 'postProduction' then
    raise exception 'needs_quality_check';
  else
    raise exception 'archived';
  end if;
  update public.projects set stage = nxt,
    history = history || jsonb_build_object('type','stageChanged','at',now(),'actor',me.slug,'detail',nxt)
  where id = pr.id returning * into pr;
  return pr;
end $$;

create or replace function public.add_project_file(
  p_project text, p_kind text, p_name text, p_path text, p_size int
) returns public.project_files
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  row public.project_files;
begin
  if not public.can_work_on_project(p_project) then raise exception 'not_allowed'; end if;
  if p_path not like p_project || '/%' then raise exception 'bad_path'; end if;
  insert into public.project_files (project_id, kind, name, path, size_bytes, uploaded_by)
  values (p_project, p_kind, p_name, p_path, p_size, me.slug) returning * into row;
  update public.projects
    set history = history || jsonb_build_object('type','fileAdded','at',now(),'actor',me.slug,'detail',p_name)
    where id = p_project;
  return row;
end $$;

create or replace function public.remove_project_file(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  f public.project_files;
  pr public.projects;
begin
  select * into f from public.project_files where id = p_id;
  if f.id is null then raise exception 'not_found'; end if;
  select * into pr from public.projects where id = f.project_id;
  -- Only before production starts, by the uploader or the owner.
  if pr.stage <> 'preProduction' or not (f.uploaded_by = me.slug or pr.owner_id = me.id) then
    raise exception 'not_allowed';
  end if;
  delete from public.project_files where id = p_id;
  update public.projects
    set history = history || jsonb_build_object('type','fileRemoved','at',now(),'actor',me.slug,'detail',f.name)
    where id = pr.id;
end $$;

revoke execute on function public.create_project(text, text, text) from public, anon;
revoke execute on function public.advance_project(text) from public, anon;
revoke execute on function public.add_project_file(text, text, text, text, int) from public, anon;
revoke execute on function public.remove_project_file(uuid) from public, anon;
grant execute on function public.create_project(text, text, text) to authenticated;
grant execute on function public.advance_project(text) to authenticated;
grant execute on function public.add_project_file(text, text, text, text, int) to authenticated;
grant execute on function public.remove_project_file(uuid) to authenticated;

-- ------------------------------------------------------------ file storage
-- Private bucket; each project has its own folder named after its id.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('project-files', 'project-files', false, 20971520, array[
  'application/pdf', 'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.oasis.opendocument.text', 'text/plain', 'image/png', 'image/jpeg'
]) on conflict (id) do nothing;

create policy "project files: read" on storage.objects for select to authenticated
  using (bucket_id = 'project-files' and public.can_see_project((storage.foldername(name))[1]));
create policy "project files: upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'project-files' and public.can_work_on_project((storage.foldername(name))[1]));
create policy "project files: delete" on storage.objects for delete to authenticated
  using (bucket_id = 'project-files' and public.can_work_on_project((storage.foldername(name))[1]));

-- --------------------------------------------------------------- demo data
-- reset_demo() also rebuilds the demo projects (fixed ids p1–p3, so their
-- stored files survive a reset) and links a few bookings to them.
alter function public.reset_demo() rename to reset_demo_sessions;
revoke execute on function public.reset_demo_sessions() from public, anon, authenticated;

create or replace function public.reset_demo() returns void
language plpgsql security definer set search_path = public as $$
declare
  id_of jsonb;
begin
  if auth.uid() is not null and not public.has_role(public.me(), 'admin') then
    raise exception 'not_allowed';
  end if;
  delete from public.projects where true;
  perform public.reset_demo_sessions();
  select jsonb_object_agg(slug, id) into id_of from public.profiles;
  insert into public.projects (id, title, description, type, stage, owner_id, owner_slug, member_slugs, created_at, history) values
  ('p1', 'Podcast « Voix du campus »',
    'Une série de 6 épisodes avec des étudiants et des enseignants sur la vie au campus.',
    'culture', 'production', (id_of->>'yasmine')::uuid, 'yasmine', array['adam'], now() - interval '25 days',
    jsonb_build_array(
      jsonb_build_object('type','created','at',now()-interval '25 days','actor','yasmine'),
      jsonb_build_object('type','fileAdded','at',now()-interval '23 days','actor','yasmine','detail','Conducteur épisode 1.pdf'),
      jsonb_build_object('type','stageChanged','at',now()-interval '22 days','actor','yasmine','detail','production'))),
  ('p2', 'MOOC « Introduction à l’IA »',
    'Huit capsules vidéo de 10 minutes pour le cours en ligne de première année.',
    'teaching', 'preProduction', (id_of->>'rami')::uuid, 'rami', '{}', now() - interval '4 days',
    jsonb_build_array(jsonb_build_object('type','created','at',now()-interval '4 days','actor','rami'))),
  ('p3', 'Court-métrage du Club Audiovisuel',
    'Un court-métrage de fiction de 8 minutes tourné au Plateau TV et sur fond vert.',
    'culture', 'postProduction', (id_of->>'adam')::uuid, 'adam', '{}', now() - interval '45 days',
    jsonb_build_array(jsonb_build_object('type','created','at',now()-interval '45 days','actor','adam')));
  insert into public.project_files (project_id, kind, name, path, size_bytes, uploaded_by, uploaded_at) values
  ('p1', 'rundown', 'Conducteur épisode 1.pdf', 'p1/conducteur-episode-1.pdf', 182400, 'yasmine', now() - interval '23 days'),
  ('p3', 'script', 'Script court-métrage.pdf', 'p3/script-court-metrage.pdf', 241000, 'adam', now() - interval '43 days');
  -- Link Yasmine's podcast sessions and Rami's MOOC session.
  update public.bookings set project_id = 'p1'
    where requester_slug = 'yasmine' and studio_id = 'podcast';
  update public.bookings set project_id = 'p2'
    where requester_slug = 'rami' and studio_id = 'pedago';
end $$;
revoke execute on function public.reset_demo() from public, anon;
grant execute on function public.reset_demo() to authenticated;
-- The nightly job keeps calling public.reset_demo(), now including projects.
