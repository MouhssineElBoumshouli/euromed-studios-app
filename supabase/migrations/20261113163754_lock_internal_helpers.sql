revoke execute on function public.slot_problem(text, timestamptz, timestamptz, uuid, boolean),
  public.needs_level1_fallback(public.bookings), public.can_decide(public.profiles, public.bookings),
  public.decided_earlier(public.profiles, public.bookings), public.room_of(text),
  public.event(text, text, text), public.bump_world()
  from authenticated, anon, public;
grant execute on function public.can_decide(public.profiles, public.bookings) to authenticated;
