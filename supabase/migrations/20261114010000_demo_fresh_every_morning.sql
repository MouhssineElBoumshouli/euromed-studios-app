-- Keep the live demo fresh without anyone pressing "reset".
-- 1. reset_demo() also seeds "today" sessions when run before opening
--    (10:00 and 14:00), not only during opening hours.
-- 2. A nightly job resets the demo at 04:00 UTC, Monday to Friday, so the
--    demo always shows today's sessions and recent requests. Weekends keep
--    Friday's data (the studios are closed then).
create or replace function public.reset_demo() returns void
language plpgsql security definer set search_path = public as $$
declare
  local timestamp := now() at time zone 'Africa/Casablanca';
  h int := extract(hour from local)::int;
  weekday boolean := extract(isodow from local) <= 5;
  rami uuid := (select id from public.profiles where slug = 'rami');
  adam uuid := (select id from public.profiles where slug = 'adam');
  a timestamptz;  -- first session start
  b timestamptz;  -- second session start
begin
  if auth.uid() is not null and not public.has_role(public.me(), 'admin') then
    raise exception 'not_allowed';
  end if;
  perform public.reset_demo_base();
  if weekday and h between 9 and 16 then
    -- During the day: one session now, one next hour.
    a := date_trunc('hour', local) at time zone 'Africa/Casablanca';
    b := a + interval '1 hour';
  elsif weekday and h < 9 then
    -- Early morning (the nightly job): one in the morning, one after lunch.
    a := (local::date + time '10:00') at time zone 'Africa/Casablanca';
    b := (local::date + time '14:00') at time zone 'Africa/Casablanca';
  else
    return;
  end if;
  insert into public.bookings (reference, requester_id, requester_slug, requester_type, establishment_id, club_id,
    studio_id, start_at, end_at, activity, status, note, technician_slug, equipment, history) values
  ('ES-2026-0136', rami, 'rami', 'professor', 'eidia', null, 'chroma',
    a, a + interval '1 hour', 'filming', 'approved', 'Tournage d’une capsule sur fond vert.', 'haddad',
    '[{"item_id":"led_kit","quantity":1,"required":true,"outcome":"confirmed"}]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',now()-interval '3 days','actor','rami'),
      jsonb_build_object('type','entityApproved','at',now()-interval '2 days','actor','benjelloun'),
      jsonb_build_object('type','studioApproved','at',now()-interval '1 day','actor','tazi'))),
  ('ES-2026-0139', adam, 'adam', 'club', 'emadu', 'club_av', 'podcast',
    b, b + interval '1 hour', 'recording', 'approved', null, null, '[]',
    jsonb_build_array(
      jsonb_build_object('type','submitted','at',now()-interval '4 days','actor','adam'),
      jsonb_build_object('type','entityApproved','at',now()-interval '3 days','actor','amrani'),
      jsonb_build_object('type','studioApproved','at',now()-interval '2 days','actor','tazi')));
end $$;
revoke execute on function public.reset_demo() from public, anon;
grant execute on function public.reset_demo() to authenticated;

create extension if not exists pg_cron;
select cron.unschedule(jobid) from cron.job where jobname = 'demo-fresh-every-morning';
select cron.schedule('demo-fresh-every-morning', '0 4 * * 1-5', 'select public.reset_demo()');
