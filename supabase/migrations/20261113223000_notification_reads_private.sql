-- Review fix: "when did X last read their notifications" is private.
-- Move it out of profiles (readable by every signed-in person) into a
-- table each person can read only for themselves.
create table public.notification_reads (
  person_id uuid primary key references public.profiles (id) on delete cascade,
  seen_at timestamptz not null
);
alter table public.notification_reads enable row level security;
create policy "own only" on public.notification_reads for select to authenticated
  using (person_id = auth.uid());

insert into public.notification_reads (person_id, seen_at)
  select id, notifications_seen_at from public.profiles where notifications_seen_at is not null;
update public.profiles set notifications_seen_at = null where notifications_seen_at is not null;
comment on column public.profiles.notifications_seen_at is 'Unused since notification_reads; to be dropped.';

create or replace function public.mark_notifications_seen() returns timestamptz
language plpgsql security definer set search_path = public as $$
declare t timestamptz := now();
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  insert into public.notification_reads (person_id, seen_at) values (auth.uid(), t)
  on conflict (person_id) do update set seen_at = excluded.seen_at;
  return t;
end $$;
revoke execute on function public.mark_notifications_seen() from public, anon;
grant execute on function public.mark_notifications_seen() to authenticated;
