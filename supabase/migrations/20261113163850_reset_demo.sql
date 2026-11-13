-- Demo data, always relative to today, so the demo is fresh on any date.
-- The fictional administrator (Sara Idrissi) can run reset_demo() from the app.

-- k-th weekday from today in Casablanca (0 = today, or next weekday if weekend), at hour h.
create or replace function public.demo_at(k int, h int) returns timestamptz
language plpgsql stable set search_path = public as $$
declare d date := (now() at time zone 'Africa/Casablanca')::date; step int := sign(k)::int; n int := abs(k);
begin
  while extract(isodow from d) > 5 loop d := d + 1; end loop;
  while n > 0 loop
    d := d + step;
    if extract(isodow from d) <= 5 then n := n - 1; end if;
  end loop;
  return (d + make_time(h, 0, 0)) at time zone 'Africa/Casablanca';
end $$;

create or replace function public.reset_demo() returns void
language plpgsql security definer set search_path = public as $$
declare
  id_of jsonb;
begin
  if auth.uid() is not null and not public.has_role(public.me(), 'admin') then
    raise exception 'not_allowed';
  end if;
  select jsonb_object_agg(slug, id) into id_of from public.profiles;
  delete from public.bookings where true;
  delete from public.maintenance where true;
  delete from public.charter_signatures where true;
  perform setval('public.booking_reference_seq', 147, false);

  insert into public.charter_signatures (person_id, version)
    select id, '1.0' from public.profiles where slug <> 'omar';

  insert into public.maintenance (room_id, start_at, end_at, reason)
    values ('area4', demo_at(0, 14), demo_at(0, 17), 'Calibrage des caméras');

  insert into public.bookings (reference, requester_id, requester_slug, requester_type, establishment_id, club_id,
    studio_id, start_at, end_at, activity, status, note, refusal_reason, technician_slug, equipment, history) values
  ('ES-2026-0138', (id_of->>'yasmine')::uuid, 'yasmine', 'student', 'eidia', null, 'plateau_tv',
    demo_at(1,14), demo_at(1,15), 'filming', 'approved', null, null, 'haddad',
    '[{"item_id":"kit_cam","quantity":1,"required":true,"outcome":"confirmed"}]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',now()-interval '2 days','actor','yasmine'),
      jsonb_build_object('type','entityApproved','at',now()-interval '30 hours','actor','amrani'),
      jsonb_build_object('type','studioApproved','at',now()-interval '20 hours','actor','tazi','comment','S. Haddad sera en régie.'))),
  ('ES-2026-0142', (id_of->>'yasmine')::uuid, 'yasmine', 'student', 'eidia', null, 'podcast',
    demo_at(3,10), demo_at(3,11), 'recording', 'pendingStudio', 'Enregistrement avec deux invités.', null, null,
    '[{"item_id":"lav_mic","quantity":2,"required":false,"outcome":"pending"}]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',now()-interval '15 hours','actor','yasmine'),
      jsonb_build_object('type','entityApproved','at',now()-interval '50 minutes','actor','amrani','comment','Projet pertinent, bon courage.'))),
  ('ES-2026-0145', (id_of->>'yasmine')::uuid, 'yasmine', 'student', 'eidia', null, 'chroma',
    demo_at(4,9), demo_at(4,10), 'filming', 'pendingEntity', null, null, null, '[]',
    jsonb_build_array(jsonb_build_object('type','submitted','at',now()-interval '1 hour','actor','yasmine'))),
  ('ES-2026-0121', (id_of->>'yasmine')::uuid, 'yasmine', 'student', 'eidia', null, 'podcast',
    demo_at(-7,14), demo_at(-7,15), 'recording', 'completed', null, null, 'haddad', '[]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',demo_at(-10,11),'actor','yasmine'),
      jsonb_build_object('type','entityApproved','at',demo_at(-9,10),'actor','amrani'),
      jsonb_build_object('type','studioApproved','at',demo_at(-8,9),'actor','tazi'),
      jsonb_build_object('type','checkedIn','at',demo_at(-7,14),'actor','haddad'),
      jsonb_build_object('type','completed','at',demo_at(-7,15),'actor','haddad'))),
  ('ES-2026-0127', (id_of->>'yasmine')::uuid, 'yasmine', 'student', 'eidia', null, 'speedmooc',
    demo_at(-3,10), demo_at(-3,11), 'filming', 'refused', null,
    'Créneau réservé à un tournage MOOC prioritaire. Le Studio Pédagogique est libre le même jour à 14:00.', null, '[]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',demo_at(-6,16),'actor','yasmine'),
      jsonb_build_object('type','entityApproved','at',demo_at(-5,9),'actor','amrani'),
      jsonb_build_object('type','refused','at',demo_at(-5,15),'actor','tazi','comment',
        'Créneau réservé à un tournage MOOC prioritaire. Le Studio Pédagogique est libre le même jour à 14:00.'))),
  ('ES-2026-0131', (id_of->>'nadia')::uuid, 'nadia', 'communication', null, null, 'plateau_tv',
    demo_at(0,9), demo_at(0,12), 'filming', 'approved', null, null, 'haddad', '[]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',demo_at(-4,10),'actor','nadia'),
      jsonb_build_object('type','entityApproved','at',demo_at(-4,14),'actor','lahlou'),
      jsonb_build_object('type','studioApproved','at',demo_at(-3,9),'actor','tazi'))),
  ('ES-2026-0133', (id_of->>'rami')::uuid, 'rami', 'professor', 'eidia', null, 'pedago',
    demo_at(1,9), demo_at(1,12), 'recording', 'approved', null, null, null, '[]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',demo_at(-3,11),'actor','rami'),
      jsonb_build_object('type','entityApproved','at',demo_at(-3,17),'actor','benjelloun'),
      jsonb_build_object('type','studioApproved','at',demo_at(-1,10),'actor','tazi'))),
  ('ES-2026-0140', (id_of->>'adam')::uuid, 'adam', 'club', 'emadu', 'club_av', 'plateau_tv',
    demo_at(2,15), demo_at(2,17), 'filming', 'pendingStudio', 'Tournage de l’émission du club, 3 invités.', null, null,
    '[{"item_id":"hand_mic","quantity":2,"required":true,"outcome":"pending"},{"item_id":"led_kit","quantity":1,"required":false,"outcome":"pending"}]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',now()-interval '40 hours','actor','adam'),
      jsonb_build_object('type','entityApproved','at',now()-interval '16 hours','actor','amrani'))),
  ('ES-2026-0146', (id_of->>'adam')::uuid, 'adam', 'student', 'emadu', null, 'photo',
    demo_at(5,14), demo_at(5,15), 'filming', 'pendingEntity', null, null, null, '[]',
    jsonb_build_array(jsonb_build_object('type','submitted','at',now()-interval '25 minutes','actor','adam'))),
  ('ES-2026-0144', (id_of->>'omar')::uuid, 'omar', 'external', null, null, 'podcast',
    demo_at(6,10), demo_at(6,12), 'recording', 'pendingEntity', 'Enregistrement d’un podcast d’entreprise.', null, null, '[]',
    jsonb_build_array(jsonb_build_object('type','submitted','at',now()-interval '3 hours','actor','omar'))),
  ('ES-2026-0143', (id_of->>'benjelloun')::uuid, 'benjelloun', 'professor', 'eidia', null, 'speedmooc',
    demo_at(2,10), demo_at(2,11), 'recording', 'pendingEntity', 'Capsule de présentation du master IA.', null, null, '[]',
    jsonb_build_array(jsonb_build_object('type','submitted','at',now()-interval '5 hours','actor','benjelloun')));
end $$;
revoke execute on function public.reset_demo(), public.demo_at(int, int) from public, anon;
grant execute on function public.reset_demo() to authenticated;

select public.reset_demo();
