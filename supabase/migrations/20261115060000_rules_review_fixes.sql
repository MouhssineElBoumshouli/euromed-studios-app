-- Review fixes for #16.
-- 1. submit_booking: slots line up with the opening hour (30-minute and
--    2-hour slots now work), the booking window counts whole days like the
--    app, and equipment is checked against the stock.
-- 2. update_settings: the student quota can be "no limit" (null).
-- 3. publish_charter: a new version must be higher than the current one.

create or replace function public.submit_booking(
  p_studio text, p_start timestamptz, p_end timestamptz, p_activity text,
  p_club text default null, p_project text default null, p_note text default null,
  p_equipment jsonb default '[]'
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  st public.settings;
  s public.studios;
  t text;
  ls timestamp; le timestamp;
  start_min int; end_min int;
  item jsonb;
  e public.equipment;
  used int;
  problem text;
  b public.bookings;
begin
  if p.id is null then raise exception 'not_signed_in'; end if;
  select * into st from public.settings;
  select * into s from public.studios where id = p_studio;
  if s.id is null or not s.bookable then raise exception 'studio_not_bookable'; end if;

  -- Who is asking, as which kind of requester.
  if p_club is not null then
    if not (public.has_role(p,'clubRepresentative') and p_club = any (p.club_ids)) then
      raise exception 'not_club_representative';
    end if;
    t := 'club';
  elsif public.has_role(p,'professor') then t := 'professor';
  elsif public.has_role(p,'communication') then t := 'communication';
  elsif public.has_role(p,'externalClient') then t := 'external';
  elsif public.has_role(p,'student') then t := 'student';
  else raise exception 'not_a_requester';
  end if;

  if not exists (select 1 from public.charter_signatures where person_id = p.id and version = st.charter_version) then
    raise exception 'charter_missing';
  end if;

  -- Opening hours, whole slots, weekdays, not in the past, not too far ahead.
  ls := p_start at time zone st.time_zone;
  le := p_end at time zone st.time_zone;
  start_min := extract(hour from ls)::int * 60 + extract(minute from ls)::int;
  end_min := extract(hour from le)::int * 60 + extract(minute from le)::int;
  if ls::date <> le::date
     or extract(isodow from ls) > 5
     or start_min < st.opening_hour * 60
     or end_min > st.closing_hour * 60
     or extract(epoch from (p_end - p_start)) / 60 < st.slot_minutes
     or (extract(epoch from (p_end - p_start)) / 60)::int % st.slot_minutes <> 0
     or extract(second from ls) <> 0
     or (start_min - st.opening_hour * 60) % st.slot_minutes <> 0 then
    raise exception 'outside_opening_hours';
  end if;
  if p_start <= now() then raise exception 'in_the_past'; end if;
  -- Whole calendar days, like the app: the last day of the window is open
  -- all day long.
  if ls::date > (now() at time zone st.time_zone)::date + st.max_advance_days then
    raise exception 'too_far_ahead';
  end if;
  if p_activity not in ('recording','filming','editing','mixing') then raise exception 'activity_required'; end if;

  problem := public.slot_problem(p_studio, p_start, p_end, null, false);
  if problem is not null then raise exception 'slot_taken: %', problem; end if;

  -- Weekly quota (Q4: students only by default).
  if t = 'student' and st.student_quota_minutes is not null then
    select coalesce(sum(extract(epoch from (o.end_at - o.start_at)) / 60), 0)::int into used
      from public.bookings o
     where o.requester_id = p.id and o.requester_type = 'student'
       and o.status in ('pendingEntity','pendingStudio','approved','completed')
       and date_trunc('week', o.start_at at time zone st.time_zone) = date_trunc('week', ls);
    if used + extract(epoch from (p_end - p_start)) / 60 > st.student_quota_minutes then
      raise exception 'quota_exceeded';
    end if;
  end if;

  -- Equipment: known items, whole quantities, never more than the stock.
  if p_equipment is not null and jsonb_typeof(p_equipment) <> 'array' then
    raise exception 'bad_equipment';
  end if;
  for item in select * from jsonb_array_elements(coalesce(p_equipment, '[]')) loop
    select * into e from public.equipment where id = item->>'item_id';
    if e.id is null or jsonb_typeof(item->'quantity') is distinct from 'number' then
      raise exception 'bad_equipment';
    end if;
    if (item->>'quantity')::numeric <> floor((item->>'quantity')::numeric)
       or (item->>'quantity')::numeric not between 1 and e.stock then
      raise exception 'bad_equipment';
    end if;
  end loop;

  insert into public.bookings (
    reference, requester_id, requester_slug, requester_type, establishment_id, club_id, project_id,
    studio_id, start_at, end_at, activity, status, note, equipment, history
  ) values (
    'ES-' || extract(year from now())::int || '-' || lpad(nextval('public.booking_reference_seq')::text, 4, '0'),
    p.id, p.slug, t, p.establishment_id, p_club, p_project,
    p_studio, p_start, p_end, p_activity, 'pendingEntity', nullif(trim(p_note), ''),
    coalesce(p_equipment, '[]'),
    jsonb_build_array(public.event('submitted', p.slug))
  ) returning * into b;
  return b;
end $$;

create or replace function public.update_settings(
  p_opening int, p_closing int, p_slot int, p_advance int, p_quota int, p_grace int
) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  s public.settings;
  parts text[] := '{}';
begin
  if not public.has_role(me, 'admin') then raise exception 'not_allowed'; end if;
  if p_opening is null or p_closing is null or p_opening < 6 or p_closing > 23 or p_opening >= p_closing then
    raise exception 'bad_hours';
  end if;
  if p_slot is null or p_slot not in (30, 60, 120) then raise exception 'bad_slot'; end if;
  if ((p_closing - p_opening) * 60) % p_slot <> 0 then raise exception 'slot_misfit'; end if;
  if p_advance is null or p_advance not between 1 and 180 then raise exception 'bad_advance'; end if;
  -- null = no weekly limit.
  if p_quota is not null and (p_quota not between 30 and 2400 or p_quota % 30 <> 0) then
    raise exception 'bad_quota';
  end if;
  if p_grace is null or p_grace not between 0 and 60 then raise exception 'bad_grace'; end if;
  select * into s from public.settings where id = 1 for update;
  if s.opening_hour <> p_opening or s.closing_hour <> p_closing then
    parts := parts || format('Horaires : %sh–%sh → %sh–%sh', s.opening_hour, s.closing_hour, p_opening, p_closing);
  end if;
  if s.slot_minutes <> p_slot then
    parts := parts || format('Créneaux : %s → %s min', s.slot_minutes, p_slot);
  end if;
  if s.max_advance_days <> p_advance then
    parts := parts || format('Réservation jusqu’à %s → %s jours', s.max_advance_days, p_advance);
  end if;
  if s.student_quota_minutes is distinct from p_quota then
    parts := parts || format('Quota étudiant : %s → %s',
      coalesce(replace(trim_scale(s.student_quota_minutes / 60.0)::text, '.', ',') || ' h/semaine', 'sans limite'),
      coalesce(replace(trim_scale(p_quota / 60.0)::text, '.', ',') || ' h/semaine', 'sans limite'));
  end if;
  if s.qr_grace_minutes <> p_grace then
    parts := parts || format('Accès avant la séance : %s → %s min', s.qr_grace_minutes, p_grace);
  end if;
  if cardinality(parts) = 0 then return; end if;
  update public.settings set opening_hour = p_opening, closing_hour = p_closing, slot_minutes = p_slot,
    max_advance_days = p_advance, student_quota_minutes = p_quota, qr_grace_minutes = p_grace
    where id = 1;
  perform public.audit('settingsChanged', 'settings', '1', array_to_string(parts, ' · '),
    jsonb_build_object('before', to_jsonb(s)));
end $$;

-- "2.1" → {2,1,0}, so versions compare as numbers (2.10 > 2.9).
create or replace function public.version_key(v text) returns int[]
language sql immutable set search_path = public as $$
  select (string_to_array(v, '.')::int[] || '{0,0}'::int[])[1:3]
$$;

create or replace function public.publish_charter(p_version text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  v text := trim(coalesce(p_version, ''));
  old text;
begin
  if not public.has_role(me, 'admin') then raise exception 'not_allowed'; end if;
  if v !~ '^[0-9]{1,4}(\.[0-9]{1,4}){0,2}$' then raise exception 'bad_version'; end if;
  select charter_version into old from public.settings where id = 1 for update;
  if public.version_key(v) = public.version_key(old) then raise exception 'same_version'; end if;
  if public.version_key(v) < public.version_key(old) then raise exception 'older_version'; end if;
  update public.settings set charter_version = v where id = 1;
  perform public.audit('charterPublished', 'charter', v, format('Charte : version %s → %s', old, v));
end $$;
