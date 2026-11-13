alter function public.decided_earlier(public.profiles, public.bookings) set search_path = public;
alter function public.room_of(text) set search_path = public;
alter function public.event(text, text, text) set search_path = public;
alter function public.has_role(public.profiles, text) set search_path = public;
alter function public.is_staff(public.profiles) set search_path = public;
alter function public.covers_l1(public.profiles, public.bookings) set search_path = public;
revoke execute on function public.can_decide(public.profiles, public.bookings) from authenticated;
