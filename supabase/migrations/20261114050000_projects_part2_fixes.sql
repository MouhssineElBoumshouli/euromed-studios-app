-- Review fixes for projects part 2.

-- The 10-collaborator cap counts pending invitations too, and is checked
-- again on acceptance. Only requesters and the technical team can be
-- invited (same list as the app).
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
  if not (invitee.roles && array['student','professor','communication','clubRepresentative','externalClient','regisseur']) then
    raise exception 'not_invitable';
  end if;
  if invitee.id = pr.owner_id or p_slug = any (pr.member_slugs) then raise exception 'already_member'; end if;
  if exists (select 1 from public.project_invites where project_id = p_id and invitee_slug = p_slug and status = 'pending') then
    raise exception 'already_invited';
  end if;
  if cardinality(pr.member_slugs)
     + (select count(*) from public.project_invites where project_id = p_id and status = 'pending') >= 10 then
    raise exception 'too_many_members';
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
  if p_accept and cardinality(pr.member_slugs) >= 10 then raise exception 'too_many_members'; end if;
  update public.project_invites set status = case when p_accept then 'accepted' else 'declined' end, answered_at = now()
    where id = p_invite;
  if p_accept then
    update public.projects set member_slugs = array_append(member_slugs, me.slug)
      where id = pr.id and not (me.slug = any (member_slugs));
    perform public.log_project(pr.id, me.slug, 'memberJoined', null);
  end if;
end $$;

-- Resuming the edit clears the previous quality-check comment.
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
  update public.projects
    set post_status = p_status,
        qc_note = case when p_status = 'inProgress' then null else qc_note end
    where id = p_id;
  insert into public.project_messages (project_id, author_slug, kind, body)
  values (p_id, me.slug, 'status', p_status);
  perform public.log_project(p_id, me.slug, 'postStatus', p_status);
end $$;

-- Same link rule as the app: https, a host with a dot, no spaces.
create or replace function public.quality_check(p_id text, p_passed boolean, p_note text default null, p_delivery_url text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  pr public.projects;
  note text := nullif(trim(coalesce(p_note, '')), '');
  link text := trim(coalesce(p_delivery_url, ''));
begin
  select * into pr from public.projects where id = p_id for update;
  if pr.id is null then raise exception 'not_found'; end if;
  if not public.is_tech_team(me) then raise exception 'not_allowed'; end if;
  if pr.stage <> 'postProduction' or pr.post_status <> 'readyForCheck' then raise exception 'not_ready'; end if;
  if p_passed then
    if link !~ '^https://[^[:space:]/]+\.[^[:space:]]+$' then raise exception 'bad_link'; end if;
    update public.projects set stage = 'archived', delivery_url = link, delivered_at = now(), qc_note = note
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
