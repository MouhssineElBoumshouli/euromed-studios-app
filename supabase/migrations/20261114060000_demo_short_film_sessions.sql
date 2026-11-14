-- Demo: the short film (p3, in post-production) shows the two shooting
-- sessions it was made from, already held.
create or replace function public.reset_demo_short_film_sessions() returns void
language plpgsql security definer set search_path = public as $$
declare
  adam uuid := (select id from public.profiles where slug = 'adam');
begin
  insert into public.bookings (reference, requester_id, requester_slug, requester_type, establishment_id, club_id,
    studio_id, start_at, end_at, activity, status, note, refusal_reason, technician_slug, equipment, project_id, history)
  select v.ref, adam, 'adam', 'club', 'emadu', 'club_av', v.studio,
    v.s, v.s + interval '2 hours', 'filming', 'completed', 'Tournage du court-métrage.', null, 'haddad', '[]', 'p3',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',v.s - interval '6 days','actor','adam'),
      jsonb_build_object('type','entityApproved','at',v.s - interval '5 days','actor','amrani'),
      jsonb_build_object('type','studioApproved','at',v.s - interval '4 days','actor','tazi'),
      jsonb_build_object('type','checkedIn','at',v.s,'actor','haddad'),
      jsonb_build_object('type','completed','at',v.s + interval '2 hours','actor','haddad'))
  from (values
    ('ES-2026-0101', 'plateau_tv', date_trunc('day', now()) - interval '13 days' + interval '9 hours'),
    ('ES-2026-0104', 'chroma', date_trunc('day', now()) - interval '12 days' + interval '14 hours')
  ) as v(ref, studio, s);
end $$;
revoke execute on function public.reset_demo_short_film_sessions() from public, anon, authenticated;

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
  perform public.reset_demo_short_film_sessions();
end $$;
revoke execute on function public.reset_demo_projects_part2() from public, anon, authenticated;
