-- Demo data must respect the rules it demonstrates: Yasmine's third
-- request moves 8 weekdays ahead so her week never exceeds the 2 h quota.
do $$
declare d text;
begin
  select pg_get_functiondef('public.reset_demo_base()'::regprocedure) into d;
  d := replace(d, 'demo_at(4,9), demo_at(4,10)', 'demo_at(8,9), demo_at(8,10)');
  execute d;
end $$;
select public.reset_demo();
