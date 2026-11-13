-- The régie demo needs sessions happening "now". After the usual reset, add
-- two validated sessions around the current hour (on weekdays, during
-- opening hours): one with its access open, one starting next hour.
alter function public.reset_demo() rename to reset_demo_base;
revoke execute on function public.reset_demo_base() from public, anon, authenticated;

create or replace function public.reset_demo() returns void
language plpgsql security definer set search_path = public as $$
declare
  local timestamp := now() at time zone 'Africa/Casablanca';
  h int := extract(hour from local)::int;
  rami uuid := (select id from public.profiles where slug = 'rami');
  adam uuid := (select id from public.profiles where slug = 'adam');
  base timestamptz := date_trunc('hour', local) at time zone 'Africa/Casablanca';
begin
  if auth.uid() is not null and not public.has_role(public.me(), 'admin') then
    raise exception 'not_allowed';
  end if;
  perform public.reset_demo_base();
  if extract(isodow from local) <= 5 and h between 9 and 16 then
    insert into public.bookings (reference, requester_id, requester_slug, requester_type, establishment_id, club_id,
      studio_id, start_at, end_at, activity, status, note, technician_slug, equipment, history) values
    ('ES-2026-0136', rami, 'rami', 'professor', 'eidia', null, 'chroma',
      base, base + interval '1 hour', 'filming', 'approved', 'Tournage d’une capsule sur fond vert.', 'haddad',
      '[{"item_id":"led_kit","quantity":1,"required":true,"outcome":"confirmed"}]',
      jsonb_build_array(
        jsonb_build_object('type','submitted','at',now()-interval '3 days','actor','rami'),
        jsonb_build_object('type','entityApproved','at',now()-interval '2 days','actor','benjelloun'),
        jsonb_build_object('type','studioApproved','at',now()-interval '1 day','actor','tazi'))),
    ('ES-2026-0139', adam, 'adam', 'club', 'emadu', 'club_av', 'podcast',
      base + interval '1 hour', base + interval '2 hours', 'recording', 'approved', null, null, '[]',
      jsonb_build_array(
        jsonb_build_object('type','submitted','at',now()-interval '4 days','actor','adam'),
        jsonb_build_object('type','entityApproved','at',now()-interval '3 days','actor','amrani'),
        jsonb_build_object('type','studioApproved','at',now()-interval '2 days','actor','tazi')));
  end if;
end $$;
revoke execute on function public.reset_demo() from public, anon;
grant execute on function public.reset_demo() to authenticated;
