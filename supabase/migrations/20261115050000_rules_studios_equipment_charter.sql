-- I4–I7 · Rules, studios, maintenance, equipment and the charter, set by
-- an admin. Each change is checked, applied in one step and logged (P-11).
-- The studio manager can also plan maintenance (he runs the rooms).

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
  if p_opening < 6 or p_closing > 23 or p_opening >= p_closing then raise exception 'bad_hours'; end if;
  if p_slot not in (30, 60, 120) then raise exception 'bad_slot'; end if;
  if ((p_closing - p_opening) * 60) % p_slot <> 0 then raise exception 'slot_misfit'; end if;
  if p_advance not between 1 and 180 then raise exception 'bad_advance'; end if;
  if p_quota not between 30 and 2400 or p_quota % 30 <> 0 then raise exception 'bad_quota'; end if;
  if p_grace not between 0 and 60 then raise exception 'bad_grace'; end if;
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
  if s.student_quota_minutes <> p_quota then
    parts := parts || format('Quota étudiant : %s → %s h/semaine',
      trim(to_char(s.student_quota_minutes / 60.0, 'FM990.0')), trim(to_char(p_quota / 60.0, 'FM990.0')));
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

create trigger settings_bump after update on public.settings
  for each statement execute function public.bump_world();

-- Open or close a studio to booking. Bookings already made are kept.
create or replace function public.set_studio_bookable(p_id text, p_bookable boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  st public.studios;
begin
  if not public.has_role(me, 'admin') then raise exception 'not_allowed'; end if;
  select * into st from public.studios where id = p_id for update;
  if st.id is null then raise exception 'not_found'; end if;
  if st.bookable = p_bookable then return; end if;
  update public.studios set bookable = p_bookable where id = p_id;
  perform public.audit('studioChanged', 'studio', p_id,
    st.name || case when p_bookable then ' : ouvert à la réservation' else ' : fermé à la réservation' end);
end $$;

create trigger studios_bump after update on public.studios
  for each statement execute function public.bump_world();

-- Plan a maintenance closure. Validated sessions in that window are
-- reported back so staff can warn the people concerned (they are not
-- cancelled automatically).
create or replace function public.add_maintenance(
  p_room text, p_start timestamptz, p_end timestamptz, p_reason text
) returns int
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  reason text := trim(coalesce(p_reason, ''));
  clashes int;
  names text;
begin
  if not (public.has_role(me, 'admin') or public.has_role(me, 'studioManager')) then
    raise exception 'not_allowed';
  end if;
  if not exists (select 1 from public.studios where room_id = p_room) then raise exception 'not_found'; end if;
  if p_end <= p_start then raise exception 'bad_period'; end if;
  if p_end < now() then raise exception 'in_the_past'; end if;
  if p_end - p_start > interval '60 days' then raise exception 'too_long'; end if;
  if char_length(reason) not between 3 and 200 then raise exception 'reason_required'; end if;
  if exists (select 1 from public.maintenance m where m.room_id = p_room and m.start_at < p_end and p_start < m.end_at) then
    raise exception 'overlap';
  end if;
  insert into public.maintenance (room_id, start_at, end_at, reason) values (p_room, p_start, p_end, reason);
  select count(*) into clashes from public.bookings b join public.studios s on s.id = b.studio_id
    where s.room_id = p_room and b.status in ('approved','pendingEntity','pendingStudio')
      and b.start_at < p_end and p_start < b.end_at;
  select string_agg(name, ' / ') into names from public.studios where room_id = p_room;
  perform public.audit('maintenancePlanned', 'room', p_room,
    names || ' : ' || to_char(p_start at time zone 'Africa/Casablanca', 'DD/MM HH24:MI') || ' → '
      || to_char(p_end at time zone 'Africa/Casablanca', 'DD/MM HH24:MI') || ' · ' || reason
      || case when clashes > 0 then ' · ' || clashes || ' séance(s) concernée(s)' else '' end);
  return clashes;
end $$;

create or replace function public.remove_maintenance(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  m public.maintenance;
  names text;
begin
  if not (public.has_role(me, 'admin') or public.has_role(me, 'studioManager')) then
    raise exception 'not_allowed';
  end if;
  select * into m from public.maintenance where id = p_id for update;
  if m.id is null then raise exception 'not_found'; end if;
  delete from public.maintenance where id = p_id;
  select string_agg(name, ' / ') into names from public.studios where room_id = m.room_id;
  perform public.audit('maintenanceRemoved', 'room', m.room_id, names || ' : ' || m.reason);
end $$;

-- Equipment stock (I5). Lowering stock below what is already promised for
-- future sessions is refused.
create or replace function public.set_equipment_stock(p_id text, p_stock int) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  e public.equipment;
begin
  if not public.has_role(me, 'admin') then raise exception 'not_allowed'; end if;
  if p_stock not between 0 and 999 then raise exception 'bad_stock'; end if;
  select * into e from public.equipment where id = p_id for update;
  if e.id is null then raise exception 'not_found'; end if;
  if e.stock = p_stock then return; end if;
  update public.equipment set stock = p_stock where id = p_id;
  perform public.audit('equipmentChanged', 'equipment', p_id,
    format('%s : stock %s → %s', e.name, e.stock, p_stock));
end $$;

create trigger equipment_bump after update on public.equipment
  for each statement execute function public.bump_world();

-- Charter (I7): a new version makes everyone sign again before booking.
create or replace function public.publish_charter(p_version text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  v text := trim(coalesce(p_version, ''));
  old text;
begin
  if not public.has_role(me, 'admin') then raise exception 'not_allowed'; end if;
  if v !~ '^[0-9]+(\.[0-9]+){0,2}$' then raise exception 'bad_version'; end if;
  select charter_version into old from public.settings where id = 1 for update;
  if v = old then raise exception 'same_version'; end if;
  update public.settings set charter_version = v where id = 1;
  perform public.audit('charterPublished', 'charter', v, format('Charte : version %s → %s', old, v));
end $$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.update_settings(int, int, int, int, int, int)',
    'public.set_studio_bookable(text, boolean)',
    'public.add_maintenance(text, timestamptz, timestamptz, text)',
    'public.remove_maintenance(uuid)',
    'public.set_equipment_stock(text, int)',
    'public.publish_charter(text)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
