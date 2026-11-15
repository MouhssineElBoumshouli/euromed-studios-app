-- A turned-off account must not reach anything. Four functions and two
-- read rules still trusted the sign-in alone (auth.uid()); they now go
-- through me(), which returns nothing for a turned-off account.

create or replace function public.can_view(b public.bookings) returns boolean
language sql stable security definer set search_path = public as $$
  select (public.me()).id is not null and (
       b.requester_id = (public.me()).id
    or public.is_staff(public.me())
    or public.covers_l1(public.me(), b)
    or exists (select 1 from jsonb_array_elements(b.history) e where e->>'actor' = (public.me()).slug))
$$;

create or replace function public.busy_slots(p_from timestamptz, p_to timestamptz)
returns table (id uuid, studio_id text, start_at timestamptz, end_at timestamptz, status text)
language sql stable security definer set search_path = public as $$
  select b.id, b.studio_id, b.start_at, b.end_at, b.status from public.bookings b
  where (public.me()).id is not null
    and b.status in ('pendingEntity','pendingStudio','approved')
    and b.start_at < p_to and p_from < b.end_at
$$;

create or replace function public.sign_charter() returns void
language plpgsql security definer set search_path = public as $$
declare v text; me public.profiles := public.me();
begin
  if me.id is null then raise exception 'not_signed_in'; end if;
  select charter_version into v from public.settings;
  insert into public.charter_signatures (person_id, version) values (me.id, v)
  on conflict do nothing;
end $$;

create or replace function public.mark_notifications_seen() returns timestamptz
language plpgsql security definer set search_path = public as $$
declare t timestamptz := now(); me public.profiles := public.me();
begin
  if me.id is null then raise exception 'not_signed_in'; end if;
  insert into public.notification_reads (person_id, seen_at) values (me.id, t)
  on conflict (person_id) do update set seen_at = excluded.seen_at;
  return t;
end $$;

drop policy "own or staff" on public.charter_signatures;
create policy "own or staff" on public.charter_signatures for select to authenticated
  using (person_id = (public.me()).id or public.is_staff(public.me()) or public.has_role(public.me(), 'entityApprover'));

drop policy "own only" on public.notification_reads;
create policy "own only" on public.notification_reads for select to authenticated
  using (person_id = (public.me()).id);
