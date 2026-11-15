-- Review fixes for users and roles.

-- 1. A turned-off approver no longer counts as covering level 1, so the
--    admin fallback takes over instead of requests getting stuck.
create or replace function public.needs_level1_fallback(b public.bookings) returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (
    select 1 from public.profiles p
    where p.active and p.id <> b.requester_id and public.covers_l1(p, b)
  )
$$;

-- Canonical (sorted) forms, so reordering isn't seen as a change.
create or replace function public.sorted_scopes(s jsonb) returns jsonb
language sql immutable as $$
  select coalesce(jsonb_agg(e order by e->>'type', coalesce(e->>'establishment_id', '')), '[]')
  from jsonb_array_elements(coalesce(s, '[]')) e
$$;
create or replace function public.sorted_text(a text[]) returns text[]
language sql immutable as $$
  select coalesce(array_agg(x order by x), '{}') from unnest(coalesce(a, '{}')) x
$$;

-- 2. One function, now with: a lock so two admins can't remove each other
--    at the same time; a "stale" refusal when the person changed since the
--    admin opened the page; known establishments only; and the option to
--    cancel a turned-off person's waiting requests.
create or replace function public.set_person_access(
  p_slug text, p_roles text[], p_scopes jsonb, p_clubs text[], p_active boolean,
  p_expected jsonb, p_cancel_pending boolean default false
) returns int
language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.me();
  prev public.profiles;
  allowed text[] := array['student','professor','communication','clubRepresentative','externalClient',
                          'entityApprover','studioManager','regisseur','admin'];
  establishments text[] := array['eidia','emadu'];
  v_roles text[];
  v_scopes jsonb := '[]';
  v_clubs text[] := '{}';
  added text[];
  removed text[];
  parts text[] := '{}';
  s jsonb;
  cancelled int := 0;
begin
  if not public.has_role(me, 'admin') then raise exception 'not_allowed'; end if;
  -- Serialise access changes: the last-admin rule must see a stable world.
  perform pg_advisory_xact_lock(hashtext('set_person_access'));
  select * into prev from public.profiles where slug = p_slug for update;
  if prev.id is null then raise exception 'unknown_person'; end if;

  if p_expected is not null and (
       public.sorted_text(prev.roles) is distinct from public.sorted_text(array(select jsonb_array_elements_text(p_expected->'roles')))
    or public.sorted_scopes(prev.approver_scopes) is distinct from public.sorted_scopes(p_expected->'scopes')
    or public.sorted_text(prev.club_ids) is distinct from public.sorted_text(array(select jsonb_array_elements_text(p_expected->'clubs')))
    or prev.active is distinct from (p_expected->>'active')::boolean) then
    raise exception 'stale';
  end if;

  v_roles := public.sorted_text(array(select distinct unnest(p_roles)));
  if cardinality(v_roles) = 0 then raise exception 'no_role'; end if;
  if not v_roles <@ allowed then raise exception 'bad_role'; end if;

  if 'entityApprover' = any (v_roles) then
    if jsonb_typeof(coalesce(p_scopes, '[]')) <> 'array' then raise exception 'bad_scope'; end if;
    for s in select * from jsonb_array_elements(coalesce(p_scopes, '[]')) loop
      if coalesce(s->>'type', '') not in ('student','club','professor','communication','external') then
        raise exception 'bad_scope';
      end if;
      if s ? 'establishment_id' and s->>'establishment_id' is not null
         and not (s->>'establishment_id' = any (establishments)) then
        raise exception 'bad_scope';
      end if;
    end loop;
    v_scopes := public.sorted_scopes(p_scopes);
    if jsonb_array_length(v_scopes) = 0 then raise exception 'scope_required'; end if;
  end if;
  if 'clubRepresentative' = any (v_roles) then
    v_clubs := public.sorted_text(p_clubs);
    if cardinality(v_clubs) = 0 then raise exception 'club_required'; end if;
  end if;

  if prev.id = me.id and (not p_active or not ('admin' = any (v_roles))) then
    raise exception 'self_lockout';
  end if;
  if (not p_active or not ('admin' = any (v_roles)))
     and 'admin' = any (prev.roles)
     and not exists (select 1 from public.profiles
                     where profiles.active and 'admin' = any (profiles.roles) and profiles.id <> prev.id) then
    raise exception 'last_admin';
  end if;

  update public.profiles
    set roles = v_roles, approver_scopes = v_scopes, club_ids = v_clubs, active = p_active
    where id = prev.id;

  -- A turned-off person's waiting requests can be cancelled in the same step.
  if not p_active and p_cancel_pending then
    update public.bookings
      set status = 'cancelled',
          history = history || public.event('cancelled', me.slug, 'Compte désactivé par l’administration')
      where requester_id = prev.id and status in ('pendingEntity','pendingStudio');
    get diagnostics cancelled = row_count;
  end if;

  select coalesce(array_agg(x), '{}') into added from unnest(v_roles) x where not x = any (prev.roles);
  select coalesce(array_agg(x), '{}') into removed from unnest(prev.roles) x where not x = any (v_roles);
  if cardinality(added) > 0 then
    parts := parts || ('+ ' || (select string_agg(public.role_label(x), ', ') from unnest(added) x));
  end if;
  if cardinality(removed) > 0 then
    parts := parts || ('− ' || (select string_agg(public.role_label(x), ', ') from unnest(removed) x));
  end if;
  if v_scopes is distinct from public.sorted_scopes(case when 'entityApprover' = any (prev.roles) then prev.approver_scopes else '[]' end) then
    parts := parts || 'périmètre de validation modifié'::text;
  end if;
  if v_clubs is distinct from public.sorted_text(case when 'clubRepresentative' = any (prev.roles) then prev.club_ids else '{}' end) then
    parts := parts || 'clubs modifiés'::text;
  end if;
  if p_active is distinct from prev.active then
    parts := parts || (case when p_active then 'compte réactivé' else 'compte désactivé' end)::text;
  end if;
  if cancelled > 0 then
    parts := parts || (cancelled || ' demande(s) en attente annulée(s)')::text;
  end if;
  if cardinality(parts) = 0 then return 0; end if;

  perform public.audit(
    case when p_active is distinct from prev.active
         then case when p_active then 'accountEnabled' else 'accountDisabled' end
         else 'rolesChanged' end,
    'person', prev.slug,
    prev.first_name || ' ' || prev.last_name || ' : ' || array_to_string(parts, ' · '),
    jsonb_build_object('before', jsonb_build_object('roles', prev.roles, 'scopes', prev.approver_scopes,
                                                    'clubs', prev.club_ids, 'active', prev.active),
                       'after', jsonb_build_object('roles', v_roles, 'scopes', v_scopes,
                                                   'clubs', v_clubs, 'active', p_active),
                       'cancelled', cancelled));
  return cancelled;
end $$;
revoke execute on function public.set_person_access(text, text[], jsonb, text[], boolean, jsonb, boolean) from public, anon;
grant execute on function public.set_person_access(text, text[], jsonb, text[], boolean, jsonb, boolean) to authenticated;

-- The old 5-argument version is replaced.
revoke execute on function public.set_person_access(text, text[], jsonb, text[], boolean) from public, anon, authenticated;
