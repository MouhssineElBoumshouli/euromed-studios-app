-- Euromed Studios · core schema, permissions and booking rules.
--
-- Principle: the app may only READ through row-level security. Every change
-- goes through the functions below, which check the same rules as the app
-- (docs/requirements.md R-09..R-19, P-02, Q18) on the server, so a modified
-- app can't skip them. Enum-like text values match the Dart enum names.

create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------------ catalog
create table public.settings (
  id int primary key default 1 check (id = 1),
  opening_hour int not null default 9,
  closing_hour int not null default 18,
  slot_minutes int not null default 60,
  max_advance_days int not null default 30,
  student_quota_minutes int default 120,
  qr_grace_minutes int not null default 0,
  charter_version text not null default '1.0',
  time_zone text not null default 'Africa/Casablanca'
);
insert into public.settings default values;

create table public.studios (
  id text primary key,
  name text not null,
  room_id text not null,
  bookable boolean not null default true
);

create table public.equipment (
  id text primary key,
  name text not null,
  stock int not null check (stock >= 0)
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  slug text not null unique,
  first_name text not null,
  last_name text not null,
  title text,
  establishment_id text,
  roles text[] not null default '{}',
  club_ids text[] not null default '{}',
  -- [{ "type": "student", "establishment_id": null }, ...]
  approver_scopes jsonb not null default '[]'
);

create table public.charter_signatures (
  person_id uuid not null references public.profiles (id) on delete cascade,
  version text not null,
  signed_at timestamptz not null default now(),
  primary key (person_id, version)
);

create sequence public.booking_reference_seq start 147;

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  reference text not null unique,
  requester_id uuid not null references public.profiles (id),
  requester_slug text not null,
  requester_type text not null
    check (requester_type in ('student','club','professor','communication','external')),
  establishment_id text,
  club_id text,
  project_id text,
  studio_id text not null references public.studios (id),
  start_at timestamptz not null,
  end_at timestamptz not null check (end_at > start_at),
  activity text not null check (activity in ('recording','filming','editing','mixing')),
  status text not null
    check (status in ('pendingEntity','pendingStudio','approved','refused','cancelled','completed')),
  note text check (char_length(note) <= 300),
  refusal_reason text,
  technician_slug text,
  -- [{ "item_id", "quantity", "required", "outcome", "note" }]
  equipment jsonb not null default '[]',
  -- [{ "type", "at", "actor", "comment" }] — append-only audit trail (P-11)
  history jsonb not null default '[]',
  created_at timestamptz not null default now()
);
create index bookings_time_idx on public.bookings (start_at, end_at);
create index bookings_requester_idx on public.bookings (requester_id);

create table public.maintenance (
  id uuid primary key default gen_random_uuid(),
  room_id text not null,
  start_at timestamptz not null,
  end_at timestamptz not null check (end_at > start_at),
  reason text not null
);

-- One row that changes whenever bookings change. Everyone may listen to it,
-- so every screen refreshes live without seeing other people's details.
create table public.world_version (
  id int primary key default 1 check (id = 1),
  version bigint not null default 0,
  updated_at timestamptz not null default now()
);
insert into public.world_version default values;

-- ------------------------------------------------------------------ helpers
create or replace function public.me() returns public.profiles
language sql stable security definer set search_path = public as $$
  select * from public.profiles where id = auth.uid()
$$;

create or replace function public.has_role(p public.profiles, r text) returns boolean
language sql immutable as $$ select p.id is not null and r = any (p.roles) $$;

create or replace function public.is_staff(p public.profiles) returns boolean
language sql immutable as $$
  select public.has_role(p,'studioManager') or public.has_role(p,'admin') or public.has_role(p,'regisseur')
$$;

create or replace function public.covers_l1(p public.profiles, b public.bookings) returns boolean
language sql immutable as $$
  select public.has_role(p,'entityApprover') and exists (
    select 1 from jsonb_array_elements(p.approver_scopes) s
    where s->>'type' = b.requester_type
      and (s->>'establishment_id' is null or s->>'establishment_id' = b.establishment_id)
  )
$$;

create or replace function public.decided_earlier(p public.profiles, b public.bookings) returns boolean
language sql immutable as $$
  select exists (
    select 1 from jsonb_array_elements(b.history) e
    where e->>'actor' = p.slug and e->>'type' in ('entityApproved','studioApproved')
  )
$$;

-- Q18: if nobody but the requester covers Level 1, the Administrator decides.
create or replace function public.needs_level1_fallback(b public.bookings) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from public.profiles p where p.id <> b.requester_id and public.covers_l1(p, b)
  )
$$;

create or replace function public.can_decide(p public.profiles, b public.bookings) returns boolean
language sql stable security definer set search_path = public as $$
  select p.id is not null
     and p.id <> b.requester_id                       -- P-02: no self-approval
     and not public.decided_earlier(p, b)             -- R-16: two different people
     and case b.status
       when 'pendingEntity' then public.covers_l1(p, b)
         or (public.has_role(p,'admin') and public.needs_level1_fallback(b))
       when 'pendingStudio' then public.has_role(p,'studioManager') or public.has_role(p,'admin')
       else false
     end
$$;

create or replace function public.can_view(b public.bookings) returns boolean
language sql stable security definer set search_path = public as $$
  select b.requester_id = auth.uid()
      or public.is_staff(public.me())
      or public.covers_l1(public.me(), b)
      or exists (select 1 from jsonb_array_elements(b.history) e where e->>'actor' = (public.me()).slug)
$$;

create or replace function public.room_of(studio text) returns text
language sql stable as $$ select room_id from public.studios where id = studio $$;

-- What blocks a slot, in words, or null. Shared rooms block each other.
create or replace function public.slot_problem(
  p_studio text, p_start timestamptz, p_end timestamptz, p_exclude uuid, p_only_approved boolean
) returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select 'Créneau déjà ' || case when o.status = 'approved' then 'validé' else 'en attente' end
            || ' pour ' || s.name || ' (' || o.reference || ').'
       from public.bookings o join public.studios s on s.id = o.studio_id
      where o.id is distinct from p_exclude
        and s.room_id = public.room_of(p_studio)
        and (case when p_only_approved then o.status = 'approved'
                  else o.status in ('pendingEntity','pendingStudio','approved') end)
        and o.start_at < p_end and p_start < o.end_at
      limit 1),
    (select 'Maintenance prévue : ' || m.reason || '.'
       from public.maintenance m
      where m.room_id = public.room_of(p_studio) and m.start_at < p_end and p_start < m.end_at
      limit 1)
  )
$$;

create or replace function public.bump_world() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.world_version set version = version + 1, updated_at = now() where id = 1;
  return null;
end $$;
create trigger bookings_bump after insert or update or delete on public.bookings
  for each statement execute function public.bump_world();
create trigger maintenance_bump after insert or update or delete on public.maintenance
  for each statement execute function public.bump_world();
create trigger charter_bump after insert or update or delete on public.charter_signatures
  for each statement execute function public.bump_world();

-- --------------------------------------------------------------- reads (RLS)
alter table public.settings enable row level security;
alter table public.studios enable row level security;
alter table public.equipment enable row level security;
alter table public.profiles enable row level security;
alter table public.charter_signatures enable row level security;
alter table public.bookings enable row level security;
alter table public.maintenance enable row level security;
alter table public.world_version enable row level security;

create policy "signed-in read" on public.settings for select to authenticated using (true);
create policy "signed-in read" on public.studios for select to authenticated using (true);
create policy "signed-in read" on public.equipment for select to authenticated using (true);
create policy "signed-in read" on public.profiles for select to authenticated using (true);
create policy "signed-in read" on public.maintenance for select to authenticated using (true);
create policy "signed-in read" on public.world_version for select to authenticated using (true);
create policy "own or staff" on public.charter_signatures for select to authenticated
  using (person_id = auth.uid() or public.is_staff(public.me()) or public.has_role(public.me(),'entityApprover'));
create policy "who may see a booking" on public.bookings for select to authenticated
  using (public.can_view(bookings));
-- No insert/update/delete policies: writes only through the functions below.

-- Times taken in every room, without who or why: for availability screens.
create or replace function public.busy_slots(p_from timestamptz, p_to timestamptz)
returns table (id uuid, studio_id text, start_at timestamptz, end_at timestamptz, status text)
language sql stable security definer set search_path = public as $$
  select b.id, b.studio_id, b.start_at, b.end_at, b.status from public.bookings b
  where auth.uid() is not null
    and b.status in ('pendingEntity','pendingStudio','approved')
    and b.start_at < p_to and p_from < b.end_at
$$;

-- -------------------------------------------------------------------- writes
create or replace function public.event(p_type text, p_actor text, p_comment text default null)
returns jsonb language sql stable as $$
  select jsonb_build_object('type', p_type, 'at', now(), 'actor', p_actor, 'comment', p_comment)
$$;

create or replace function public.sign_charter() returns void
language plpgsql security definer set search_path = public as $$
declare v text;
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  select charter_version into v from public.settings;
  insert into public.charter_signatures (person_id, version) values (auth.uid(), v)
  on conflict do nothing;
end $$;

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
  if ls::date <> le::date
     or extract(isodow from ls) > 5
     or extract(hour from ls) < st.opening_hour
     or (extract(hour from le) * 60 + extract(minute from le)) > st.closing_hour * 60
     or extract(epoch from (p_end - p_start)) / 60 < st.slot_minutes
     or (extract(epoch from (p_end - p_start)) / 60)::int % st.slot_minutes <> 0
     or extract(minute from ls) <> 0 then
    raise exception 'outside_opening_hours';
  end if;
  if p_start <= now() then raise exception 'in_the_past'; end if;
  if p_start > now() + make_interval(days => st.max_advance_days) then raise exception 'too_far_ahead'; end if;
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

create or replace function public.approve_booking(
  p_id uuid, p_comment text default null, p_equipment jsonb default null, p_technician text default null
) returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  b public.bookings;
  problem text;
begin
  select * into b from public.bookings where id = p_id for update;
  if b.id is null then raise exception 'not_found'; end if;
  if not public.can_decide(p, b) then raise exception 'not_allowed'; end if;
  if b.status = 'pendingEntity' then
    update public.bookings set
      status = 'pendingStudio',
      history = history || public.event('entityApproved', p.slug, nullif(trim(p_comment), ''))
    where id = p_id returning * into b;
  else
    problem := public.slot_problem(b.studio_id, b.start_at, b.end_at, b.id, true);
    if problem is not null then raise exception 'conflict: %', problem; end if;
    if p_technician is not null and not exists (
      select 1 from public.profiles where slug = p_technician and 'regisseur' = any (roles)) then
      raise exception 'unknown_technician';
    end if;
    update public.bookings set
      status = 'approved',
      equipment = coalesce(p_equipment, equipment),
      technician_slug = p_technician,
      history = history || public.event('studioApproved', p.slug, nullif(trim(p_comment), ''))
    where id = p_id returning * into b;
  end if;
  return b;
end $$;

create or replace function public.refuse_booking(p_id uuid, p_reason text)
returns public.bookings
language plpgsql security definer set search_path = public as $$
declare
  p public.profiles := public.me();
  b public.bookings;
begin
  if p_reason is null or trim(p_reason) = '' then raise exception 'reason_required'; end if;
  select * into b from public.bookings where id = p_id for update;
  if b.id is null then raise exception 'not_found'; end if;
  if not public.can_decide(p, b) then raise exception 'not_allowed'; end if;
  update public.bookings set
    status = 'refused',
    refusal_reason = trim(p_reason),
    history = history || public.event('refused', p.slug, trim(p_reason))
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
          and b.start_at > now()) then
    raise exception 'not_allowed';
  end if;
  update public.bookings set
    status = 'cancelled',
    history = history || public.event('cancelled', p.slug, nullif(trim(p_reason), ''))
  where id = p_id returning * into b;
  return b;
end $$;

-- Only the functions above are callable; helpers stay internal.
revoke execute on all functions in schema public from public, anon;
grant execute on function public.busy_slots(timestamptz, timestamptz),
  public.sign_charter(), public.submit_booking(text, timestamptz, timestamptz, text, text, text, text, jsonb),
  public.approve_booking(uuid, text, jsonb, text), public.refuse_booking(uuid, text),
  public.cancel_booking(uuid, text)
  to authenticated;
-- RLS policies call these helpers as the signed-in user.
grant execute on function public.me(), public.has_role(public.profiles, text), public.is_staff(public.profiles),
  public.covers_l1(public.profiles, public.bookings), public.can_view(public.bookings)
  to authenticated;

alter publication supabase_realtime add table public.world_version;
