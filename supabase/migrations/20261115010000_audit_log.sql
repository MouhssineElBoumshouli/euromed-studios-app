-- P-11 / I8: an activity log for admin actions (role changes, rule
-- changes, demo resets…). Booking and project actions already keep their
-- own history; the activity screen shows all three together.
create table public.audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_slug text,              -- null = the system (nightly job)
  action text not null,         -- e.g. 'rolesChanged', 'settingsChanged'
  target_type text,             -- 'person', 'settings', 'studio', …
  target_id text,
  summary text not null check (char_length(summary) <= 300),
  details jsonb not null default '{}'
);
create index audit_log_at on public.audit_log (at desc);

alter table public.audit_log enable row level security;
-- Only admins read it; nobody writes to it directly (append-only).
create policy "admins read" on public.audit_log for select to authenticated
  using (public.has_role(public.me(), 'admin'));

create trigger audit_log_bump after insert on public.audit_log
  for each statement execute function public.bump_world();

create or replace function public.audit(
  p_action text, p_target_type text, p_target_id text, p_summary text, p_details jsonb default '{}'
) returns void
language sql security definer set search_path = public as $$
  insert into public.audit_log (actor_slug, action, target_type, target_id, summary, details)
  values ((public.me()).slug, p_action, p_target_type, p_target_id, left(p_summary, 300), coalesce(p_details, '{}'))
$$;
revoke execute on function public.audit(text, text, text, text, jsonb) from public, anon, authenticated;

-- Log demo resets (by an admin, or by the nightly job).
alter function public.reset_demo() rename to reset_demo_all;
revoke execute on function public.reset_demo_all() from public, anon, authenticated;

create or replace function public.reset_demo() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.has_role(public.me(), 'admin') then
    raise exception 'not_allowed';
  end if;
  perform public.reset_demo_all();
  perform public.audit('demoReset', 'demo', null,
    case when auth.uid() is null then 'Remise à zéro automatique des données de démonstration'
         else 'Remise à zéro des données de démonstration' end);
end $$;
revoke execute on function public.reset_demo() from public, anon;
grant execute on function public.reset_demo() to authenticated;
