-- Régie: let a validated person in, then close the session with a report.
-- Only régisseurs, the Studio Manager and admins may do it.

create or replace function public.can_operate(p public.profiles) returns boolean
language sql immutable set search_path = public as $$
  select public.has_role(p,'regisseur') or public.has_role(p,'studioManager') or public.has_role(p,'admin')
$$;

create or replace function public.check_in_booking(p_id uuid) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  b public.bookings;
begin
  if not public.can_operate(p) then raise exception 'not_allowed'; end if;
  select * into b from public.bookings where id = p_id for update;
  if b.id is null then raise exception 'not_found'; end if;
  if b.status <> 'approved' then raise exception 'not_validated'; end if;
  if b.history @> '[{"type":"checkedIn"}]' then raise exception 'already_checked_in'; end if;
  if now() < b.start_at - interval '15 minutes' then raise exception 'too_early'; end if;
  if now() >= b.end_at then raise exception 'session_over'; end if;
  update public.bookings set history = history || public.event('checkedIn', p.slug)
   where id = p_id returning * into b;
  return b;
end $$;

create or replace function public.complete_booking(p_id uuid, p_report text default null)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  b public.bookings;
begin
  if not public.can_operate(p) then raise exception 'not_allowed'; end if;
  select * into b from public.bookings where id = p_id for update;
  if b.id is null then raise exception 'not_found'; end if;
  if b.status <> 'approved'
     or not (b.history @> '[{"type":"checkedIn"}]' or now() >= b.end_at) then
    raise exception 'not_allowed';
  end if;
  update public.bookings set
    status = 'completed',
    history = history || public.event('completed', p.slug, nullif(trim(p_report), ''))
  where id = p_id returning * into b;
  return b;
end $$;

revoke execute on function public.can_operate(public.profiles) from public, anon, authenticated;
revoke execute on function public.check_in_booking(uuid), public.complete_booking(uuid, text) from public, anon;
grant execute on function public.check_in_booking(uuid), public.complete_booking(uuid, text) to authenticated;
