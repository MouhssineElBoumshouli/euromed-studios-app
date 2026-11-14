-- Projects, part 2 (R-24, R-25, R-27, P-07, P-08):
-- post-production status and a conversation thread with correction
-- requests, the technical team's quality check and final delivery, and
-- inviting collaborators.
-- Additive only: new columns, new tables, new functions.

alter table public.projects
  add column post_status text not null default 'notStarted'
    check (post_status in ('notStarted','inProgress','correctionRequested','readyForCheck')),
  add column delivery_url text check (delivery_url is null or delivery_url ~ '^https://'),
  add column delivered_at timestamptz,
  add column qc_note text check (char_length(qc_note) <= 600);

-- The conversation of a project (mostly during post-production).
create table public.project_messages (
  id uuid primary key default gen_random_uuid(),
  project_id text not null references public.projects (id) on delete cascade,
  author_slug text not null,
  kind text not null default 'message'
    check (kind in ('message','correction','status','qcFailed','qcPassed')),
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index project_messages_project on public.project_messages (project_id, created_at);

-- Invitations to collaborate (R-27). The title is copied so the invited
-- person can read it before they can see the project.
create table public.project_invites (
  id uuid primary key default gen_random_uuid(),
  project_id text not null references public.projects (id) on delete cascade,
  project_title text not null,
  invitee_slug text not null,
  invited_by text not null,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  answered_at timestamptz
);
create unique index project_invites_one_pending
  on public.project_invites (project_id, invitee_slug) where status = 'pending';

alter table public.project_messages enable row level security;
alter table public.project_invites enable row level security;
create policy "project people" on public.project_messages for select to authenticated
  using (public.can_see_project(project_id));
create policy "invitee, owner or staff" on public.project_invites for select to authenticated
  using (invitee_slug = (public.me()).slug or public.can_see_project(project_id));

create trigger project_messages_bump after insert or update or delete on public.project_messages
  for each statement execute function public.bump_world();
create trigger project_invites_bump after insert or update or delete on public.project_invites
  for each statement execute function public.bump_world();

-- ------------------------------------------------------------------ helpers
-- The technical team runs editing and the quality check.
create or replace function public.is_tech_team(p public.profiles) returns boolean
language sql stable set search_path = public as $$
  select public.has_role(p,'regisseur') or public.has_role(p,'studioManager') or public.has_role(p,'admin')
$$;

create or replace function public.log_project(pid text, actor text, ev text, detail text default null)
returns void language sql security definer set search_path = public as $$
  update public.projects
    set history = history || jsonb_strip_nulls(jsonb_build_object('type',ev,'at',now(),'actor',actor,'detail',detail))
    where id = pid
$$;
revoke execute on function public.log_project(text, text, text, text) from public, anon, authenticated;

-- --------------------------------------------------------- post-production
-- Technical team: notStarted → inProgress → readyForCheck, and back to
-- inProgress after a correction request.
create or replace function public.set_post_status(p_id text, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  pr public.projects;
begin
  select * into pr from public.projects where id = p_id for update;
  if pr.id is null then raise exception 'not_found'; end if;
  if not public.is_tech_team(me) then raise exception 'not_allowed'; end if;
  if pr.stage <> 'postProduction' then raise exception 'wrong_stage'; end if;
  if not (
    (pr.post_status in ('notStarted','correctionRequested') and p_status = 'inProgress') or
    (pr.post_status = 'inProgress' and p_status = 'readyForCheck')
  ) then raise exception 'bad_transition'; end if;
  update public.projects set post_status = p_status where id = p_id;
  insert into public.project_messages (project_id, author_slug, kind, body)
  values (p_id, me.slug, 'status', p_status);
  perform public.log_project(p_id, me.slug, 'postStatus', p_status);
end $$;

-- Anyone on the project, or staff, writes in the thread. The owner and
-- collaborators can turn a message into a correction request (R-24).
create or replace function public.post_project_message(p_id text, p_body text, p_correction boolean default false)
returns void language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  pr public.projects;
  body text := trim(p_body);
begin
  select * into pr from public.projects where id = p_id for update;
  if pr.id is null then raise exception 'not_found'; end if;
  if pr.stage = 'archived' then raise exception 'archived'; end if;
  if not (public.involved_in(me, pr) or public.is_staff(me)) then raise exception 'not_allowed'; end if;
  if char_length(body) = 0 then raise exception 'empty'; end if;
  if p_correction then
    if not public.involved_in(me, pr) then raise exception 'not_allowed'; end if;
    if pr.stage <> 'postProduction' or pr.post_status not in ('inProgress','readyForCheck') then
      raise exception 'no_correction_now';
    end if;
    update public.projects set post_status = 'correctionRequested' where id = p_id;
    perform public.log_project(p_id, me.slug, 'correction', left(body, 140));
  end if;
  insert into public.project_messages (project_id, author_slug, kind, body)
  values (p_id, me.slug, case when p_correction then 'correction' else 'message' end, body);
end $$;

-- ----------------------------------------------------------- quality check
-- P-08: a pass archives the project and releases the final file (a secure
-- link, see Q12); a fail sends it back to corrections with a reason.
create or replace function public.quality_check(p_id text, p_passed boolean, p_note text default null, p_delivery_url text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  pr public.projects;
  note text := nullif(trim(coalesce(p_note, '')), '');
begin
  select * into pr from public.projects where id = p_id for update;
  if pr.id is null then raise exception 'not_found'; end if;
  if not public.is_tech_team(me) then raise exception 'not_allowed'; end if;
  if pr.stage <> 'postProduction' or pr.post_status <> 'readyForCheck' then raise exception 'not_ready'; end if;
  if p_passed then
    if p_delivery_url is null or p_delivery_url !~ '^https://[^ ]+\.[^ ]+' then raise exception 'bad_link'; end if;
    update public.projects set stage = 'archived', delivery_url = p_delivery_url, delivered_at = now(), qc_note = note
      where id = p_id;
    insert into public.project_messages (project_id, author_slug, kind, body)
    values (p_id, me.slug, 'qcPassed', coalesce(note, 'Contrôle qualité validé.'));
    perform public.log_project(p_id, me.slug, 'qcPassed', null);
  else
    if note is null then raise exception 'reason_required'; end if;
    update public.projects set post_status = 'correctionRequested', qc_note = note where id = p_id;
    insert into public.project_messages (project_id, author_slug, kind, body)
    values (p_id, me.slug, 'qcFailed', note);
    perform public.log_project(p_id, me.slug, 'qcFailed', left(note, 140));
  end if;
end $$;

-- ----------------------------------------------------------------- members
create or replace function public.invite_member(p_id text, p_slug text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  pr public.projects;
  invitee public.profiles;
begin
  select * into pr from public.projects where id = p_id for update;
  if pr.id is null then raise exception 'not_found'; end if;
  if pr.owner_id <> me.id then raise exception 'not_allowed'; end if;
  if pr.stage = 'archived' then raise exception 'archived'; end if;
  select * into invitee from public.profiles where slug = p_slug;
  if invitee.id is null then raise exception 'unknown_person'; end if;
  if invitee.id = pr.owner_id or p_slug = any (pr.member_slugs) then raise exception 'already_member'; end if;
  if cardinality(pr.member_slugs) >= 10 then raise exception 'too_many_members'; end if;
  if exists (select 1 from public.project_invites where project_id = p_id and invitee_slug = p_slug and status = 'pending') then
    raise exception 'already_invited';
  end if;
  insert into public.project_invites (project_id, project_title, invitee_slug, invited_by)
  values (p_id, pr.title, p_slug, me.slug);
  perform public.log_project(p_id, me.slug, 'memberInvited', p_slug);
end $$;

create or replace function public.answer_invite(p_invite uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  inv public.project_invites;
  pr public.projects;
begin
  select * into inv from public.project_invites where id = p_invite for update;
  if inv.id is null or inv.invitee_slug <> me.slug then raise exception 'not_found'; end if;
  if inv.status <> 'pending' then raise exception 'already_answered'; end if;
  select * into pr from public.projects where id = inv.project_id for update;
  if p_accept and pr.stage = 'archived' then raise exception 'archived'; end if;
  update public.project_invites set status = case when p_accept then 'accepted' else 'declined' end, answered_at = now()
    where id = p_invite;
  if p_accept then
    update public.projects set member_slugs = array_append(member_slugs, me.slug)
      where id = pr.id and not (me.slug = any (member_slugs));
    perform public.log_project(pr.id, me.slug, 'memberJoined', null);
  end if;
end $$;

create or replace function public.cancel_invite(p_invite uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  inv public.project_invites;
begin
  select * into inv from public.project_invites where id = p_invite for update;
  if inv.id is null or inv.status <> 'pending' then raise exception 'not_found'; end if;
  if not exists (select 1 from public.projects where id = inv.project_id and owner_id = me.id) then
    raise exception 'not_allowed';
  end if;
  update public.project_invites set status = 'cancelled', answered_at = now() where id = p_invite;
end $$;

-- The owner removes a collaborator, or a collaborator leaves.
create or replace function public.remove_member(p_id text, p_slug text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  pr public.projects;
begin
  select * into pr from public.projects where id = p_id for update;
  if pr.id is null then raise exception 'not_found'; end if;
  if not (pr.owner_id = me.id or me.slug = p_slug) then raise exception 'not_allowed'; end if;
  if not (p_slug = any (pr.member_slugs)) then raise exception 'not_member'; end if;
  update public.projects set member_slugs = array_remove(member_slugs, p_slug) where id = p_id;
  perform public.log_project(p_id, me.slug, case when me.slug = p_slug then 'memberLeft' else 'memberRemoved' end, p_slug);
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.set_post_status(text, text)',
    'public.post_project_message(text, text, boolean)',
    'public.quality_check(text, boolean, text, text)',
    'public.invite_member(text, text)',
    'public.answer_invite(uuid, boolean)',
    'public.cancel_invite(uuid)',
    'public.remove_member(text, text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
revoke execute on function public.is_tech_team(public.profiles) from public, anon;

-- --------------------------------------------------------------- demo data
-- The court-métrage is being edited and Adam has asked for a change; Yasmine
-- has invited Rami to her podcast.
create or replace function public.reset_demo_projects_part2() returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.projects set post_status = 'correctionRequested' where id = 'p3';
  insert into public.project_messages (project_id, author_slug, kind, body, created_at) values
  ('p3', 'haddad', 'status', 'inProgress', now() - interval '6 days'),
  ('p3', 'haddad', 'message', 'Premier montage en ligne. Durée actuelle : 8 min 40. Dites-nous si le rythme vous convient.', now() - interval '3 days'),
  ('p3', 'adam', 'correction', 'Merci ! Pouvez-vous raccourcir la scène 4 d’environ 20 secondes et remonter un peu le son des dialogues ?', now() - interval '2 days');
  update public.projects set history = history
    || jsonb_build_object('type','stageChanged','at',now()-interval '8 days','actor','adam','detail','postProduction')
    || jsonb_build_object('type','postStatus','at',now()-interval '6 days','actor','haddad','detail','inProgress')
    || jsonb_build_object('type','correction','at',now()-interval '2 days','actor','adam','detail','Raccourcir la scène 4, remonter le son des dialogues')
    where id = 'p3';
  insert into public.project_invites (project_id, project_title, invitee_slug, invited_by, created_at)
  values ('p1', 'Podcast « Voix du campus »', 'rami', 'yasmine', now() - interval '5 hours');
  update public.projects set history = history
    || jsonb_build_object('type','memberInvited','at',now()-interval '5 hours','actor','yasmine','detail','rami')
    where id = 'p1';
end $$;
revoke execute on function public.reset_demo_projects_part2() from public, anon, authenticated;

-- reset_demo() calls it at the end (projects are rebuilt first).
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
  ('p1', 'rundown', 'Conducteur épisode 1.pdf', 'p1/conducteur-episode-1.pdf', 640, 'yasmine', now() - interval '23 days'),
  ('p3', 'script', 'Script court-métrage.pdf', 'p3/script-court-metrage.pdf', 650, 'adam', now() - interval '43 days');
  update public.bookings set project_id = 'p1'
    where requester_slug = 'yasmine' and studio_id = 'podcast';
  update public.bookings set project_id = 'p2'
    where requester_slug = 'rami' and studio_id = 'pedago';
  perform public.reset_demo_projects_part2();
end $$;
revoke execute on function public.reset_demo() from public, anon;
grant execute on function public.reset_demo() to authenticated;
