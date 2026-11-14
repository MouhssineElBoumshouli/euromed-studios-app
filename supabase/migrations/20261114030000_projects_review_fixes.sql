-- Review fixes for projects (part 1).

-- 1. Deleting a stored file follows the same rule as remove_project_file:
--    before production, by the uploader or the project owner. The uploader
--    may also clean up their own upload that was never recorded.
create or replace function public.can_delete_project_object(obj_name text, obj_owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.projects pr
    where pr.id = (storage.foldername(obj_name))[1]
      and public.involved_in(public.me(), pr)
      and (
        -- never recorded: the uploader cleans up after a failed save
        (obj_owner = auth.uid()
          and not exists (select 1 from public.project_files f where f.path = obj_name))
        or
        -- recorded and already removed from the list by remove_project_file
        (pr.stage = 'preProduction' and (obj_owner = auth.uid() or pr.owner_id = auth.uid())
          and not exists (select 1 from public.project_files f where f.path = obj_name))
      )
  )
$$;
revoke execute on function public.can_delete_project_object(text, uuid) from public, anon;
grant execute on function public.can_delete_project_object(text, uuid) to authenticated;

drop policy "project files: delete" on storage.objects;
create policy "project files: delete" on storage.objects for delete to authenticated
  using (bucket_id = 'project-files' and public.can_delete_project_object(name, owner));

-- 2. A file is only recorded if it was really uploaded by this person; the
--    size comes from storage, not from the app.
create or replace function public.add_project_file(
  p_project text, p_kind text, p_name text, p_path text, p_size int
) returns public.project_files
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  real_size int;
  row public.project_files;
begin
  if not public.can_work_on_project(p_project) then raise exception 'not_allowed'; end if;
  if p_path not like p_project || '/%' then raise exception 'bad_path'; end if;
  select (o.metadata->>'size')::int into real_size
    from storage.objects o
    where o.bucket_id = 'project-files' and o.name = p_path and o.owner = auth.uid();
  if real_size is null then raise exception 'file_missing'; end if;
  insert into public.project_files (project_id, kind, name, path, size_bytes, uploaded_by)
  values (p_project, p_kind, p_name, p_path, real_size, me.slug) returning * into row;
  update public.projects
    set history = history || jsonb_build_object('type','fileAdded','at',now(),'actor',me.slug,'detail',p_name)
    where id = p_project;
  return row;
end $$;

-- 3. Everyone on a project (and studio staff) sees its sessions, so the
--    owner can see a collaborator's session and move the project forward.
create policy "sessions of my projects" on public.bookings for select to authenticated
  using (project_id is not null and public.can_see_project(project_id));

-- 4. Security advisor: fixed search path; the trigger function is not an API.
alter function public.involved_in(public.profiles, public.projects) set search_path = public;
revoke execute on function public.check_booking_project() from public, anon, authenticated;
