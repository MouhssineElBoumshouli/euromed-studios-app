-- Review fixes for the régie:
-- * an absence is its own status ("noShow"), never a finished session;
-- * a session can only be closed after a check-in;
-- * the early entry window is the admin setting qr_grace_minutes (Q19),
--   the same one that opens the QR pass, so pass and door agree;
-- * a session already started (checked in) can no longer be cancelled.

alter table public.bookings drop constraint bookings_status_check;
alter table public.bookings add constraint bookings_status_check
  check (status in ('pendingEntity','pendingStudio','approved','refused','cancelled','completed','noShow'));
update public.settings set qr_grace_minutes = 15 where id = 1;

create or replace function public.check_in_booking(p_id uuid) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  b public.bookings;
  early int := (select qr_grace_minutes from public.settings);
begin
  if not public.can_operate(p) then raise exception 'not_allowed'; end if;
  select * into b from public.bookings where id = p_id for update;
  if b.id is null then raise exception 'not_found'; end if;
  if b.status <> 'approved' then raise exception 'not_validated'; end if;
  if b.history @> '[{"type":"checkedIn"}]' then raise exception 'already_checked_in'; end if;
  if now() < b.start_at - make_interval(mins => early) then raise exception 'too_early'; end if;
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
  if b.status <> 'approved' or not (b.history @> '[{"type":"checkedIn"}]') then
    raise exception 'not_allowed';
  end if;
  update public.bookings set
    status = 'completed',
    history = history || public.event('completed', p.slug, nullif(trim(p_report), ''))
  where id = p_id returning * into b;
  return b;
end $$;

create or replace function public.mark_no_show(p_id uuid) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  b public.bookings;
begin
  if not public.can_operate(p) then raise exception 'not_allowed'; end if;
  select * into b from public.bookings where id = p_id for update;
  if b.id is null then raise exception 'not_found'; end if;
  if b.status <> 'approved' or b.history @> '[{"type":"checkedIn"}]'
     or now() < b.start_at + interval '15 minutes' then
    raise exception 'not_allowed';
  end if;
  update public.bookings set
    status = 'noShow',
    history = history || public.event('noShow', p.slug)
  where id = p_id returning * into b;
  return b;
end $$;

create or replace function public.cancel_booking(p_id uuid, p_reason text default null)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  b public.bookings;
begin
  select * into b from public.bookings where id = p_id for update;
  if b.id is null then raise exception 'not_found'; end if;
  if not ((b.requester_id = p.id or public.has_role(p,'admin'))
          and b.status in ('pendingEntity','pendingStudio','approved')
          and b.start_at > now()
          and not (b.history @> '[{"type":"checkedIn"}]')) then
    raise exception 'not_allowed';
  end if;
  update public.bookings set
    status = 'cancelled',
    history = history || public.event('cancelled', p.slug, nullif(trim(p_reason), ''))
  where id = p_id returning * into b;
  return b;
end $$;

revoke execute on function public.mark_no_show(uuid) from public, anon;
grant execute on function public.mark_no_show(uuid) to authenticated;
