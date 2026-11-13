-- Notifications are derived from booking history in the app (decision
-- 0005). The server only remembers, per person, when they last opened
-- their notifications. Each person can only set their own.
alter table public.profiles add column notifications_seen_at timestamptz;

create or replace function public.mark_notifications_seen() returns timestamptz
language plpgsql security definer set search_path = public as $$
declare t timestamptz := now();
begin
  if auth.uid() is null then raise exception 'not_signed_in'; end if;
  update public.profiles set notifications_seen_at = t where id = auth.uid();
  return t;
end $$;
revoke execute on function public.mark_notifications_seen() from public, anon;
grant execute on function public.mark_notifications_seen() to authenticated;
